import { sb } from '@/shared/lib/bridge';
import { logSilentError } from '@/shared/lib/errorLog';
import { zonedTimeToUtc } from '@/shared/lib/timezone';

/** `termine.kanal`/`termin_series.kanal` (CLAUDE.md "Questbaum-Übersetzung, erster Schritt: Termin-Kanal"). */
export type KanbanKanal = 'online' | 'buero' | 'betrieb';

export interface TerminRange {
  startAt: Date;
  endAt: Date;
}

/**
 * 1:1-Portierung von `computeTerminRange()` — `null` bei unvollständiger
 * Eingabe (Feld noch leer), `'invalid'` bei Ende ≤ Start.
 */
export function computeTerminRange(
  datum: string,
  startStr: string,
  endeStr: string,
  timeZone: string,
): TerminRange | 'invalid' | null {
  if (!datum || !startStr || !endeStr) return null;
  const [y, m, d] = datum.split('-').map(Number);
  const [sh, sm] = startStr.split(':').map(Number);
  const [eh, em] = endeStr.split(':').map(Number);
  if (y === undefined || m === undefined || d === undefined || sh === undefined || sm === undefined || eh === undefined || em === undefined) {
    return null;
  }
  const startAt = zonedTimeToUtc(y, m, d, sh, sm, timeZone);
  const endAt = zonedTimeToUtc(y, m, d, eh, em, timeZone);
  if (endAt.getTime() <= startAt.getTime()) return 'invalid';
  return { startAt, endAt };
}

/** 1:1-Portierung des `termine`-Inserts aus `promptKanbanTermin()`. */
export async function insertKanbanTermin(
  orgId: string,
  ownerId: string,
  contactId: string,
  title: string,
  range: TerminRange,
  kanal: KanbanKanal | null,
): Promise<void> {
  const { error } = await sb()
    .from('termine')
    .insert({
      org_id: orgId,
      owner_id: ownerId,
      contact_id: contactId,
      title,
      start_at: range.startAt.toISOString(),
      end_at: range.endAt.toISOString(),
      kanal,
    });
  if (error) throw error;
}

/**
 * 1:1-Portierung von `attachKanalToLoggedAction()` — trägt den erst im
 * Termin-Popup gewählten Kanal nachträglich am bereits geloggten
 * `action_log`-Eintrag ("Termin vereinbart") nach. Läuft über die
 * eigene `attach_kanal_to_own_action`-RPC statt eines direkten
 * `.update()` (CLAUDE.md: `action_log` hat seit der RLS-Härtung keine
 * Schreib-Policy mehr). **Non-kritisch, wie im Original:** schlägt der
 * Nachtrag fehl, bleibt die Aktion einfach ohne Kanal-Zuordnung stehen,
 * kein Abbruch der Karten-Verschiebung.
 */
export async function attachKanalToLoggedAction(logId: string | undefined, kanal: KanbanKanal | null): Promise<void> {
  if (!logId || !kanal) return;
  const { error } = await sb().rpc('attach_kanal_to_own_action', { p_log_id: logId, p_kanal: kanal });
  if (error) logSilentError('Kanal nachtragen', error);
}
