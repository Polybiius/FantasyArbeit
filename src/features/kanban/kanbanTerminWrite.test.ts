import { describe, expect, it } from 'vitest';

import { computeTerminRange } from './kanbanTerminWrite';

const TZ = 'Europe/Berlin';

describe('computeTerminRange', () => {
  it('liefert null bei fehlendem Datum/Start/Ende', () => {
    expect(computeTerminRange('', '09:00', '10:00', TZ)).toBeNull();
    expect(computeTerminRange('2026-06-15', '', '10:00', TZ)).toBeNull();
    expect(computeTerminRange('2026-06-15', '09:00', '', TZ)).toBeNull();
  });

  it("liefert 'invalid', wenn das Ende nicht nach dem Start liegt", () => {
    expect(computeTerminRange('2026-06-15', '10:00', '10:00', TZ)).toBe('invalid');
    expect(computeTerminRange('2026-06-15', '10:00', '09:00', TZ)).toBe('invalid');
  });

  it('berechnet den korrekten UTC-Bereich für eine gültige Eingabe (Sommerzeit)', () => {
    const range = computeTerminRange('2026-06-15', '09:00', '10:30', TZ);
    expect(range).not.toBe('invalid');
    expect(range).not.toBeNull();
    if (range === 'invalid' || range === null) throw new Error('unreachable');
    expect(range.startAt.toISOString()).toBe('2026-06-15T07:00:00.000Z');
    expect(range.endAt.toISOString()).toBe('2026-06-15T08:30:00.000Z');
  });
});
