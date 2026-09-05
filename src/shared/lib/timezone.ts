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

export interface WallClockParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
}

/** 1:1-Portierung von `fullPartsInTZ()` — wie `yearInTimeZone()`, aber der ganze Wandzeit-Zeitpunkt inkl. Uhrzeit, gebraucht von `zonedTimeToUtc()`. */
export function fullPartsInTZ(date: Date, timeZone: string): WallClockParts {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  });
  const map: Record<string, string> = {};
  for (const part of fmt.formatToParts(date)) map[part.type] = part.value;
  return { year: Number(map.year), month: Number(map.month), day: Number(map.day), hour: Number(map.hour), minute: Number(map.minute) };
}

/**
 * 1:1-Portierung von `zonedTimeToUtc()` — kehrt `fullPartsInTZ()` um: aus
 * Wandzeit-Komponenten (Jahr/Monat/Tag/Stunde/Minute), interpretiert in
 * einer bestimmten IANA-Zeitzone, den korrekten UTC-Zeitpunkt
 * konstruieren. Standard-Näherungsverfahren (2 Durchläufe reichen, da
 * eine Zeitzone ihren Versatz nie zweimal in derselben Stunde wechselt):
 * erste Näherung naiv als UTC interpretieren, per `Intl` prüfen, wie sie
 * sich in der Zielzone tatsächlich liest, Differenz zur gewünschten
 * Wandzeit draufaddieren.
 */
export function zonedTimeToUtc(year: number, month: number, day: number, hour: number, minute: number, timeZone: string): Date {
  const wanted = Date.UTC(year, month - 1, day, hour, minute);
  let guess = wanted;
  for (let i = 0; i < 2; i++) {
    const p = fullPartsInTZ(new Date(guess), timeZone);
    const seen = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute);
    const diff = wanted - seen;
    if (diff === 0) break;
    guess += diff;
  }
  return new Date(guess);
}
