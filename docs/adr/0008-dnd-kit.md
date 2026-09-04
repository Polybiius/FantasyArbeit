# ADR-0008 — Drag & Drop via `dnd-kit` statt zwei parallelen Bedienwegen

**Status:** akzeptiert (2026-09-04)
**Bezug:** ADR-0001 · ADR-0007 (Zustandsmaschine) · Block-5-Vorbereitung

## Kontext

Der Vanilla-Kanban hat **zwei parallele Interaktionswege** für dieselbe
Handlung: natives HTML5-Drag&Drop (Maus) und einen eigenen Verschieben-
Knopf mit Zielspalten-Menü (Touch-Fallback, weil native HTML5-DnD auf
Touch-Geräten nachweislich unzuverlässig ist, siehe CLAUDE.md-Abschnitt
"Bedienung auch ohne Ziehen"). Beide Wege müssen dauerhaft parallel
gepflegt, getestet und synchron gehalten werden.

## Entscheidung

**`dnd-kit`** wird der einzige Interaktionsweg für Ziehen im React-
Kanban — Maus, Touch und Tastatur laufen über dieselbe Bibliothek,
kein zweiter, separat gepflegter Fallback-Mechanismus mehr nötig.

## Konsequenzen

**Positiv:**
- Ein Interaktionsweg statt zwei — weniger Code, ein Satz Tests statt
  zwei parallele Test-Suiten für dieselbe Handlung.
- **Barrierefreiheit gratis mit:** `dnd-kit` unterstützt Tastatur-
  Bedienung und Screenreader-Ansagen nativ — bisher hatte weder der
  native Drag-Weg noch der Verschieben-Knopf eine Tastatur-Alternative.
- Löst das Grundproblem (unzuverlässige native HTML5-DnD-API auf
  Touch) an der Wurzel statt es dauerhaft mit einem zweiten UI zu
  umgehen.

**Negativ:** zusätzliche Abhängigkeit (~10 kB gzip) — im Rahmen der im
Migrationsplan definierten Bundle-Schwelle (>400 kB Alarm) unkritisch.
Der Vanilla-Kanban selbst bleibt bis zu seiner tatsächlichen Migration
unverändert (natives DnD + Verschieben-Knopf) — Strangler-Fig-Prinzip,
kein vorzeitiger Umbau des Alt-Codes.

## Verworfene Alternativen

- **`react-dnd`** — schwerer, sein HTML5-Backend hat dasselbe
  Touch-Problem wie die native API und bräuchte ohnehin ein separates
  Touch-Backend, löst das Grundproblem also nicht in einem Aufwasch.
- **`react-beautiful-dnd`** — nicht mehr aktiv gepflegt (offiziell
  archiviert), ungeeignet für eine Neuentwicklung.
- **Status quo (nativ + Verschieben-Menü) unverändert nach React
  portieren** — schleppt die Zwei-Wege-Komplexität dauerhaft mit,
  genau der Zustand, den dieser Schritt auflösen soll.
