/**
 * Retry mit exponentiellem Backoff für einzelne, idempotente
 * Netzwerk-Aufrufe — Entscheidung 2026-09-05 (siehe
 * `src/features/kanban/kanbanActionLog.ts`): ein kurzer WLAN-/Server-
 * Wackler soll eine ansonsten erfolgreiche Kanban-Aktion nicht sofort
 * als „endgültig gescheitert" behandeln.
 *
 * **Bewusst NICHT als globaler TanStack-Query-`mutations.retry`-Default**
 * (`src/app/queryClient.ts` setzt dort explizit `retry: 0`) — das würde
 * die GESAMTE, oft mehrschrittige Mutation erneut von vorn laufen lassen
 * (bereits erledigte Schreibschritte, erneut geöffnete Popups). Dieser
 * Helfer wird stattdessen gezielt um EINEN einzelnen RPC-Aufruf gelegt,
 * der serverseitig gegen Mehrfachbuchung abgesichert ist (CLAUDE.md
 * „Idempotenz-Härtung" — `log_action_for_self()` hat ein 5-Sekunden-
 * Dedup-Fenster gegen exakt wiederholte Aufrufe).
 */
export interface RetryOptions {
  /** Zusätzliche Versuche nach dem ersten (Default 2 → insgesamt 3 Versuche). */
  retries?: number;
  /** Basis-Pause vor dem ersten Wiederholungsversuch, verdoppelt sich je Versuch. */
  baseDelayMs?: number;
}

export async function withRetry<T>(fn: () => Promise<T>, opts: RetryOptions = {}): Promise<T> {
  const retries = opts.retries ?? 2;
  const baseDelayMs = opts.baseDelayMs ?? 500;
  let lastError: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (attempt === retries) break;
      await sleep(baseDelayMs * 2 ** attempt);
    }
  }
  throw lastError;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
