import { describe, expect, it, vi } from 'vitest';

import { withRetry } from './retry';

describe('withRetry', () => {
  it('gibt das Ergebnis beim ersten Versuch zurück, ohne zu warten', async () => {
    const fn = vi.fn().mockResolvedValue('ok');
    await expect(withRetry(fn, { baseDelayMs: 0 })).resolves.toBe('ok');
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('versucht es nach einem Fehlschlag erneut und gibt bei Erfolg zurück', async () => {
    const fn = vi
      .fn()
      .mockRejectedValueOnce(new Error('netzwerk-wackler'))
      .mockResolvedValueOnce('ok-beim-zweiten-versuch');
    await expect(withRetry(fn, { baseDelayMs: 0 })).resolves.toBe('ok-beim-zweiten-versuch');
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('wirft den letzten Fehler, wenn alle Versuche scheitern', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('dauerhaft down'));
    await expect(withRetry(fn, { retries: 2, baseDelayMs: 0 })).rejects.toThrow('dauerhaft down');
    // 1 erster Versuch + 2 Wiederholungen = 3 Aufrufe insgesamt.
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('respektiert eine `retries: 0`-Konfiguration (kein Wiederholungsversuch)', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('sofort endgültig'));
    await expect(withRetry(fn, { retries: 0, baseDelayMs: 0 })).rejects.toThrow('sofort endgültig');
    expect(fn).toHaveBeenCalledTimes(1);
  });
});
