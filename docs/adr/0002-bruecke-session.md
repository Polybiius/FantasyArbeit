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
STABILE Namen: `dist/assets/react.js` (Entry-JS, über
`rollupOptions.output.entryFileNames`) und `dist/assets/app.css` (aus dem
`app.html`-Entry extrahiertes CSS). GitHub Pages serviert `dist/` aus dem
Repo-Wurzelverzeichnis. Ab **Block 3** bekommt `index.html` einen festen
`<script type="module" src="dist/assets/react.js">` + einen festen
`<link rel="stylesheet" href="dist/assets/app.css">` — beide ändern sich
nie wieder. `npm run build` läuft vor jedem Commit, der `src/` ändert
(sobald die Tags stehen).

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

## Nachtrag 2026-09-03 (2) — Block 3 live geschaltet + `notifyProfilePatch()`

`index.html` lädt `dist/assets/react.js`/`dist/assets/app.css` jetzt
tatsächlich (nicht mehr nur vorbereitet) — React läuft ab sofort in der
echten Seite, für `#page-einstellungen` (Block-3-Pilot, siehe
`src/features/einstellungen/README.md`).

**Eine bewusste, schmale Ausnahme von "nur lesen":** `window.__bridge`
bekommt `notifyProfilePatch(patch: Partial<Profile>): void`. React
schreibt weiterhin nie direkt in das Vanilla-`profile`-Objekt — es liefert
nur einen bereits vom Server bestätigten Patch (nach erfolgreicher
`profiles`-Mutation), den derselbe Vanilla-Code mutiert, der `profile`
auch sonst immer mutiert (`Object.assign` innerhalb der Bridge-Definition,
nicht in React). Ohne das würde die Vanilla-Hälfte nach einer React-
Schreibaktion (z.B. `chronik_show_xp`) bis zum nächsten Neuladen einen
veralteten Wert zeigen. Löst keine Vanilla-Re-Renders aus — Seiten, die
`profile` live lesen, tun das ohnehin erst bei ihrem nächsten eigenen
Render.

Empirisch gegen die echte Seite verifiziert (Playwright, echter
Login+DB-Roundtrip, `~/.local/share/playwright-portable/
check_react_pilot_einstellungen.mjs`): Bridge eingefroren,
`notifyProfilePatch` vorhanden, Toggle- und Formular-Schreibpfad
patchen die Bridge korrekt zurück, Seitenwechsel zu einer Vanilla-Seite
funktioniert unverändert, keine Konsolen-/Seitenfehler.

## Nachtrag 2026-09-03 (3) — Stats-Snapshot für den künftigen App-Rahmen (Block 4, S4)

Der laut Fahrplan "schwerste Brückenfall": der App-Rahmen (Block 4)
enthält die Level-/XP-/Energie-Leiste, sichtbar auf JEDER Seite — auch
den noch-Vanilla-Seiten. Jede geloggte Aktion (Kanban, Kontakt-Chronik,
Verkauf, ...) läuft weiterhin im alten `<script>`-Block und muss dem
künftigen React-Kopfbereich mitteilen, dass sich die Zahlen geändert
haben.

**Entscheidung:** kein zweiter Rechenweg. Die Level-Kurve/Energie-Formel
existiert nur einmal, in Vanillas `render()` (Zeile ~4416, läuft nach
jeder der ~9 Aufrufstellen). `render()` liefert das bereits fertig
berechnete Ergebnis über `__bridgeNotifyStats(stats)` an die Bridge
durch — React bekommt nie den Rechenweg, nur den Snapshot. Ein
TypeScript-Nachbau derselben Formel wäre exakt die "zwei Quellen laufen
auseinander"-Bug-Klasse, die im Projekt bereits mehrfach real aufgetreten
ist (siehe CLAUDE.md, Abschnitt "Sonderquest-Hinweise": Warnung und
tatsächliche Löschung müssen denselben Aktivitäts-Anker benutzen).

**Neue Bridge-Mitglieder** (bewusst im `useSyncExternalStore`-Vertrag
gehalten — subscribe ohne Nutzlast + separater Snapshot-Getter, nicht
wie `onAuthChange` ein Event mit Payload):
- `getCharacterStats(): Readonly<CharacterStats> | null` — `null` vor
  dem ersten `render()`-Lauf (z.B. während des Logins).
- `onStatsChange(fn: () => void): () => void` — feuert nach JEDEM
  `render()`-Aufruf, deckt damit alle Aufrufstellen automatisch ab, ohne
  sie einzeln anzufassen.

React-seitig: `useCharacterStats()` (`src/shared/hooks/`), ein
`useSyncExternalStore`-Hook nach demselben Muster wie
`useCharacterClass()`. Verwendet wird das erst mit den echten
App-Rahmen-Komponenten (Block 4, Kopfbereich).

Empirisch gegen die echte, laufende Seite verifiziert (Playwright, echter
Login): `getCharacterStats()` liefert direkt nach dem Login einen
Snapshot, der exakt mit der im DOM angezeigten Levelzahl übereinstimmt
(`{level:17, xpIntoLevel:316, xpNeededForLevel:473, totalXp:3299,
energyUsed:0, energyMax:20, energyRemaining:20}` gegen `#levelNum` →
`17`). Bundle-Größe unverändert (die neuen Dateien werden noch von
nichts importiert, Tree-Shaking entfernt sie aus dem Produktions-Build).
Beide Regressions-Suiten weiterhin grün.

## Nachtrag 2026-09-03 (4) — Nav-Status + erste echte Sidebar/Header-Komponenten

Direkte Fortsetzung von Nachtrag (3): die React-Sidebar braucht zwei
weitere Informationen, die NUR Vanilla korrekt kennt, weil sie über eine
reine Feldabfrage hinausgehen — welche Seite gerade WIRKLICH aktiv ist
(nach allen Weiterleitungsregeln in `showPage()`: ungültiger Hash → Pool-
Zustand → fehlende Admin-/Gildengründer-Rechte, in dieser Reihenfolge)
und ob die eingeloggte Person mindestens eine Gilde gegründet hat
(`myFoundedGuildIds`, eine eigene DB-Abfrage, steht nicht in `profile`).

**Bewusste Grenze, um die Bridge nicht ausufern zu lassen:** Admin-Rolle
(`profile.role`) und Pool-Zustand (`profile.org_id`) werden NICHT über
die Bridge dupliziert — das sind einfache, stabile Feldabfragen auf dem
ohnehin schon lesbaren `profile`-Objekt, kein eigener Rechenweg mit
Redundanz-Risiko. Nur die zwei oben genannten, echt abgeleiteten Werte
bekommen einen eigenen Bridge-Kanal:

- `getNavState(): Readonly<NavState>` — `{activePage, isGuildFounder}`,
  immer verfügbar (sinnvoller Default schon vor dem ersten Login).
- `onNavChange(fn: () => void): () => void` — feuert nach jedem
  `showPage()`-Aufruf (via `__bridgeNotifyNav({activePage})`) und nach
  jedem Neuladen des Gildengründer-Status
  (`__bridgeNotifyNav({isGuildFounder})` in `loadMyFoundedGuilds()`).

React-seitig: `useNavState()` (gleiches `useSyncExternalStore`-Muster wie
`useCharacterStats()`), `useProfileFlags()` (liest `isPool`/`isAdmin`
direkt aus `getProfile()`, reagiert wie `useCharacterClass()` auf
Login/Logout — ein Live-Wechsel mitten in der Sitzung braucht bewusst
weiterhin ein Neuladen, akzeptierte Einschränkung wie dort).

**Erste echte App-Rahmen-Komponenten:** `src/app/navItems.ts` (1:1-
Portierung der Nav-Struktur aus `index.html` als reine Daten — Icons,
klassenabhängige Label-Tabellen, vier unabhängige Sichtbarkeitsregeln,
keine Logik), `src/app/Sidebar.tsx`, `src/app/StatsHeader.tsx`. Navigation
läuft über echte `<a href="#seite">`, kein `onClick`/`location.hash=` —
Rechtsklick/neuer Tab/Bookmark funktionieren unverändert (ADR-0003),
Vanillas `showPage()` bleibt über den bestehenden `hashchange`-Listener
die einzige Instanz, die eine Seite tatsächlich zeigt/verbietet.

**Noch NICHT in `index.html` scharf geschaltet** — isoliert per
Wegwerf-Vorschau (gemockte `window.__bridge`, kein echter Login nötig)
gebaut und per Playwright-Screenshot in allen 3 Klassenfarben + Pool-
Zustand + Nicht-Admin/Nicht-Gildengründer verifiziert: korrekte
klassenabhängige Labels, korrekte aktive Markierung, korrekte
Sichtbarkeits-Kombination je Zustand (Pool zeigt nur Organisation +
weiterhin die von Pool unabhängigen Admin-/Gildengründer-Punkte — exakt
das mitunter überraschende, aber echte Vanilla-Verhalten, keine
Vereinfachung). Bundle-Größe der Produktion unverändert (JS), `app.css`
wuchs um die jetzt im Quellcode vorhandenen, aber noch von nichts
importierten Tailwind-Klassen (Tailwind scannt Text, nicht den
Modul-Graphen — tote, aber harmlose zusätzliche Regeln, verschwinden
automatisch wieder, sobald diese Dateien sich ändern oder entfernt
werden). Beide Regressions-Suiten weiterhin grün.

**Lehre aus dem Bau der Wegwerf-Vorschau:** ein State-getriebener
`window.__bridge`-Mock (`useState`+Neuzuweisung im Render-Körper) löste
eine `useSyncExternalStore`-Endlosschleife aus ("getSnapshot should be
cached") — jeder Getter muss bei wiederholtem Aufruf dieselbe
Objekt-Referenz liefern, ein neues Objektliteral pro Aufruf reicht schon.
Die echte Vanilla-Bridge macht das schon richtig (`navState`/
`characterStats` sind stabile Modul-Variablen); der Mock wurde auf
synchrones Setzen vor dem Mount (URL-Parameter + echtes Neuladen statt
React-State) umgestellt, entspricht damit auch eher der echten
Produktions-Reihenfolge.
