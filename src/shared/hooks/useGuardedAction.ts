import { useCallback, useRef, useState } from 'react';

import { logSilentError } from '@/shared/lib/errorLog';

interface GuardedAction<Args extends unknown[]> {
  /** true, solange die Aktion läuft — für `disabled`/Spinner am Auslöser. */
  pending: boolean;
  /** Startet die Aktion; ignoriert Aufrufe, während sie schon läuft. */
  run: (...args: Args) => Promise<void>;
}

/**
 * Entsprechung zu `withClickGuard()` im Vanilla-Code: verhindert, dass
 * eine schreibende Aktion durch Doppelklick zweimal ausgelöst wird. Der
 * `busy`-Ref greift synchron (vor dem Re-Render), `pending` ist der
 * anzeigbare Zustand.
 *
 * Schützt NUR gegen den Doppelklick im selben Tab — nicht gegen Netzwerk-
 * Retries oder einen zweiten Tab; das deckt die serverseitige Idempotenz-
 * Härtung ab (siehe CLAUDE.md).
 *
 * Ein geworfener Fehler wird protokolliert und geschluckt (kein „kein
 * fehlgeschlagener DB-Vorgang verschwindet spurlos"). Wer eine sichtbare
 * Fehlermeldung braucht, nutzt den `error`-Zustand der zugrundeliegenden
 * TanStack-Mutation, nicht diesen Hook.
 */
export function useGuardedAction<Args extends unknown[]>(
  action: (...args: Args) => Promise<unknown>,
): GuardedAction<Args> {
  const [pending, setPending] = useState(false);
  const busy = useRef(false);

  const run = useCallback(
    async (...args: Args) => {
      if (busy.current) return;
      busy.current = true;
      setPending(true);
      try {
        await action(...args);
      } catch (err) {
        logSilentError('Geschützte Aktion fehlgeschlagen', err);
      } finally {
        busy.current = false;
        setPending(false);
      }
    },
    [action],
  );

  return { pending, run };
}
