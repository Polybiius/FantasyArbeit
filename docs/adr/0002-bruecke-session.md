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
