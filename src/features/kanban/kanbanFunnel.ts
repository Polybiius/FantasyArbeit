import { sb } from '@/shared/lib/bridge';
import { yearInTimeZone } from '@/shared/lib/timezone';

import type { KanbanFunnelMarker } from './kanbanTransitions';

const FUNNEL_MARKERS: readonly KanbanFunnelMarker[] = [
  'termin_wahrgenommen',
  'zweittermin_wahrgenommen',
  'zweittermin_vereinbart',
];

/**
 * 1:1-Portierung von Vanillas `hasFunnelMarkerThisYear()` (`index.html`)
 * — bewusst dieselbe Technik: alle drei Trichter-Marken-Zeilen des
 * Kontakts laden (kleine Menge, kein Datumsfilter in der Abfrage nötig)
 * und ERST DANACH im Speicher nach Jahr filtern, statt einen
 * UTC-Datumsbereich in die Abfrage selbst zu schreiben — Vanilla filtert
 * genauso rein clientseitig (`todayKey(e.created_at).slice(0,4)===year`),
 * vermeidet damit dieselbe Zeitzonen-Umrechnungs-Fallstricke, die eine
 * DB-seitige `>= <Jahresanfang-UTC>`-Grenze bräuchte.
 *
 * **`.eq('user_id', ownerId)` ist Pflicht, nicht optional** (Fund einer
 * unabhängigen Zweitmeinung): Vanillas eigenes `log`-Array ist beim
 * Laden bereits auf `user_id = eigene ID` gescopt (`index.html`,
 * `sb.from('action_log')...eq('user_id', profile.id)`). Ohne diesen
 * Filter liefert `action_log`s RLS-Policy (die Sichtbarkeit u.a. über
 * den AKTUELLEN Kontakt-Eigentümer auflöst, siehe CLAUDE.md "Chronik-
 * Sichtbarkeit folgt der Kontakt-Freigabe") bei einem im laufenden Jahr
 * umverteilten Kontakt (Gilden-Pool, Mitarbeiter-Offboarding) auch
 * Zeilen des VORBESITZERS zurück — eine bereits vom Vorbesitzer
 * geloggte Marke hätte die eigene, neue Marke sonst fälschlich
 * unterdrückt.
 */
export async function fetchFunnelMarkerRows(
  contactId: string,
  ownerId: string,
): Promise<Array<{ action_key: string; created_at: string }>> {
  const { data, error } = await sb()
    .from('action_log')
    .select('action_key,created_at')
    .eq('contact_id', contactId)
    .eq('user_id', ownerId)
    .in('action_key', FUNNEL_MARKERS);
  if (error) throw error;
  return data;
}

export function buildHasFunnelMarkerThisYear(
  rows: ReadonlyArray<{ action_key: string; created_at: string }>,
  timeZone: string,
): (marker: KanbanFunnelMarker) => boolean {
  const currentYear = yearInTimeZone(new Date(), timeZone);
  const loggedThisYear = new Set(
    rows.filter((row) => yearInTimeZone(new Date(row.created_at), timeZone) === currentYear).map((row) => row.action_key),
  );
  return (marker) => loggedThisYear.has(marker);
}
