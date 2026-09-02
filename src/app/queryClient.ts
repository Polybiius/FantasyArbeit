import { MutationCache, QueryCache, QueryClient } from '@tanstack/react-query';

import { logSilentError } from '@/shared/lib/errorLog';

/**
 * Zentraler TanStack-Query-Client (docs/adr/0004).
 *
 * - `refetchOnWindowFocus: false` — die Vanilla-App lädt nie automatisch
 *   beim Fensterwechsel neu; das neue Verhalten soll sich nicht anders
 *   anfühlen.
 * - Mutations ohne Retry — Doppel-Absenden ist serverseitig abgesichert
 *   (Idempotenz-Härtung), aber ein automatischer Retry würde die
 *   `updated_at`-Sperrprüfung unnötig zweimal auslösen.
 * - Keine naiven optimistischen Updates hier als Default — die würden der
 *   serverseitigen Sperrlogik (SECURITY-DEFINER-RPCs) vorgreifen.
 * - Fehler aus Queries UND Mutations laufen global ins `error_log`
 *   (Entsprechung zu `logSilentError()` im Vanilla-Code).
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
    },
  },
  queryCache: new QueryCache({
    onError: (error, query) => {
      logSilentError(`Query ${describeKey(query.queryKey)}`, error);
    },
  }),
  mutationCache: new MutationCache({
    onError: (error, _vars, _ctx, mutation) => {
      const key = mutation.options.mutationKey;
      logSilentError(`Mutation ${key ? describeKey(key) : '(ohne Key)'}`, error);
    },
  }),
});

function describeKey(key: readonly unknown[]): string {
  return key
    .map((part) => (typeof part === 'string' || typeof part === 'number' ? String(part) : '…'))
    .join('/');
}
