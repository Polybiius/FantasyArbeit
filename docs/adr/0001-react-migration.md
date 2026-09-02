# ADR-0001 — Umstieg von Vanilla-`index.html` auf React

**Status:** akzeptiert (2026-09-02) · Baustart nach erfolgreichem Pitch freigegeben
**Kontext-Datei:** Claude-Erinnerung `project_framework_migration_plan` (voller Fahrplan + blinder Review)

## Kontext

Das Frontend war von Anfang an bewusst eine einzige `index.html` mit
eingebettetem Vanilla-JS (`<script>`-Block, Stand 2026-09-02: ~9.013
Zeilen, innerhalb der in `CLAUDE.md` dokumentierten Alarmzone
8.000–10.000). Drei der vier dort festgelegten Alarmglocken-Schwellen
sind ausgelöst:

1. `<script>`-Block in der Zeilenzone.
2. Dieselbe Karten-Darstellung über ≥ 3 `render*`-Funktionen kopiert
   (Kontakttabelle `renderContactsTableInto`, Kanban-Karte
   `renderKanbanBoard`, Kanban-Kurzvorschau `openKanbanPreview` — alle
   drei im Code verifiziert).
3. Wiederholte echte Stale-UI-Bugs durch vergessenes manuelles
   `render*()`-Nachbestellen (mehrfach in Bugfix-Durchgängen gefunden).

Der **eigentliche** technische Gewinn liegt tiefer: die zwei in
`CLAUDE.md` dokumentierten wiederkehrenden Bug-Klassen verschwinden
strukturell —

- **Stored-XSS über `innerHTML`** (182 Fundstellen, `escHtml()`/`` html`` ``
  nur an ~120 davon konsequent): JSX escaped per Default.
- **Listener-Stacking bei wiederholtem Init** (196 `addEventListener`,
  `withClickGuard` nur 15×): `useEffect`-Cleanup macht das strukturell
  unmöglich.

Das Backend (Supabase, ~102 Migrationen, stark auditierte RLS) ist von
alldem unberührt und wird **nicht angefasst** — das Risiko sitzt
ausschließlich in der sichtbaren Oberfläche.

Randbedingungen, die die Wahl prägen: der einzige Stakeholder ist kein
Programmierer und liest keinen Code; eine KI ist der alleinige
Entwickler, über viele getrennte Sitzungen ohne gemeinsames Gedächtnis;
7–8 Testnutzer, **null zahlende Kunden** (günstigster Zeitpunkt); Ziel
10–15 Nutzer pro Kundenorganisation.

## Entscheidung

Schrittweiser Umstieg auf **React + Vite + striktes TypeScript**, nach
dem Strangler-Fig-Prinzip: die alte `index.html` läuft während des
gesamten Umbaus weiter, neue Bereiche entstehen daneben, nicht an ihrer
Stelle.

- **React**, nicht Vue — Grund ist **Trainingsdaten-Dichte** (ein
  KI-Agent schreibt unbeaufsichtigt idiomatischeren, weniger
  "erfundenen" React-Code), nicht "Hireability" (bei null Kunden
  spekulativ).
- **Striktes TypeScript** (`strict: true`, `no-explicit-any` als
  Fehler) von Tag 1. Wichtig: TS ist ein Werkzeug gegen Typ-/
  Refactoring-Fehler, **kein Ersatz für die Zweitmeinungs-Disziplin** —
  es fängt keine der real dokumentierten Bug-Klassen (RLS, Races, XSS,
  Doppel-Submit, Stale-Render).
- **Kein SSR/Meta-Framework** — die App liegt komplett hinter Login.
- **Backend unangetastet.**
- Reihenfolge/Blöcke: siehe `project_framework_migration_plan`,
  Abschnitt "⭐ BLINDER REVIEW".

## Konsequenzen

**Positiv:** zwei Bug-Klassen strukturell weg; die Karten-Duplikation
wird in *eine* geteilte Komponente aufgelöst (`shared/domain/`, siehe
ADR-0005); automatischer Build+Deploy via GitHub Actions; typisierte
Verträge für Validierungsregeln (Zod); testbare reine Rechenfunktionen
(Vitest).

**Negativ / Kosten:** mehrwöchige Koexistenzphase mit doppelter
Wartungsfläche; die ~380 `innerHTML`/`addEventListener`-Stellen müssen
konvertiert werden (das ist der eigentliche Aufwand, nicht "4 Helfer
portieren"); harter Feature-Stopp im Alt-Code während Blöcke 1–3.

**Risiko:** Daten/Sicherheit ≈ null (Backend unberührt). Funktions-
Regressionen niedrig-mittel, abgefedert durch schrittweises Vorgehen +
bestehende Playwright-Suite + Vorschau-Deployments + Zweitmeinung je
Schritt. Realistischste Sorge: "dauert länger", nicht "geht kaputt".

**Rückholbarkeit:** git-Tag `demo-2026-09-02-pre-react` markiert den
letzten reinen Vanilla-Stand. Pro Block eine eigene Rückbau-Definition
(im Fahrplan).

## Verworfene Alternativen

- **Vue** — ernsthaft erwogen (leichtere Kurve, näher an der heutigen
  Struktur, konzern-unabhängig). Verworfen zugunsten Trainingsdaten-
  Dichte.
- **Nichts tun / weiter Vanilla** — die Alarmglocken sind ausgelöst, die
  Bug-Klassen wiederholen sich, die Karten-Duplikation wächst.
- **Next.js/Nuxt (SSR)** — kein SEO-/Erstladungs-Bedarf hinter Login.
- **Kanban/Kontakte zuerst migrieren** (ursprünglicher Plan) — vom
  Architektur-Review verworfen: bestverstandener *und* am dichtesten
  vernetzter Bereich zugleich, zu riskant als Pilot. Jetzt: isolierter
  Randbereich zuerst.
