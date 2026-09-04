# Migrations-Status: Vanilla → React

Sichtbare Tabelle, welcher Bereich in welchem Zustand ist. **Bei jeder
Sitzung zuerst hier nachsehen**, bevor an einem Bereich gearbeitet wird —
verhindert, dass in der falschen von zwei parallelen Implementierungen
gearbeitet wird.

Voller Fahrplan: Claude-Erinnerung `project_framework_migration_plan`
(Abschnitt "⭐ BLINDER REVIEW + FINALE ENTSCHEIDUNGEN"). Entscheidungen:
`docs/adr/`.

## Blöcke (Reihenfolge nach blindem Review, 2026-09-02)

| # | Block | Status | Notiz |
|---|-------|--------|-------|
| — | Vor-Block-1: Suite ins Repo (`npm test`) | ✅ erledigt (2026-09-02, `2634e6e`) | |
| — | Vor-Block-1: `data-testid` + Flakiness-Fix (S2) | ✅ erledigt (2026-09-02) | Register in `tests/README.md`; 20+ Läufe grün |
| — | Vor-Block-1: Brücke `window.__bridge` + `onAuthStateChange` (ADR-0002) | ✅ erledigt (2026-09-02, `32a8a94`) | |
| — | Vor-Block-1: Vorschau-Deployment (Cloudflare/Netlify) | offen | GitHub Pages kann es nicht — braucht Account-Aktion des Nutzers |
| 1 | Grundgerüst (React/TS/Vite/TanStack Query/RHF+Zod/ESLint-Umstieg) | ✅ erledigt (2026-09-02) | Versionen + Begründung: `docs/setup-notes.md`. Vite-Einstieg `app.html`. Keine Seite migriert. |
| 2 | Brücke (Routing/Auth/Theming/globale Muster) | ✅ erledigt (2026-09-02) | 4 Stücke: `a9169e6` / `13e7e0e` / `ba43e8c` / `b982dcb`. |
| — | Fundament-Review-Funde beheben (blinder Opus-Review) | ✅ erledigt (2026-09-03) | `e5e3865` P2/P3/P7 · `b0be43c` P1 (dist/ mitversioniert) · `e483c94` P4/P5/P6 · `fc25158` Konventionen (queryKeys u.a.). Beide in Block 3 nachgezogen: der feste `<script>`+`<link>` in index.html lädt jetzt tatsächlich (`82c9087`); `errorLog` bei org-losen Nutzern bleibt wie es ist — Einstellungen steht in `POOL_HIDDEN_NAV_PAGES`, ein Pool-Nutzer erreicht die React-Seite gar nicht, betrifft also erst eine künftige org-lose React-Seite (z.B. Organisation/Warteraum in Block 6). |
| 3 | Pilot im Wegwerf-Layout (Kandidat: Einstellungen) | ✅ erledigt (2026-09-03) | Alle 4 SETTINGS_GROUPS live in Produktion, Danger Zone bewusst Vanilla — `src/features/einstellungen/README.md`. Vanilla-Gegenstück bewusst nicht gelöscht (siehe "Fertig"-Definition unten) |
| 4 | App-Rahmen (Sidebar/Vollbreite, Design-Grundlage) | ✅ erledigt (2026-09-04, gemerged nach `main` als `b16aa46`) | Styling-Grundlage (ADR-0006) + Bridge für Level/XP/Energie + Nav-Status (ADR-0002-Nachtrag 3+4) + Sidebar/StatsHeader/AppShellPortals live verdrahtet. `.wrap{max-width:1040px}`-Schmerzpunkt behoben (Grid ohne Breitenobergrenze). **Sieben echte Bugs beim Scharfschalten gefunden+behoben** (Playwright, echte Admin-/Mitglied-Testkonten, alle 14/11 Seiten + Regressions-Suite): (1) `setPoolNavVisibility()` + 6 weitere `getElementById('nav*Btn')`-Stellen griffen auf jetzt entfernte Nav-Buttons zu → Absturz bei jedem Login, alle zu Kein-Ops/entfernt; (2) `#app`-Sichtbar-Schalten setzte `style.display='block'` (Inline-Style schlägt jede CSS-Klasse) statt `'grid'` → riesige Leerfläche über dem Inhalt; (3) StatsHeader in `.header-right` gequetscht → überlappende XP-Texte, gelöst durch volle Header-Breite (wie das ursprüngliche `.xpbar-wrap`); (4) dieselbe Quetschung nochmal mobil, responsive Stapel-Variante ergänzt; (5) `openContactPage()` pflegt die Nav-Markierung unabhängig von `showPage()` → Regressions-Suite fing das (Nav-Highlight nach Kontakt-Deep-Link-Reload), `__bridgeNotifyNav()` dort ergänzt; (6) `active`-CSS-Klasse fehlte (Sidebar nutzte nur Inline-Styles) → als reine Marker-Klasse ergänzt; (7) "Abenteuerlog"-Klick verlor die gespeicherte Kalender-Ansicht/-Tag → neue Bridge-Funktion `navigateToTagebuch()`, per Test verifiziert (Wochenansicht übersteht Wegnavigieren+Zurückklicken). Alle 44 Regressions-Prüfungen grün, 0 Konsolen-/Seitenfehler über alle getesteten Seiten/Konten/Breakpoints. Vor dem Merge nochmal komplett grün (44/44) auf dem finalen Stand `b16aa46` bestätigt. |
| 5 | Kanban + Kontakte gemeinsam — **Verhalten bit-identisch eingefroren** | offen (Verhaltens-Vertrag als Tests fertig, siehe `tests/regression_suite.mjs`; Architektur-Entscheidungen ADR-0007–0011 stehen) | gemeinsame Kontakt-Karte entsteht hier; `contacts` serverseitig paginieren + volltextsuchen (ADR-0010); Kanban als Zustandsmaschine (ADR-0007) + `dnd-kit` (ADR-0008); Realtime für Kontakte (ADR-0009, RLS-Verifikation Pflicht-Gate); Zod an RPC-Grenzen (ADR-0011) |
| 5b | B2C→B2B-Aktions-Rework | offen | **erste Priorität direkt nach 5** — eigene Änderung, getrennt von der Migration |
| 6 | Restliche Bereiche (Kalender, Statistik, Charakter/Gilde/Tagebuch, Admin zuletzt) | offen | Alt-Seiten laufen parallel weiter |

## Bereiche

| Bereich | Status | Block | Datum |
|---------|--------|-------|-------|
| Einstellungen | ✅ React (Danger Zone bewusst Vanilla) | 3 (Pilot-Kandidat) | 2026-09-03 |
| Kanban | Vanilla | 5 | — |
| Kontakte | Vanilla | 5 | — |
| Dungeons | Vanilla | 6 | — |
| Verkauf/Statistik | Vanilla | 6 | — |
| Kalender | Vanilla | 6 | — |
| Charakter | Vanilla | 6 | — |
| Gilde | Vanilla | 6 | — |
| Tagebuch | Vanilla | 6 | — |
| Admin (Produkte/Fehlerprotokoll/Notfallzugriff/Organisation/Löschanfragen) | Vanilla | 6 (zuletzt) | — |

## Feature-Stopp

~~Ab 2026-09-02 bis Ende Block 3: harter Feature-Stopp im Alt-Code~~ —
**vorbei, Block 3 ist seit 2026-09-03 fertig.** Ab jetzt (Block 4) gilt
die weiche Regel: neue Features im Alt-Code sind erlaubt, aber jede in
einem noch nicht migrierten Bereich hier als Re-Migrations-Schuld
eintragen.

| Datum | Feature | Bereich | Re-Migrations-Schuld? |
|-------|---------|---------|-----------------------|
| — | — | — | — |

## Bekannte Design-Schulden aus Wegwerf-Layouts

Bereiche, deren React-Fassung technisch fertig ist, aber die alte
Kachel-/Modal-Optik bewusst NICHT nachgebaut wurde (Pilot-Prinzip:
Infrastruktur zuerst testen, Optik erst in einer eigenen Design-Runde).
Nutzer-Rückmeldung (2026-09-04): Einstellungen sieht dadurch spürbar
schlichter aus als vorher — akzeptiert, bewusst auf später verschoben,
kein akuter Fix.

| Bereich | Was fehlt gegenüber Vanilla | Wann nachziehen |
|---------|------------------------------|------------------|
| Einstellungen | Icon-Kacheln als Startseite + Klick-öffnet-Modal-Muster (jetzt: alle Felder flach untereinander) | Eigene Design-Politur-Runde, nicht vor Block 5 |

## "Fertig"-Definition

Die Migration gilt als abgeschlossen, wenn: alle Bereiche oben auf
"Migriert" stehen, die Regressions-Suite komplett gegen die neuen
Implementierungen grün läuft, und der `<script>`-Block aus `index.html`
entfernt ist. Erst dann wird der Fahrplan-Block aus `CLAUDE.md` entfernt.
