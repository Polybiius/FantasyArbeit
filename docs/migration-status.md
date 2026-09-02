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
| — | Vor-Block-1: Suite ins Repo + `data-testid` | offen | solange `index.html` noch Vanilla |
| — | Vor-Block-1: Brücke `window.__bridge` + `onAuthStateChange` (ADR-0002) | offen | ~30 Zeilen in `index.html` |
| — | Vor-Block-1: Vorschau-Deployment (Cloudflare/Netlify) | offen | GitHub Pages kann es nicht |
| 1 | Grundgerüst (React/TS/Vite/TanStack Query/RHF+Zod/ESLint-Umstieg) | offen | keine Seite migriert |
| 2 | Brücke (Routing/Auth/Theming/globale Muster/Deploy) | offen | hairiest step, isoliert |
| 3 | Pilot im Wegwerf-Layout (Kandidat: Einstellungen) | offen | testet Block 1–2 |
| 4 | App-Rahmen (Sidebar/Vollbreite, Design-Grundlage) | offen | nach dem Pilot, nicht davor (S4) |
| 5 | Kanban + Kontakte gemeinsam — **Verhalten bit-identisch eingefroren** | offen | gemeinsame Kontakt-Karte entsteht hier; `contacts` serverseitig paginieren |
| 5b | B2C→B2B-Aktions-Rework | offen | **erste Priorität direkt nach 5** — eigene Änderung, getrennt von der Migration |
| 6 | Restliche Bereiche (Kalender, Statistik, Charakter/Gilde/Tagebuch, Admin zuletzt) | offen | Alt-Seiten laufen parallel weiter |

## Bereiche

| Bereich | Status | Block | Datum |
|---------|--------|-------|-------|
| Einstellungen | Vanilla | 3 (Pilot-Kandidat) | — |
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

**Ab 2026-09-02 bis Ende Block 3: harter Feature-Stopp im Alt-Code** —
nur Bugfixes. Ab Block 4: neue Features im Alt-Code erlaubt, aber jede in
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
