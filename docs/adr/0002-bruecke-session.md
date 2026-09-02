# ADR-0002 — Koexistenz-Brücke: `window.__bridge` (Weg A)

**Status:** akzeptiert (2026-09-02)
**Bezug:** ADR-0001 · Fund S1 aus dem blinden Review

## Kontext

Während der Koexistenzphase laufen alte Vanilla-Seiten und neue
React-Seiten auf derselben `index.html` / demselben Deployment. Beide
Hälften brauchen Zugriff auf **eine** Supabase-Verbindung und **eine**
Auth-Session — zwei getrennte Verbindungen auf demselben
localStorage-`storageKey` führen zu einem Auth-Race (eine Hälfte
rotiert den Refresh-Token, die andere versucht es mit dem nun
ungültigen → Nutzer wird mitten in der Sitzung ausgeloggt).

**Problem:** der gesamte `<script>`-Block ist eine geschlossene IIFE
(`(function(){ … })();`). Nichts wird nach außen exportiert
(`grep -c "window\.\w* *=" index.html` → 0). `sb`, `session`, `profile`,
`config`, `log` u.a. sind aus einem separaten Vite-Bundle nicht
erreichbar. Zusätzlich gibt es **keinen `onAuthStateChange`-Listener** —
die Session wird genau einmal beim Init via `getSession()` gelesen, die
Alt-Hälfte erfährt von Login/Logout sonst nichts.

## Entscheidung

**Weg A — ein kontrolliertes, dokumentiertes Fenster in die IIFE.**

1. In `index.html` (noch Vanilla) genau diese Dinge auf ein einziges
   benanntes Objekt `window.__bridge` legen:
   - `sb` — der Supabase-Client (die eine Verbindung).
   - eine **nur-lese** Sicht auf `session` und `profile` (Getter oder
     eingefrorene Kopie, kein Schreibzugriff von außen).
   - ein Ereignis-/Callback-Mechanismus, über den React auf
     Session-Wechsel reagieren kann.
2. Den fehlenden `sb.auth.onAuthStateChange(...)`-Listener nachrüsten —
   er hält die Alt-Hälfte *und* `window.__bridge` bei Login/Logout/
   Token-Refresh synchron. (Eigenständiger Gewinn, auch ohne Migration.)
3. `window.__bridge` ist damit ein **schmaler, stabiler Vertrag**. Was
   dort neu durchgereicht wird, ist eine bewusste Erweiterung dieses
   ADR, kein Ad-hoc-Anbau.

React importiert **nicht** `@supabase/supabase-js` selbst, sondern nutzt
ausschließlich `window.__bridge.sb`.

## Konsequenzen

**Positiv:** genau eine Verbindung, eine Session, kein Auth-Race; der
`onAuthStateChange`-Listener schließt eine bestehende Lücke; der
Übergabepunkt ist an einer Stelle sichtbar und typisierbar
(`shared/types/`).

**Negativ:** die als "unangetastet" bezeichnete Datei wird doch
angefasst (klein: ~30 Zeilen, additiv, geringes Risiko). `window.__bridge`
wird tragend für den ganzen Umbau — Erweiterungen brauchen Disziplin
(dieses ADR fortschreiben).

**Test:** Rauchtest mit echtem Login vor und nach dem Einbau; Session
bleibt über einen simulierten Token-Refresh erhalten; Logout in der
Alt-Hälfte propagiert nach React.

## Verworfene Alternativen

- **Weg B — React öffnet seinen eigenen Supabase-Client.** Zwei
  GoTrue-Instanzen auf einem `storageKey` → intermittierender Logout
  mitten in der Sitzung, schwer zu reproduzieren, trifft den einen
  nicht-technischen Tester. Verworfen.
- **Weg B mit `persistSession:false` + `autoRefreshToken:false` am
  Zweit-Client** — technisch möglich, aber dann muss exakt eine Hälfte
  Session-Eigentümer sein und die andere ständig informieren; das ist
  Weg A mit mehr beweglichen Teilen.
- **Getrennte `storageKey`s / zwei Logins** — inakzeptabel (Nutzer
  müsste sich zweimal anmelden).

---

## Nachtrag 2026-09-03 — Auslieferung des Bundles + Härtung aus dem Fundament-Review

Der Fundament-Review (blind, Opus) hat drei Lücken gefunden, die dieses
ADR eigentlich abdecken sollte:

### 1. Wie kommt der gebaute Bundle in die Produktion? (war offen)

**Entscheidung:** `dist/` wird **mitversioniert**. `vite build` erzeugt
STABILE Namen (`dist/assets/react.js`, künftig `dist/assets/react.css`)
über `rollupOptions.output.entryFileNames`. GitHub Pages serviert `dist/`
aus dem Repo-Wurzelverzeichnis. Ab **Block 3** bekommt `index.html` einen
festen `<script type="module" src="dist/assets/react.js">` — der ändert
sich nie wieder. `npm run build` läuft vor jedem Commit, der `src/`
ändert (sobald der Tag steht).

**Verworfen für jetzt:** GitHub Actions (Build+Deploy automatisch). Das
ist der dokumentierte Zielzustand (Plan: "löst die manuelle Ablage ab"),
aber ein eigener Schritt — Pages-Quelle umstellen, Workflow, Test —, der
nicht zum "billig vor Block 3"-Rahmen passt. Interim: `dist/` committen.

**Vite-Einstieg von `dev.html` auf `app.html` umbenannt** — der
Produktions-Chunk soll nicht "dev" heißen.

### 2. Skript-Reihenfolge

`index.html` (der Vanilla-`<script>`) MUSS vor dem React-Bundle laufen,
sonst fehlt `window.__bridge` beim Mount. Als klassisches Inline-Skript
läuft es ohnehin vor jedem `type="module"`-Skript (deferred). Als
Kommentar an der Brücke in `index.html` festgehalten — den React-Tag
nicht in den `<head>` ziehen.

### 3. "Nur lesen" jetzt tatsächlich erzwungen

`window.__bridge` ist `Object.freeze`d, `getSession()`/`getProfile()`
geben `Readonly<>`. Der `onAuthStateChange`-Listener schreibt `session`
nur noch bei einer echten Session; `SIGNED_OUT` (auch cross-tab per
BroadcastChannel) führt zu `location.reload()` statt einem `null` in
einer Variablen, die der Alt-Code als non-null behandelt.

Umgesetzt in Commits `e5e3865` (Härtung) + diesem.
