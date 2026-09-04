# ADR-0010 — Kontakte: Cursor-Paginierung, Volltextsuche, Virtualisierung

**Status:** akzeptiert (2026-09-04)
**Bezug:** ADR-0001 · ADR-0004 (TanStack Query) · Fahrplan-Punkt S7
("geprüft, kein aktueller Bug, aber Pflicht für Block 5")

## Kontext

`loadContactsBundle()` lädt heute alle sichtbaren Kontakte auf einmal.
Anders als beim persönlichen, gedeckelten Kanban wächst die
Kontaktliste **unbegrenzt** — gilden-/org-weit geteilt, über Jahre,
gewonnene Kunden werden nie automatisch gelöscht. Aktuell folgenlos
(vier Testkontakte), aber ein garantierter Bruch bei echten
Kundendaten (mehrere Tausend Kontakte pro Organisation).

## Entscheidung

- **Cursor-basierte Paginierung** (nicht Offset) über `useInfiniteQuery`
  — Offset-Paginierung wird unter RLS-gefilterten, sich verändernden
  Listen (neue Kontakte, Umverteilungen) inkonsistent (übersprungene
  oder doppelte Zeilen zwischen zwei Seiten).
- **Echte serverseitige Volltextsuche** über einen `tsvector`-Index auf
  Name/Telefon/E-Mail (neue, migrations-pflichtige Spalte/Index) statt
  Client-seitigem Filtern einer bereits geladenen Seite.
- **Listen-Virtualisierung** (`@tanstack/react-virtual`) für die
  Kontakttabelle, sobald reale Datenmengen das rechtfertigen.

## Konsequenzen

**Positiv:** bleibt performant unabhängig von der tatsächlichen
Kontaktzahl einer Organisation — löst den einzigen im Fahrplan bereits
benannten "garantiert wird's ein Problem"-Punkt, bevor er real auftritt.

**Negativ:** eine neue Migration (Index, ggf. eine Such-RPC) — reine
Struktur-/Indexänderung ohne Berechtigungsbezug, braucht nach CLAUDE.md-
Konvention keine unabhängige Zweitmeinung, aber den üblichen Dry-Run.
Cursor-Logik ist etwas komplexer zu implementieren als ein einfacher
`limit`/`offset`.

## Verworfene Alternativen

- **Alles weiter laden, nur Rendering optimieren** — verschiebt das
  eigentliche Problem (Netzwerk-/Speicherlast wächst weiter unbegrenzt),
  löst es nicht.
- **Offset-Paginierung** — einfacher zu bauen, aber nachweislich
  fehleranfällig unter genau den Bedingungen, die hier vorliegen
  (dynamische, RLS-gefilterte Listen mit mehreren Schreibern).
- **Client-seitiges Filtern eines großen geladenen Sets für die Suche**
  — funktioniert nur, solange "alles laden" ohnehin schon passiert;
  entfällt mit der Paginierungs-Entscheidung von selbst.
