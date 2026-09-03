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
| 4 | App-Rahmen (Sidebar/Vollbreite, Design-Grundlage) | 🔶 läuft (2026-09-03) | Styling-Grundlage (ADR-0006) + Bridge für Level/XP/Energie + Nav-Status (ADR-0002-Nachtrag 3+4) fertig. `Sidebar.tsx`/`StatsHeader.tsx`/`navItems.ts` gebaut + isoliert per Playwright-Screenshot verifiziert (alle 3 Klassen, Pool-Modus, Nicht-Admin) — **noch NICHT in `index.html` scharf geschaltet**, aktuell totes Bundle-Gewicht (nichts importiert sie). Fehlt noch: Vollbreite-Layout-Grid (Sidebar+Content als CSS-Grid-Geschwister, kein DOM-Umbau des Vanilla-`.content`), dann das eigentliche Scharfschalten in Produktion (eigener, mit Nutzer abgestimmter Schritt — betrifft jede Seite). |
| 5 | Kanban + Kontakte gemeinsam — **Verhalten bit-identisch eingefroren** | offen | gemeinsame Kontakt-Karte entsteht hier; `contacts` serverseitig paginieren |
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

## "Fertig"-Definition

Die Migration gilt als abgeschlossen, wenn: alle Bereiche oben auf
"Migriert" stehen, die Regressions-Suite komplett gegen die neuen
Implementierungen grün läuft, und der `<script>`-Block aus `index.html`
entfernt ist. Erst dann wird der Fahrplan-Block aus `CLAUDE.md` entfernt.
