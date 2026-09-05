import { getBridge, sb, type ActionLogRow } from '@/shared/lib/bridge';
import { logSilentError, reportError } from '@/shared/lib/errorLog';
import { withRetry } from '@/shared/lib/retry';

import { contactDisplayName } from '@/shared/domain/contactCard/contactDisplay';
import type { KanbanContact } from './kanbanApi';
import type { KanbanExtraAction, KanbanFunnelMarker, KanbanMainAction } from './kanbanTransitions';

export type LoggableKanbanAction = KanbanMainAction | KanbanFunnelMarker | KanbanExtraAction;

/**
 * Gemeinsamer `log_action_for_self()`-Aufruf für jede Art von
 * Kanban-Aktion (Hauptaktion, Trichter-Marke, oder eine der optionalen
 * Zusatzaktionen aus `offerExtraAction()`) — vorher nur in
 * `kanbanMutations.ts` definiert, jetzt zentral, damit die
 * Zusatzaktions-Popups (`KanbanExtraActionModal.tsx`) dieselbe Funktion
 * nutzen können statt eine zweite Kopie zu pflegen.
 *
 * **Resilienz-Entscheidung 2026-09-05 (Nutzer-Gespräch zur offenen
 * Architektur-Frage aus `docs/migration-status.md` Block 5):**
 * Priorität ist Gesamtsystem/CRM vor Gamification-Ebene — eine
 * fehlschlagende XP-/Trichter-Buchung darf den viel wichtigeren
 * Kanban-/CRM-Schreibpfad nicht blockieren, exakt wie Vanillas
 * `logKanbanAction()` (`index.html`, nutzt `reportError()`, kein
 * `throw`). Zwei Bausteine dafür:
 * 1. `withRetry()` fängt den häufigsten Fall (kurzer Netzwerk-Wackler)
 *    unsichtbar ab, bevor überhaupt "fehlgeschlagen" gilt — der Aufruf
 *    ist serverseitig idempotent (5-Sekunden-Dedup-Fenster,
 *    "Idempotenz-Härtung"), ein Retry kann also nie doppelt buchen.
 * 2. Bleibt es dabei (echter Ausfall statt Wackler), wird NICHT
 *    geworfen — `reportError()` meldet sichtbar (Alert +
 *    Fehlerprotokoll, wie Vanilla) und die Funktion gibt `null` zurück.
 *    Aufrufer (`kanbanMutations.ts`) laufen dadurch unverändert weiter,
 *    genau wie `moveKanbanCard()` das bei einem `ok===false` tut.
 */
export async function logKanbanAction(
  contact: Pick<KanbanContact, 'id' | 'location_id' | 'name' | 'vorname' | 'nachname'>,
  actionKey: LoggableKanbanAction,
): Promise<ActionLogRow | null> {
  try {
    return await withRetry(async () => {
      const { data, error } = await sb().rpc('log_action_for_self', {
        p_action_key: actionKey,
        p_context: contactDisplayName(contact),
        p_location_id: contact.location_id ?? undefined,
        p_contact_id: contact.id,
      });
      if (error) throw error;
      return data;
    });
  } catch (err) {
    reportError(`Kanban-Aktion speichern (${actionKey})`, err);
    return null;
  }
}

/**
 * Loggt UND meldet die Buchung sofort an die Brücke (ADR-0002,
 * `notifyActionLogged()`) — siehe Modul-Kommentar an
 * `useMoveKanbanCardMutation()` für die Begründung, warum das einzeln
 * pro Buchung passiert statt gebündelt am Ende. Gibt die eingefügte
 * Zeile zurück (z.B. für `attachKanalToLoggedAction()`, das die ID der
 * gerade geloggten "Termin vereinbart"-Aktion braucht) — oder `null`,
 * wenn `logKanbanAction()` selbst nach Wiederholungsversuchen
 * fehlgeschlagen ist (siehe dortiger Kommentar); Aufrufer laufen in
 * diesem Fall bewusst unverändert weiter, es gibt nichts an die Brücke
 * zu melden.
 *
 * **Der Bridge-Sync wird bewusst NICHT als Teil des Erfolgs/Misserfolgs
 * dieser Funktion behandelt** (Fund einer unabhängigen Zweitmeinung,
 * 2026-09-05): `log_action_for_self` hat zu diesem Zeitpunkt bereits
 * unwiderruflich geschrieben — ein fehlschlagender `notifyActionLogged()`
 * danach ist nur ein UI-Sync-Problem (Vanillas XP-/Energie-Anzeige
 * hinkt bis zum nächsten eigenen Render hinterher), kein Buchungsfehler.
 * Würde dieser Fehler stattdessen geworfen, könnte ein Aufrufer, der bei
 * einem Fehlschlag einen erneuten Klick zulässt (z.B.
 * `KanbanExtraActionModal`), außerhalb des serverseitigen 5-Sekunden-
 * Dedup-Fensters (CLAUDE.md "Idempotenz-Härtung") dieselbe Aktion ein
 * zweites Mal buchen.
 */
export async function logAndNotify(
  contact: Pick<KanbanContact, 'id' | 'location_id' | 'name' | 'vorname' | 'nachname'>,
  actionKey: LoggableKanbanAction,
): Promise<ActionLogRow | null> {
  const row = await logKanbanAction(contact, actionKey);
  if (!row) return null;
  try {
    await getBridge().notifyActionLogged([row]);
  } catch (err) {
    logSilentError('Bridge-Sync nach Aktion', err);
  }
  return row;
}
