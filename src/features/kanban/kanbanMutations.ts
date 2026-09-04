import { useMutation, useQueryClient, type QueryClient } from '@tanstack/react-query';

import { getBridge, sb, type ActionLogRow } from '@/shared/lib/bridge';
import { lockedUpdate } from '@/shared/lib/lockedUpdate';
import { qk } from '@/shared/lib/queryKeys';
import { resolveTimeZone } from '@/shared/lib/timezone';

import { contactDisplayName } from '@/shared/domain/contactCard/contactDisplay';
import type { KanbanBoardColumns, KanbanContact } from './kanbanApi';
import { buildHasFunnelMarkerThisYear, fetchFunnelMarkerRows } from './kanbanFunnel';
import { fetchOrgActionCosts } from './kanbanRuleConfig';
import {
  decideKanbanTransition,
  type KanbanFunnelMarker,
  type KanbanMainAction,
  type KanbanStage,
} from './kanbanTransitions';

export interface MoveKanbanCardInput {
  contact: KanbanContact;
  toStage: KanbanStage;
}

export type MoveKanbanCardResult = { moved: true } | { conflict: true };

async function logKanbanAction(
  contact: KanbanContact,
  actionKey: KanbanMainAction | KanbanFunnelMarker,
): Promise<ActionLogRow> {
  const { data, error } = await sb().rpc('log_action_for_self', {
    p_action_key: actionKey,
    p_context: contactDisplayName(contact),
    p_location_id: contact.location_id ?? undefined,
    p_contact_id: contact.id,
  });
  if (error) throw error;
  return data;
}

/**
 * Zieht die Karte im Cache SOFORT auf den bereits vom Server bestätigten
 * Stand (nicht erst nach einem Refetch) — schließt zwei von einer
 * unabhängigen Zweitmeinung gefundene Zeitfenster in einem Rutsch:
 * (a) bliebe das Board bis zum nächsten Refetch in der alten Spalte
 * stehen, obwohl `kanban_stage` in der DB schon geändert ist, sähe ein
 * sofortiges zweites Ziehen derselben Karte einen falschen Ausgangspunkt;
 * (b) ohne das frische `updated_at` im Cache würde ein sofortiger
 * zweiter Zug mit dem VERALTETEN `updated_at` gegen `update_contact_
 * locked` laufen und fälschlich als Konflikt ("jemand anders hat das
 * geändert") abgelehnt — CLAUDE.md verlangt genau deshalb explizit,
 * dass jede Schreibstelle das lokale Objekt nach Erfolg nachzieht.
 */
function moveContactInCache(
  queryClient: QueryClient,
  ownerId: string,
  contactId: string,
  fromStage: KanbanStage,
  toStage: KanbanStage,
  updatedAt: string,
) {
  queryClient.setQueryData<KanbanBoardColumns>(qk.kanban.board(ownerId), (old) => {
    if (!old) return old;
    const found = old[fromStage].find((c) => c.id === contactId);
    if (!found) return old;
    const moved: KanbanContact = { ...found, kanban_stage: toStage, updated_at: updatedAt };
    return {
      ...old,
      [fromStage]: old[fromStage].filter((c) => c.id !== contactId),
      [toStage]: [...old[toStage], moved],
    };
  });
}

/**
 * Echter Schreibpfad für einen Kanban-Kartenzug (Block 5) — Ablauf von
 * `moveKanbanCard()` in `index.html`: ERST die sperr-geprüfte
 * Spaltenänderung, ERST DANACH XP buchen (Bugfix 2026-08-30 im
 * Original — sonst XP gebucht, aber Karte gar nicht verschoben, falls
 * der Sperr-Check scheitert).
 *
 * **Jede XP-Buchung wird EINZELN sofort an die Brücke gemeldet**, nicht
 * erst gebündelt am Ende (Fund einer unabhängigen Zweitmeinung):
 * scheitert eine spätere Buchung (z.B. eine Trichter-Marke, etwa durch
 * einen kurzen Netzwerk-Hänger), bleiben die bereits erfolgreich
 * gebuchten Punkte trotzdem sofort in Vanillas Anzeige sichtbar, statt
 * bis zum nächsten Vanilla-Render verloren/verzögert zu wirken.
 *
 * **Bewusst NICHT Teil dieser Funktion: "Gewonnen"/"Verloren".** Beide
 * brauchen ein Verkaufs-Popup (Produkt/Menge erfassen bzw. Kündigung),
 * das noch nicht gebaut ist — `decideKanbanTransition()` liefert dafür
 * `specialFlow`, aber `resolveWonOutcome()`/`resolveLostOutcome()`
 * lassen sich erst NACH einem bekannten Popup-Ausgang aufrufen. Ein Zug
 * auf diese beiden Spalten wird hier deshalb klar abgelehnt statt einen
 * unvollständigen Verkauf zu erzeugen (siehe README).
 */
export function useMoveKanbanCardMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: ['kanban', 'move'],
    mutationFn: async ({ contact, toStage }: MoveKanbanCardInput): Promise<MoveKanbanCardResult> => {
      const fromStage = contact.kanban_stage;

      if (toStage === 'gewonnen' || toStage === 'verloren') {
        throw new Error(
          `„${toStage === 'gewonnen' ? 'Gewonnen' : 'Verloren'}“ braucht ein Verkaufs-Popup — das kommt in einem eigenen, ` +
            'späteren Bauschritt (siehe src/features/kanban/README.md).',
        );
      }

      const profile = getBridge().getProfile();
      if (!profile) throw new Error('Keine Session — Kanban-Zug kann nicht gespeichert werden.');
      if (!profile.org_id) throw new Error('Keine Organisation — Kanban ist nur für Organisationsmitglieder verfügbar.');
      const timeZone = resolveTimeZone(profile.timezone);

      const [actionCosts, funnelRows] = await Promise.all([
        // Regelwerk ändert sich selten -- gecacht statt bei jedem
        // Kartenzug neu vom Server geladen (Fund einer unabhängigen
        // Zweitmeinung: Effizienz).
        queryClient.fetchQuery({
          queryKey: qk.kanban.actionCosts(profile.org_id),
          queryFn: () => fetchOrgActionCosts(profile.org_id!),
          staleTime: 5 * 60_000,
        }),
        fetchFunnelMarkerRows(contact.id, profile.id),
      ]);
      const stats = getBridge().getCharacterStats();

      const plan = decideKanbanTransition(fromStage, toStage, {
        energyRemaining: stats?.energyRemaining ?? 0,
        actionEnergyCost: (action) => actionCosts[action]?.energy ?? 0,
        hasFunnelMarkerThisYear: buildHasFunnelMarkerThisYear(funnelRows, timeZone),
        isKunde: contact.status === 'kunde',
      });
      if (!plan.allowed) {
        throw new Error(plan.rejectionReason ?? 'Dieser Zug ist nicht erlaubt.');
      }

      const updated = await lockedUpdate(
        'update_contact_locked',
        { p_id: contact.id, p_expected_updated_at: contact.updated_at, p_patch: { kanban_stage: toStage } },
        `Kontakt „${contactDisplayName(contact)}“`,
      );
      if (!updated) return { conflict: true };

      moveContactInCache(queryClient, profile.id, contact.id, fromStage, toStage, updated.updated_at);

      if (plan.mainAction) {
        const row = await logKanbanAction(contact, plan.mainAction);
        await getBridge().notifyActionLogged([row]);
      }
      for (const marker of plan.funnelMarkers) {
        const row = await logKanbanAction(contact, marker);
        await getBridge().notifyActionLogged([row]);
      }

      return { moved: true };
    },
    onSettled: () => {
      // Sicherheitsnetz zusätzlich zur sofortigen Cache-Korrektur oben --
      // deckt Fälle ab, die diese Funktion selbst nicht kennt (ein
      // Kollege hat denselben geteilten Kontakt zeitgleich woanders
      // verschoben). Bewusst `onSettled`, nicht nur `onSuccess`, damit
      // auch ein abgelehnter/fehlgeschlagener Zug den Cache im
      // Hintergrund wieder mit dem echten Serverstand abgleicht.
      const ownerId = getBridge().getProfile()?.id;
      if (ownerId) void queryClient.invalidateQueries({ queryKey: qk.kanban.board(ownerId) });
    },
  });
}
