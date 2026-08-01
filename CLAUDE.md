# Projekt: Vertriebs-Quest (Gamifiziertes CRM für Vertriebsteams)

Dieses Dokument ist der Gedächtnis-Ersatz für eine lange Chat-Konversation, in der
dieses Projekt von Grund auf entstanden ist. Lies es vollständig, bevor du an
irgendetwas im Repo arbeitest.

## Die Grundidee

Der Nutzer (Vertrieb, aktuell Versicherungsprodukte — Lebens-, Kranken- und
Sachversicherungen — an akademische Heilberufe/Krankenhäuser) wollte die
Motivationsmechanik von Rollenspielen (XP, Level, Quests, Charakterklassen) auf
echten Vertriebsalltag übertragen — UND daraus organisch ein vollwertiges,
generalisierbares CRM wachsen lassen, das später an andere Vertriebsorganisationen
verkauft werden kann (jede Organisation bekommt ihr eigenes Regelwerk).

**Wichtigster Leitsatz der gesamten Architektur, von Anfang an durchgehalten:**
Alles, was sich zwischen Organisationen unterscheiden könnte (Aktionen, XP-Werte,
Skills, Level-Kurve, Quests, Kontaktrollen, Ortstypen), lebt als **Daten im
Regelwerk (`rule_configs.config`, JSONB)**, nicht hart im Code. Neue Kunden
(andere Vertriebsorganisationen) sollen sich per Konfiguration anpassen lassen,
nicht per Code-Änderung.

## Tech-Stack

- **Frontend**: eine einzige `index.html`-Datei. Vanilla JavaScript (kein Framework,
  bewusst so gehalten — der Nutzer ist kein Entwickler und hat das bisher komplett
  ohne Claude Code gebaut, nur über den Browser-basierten Claude-Chat mit
  Copy-Paste in GitHubs Web-Upload). Single-Page-Application-Prinzip: alle "Seiten"
  sind `<div class="page">`-Blöcke, die per `display:none`/`block` umgeschaltet
  werden (`showPage()`), plus URL-Hash-Persistenz.
- **Backend**: Supabase (Postgres + Auth + Storage + automatische REST-API via
  PostgREST). Kein eigener Server, keine Edge Functions bisher.
- **Karte**: Leaflet.js + OpenStreetMap-Kacheln (CartoDB dark-Theme), Geocoding
  über die öffentliche Nominatim-API (kostenlos, kein Key).
- **Hosting**: GitHub Pages, Repo ist öffentlich (nötig für den kostenlosen
  GitHub-Pages-Plan; unbedenklich, weil der Supabase-Key im Code ein bewusst
  öffentlicher "publishable key" ist, abgesichert durch RLS, nicht durch
  Geheimhaltung).
- **Codequalität**: ESLint (seit 2026-07-31, `eslint.config.js` +
  `eslint-plugin-html`, prüft direkt den `<script>`-Block in `index.html`,
  keine Datei-Aufteilung nötig). Node.js liegt dafür portabel unter
  `~/.local/share/nodejs-portable` (kein Systemeingriff, kein `sudo`
  gebraucht), PATH-Eintrag dafür in `~/.bashrc`. `npm run lint` zum manuellen
  Prüfen, VS-Code-Erweiterung "ESLint" zeigt Warnungen live beim Tippen an.
  Absichtlich schlanker Regelsatz bisher (nur `no-unused-vars`/`no-undef`) —
  erst bei echtem Bedarf erweitern, nicht vorab.
- **Bisheriger Workflow**: Der Nutzer hat NICHT lokal mit Git gearbeitet, sondern
  jede neue `index.html`-Version über den GitHub-Web-Upload hochgeladen, und jeden
  SQL-Patch manuell im Supabase SQL-Editor ausgeführt. Das ändert sich jetzt mit
  Claude Code: Commits/Pushes laufen seit 2026-07-31 automatisch durch Claude
  Code (ein GitHub Personal Access Token liegt im `credential.helper store` des
  Nutzers, dadurch kein `ksshaskpass`-Problem mehr). **SQL-Patches laufen
  weiterhin manuell** über den Supabase SQL-Editor beim Nutzer — dafür hat
  Claude Code keinen Zugriff/Zugangsdaten.

## Datenbank — aktueller Stand (Annahme: Patch 1–23 sind alle eingespielt)

**Wenn das nicht stimmt, sofort korrigieren, bevor irgendetwas gebaut wird** — sonst
versucht Claude Code eventuell, Dinge doppelt anzulegen oder Migrationen in falscher
Reihenfolge zu bauen.

Alle SQL-Patches liegen im Ordner `sql/` (chronologisch benannt, `schema.sql` +
`patch.sql` sind die ursprüngliche Basis, danach `patch2_...` bis `patch23_...`).
Sie wurden bisher **einzeln, nacheinander, manuell** im Supabase SQL-Editor
ausgeführt — nicht über eine Migrations-Toolchain. `PATCH_LOG.md` listet die
genaue Reihenfolge und was jeder Patch bewirkt.

Seit Patch 17/17b gibt es außerdem: eine zentrale `error_log`-Tabelle (jeder
fehlgeschlagene Datenbank-Aufruf im Frontend wird dort protokolliert, sichtbar
nur für Admins im neuen Reiter "Fehlerprotokoll"), sowie Indizes auf den
bisher unindizierten Fremdschlüssel-Spalten von `contacts`, `locations`,
`sales` und `profiles` (Postgres indiziert Fremdschlüssel nicht automatisch).
Im Frontend-Code gibt es dafür zwei zentrale Helferfunktionen ganz oben im
Skript: `reportError(context, error, statusEl)` für Fehler, die der Nutzer
direkt sehen soll (Formular-Speichern etc.), und `logSilentError(context,
error)` für Hintergrund-Ladevorgänge, wo ein alert()-Popup nur stören würde.
**Neuer Code, der mit der Datenbank spricht, sollte konsequent eine der beiden
Funktionen benutzen statt eigene Fehlerbehandlung zu erfinden.**

### Kern-Tabellen

- `organizations` — eine Zeile pro Kunde/Vertriebsorganisation, inkl. `timezone`
  (Vorkehrung für internationale Skalierung, aktuell fix `Europe/Berlin`).
- `profiles` — ein Nutzer-Account, 1:1 mit Supabase Auth. Felder u.a.
  `character_class` ('hexer'|'krieger'|'schuetze'), `role` ('admin'|'member'),
  `total_xp`/`level` (**Cache!** — wird bei jedem Render clientseitig
  nachgezogen, damit Gildenmitglieder das Level sehen können, ohne Zugriff auf
  fremde private Logs zu brauchen).
- `rule_configs` — **das Herzstück der Templating-Fähigkeit**. Ein JSONB-Blob
  pro Organisation mit: `actions` (XP-Aktionen), `skills`, `levelBase`/
  `levelExponent` (Level-Kurve: `XP für Level L = levelBase * L^levelExponent`),
  `recurringQuests`, `questChains`, `items`, `locationTypes`, `contactRoles`,
  `contactsVisibility` ('private'|'shared').
- `action_log` — jede geloggte Aktion. XP/Level werden **niemals gespeichert**,
  sondern bei jedem Render aus diesem Log neu berechnet (`computeTotals()`).
  Hat optionale Verknüpfungen zu `location_id` und `contact_id`.
- `locations` ("Dungeons") — Accounts/Betriebe. Hat `owner_id` (Pool-Mechanismus:
  leer = "im Pool", sonst einem Mitarbeiter zugewiesen — bei Neuzuweisung
  wandern per Trigger automatisch alle zugehörigen Kontakte mit). `type`
  generisch (z.B. 'krankenhaus', 'niederlassung'), Anzeige/Icon kommt aus
  `rule_configs.locationTypes`. Seit Patch 14 darf JEDES Team-Mitglied neue
  Locations anlegen (nicht mehr nur Admin), Umverteilen bleibt Admin-exklusiv.
- `contacts` — das CRM-Herzstück. Vorname/Nachname getrennt (technisch: `name`
  ist eine **generierte Spalte** aus beiden, damit alter Code weiterläuft).
  Felder: Geburtsdatum, Telefon, E-Mail, Wohnort (Straße/Ort, getrennt vom
  Betriebsort!), `role` (Berufsstatus, 7 Werte: Assistenzarzt, Facharzt,
  Oberarzt, Oberarzt mit leitender Funktion, Chefarzt, Niedergelassen,
  Freiberuflich), Bedarfsanalyse als **zwei** Felder (`bedarf_ist`/
  `bedarf_wunsch`), `status` (kalt/warm/kunde/verloren — reines Tracking,
  keine Rückwirkung auf XP), `naechster_kontakt` (Wiedervorlage-Datum),
  `owner_id` (folgt automatisch dem Location-Owner, siehe Trigger oben).
  Seit Patch 18/19: `kanban_stage` (nullable, 8 feste Werte, siehe Abschnitt
  "Kanban" unten) — die Spalte, in der der Kontakt im Kanban-Board liegt.
  **NULL = kein Kanban-Kontakt, taucht im Board gar nicht auf.** Bewusst
  *nicht* automatisch für jeden Kontakt gesetzt, nur weil er in der
  Datenbank existiert — Patch 18 hatte das fälschlicherweise per Default
  gemacht, Patch 19 korrigiert das (siehe PATCH_LOG.md).
  Sichtbarkeit konfigurierbar über `contacts_shared_for_org()` (liest
  `rule_configs.contactsVisibility`).
- `products` — **Produktkatalog** (seit Patch 23), ersetzt den früheren
  Freitext-Dummy in `sales.produkt`. `org_id`, `key` (stabil, aus dem Namen
  abgeleitet — für spätere Questline-Verknüpfung), `name`, `category`,
  `subcategory` (optional), `active`. Kategorien/Unterkategorien sind bewusst
  einfache Textfelder, keine eigene Tabelle (Rule of Three: erst bei
  echtem Mehrbedarf abstrahieren). Pflege nur Admins (später ggf. je
  Organisation, aber weiterhin admin-exklusiv). **Nie löschbar, nur
  deaktivierbar** (`active=false`) — gleiches Prinzip wie sonst im Projekt,
  historische Verkäufe zeigen weiterhin auf das damalige Produkt. Verwaltung
  über den neuen Reiter "Produkte" (nur für Admins sichtbar), Zuordnung
  Kategorie→Produkt in den Verkaufs-Popups über `populateCategorySelect()`/
  `populateProductSelect()` in `index.html`.
- `sales` — echte Verkaufshistorie (nicht nur ein Feld!): mehrere Produkte pro
  Kontakt über die Zeit, `status` ('gewonnen'/'verloren'), `menge` (seit
  Patch 21, Integer, Default 1). Seit Patch 23: `product_id` (Verweis auf
  `products`, Pflicht — kein Freitext mehr) statt der früheren `produkt`-
  Textspalte, dazu `bewertungssumme` und `laufender_beitrag` (beide Zahlen,
  werden beim Verkaufen erfasst, aber in Phase 1 **noch nicht** zu Provision/
  Bewertungspunkten verrechnet — kommt als eigener, späterer Patch, siehe
  "Bewusst aufgeschobene Ideen"), `vertragsbeginn` (Datum, Pflichtfeld beim
  Gewinnen, kann in der Zukunft liegen — z.B. Kündigungsfristen bei PKV-
  Wechseln) und `vertragsende` (Datum, nullable — leer = Vertrag läuft noch,
  gesetzt = gekündigt/ausgelaufen; **nicht** dasselbe wie `status='verloren'`,
  das bleibt ein eigener Fall für nie zustande gekommene Abschlüsse). Ein
  Abschluss kann mehrere Zeilen erzeugen (ein Insert pro Produkt inkl.
  eigener Menge), siehe Kanban-Abschnitt unten (`recordWonSalesLoop()`).
  Details zur Verkaufshistorie-Anzeige: siehe eigener Abschnitt
  "Produktkatalog & Verkaufshistorie" unten.
- `journal_entries` — Tagebuch, **fünf feste Fragen** pro Tag (siehe unten),
  strikt privat (auch Admins sehen fremde Einträge NICHT — bewusst die einzige
  Tabelle ohne Admin-Ausnahme).
- `journal_entry_mentions` — @mention-Markierungen aus dem Tagebuch (seit Patch
  16, ersetzt das frühere einzelne `tagged_contact_id`-Feld): beliebig viele
  Kontakt-Markierungen pro Tagebuchtag, rein persönlich, **keine
  CRM-Statistik**, genauso privat wie `journal_entries` selbst. Angezeigt wird
  das nicht im Tagebuch, sondern im Kontakt-Detail als eigener Reiter
  "Tagebucheintrag" (Liste der Tage, an denen der Kontakt erwähnt wurde) —
  bewusst **nicht löschbar**, ein Tagebucheintrag bleibt stehen wie geschrieben.
- `journal_photos` — ein Foto pro Tag, privater Storage-Bucket. Hat schon jetzt
  `transformed_path`/`transform_status`, aktuell ungenutzt — Platzhalter für
  eine spätere KI-Bildumwandlung (siehe "Bewusst aufgeschobene Ideen" unten).
- `user_inventory`, `guilds`, `guild_members`, `friends` — siehe `PATCH_LOG.md`
  für Details, Funktionsweise ist selbsterklärend über die Namen.
  **Item-Effekt-System** (seit Patch 3, bis zu dieser Session ungenutzt):
  Items leben in `rule_configs.config.items` (Katalog, aktuell nur
  `mana_trank`), `user_inventory` hält nur `item_key`+`quantity` pro Nutzer.
  `useItem()` in `index.html` liest `def.effect` und wertet ihn aus —
  `full_energy_refill` loggt einen `action_log`-Eintrag mit `energy:
  -energyUsedToday()` (xp 0, kein Skill), was die Tagesenergie exakt auf
  Maximum zurücksetzt, ohne einen separaten "aktuelle Energie"-Zustand zu
  pflegen (bleibt komplett aus dem Log abgeleitet, wie der Rest des
  Energie-Systems). Neue Item-Effekte brauchen nur einen neuen `effect`-Wert
  im Katalog + einen neuen `if`-Zweig in `useItem()`, keine Schema-Änderung.
  **Täglicher Gratis-Manatrank** (seit dieser Session, `grantDailyManatrank()`
  in `index.html`, aufgerufen in `enterApp()` — läuft für Handy und Desktop
  identisch, da beide dieselbe Initialisierung durchlaufen): jeden
  Kalendertag kommt ein Manatrank zum `user_inventory`-Bestand dazu, **stapelt
  sich** (kein Deckel, kein Wegnehmen von Ungenutztem). Hängt bewusst am
  Kalendertag, nicht am Login-Moment — genau wie Energie-Reset und Tagebuch
  (ein erster Versuch hing an `user_inventory.updated_at` bzw. am
  Login-Zeitpunkt und wurde vom Nutzer zu Recht zurückgewiesen). Dafür ein
  eigener Log-Marker (`action_key: 'manatrank_taeglich'`, xp 0, energy 0,
  `meta.qty`) statt `updated_at` — Letzteres wird beim Trinken selbst auch
  verändert und wäre als "letzte Gutschrift"-Marker mehrdeutig gewesen. Beim
  nächsten Öffnen werden auch mehrere ausgelassene Tage auf einmal nachgeholt
  (`daysBetweenKeys()` zwischen dem letzten Marker-Tag und heute) — nicht nur
  ein einzelner Tages-Ausgleich. `useItem()`/`full_energy_refill` (Trinken,
  füllt die Tagesenergie komplett auf) ist davon unabhängig und unverändert.
- `error_log` — zentrales Fehlerprotokoll (seit Patch 17). Jeder fehlgeschlagene
  Datenbank-Aufruf im Frontend landet hier (`org_id`, `user_id`, `context`,
  `message`, `created_at`). Insert darf jeder für die eigene Organisation,
  Lesen nur Admins — sichtbar im neuen Reiter "Fehlerprotokoll". Bewusst kein
  Update/Delete: ein Protokoll wird nicht nachträglich verändert.

### Sicherheitsmodell (RLS), zum Verständnis

Fast jede Tabelle hat `org_id` und eine RLS-Policy, die auf eine Hilfsfunktion
`public.current_org_id()` zurückgreift (liest `org_id` aus `profiles` für
`auth.uid()`). Für Admin-Prüfung gibt's `public.is_admin()`. Für Kontakt-Sichtbarkeit
`public.contacts_shared_for_org()` (liest die Regelwerk-Einstellung).
**Prinzip, das durchgehend gilt:** Sichtbarkeit ist meist konfigurierbar
(privat vs. team-weit geteilt), Schreibrechte sind enger (Eigentümer + Admin).

## Level-/XP-System (wichtig für jede Regelwerk-Änderung)

- Aktuelle Kurve: `levelBase = 4.7`, `levelExponent = 1.5` → `XP für Level L =
  4.7 * L^1.5`. Ziel: bei durchschnittlicher Vertriebsleistung soll Level 100
  nach **10 Jahren** erreicht werden (200 Arbeitstage/Jahr angenommen).
- Diese Kalibrierung wurde mehrfach neu gerechnet, wenn sich das Regelwerk
  änderte (z.B. als Quest-Boni dazukamen, als "Ansprache" vereinheitlicht
  wurde, als Konversions-Bonus/-Malus eingeführt wurde). **Jede substanzielle
  Änderung an XP-Werten oder Quest-Häufigkeit sollte die Kurve neu
  kalibrieren** — Methode: wöchentliches XP-Budget aus angenommener
  Aktivität hochrechnen, `levelBase` so wählen, dass die Summe aller
  Level-Schwellen 1–99 dem 10-Jahres-Gesamt-XP entspricht.
- Ein neuer Mechanismus (Patch 12): **Konversions-Bonus/-Malus** — Termin
  wahrgenommen gibt zusätzlich +5 XP (Bestätigung guter Ansprache), Termin
  NICHT wahrgenommen gibt −2 XP. **Dieser Mechanismus hängt an einem Kanban,
  das noch nicht gebaut ist** (siehe unten) — jemand muss aktiv markieren,
  ob ein Termin stattfand.
- Kalibrierung basiert auf einer **geschätzten** 80%-Erscheinquote — vorläufig,
  mit echten Nutzungsdaten später nachjustierbar.

## Sigil der Fähigkeiten (Skill-Radar auf der Charakter-Seite)

Bewusst NICHT auf 100% skaliert nach eigenem Bestwert (das würde den Radar
immer fast voll aussehen lassen). Stattdessen: feste Obergrenze, abgeleitet aus
dem GESAMTEN 10-Jahres-Ziel (`maxLevelTotalXp() * 0.4`), plus eine harte
88%-Kappung (`VISUAL_CAP`), damit nie ein Skill den Rand komplett erreicht —
soll sichtbare Stärken/Schwächen zeigen, kein "fertig"-Gefühl vermitteln.

## Charakterklassen

Drei Klassen: Hexer (blau-violett), Krieger (rot/Ember), Schütze (grün/Gold).
Klassenwahl ist **einmalig, dauerhaft** (kein Umskillen), aber ein Admin kann
über einen versteckten Klassenschalter im Header testweise wechseln.
Farbthema ist NICHT nur ein Akzent, sondern durchdringt die ganze Optik
(Hintergrund-Glow, Panels, Rahmen — siehe `CLASS_THEMES` in `index.html`).
Regelwerk ist über alle Klassen hinweg **identisch** (nur Optik/Begriffe
unterscheiden sich) — bewusste Design-Entscheidung, keine Einschränkung.

Klassenabhängige Begriffe für dieselbe Funktion:
| Funktion | Hexer | Krieger | Schütze |
|---|---|---|---|
| Gilde | Orden | Legion | Bund |
| Mitglied hinzufügen | Arkanisten hinzufügen | Legionäre hinzufügen | Bundesbrüder hinzufügen |
| Kundendatenbank | Arkanes Register | Kriegsarchiv | Jägerchronik |
| Kanban | Questpfad | Gildenbrett | Feldzug |

## Kanban (Questpfad / Gildenbrett / Feldzug), seit Patch 18

Acht feste Spalten (Reihenfolge in `KANBAN_STAGES` in `index.html`): Neuer Lead
→ Ersttermin vereinbart → Nicht erschienen / Angebot versendet → Zweittermin →
Gewonnen / Verloren → Dauerbrenner. **Bewusst fest im Code**, nicht
konfigurierbar (Rule of Three — erst wenn eine zweite Organisation ansteht,
lohnt sich die Abstraktion; vorher würden wir nur raten).

**Optik als Wegkarte statt Büro-Spalten** (bewusste Design-Entscheidung, weil
seitliches Scrollen zum "Questpfad"-Namen passt, wenn es sich wie eine Route
anfühlt statt wie ein CRM-Board): Wegpunkte mit Icon-Marker pro Stufe, im
Zickzack versetzt (`nth-child(4n+1)`/`nth-child(4n+3)` in der CSS), verbunden
durch Pfeile (`.kanban-path-arrow`). Responsive über eine einzige Media
Query bei 760px: Desktop bleibt die waagerechte, scrollbare Route; auf dem
Handy dreht sich dieselbe Route senkrecht (Spalten stapeln sich, Zickzack
wird zu links/rechts-Versatz, Pfeile drehen sich 90°) — man scrollt dann
nach unten statt seitlich zu wischen. Drag & Drop, `moveKanbanCard()` usw.
sind davon komplett unberührt, das ist reine CSS/HTML-Optik.

Jede Karte ist ein Kontakt. Die Spalte selbst wird zwar aus dem Aktions-Log
abgeleitet (Philosophie: "Kanban wird nicht gepflegt, sondern abgeleitet"),
aber weil zwei Spalten (Angebot versendet, Zweittermin) dieselbe Aktion
(`pitch`) loggen, reicht das Log allein nicht zur Unterscheidung — deshalb
gibt's zusätzlich `contacts.kanban_stage` als expliziten Spalten-Zeiger, der
beim Ziehen direkt mitgesetzt wird. Ziehen ist die Bedienoberfläche, das Log
bleibt die Wahrheitsquelle für XP/Quests/Statistik.

**Wichtig (Lehre aus Patch 18/19-Bug):** in der Datenbank zu stehen bedeutet
NICHT automatisch, im Kanban zu sein. `kanban_stage` ist nullable und wird nur
über einen der bewusst dafür gebauten Wege gesetzt — "+ Neuer Lead" im Board,
"Termin vereinbart" am Dungeon, oder manuell im Kontaktformular
(`contactKanbanStageSelect`, Default "– Nicht im Kanban –"). Ein Kontakt mit
`kanban_stage = null` taucht im Board schlicht nirgends auf. Beim Rendern
(`renderKanbanBoard()`) werden Kontakte ohne gesetzte Stufe deshalb bewusst
übersprungen, nicht in "Neuer Lead" einsortiert.

**Bedienung auch ohne Ziehen (seit dieser Session):** die native HTML5-Drag&Drop-
API (`draggable`, `dragstart`/`dragover`/`drop`) ist eine reine Maus-API und
feuert auf Touch-Geräten nicht zuverlässig — auf dem Handy ging Ziehen im
Kanban praktisch nicht. Jede Karte hat deshalb zusätzlich ein ↕-Symbol
(`.kc-move-btn`), das `openKanbanMoveMenu()` öffnet: ein Menü mit allen
Zielspalten, Antippen ruft dieselbe `moveKanbanCard()`-Logik auf wie das
Ziehen (gleiche Validierung, gleiches XP-Logging). Ziehen per Maus funktioniert
weiterhin zusätzlich, nichts wurde entfernt.

**Spaltenübergänge und was sie auslösen** (Logik in `moveKanbanCard()`):
- → Ersttermin vereinbart: Aktion `termin_vereinbart`. Auch erreichbar per
  Klick auf "Termin vereinbart" an einem Dungeon (fragt dann nach
  Vorname/Nachname und legt den Kontakt live an, statt anonym zu loggen).
- → Nicht erschienen: **nur von Ersttermin vereinbart aus**, sonst Abbruch.
  Loggt `termin_nicht_wahrgenommen` (−2 XP, der lange geplante
  Konversions-Malus).
- → Angebot versendet / Zweittermin: Aktion `pitch`, danach optionales Popup
  "Bedarfsanalyse geführt?" (Kann übersprungen werden).
- → Gewonnen: Aktion `abschluss`, danach Popup `recordWonSalesLoop()` —
  Produkt + Menge eintragen, "+ Produkt hinzufügen" für beliebig viele weitere
  Produkte desselben Abschlusses, "Fertig" zum Abschließen (je ein Insert in
  `sales` pro Produkt, seit Patch 21 inkl. `menge`), `contacts.status` →
  'kunde'. Dieselbe Wirkung (Spalte, Verkaufs-Popup, Status) hat auch der
  "Abschluss"-Button im normalen Kontakt-Aktionsdialog (`logActionForContact`)
  — beide Wege laufen seit dieser Session über die gemeinsame Funktion
  `recordWinOrLoss()`, vorher fehlte das dort komplett (Bug: Abschluss über
  den Kontaktdialog loggte XP, sprang aber nicht nach Gewonnen).
- → Verloren: **keine XP-Aktion** ("Verloren ist verloren"), nur einfache
  Produkt-Abfrage (kein Mengenfeld, keine Mehrfach-Schleife — bewusst so
  belassen, "wie viel verkauft" ergibt bei einem verlorenen Deal keinen Sinn)
  → Eintrag in `sales` (verloren), `contacts.status` → 'verloren'.
- Von Gewonnen/Verloren zurück zu Ersttermin/Angebot versendet/Zweittermin:
  zählt als Kundenausbau, loggt `kundenausbau` statt der sonst üblichen
  Aktion für diese Spalte.
- → Dauerbrenner: kein Zwang — Popup mit vier optionalen Aktionen
  (Bedarfsanalyse, Angebot/Pitch, Termin wahrgenommen, Empfehlung erhalten)
  oder einfach schließen. Gedacht für Kontakte, bei denen es aus privaten
  Gründen beim Kunden gerade nicht weitergeht, aber vermutlich wieder wird.
- → Neuer Lead: keine automatische Aktion (nur über "+ Neuer Lead" im Board
  erreichbar, nicht per Zurückziehen gedacht).

Alle diese Aktionen respektieren das normale Energie-Budget des Tages (wie
jede andere geloggte Aktion auch) — reicht die Energie nicht, wird die
Karte nicht verschoben, sondern nur eine Meldung gezeigt.

Die Kanban-Stufe eines Kontakts lässt sich auch direkt im Kontaktformular
setzen (`contactKanbanStageSelect`) — das ist eine reine Korrekturmöglichkeit
ohne Aktions-Logging, nicht der normale Weg (der bleibt das Ziehen im Board).

## Produktkatalog & Verkaufshistorie, seit Patch 23

Verkauft werden **Versicherungsprodukte** (Lebens-, Kranken- [Voll-/
Zusatzversicherung als Unterkategorien], Sachversicherungen) an akademische
Heilberufe. Kategorien können optional eine Unterkategorie haben — nicht
zwingend bei jeder, ergibt sich beim tatsächlichen Einpflegen der Produkte.

**Phasenansatz, bewusst so entschieden:** Phase 1 (dieser Patch) baut nur die
Struktur — Katalog, Kategorien, Verkaufserfassung inkl. Bewertungssumme (BWS)
und laufendem Beitrag. Die eigentliche **Verrechnung** (BWS → Provision →
Bewertungspunkte) ist bewusst auf Phase 2 verschoben, siehe "Bewusst
aufgeschobene Ideen". Das BWS-Feld ist im Verkaufs-Popup trotzdem schon von
Anfang an sichtbar (nicht erst mit Phase 2 nachgerüstet) — Absicht: der
Nutzer soll sich früh an den Ablauf gewöhnen und beim echten Benutzen merken,
ob noch weitere Felder/Reiter nötig sind ("learning by doing").

**Drei getrennte Zahlen-Ebenen, nicht verwechseln:**
1. **XP/Level** (Spiel) — kommt über Quests, nie direkt vom Verkauf.
2. **Vertriebsstatistik** (rohe Zahlen wie Vertragsanzahl oder BWS-Summe pro
   Kategorie, z.B. "Lebenproduktion") — bildet reale Vertriebsleistung ab,
   dient auch der Eigen-/Mitarbeitermotivation. Der noch zu bauende
   Questbaum (siehe "Ein aktiver, paralleler Nebenstrang") wird sich
   vermutlich auf **beides** beziehen können: rohe Stückzahlen ("10
   Lebensversicherungen") UND BWS-Schwellen ("25 Mio Leben-BWS") — deshalb
   muss `sales.product_id` ein echter Verweis sein, kein Freitext, damit sich
   später sauber nach Produkt/Kategorie aufsummieren lässt.
3. **Bewertungssumme → Provision & Bewertungspunkte** — die reale
   Versicherungs-Kennzahl aus dem Job des Nutzers, unabhängig vom Spiel.
   Kommt in Phase 2, und wird dann vermutlich (wie XP/Level) **live aus der
   gespeicherten BWS berechnet, nicht als eigene Spalte gespeichert** —
   konsistent mit dem Rest des Projekts (`computeTotals()`-Prinzip).

**Verkaufshistorie-Reiter am Kontakt** (zwischen "Übersicht" und
"Tagebucheintrag", `renderContactSalesTab()` in `index.html`): kompakt
zunächst nur der Produktname sichtbar (Muster wie überall im Projekt: erst
kompakt, Klick für Details) — Details bei Klick auf den Kontakt sichtbar in
zwei Gruppen:
- **Bestehende Produkte**: `status='gewonnen'` und `vertragsende` leer.
- **Historisch**: `status='verloren'` (nie zustande gekommen) ODER
  `status='gewonnen'` mit gesetztem `vertragsende` (war aktiv, dann
  gekündigt/ausgelaufen) — bewusst **beide** Fälle in einer Gruppe, weil aus
  Kunden-Historien-Sicht beides "nicht mehr aktiv" bedeutet, auch wenn der
  Grund unterschiedlich ist.

**Wichtige Geschäftsregel:** Ein Vertrag als gekündigt/ausgelaufen markieren
(`vertragsende` setzen, per Eingabe des Kündigungsdatums) rührt
`contacts.status` **nicht** an — ein Kunde bleibt "kunde", solange
irgendein anderer Vertrag bei ihm noch läuft. Kündigen darf jeder für seine
eigenen Kontakte (Owner oder Admin, wie sonst auch — technisch bereits durch
die bestehende `sales_update_like_contact`-RLS-Policy abgedeckt, keine neue
Policy nötig).

**"Verloren"-Verkäufe** (Kanban-Spalte Verloren, oder Abschluss-Dialog)
laufen jetzt über ein eigenes, bewusst schlankes Popup (`saleLostModal`/
`recordLostSale()`) — nur Kategorie+Produkt-Auswahl, weiterhin **ohne**
Mengenfeld und ohne Mehrfach-Schleife (wie vor Patch 23 dokumentiert: "wie
viel verkauft" ergibt bei einem verlorenen Deal keinen Sinn). Auch hier
Pflicht, ein Katalog-Produkt zu wählen — kein Freitext-Fallback mehr,
irgendwo im System.

## Bewusst aufgeschobene Ideen (NICHT vergessen, aber NICHT von selbst bauen)
- **Manatrank-Vergabe an Quests knüpfen** (statt/zusätzlich zum täglichen
  Gratis-Trank aus `grantDailyManatrank()`, siehe oben bei `user_inventory`):
  vom Nutzer am 2026-07-31 als "wird sich noch ändern" angekündigt, noch ohne
  Details. Vor dem Umbauen erst klären, wie genau (ersetzt der tägliche
  Gratis-Trank die Quest-Vergabe, oder kommt beides zusammen — `grantItem()`
  für Quest-Belohnungen existiert bereits und ist unabhängig nutzbar).
- **Gilden-basierte Sichtbarkeit** (statt des heutigen organisationsweiten
  `contactsVisibility`-Schalters): war am 2026-07-30 als aktive, dringliche
  Baustelle besprochen (Grundidee, zwei Beispiel-Szenarien B2B/B2C, zwei
  offene Detailfragen), wurde am 2026-07-31 vom Nutzer bewusst zurückgestuft
  — auf **viel später** verschoben, nicht mehr aktiv. Vor dem Wiederaufnehmen:
  falls der Chat-Verlauf vom 2026-07-30 verfügbar ist, dort nachlesen (Details
  wurden hier bewusst nicht mehr mitgeschleppt). Nicht von selbst wieder
  anfangen, nur wenn der Nutzer es explizit anstößt.
- **BWS-Verrechnung (Phase 2 des Produktkatalogs)**: `sales.bewertungssumme`
  wird seit Patch 23 erfasst, aber noch nicht zu Provision/Bewertungspunkten
  verrechnet. Vor dem Bauen klären: ist die BWS ein fester Wert je Produkt
  oder wird sie aus `laufender_beitrag` × einem produktabhängigen Faktor
  berechnet, und wie genau werden daraus Provision und Bewertungspunkte
  (feste Prozentsätze pro Produkt? organisationsweiter Faktor?).
- **Vertragsnummer-Feld an `sales`** — vom Nutzer am 2026-07-31 fürs
  zukünftige B2B-CRM-Geschäft angekündigt (andere Vertriebsorganisationen
  brauchen das vermutlich), aktuell aber noch nicht gebraucht — bewusst noch
  nicht ins Schema aufgenommen.
- **Malus-Berechnung bei gekündigten/ausgelaufenen Verträgen**: vom Nutzer am
  2026-07-31 als Zukunftsidee erwähnt ("was wir aus dem Malus rechnerisch
  machen, dazu in Zukunft mehr"), noch ohne jegliche Details — evtl.
  verwandt mit dem bestehenden Konversions-Malus-Mechanismus beim Kanban
  (`termin_nicht_wahrgenommen`, −2 XP). Nicht von selbst anfangen.
- **Admin-Benachrichtigung bei Kündigung durch Mitarbeiter**: wenn ein
  Team-Mitglied einen Vertrag als gekündigt/ausgelaufen markiert, soll der
  Admin künftig automatisch informiert werden (vom Nutzer am 2026-07-31
  angekündigt). Aktuell passiert das noch nicht — braucht vermutlich einen
  neuen Benachrichtigungsmechanismus, den es im Projekt bisher gar nicht
  gibt.
- **Jahresend-Dramatisierung**: alle Tagebucheinträge (+ ggf. Fotos) eines
  Nutzers werden am Jahresende per LLM zu einer zusammenhängenden
  Heldenreise-Erzählung verdichtet. Braucht eine Supabase Edge Function
  (Anthropic-API-Key darf nicht im Client landen). Bewusst NICHT laufend pro
  Eintrag, sondern **einmal am Jahresende** — hält Kosten niedrig.
- **KI-Bildumwandlung von Tagebuch-Fotos** — z.B. "Hexer im Rat der Weißen".
  `journal_photos.transformed_path` ist als Platzhalter schon da. Selbes
  Kostenprinzip: on-demand statt pro Foto.
- **Ausrüstungs-Charakterbilder / echter Charakterscreen** (wie in einem
  RPG, nicht nur Icons). Wichtige Erkenntnis aus der Diskussion:
  handgezeichnete SVGs von Claude sind KEINE brauchbare Grundlage für echte
  Charakterkunst (Qualitätsproblem, nicht Architekturproblem).
  **KI-Bildgenerierung pro Einzelteil wurde verworfen** (Thema
  abgeschlossen, 2026-08-01): unabhängig generierte Bilder halten Proportion
  und Ankerpunkte nicht zuverlässig ein, die Ebenen (`profiles.
  equipped_weapon/armor/accessory` + `items.image`) müssen aber pixelgenau
  zueinander passen — ein technisches Problem, kein Geschmacksproblem.
  Einziger tragfähiger Weg: fertige, bereits in Ebenen aufgeteilte
  Asset-Pakete (z.B. itch.io — Lizenz für spätere kommerzielle Nutzung des
  Produkts vorher prüfen).

  **Design für Gewinnen/Anziehen, seit 2026-08-01 festgelegt (noch nicht
  gebaut):**
  - *Gewinnen*: über das bestehende `grantItem()` (bisher nur für
    Quest-Belohnungen wie den täglichen Manatrank genutzt) — Quests
    bekommen ein optionales `reward_item_key`+`qty`-Feld im Regelwerk, bei
    Abschluss landet das Item wie gehabt in `user_inventory`. Keine neue
    Infrastruktur nötig.
  - *Anziehen/Ausziehen*: bewusst **keine geloggte Aktion** (kein XP, kein
    `action_log`-Eintrag) — reine Kosmetik, kein Vertriebsverhalten. Neues,
    einfaches `equipItem(slot, item_key)`/`unequipItem(slot)`, setzt nur
    `profiles.equipped_<slot>`, beliebig oft wiederholbar, verbraucht das
    Item in `user_inventory` NICHT (Unterschied zu Verbrauchsgütern wie dem
    Manatrank, die beim Benutzen abgezogen werden).
  - Dafür braucht der Item-Katalog (`rule_configs.config.items`) eine
    Unterscheidung: `slot: 'weapon'|'armor'|'accessory'` für Ausrüstung
    (nicht verbraucht) vs. das bestehende `effect`-Feld für Verbrauchsgüter
    (wird verbraucht, siehe `useItem()`). Kein neues DB-Schema nötig — passt
    komplett in die bestehenden Tabellen (`user_inventory`, `profiles.
    equipped_*`, Regelwerk-JSON).

  Technisches Fundament ist **fertig**: `profiles.
  equipped_weapon/armor/accessory`, `items.image`-Feld (aktuell leer) —
  sobald eine Bild-URL im Regelwerk hinterlegt wird, rendert die
  Charakter-Seite sie automatisch als Ebene, ohne Code-Änderung. Fehlt noch:
  das Asset-Paket selbst, `equipItem()`/`unequipItem()`, und das
  Reward-Feld in Quests.

  **Asset-Quelle, seit 2026-08-01 im Testeinsatz:** heruntergeladene
  GandalfHardcore-Pakete (Basis-Körper, Arm-/Handschuh-Ebenen, Hand-Items/
  Waffen, Rücken-Ebenen, Kleidung männlich/weiblich, Hüte, Masken,
  Elfenohren, Rücken-Layer, u.a.), liegen lokal unter
  `~/Schreibtisch/GandalfHardcore *.zip` (wird laufend um weitere
  Zusatzpakete ergänzt, noch kein Bogen/Zauberstab dabei — fehlt für
  Schütze/Hexer). Verifiziert (Python/Pillow-
  Komposit): Ebenen liegen pixelgenau übereinander, keine Ausrichtungs-
  probleme. Sheets sind Animations-Spritesheets mit mehreren Reihen
  unterschiedlicher Frame-Anzahl je Aktion (Idle/Laufen/Angriff/...) — für
  den Charakterscreen reicht das Herausschneiden EINES Frames (z.B.
  Idle-Pose) pro Ebene, keine Animation nötig. Lizenz erlaubt kommerzielle
  Projekte, Verändern erlaubt, keine Namensnennungspflicht — verbietet aber
  Weiterverkauf/Weitergabe der rohen Assets, KI-Training und Einbau in
  "Game Tools". **Lizenzfrage Multi-Tenant-SaaS (mehrere zahlende
  Kundenorganisationen) bewusst zurückgestellt** (Nutzer, 2026-08-01): das
  Projekt ist aktuell rein persönlich/intern (siehe auch
  "Bewusst aufgeschobene Ideen" unten, Verkauf ist noch weit weg) — erst
  klären, wenn ein tatsächlicher Verkauf an eine zweite Organisation
  ansteht, nicht vorher. Bei der Outfit-Auswahl aus "Female Clothing"
  trotzdem schon jetzt bewusst freizügige
  Teile (Bikini/Unterwäsche) aussortieren — passt nicht zum B2B-Kontext
  (Vertrieb an akademische Heilberufe).

  **Zurückgestellte Alternative, falls mehrere Organisationen später einen
  jeweils eigenen Look brauchen:** ein riggtes 3D-Charaktermodell (z.B.
  Reallusion Character Creator) statt 2D-Ebenen — löst Bild-Ausrichtung
  strukturell (Ausrüstung wird auf das Skelett gesteckt, nicht gezeichnet),
  jedes neue Item danach günstiger als ein komplett neu gezeichnetes
  2D-Bild. Höherer Einstiegsaufwand, deshalb bewusst zurückgestellt, solange
  die 2D-Ebenen-Lösung oben für die aktuellen 3 Klassen ausreicht.

  **Krieger-Portrait, seit 2026-08-01 testweise live** (Nutzer: "kann sein,
  wenn es nicht schön ist, dass wir das wieder rückgängig machen" — bewusst
  ein Versuch, kein endgültiger Beschluss): Basis-Körper + roter Umhang +
  Schwert + Standard-Kleidung + Haare, aus einem Idle-Frame der Sheets
  zusammengesetzt (Python/Pillow, Frame-Ausschnitt (31,21,48,64) auf der
  800×448-Leinwand). Datei liegt unter `img/characters/krieger.png` (erster
  Bild-Ordner im Repo, es gab bisher keine lokalen Bild-Assets). Eingebaut
  an drei Stellen in `index.html`:
  - `#authScreen` (Login-Formular): `.auth-portrait`, rein dekorativ, zeigt
    sich unabhängig von der eigenen Klasse.
  - `#charCreateScreen`: Krieger-Klassenkarte, `.class-portrait-img`
    ersetzt dort das ⚔️-Emoji (Hexer/Schütze behalten ihre Emoji, kein Bild
    vorhanden).
  - `#page-charakter` (`charArtStack`): `renderCharacterEquipment()` hat
    jetzt eine `CLASS_BASE_ART`-Map (aktuell nur `krieger` gefüllt) — zeigt
    bei passender Klasse das Basisbild UNTER den bereits bestehenden
    Ausrüstungs-Ebenen (siehe oben), andere Klassen fallen weiter auf den
    Hinweistext zurück.
  `image-rendering:pixelated` überall gesetzt, damit die Pixel-Art beim
  Hochskalieren scharf bleibt statt zu verschwimmen. Schütze/Hexer bewusst
  noch nicht gebaut (dem Nutzer gefielen die ersten Test-Kombinationen mit
  dem "Stick"-Platzhalter-Item nicht) — fehlt aktuell vor allem ein
  Bogen/Zauberstab-Asset, siehe oben.
- **Multi-Org-Charakter-Portabilität**: die Idee, dass ein Nutzer den
  Charakter (Level/Skills/Tagebuch) über einen Arbeitgeberwechsel hinweg
  mitnehmen könnte, während Dungeons/Items/Quests bei der alten Organisation
  bleiben. **Echte strukturelle Weiche** (aktuell ist ein Profil fest an
  GENAU EINE Organisation gekettet) — bewusst nicht angefasst, nur
  dokumentiert.
- **Team-Reporting für Teamleiter** (wie viele Accounts pro Mitarbeiter, etc.)
  — technisch trivial, sobald `locations.owner_id` existiert (existiert
  bereits seit Patch 11), aber noch keine UI dafür gebaut.
- **Automatisiertes Anruf-Verzeichnis** ("wen sollte ich als Nächstes
  anrufen") — nur als Idee erwähnt, nichts geplant.

## Ein aktiver, paralleler Nebenstrang

Der Nutzer baut **außerhalb dieses Chats** parallel an einem größeren
Quest-Baum (Quest-Ketten wie "Krankenhaus-Meister", aber viel mehr davon) —
vermutlich in Obsidian Canvas oder einer Tabelle. Wenn der Nutzer eine
Quest-Baum-Datei mitbringt, geht es darum, sie ins `recurringQuests`/
`questChains`-JSON-Schema im Regelwerk zu übersetzen — Format siehe
bestehende Beispiele in `sql/patch2_journal.sql` ff. bzw. direkt in der
Supabase-Tabelle `rule_configs`.

## Bekannte, bewusst in Kauf genommene Lücken

- Aktuell sieht JEDES Organisationsmitglied ALLE Accounts/Locations
  (`locations_select_org`-Policy hat keine Besitzer-Einschränkung) — laut
  Nutzer eigentlich falsches Verhalten, aber die geplante Lösung (gilden-
  basierte Sichtbarkeit, siehe "Bewusst aufgeschobene Ideen") ist bewusst auf
  später verschoben. Bis dahin: kein Alleingang, nicht von selbst reparieren.
- "Zuletzt kontaktiert" an einem Kontakt zeigt nur **eigene** Log-Einträge des
  gerade eingeloggten Nutzers, nicht die von Kollegen — auch wenn der Kontakt
  auf "shared" steht. Grund: `action_log` bleibt grundsätzlich privat; es gibt
  eine RLS-Policy (`log_select_shared_contact_activity`), die Team-Sicht auf
  Log-Einträge AN EINEM GETEILTEN KONTAKT erlaubt, aber die UI zieht das noch
  nicht konsequent. Könnte man ausbauen.
- Level-Kurve basiert auf geschätzten, nicht gemessenen Aktivitätswerten.
- Kein automatisiertes Testen — der Nutzer testet manuell mit sich selbst und
  zwei Kollegen (Safari/iPhone + Brave/Desktop).

## Wie mit dem Nutzer arbeiten (Ton/Stil aus dem bisherigen Chat)

- Der Nutzer ist **kein Programmierer**, aber technisch interessiert und will
  Dinge wirklich verstehen, nicht nur "vertrauen". Erklärungen in einfacher
  Sprache, Fachbegriffe kurz einordnen.
- Der Nutzer besteht darauf, bei größeren/zentralen Bausteinen (explizit z.B.
  bei der Kundendatenbank: "das Herzstück") **erst gemeinsam durchzusprechen,
  bevor Code geschrieben wird**. Diese Regel gilt weiter: bei Kernstrukturen
  (Datenmodell-Änderungen, neue zentrale Tabellen, Berechtigungsmodelle) erst
  Verständnis-Rückmeldung + offene Fragen, dann erst nach Bestätigung bauen.
  **Präzisierung (seit 2026-07-31, Produktkatalog-Feature):** "erst
  durchsprechen" heißt eine gründliche **Konversation** vorher — NICHT
  zusätzlich einen SQL-/Code-Entwurf zum Gegenlesen vorlegen, bevor er läuft.
  Der Nutzer kann rohen SQL-/Code-Text als Nicht-Programmierer ohnehin nicht
  sinnvoll bewerten ("ich muss es sehen und fühlen") — nach ausführlicher
  Diskussion einfach bauen, hochladen, der Nutzer testet die laufende
  Funktion im Alltag und gibt danach Rückmeldung.
- Der Nutzer denkt gerne "groß"/langfristig (Skalierbarkeit auf andere
  Vertriebe, Templating), will aber in **kleinen, funktionierenden Schritten**
  bauen — nicht alles auf einmal.
- Der Nutzer ist vorsichtig bei destruktiven SQL-Operationen (`DROP`,
  `DELETE`) — immer explizit warnen, wenn ein Patch sowas enthält, und den
  Unterschied zu harmlosen `DROP POLICY`-Fällen erklären.
- SQL-Patches wurden bisher immer als eigene, nummerierte, kommentierte
  Dateien geliefert (nicht in bestehende Migrationen eingemischt) — dieses
  Muster beibehalten, bis eine echte Migrations-Toolchain eingeführt wird.
- **Blankoscheck für git commit/push** (seit 2026-07-31): der Nutzer will
  vor normalem Committen und Pushen **nicht mehr gefragt werden** — einfach
  machen, nach jeder abgeschlossenen Änderung. Gilt nicht für wirklich
  destruktive Git-Operationen (force-push, reset --hard, Branches löschen)
  — dafür weiterhin fragen. **Push funktioniert seit 2026-07-31 direkt aus
  Claude Code heraus** (GitHub Personal Access Token im
  `credential.helper store` des Nutzers hinterlegt, siehe Tech-Stack oben)
  — kein manueller Zwischenschritt beim Nutzer mehr nötig, anders als noch
  am Anfang dieser Session (damals scheiterte es an fehlendem
  `ksshaskpass` in der Sandbox).
