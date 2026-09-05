import { describe, expect, it } from 'vitest';

import { fullPartsInTZ, zonedTimeToUtc } from './timezone';

describe('zonedTimeToUtc', () => {
  it('roundtrip: fullPartsInTZ(zonedTimeToUtc(...)) liefert dieselben Wandzeit-Komponenten', () => {
    const parts = { year: 2026, month: 6, day: 15, hour: 14, minute: 30 };
    const utc = zonedTimeToUtc(parts.year, parts.month, parts.day, parts.hour, parts.minute, 'Europe/Berlin');
    expect(fullPartsInTZ(utc, 'Europe/Berlin')).toEqual(parts);
  });

  it('berücksichtigt den Sommerzeit-Versatz (Europe/Berlin, UTC+2 im Juni)', () => {
    const utc = zonedTimeToUtc(2026, 6, 15, 14, 0, 'Europe/Berlin');
    expect(utc.toISOString()).toBe('2026-06-15T12:00:00.000Z');
  });

  it('berücksichtigt den Winterzeit-Versatz (Europe/Berlin, UTC+1 im Januar)', () => {
    const utc = zonedTimeToUtc(2026, 1, 15, 14, 0, 'Europe/Berlin');
    expect(utc.toISOString()).toBe('2026-01-15T13:00:00.000Z');
  });

  it('liefert für UTC selbst dieselbe Uhrzeit unverändert zurück', () => {
    const utc = zonedTimeToUtc(2026, 1, 15, 14, 0, 'UTC');
    expect(utc.toISOString()).toBe('2026-01-15T14:00:00.000Z');
  });
});
