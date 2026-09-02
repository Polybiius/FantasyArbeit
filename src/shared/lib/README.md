# `src/shared/lib/`

Die einzige Schicht, die die **Brücke zum Vanilla-Code** kennt.

| Datei | Inhalt |
|---|---|
| `bridge.ts` | typisierter Zugriff auf `window.__bridge` (Supabase-Client + Session + Profil, nur lesen). `getBridge()` / `sb()`. Siehe `docs/adr/0002`. |

**Noch offen (Block 2, folgende Stücke):**
- `errorLog.ts` — React-Anbindung an die `error_log`-Tabelle
  (Entsprechung zu `reportError()` / `logSilentError()` im Vanilla-Code).

## Typen

`src/shared/types/supabase.ts` wird von `npm run gen:types`
(`supabase gen types typescript --linked`) erzeugt — **nie von Hand
ändern**. Nach jeder schemaändernden Migration neu generieren (gleiche
Disziplin wie die Regressions-Suite vor jedem Push).

`@supabase/supabase-js` ist als `devDependency` **exakt** auf die Version
gepinnt, die die `index.html` per CDN lädt (aktuell `2.114.0`) — nur für
die Typen, der Runtime-Client kommt aus der Brücke.
