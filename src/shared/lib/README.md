# `src/shared/lib/`

Die einzige Schicht, die die **Brücke zum Vanilla-Code** kennt.

| Datei | Inhalt |
|---|---|
| `bridge.ts` | typisierter Zugriff auf `window.__bridge` (Supabase-Client + Session + Profil, nur lesen). `getBridge()` / `sb()`. Siehe `docs/adr/0002`. |
| `errorLog.ts` | `logSilentError()` / `logToErrorLog()` — schreibt in dieselbe `error_log`-Tabelle wie `reportError()`/`logSilentError()` im Vanilla-Code. |
| `notifyConflict.ts` | `notifyConflict(subject)` — Meldung bei gleichzeitiger Bearbeitung (Entsprechung zu `alertConflict()`). Vorerst `window.alert`. |
| `lockedUpdate.ts` | `rpcLockedUpdate()` (roh) und `lockedUpdate()` (mit Konfliktmeldung, wirft eine echte `Error`) — der einzige Schreibweg auf `contacts`/`locations`/`sales`/`termine`/`termin_series` (CLAUDE.md „Konflikt-Schutz"). Loggt NICHT selbst (die TanStack-Mutation ist der Owner). |
| `toError.ts` | `toError(value)` — stellt sicher, dass ein geworfener Wert eine echte `Error`-Instanz ist (postgrest-js wirft bei fetch-Fehlern ein nacktes Objekt). |
| `queryKeys.ts` | `qk.*` — die zentrale Query-Key-Fabrik + die 5 Regeln dafür (docs/adr/0004). Kein `useQuery`/`useMutation` bildet seinen Key inline. |

## Typen

`src/shared/types/supabase.ts` wird von `npm run gen:types`
(`supabase gen types typescript --linked`) erzeugt — **nie von Hand
ändern**. Nach jeder schemaändernden Migration neu generieren (gleiche
Disziplin wie die Regressions-Suite vor jedem Push).

`@supabase/supabase-js` ist als `devDependency` **exakt** auf die Version
gepinnt, die die `index.html` per CDN lädt (aktuell `2.114.0`) — nur für
die Typen, der Runtime-Client kommt aus der Brücke.
