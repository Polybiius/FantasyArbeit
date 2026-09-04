/**
 * Portierung von Vanillas `tz()`-Prinzip (CLAUDE.md "Zeitzonen: pro
 * Nutzer, geräteunabhängig") — NUR das Jahr, gebraucht für den
 * Akquise-Trichter-Duplikatschutz (`hasFunnelMarkerThisYear` in
 * `kanbanTransitions.ts`).
 *
 * Bewusst OHNE `organizations.timezone`-Fallback (Vanillas dritte
 * Stufe, `tz(){ return profile.timezone || org.timezone ||
 * 'Europe/Berlin' }`) — die Spalte ist laut CLAUDE.md für jede
 * Organisation aktuell fest auf 'Europe/Berlin' (Platzhalter für
 * künftige internationale Skalierung, noch nie anders genutzt). Ein
 * zusätzlicher Netzwerk-Request nur für diesen praktisch nie
 * greifenden Rückfall stünde in keinem Verhältnis — `profile.timezone`
 * fehlt → 'Europe/Berlin' liefert heute in jedem echten Fall dasselbe
 * Ergebnis wie Vanillas volle Kette.
 */
export function resolveTimeZone(profileTimezone: string | null | undefined): string {
  return profileTimezone || 'Europe/Berlin';
}

/** Kalenderjahr eines Zeitpunkts in einer IANA-Zeitzone (z.B. für Jahres-Duplikatschutz-Vergleiche). */
export function yearInTimeZone(date: Date, timeZone: string): number {
  return Number(new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric' }).format(date));
}
