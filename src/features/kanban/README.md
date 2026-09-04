# `kanban/` — Block 5 (Kanban + Kontakte)

Erster Baustein von Block 5, siehe `docs/migration-status.md` und
ADR-0007. Noch nicht in eine Seite eingebunden — dieser Ordner enthält
bisher ausschließlich die reine Übergangslogik, kein UI.

## `kanbanTransitions.ts`

Die komplette Entscheidungslogik von `moveKanbanCard()`/
`moveContactToGewonnenAndRecordSale()` aus der Vanilla-`index.html`,
übersetzt in eine reine, framework-freie Funktion (docs/adr/0007) —
kein React, kein Netzwerk, kein DOM. Gegen den bestehenden Playwright-
"Kanban-Übergangs-Vertrag" (`tests/regression_suite.mjs`) abgeglichen.

**`decideKanbanTransition(fromStage, toStage, context)`** liefert die
Entscheidung für einen Kartenzug: erlaubt/abgelehnt, Hauptaktion,
sofort zu loggende Trichter-Marken, Popups, und ob es sich um einen der
beiden Sonderfälle ("gewonnen"/"verloren") handelt, deren Ausgang von
einem Popup abhängt.

**`resolveWonOutcome`/`resolveLostOutcome`** lösen genau diese beiden
Sonderfälle auf, sobald der tatsächliche Popup-Ausgang bekannt ist
(wurde ein Produkt eingetragen oder nicht) — siehe die Asymmetrie im
Datei-Kopfkommentar: "Gewonnen" macht die Spaltenänderung bei fehlendem
Produkt rückgängig (Revert-Pfad), "Verloren" nicht.

## Testabdeckung

`kanbanTransitions.test.ts`, `npm run test:unit` (Vitest, Node-
Umgebung, kein Browser) — 21 Prüfungen, darunter eine erschöpfende
Schleife über alle 8×8 Spalten-Kombinationen. Ein echter Fund direkt
beim Schreiben: der Übergang "Ersttermin vereinbart → Zweittermin"
loggt bei einem frischen (nicht-Kunden-)Kontakt **beide** Trichter-
Marken gleichzeitig (`termin_wahrgenommen` UND `zweittermin_vereinbart`)
— ein Fall, den der Playwright-Vertrag nie beobachtet hat, weil der
dortige Testkontakt zu diesem Zeitpunkt der Kette bereits Kunde war
(isKunde-Schutz unterdrückte beide). Genau der Wert einer erschöpfenden,
reinen Prüfung unabhängig vom Reihenfolge-Zufall eines E2E-Testverlaufs.

`npm run test:unit:watch` für den Watch-Modus beim Weiterbauen.

## Noch offen (nächste Schritte in Block 5)

- Anbindung an React-Komponenten (Board, Verschieben-Menü) — noch nicht
  gebaut, dieser Ordner ist bisher reine Logik ohne Verwender.
- `dnd-kit` (ADR-0008) für die eigentliche Zieh-Interaktion.
- Die gemeinsame Kontakt-Karten-Komponente (`shared/domain/`, siehe
  ADR-0005) — unabhängig von dieser Datei, wird parallel gebraucht.
- Popup-Komponenten für die vier `KanbanPopup`-Werte + die beiden
  Verkaufs-Popups (Gewonnen/Verloren).
