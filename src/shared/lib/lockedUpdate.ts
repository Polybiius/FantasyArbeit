import type { PostgrestError } from '@supabase/supabase-js';

import { sb } from '@/shared/lib/bridge';
import { notifyConflict } from '@/shared/lib/notifyConflict';
import { toError } from '@/shared/lib/toError';
import type { Database } from '@/shared/types/supabase';

/**
 * Die fünf Tabellen mit echtem Mehrfach-Schreiber-Risiko dürfen NICHT
 * mehr per direktem `UPDATE` beschrieben werden (keine RLS-Policy mehr) —
 * der einzige Schreibweg ist je eine `SECURITY DEFINER`-Funktion, die
 * Berechtigung + Sperr-Wert (`updated_at`) atomar prüft. Siehe CLAUDE.md
 * „Konflikt-Schutz bei gleichzeitiger Bearbeitung".
 */
export const LOCKED_UPDATE_FNS = [
  'update_contact_locked',
  'admit_location_to_guild_pool_locked',
  'assign_location_owner_locked',
  'cancel_sale_locked',
  'update_termin_locked',
  'update_termin_series_locked',
] as const;

export type LockedUpdateFn = (typeof LOCKED_UPDATE_FNS)[number];

type LockedArgs<K extends LockedUpdateFn> = Database['public']['Functions'][K]['Args'];
type LockedRow<K extends LockedUpdateFn> = Database['public']['Functions'][K]['Returns'];

export type LockedUpdateResult<T> = { data: T } | { conflict: true } | { error: PostgrestError };

/**
 * Roher Aufruf einer `*_locked`-Funktion.
 *
 * **PostgREST-Eigenheit** (live per REST-Test entdeckt, siehe CLAUDE.md):
 * ein SQL-NULL bei zusammengesetztem Rückgabetyp kommt NICHT als JSON
 * `null`, sondern als Objekt mit lauter `null`-Feldern zurück ("truthy"
 * in JS). Deshalb zusätzlich `row.id === null` prüfen, nicht nur `!row`.
 */
export async function rpcLockedUpdate<K extends LockedUpdateFn>(
  fnName: K,
  args: LockedArgs<K>,
): Promise<LockedUpdateResult<LockedRow<K>>> {
  // supabase-js kann die richtige rpc-Signatur nicht aus einem generischen
  // Funktionsnamen (K) ableiten -- deshalb hier der Cast an der Grenze.
  // Die öffentliche Signatur oben (fnName: K, args: LockedArgs<K>,
  // Rückgabe LockedRow<K>) bleibt voll typisiert.
  const { data, error } = (await sb().rpc(fnName, args as never)) as {
    data: unknown;
    error: PostgrestError | null;
  };
  if (error) return { error };
  const row = data as LockedRow<K> | null;
  if (!row || (row as { id: string | null }).id === null) return { conflict: true };
  return { data: row };
}

/**
 * Bequemer Weg: ruft die `*_locked`-Funktion auf und behandelt die drei
 * Ausgänge einheitlich.
 *   - Erfolg  -> die frische Zeile
 *   - Konflikt -> `notifyConflict(subject)` + Rückgabe `null` (Aufrufer stoppt)
 *   - Fehler  -> `throw` einer echten `Error`-Instanz
 *
 * **Logging:** dieser Weg loggt NICHT selbst — er ist dafür gedacht,
 * innerhalb einer TanStack-Mutation aufgerufen zu werden, deren
 * `mutationCache.onError` den Fehler ins `error_log` schreibt (ein
 * Owner, siehe docs/adr/0004). Ein direkter Aufrufer außerhalb einer
 * Mutation muss den geworfenen Fehler selbst per `logSilentError`
 * protokollieren.
 *
 * Nach Erfolg muss der Aufrufer den lokal gehaltenen `updated_at`-Wert
 * mitziehen (sonst läuft die nächste Aktion auf demselben Objekt in
 * einen Selbst-Konflikt) — genau wie im Vanilla-Code.
 */
export async function lockedUpdate<K extends LockedUpdateFn>(
  fnName: K,
  args: LockedArgs<K>,
  conflictSubject: string,
): Promise<LockedRow<K> | null> {
  const res = await rpcLockedUpdate(fnName, args);
  if ('error' in res) {
    throw toError(res.error);
  }
  if ('conflict' in res) {
    notifyConflict(conflictSubject);
    return null;
  }
  return res.data;
}
