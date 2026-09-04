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

## `KanbanBoard.tsx` + `kanbanMutations.ts` — echter Schreibpfad

`dnd-kit`-Board (ADR-0008), rendert `KANBAN_STAGES` als Spalten mit der
gemeinsamen `ContactCard` (`shared/domain/contactCard/`). Ziehen prüft
jeden Zug live gegen `decideKanbanTransition()` — ein laut
Zustandsmaschine verbotener Zug (z.B. "Nicht erschienen" vom "Neuer
Lead" aus) wird abgelehnt und als Meldung angezeigt, bevor überhaupt
etwas passiert. Ein erlaubter Zug wird ECHT gespeichert
(`useMoveKanbanCardMutation()`, `kanbanMutations.ts`):

1. `update_contact_locked` setzt `kanban_stage` (sperr-geprüft).
2. Der Board-Cache wird SOFORT (synchron, nicht erst nach einem
   Refetch) auf den bestätigten Serverstand gezogen.
3. `log_action_for_self` bucht Hauptaktion + Trichter-Marken — JEDE
   Buchung wird einzeln sofort per `getBridge().notifyActionLogged()`
   an Vanilla gemeldet (dritte Bridge-Ausnahme, `docs/adr/0002`):
   Vanilla reiht die Zeile in seinen `log`-Puffer ein, prüft Quests neu
   und rendert — damit bleibt der XP-/Energie-Header synchron, ohne
   dass React die Punkte-/Quest-Logik selbst nachbaut.

**Zwei echte Bugs einer unabhängigen Zweitmeinung** (vor dem ersten
Commit dieses Schreibpfads gefunden und behoben, siehe Git-Historie):
ein zu spätes/gebündeltes `notifyActionLogged()` hätte bei einem
Teilfehler (z.B. die zweite von zwei Buchungen schlägt fehl) bereits
erfolgreich gebuchte Punkte bis zum nächsten Vanilla-Render unsichtbar
gelassen; ein reines `invalidateQueries()` ohne sofortige
Cache-Korrektur hätte ein schnelles zweites Ziehen derselben Karte mit
einem veralteten `updated_at` in einen falschen Selbst-Konflikt laufen
lassen (CLAUDE.md, "Konflikt-Schutz bei gleichzeitiger Bearbeitung",
verlangt genau deshalb das sofortige Nachziehen). Ein dritter Fund
(`kanbanFunnel.ts`): die Trichter-Marken-Abfrage fehlte der
`user_id`-Filter, den Vanillas eigenes `log`-Array immer hat — bei
einem im laufenden Jahr umverteilten Kontakt (Gilden-Pool,
Mitarbeiter-Offboarding) hätte das eine bereits vom Vorbesitzer
geloggte Marke fälschlich für den neuen Besitzer mitgezählt.

**Bewusst NICHT Teil dieses Bausteins:**
- **"Gewonnen"/"Verloren"** — brauchen ein Verkaufs-Popup (Produkt/
  Menge bzw. Kündigung erfassen), das noch nicht existiert. Ein Zug
  dorthin wird von `kanbanMutations.ts` klar abgelehnt statt einen
  unvollständigen Verkauf zu erzeugen.
- Popup-Komponenten für die vier `KanbanPopup`-Werte (Bedarfsanalyse-
  Nachfrage, Termin-Eintragung) — aktuell werden diese Zusatzabfragen
  beim Zug übersprungen (entspricht dem in Vanilla ohnehin
  überspringbaren Pfad, kein Verhaltensbruch, nur noch nicht als
  eigene Nachfrage gebaut).
- Geteilte, schreibgeschützte Karten aus Termin-Einladungen (siehe
  `kanbanApi.ts` oben).
- **Noch NICHT in `App.tsx` verdrahtet** — kein `<Route path="kanban">`,
  also für Produktion weiterhin unerreichbar. Bewusst so belassen
  (Kanban ist der vom Nutzer explizit als "langsam und vorsichtig"
  markierte Bereich, siehe `feedback_caution_signal_suspends_autopush`
  in Claudes Erinnerung) — das Scharfschalten (Route eintragen,
  Vanilla-Seite verstecken) ist ein eigener, noch nicht gegangener
  Schritt, ebenso ein echter End-to-End-Test gegen die laufende App
  (bisher nur Typecheck/Lint/Vitest/Build + Zweitmeinungs-Review, keine
  Playwright-Prüfung mit echtem Login).

## Noch offen (nächste Schritte in Block 5)

1. Popup-Komponenten (siehe oben) + der eigentliche Verkaufs-Schreibpfad
   für "Gewonnen"/"Verloren".
2. Route in `App.tsx` + Vanilla-Kanban-Seite ausblenden (das eigentliche
   Scharfschalten) — erst nach echtem End-to-End-Test.
3. Geteilte, schreibgeschützte Karten aus Termin-Einladungen (siehe
   `kanbanApi.ts` oben).
4. `contacts`-Volltextsuche/-Paginierung (ADR-0010) und Realtime
   (ADR-0009) betreffen vor allem die künftige Kontakt-Tabelle, nicht
   das Kanban-Board selbst (dessen Datenmenge ist strukturell gedeckelt
   — persönlich, keine Massenliste).
