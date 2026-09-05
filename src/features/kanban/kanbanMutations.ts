import { useMutation, useQueryClient, type QueryClient } from '@tanstack/react-query';

import { getBridge } from '@/shared/lib/bridge';
import { lockedUpdate } from '@/shared/lib/lockedUpdate';
import { qk } from '@/shared/lib/queryKeys';
import { resolveTimeZone } from '@/shared/lib/timezone';
import type { Json } from '@/shared/types/supabase';

import { contactDisplayName } from '@/shared/domain/contactCard/contactDisplay';
import { logAndNotify } from './kanbanActionLog';
import type { KanbanBoardColumns, KanbanContact } from './kanbanApi';
import type { KanbanExtraPopups } from './useKanbanExtraPopups';
import type { KanbanSalePopups } from './useKanbanSalePopups';
import { buildHasFunnelMarkerThisYear, fetchFunnelMarkerRows } from './kanbanFunnel';
import { BEDARFSANALYSE_EXTRA_OPTIONS, DAUERBRENNER_EXTRA_OPTIONS } from './kanbanLabels';
import { fetchOrgActionCosts } from './kanbanRuleConfig';
import { syncWiedervorlageTask } from './kanbanSaleWrite';
import { attachKanalToLoggedAction } from './kanbanTerminWrite';
import { decideKanbanTransition, resolveLostOutcome, resolveWonFunnelMarkers, type KanbanStage } from './kanbanTransitions';

export interface MoveKanbanCardInput {
  contact: KanbanContact;
  toStage: KanbanStage;
}

export type MoveKanbanCardResult = { moved: true } | { conflict: true };

/**
 * Verschiebt eine Karte ZWISCHEN zwei Spalten im Cache, sofort auf den
 * bereits vom Server bestätigten Stand (nicht erst nach einem Refetch) —
 * schließt zwei von einer unabhängigen Zweitmeinung gefundene Zeitfenster
 * in einem Rutsch: (a) bliebe das Board bis zum nächsten Refetch in der
 * alten Spalte stehen, obwohl `kanban_stage` in der DB schon geändert
 * ist, sähe ein sofortiges zweites Ziehen derselben Karte einen falschen
 * Ausgangspunkt; (b) ohne das frische `updated_at` im Cache würde ein
 * sofortiger zweiter Zug mit dem VERALTETEN `updated_at` gegen
 * `update_contact_locked` laufen und fälschlich als Konflikt
 * ("jemand anders hat das geändert") abgelehnt — CLAUDE.md verlangt genau
 * deshalb explizit, dass jede Schreibstelle das lokale Objekt nach Erfolg
 * nachzieht.
 *
 * Getrennt von `patchContactFieldsInCache()` (Fund einer unabhängigen
 * Zweitmeinung, 2026-09-05: eine einzige Funktion für "Karte zwischen
 * Spalten verschieben" UND "Felder in derselben Spalte patchen" über
 * einen `fromStage===toStage`-Trick war unnötig unklar) — diese Funktion
 * verschiebt IMMER zwischen unterschiedlichen Spalten.
 */
function moveContactInCache(
  queryClient: QueryClient,
  ownerId: string,
  contactId: string,
  fromStage: KanbanStage,
  toStage: KanbanStage,
  patch: Partial<KanbanContact>,
) {
  queryClient.setQueryData<KanbanBoardColumns>(qk.kanban.board(ownerId), (old) => {
    if (!old) return old;
    const found = old[fromStage].find((c) => c.id === contactId);
    if (!found) return old;
    const updated: KanbanContact = { ...found, ...patch, kanban_stage: toStage };
    return {
      ...old,
      [fromStage]: old[fromStage].filter((c) => c.id !== contactId),
      [toStage]: [...old[toStage], updated],
    };
  });
}

/**
 * Patcht Felder einer Karte, OHNE sie zwischen Spalten zu verschieben
 * (z.B. der reine Status-/Wiedervorlage-Nachzug nach "Gewonnen"/
 * "Verloren", wo die Spalte bereits feststeht). Siehe `moveContactInCache()`
 * für die Begründung der Aufteilung.
 */
function patchContactFieldsInCache(
  queryClient: QueryClient,
  ownerId: string,
  contactId: string,
  stage: KanbanStage,
  patch: Partial<KanbanContact>,
) {
  queryClient.setQueryData<KanbanBoardColumns>(qk.kanban.board(ownerId), (old) => {
    if (!old) return old;
    const found = old[stage].find((c) => c.id === contactId);
    if (!found) return old;
    const updated: KanbanContact = { ...found, ...patch };
    return { ...old, [stage]: old[stage].map((c) => (c.id === contactId ? updated : c)) };
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
 * **"Gewonnen"/"Verloren" (dieser Baustein):** `salePopups` (siehe
 * `useKanbanSalePopups.tsx`) öffnet das jeweilige Verkaufs-Popup und
 * liefert erst zurück, wenn der Nutzer geantwortet hat — `resolveWonFunnelMarkers()`/
 * `resolveLostOutcome()` (`kanbanTransitions.ts`) entscheiden danach,
 * was das für Spalte/Status/Trichter-Marken bedeutet, 1:1 zu
 * `moveContactToGewonnenAndRecordSale()`/`recordWinOrLoss()` im echten
 * Code. **Bewusste Vereinfachung gegenüber Vanilla:** scheitert der
 * NACHGELAGERTE Status-Update (`contacts.status` → 'kunde'/'verloren')
 * an einem echten Fehler (nicht an einem Sperr-Konflikt — der wird über
 * `statusUpdateConflicted`/`{conflict:true}` korrekt behandelt), wirft
 * `lockedUpdate()` und bricht die Mutation ab, während Vanilla dort nur
 * `logSilentError()` loggt und trotzdem `true` zurückgibt. Realer Fehler
 * an dieser Stelle (Kontakt existiert/RLS greift bereits) ist ein sehr
 * seltener Randfall; der `onSettled`-Refetch unten zieht den echten
 * Serverstand in jedem Fall nach.
 *
 * **Zusatz-Popups (Bedarfsanalyse/Termin), dieser Baustein:**
 * `extraPopups` (siehe `useKanbanExtraPopups.tsx`) hängt am Ende des
 * Normalfalls dieselbe Sequenz wie in `moveKanbanCard()` an — alle
 * überspringbar, ändern nie, OB die Karte verschoben wurde (die Spalte
 * steht zu diesem Zeitpunkt schon fest). Bewusst NUR im Normalfall, nicht
 * bei "Gewonnen"/"Verloren" (1:1 zu Vanilla — dort gibt es keine
 * Bedarfsanalyse-/Termin-Nachfrage). Iteriert seit einer unabhängigen
 * Zweitmeinung (2026-09-05) über `plan.popups` statt über eine zweite,
 * unabhängig gepflegte `if`-Kette derselben Entscheidung.
 */
export function useMoveKanbanCardMutation(salePopups: KanbanSalePopups, extraPopups: KanbanExtraPopups) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: ['kanban', 'move'],
    mutationFn: async ({ contact, toStage }: MoveKanbanCardInput): Promise<MoveKanbanCardResult> => {
      const fromStage = contact.kanban_stage;

      const profile = getBridge().getProfile();
      if (!profile) throw new Error('Keine Session — Kanban-Zug kann nicht gespeichert werden.');
      if (!profile.org_id) throw new Error('Keine Organisation — Kanban ist nur für Organisationsmitglieder verfügbar.');
      const orgId = profile.org_id;
      const timeZone = resolveTimeZone(profile.timezone);
      const conflictSubject = `Kontakt „${contactDisplayName(contact)}“`;

      const [actionCosts, funnelRows] = await Promise.all([
        // Regelwerk ändert sich selten -- gecacht statt bei jedem
        // Kartenzug neu vom Server geladen (Fund einer unabhängigen
        // Zweitmeinung: Effizienz).
        queryClient.fetchQuery({
          queryKey: qk.kanban.actionCosts(orgId),
          queryFn: () => fetchOrgActionCosts(orgId),
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

      // ---- Sonderfall "Gewonnen" ----------------------------------------
      if (plan.specialFlow === 'gewonnen') {
        const staged = await lockedUpdate(
          'update_contact_locked',
          { p_id: contact.id, p_expected_updated_at: contact.updated_at, p_patch: { kanban_stage: 'gewonnen' } },
          conflictSubject,
        );
        if (!staged) return { conflict: true };
        moveContactInCache(queryClient, profile.id, contact.id, fromStage, 'gewonnen', { updated_at: staged.updated_at });

        const result = await salePopups.requestWonSale(contact);

        // Wiedervorlage wird UNABHÄNGIG vom Verkaufs-Ausgang geschrieben
        // (auch im Revert-Pfad unten) -- 1:1 zu `recordWonSalesLoop()` im
        // echten Code. Fund zweier unabhängiger Zweitmeinungen
        // (2026-09-05): (a) `naechster_kontakt` wird MIT der jeweils
        // nächsten ohnehin fälligen Spalten-/Status-Änderung in EINEM
        // `lockedUpdate()`-Aufruf kombiniert statt in einem eigenen --
        // `update_contact_locked` akzeptiert beliebige Kombinationen
        // seiner erlaubten Felder gleichzeitig, ein zweiter, unabhängiger
        // Schreibvorgang war unnötig UND riskant: ein Konflikt darin hätte
        // (b) den danach folgenden Schreibvorgang mit dem GLEICHEN,
        // bereits veralteten `updated_at` erneut scheitern lassen (zwei
        // Konflikt-Meldungen für eine einzige Kollision) UND (c) eine
        // `tasks`-Wiedervorlage-Zeile hätte entstehen können, obwohl das
        // zugehörige `contacts.naechster_kontakt` gar nicht gespeichert
        // wurde -- `syncWiedervorlageTask()` läuft deshalb jetzt NACH dem
        // kombinierten Schreibvorgang, nur bei dessen Erfolg (1:1 zu
        // Vanillas Reihenfolge).
        if (!result.saleRecorded) {
          // Kein Produkt eingetragen -- Spalte zurücknehmen (Revert-Pfad,
          // siehe Modul-Kommentar an `resolveWonFunnelMarkers()`).
          const revertPatch: Record<string, Json> = { kanban_stage: fromStage };
          if (result.wiedervorlage) revertPatch.naechster_kontakt = result.wiedervorlage;
          const reverted = await lockedUpdate(
            'update_contact_locked',
            { p_id: contact.id, p_expected_updated_at: staged.updated_at, p_patch: revertPatch },
            conflictSubject,
          );
          if (!reverted) return { conflict: true };
          moveContactInCache(queryClient, profile.id, contact.id, 'gewonnen', fromStage, { updated_at: reverted.updated_at });
          if (result.wiedervorlage) {
            await syncWiedervorlageTask(orgId, profile.id, contact.id, contactDisplayName(contact), result.wiedervorlage);
          }
          return { moved: true };
        }

        // Status-Update VOR der "abschluss"-XP-Buchung (Fund einer
        // unabhängigen Zweitmeinung, 2026-09-05 -- kehrt die vorherige
        // Reihenfolge um): Vanillas `recordWinOrLoss()` setzt
        // `contacts.status` ebenfalls VOR dem XP-Log, damit ein
        // fehlschlagender `log_action_for_self`-Aufruf (Netzwerk-Hänger
        // o.ä.) danach nicht die wichtigere CRM-Tatsache verhindert --
        // sonst stünde die Karte in "Gewonnen" mit bereits eingetragenem
        // Verkauf, aber `contacts.status` bliebe auf dem alten Wert
        // stehen, ohne normalen Weg, das über die UI zu wiederholen (die
        // Karte lässt sich nicht "erneut" auf eine bereits erreichte
        // Spalte ziehen).
        const wonPatch: Record<string, Json> = { status: 'kunde' };
        if (result.wiedervorlage) wonPatch.naechster_kontakt = result.wiedervorlage;
        let statusUpdateConflicted = false;
        const statusUpdated = await lockedUpdate(
          'update_contact_locked',
          { p_id: contact.id, p_expected_updated_at: staged.updated_at, p_patch: wonPatch },
          conflictSubject,
        );
        if (statusUpdated) {
          patchContactFieldsInCache(queryClient, profile.id, contact.id, 'gewonnen', {
            updated_at: statusUpdated.updated_at,
            status: 'kunde',
          });
          if (result.wiedervorlage) {
            await syncWiedervorlageTask(orgId, profile.id, contact.id, contactDisplayName(contact), result.wiedervorlage);
          }
        } else {
          statusUpdateConflicted = true;
        }

        await logAndNotify(contact, 'abschluss');

        // Trichter-Marken MÜSSEN auch im Konfliktfall noch geloggt werden
        // (siehe `resolveWonFunnelMarkers()`-Dokumentation) -- deshalb erst
        // danach `{conflict:true}` zurückgeben (Fund einer unabhängigen
        // Zweitmeinung, 2026-09-05: vorher wurde der Konflikt hier
        // verschluckt, die Mutation gab immer `{moved:true}` zurück).
        for (const marker of resolveWonFunnelMarkers(statusUpdateConflicted, plan.funnelMarkersIfWon)) {
          await logAndNotify(contact, marker);
        }
        return statusUpdateConflicted ? { conflict: true } : { moved: true };
      }

      // ---- Sonderfall "Verloren" -----------------------------------------
      if (plan.specialFlow === 'verloren') {
        const updated = await lockedUpdate(
          'update_contact_locked',
          { p_id: contact.id, p_expected_updated_at: contact.updated_at, p_patch: { kanban_stage: 'verloren' } },
          conflictSubject,
        );
        if (!updated) return { conflict: true };
        moveContactInCache(queryClient, profile.id, contact.id, fromStage, 'verloren', { updated_at: updated.updated_at });

        // Trichter-Marken werden SOFORT gebucht, unabhängig vom
        // Popup-Ausgang (1:1 zu `decideKanbanTransition()`s `funnelMarkers`
        // bei `specialFlow==='verloren'`).
        for (const marker of plan.funnelMarkers) {
          await logAndNotify(contact, marker);
        }

        const saleRecorded = await salePopups.requestLostSale(contact);
        const outcome = resolveLostOutcome(saleRecorded);
        if (outcome.setStatusVerloren) {
          const statusUpdated = await lockedUpdate(
            'update_contact_locked',
            { p_id: contact.id, p_expected_updated_at: updated.updated_at, p_patch: { status: 'verloren' } },
            conflictSubject,
          );
          if (!statusUpdated) return { conflict: true };
          patchContactFieldsInCache(queryClient, profile.id, contact.id, 'verloren', {
            updated_at: statusUpdated.updated_at,
            status: 'verloren',
          });
        }
        return { moved: true };
      }

      // ---- Normalfall (alle übrigen Übergänge) ----------------------------
      const updated = await lockedUpdate(
        'update_contact_locked',
        { p_id: contact.id, p_expected_updated_at: contact.updated_at, p_patch: { kanban_stage: toStage } },
        conflictSubject,
      );
      if (!updated) return { conflict: true };

      moveContactInCache(queryClient, profile.id, contact.id, fromStage, toStage, { updated_at: updated.updated_at });

      let mainActionRow: { id: string } | null = null;
      if (plan.mainAction) {
        mainActionRow = await logAndNotify(contact, plan.mainAction);
      }
      for (const marker of plan.funnelMarkers) {
        await logAndNotify(contact, marker);
      }

      // ---- Zusatz-Popups (überspringbar, 1:1 zu `moveKanbanCard()`) --------
      for (const popup of plan.popups) {
        if (popup === 'bedarfsanalyse-optional') {
          await extraPopups.offerExtraAction(contact, BEDARFSANALYSE_EXTRA_OPTIONS);
        } else if (popup === 'termin-ersttermin') {
          // Der Kanal war beim `logAndNotify()` oben noch nicht bekannt (kommt
          // erst aus diesem Popup) -- deshalb hier an der bereits geloggten
          // "Termin vereinbart"-Aktion nachgetragen, 1:1 zu
          // `attachKanalToLoggedAction(ok, usedKanal)` im echten Code.
          const usedKanal = await extraPopups.promptTermin(contact, 'Ersttermin');
          await attachKanalToLoggedAction(mainActionRow?.id, usedKanal);
        } else if (popup === 'termin-zweittermin') {
          await extraPopups.promptTermin(contact, 'Zweittermin');
        } else if (popup === 'dauerbrenner-optional') {
          await extraPopups.offerExtraAction(contact, DAUERBRENNER_EXTRA_OPTIONS);
        }
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
