# `kanban/` — Block 5 (Kanban + Kontakte)

Block 5, siehe `docs/migration-status.md`, ADR-0007 und ADR-0008. **Noch
nicht in `App.tsx` verdrahtet** — kein `<Route path="kanban">`, also für
Produktion unerreichbar, obwohl der Code schon existiert. Bewusst so
belassen (Kanban ist der vom Nutzer explizit als "langsam und
vorsichtig" markierte Bereich, siehe
`feedback_caution_signal_suspends_autopush` in Claudes Erinnerung) —
das Scharfschalten (Route eintragen, Vanilla-Seite verstecken) ist ein
eigener, noch nicht gegangener Schritt.

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

## `kanbanLabels.ts`

1:1-Portierung von `KANBAN_STAGE_META` (Icon+Label je Spalte) aus
`index.html`. Klassen-unabhängig (nur der Seitentitel ist klassen-
abhängig, siehe `src/app/navItems.ts` `CLASS_KANBAN_LABELS`).

## `kanbanApi.ts`

`useKanbanBoardQuery()` — liest die eigene Kanban-Pipe (`contacts` mit
gesetztem `kanban_stage`, gefiltert auf `owner_id = eigene ID`, siehe
CLAUDE.md "Kanban ist strikt die eigene Vertriebspipe, kein Gilden-
Blick"), gruppiert nach Spalte. Antwort wird per Zod geprüft
(`docs/adr/0011`) — erster echter Verwender dieser ADR-Entscheidung.
**Noch nicht Teil dieses Ausbauschritts:** die geteilten, schreib-
geschützten Karten aus angenommenen Termin-Einladungen
(`.kanban-card-shared` im Vanilla-Original) — eigener Datenpfad
(`termin_invitations`), reine Lese-Ergänzung für später.

## `KanbanBoard.tsx`

`dnd-kit`-Board (ADR-0008), rendert `KANBAN_STAGES` als Spalten mit der
gemeinsamen `ContactCard` (`shared/domain/contactCard/`). Ziehen prüft
jeden Zug live gegen `decideKanbanTransition()` — ein laut
Zustandsmaschine verbotener Zug (z.B. "Nicht erschienen" vom "Neuer
Lead" aus) wird abgelehnt und als Meldung angezeigt, bevor überhaupt
etwas passiert.

**Bewusst noch KEIN Schreibzugriff — ausführliche Begründung im
Datei-Kopfkommentar von `KanbanBoard.tsx`.** Kurzfassung: ein echter
Kartenzug würde XP/Energie ändern (`log_action_for_self`), aber die
Brücke (`docs/adr/0002`) hat aktuell keinen Weg, den Vanilla-
Header/die Vanilla-Quest-Prüfung danach zur Neuberechnung zu bewegen
(`useCharacterStats()` liest nur, was Vanillas eigener `render()`-Lauf
zuletzt berechnet hat). Ein React-Kartenzug, der `action_log` direkt
beschreibt, würde die XP-/Energie-Anzeige bis zum nächsten Vanilla-
Render veraltet stehen lassen — ein echter, sichtbarer Bug. Erlaubte
Züge verschieben die Karte deshalb vorerst nur LOKAL (React-`useState`,
sichtbare "Vorschau, noch nicht gespeichert"-Kennzeichnung im Board),
ohne `contacts` zu beschreiben.

**Weil ohne Persistieren keine echten Energie-/Trichter-Daten aus
`action_log` geladen werden**, läuft die Zug-Prüfung mit einem bewusst
durchlässigen Kontext (unbegrenzte Energie, keine Trichter-Duplikate)
— sie greift trotzdem für die einzige rein herkunftsbezogene Regel
("Nicht erschienen" nur vom Ersttermin/Zweittermin aus), die von
Live-Daten unabhängig ist. Sobald der echte Schreibpfad kommt, muss
dieser Platzhalter-Kontext durch echte Werte ersetzt werden.

## Noch offen (nächste Schritte in Block 5)

1. **Die Bridge-Lücke klären** (siehe oben) — vermutlich eine kleine,
   neue Ausnahme analog zu `notifyProfilePatch` (`docs/adr/0002`), die
   Vanilla nach einem React-Kartenzug zu einem Re-Sync von
   Stats/Quests bewegt. Eigene Entscheidung, noch nicht getroffen.
2. Danach: der echte Schreibpfad selbst (`update_contact_locked` für
   `kanban_stage`, `log_action_for_self` für Hauptaktion+Trichter-
   Marken, in dieser Reihenfolge — siehe Kommentar in
   `moveKanbanCard()`, `index.html`) für die Übergänge OHNE Popup.
3. Popup-Komponenten für die vier `KanbanPopup`-Werte + die beiden
   Verkaufs-Popups (Gewonnen/Verloren, inkl. `resolveWonOutcome`/
   `resolveLostOutcome`).
4. Geteilte, schreibgeschützte Karten aus Termin-Einladungen (siehe
   `kanbanApi.ts` oben).
5. `contacts`-Volltextsuche/-Paginierung (ADR-0010) und Realtime
   (ADR-0009) betreffen vor allem die künftige Kontakt-Tabelle, nicht
   das Kanban-Board selbst (dessen Datenmenge ist strukturell gedeckelt
   — persönlich, keine Massenliste).
