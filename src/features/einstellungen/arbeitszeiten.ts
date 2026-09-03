import type { Json } from '@/shared/types/supabase';

export const WEEKDAY_KEYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] as const;
export type WeekdayKey = (typeof WEEKDAY_KEYS)[number];
export const WEEKDAY_LABELS_FULL: Record<WeekdayKey, string> = {
  mon: 'Montag', tue: 'Dienstag', wed: 'Mittwoch', thu: 'Donnerstag',
  fri: 'Freitag', sat: 'Samstag', sun: 'Sonntag',
};

export interface DaySpan {
  start: string;
  end: string;
}

export type Arbeitszeiten = Partial<Record<WeekdayKey, DaySpan>>;

function isDaySpan(v: unknown): v is DaySpan {
  return (
    typeof v === 'object' && v !== null && typeof (v as DaySpan).start === 'string' && typeof (v as DaySpan).end === 'string'
  );
}

/**
 * `profiles.arbeitszeiten` ist eine generische `Json`-Spalte (Supabase-
 * Typgenerierung kennt die konkrete Form nicht) -- hier sicher auf die
 * bekannte Form einengen, statt blind zu casten. Ein unerwarteter Wert
 * (nie vorgekommen, aber die Spalte ist technisch offen) liefert ein
 * leeres Objekt statt eines Crashs.
 */
export function parseArbeitszeiten(json: Json | null | undefined): Arbeitszeiten {
  if (typeof json !== 'object' || json === null || Array.isArray(json)) return {};
  const result: Arbeitszeiten = {};
  for (const key of WEEKDAY_KEYS) {
    const v = (json as Record<string, Json>)[key];
    if (isDaySpan(v)) result[key] = { start: v.start, end: v.end };
  }
  return result;
}
