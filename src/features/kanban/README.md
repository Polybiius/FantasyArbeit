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

**`resolveWonFunnelMarkers`/`resolveLostOutcome`** lösen genau diese
beiden Sonderfälle auf, sobald der tatsächliche Popup-Ausgang bekannt
ist (wurde ein Produkt eingetragen oder nicht) — siehe die Asymmetrie im
Datei-Kopfkommentar: "Gewonnen" macht die Spaltenänderung bei fehlendem
Produkt rückgängig (Revert-Pfad, seit 2026-09-05 direkt in
`kanbanMutations.ts`, nicht mehr in dieser Funktion selbst), "Verloren"
nicht.

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

## `kanbanProducts.ts` + `kanbanSaleWrite.ts` + Verkaufs-Popups — "Gewonnen"/"Verloren"

**Echter Schreibpfad für die beiden Sonderfälle, seit diesem Baustein.**
`kanbanProducts.ts` portiert den Produktkatalog-Zugriff
(`populateCategorySelect()`/`populateProductSelect()`/
`computeRecontactDate()`), `kanbanSaleWrite.ts` die eigentlichen
`sales`-Inserts + `syncWiedervorlageTask()`. `KanbanWonSaleModal.tsx`
(1:1 zu `recordWonSalesLoop()` — Produkt-Schleife, BWS-Live-Vorschau,
Nachfass-Empfehlung, Wiedervorlage) und `KanbanLostSaleModal.tsx` (1:1
zu `recordLostSale()` — nur Kategorie+Produkt) sind promise-basiert wie
ihre Vanilla-Vorbilder; `useKanbanSalePopups.tsx` hält das jeweils
offene Popup und liefert `kanbanMutations.ts` zwei
`requestWonSale()`/`requestLostSale()`-Einstiegspunkte, auf die
`useMoveKanbanCardMutation()` wartet, bevor sie mit
`resolveWonFunnelMarkers()`/`resolveLostOutcome()` (`kanbanTransitions.ts`)
weiterrechnet.

**Bewusste Abweichungen von Vanilla, beide dokumentiert an der
jeweiligen Stelle:**
- Ein Klick auf den abgedunkelten Hintergrund löst bei
  `KanbanWonSaleModal` denselben `finish()`-Pfad wie "✕" aus. Vanillas
  globaler Backdrop-Klick-Handler schließt `.loc-modal` dagegen nur
  optisch, OHNE die wartende Promise aufzulösen — für eine TanStack-
  Mutation wäre das ein für immer hängendes, das ganze Board
  sperrendes `aria-busy`, deshalb bewusst korrigiert (siehe Kommentar
  in `KanbanWonSaleModal.tsx`).
- Scheitert der NACHGELAGERTE Status-Update (`contacts.status` →
  'kunde'/'verloren') an einem echten Fehler (nicht an einem
  Sperr-Konflikt, der korrekt behandelt wird), wirft `lockedUpdate()`
  und bricht die Mutation ab — Vanilla loggt dort nur `logSilentError()`
  und macht trotzdem weiter. Sehr seltener Randfall, der `onSettled`-
  Refetch zieht den echten Serverstand in jedem Fall nach (siehe
  Kommentar in `kanbanMutations.ts`).

**Bewusst NICHT Teil dieses Bausteins:**
- Geteilte, schreibgeschützte Karten aus Termin-Einladungen (siehe
  `kanbanApi.ts` oben).
- **Noch NICHT in `App.tsx` verdrahtet** — kein `<Route path="kanban">`,
  also für Produktion weiterhin unerreichbar. Bewusst so belassen
  (Kanban ist der vom Nutzer explizit als "langsam und vorsichtig"
  markierte Bereich, siehe `feedback_caution_signal_suspends_autopush`
  in Claudes Erinnerung) — das Scharfschalten (Route eintragen,
  Vanilla-Seite verstecken) ist ein eigener, noch nicht gegangener
  Schritt, ebenso ein echter End-to-End-Test gegen die laufende App
  (bisher nur Typecheck/Lint/Vitest/Build, keine Playwright-Prüfung mit
  echtem Login).

## `KanbanExtraActionModal.tsx` + `KanbanTerminModal.tsx` + `kanbanTerminWrite.ts` — Bedarfsanalyse/Termin/Dauerbrenner

Die drei zuvor übersprungenen, aber überspringbaren Zusatzabfragen aus
`moveKanbanCard()` sind seit diesem Baustein ebenfalls gebaut:
`KanbanExtraActionModal.tsx` (1:1 zu `offerExtraAction()` — Bedarfsanalyse
bei Angebot/Zweittermin, vier Optionen bei Dauerbrenner, mit
XP/Energie-Anzeige aus dem Regelwerk) und `KanbanTerminModal.tsx` (1:1
zu `promptKanbanTermin()` — Datum/Start/Ende/Kanal, legt bei Ersttermin/
Zweittermin einen echten Kalendertermin an). `kanbanTerminWrite.ts`
portiert `computeTerminRange()`/den `termine`-Insert/
`attachKanalToLoggedAction()`; `zonedTimeToUtc()`/`fullPartsInTZ()`
wanderten dafür nach `shared/lib/timezone.ts` (mit eigenen Vitest-Tests,
inkl. Sommer-/Winterzeit-Fall). `logKanbanAction`/`logAndNotify` wurden
aus `kanbanMutations.ts` nach `kanbanActionLog.ts` gezogen, damit das
Zusatzaktions-Popup dieselbe Funktion nutzt statt einer zweiten Kopie.
`useKanbanExtraPopups.tsx` ist die Entsprechung zu
`useKanbanSalePopups.tsx` für diese beiden Popup-Arten.

## Funde einer unabhängigen Zweitmeinung (8 Finder-Agenten, 2026-09-05) — 11 von 12 behoben

Nach dem Bau der Zusatz-Popups oben wurde eine breite Zweitmeinungsrunde
eingeholt (8 parallele Agenten, je eigene Linse — Korrektheit/Effizienz/
Wiederverwendung/Vereinfachung/CLAUDE.md-Konventionen/entferntes
Verhalten/Cross-File/Zeile-für-Zeile). Alle 12 Funde noch am selben Tag
behoben bis auf Fund 7 (siehe unten, wartet strukturell auf die
Bridge-Erweiterung beim Scharfschalten). **Weiterhin ungepusht/nicht
scharfgeschaltet, kein Risiko für die echte Anwendung.**

1. **Echter Datenintegritäts-Bug, behoben:** `KanbanWonSaleModal` schrieb
   bei gesetzter Wiedervorlage nur die `tasks`-Zeile
   (`syncWiedervorlageTask()`), nicht `contacts.naechster_kontakt` —
   Vanillas `recordWonSalesLoop()` schreibt beides. Fix wie geplant:
   `KanbanWonSaleModalProps.onResolve` liefert jetzt
   `{saleRecorded, wiedervorlage}` (`WonSaleResult`), der eigentliche
   `naechster_kontakt`-Schreibvorgang (inkl. `syncWiedervorlageTask()`)
   sitzt jetzt in `kanbanMutations.ts`, direkt nach dem Stage-Set auf
   "gewonnen" — mit dem dort bereits frischen `staged.updated_at`.
   Läuft, wie per Vanilla-Vergleich verlangt, UNABHÄNGIG von
   `saleRecorded` (auch im Revert-Fall).
2. **Behoben:** `KanbanExtraActionModal.pick()` fängt einen
   fehlschlagenden `logAndNotify()`-Aufruf jetzt ab, zeigt einen
   sichtbaren Status-Text (gleiches Muster wie die Verkaufs-/Termin-
   Popups) statt das Popup einfach zu schließen, und loggt per
   `logSilentError`.
3. **Behoben:** `KanbanExtraActionModal` sperrt die Options-Buttons jetzt
   zusätzlich, solange `useOrgActionCostsQuery()` noch lädt
   (`costsLoading`).
4. **Behoben:** `resolveWonOutcome()` → `resolveWonFunnelMarkers(
   statusUpdateConflicted, funnelMarkersIfWon)` — der tote
   `!saleRecorded`-Zweig ist weg, der Revert-Pfad wird jetzt ausschließlich
   in `kanbanMutations.ts` behandelt. `kanbanTransitions.test.ts`
   entsprechend angepasst.
5. **Behoben:** `kanbanMutations.ts` iteriert jetzt über `plan.popups`
   statt über eine zweite, unabhängig gepflegte `if`-Kette.
6. **Behoben:** die drei betroffenen `lockedUpdate()`-Folgeaufrufe
   (Revert bei "Gewonnen" ohne Produkt, Status-Update bei "Gewonnen"/
   "Verloren") geben jetzt korrekt `{conflict:true}` zurück statt
   `{moved:true}`. Beim Status-Update auf "Gewonnen" werden die per
   `resolveWonFunnelMarkers()` fälligen Trichter-Marken dabei weiterhin
   ZUERST geloggt (der eigentliche Zweck von `statusUpdateConflicted`),
   erst danach wird der Konflikt gemeldet.
7. **Noch offen, bewusst:** Sobald Kanban live ist, invalidieren neue
   `sales`-Inserts aus den Verkaufs-Popups Vanillas `mySalesCache` nicht
   — die Verkaufsstatistik-Seite (noch Vanilla, Block 6) zeigt bis zum
   manuellen Neuladen veraltete Zahlen nach einem über React
   abgeschlossenen Verkauf. Braucht eine neue, dokumentierte
   `window.__bridge`-Erweiterung (ADR-0002 ist ein "schmaler, stabiler
   Vertrag" — keine Ad-hoc-Anbauten) UND eine kleine Vanilla-seitige
   Ergänzung in `index.html`, die während des aktuellen Feature-Stopps
   dort nicht nebenbei mitgezogen werden sollte. Zusammen mit Schritt 2
   unten (Route scharfschalten) angehen, nicht isoliert vorher.
8. **Behoben:** neuer `shared/hooks/useBusyGuard.ts` (Ref-basierte
   synchrone Sperre wie `useGuardedAction`, aber mit Rückgabewert/
   Fehler-Weitergabe für Inline-Status-Texte, `run(fn)` statt einer
   vorab gebundenen Aktion) — alle vier Modale (`KanbanWonSaleModal`/
   `KanbanLostSaleModal`/`KanbanTerminModal`/`KanbanExtraActionModal`)
   nutzen ihn jetzt statt eines eigenen `useState`-Busy-Flags.
9. **Behoben:** neuer `shared/hooks/usePendingPopup.ts` (generisches
   "ein Popup offen halten, per Promise auflösen") — `useKanbanSalePopups.tsx`/
   `useKanbanExtraPopups.tsx` bauen jetzt beide darauf auf, je eine
   Hook-Instanz pro Popup-Art statt einer eigenen Discriminated-Union.
10. **Behoben:** neues `shared/ui/formStyles.ts`
    (`formSelectClass`/`formInputClass`/`formLabelClass`) — die drei
    betroffenen Modale importieren jetzt von dort statt eigener Kopien.
11. **Behoben:** die drei betroffenen Modale nutzen jetzt
    `toError(err).message` statt `err instanceof Error ? err.message :
    '<fallback>'`.
12. **Behoben:** `patchContactInCache()` in zwei Funktionen aufgeteilt —
    `moveContactInCache()` (zwischen Spalten) und
    `patchContactFieldsInCache()` (Felder in derselben Spalte, z.B. der
    Status-/Wiedervorlage-Nachzug).

## Noch offen (nächste Schritte in Block 5)

1. Fund 7 oben (Vanillas `mySalesCache` nach einem React-Verkauf
   invalidieren) — zusammen mit Schritt 2 angehen, nicht isoliert.
2. Route in `App.tsx` + Vanilla-Kanban-Seite ausblenden (das eigentliche
   Scharfschalten) — erst nach echtem End-to-End-Test.
3. Geteilte, schreibgeschützte Karten aus Termin-Einladungen (siehe
   `kanbanApi.ts` oben).
4. `contacts`-Volltextsuche/-Paginierung (ADR-0010) und Realtime
   (ADR-0009) betreffen vor allem die künftige Kontakt-Tabelle, nicht
   das Kanban-Board selbst (dessen Datenmenge ist strukturell gedeckelt
   — persönlich, keine Massenliste).
