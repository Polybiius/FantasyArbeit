import { getBridge } from '@/shared/lib/bridge';

/**
 * Entspricht `reportError()` / `logSilentError()` im Vanilla-Code: jeder
 * fehlgeschlagene Datenbank-Vorgang landet in der `error_log`-Tabelle,
 * damit ein Admin ihn im „Fehlerprotokoll"-Reiter sieht, ohne dass sich
 * der Nutzer erst melden muss.
 *
 * Die sichtbare Rückmeldung an den Nutzer (Toast / Formular-Fehlertext)
 * kommt separat mit dem globalen Toast-System (späteres Block-2-Stück) —
 * hier geht es nur um den Protokoll-Eintrag.
 */
export function logToErrorLog(context: string, message: string): void {
  try {
    const bridge = getBridge();
    const profile = bridge.getProfile();
    // Ohne Organisation (reiner Pool-Nutzer) gibt es kein org-gebundenes
    // Fehlerprotokoll -- und dort läuft ohnehin noch kein React.
    if (!profile?.org_id) return;
    void bridge.sb
      .from('error_log')
      .insert({ org_id: profile.org_id, user_id: profile.id, context, message })
      .then(({ error }) => {
        if (error) console.error('error_log insert fehlgeschlagen', error);
      });
  } catch (e) {
    // Brücke nicht verfügbar (z.B. app.html ohne Vanilla-Bundle).
    console.error('[error_log nicht verfügbar]', context, message, e);
  }
}

/** Hintergrund-Fehler: Konsole + Fehlerprotokoll, kein Popup. */
export function logSilentError(context: string, error: unknown): void {
  console.error(context, error);
  logToErrorLog(context, toMessage(error));
}

/**
 * Entspricht `reportError()` (ohne `statusEl`-Variante) im Vanilla-Code:
 * Konsole + Fehlerprotokoll + sichtbarer `alert()`. Für Fehler, die trotz
 * Wiederholungsversuchen bestehen bleiben, den begonnenen Vorgang aber
 * NICHT abbrechen sollen — siehe
 * `src/features/kanban/kanbanActionLog.ts` (Entscheidung 2026-09-05: eine
 * fehlschlagende XP-/Trichter-Buchung meldet sich sichtbar, blockiert
 * aber die wichtigere CRM-Schreiboperation nicht).
 */
export function reportError(context: string, error: unknown): void {
  console.error(context, error);
  const message = toMessage(error);
  logToErrorLog(context, message);
  window.alert(`Fehler: ${message}`);
}

function toMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}
