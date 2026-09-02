/**
 * Stellt sicher, dass ein Wert eine echte `Error`-Instanz ist.
 *
 * supabase-js / postgrest-js wirft bei HTTP-Fehlern eine echte
 * `Error`-Unterklasse (`PostgrestError`), aber bei **fetch-Fehlern**
 * (offline, DNS, abgebrochen) ein nacktes Objekt `{message, details,
 * hint, code}` mit `status: 0`. TanStack Query und `error instanceof
 * Error`-Prüfungen erwarten aber eine echte `Error`.
 */
export function toError(value: unknown): Error {
  if (value instanceof Error) return value;
  if (
    value !== null &&
    typeof value === 'object' &&
    'message' in value &&
    typeof value.message === 'string'
  ) {
    return Object.assign(new Error(value.message), value);
  }
  return new Error(typeof value === 'string' ? value : JSON.stringify(value));
}
