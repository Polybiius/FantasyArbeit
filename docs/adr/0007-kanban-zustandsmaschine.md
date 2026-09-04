# ADR-0007 — Kanban-Übergangslogik als explizite Zustandsmaschine

**Status:** akzeptiert (2026-09-04)
**Bezug:** ADR-0001 · Block-5-Vorbereitung (Kanban+Kontakte-Migration) ·
`tests/regression_suite.mjs` Abschnitt "Kanban-Übergangs-Vertrag"

## Kontext

`moveKanbanCard()` im Vanilla-Code ist ein gewachsenes if/else-Geflecht:
8 Spalten, pro Übergang unterschiedliche Hauptaktion, Wächter (Energie-
Budget, Herkunfts-Beschränkung bei "Nicht erschienen"), abgeleitete
Nebenwirkungen (Trichter-Marken, Popups). Die Logik steht nirgends
explizit — sie ist nur im Code selbst lesbar. Das musste vor Block 5
erst mühsam per Playwright-Tests (RPC-Interception, echter Kartenzug
im Headless-Browser) rekonstruiert werden, um überhaupt eine Messlatte
für die Migration zu haben. Genau das ist das Symptom: die Fachlogik
lebt nur im UI-Kontext, nicht als eigenständig prüfbare Einheit.

## Entscheidung

Die Übergangslogik wird als **explizite Zustandsmaschine** modelliert —
eine reine, framework-freie Funktion (kein React, kein Netzwerk,
kein DOM), die aus `(aktuelleSpalte, Zielspalte, Kontext)` eine
Entscheidung ableitet: `{erlaubt, hauptaktion, trichterMarken,
popups}`. Kontext enthält nur das, was die Entscheidung braucht
(`isKunde`, `fromTerminal` u.ä.), keine Seiteneffekte.

**Hand-geschriebene Übergangstabelle statt einer Bibliothek wie
XState.** Die Maschine ist klein (8 Zustände, keine verschachtelten
oder parallelen Zustände, kein Bedarf an einem Statechart-Visualizer
für Fachabteilungen) — eine zusätzliche, für dieses Team unbekannte
Bibliothek wäre hier Mehraufwand ohne Gegenwert.

Die React-Komponenten (Board, Verschieben-Menü) rufen ausschließlich
diese Funktion auf, um zu entscheiden, welche Zielspalten von einer
Karte aus überhaupt angeboten werden, und welche Nebenwirkungen
(Popups, RPC-Aufrufe) nach einem Zug folgen.

## Konsequenzen

**Positiv:**
- Ungültige Züge (z.B. "Nicht erschienen" von "Neuer Lead" aus) werden
  im Verschieben-Menü strukturell gar nicht erst angeboten, statt zur
  Laufzeit per `alert()` abgefangen zu werden.
- Die Fachlogik wird mit Vitest in Millisekunden erschöpfend testbar
  (alle 8×8 Kombinationen, nicht nur die von Hand ausgewählten acht) —
  der bestehende Playwright-"Kanban-Übergangs-Vertrag" schrumpft auf
  dünne Rauchtests ("kommt der UI-Klick bei der Maschine an"), die
  eigentliche Fachprüfung wandert dorthin, wo sie hingehört.
- Eine einzige, benannte Quelle der Wahrheit für "was passiert bei
  diesem Zug" — nicht mehr über mehrere `if`-Zweige verteilt.

**Negativ:** ein zusätzlicher Übersetzungsschritt beim Bauen (Vanilla-
Verhalten → Tabelle → React-Aufruf); die Tabelle muss bei jeder
späteren Regelwerk-Änderung (z.B. B2C→B2B-Rework, Block 5b) bewusst
mitgepflegt werden.

## Verworfene Alternativen

- **1:1-Portierung des if/else-Geflechts in einen React-Hook** — würde
  das eigentliche Problem (implizite Logik) unverändert mitschleppen,
  nur in neuer Syntax.
- **XState** — mächtiger als hier gebraucht (Parallelität, History-
  Zustände, eigene Tooling-Lernkurve) für eine flache 8-Zustands-
  Maschine ohne Verschachtelung.
- **Reiner Reducer ohne explizite Übergangstabelle** — bliebe implizit
  genug, dass ungültige Züge weiterhin nur zur Laufzeit auffallen.
