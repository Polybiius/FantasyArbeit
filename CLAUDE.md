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
- **Radius-/Schatten-System** (seit 2026-08-02): einheitliche CSS-Variablen im
  `:root`-Block von `index.html` statt roher Werte — `--radius-xs/sm/md/lg/pill`
  (4/8/12/14/999px, nach Element-Größe: kleine Bedienelemente=sm,
  Karten/Kacheln=md, große Container/Panels=lg) und `--shadow-rest`/
  `--shadow-raised` (dezenter Schatten im Ruhezustand auf Panels/Karten,
  kräftigerer beim Hover auf klickbaren Kacheln). Vorher liefen `border-radius`
  auf 9 verschiedenen unsystematischen Werten und Schatten fast nirgends außer
  bei den Dungeon-Kacheln. **Neue UI-Elemente sollten diese Variablen
  weiterverwenden statt neue Radius-/Schatten-Werte zu erfinden.**
- **Visuelle Prüfung durch Claude Code** (seit 2026-08-02): Playwright +
  Chromium liegen portabel unter `~/.local/share/playwright-portable`
  (eigenes kleines `npm`-Projekt dort, nicht Teil des Repos/`package.json`
  von FantasyArbeit — reines Werkzeug für Claude Code, kein Produkt-Code).
  Kein Systemeingriff, kein `sudo`. Damit kann Claude Code bei
  Frontend-Änderungen die Seite tatsächlich headless rendern und sich per
  Screenshot selbst gegenprüfen (`node shot.mjs <pfad>` als Beispielskript,
  startet vorher `python3 -m http.server` im Repo-Ordner) statt nur den
  CSS-Code zu lesen und zu hoffen, dass es passt. Chromium ist technisch
  derselbe Rendering-Kern (Blink) wie im vom Nutzer verwendeten Brave —
  visuell identisch für CSS/Layout-Zwecke.
- **Lokales Öffnen von HTML-Dateien beim Nutzer** (seit 2026-08-02): Brave
  läuft bei ihm sandboxed (vermutlich Flatpak) — ein direkter `file://`-Zugriff
  auf den Projektordner schlägt fehl (`ERR_FILE_NOT_FOUND`), und Dateien über
  den Datei-Öffnen-Dialog ausgewählt landen nur mit Zugriff auf genau diese
  eine Datei hinter einem `/run/user/.../doc/...`-Portal-Pfad — Nachbarordner
  wie `img/` sind dann nicht erreichbar, Bilder mit relativen Pfaden bleiben
  kaputt. Lösung: VS-Code-Erweiterung **"Live Server"** (ritwickdey.LiveServer,
  installiert per `code --install-extension ritwickdey.LiveServer`) —
  Rechtsklick auf eine HTML-Datei im Explorer → "Open with Live Server"
  liefert sie über `http://127.0.0.1:5500/...` aus, das umgeht die
  Sandbox-Einschränkung komplett (Netzwerkzugriff ist uneingeschränkt) und
  lädt bei jedem Speichern automatisch neu. Das ist jetzt der Standardweg für
  den Nutzer, um lokale HTML-Dateien (Produkt oder Dummy) im Browser zu sehen.
- **Bisheriger Workflow**: Der Nutzer hat NICHT lokal mit Git gearbeitet, sondern
  jede neue `index.html`-Version über den GitHub-Web-Upload hochgeladen, und jeden
  SQL-Patch manuell im Supabase SQL-Editor ausgeführt. Das ändert sich jetzt mit
  Claude Code: Commits/Pushes laufen seit 2026-07-31 automatisch durch Claude
  Code (ein GitHub Personal Access Token liegt im `credential.helper store` des
  Nutzers, dadurch kein `ksshaskpass`-Problem mehr). **SQL-Patches laufen
  weiterhin manuell** über den Supabase SQL-Editor beim Nutzer — dafür hat
  Claude Code keinen Zugriff/Zugangsdaten.

## Datenbank — aktueller Stand (Annahme: Patch 1–25 eingespielt)

**Wenn das nicht stimmt, sofort korrigieren, bevor irgendetwas gebaut wird** — sonst
versucht Claude Code eventuell, Dinge doppelt anzulegen oder Migrationen in falscher
Reihenfolge zu bauen. Patch 24 (`patch24_profil_onboarding.sql`,
`real_name`/`gender`/`company`) und Patch 25 (`patch25_aussehen.sql`,
`skin_tone`/`hair_style`) wurden vom Nutzer am 2026-08-02 im Supabase
SQL-Editor ausgeführt.

**Wichtig zu Patch 25:** die Datenbank-Spalten `profiles.skin_tone`/`hair_style`
existieren seit 2026-08-02 live; der zugehörige Screen ("Aussehen", siehe
unten) wurde seit 2026-08-03 ins echte `index.html` übertragen und schreibt
seitdem auch tatsächlich hinein. **SQL-Patches werden künftig erst nach
explizitem Go von Claude Code ausgeführt** (nicht mehr sobald die Datei
existiert) — siehe Absprache vom 2026-08-02.

Alle SQL-Patches liegen im Ordner `sql/` (chronologisch benannt, `schema.sql` +
`patch.sql` sind die ursprüngliche Basis, danach `patch2_...` bis `patch24_...`).
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
  fremde private Logs zu brauchen). Seit Patch 24 zusätzlich `real_name`
  (echter Name, getrennt vom Charakternamen in `display_name`), `gender`
  ('m'|'w', steuert nur die Anzeige der Klassenbezeichnung bei der
  Charaktererstellung, siehe "Profil-Onboarding" unten) und `company`
  (Freitext, optional — **kein** Bezug zum Mandanten-System
  `organizations`, siehe dort). Alle drei nullable, bei alten Profilen
  (vor Patch 24 registriert) bleiben sie leer.
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

## Profil-Onboarding, seit Patch 24 (2026-08-02)

Zwischen Anmeldung und Klassenwahl gibt es jetzt einen dritten Schritt,
`#profileScreen` in `index.html` (drei Screens insgesamt: `authScreen` →
`profileScreen` → `charCreateScreen`). Dort werden vier Felder erfasst, bevor
der eigentliche Charakter erschaffen wird:

- **Echter Name** (`realNameInput` → `profiles.real_name`) — bewusst getrennt
  vom Charakternamen (`charNameInput` → `profiles.display_name`, wie bisher).
- **Geschlecht** (`männlich`/`weiblich`, zwei Toggle-Buttons `.gender-btn` →
  `profiles.gender`, Werte `'m'`/`'w'`). Steuert **ausschließlich** die
  Anzeige-Bezeichnung der Klassen bei der Klassenwahl direkt danach (siehe
  unten) — keine Auswirkung auf Regelwerk, Berechnungen oder sonstige Logik.
  Bewusst nur zwei Optionen (Entscheidung vom Nutzer, 2026-08-02): eine
  dritte/neutrale Form hätte eine eigene grammatikalische Lösung gebraucht,
  die noch nicht ansteht.
- **Unternehmen** (`companyInput`, optional → `profiles.company`) — reines
  Freitext-Anzeigefeld ("wo arbeitest du", darf leer bleiben, z.B. bei
  Selbstständigkeit). **Wichtig, nicht verwechseln:** hat NICHTS mit dem
  Mandanten-System `organizations` zu tun — es wird keine echte Organisation
  ausgewählt oder gewechselt, nur ein Textfeld gespeichert. Eine echte
  Mehrfach-Organisations-Auswahl wäre ein großer struktureller Umbau (aktuell
  fest auf `DEFAULT_ORG_ID` verdrahtet) und war explizit nicht gemeint.
- **Charaktername** (wie bisher, jetzt nur räumlich auf diesen Screen
  verschoben statt auf dem Klassenwahl-Screen).

Der "Weiter"-Button (`profileNextBtn`) bleibt sichtbar gedimmt (Klasse
`.btn-disabled`, KEIN natives `disabled`-Attribut — bewusst so, siehe
unten), bis Name, Geschlecht und Charaktername ausgefüllt sind (Unternehmen
bleibt optional). Klickt man trotzdem, wackeln genau die fehlenden Felder
kurz rot (`.shake`-Klasse, `@keyframes wobble`, per `shakeEl()`-Helfer in
`index.html`) statt stumm nichts zu tun.

**Geschlechtsabhängige Klassenbezeichnung**: Beim Wechsel auf den
Klassenwahl-Screen setzt `CLASS_NAMES[gender]` die Beschriftung der drei
Klassenkarten auf Hexer/Krieger/Schütze (männlich) oder
Hexerin/Kriegerin/Schützin (weiblich). Das betrifft **nur** die Karten-Texte
in diesem einen Screen — `CLASS_LABELS` (Klassenanzeige im Header nach dem
Einloggen, "Klasse: Hexer") und alle klassenabhängigen Begriffe oben in
dieser Tabelle (Gilde/Kanban/Kundendatenbank) enthalten das Wort
Hexer/Krieger/Schütze selbst nicht und brauchten deshalb keine Anpassung.
Falls die Kopfzeilen-Anzeige nach dem Einloggen künftig auch geschlechtsabhängig
sein soll, ist das ein separater, noch nicht gebauter Schritt.

**"Charakter erschaffen"-Button** (`charCreateBtn`, Klassenwahl-Screen)
funktioniert nach demselben Muster: gedimmt via `.btn-disabled` bis eine
Klasse gewählt ist, wackelnde Klassenkarten (nicht der Button selbst) bei
einem Klick ohne Auswahl. Der eigentliche `profiles`-Insert passiert weiterhin
erst hier, ganz am Ende (ein einziger atomarer Insert mit allen sechs
Feldern: `display_name`, `character_class`, `real_name`, `gender`, `company`,
plus `id`/`org_id`/`role` wie bisher) — die Werte aus dem Profil-Screen werden
dafür einfach erneut aus den (nur visuell versteckten, nicht entfernten)
Input-Feldern gelesen.

**`.btn-disabled` statt natives `disabled`-Attribut, bewusst so** (bei
`profileNextBtn` UND `charCreateBtn`): ein echtes `disabled`-Attribut
unterdrückt Klick-Events komplett, dann könnte kein Wobble-Hinweis beim
Versuch ausgelöst werden. Die CSS-Regel `.auth-btn:disabled,.auth-btn.btn-disabled`
sorgt dafür, dass beide Zustände (natives Attribut UND die neue Klasse)
gleich aussehen (gedimmt, kein Leucht-Gradient) — betrifft auch den
`authSubmitBtn`, falls der je ein `disabled`-Attribut bekommen sollte.

**Entstehungsweg**: Diese ganze Änderung wurde zuerst in einer separaten,
nicht versionierten Datei `dummy-anmeldung.html` (Projekt-Root, lokal, nicht
committed) durchgespielt und optisch geprüft, bevor sie hierher übertragen
wurde. Grund ist NICHT Risiko-Minimierung, sondern schlicht Sichtbarkeit: der
Nutzer hat längst ein eigenes Profil und kann Anmelde-/Charaktererstellungs-
Bildschirme im echten Programm gar nicht mehr erreichen, um Änderungen daran
zu begutachten — ohne Dummy hätte er sie schlicht nicht sehen können. Dieses
Muster lohnt sich deshalb gezielt für Bildschirme, die nur einmalig VOR einem
bestimmten Zustand erscheinen (Erstanmeldung, Ersteinrichtung) — nicht
pauschal für jede riskante Änderung an normal erreichbaren Seiten, die sich
der Nutzer direkt in der echten Anwendung ansehen kann. Playwright/Chromium
(siehe oben) dient dabei der automatisierten
Kontrolle beider Versionen.

**`dummy-anmeldung.html` seit 2026-08-03 gelöscht:** der Admin-Knopf "🎭 Neu
erschaffen" (siehe Kanban-Abschnitt weiter unten bzw. Git-Commit
`0a27220`) springt für Admins zurück auf `profileScreen` →
`charCreateScreen` → `appearanceScreen` und aktualisiert am Ende das
bestehende Profil statt eines neuen anzulegen. Damit ist die ursprüngliche
Sichtbarkeits-Lücke, die die Dummy-Datei überhaupt nötig gemacht hatte,
strukturell geschlossen — der Nutzer kann sich jede künftige Änderung an
diesen drei Screens direkt im echten, laufenden Programm ansehen. Alle
Code-Stellen unten, die noch von `dummy-anmeldung.html` sprechen, sind
historisch gemeint (beschreiben, wo etwas ursprünglich gebaut/geprüft
wurde) — aktuell lebt der gesamte Rendering-Code nur noch in `index.html`.
**Lehre fürs nächste Mal:** bevor eine neue Dummy-Datei für ein
"unerreichbar gewordenes" Onboarding-artiges Bildschirm gebaut wird, erst
prüfen, ob ein kleiner, dauerhafter Admin-Debug-Zugang (wie dieser Knopf)
die Sichtbarkeits-Lücke nicht direkter und dauerhaft schließt, statt eine
Wegwerf-Kopie zu pflegen.

## Aussehen-Screen (Hautfarbe/Frisur), seit Patch 25 (2026-08-02)

Vierter Onboarding-Schritt, direkt nach der Klassenwahl, vor dem Sprung ins
Programm: `authScreen` → `profileScreen` → `charCreateScreen` → **`appearanceScreen`**
→ App. Zuerst im Dummy (`dummy-anmeldung.html`) gebaut und geprüft, seit
2026-08-03 auch ins echte `index.html` übertragen (siehe "Entstehungsweg"
oben zum generellen Muster) — der eigentliche `profiles`-Insert (inkl.
`character_class`/`real_name`/`gender`/`company`, seit diesem Umbau auch
`skin_tone`/`hair_style`) passiert jetzt ganz am Ende, im Klick-Handler von
`appearanceDoneBtn` statt wie vorher in `charCreateBtn` — die Klassenwahl
selbst löst keinen Insert mehr aus, sondern blättert nur weiter zum
Aussehen-Screen.

Zwei Auswahlen, wie in einem RPG-Charaktereditor:
- **Hautfarbe**: 5 vorgefertigte Töne je Geschlecht (`Male Skin1-5`/`Female
  Skin1-5` aus dem GandalfHardcore-Paket), einfache Klick-Auswahl.
- **Frisur**: kein echter Farb-Regler (die Frisuren-Bilder kommen nur in
  jeweils einer festen Farbe, keine tönbaren Ebenen). Stattdessen ein
  **Farb-Reiter** (Schwarz/Braun/Blond/Rot **+ Glatze**) als Filter über
  einem Frisuren-Raster — man wählt zuerst die Farbfamilie, dann die Form
  darin. "Glatze" (seit 2026-08-02) ist ein fünfter, besonderer Reiter ohne
  Raster dahinter — wählt ihn jemand, wird die Haar-Ebene in der
  Vorschau ausgeblendet und `selectedHair` auf den Platzhalter `__bald__`
  gesetzt (bleibt für `appearanceDoneBtn` trotzdem ein gültiger, "fertig
  gewählter" Zustand — kein erzwungener Frisur-Zwang mehr).
  Die Farbzuordnung je Frisur wurde automatisch per dominanter Bildfarbe
  bestimmt (`Design/export_creator_assets.py`, HSV-Klassifikation über die
  helleren 25% der Pixel, um die schwarze Pixel-Art-Outline nicht den
  Mittelwert verfälschen zu lassen) — bei Pixel-Art nicht hundertprozentig
  zuverlässig, könnte einzelne Frisuren falsch einsortiert haben. Bei Bedarf
  einfach die `color`-Zuordnung im `HAIR_CATALOG`-Array von Hand korrigieren,
  keine strukturelle Änderung nötig.

**Live-Vorschau: animiert, dynamisch aus Ebenen zusammengesetzt (seit
2026-08-03, zweite Überarbeitung)** — nicht mehr `<img>`-Ebenen
übereinandergelegt, sondern ein `<canvas>`, das jeden Frame per
`drawImage()` aus den einzelnen Ebenen-Sheets neu zusammensetzt. Grund für
den Wechsel: der Nutzer wollte explizit **keine statischen Einzelbilder**
("wir wollten ja ein dynamisches Charakterscreen") und dass der Charakter
sichtbar **auf der Stelle läuft** statt (wie bei einem ersten,
verworfenen CSS-`steps()`-Versuch) unsauber zu wirken.

Technik (`createSpriteRenderer(canvas, scale)`, heute nur noch in
`index.html` — ursprünglich zuerst in `dummy-anmeldung.html` gebaut, siehe
"Entstehungsweg" oben):
- Jede Ebene (Haut, Kleidung, Handschuhe, Frisur, Waffe, Rücken-Item) ist
  ein volles, unbeschnittenes Sprite-Sheet (`img/characters/sheets/`,
  siehe unten) — **kein zugeschnittenes Vorschaubild**, sondern dieselbe
  Datei, die auch die komplette Animationsmatrix enthält.
- Reihe 2 des Sprite-Grids (y=128–192) ist der Laufzyklus. **Wichtiger
  Stolperstein:** die Frames dieser Reihe liegen NICHT im 100px-Raster,
  das für die Item-Kacheln (ein Frame pro 100×64-Zelle) gilt, sondern
  enger bei **~80px Abstand** — empirisch gemessen durch Absuchen der
  Alpha-Kanäle nach zusammenhängenden Blöcken (8 klare Blobs bei
  x≈32,110,192,271,351,431,512,591, praktisch identisch über alle
  Ebenen-Typen hinweg). Mit dem falschen 100px-Raster hat der
  Bildausschnitt gelegentlich zwei benachbarte Frames gleichzeitig
  erwischt — genau der vom Nutzer gemeldete Bug ("der Charakter läuft aus
  dem Bild" / wirkt doppelt). `FRAME_W = 80` behebt das.
- Pro Tick (9 FPS, `setInterval`) wird der Frame-Index weitergezählt und
  für jede Ebene derselbe Ausschnitt (`frame*80, 128, 80, 64`) auf die
  volle Canvas-Größe hochskaliert gezeichnet (`ctx.imageSmoothingEnabled
  = false` für scharfe Pixel-Art) — daher "läuft auf der Stelle", nie aus
  dem Bild heraus.
- `setLayers(fileNames)` tauscht die Ebenen-Liste aus (z.B. bei
  Hautfarben-/Frisur-Wechsel) und rendert sofort neu, ohne den
  Animations-Timer neu zu starten.

Zwei Renderer-Instanzen (in `index.html`):
- **Klassenwahl-Portraits** (`portraitRenderers`, drei `<canvas>` statt
  der früheren `<img>`): feste Basis-Kleidung + Klassenitem, bewusst
  glatzköpfig (Frisur kommt ja erst im nächsten Screen), Krieger inkl.
  Guard Helmet. `layersForClassPortrait(cls, gender)` baut die Ebenen-Liste,
  aktualisiert beim Wechsel von `profileScreen` zu `charCreateScreen`
  passend zum gewählten Geschlecht.
- **Aussehen-Vorschau** (`appearanceRenderer`, ein `<canvas>`):
  Basis-Kleidung + Klassenitem **ohne Kopfbedeckung** (damit die gewählte
  Frisur sichtbar bleibt) + die gerade gewählte Hautfarbe/Frisur.
  `refreshAppearanceCanvas()` baut die Ebenen-Liste neu und wird bei jeder
  Hautfarben-/Frisur-/Glatze-Auswahl aufgerufen.

**Asset-Pipeline / Lizenz-Grenze:** die rohen GandalfHardcore-Zips liegen
unter `Design/` (gitignored — Lizenz verbietet Weitergabe der Rohdaten).
Für die Canvas-Animation werden aber die **vollen, unveränderten
Sprite-Sheets** gebraucht (nicht nur ein Ausschnitt) — liegen als
abgeleitete Kopien unter `img/characters/sheets/` (`Design/
export_full_sheets.py`: 10 Hauttöne, 58 Frisuren, Basis-Kleidung als
Hemd+Hose+Stiefel bzw. Corset+Rock+Socken zu einem Sheet zusammengeführt,
Handschuhe, Cape, Rucksack, zwei Waffen, Guard Helmet — ca. 780KB
insgesamt). Genau wie bei `img/characters/krieger.png` gilt: das ist
laut Lizenz gedeckt ("modifying them as needed, and displaying work
featuring the assets on designated websites"), verboten ist nur die
Weitergabe der unveränderten Rohdaten als eigenständiges Downloadpaket,
nicht das Einbauen (auch unveränderter) Einzel-Sheets ins eigene Produkt.
Die kleinen, eng zugeschnittenen Vorschaubilder unter
`img/characters/creator/` (`Design/export_creator_assets.py`) bleiben
weiterhin bestehen, aber nur noch für die **Auswahl-Kacheln** (Hautton-
Buttons, Frisuren-Raster) — nicht mehr für die Vorschau selbst. Die
frühere Zwischenstufe (`export_outfit_layers.py`, eng zugeschnittene
Basis-Kleidung/Klassenitem-Bilder unter `creator/outfit_*`) ist mit
diesem Umbau überflüssig geworden — sowohl die erzeugten Bilder als auch
das Skript selbst wurden entfernt, ebenso die sechs statischen
`img/characters/{hexer,krieger,schuetze}_{m,w}.png` von der ersten
Klassenwahl-Bildschirm-Version — beides durch die Canvas-Animation
ersetzt.

**Datenbank (Patch 25, `sql/patch25_aussehen.sql`, bereits ausgeführt):** zwei
neue nullable Spalten `profiles.skin_tone`/`hair_style` — reine Schlüssel in
den fest im Frontend hinterlegten Katalog (`SKIN_CATALOG`/`HAIR_CATALOG`,
heute nur noch in `index.html` gepflegt, siehe "Entstehungsweg" oben),
keine eigene Farbspalte nötig (siehe oben, Farbe steckt schon in der
gewählten Frisur).
Seit 2026-08-03 schreibt das echte Programm auch tatsächlich hinein (siehe
`appearanceDoneBtn`-Handler oben).

**`Design/`-Sandkasten seit 2026-08-03 aufgeräumt:** alle Wegwerf-
Vorschau-/Entscheidungswerkzeuge aus der Bau-Phase (`gallery.html` +
`thumbs/` [Asset-Katalog], `concept.html` + `concept/` [Klassen-Outfit-
Composites], `anim_demo.html` + `anim/` [erster, verworfener CSS-Animations-
Versuch], `hair_review.html` + `hair_thumbs/` [Frisuren-Farbsichtung],
`canvas_test.html` [Debug beim Animations-Bug], `creator_catalog.json`,
sowie die Erzeuger-Skripte `compose_concept.py`/`export_outfit_layers.py`/
`export_walk_anim.py`/`make_thumbs.py`) sind gelöscht, nachdem ihre
Ergebnisse ins echte Produkt übernommen waren — sie hatten ihren Zweck
erfüllt (Entscheidungen treffen, Technik austesten), ihre Ausgaben leben
jetzt als Code/Assets im Produkt weiter. **Übrig in `Design/` (alle
gitignored) bleiben bewusst:** die rohen GandalfHardcore-Zips + `extracted/`
(Quellmaterial, falls später weitere Assets gebraucht werden, z.B. für die
Schützen-Fernkampfwaffe) sowie die zwei weiterhin aktiv gebrauchten
Erzeuger-Skripte `export_creator_assets.py` und `export_full_sheets.py`
(erzeugen die tatsächlich im Produkt verwendeten `img/characters/creator/`-
und `img/characters/sheets/`-Bilder — bei Bedarf erneut ausführbar, z.B.
nach Ergänzung neuer Assets).

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

## Sprite-Labor: Asset-Erstellungs-Werkzeug für neue Items (seit 2026-08-03 gebaut)

Der Bogen (siehe "Schützen-Bogen" weiter oben) brauchte in einer früheren
Session drei Runden Live-Testen im echten, deployten Programm, bis Größe/
Spiegelung/Ankerpunkt stimmten — jedes Mal: Bild bauen, committen, pushen,
Nutzer lädt neu, meldet zurück, was noch falsch aussieht. Zu langsam für ein
rein visuelles Problem. Als Lösung dafür existiert jetzt **`Design/
sprite_lab.html`** — ein lokales, nicht versioniertes Werkzeug (liegt im
gitignoreten `Design/`-Ordner, wie die Export-Skripte), über Live Server
geöffnet (wie die Dummy-Dateien). Ursprünglich war dafür ein Claude-Code-
"Artifact" angedacht (siehe Git-Historie) — verworfen, weil Artifacts keinen
Schreibzugriff auf lokale Ordner haben und Bild-Assets nicht extern nachladen
dürfen (strikte CSP); ein lokales Live-Server-Tool kann beides.

**Funktionsweise:** zeigt den echten, animierten Laufzyklus (gleiche Technik
wie `createSpriteRenderer()` in `index.html`) mit wählbarem Referenz-Item
(Schwert/Stab/Bogen/Helm/Cape/Rucksack) zum optischen Vergleich, plus dessen
Bounding-Box-Spannweite über alle 8 Frames (Ersatz für einen manuellen
`frame_bboxes()`-Python-Aufruf). Ein neues Kandidaten-PNG wird per
Datei-Auswahl geladen; Ankerpunkt wird **per Klick** auf das Bild gesetzt
(nicht automatisch aus der Bounding-Box-Mitte — genau der Fehler, der den
allerersten Bogen falsch sitzen ließ). Größen-Regler (Maßstab, Seiten-
verhältnis bleibt erhalten), Spiegeln-Checkbox, Animationstempo einstellbar
(1–9 fps, 9 = echtes Spieltempo). **Frame-Feinjustierung**: pro einzelnem
Frame (Slider anhalten) lassen sich Position (⬅➡⬆⬇) und Rotation (⟲⟳, um den
Ankerpunkt) unabhängig voneinander setzen — wirkt jeweils NUR auf den
gerade gewählten Frame, alle 8 Frames werden so nacheinander von Hand
durchgestimmt, globaler Anker-Nudge bleibt separat für die einmalige
Grobkorrektur des Griffpunkts.

**Übertragungs-Pipe:** ein "✓ Fertig"-Knopf schreibt die abgestimmten Werte
(Anker, Maßstab, Spiegelung, Position+Rotation pro Frame) als
`sprite_lab_export.json` **direkt in einen vom Nutzer einmalig gewählten
Ordner** (File System Access API, `showDirectoryPicker()`, Berechtigung wird
in IndexedDB gemerkt und übersteht auch ein Live-Server-Neuladen) — kein
Downloads-Ordner-Raten, kein Copy-Paste nötig, Claude Code liest die Datei
direkt von der Platte. Zwischenablage-Kopie bleibt als Rückfalloption für
Browser ohne File-System-Access-Unterstützung.

**Vom Export zum echten Sheet:** `Design/bake_sprite_lab_export.py` (neu,
2026-08-03) nimmt `sprite_lab_export.json` + das Kandidaten-PNG und backt
daraus das echte 800×448-`outfit_*`-Sheet — ersetzt die frühere, nur für den
Bogen passende formelbasierte `make_bow_sprite()`/`build_bow_sheet()`-
Erzeugung in `export_full_sheets.py` (jetzt deaktiviert, siehe dort) durch
einen item-unabhängigen, wiederverwendbaren Weg. **Wichtiger technischer
Stolperstein:** PIL's `Image.rotate(winkel)` dreht im bildschirmtypischen
y-nach-unten-Koordinatensystem optisch GEGENLÄUFIG zu Canvas'
`ctx.rotate()` (dieselbe Konvention, die das Sprite-Labor und `index.html`
verwenden) — im Skript deshalb bewusst mit umgedrehtem Vorzeichen
(`rotate(-winkel)`), gegen einen Canvas-Referenzlauf abgeglichen. Beim
allerersten Bogen-Bake (siehe unten) wurde zusätzlich sicherheitshalber
direkt per Canvas (Playwright-Skript, nicht Python) gebacken, um jedes
Risiko einer Python/Canvas-Konventions-Abweichung für das erste echte
Ergebnis auszuschließen — das Python-Skript wurde daran kalibriert/verifiziert
und ist jetzt der Standardweg für zukünftige Items.

**Vor dem Zeichnen eines neuen Kandidaten weiterhin gültig:** Ankerpunkt
NICHT die Bounding-Box-Mitte der gesamten Form (kann deutlich neben dem
tatsächlichen Handgriff liegen), Mirror-Frage früh an einem einzelnen Frame
prüfen statt erst am fertigen Sheet — beides jetzt interaktiv im Sprite-Labor
prüfbar statt im Kopf vorausgeplant werden zu müssen.

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

  **Anziehen/Ausziehen: seit 2026-08-03 fertig gebaut** (Design dafür schon
  seit 2026-08-01 festgelegt, aber erst jetzt mit echten Items verbunden).
  `toggleEquip(itemKey, slotField)` in `index.html` existierte als
  Code-Gerüst tatsächlich schon seit Patch 5, lief aber all die Zeit ins
  Leere, weil kein einziges Ausrüstungs-Item im Katalog existierte (nur der
  Manatrank). Bewusst **keine geloggte Aktion** (kein XP, kein
  `action_log`-Eintrag) — reine Kosmetik, kein Vertriebsverhalten. Verbraucht
  das Item in `user_inventory` NICHT (Unterschied zu Verbrauchsgütern wie dem
  Manatrank, die beim Benutzen abgezogen werden) — Klamotten können nicht
  verschwinden. Item-Katalog unterscheidet `category:
  'waffen'|'ruestung'|'accessories'` (→ `EQUIP_SLOT_FIELD` mappt auf
  `profiles.equipped_weapon/armor/accessory`) von Verbrauchsgütern mit
  `effect`-Feld (siehe `useItem()`).

  **Rendering-Ansatz geändert gegenüber dem ursprünglichen Plan:** statt des
  anfangs geplanten flachen `items.image`-Felds (ein statisches PNG als
  Ebene über der ganzen Figur) nutzt Ausrüstung jetzt dieselbe
  Sprite-Sheet-Technik wie der Aussehen-Screen — `items.sheet` (Dateiname
  unter `img/characters/sheets/`, `{g}`-Platzhalter für geschlechtsabhängige
  Varianten wie Waffen). `layersForCharacterProfile()` baut daraus live die
  Ebenen-Liste aus den tatsächlich angezogenen Items
  (`profiles.equipped_*`), gerendert über denselben `createSpriteRenderer()`
  wie überall sonst — konsistent mit der Linie "dynamisch statt statisch"
  (siehe Memory). Das alte `items.image`-Feld/die zugehörige
  `<img>`-Overlay-Logik wurde ersatzlos entfernt, da inzwischen unbenutzt.

  Die bisherigen CLASS_OUTFIT-Klassenitems (Hexer: Zauberstab + blaues
  Cape, Krieger: Holzschwert + Guard Helmet, Schütze: kleiner Rucksack)
  sind jetzt echte Katalog-Items (`sql/patch26_klassenitems.sql`). Neue
  Charaktere bekommen sie automatisch bei der Erschaffung ins Inventar
  gelegt UND angezogen (`grantClassStarterEquipment()`, ausgelöst über ein
  `justCreatedCharacter`-Flag einmalig in `enterApp()` — nicht bei jedem
  Login), sehen also unverändert aus wie bisher, können die Teile aber ab
  jetzt im Inventar ausziehen. Bestehende Profile (die es schon vor diesem
  Patch gab) bekommen ihr Klassenitem einmalig per SQL nachträglich ins
  Inventar + angezogen. `CLASS_OUTFIT`/`layersForClassPortrait` bleiben
  unverändert bestehen — die brauchen weiterhin ein festes Beispiel-Outfit
  für die Vorschauen im Onboarding (Klassenwahl, Aussehen-Screen), wo es ja
  noch gar kein Inventar gibt.

  **Weiterhin offen:** das `reward_item_key`+`qty`-Feld für Quests (Items
  als Quest-Belohnung gewinnen, über das bestehende generische `grantItem()`
  — technisch trivial, aber noch nicht verdrahtet).

  **Schützen-Bogen, seit 2026-08-03 gelöst (`schuetze_bogen`,
  `sql/patch28_schuetze_bogen.sql`):** kein GandalfHardcore-Asset (im Paket
  nicht enthalten), sondern ein handgezeichnetes Pixel-Sprite. Gleiches
  Prinzip wie bei den anderen Klassenitems: echtes Bild-Icon
  (`img/characters/creator/item_schuetze_bogen.png`), automatische
  Start-Ausrüstung bei neuen Schützen, einmaliger Nachtrag für bestehende.

  **Zweite Überarbeitung, noch am selben Tag:** die erste, formelbasierte
  Version (`make_bow_sprite()`, Sinus-Kurve, Positions-Spur 1:1 vom Schwert
  übernommen, siehe Git-Historie von `Design/export_full_sheets.py`) wurde
  vom Nutzer als zu klobig/hässlich empfunden. Ersetzt durch eine von Hand
  gezeichnete, deutlich schlankere Silhouette (erster Entwurf, archiviert
  unter `Design/ItemKonzept/bogen_konzept_v1.png` — laut Nutzer die schönste
  der drei ursprünglichen Entwurfsgrößen). Position UND Rotation wurden pro
  einzelnem Laufzyklus-Frame von Hand im neuen Sprite-Labor (siehe eigener
  Abschnitt oben) abgestimmt — anders als beim ersten Versuch (nur
  Verschiebung entlang der Schwert-Spur, keine Rotation) schwingt der Bogen
  jetzt sichtbar mit der Laufbewegung mit (Rotation von 0° bis −75° und
  zurück über die 8 Frames). Abgestimmte Werte liegen dauerhaft in
  `Design/ItemKonzept/bogen_export.json`, gebackt über
  `Design/bake_sprite_lab_export.py`. **Weiblicher Bogen ist nur eine
  Näherung:** dieselben Werte (Anker/Maßstab/Position/Rotation) wurden 1:1
  auf `outfit_weapon_bow_w.png` übernommen, ohne eigene Abstimmung für den
  weiblichen Körper (bewusste Nutzer-Entscheidung, "näherungsweise
  übernehmen") — sitzt an der Hand nicht ganz so exakt wie beim männlichen
  Schützen. Bei Bedarf: im Sprite-Labor auf Geschlecht "Weiblich" wechseln
  und die 8 Frames eigenständig nachjustieren.

  **`layersForClassPortrait('schuetze', g)` zeigt jetzt auch den Bogen**
  (`outfit_weapon_bow_${g}.png` als letzte/oberste Ebene, wie bei Hexer/
  Krieger) — behebt den zuvor offenen Kosmetik-Punkt (siehe unten, jetzt
  entfernt), dass der Schütze auf dem Klassenwahl-Bildschirm bisher
  unbewaffnet aussah.

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
  ansteht, nicht vorher. **Korrektur (2026-08-02):** die anfängliche
  Linie, freizügige Teile (Bikini/Unterwäsche) aus "Female Clothing"
  grundsätzlich auszusortieren, wurde vom Nutzer wieder aufgehoben — ein
  bisschen Auflockerung schadet dem B2B-Kontext nicht. Bikini/Unterwäsche
  gehören also normal mit zur Outfit-Auswahl dazu, keine pauschale
  Sonderbehandlung mehr nötig.

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
  Bild-Ordner im Repo, es gab bisher keine lokalen Bild-Assets).
  Ursprünglich an drei Stellen in `index.html` eingebaut, seit 2026-08-02 nur
  noch an zweien — der Nutzer wollte es auf dem Login-Bildschirm nicht mehr
  sehen, `.auth-portrait` in `#authScreen` wurde wieder entfernt (erst im
  Dummy getestet, siehe "Profil-Onboarding" oben, dann übertragen).
  - `#page-charakter` (`charArtStack`): `renderCharacterEquipment()` hat
    weiterhin eine `CLASS_BASE_ART`-Map (aktuell nur `krieger` gefüllt) —
    zeigt bei passender Klasse das Basisbild UNTER den bereits bestehenden
    Ausrüstungs-Ebenen (siehe oben), andere Klassen fallen weiter auf den
    Hinweistext zurück. **Unverändert, nicht Teil der Aussehen/Basis-
    Kleidung-Arbeit unten** — eigenständiger, noch offener Punkt.
  `image-rendering:pixelated` überall gesetzt, damit die Pixel-Art beim
  Hochskalieren scharf bleibt statt zu verschwimmen.

  **Klassenwahl-Bildschirm auf 6 angezogene, animierte Beispielcharaktere
  erweitert (2026-08-02/03, seit 2026-08-03 auch im echten `index.html`):**
  `#charCreateScreen` zeigte anfangs nur für Krieger ein Bild
  (`img/characters/krieger.png`, s.o.), Hexer/Schütze hatten Emoji. Nach
  zwei Überarbeitungen (erst statische Einzelbilder pro Klasse+Geschlecht,
  dann — auf Wunsch des Nutzers, der explizit ein **dynamisches**, nicht
  aus flachen Einzelbildern bestehendes Charakterscreen wollte — durch
  `<canvas>`-Elemente ersetzt, siehe "Aussehen-Screen" oben für die
  Technik) zeigt der Bildschirm jetzt für alle drei Klassen ein animiertes,
  live aus Ebenen zusammengesetztes Beispiel: einheitliche Basis-Kleidung
  (Hemd/Hose/Stiefel bzw. Corset/Rock/Socken) + ein klassentypisches Item
  (Hexer: Stick + blaues Cape, Krieger: Holzschwert + Guard Helmet,
  Schütze: Small Backpack, bewusst glatzköpfig (Frisur kommt ja erst im
  Aussehen-Screen danach). `layersForClassPortrait(cls, gender)` +
  `portraitRenderers` in `index.html` (identisch auch weiterhin in
  `dummy-anmeldung.html` vorhanden, dort ohne echten Supabase-Insert). Das
  alte `img/characters/krieger.png` wurde inzwischen (2026-08-03, siehe
  unten bei "Anziehen/Ausziehen") komplett aus dem Repo entfernt —
  überflüssig geworden, seit die Charakterseite denselben Canvas-Renderer
  wie hier nutzt; die sechs zwischenzeitlich erzeugten statischen
  `hexer_m.png`/`hexer_w.png`/etc. waren schon vorher aus demselben Grund
  entfernt worden.

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
