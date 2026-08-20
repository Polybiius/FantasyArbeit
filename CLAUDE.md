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

## Geschäftsmodell / Positionierung, Leitplanken (2026-08-11)

- **Architektur-Prinzip:** Business Engine (CRM-Fakten, Kern-Tabellen/
  `rule_configs`) getrennt von Motivation Engine (XP/Level als abgeleitete
  Schicht aus `action_log`) — entspricht der bestehenden Architektur.
- **PvE statt PvP:** Fortschritt gegen ein gemeinsames Ziel statt
  Mitarbeiter-Ranking, bewusst kein Leaderboard.
- **Beachhead bleibt die eigene Versicherungs-/Vertriebs-Nische**, kein
  branchenübergreifender Sprung, bis ein zweiter echter zahlender Kunde
  ansteht (siehe Multi-Org-Schwelle oben). Die eigentliche Nische ist dabei
  nicht Branche oder Firmengröße, sondern kleine, strukturierte
  Vertriebsteams mit zählbarer, wiederholbarer Aktivität — die
  Gilden-Mechanik ist entsprechend bewusst nie für mehr als ~10-15 Personen
  gedacht, das ist ein Entwurfsparameter, keine technische Zufallsgrenze.
- **Verhaltenswissenschaftliches Fundament: Selbstbestimmungstheorie (SDT,
  Deci & Ryan), nicht Spielautomaten-Konditionierung.** Variable-ratio-
  Verstärkung (Skinner, Verstärkungsmuster von Spielautomaten/Lootboxen)
  wird bewusst NICHT auf eigentliches Vertriebsverhalten oder
  vergütungsrelevante Größen angewendet — regulatorisches Risiko (EU
  Dark-Pattern-Regulierung) und schlechtes Verkaufsargument gegenüber
  HR/Betriebsrat. Stattdessen bleiben die fünf SDT-Säulen (Progression,
  Mastery, Autonomy, Recognition, Belonging) Leitlinie für neue
  Gamification-Bausteine — passt zu bereits Gebautem (Sigil/Skills =
  Mastery, Klassenwahl = Autonomy, Gilde = Belonging). Variable/zufällige
  Belohnung bleibt auf Kosmetik/Nebensächliches begrenzt (z.B. Item-Drops
  wie der tägliche Manatrank).

Marktanalyse, Preismodell, Go-to-Market, Wettbewerbsvergleich (Pipedrive/
Salesforce/Spinify u.a.), Erfolgswahrscheinlichkeits-Einschätzungen, die
Begründung der Nischen-Eingrenzung (verworfene Branchen-Alternativen,
Kolleg:innen-Pilot-Blockade) und der zeitliche Geschäfts-Fahrplan leben
bewusst NICHT hier, sondern in Claudes Erinnerungssystem
(`project_business_fahrplan`, außerhalb des Git-Repos, nur bei
Business-Gesprächen gelesen) — dieser Abschnitt bleibt auf die
Design-Prinzipien beschränkt, die tatsächlich Code-/Feature-Entscheidungen
begründen (Business/Motivation-Engine-Trennung, PvE, Gilden-Größe, SDT).

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
- **Regressions-Suite** (seit 2026-08-17, `~/.local/share/playwright-portable/
  regression_suite.mjs`, Nutzerwunsch "best practice? dann bitte" — kein
  CI/CD, dessen Auslöser noch nicht erreicht ist, siehe "Technische
  Skalierungs-Schwellen" unten): ein wiederverwendbares Skript, das vor
  jeder größeren Änderung an den drei riskantesten Pfaden gegen die echte
  App laufen sollte — Login/rollenbasierte Sichtbarkeit, XP-/Level-
  Berechnung (`computeTotals()`/`levelInfo()`, liest `levelBase`/
  `levelExponent` live aus `rule_configs`, damit der Test auch künftige
  Neukalibrierungen richtig einschätzt), Kanban-Spalten-Zuordnung. Nutzt
  `page.route()`-Interception für alle drei Tests (wie in mehreren
  bestehenden `check_*.mjs`-Skripten) statt echter Schreibvorgänge —
  **schreibt nichts an der echten Datenbank**, unabhängig vom
  RLS-Testmuster mit `supabase db query --linked`. Aufruf: vorher
  `python3 -m http.server <port>` im Repo-Ordner starten, dann
  `node regression_suite.mjs <port>`.
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
  Nutzers, dadurch kein `ksshaskpass`-Problem mehr). **SQL-Patches liefen bis
  2026-08-08 manuell** über den Supabase SQL-Editor beim Nutzer — seitdem gibt
  es eine echte Migrations-Toolchain, siehe eigener Abschnitt
  "Supabase-CLI-Migrationstoolchain" unten.
- **Frontend-Framework-Frage (React/Vue/etc.), geklärt am 2026-08-03:** die
  "eine `index.html`, kein Framework"-Linie oben war ursprünglich eine
  praktische Zwangslage aus der Zeit vor Claude Code (Copy-Paste in GitHubs
  Web-Upload), keine Grundsatzentscheidung — aber auch nach dieser Erkenntnis
  gilt weiterhin "nicht vorbeugend wechseln, erst bei echtem Auslöser"
  (Rule-of-Three-Prinzip auf Tooling übertragen). Der Nutzer wollte dabei
  ausdrücklich **groß denken**: viele B2B-Kunden werden künftig
  unterschiedliche Bausteine brauchen (Kanban, Kundendatenbank, Gamification,
  Statistik, Tagebuch, Dungeon, Questbaum — manche projektorientiert ohne
  Dungeon, manche statistiklastig ohne Kanban). **Wichtige Klarstellung, die
  an diesem Tag herausgearbeitet wurde:** das ist eine Frage der
  **Konfigurierbarkeit** (welche Bausteine sind je Organisation aktiv — löst
  sich über `rule_configs`, z.B. ein `enabledModules`-Schlüssel, unabhängig
  vom Framework) und NICHT automatisch dasselbe wie die Frage "Framework
  oder nicht" (die betrifft nur, wie wartbar/wiederverwendbar der Code
  innerhalb eines Bausteins ist). Ein Framework schaltet keine Module für
  Kunde A ab und für Kunde B an — das bleibt Config-Arbeit, so oder so.
  Baseline-Messung an diesem Tag: `index.html` 3.845 Zeilen/208 KB,
  139 benannte Funktionen, `.contact-card`-Markup real nur an EINER Stelle
  verwendet (Kanban/Dungeon-Liste bauen ihre Kontakt-Darstellung noch
  separat) — also aktuell noch kein echtes Duplikations-Problem, das für
  React sprechen würde. **Konkrete Alarmglocken-Schwellen, ab denen das
  Framework-Thema aktiv wieder aufgegriffen werden sollte** (nicht vorher,
  nicht von selbst):
  1. Der `<script>`-Block nähert sich **~8.000–10.000 Zeilen**.
  2. Dieselbe Karten-/Listen-Darstellung (Kontakt-Karte, Dungeon-Karte, o.ä.)
     wird über **3 oder mehr** `render*`-Funktionen hinweg kopiert statt an
     einer Stelle definiert.
  3. Der Nutzer meldet einen **echten** (nicht hypothetischen) Stale-UI-Bug,
     der durch eine vergessene manuelle `render*()`-Nachbestellung entstanden
     ist.
  4. Mehrere Personen bearbeiten das Frontend gleichzeitig.
  Tritt eine dieser vier Bedingungen ein, das Thema von selbst wieder
  ansprechen — nicht erst auf Anstoß warten (Ausnahme zur sonstigen
  Zurückhaltung bei Tech-Wechseln, siehe `feedback_tech_evolution_on_trigger`
  in der Erinnerung).

## Technische Skalierungs-Schwellen ("Enterprise"-Infrastruktur)

Festgelegt am 2026-08-04, auf ausdrücklichen Nutzerwunsch, nach einer
Diskussion über einen "Vibe Coding"-Kritik-Post (Buzzword-Liste:
Kubernetes, Docker, S3, SQS, CI/CD, Terraform, Rate Limiting, Load
Balancer, High Availability, RPC, u.a.). Ziel: dasselbe Prinzip wie bei der
Frontend-Framework-Schwelle oben (konkrete, prüfbare Auslöser statt
vagem "irgendwann später") auch auf die übrige Infrastruktur ausweiten.
**Aktueller Stand bewusst: fast nichts davon ist gebaut, und das ist
richtig so** — Supabase/GitHub Pages übernehmen Server-Betrieb, Skalierung,
Firewall, Storage (S3-kompatibel) bereits managed. Nicht vorbeugend bauen,
sondern auf genau diese Auslöser warten:

- **Automatische Backups (Supabase Pro-Plan-Upgrade):** sobald echte
  Kolleg:innen anfangen, Kundendaten einzutragen, auf die sie sich
  verlassen (siehe `project_supabase_backups`-Erinnerung).
- **Multi-Org-Loskopplung** (`DEFAULT_ORG_ID` fest verdrahtet → echte
  Organisationsauswahl/-Onboarding): sobald eine zweite, tatsächlich
  zahlende Vertriebsorganisation real ansteht — nicht nur angedacht oder
  als Fernziel erwähnt. **Onboarding-Modell geklärt (2026-08-17): kein
  Self-Service — der Nutzer selbst richtet jede neue Kundenorganisation
  persönlich nach deren Wünschen ein** (per SQL, wie bisher auch), kein
  Assistenten-Interface nötig. Trotzdem noch echte Arbeit übrig: die
  Registrierungsstelle im Code (`index.html`, `profiles`-Insert) trägt
  aktuell JEDEN neuen Nutzer fest auf `DEFAULT_ORG_ID` ein, unabhängig
  davon, wie viele `organizations`-Zeilen in der DB existieren — braucht
  mindestens einen Einladungslink/-code pro Organisation, damit sich
  Mitarbeiter der richtigen Firma zuordnen. Automatische Regelwerk-
  Erzeugung (Questbaum + tägliche Quests + Provisions-/Erfolgsmessungs-
  Logik automatisch statt von Hand pro Kunde befüllen) ist **explizit
  eine spätere, eigene Aufgabe**, kein Teil dieser Schwelle — Details/
  Kontext in `project_business_fahrplan`, Einträge 2026-08-17.
  **Konzept-Skizze vom Nutzer, 2026-08-18, noch nicht gebaut:** wer sich
  registriert, landet zunächst in einem organisationslosen Gesamt-Pool
  aller angemeldeten Nutzer (nicht automatisch `DEFAULT_ORG_ID`, wie es
  der Code heute noch macht). Der Nutzer (als Organisationsinhaber)
  durchsucht diesen Pool und lädt einen erkannten Kollegen gezielt in
  seine Organisation ein. Alternative für später: ein QR-Code, den ein
  Mitarbeiter abfotografiert und dadurch direkt der richtigen
  Organisation zugeordnet wird, ohne Pool-Suche. Beides nur Konzept,
  keine Migration/kein Code dafür — relevant für den Tag, an dem diese
  Schwelle tatsächlich erreicht wird.
- **Rate Limiting:** sobald eine Organisation außerhalb der eigenen
  echten Zugriff bekommt (fremde Nutzer, potenziell missbräuchlich oder
  durch schieres Volumen andere Organisationen beeinträchtigend).
- **CI/CD + automatisiertes Testen:** dieselbe Schwelle wie beim
  Framework-Wechsel oben — mehrere Personen bearbeiten das Repo
  gleichzeitig, ODER ein Deploy verursacht einen echten (nicht
  hypothetischen) Produktionsfehler, den ein einfacher Test vorher
  gefangen hätte.
- **Kubernetes/Docker/Terraform/Load Balancer/eigene High-Availability:**
  bewusst KEIN Zahlen-Trigger — diese Themen werden erst relevant, wenn
  Supabase/GitHub Pages an eine nachweisbare Grenze stoßen (eine konkrete
  Compliance-Anforderung, ein Preis-Limit bei echter Skalierung, ein
  Performance-Limit). Nicht vorher spekulieren, sondern gegen das
  tatsächliche Supabase-Limit bauen, sobald es auftritt — nicht die ganze
  Liste auf einmal.

Diese Liste ist absichtlich nicht abschließend — ein neues Thema verdient
erst dann eine eigene Schwelle, wenn es wichtig genug wird, statt vage
"später" zu bleiben.

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
  `character_class` ('zauberer'|'krieger'|'schuetze', seit Patch 29 — hieß
  vorher 'hexer', siehe "Charakterklassen" unten), `role` ('admin'|'member'),
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
  "Tagebucheintrag" (Liste der Tage, an denen der Kontakt erwähnt wurde).
  **Korrektur 2026-08-04, kehrt eine frühere Entscheidung um:** ursprünglich
  bewusst nicht löschbar angelegt ("ein Tagebucheintrag bleibt stehen wie
  geschrieben") — der Nutzer hat das explizit widerrufen: "wenn ich den Text
  lösche, ist es gelöscht, dann gibt es keine Erwähnung mehr." Seitdem prüft
  `pruneRemovedMentions(today, row)` in `index.html` bei jedem Tagebuch-Save,
  ob das `@Name`-Kürzel (Leerzeichen entfernt, gleiche Zusammensetzung wie
  beim Einfügen) noch irgendwo im Text der 5 Felder steht — fehlt es, wird
  **nur diese eine** Markierung gelöscht (`journal_mentions_delete_own_only`-
  RLS-Policy existierte für genau diesen Fall bereits seit Patch 16, keine
  neue SQL nötig). Andere Markierungen desselben Tages bleiben unberührt,
  auch wenn ein unbeteiligtes Feld bearbeitet wird — per Playwright gegen die
  echte Datenbank verifiziert (Schreiben behält, Löschen entfernt,
  Fremd-Markierungen bleiben unangetastet).
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
- `schema_patches` — Changelog-Popup (seit Patch 32, live, siehe eigener
  Abschnitt unten). `patch_number`/`title`/`applied_at`, kein `org_id`-Bezug
  (beschreibt den DB-Zustand insgesamt,
  nicht eine Organisation). Trägt sich pro künftigem Patch selbst ein.
- `termine` — echter Termin-Kalender (seit Patch 33, live, siehe eigener
  Abschnitt "Echter Termin-Kalender" oben). `owner_id`, optionale
  `contact_id`/`location_id`, Freitext-`title`, `start_at`/`end_at`, seit
  Patch 40 zusätzlich optionales `kanal` (`'online'|'buero'|'betrieb'`,
  siehe Abschnitt "Questbaum-Übersetzung, erster Schritt" unten). Rein
  persönlich, aber mit Admin-Leserechte-Ausnahme (anders als
  `journal_entries`). Keine Überschneidungs-Prüfung, Doppelbuchungen sind
  einfach unabhängige Zeilen.
- `contact_activities` — echte CRM-Aktivitäten am Kontakt (Anrufe, später
  Emails), seit Patch 37, siehe eigener Abschnitt "Kontakt-Chronik" oben.
  Getrennt von `action_log` (das bleibt reine XP-Buchhaltung), optional
  über `action_log_id` mit der zugehörigen XP-Buchung verknüpft. Gleiches
  RLS-Muster wie `termine`.
- `tasks` — echte, abhakbare Aufgaben (seit Patch 51, live, siehe eigener
  Abschnitt "Aufgaben-System" unten). `title`, optionales `due_date`,
  optionaler `contact_id`, `source_type` (`'manual'|'geburtstag'|
  'wiedervorlage'`). Gleiches RLS-Muster wie `termine`. **Kein
  "erledigt"-Zustand** — Abhaken löscht die Zeile direkt, bewusst anders
  als der Rest des Projekts (kein `done_at`-Feld).

### Supabase-CLI-Migrationstoolchain, seit 2026-08-08

Löst das in CLAUDE.md selbst lange angekündigte Ziel ein ("dieses Muster
[nummerierte SQL-Dateien + manueller SQL-Editor] beibehalten, bis eine
echte Migrations-Toolchain eingeführt wird") — auf Nutzerwunsch
eingerichtet, nachdem die Dashboard-Warnung `42P01: relation
"supabase_migrations.schema_migrations" does not exist` den Anstoß gab.

**Setup:** Supabase-CLI liegt als normale Dev-Abhängigkeit im
`package.json` (`npm install` holt sie automatisch mit, wie ESLint —
bewusst NICHT wie Playwright als separates portables Tool außerhalb des
Repos, weil dies echtes Projekt-Werkzeug ist, kein reines
Claude-Code-Testwerkzeug). Projekt ist per `supabase link --project-ref
aaqbbkcghxldsbhqwcyh` verknüpft. Login lief einmalig über `supabase
login` im echten Terminal des Nutzers (öffnet Browser-OAuth) — der
dabei lokal gespeicherte Zugang wird von der Claude-Code-Sandbox
automatisch mitverwendet (gleiches Benutzerkonto, gleiches `$HOME`),
kein Token wurde je durch den Chat geschickt.

**Baseline:** der komplette bisherige DB-Stand (20 Tabellen, entspricht
Patch 1–39) wurde per `supabase db pull` einmalig als erste Migration
eingefroren (`supabase/migrations/20260808145403_remote_schema.sql`),
danach die Frage "Update remote migration history table?" mit Ja
bestätigt — das trägt in der bisher fehlenden
`supabase_migrations.schema_migrations`-Tabelle nur einen Vermerk
"dieser Stand ist bereits abgedeckt" ein, ändert keine echten Daten.
Behebt nebenbei die eingangs erwähnte Dashboard-Warnung.

**Wichtiger technischer Stolperstein:** `supabase db pull`/`db diff`
brauchen im Hintergrund Docker (lokale Schatten-Datenbank zum
Diffen) — das ist in der Claude-Code-Sandbox (VS-Code-Flatpak) nicht
erreichbar, selbst wenn Docker/Podman auf dem eigentlichen System
läuft (gleiche Einschränkung wie beim `flatpak`-Befehl selbst). Der
Nutzer hat deshalb den einmaligen `db pull` in seinem eigenen echten
Terminal ausgeführt, dort ist Docker vorhanden (Docker 29.6.2 UND
Podman 5.8.4 laut Nutzer-Check).
**`supabase db push` braucht dagegen KEIN Docker** (nur eine direkte
Postgres-Verbindung, keine lokale Diff-Datenbank) — funktioniert
deshalb direkt aus der Claude-Code-Sandbox heraus, per Testmigration
verifiziert (`20260808150221_claude_push_test.sql`, folgenlos, nur
`SELECT 1`).

**Neuer Workflow für künftige Schema-Änderungen:**
`supabase migration new <name>` legt eine zeitgestempelte Datei unter
`supabase/migrations/` an (ersetzt `sql/patchN_....sql` als Ablageort
für alles Neue — die alten `sql/`-Dateien + `PATCH_LOG.md` bleiben als
historisches Archiv der Patches 1–39 unangetastet liegen, werden aber
nicht fortgeführt). `supabase db push` wendet sie auf die echte
Datenbank an.

**Verbindliche Regel, vom Nutzer am 2026-08-08 ausdrücklich so
festgelegt (kein Blankoscheck wie bei `git push`):** Claude Code führt
`supabase db push` für echte inhaltliche Änderungen **immer erst nach
explizitem Go des Nutzers** aus — Migration schreiben, erklären was sie
bewirkt, warten, dann erst pushen. Gilt uneingeschränkt weiter: bei
destruktiven Operationen (`DROP`, `DELETE`) explizit warnen, siehe
allgemeine Regel weiter unten. `supabase/.temp/` ist gitignored (rein
lokaler Verbindungs-Cache, keine Geheimnisse drin, aber maschinenspezifisch).

## Sicherheitsmodell (RLS), zum Verständnis

Fast jede Tabelle hat `org_id` und eine RLS-Policy, die auf eine Hilfsfunktion
`public.current_org_id()` zurückgreift (liest `org_id` aus `profiles` für
`auth.uid()`). Für Admin-Prüfung gibt's `public.is_admin()`. Für Kontakt-Sichtbarkeit
`public.contacts_shared_for_org()` (liest die Regelwerk-Einstellung).
**Prinzip, das durchgehend gilt:** Sichtbarkeit ist meist konfigurierbar
(privat vs. team-weit geteilt), Schreibrechte sind enger (Eigentümer + Admin).

**Verschlüsselung, dokumentiert 2026-08-16 (läuft automatisch, kein
eigener Code):** Daten in Übertragung sind durchgehend TLS-verschlüsselt
(Browser↔Supabase per HTTPS/PostgREST, Browser↔GitHub Pages per HTTPS) —
beides von den jeweiligen Plattformen erzwungen, nicht selbst
konfiguriert. Daten im Ruhezustand (Postgres-Datenbank + Storage-Buckets
`journal-photos`/`contact-files`) sind von Supabase serverseitig
verschlüsselt (AES-256, Standard bei jedem Supabase-Projekt, unabhängig
vom Plan). Dieser Absatz ist der Beleg dafür, kein technischer Auftrag.

## Level-/XP-System (wichtig für jede Regelwerk-Änderung)

- Aktuelle Kurve (seit Patch 50, 2026-08-17): `levelBase = 5.80`,
  `levelExponent = 1.5` → `XP für Level L = 5.80 * L^1.5`. Ziel: bei
  durchschnittlicher Vertriebsleistung soll Level 100 nach **10 Jahren**
  erreicht werden (200 Arbeitstage/Jahr angenommen).
- Diese Kalibrierung wurde mehrfach neu gerechnet, wenn sich das Regelwerk
  änderte (z.B. als Quest-Boni dazukamen, als "Ansprache" vereinheitlicht
  wurde, als Konversions-Bonus/-Malus eingeführt wurde). **Jede substanzielle
  Änderung an XP-Werten oder Quest-Häufigkeit sollte die Kurve neu
  kalibrieren** — Methode: wöchentliches XP-Budget aus angenommener
  Aktivität hochrechnen, `levelBase` so wählen, dass die Summe aller
  Level-Schwellen 1–99 dem 10-Jahres-Gesamt-XP entspricht.
- **Größte bisherige Neukalibrierung (Patch 50, 2026-08-17):** alle
  76 Questbaum-Stufen + 11 Epics bekamen ein `bonus`-Feld, gleichzeitig
  wurde klargestellt, dass Questbaum-Stufen **Jahresquests** sind
  (Geschäftsjahr = Kalenderjahr, siehe eigener Abschnitt
  "Questbaum: Jahres-Reset..." unten) — dieselbe Stufe ist damit pro Jahr
  einmal, aber über mehrere Jahre hinweg mehrfach verdienbar. Weil das
  reale zusätzliche Lebenszeit-XP bedeutet (nicht nur eine Verschiebung
  wie bei der Krankenhaus-Meister-Migration), stieg `levelBase` von 4,70
  auf 5,80 (+23,3% Gesamt-XP bis Level 100: 185.656→228.876). Methodik-
  Detail: pro Stufe wurde geschätzt, in wie vielen der 10 Jahre eine
  konstant gute Person sie realistisch erreicht (Einstiegsstufe ~9-10/10,
  Top-Stufe ~1-2/10), diese erwarteten Lebenszeit-Summen wurden zur
  Gesamt-Zielsumme addiert, dann `levelBase` neu gelöst.
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

Drei Klassen: Zauberer (blau-violett), Krieger (rot/Ember), Schütze (grün/Gold).
Klassenwahl ist **einmalig, dauerhaft** (kein Umskillen), aber ein Admin kann
über einen versteckten Klassenschalter im Header testweise wechseln.
Farbthema ist NICHT nur ein Akzent, sondern durchdringt die ganze Optik
(Hintergrund-Glow, Panels, Rahmen — siehe `CLASS_THEMES` in `index.html`).
Regelwerk ist über alle Klassen hinweg **identisch** (nur Optik/Begriffe
unterscheiden sich) — bewusste Design-Entscheidung, keine Einschränkung.

**Umbenannt von "Hexer" zu "Zauberer" (Patch 29, 2026-08-03):** es gibt keine
"Hexerin" — die einzige echte weibliche Form wäre "Hexe", und die ist negativ
konnotiert. Deshalb komplett auf Zauberer/Zauberin umbenannt, nicht nur der
Anzeige-Text, sondern auch der interne Schlüssel (`profiles.character_class`,
Item-Keys `hexer_stab`/`hexer_cape` → `zauberer_stab`/`zauberer_cape` samt
Bilddateien) — siehe `sql/patch29_zauberer_umbenennung.sql`. Historische
Verweise auf den alten Namen (z.B. längst gelöschte Dateien wie
`hexer_m.png`) weiter unten in diesem Dokument sind bewusst unverändert
gelassen, sie beschreiben, wie etwas zum jeweiligen Zeitpunkt hieß.

Klassenabhängige Begriffe für dieselbe Funktion:
| Funktion | Zauberer | Krieger | Schütze |
|---|---|---|---|
| Gilde | Orden | Legion | Bund |
| Mitglied hinzufügen | Arkanisten hinzufügen | Legionäre hinzufügen | Bundesbrüder hinzufügen |
| Kundendatenbank | Arkanes Register | Kriegsarchiv | Jägerchronik |
| Kanban | Questpfad | Gildenbrett | Feldzug |
| Verkaufsstatistik | Arkanes Kompendium | Kriegskasse | Trophäenkammer |

**Verkaufsstatistik-Seite (`#page-statistik`, Nav-Reiter "Kompendium"/
"Kriegskasse"/"Trophäenkammer" je Klasse), seit 2026-08-03:** bisher nur ein
leerer Seiten-Rahmen (`updateStatistikLabels()` in `index.html`, gleiches
Muster wie `updateKanbanLabels()`/`updateContactLabels()` — Nav-Button-Text
UND Seiten-Überschrift ändern sich mit der Klasse). In der Navigation direkt
unter "Abenteuerlog" einsortiert — für ein normales Mitglied damit der
letzte sichtbare Reiter, bei einem Admin kommen wie gehabt noch "Produkte"
und "Fehlerprotokoll" danach. Die eigentlichen Verkaufsstatistiken (Inhalt)
sind ein separater, noch offener Bauschritt.

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
Klassenkarten auf Zauberer/Krieger/Schütze (männlich) oder
Zauberin/Kriegerin/Schützin (weiblich). Das betrifft **nur** die Karten-Texte
in diesem einen Screen — `CLASS_LABELS` (Klassenanzeige im Header nach dem
Einloggen, "Klasse: Zauberer") und alle klassenabhängigen Begriffe oben in
dieser Tabelle (Gilde/Kanban/Kundendatenbank) enthalten das Wort
Zauberer/Krieger/Schütze selbst nicht und brauchten deshalb keine Anpassung.
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
  Fragt seit dem Termin-Kalender (siehe eigener Abschnitt oben, Patch 33)
  zusätzlich nach Start-/Endzeit und legt bei Eingabe einen echten
  Kalendertermin an — überspringbar, sowohl über den Dungeon-Button als
  auch beim Ziehen einer bestehenden Karte.
- → Nicht erschienen: **nur von Ersttermin vereinbart aus**, sonst Abbruch.
  Loggt `termin_nicht_wahrgenommen` (−2 XP, der lange geplante
  Konversions-Malus).
- → Angebot versendet: Aktion `pitch`, danach optionales Popup
  "Bedarfsanalyse geführt?" (kann übersprungen werden). **Kein**
  Termin-Popup — ein verschicktes Angebot ist kein Treffen.
- → Zweittermin: dieselbe Aktion `pitch` + dieselbe Bedarfsanalyse-Nachfrage
  wie Angebot versendet, zusätzlich aber (seit Patch 33, extra entkoppelt)
  dasselbe überspringbare Termin-Popup wie bei Ersttermin — ein Zweittermin
  ist ein echtes Treffen.
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

## Kontakt-Chronik: Anruf/Email-Aktivitäten + CRM/XP-Trennung, seit Patch 37 (2026-08-07)

Auf Nutzerwunsch entstanden: die am selben Tag zuvor gebaute Chronik am
Kontakt (siehe unten, ursprünglich nur ein einfacher gemischter Feed aus
`action_log`) wurde nach Nutzer-Feedback ("für das wahre CRM sind die
XP-Aktionen nicht sooo relevant … wann ein Kunde angerufen worden ist, was
besprochen wurde, wann eine Email empfangen wurde — ähnlich wie in
Salesforce") grundlegend erweitert. Referenzpunkt des Nutzers ist explizit
Salesforce ("Log a Call"/NE-Erfassung).

**Neue Tabelle `contact_activities`** (`sql/patch37_crm_chronik.sql`) —
bewusst **getrennt von `action_log`**, das bleibt reine XP-Buchhaltung,
unangetastet. Felder: `type` ('anruf'/'email'), `outcome` (bei Anruf
'erreicht'/'nicht_erreicht' — das Nutzer-Vorbild "NE" aus Salesforce; bei
Email 'geschrieben'/'empfangen'), `betreff` (nur Email), `inhalt`
(Notiz-/Email-Text), `occurred_at` (editierbarer Zeitpunkt, Default jetzt).
**Bewusst genau die Felder, die eine spätere echte Email-Integration
bräuchte** (Nutzerwunsch: "kannst du das Fundament so erstellen, dass wir
das in Zukunft anbinden können?") — vorerst werden sie von Hand befüllt,
eine Integration würde nur noch `betreff`/`inhalt`/`occurred_at`
automatisch statt manuell setzen, keine Schema-Änderung nötig. RLS wie bei
`termine`: rein persönlich mit Admin-Leserechte-Ausnahme, Team-Sichtbarkeit
unter Kolleg:innen bewusst nicht Teil dieses Patches (siehe unten).

**XP hängt weiterhin dran** ("hinter diesen Dingen sind auch XP geknüpft,
die XP ist das spielerische Element" — ausdrückliche Nutzer-Klarstellung,
nachdem ein erster Entwurf Anruf/Email versehentlich XP-frei geplant
hatte). Vier neue, modest bemessene Aktionen im Regelwerk:
`anruf_erreicht` (4 XP), `anruf_nicht_erreicht` (1 XP, belohnt den
Versuch/die Ausdauer), `email_geschrieben` (3 XP), `email_empfangen`
(1 XP) — bewusst **keine** Neukalibrierung der Level-Kurve, da
gelegentliches manuelles Zusatz-Loggen ohne Quest-Bindung, kein
substanzieller Anteil am wöchentlichen XP-Budget. `contact_activities.
action_log_id` verknüpft optional die zugehörige XP-Buchung — dadurch
zeigt die Chronik **eine** Zeile pro Ereignis (nicht zwei), mit der XP-Zahl
als optionalem Badge statt als eigener Log-Zeile.

**Chronik zeigt jetzt zwei getrennte Sichtbarkeits-Ebenen** statt eines
unsortierten Gesamt-Feeds (`CRM_RELEVANT_ACTIONS`/`ACTIVITY_LINKED_ACTIONS`
in `index.html`, direkt bei `renderContactChronikTab()`):
- **Immer sichtbar** ("wahre CRM-Fakten", nach Nutzer-Aufzählung: "Datum
  eines Telefonats oder auch nur des Versuchs, Email geschrieben, Email
  empfangen, terminiert, Termin wahrgenommen, verkauft, Absagen und
  sowas"): die neuen Anruf-/Email-Aktivitäten, Termine, Verkäufe, sowie die
  handfesten Vertriebsschritte aus `action_log`
  (`termin_vereinbart`/`termin_wahrgenommen`/`pitch`/`kundenausbau`/
  `abschluss`/`empfehlung`/`bedarfsanalyse`). Die zugehörige XP-Zahl ist
  hier nur ein optionales Badge.
- **Nur mit eingeschaltetem Schalter sichtbar**: die reinen XP-Grind-
  Aktionen (Ansprache, Kalttelefonie, "5 Nummern gewählt",
  Bestandskunde kontaktiert, Fachinfo recherchiert, Gruppentermin,
  Boss-Encounter) — diese Zeilen fehlen komplett aus der Chronik, bis der
  Schalter aktiv ist, dann samt XP-Zahl.

**Neuer persönlicher Schalter** (`profiles.chronik_show_xp`, Default
false): Einstellungen → neue Kachel "Kontakt-Chronik" (gleiches
Kachel-Muster wie "Kalender"/"Provision & Planungsziele"), eine Checkbox
"XP-Werte in der Kontakt-Chronik mit anzeigen". Steuert **nur** die
Sichtbarkeit der XP-Zahlen/-Zeilen, nicht Anruf/Email/Termin/Verkauf
selbst — die sind immer da.

**Bedienung**: neuer Knopf "Anruf/Email loggen" am Kontakt (neben "Aktion
loggen"/"Termin eintragen"), öffnet `contactActivityModal` — Typ-Auswahl
(Anruf/Email) über dasselbe `.view-switch`-Toggle-Muster wie überall im
Projekt (keine nativen Radios, siehe Lehre vom selben Tag beim
Serientermin-Ende-Feld), je nach Typ ein passendes Ergebnis-Toggle
(Erreicht/Nicht erreicht bzw. Geschrieben/Empfangen), Notizfeld, editierbarer
Zeitpunkt. Respektiert das normale Tages-Energie-Budget wie jede andere
Aktion.

**Bewusst noch nicht Teil dieses Patches** (siehe [[project-roadmap-prioritaeten]]):
Team-Sichtbarkeit der Chronik bei geteilten Kontakten — der Nutzer wollte
das explizit erst später besprechen ("wir müssen die Datenbank komplett
neu bearbeiten", noch ohne Details) und echte Email-Integration
(IMAP/Weiterleitung o.ä., nur das Datenfundament ist vorbereitet).

## Einstellungen: Registry-getriebenes Fundament, seit 2026-08-07

Auf Nutzerwunsch ("ich möchte mir dir heute eine grundidee ein fundament
für die einstellungen gießen") umgebaut, bevor die Seite über die bisher 3
Themen-Kacheln hinauswächst — Auslöser war ein vom Nutzer gesehenes Video
mit einer als vorbildlich empfundenen Einstellungen-UX, aus der er
Stichworte mitbrachte (instant-apply Toggles, Save-Bar bei Identitätsfeldern,
Gruppierung statt langer Liste, Advanced-Klappe, Suche mit Highlighting,
Modified-Badge, Undo, Danger Zone). **Wichtig für die Zusammenarbeit:** der
Nutzer verstand das Registry-Prinzip trotz zweier Erklärversuche nicht
wirklich — hat aber grünes Licht gegeben, nachdem klar war, dass es
Industriestandard ist ("wenn das best practice ist ... dann bitte"). Bei
ähnlich abstrakten Architektur-Erklärungen künftig nicht auf vollständigem
Verständnis bestehen, sondern die Best-Practice-Einordnung anbieten und bei
Zustimmung einfach bauen (siehe [[feedback_defer_to_best_practice_when_confused]]).

**Kernidee:** `SETTINGS_REGISTRY` (Liste aller Einstellungen) +
`SETTINGS_GROUPS` (Themen-Kacheln: Profil, Provision & Planungsziele,
Kalender, Kontakt-Chronik) in `index.html` — eine neue Einstellung ist EIN
Eintrag in der Liste (`id`, `group`, `label`, `desc`, `type`
toggle/text/number/heading/alias, `field`), Rendering/Gruppierung/Suche/
Advanced-Klappe laufen automatisch mit, statt wie vorher pro Einstellung
vier Code-Stellen von Hand zu pflegen (HTML, Laden, Speichern, jetzt auch
Suche). **Bei jeder künftigen neuen Einstellung diesem Muster folgen**,
nicht wieder Handarbeit einführen.

**Zwei Speicher-Verhalten, je nach Feldtyp:**
- **Toggles** speichern sofort bei Klick (`settingsToggleChanged()`), kein
  Save-Button. Danach ein Toast mit "Rückgängig" (macht die DB-Änderung per
  erneutem Update rückgängig, kein echtes Undo-System) und ein
  Sitzungs-Badge pro Gruppen-Kopfzeile ("2 geändert") — zählt Interaktionen
  seit Seitenaufruf, wird durch Rückgängig NICHT wieder heruntergezählt
  (bewusst einfach gehalten, reine Rückmeldung "das hast du heute
  angefasst").
- **Text-/Zahlenfelder** sammeln sich in `settingsPending` und einer
  fixierten Save-Bar unten (Speichern/Verwerfen, `#settingsSaveBar`) — taucht
  erst auf, wenn der Wert wirklich vom geladenen Profil-Wert abweicht.

**Suche** (`settingsApplySearch()`) filtert Titel+Beschreibung aller
Registry-Einträge, hebt Treffer mit `<mark>` hervor, klappt Treffer-Gruppen
automatisch auf. `type:'alias'`-Einträge (aktuell nur "Arbeitszeiten") sind
reine Such-Stichworte für Custom-Widgets ohne eigenes Registry-Feld,
`type:'heading'` sind Zwischenüberschriften innerhalb einer Gruppe
(z.B. "Individuelle Provision" vs. "Persönliche Planungsziele" innerhalb
der Provision-Gruppe).

**Advanced-Mechanismus** (`entry.advanced:true`, "Erweitert anzeigen"-Link
pro Gruppe) ist gebaut, aber **aktuell auf keinem einzigen Eintrag gesetzt**
— der Nutzer wusste beim Bauen noch nicht, was da reingehört ("Zukunftsmusik").
Nicht von selbst nachträglich Felder als advanced markieren, nur wenn der
Nutzer das konkret anstößt.

**Neue Profil-Gruppe** (`real_name`, `company`) — vorher nur einmalig im
Profil-Onboarding editierbar, jetzt jederzeit nachträglich änderbar. Der
**Charaktername** (`display_name`) bewusst NICHT mit reingenommen — der ist
bereits an anderer Stelle editierbar (`#nameInput` im Header, seit
`profileNextBtn`/Onboarding-Ära bestehender Code, Zeile ~2283 in
`index.html`), eine zweite Editierstelle hätte nur Sync-Verwirrung gestiftet.

**Danger Zone** (rot abgesetzt, `.card.settings-danger-zone`) mit
"Account löschen"-Button — **bewusst nur die Optik/das Bestätigungs-Modal
gebaut, das eigentliche Löschen ist NICHT angebunden** (Modal sagt das dem
Nutzer auch explizit). Grund: vorher muss geklärt werden, was mit
Kontakten/Dungeons (`owner_id`), Verkäufen, Tagebucheinträgen passiert, die
dem zu löschenden Account gehören — ein eigenes, noch nicht geführtes
Gespräch, keine Kleinigkeit nebenbei. Beim nächsten Anstoß zu diesem Thema:
erst durchsprechen (siehe genereller Grundsatz oben), dann erst SQL/Code.

**CSS-Stolperstein, falls das Muster nochmal auftaucht:** eigene
Farb-Overrides auf bereits bestehenden Klassen (`.card`, `.cal-nav-btn`)
greifen nur, wenn die Spezifität höher ist als die Basisregel — ein reiner
neuer Klassenname mit gleicher Spezifität (0,1,0) verliert gegen die
später im Stylesheet stehende Basisregel, unabhängig davon, wo im Dokument
die neue Regel steht. Lösung: beide Klassen kombinieren
(`.card.settings-danger-zone`, `.cal-nav-btn.settings-save-bar-save`) statt
nur die neue Klasse allein zu verwenden.

**Zwei Nachbesserungen, noch am selben Tag (2026-08-07), beide auf direktes
Nutzer-Feedback:**

1. **Optik-Politur:** native Checkboxen/zu schmale Eingabefelder/Monospace-
   Fließtext wirkten "klobig". Ersetzt durch einen echten Pill-Schalter
   (`.settings-switch`, folgt automatisch der Klassen-Akzentfarbe),
   volle-Breite dunkle Inputs (`.settings-input`), normale Fließschrift
   für Beschreibungen (`.settings-field-desc`, nicht mehr das
   wiederverwendete `.empty-page-hint`) und weniger Trennlinien.
2. **Startseite von Balken auf Kacheln umgebaut:** die anfängliche
   Gruppen-Übersicht (4 volle-Breite aufklappbare Balken) fühlte sich laut
   Nutzer nicht stimmig an ("diese großen Rechtecke... ist nicht meins") —
   passte auch nicht ins sonstige Kachel-Vokabular der App (Dungeons,
   Gilde, Inventar, Produkte laufen alle über `.dungeon-tile-grid`/
   `.dungeon-tile`, "Kachel statt Liste" war schon beim Produktkatalog
   ausdrücklicher Nutzerwunsch, 2026-08-03). Jetzt: `buildSettingsTileGridHtml()`
   zeigt die 4 Gruppen als kompakte Icon-Kacheln (Symbol, Name, Untertitel
   = Feldanzahl oder "N geändert"), Klick auf eine Kachel öffnet
   `openSettingsGroupModal(gid)` — ein `.loc-modal` mit den Feldern dieser
   EINEN Gruppe, exakt wie beim Produkt-Detail-Modal. Danger Zone bleibt
   bewusst eine eigene rote Karte außerhalb des Kachel-Rasters (nur ein
   Button, keine Feldliste — keine "vielen großen Rechtecke" mehr, aber
   auch keine künstliche Vereinheitlichung um der Einheitlichkeit willen).
   Save-Bar/Toast bekamen `z-index:1002` (über dem Modal, `z-index:1000`),
   da Text-/Zahlenfelder jetzt im Modal liegen. Suche filtert jetzt die
   Kacheln (zeigt nur Gruppen mit Treffern, hebt den Kachel-Namen hervor)
   und hebt zusätzlich die passenden Felder hervor, sobald das jeweilige
   Gruppen-Modal offen ist (`settingsHighlightFieldsInScope()`). Die
   Arbeitszeiten-Tagesreihen (Checkbox+zwei Uhrzeiten pro Wochentag)
   brachen im schmaleren Modal (480px statt voller Kartenbreite) hässlich
   um — neues kompaktes `.az-day-row`-Layout (Label links, beide Uhrzeiten
   rechts als Paar) behebt das, unabhängig von Bildschirmbreite.

## Sicherheits-Durchgang: XSS-Escaping nachgerüstet, 2026-08-07

Auf Nutzeranfrage ("codebasescan für key tokens api ... full security audit")
zwei getrennte Prüfungen gemacht, statt vorschnell Infrastruktur zu bauen,
die laut den "Technische Skalierungs-Schwellen" (siehe oben) noch nicht
gebraucht wird — Rate Limiting z.B. bewusst NICHT gebaut (Supabase drosselt
Login-Versuche bereits selbst, und der dort dokumentierte Auslöser —
"eine Organisation außerhalb der eigenen bekommt Zugriff" — ist noch nicht
erreicht).

1. **Secret-Scan** (`grep -r` nach Service-Role-/Private-/API-Key-Mustern
   über das ganze Repo): sauber. Der einzige Key im Code ist der
   Supabase-Anon-Key — der ist absichtlich öffentlich, siehe "Tech-Stack"
   oben (RLS statt Geheimhaltung). Diese Architektur hat strukturell gar
   keinen Ort für ein verstecktes Backend-Geheimnis.
2. **XSS-Escaping-Lücke, echt und verbreitet gefunden und behoben:**
   `escHtml()` (Helferfunktion ganz oben im Skript) wurde an sehr vielen
   Stellen, an denen Datenbank-Text per `innerHTML` gerendert wird, schlicht
   vergessen — betraf u.a. den zentralen `field()`-Helfer in der
   Kontaktdetail-Ansicht (Telefon/E-Mail/Wohnort/Bedarf-Ist/-Wunsch/Notizen
   auf einen Schlag), die Kontakttabelle, Kanban-Karten, die
   Handlungen/Chronik-Listen (`action_log.context` — hängt oft direkt am
   Kontaktnamen), Anruf/Email-Notizen, Termin-Titel, Gilden-/Freundes-Namen,
   zwei ältere Autocomplete-Boxen und mehr (~20 Stellen insgesamt). Ein
   böswillig benannter Kontakt (z.B. Vorname `<img src=x
   onerror="...">`) hätte beim Anzeigen durch jedes Team-Mitglied
   ausgeführt werden können — echte, ausnutzbare Stored-XSS-Lücke, kein
   theoretisches Risiko. `escHtml()` selbst war zusätzlich unvollständig
   (escapte kein `"`/`'`, dadurch in Attribut-Kontexten wie
   `data-name="${...}"` weiterhin ausbrechbar) — jetzt escapt es auch
   Anführungszeichen, sicher für Text- UND Attribut-Kontexte gleichermaßen.
   **Bei jedem neuen Rendering-Code, der Datenbank-Text per `innerHTML`
   einfügt: `escHtml()` verwenden, keine Ausnahme** — das war hier die
   eigentliche Lehre, nicht nur der einmalige Fix.
   Per Playwright end-to-end gegen den echten Account verifiziert: echter
   Testkontakt mit `<img onerror>`/`<svg onload>`/`<script>`-Payloads in
   Vorname/Nachname/Notizen angelegt, Payload blieb in Tabelle UND
   Detailansicht als sichtbarer Text (`&lt;img ...`) statt auszuführen,
   `window.__xssFired` blieb bei 0, Testkontakt danach wieder gelöscht.
   **Bewusst nicht angefasst:** Inhalte aus `rule_configs`
   (Quest-/Questchain-Namen, Aktions-Labels) — die kommen nicht aus
   In-App-Formularen, sondern werden vom Admin direkt per Supabase
   SQL-Editor gepflegt, vertrauenswürdige Konfiguration, kein Nutzer-Input.
   **Nebenbei aufgefallen, keine Handlung nötig, nur als Beobachtung:** es
   gibt mittlerweile drei leicht unterschiedliche Autocomplete-Implementierungen
   für Kontakt-/Ort-Suche in `index.html` (organisch bei verschiedenen
   Features entstanden) — noch kein Grund zum Vereinheitlichen (Rule of
   Three ist gerade erst erreicht), aber falls eine vierte dazukommt, lohnt
   sich ein gemeinsamer Helfer.
3. **`maxlength` auf bisher unbegrenzten Freitextfeldern nachgetragen**
   (noch selber Tag, Nutzerwunsch) — keine Abwehr gegen böswillige Nutzer
   (siehe Begründung oben, dafür fehlt hier das Bedrohungsmodell), sondern
   reine UX-Hygiene gegen versehentliches Riesig-Reinpasten. Namen/Orte/
   Titel meist 60–150 Zeichen, Notizfelder 1000–3000, die 5 Tagebuch-Fragen
   bewusst großzügig **5000 Zeichen** ("lieber ein paar Zeichen mehr als zu
   wenig", ausdrücklicher Nutzerwunsch — Tagebuch soll sich niemals eng
   anfühlen). Bewusst NICHT angefasst: reine Such-/Autocomplete-Felder
   (`contactLocationSearch`, `friendSearchInput`, `termineEntry*Search`,
   Wert wird nicht direkt gespeichert) und `configEditor` (roher
   JSON-Editor für `rule_configs`, admin-only, kann legitim mehrere KB groß
   sein).

**Nachtrag noch am selben Tag: RLS-Durchgang (statische Analyse aller
`sql/*.sql`-Policies + Live-Bestätigung per direktem PostgREST-Aufruf mit
echtem Session-Token, nicht nur gelesen/vermutet):**

- **Gefunden, gefixt, ausgeführt UND nach Ausführung erneut live bestätigt
  (`sql/patch38_profile_privilege_schutz.sql`, seit 2026-08-07 live):**
  `profiles_update_own` hat `using (id = auth.uid())` ohne eigene
  `with check` — Postgres übernimmt dafür automatisch dieselbe Bedingung,
  die aber nur `id` schützt, keine andere Spalte. Erstbestätigung: eigener
  Account per PATCH auf `/rest/v1/profiles` von `role:'admin'` auf
  `'member'` gesetzt und sofort wieder zurück (beides per Read verifiziert)
  — ein normaler Nutzer könnte sich also selbst zum Admin machen
  (`is_admin()` liest nur `profiles.role`), ebenso `character_class`
  (soll laut Konzept "einmalig, dauerhaft" sein) und `org_id` frei ändern.
  Patch 38 fügt einen BEFORE-UPDATE-Trigger hinzu, der diese drei Spalten
  blockiert, außer der Ausführende ist bereits Admin. **Nach dem Einspielen
  erneut getestet, diesmal mit einem frischen Wegwerf-Testaccount statt dem
  echten Account** (Selbstregistrierung ist offen, siehe Patch 39): als
  Admin auf `member` herabgestuft (erlaubt), direkt danach als `member`
  versucht sich selbst zurück auf `admin` zu setzen — vom Trigger korrekt
  mit der eigenen Fehlermeldung ("Nur Admins dürfen die Rolle ändern.")
  abgelehnt, Rolle blieb `member`. Schutz bestätigt wirksam.
- **Zweite, verwandte Lücke direkt beim erneuten Testen gefunden, gefixt,
  ausgeführt UND nach Ausführung erneut live bestätigt — Patch 38 deckte
  nur UPDATE ab, nicht die allererste Zeile (`sql/patch39_profile_insert_privilege_schutz.sql`,
  seit 2026-08-07 live):** `profiles_insert_self` prüft beim Anlegen
  ebenfalls nur `id = auth.uid()`. Erstbestätigung: ein direktes INSERT mit
  `role:'admin'` im Payload legt sofort ein fertiges Admin-Profil an —
  komplett am Registrierungsbildschirm vorbei (der schickt zwar immer
  `role:'member'`, aber das ist nur eine Konvention der App, keine
  Absicherung auf Datenbank-Ebene). Da die App offene Selbstregistrierung
  erlaubt (kein Einladungszwang), war das nicht nur ein Kollegen-Risiko,
  sondern von jedem Internet-Besucher aus nutzbar, der die URL kennt.
  Patch 39 erzwingt `role='member'` und die aktuelle Standard-`org_id` per
  BEFORE-INSERT-Trigger bei jeder neuen Zeile, unabhängig vom
  mitgeschickten Wert. **Nach dem Einspielen erneut getestet, wieder mit
  einem frischen Wegwerf-Account**: INSERT-Payload versuchte diesmal
  `role:'admin'` UND eine komplett fremde `org_id` einzuschleusen — die
  tatsächlich gespeicherte Zeile hatte trotzdem `role:'member'` und die
  korrekte Standard-Org, `character_class` blieb wie gewollt frei wählbar.
  Schutz bestätigt wirksam.
- ~~Gefunden, noch NICHT gefixt: `user_inventory` hat dieselbe Lücke bei
  `item_key`/`quantity`~~ — **behoben, 2026-08-15, siehe eigener
  Abschnitt "Serverseitige Schreib-Härtung" weiter unten.**
- **Restliche `update`-Policies ohne explizite `with check`** (contacts,
  termine, termin_series, contact_activities, journal_entries, friends,
  guild_members) sind trotz desselben Musters **nicht** betroffen — ihre
  `using`-Bedingung referenziert direkt die Eigentümer-Spalte
  (`owner_id`/`user_id`), wodurch ein Versuch, diese Spalte auf eine
  fremde ID umzubiegen, automatisch an derselben Bedingung scheitert.
  Nur bei `profiles` (Bedingung hängt an `id`, geschützt sind aber ganz
  andere Spalten) und `user_inventory` (Bedingung hängt an `user_id`,
  betroffen sind `item_key`/`quantity`) greift der Trick nicht.
- **Noch nicht geprüft, falls das Thema weitergeht:** ob es im Frontend
  Stellen gibt, die sich nur auf verstecktes UI verlassen (z.B. ein
  Admin-Button einfach ausgeblendet), ohne dass eine passende RLS-Policy
  dahintersteht — sowie Randfälle in der Business-Logik (Kanban-Übergänge,
  Provisionsberechnung).
- ~~Aufräumen nötig, vom Testen übrig geblieben~~ — **erledigt.** Die
  Testzeile in `user_inventory` (`item_key='xss_audit_testitem'`) und die
  zwei Wegwerf-Testprofile (`PatchAuditTest`/`Patch39AuditTest`) samt
  ihrer `@example.com`-Auth-Nutzer sind nicht mehr in der DB (zuletzt am
  2026-08-10 per `supabase db query --linked` gegengeprüft, 0 Treffer).

## Nachtrag: locName()-XSS-Lücke + Datenbank-Advisor-Durchgang (2026-08-11)

Auf die Frage "was könnten wir bei diesem Tempo übersehen haben" zwei
echte, kleine Funde gemacht und **verifiziert behoben** (nicht nur
behauptet):
- `locName()` (Dungeon-/Betriebsname) escapte seinen Rückgabewert nicht —
  drei Renderstellen betroffen (Kontakte-nach-Dungeon-Kacheln,
  Kontakttabelle, Kanban-Karten). Gleiche Lückenklasse wie der
  Sicherheits-Durchgang vom 2026-08-07, dort aber nicht erfasst (Locations
  waren nicht im Scope, oder Regression durch neueren Code). Gefixt.
- Passwortfeld (`authPassword`) ohne `maxlength` nachgetragen — reine
  Hygiene, kein Sicherheitsrisiko.

**Neu entdecktes Werkzeug fürs nächste Mal:** `supabase db advisors
--linked --type all --level info` (Supabases offizieller Security-/
Performance-Linter gegen die echte, verlinkte DB — lokal per `export
PATH="$HOME/.local/share/nodejs-portable/bin:$PATH" &&
./node_modules/.bin/supabase db advisors --linked ...`, JSON-Output gut
mit `jq` auswertbar). Deutlich zuverlässiger als eigenes Grep-Raten für
sowas — bei künftigen ähnlichen Audits zuerst hiermit starten.

**Ergebnis dieses Durchgangs:**
- **Gefixt, live** (Migration `20260811202349_fk_indizes_und_search_path_haertung.sql`):
  33 fehlende Indizes auf Fremdschlüssel-Spalten bei neueren Tabellen
  (Kalender, Gilden, Dateien, Chronik — das Muster aus Patch 17/17b wurde
  bei ihnen nicht mitgezogen), plus fester `search_path` auf 7 Funktionen
  mit erhöhten Rechten (`is_admin`, `current_org_id`,
  `contacts_shared_for_org`, u.a. — Härtung gegen search_path-hijacking).
  Per erneutem Advisor-Lauf verifiziert: 0 verbleibende
  `unindexed_foreign_keys`-Meldungen.
- **Geprüft, unbedenklich:** 28 als "von anon/authenticated ausführbar"
  gemeldete Funktionen. Die vier bedrohlichsten
  (`handle_member_offboarding`, `sync_contacts_owner_on_location_reassign`,
  `enforce_profile_insert_defaults`, `protect_privileged_profile_fields`)
  sind strukturell `returns trigger`-Funktionen — Postgres kann die gar
  nicht direkt aufrufen lassen, unabhängig von vergebenen Rechten. Der
  Rest sind RLS-Hilfsfunktionen (müssen breit ausführbar sein) oder
  RPC-Funktionen mit eigener interner Prüfung (z.B. `admin_emergency_access`
  prüft `is_admin()` intern).
- **Bewusst zurückgestellt, echte "erst bei Skalierung"-Kandidaten**
  (gleiche Logik wie "Technische Skalierungs-Schwellen" oben): 60×
  mehrere permissive RLS-Policies pro Tabelle, 54× `auth.uid()` statt
  `(select auth.uid())` in RLS-Policies — beides bekannte
  Supabase-Performance-Muster, bei der aktuellen Nutzerzahl irrelevant.
  114 Policy-Stellen jetzt hastig umzuschreiben wäre ein unnötiges
  Zugriffsmodell-Risiko gewesen. Erst bei echtem Abfrage-Volumen
  angehen, nicht vorbeugend. 8 ungenutzte Indizes (Rauschen bei geringer
  Last, keine Handlung). "Leaked Password Protection" im
  Supabase-Dashboard ist aus — reiner Klick, kein SQL, noch nicht
  angeschaltet, bei Gelegenheit selbst aktivierbar.

## Abenteuerlog-Seite (Kalender/Tagebuch/Foto), seit 2026-08-04 neu sortiert

Reihenfolge auf `#page-tagebuch` ist jetzt bewusst: **Kalender oben →
Tagebuch-Serie → die 5 Tagebuch-Fragen → Foto ganz unten** (vorher:
Tagebuch-Fragen → Foto → Kalender). Reiner Layout-Wunsch des Nutzers, keine
Datenbank-/Logik-Änderung — alle IDs, RLS, `journal_entries`/`journal_photos`
unverändert.

**Tagebuch-Serie** (neue Kachel zwischen Kalender und Tagebuch-Fragen,
`journalStreakTag`/`journalStreakHint` in `index.html`): zeigt "X Tage in
Folge Tagebuch geführt", nach demselben Muster wie XP/Level — **wird nie
gespeichert**, sondern bei jedem Aufruf frisch aus `journal_entries`
berechnet (`loadJournalStreak()`, liest die letzten 400 Tage). Die eigentliche
Zähllogik sitzt bewusst in einer reinen, DB-losen Funktion
(`computeJournalStreak(entryDateKeys, todayStr)`, neben `daysBetweenKeys()`)
statt direkt in der Ladefunktion — **auf ausdrücklichen Nutzerwunsch**, damit
eine künftige Quest-Prüfung ("30 Tage in Folge Tagebuch führen", Teil des
externen Quest-Baum-Nebenstrangs, siehe unten) dieselbe Logik aufrufen kann,
statt die Streak-Berechnung ein zweites Mal zu schreiben. Ist der heutige Tag
noch nicht eingetragen, bleibt die bis gestern gezählte Serie "am Leben"
(noch nicht gerissen) — erst wenn auch gestern kein Eintrag existiert, fällt
die Serie auf 0. Aktualisiert sich live nach jedem Auto-Save
(`scheduleJournalSave()`), kein Neuladen der Seite nötig.

**Bugfix 2026-08-04, wichtiger Stolperstein:** "hat einen Eintrag" darf NICHT
heißen "eine `journal_entries`-Zeile für den Tag existiert" — ein `upsert`
beim Leeren aller 5 Felder überschreibt die Zeile nur mit leeren Strings,
löscht sie aber nicht. Ein bewusst nicht-löschbares Löschen ist hier auch gar
nicht möglich: `journal_entry_mentions` hat einen Fremdschlüssel auf
`journal_entries(user_id, entry_date)` **mit `on delete cascade`**
(`patch16_tagebuch_mentions.sql`) — ein echtes Löschen der leeren Zeile würde
also still auch @mention-Markierungen mitreißen, die laut CLAUDE.md bewusst
NICHT löschbar sein sollen. Deshalb prüft `journalRowHasContent(row)`
(neben `JOURNAL_FIELDS`) jetzt an allen drei Stellen, die "Tag hat einen
Eintrag" auswerten (`renderCalendar()`, `loadJournalStreak()`,
`scheduleJournalSave()`), ob mindestens eines der 5 Felder noch echten Text
enthält, statt nur auf Zeilen-Existenz zu prüfen. Bei jeder künftigen
Änderung an dieser Logik dasselbe Prinzip weiterverwenden, nicht auf
Zeilen-Existenz zurückfallen.

**Echter Termin-Kalender (Wochenansicht, Outlook-Stil), seit 2026-08-05
live** — Phase 1 der am 2026-08-04 nur als Vision notierten Idee, nach
ausführlicher Absprache gebaut (siehe Muster "erst durchsprechen" oben).
Der Kalender bleibt in der Monatsansicht ein reiner Tagebuch-Rückblick,
bekommt aber eine neue, umschaltbare **Wochenansicht** dazu (`calViewMode`
'monat'/'woche', Umschalter über das bestehende `.view-switch`-Muster wie
bei Kontakte "Nach Dungeon/Alle Kontakte"). Monatsansicht hat jetzt zusätzlich
eine Mo–So-Kopfzeile (`.cal-weekday-header`, fehlte vorher komplett) und
zeigt einen dritten Punkt-Typ (`dot-termin`) neben den bestehenden
Tagebuch-/Foto-Punkten, wenn an dem Tag ein Termin liegt.

**Datenmodell (Patch 33, `sql/patch33_termine.sql`):** neue Tabelle
`termine` — `owner_id` (rein persönlich, keine Team-Sichtbarkeit, wie beim
Tagebuch), optionale `contact_id`/`location_id`, Freitext-`title`,
`start_at`/`end_at` (timestamptz). **Bewusst NICHT so abgeschottet wie
`journal_entries`**: Admins haben eine normale Leserechte-Ausnahme (wie bei
Kontakten/Locations) — ausdrückliche Nutzerentscheidung ("das wird noch
skalieren", Tagebuch bleibt die einzige komplett private Ausnahme). Keine
Überschneidungs-Prüfung in der DB — Doppelbuchungen sind einfach
unabhängige Zeilen, die Wochenansicht **layoutet sie nebeneinander**
(Outlook-Stil, `computeOverlapLayout()`: Cluster überschneidender Termine
gruppieren, dann greedy Spalten vergeben — Standard-Kollisionsalgorithmus).
Zusätzlich `profiles.arbeitszeiten` (JSONB, pro Wochentag `{start,end}`) für
eine neue Einstellungen-Unterseite "Kalender" → Arbeitszeiten (eigene
aufklappbare Kachel neben "Provision & Planungsziele", gleiches Muster).
Wirkt sich nur optisch aus (Zeiten außerhalb werden in der Wochenansicht
abgedunkelt, `.week-nonwork-overlay`, `pointer-events:none`) — Termine
lassen sich weiterhin überall eintragen, nichts wird technisch gesperrt.

**Bedienung Wochenansicht:** Zeitraster im Halbe-Stunde-Takt
(`HALF_HOUR_PX=32`), Ziehen über eine Zeitspanne (Pointer Events, nicht
native HTML5-Drag&Drop — gleicher Grund wie beim Kanban-↕-Menü: funktioniert
zuverlässig auch auf Touch) öffnet ein Popup (Titel, Start/Ende, optional
Kontakt-/Betrieb-Suche über eine neue generische `initGenericAutocomplete()`-
Hilfsfunktion, die den bestehenden `contactLocationSearch`-Stil wiederverwendet).
**Wichtiger Stolperstein, gelöst:** ob ein Klick einen bestehenden Termin
öffnet oder einen neuen erzeugt, entscheidet sich über die **Ziehstrecke**
(>6px Bewegung = neuer Termin), nicht über das Element unter dem Finger —
sonst ließe sich kein zweiter, überschneidender Termin mehr über einem
bereits voll-breiten bestehenden Termin aufziehen (der erste Versuch hat
das per `e.target.closest('.week-event')`-Abbruch im `pointerdown` blockiert
und musste korrigiert werden). Zeitachse bleibt beim seitlichen Scrollen auf
schmalen Bildschirmen sticky stehen (`.week-time-col{position:sticky;
left:0}`) — **derselbe Bug wie bei der Kontakt-Tabelle zuvor** (siehe
Abenteuerlog/Kontakte-Fix weiter oben) ist hier auch aufgetaucht: der erste
Wurf hatte `overflow-x:hidden` auf `.week-view-wrap` gesetzt, wodurch
Samstag/Sonntag auf dem Handy einfach unsichtbar abgeschnitten waren statt
scrollbar zu sein — auf `overflow-x:auto` korrigiert, gegen die echte,
eingeloggte App auf 390px-Breite verifiziert.

**Kanban-Integration:** die Kanban-Übergänge "Ersttermin vereinbart" und
"Zweittermin" fragen jetzt beide (überspringbar, kein Zwang, `promptKanbanTermin()`)
nach Datum+Uhrzeit und legen bei Eingabe einen echten Kalendertermin an —
und zwar an **beiden** Auslösern: dem bestehenden Dungeon-Button
(`terminLeadModal`, jetzt um Start/Ende-Zeitfelder ergänzt) UND beim Ziehen
einer bereits bestehenden Karte im Board (vorher dort komplett ohne
Datumsabfrage). **"Angebot versendet" bekommt bewusst KEIN Termin-Popup**
— teilte sich vorher denselben Code-Pfad wie Zweittermin (beide loggen die
Aktion `pitch`), wurde dafür entkoppelt: ein Angebot verschicken ist kein
Treffen. Derselbe `promptKanbanTermin()`-Baustein sitzt zusätzlich als
"Termin eintragen"-Button im Kontaktformular (`cdTerminBtn`) — bequemer
Nachtrag, falls beim Verschieben übersprungen wurde, ausdrücklicher
Nutzerwunsch ("das hat was Bequemliches"). **Seit 2026-08-09 abends:**
steht die Karte gerade auf Gewonnen/Verloren, holt derselbe Button sie
jetzt zusätzlich auf Ersttermin zurück (gleiche `kundenausbau`-Aktion wie
beim Ziehen im Kanban, kein neuer Kontakt) — vorher passierte das nur beim
Ziehen im Board, nicht über diesen Button, was der Nutzer als Bug meldete.
**Geklärt am 2026-08-10, weiterhin bewusst NICHT gebaut:** ein Rücksprung
Gewonnen/Verloren → Ersttermin (Kundenausbau) soll im Hintergrund
mitzählen, der wievielte Termin es der Reihe nach für den Kontakt ist —
eine einzige durchlaufende Nummer pro Kontakt (Ersttermin+Zweittermin vor
dem ersten Gewinn = 1./2., jeder spätere Kundenausbau-Rücksprung zählt
fortlaufend weiter, 3./4./5. …). **Bewusst nirgends in der UI anzeigen**
(ausdrücklicher Nutzerwunsch, "das muss nirgends erscheinen … der Kanban
ist einfach praktisch") — die Chronik zeigt die Kontaktintensität für
Menschen schon ausreichend über Datum/Art jeder Zeile. Zweck ist rein,
dass ein künftiger Kundenausbau-Quest-Typ (Kategorie "Advance", siehe
Questbaum-Notiz) diese Zahl als Schwellenwert nutzen kann. Da noch keine
Quest das braucht, absichtlich noch nicht gecodet (Rule of Three) — wenn
gebaut wird, dann live aus `action_log` abgeleitet
(`termin_vereinbart`/Zweittermin-Kanban-Übergänge desselben Kontakts
zählen), kein neues Speicherfeld nötig, gleiches Prinzip wie
`computeJournalStreak()`.

**Bewusst noch nicht gebaut (Phase 2, siehe "Bewusst aufgeschobene Ideen"-
Prinzip):** wiederkehrende Termine, Erinnerungen, Tagesansicht. Nicht von
selbst anfangen, nur auf expliziten Anstoß.

**Nachbesserung Patch 34 (`sql/patch34_wochenende_ausblenden.sql`,
2026-08-05), noch am selben Tag:** Bugfix + neue Einstellung, ausgelöst
durch echtes Nutzer-Feedback ("ich hab meine Arbeitszeit nun von Montag bis
Freitag gelegt, der Kalender zeigt immer noch Samstag und Sonntag"). Zwei
Dinge:
1. **Bugfix:** ein Wochentag ganz ohne Arbeitszeiten-Eintrag (z.B. ein nicht
   konfiguriertes Wochenende) galt fälschlich als ungegraut statt komplett
   arbeitsfrei — jetzt wird ein Tag ohne Eintrag in der Wochenansicht
   ganztägig abgedunkelt (`week-nonwork-overlay` über die volle Höhe).
2. **Neue Einstellung** `profiles.calendar_hide_weekends` (boolean,
   Default false) — Checkbox in Einstellungen → Kalender → Arbeitszeiten:
   Samstag/Sonntag lassen sich statt nur grau auch **komplett ausblenden**
   (wie Outlooks "Arbeitswoche"-Ansicht). Das Wochenraster passt seine
   Spaltenzahl/-breite dafür jetzt dynamisch an (`grid-template-columns`
   wird pro `renderWeekView()`-Aufruf per JS gesetzt), statt fest auf 7
   Spalten zu bestehen.

**Kalender-Aufgaben (Geburtstage + Wiedervorlage), seit 2026-08-06 live
(Patch 35, `sql/patch35_kalender_aufgaben.sql`) — Phase 2 des Termin-
Kalenders, erster Baustein.** Nicht-blockierender Hinweis-Mechanismus im
Kalender, bewusst wie XP/Level komplett **abgeleitet, nicht extra
gespeichert**: `tasksForDate(dateStr)` in `index.html` liest bei jedem
Rendern die eigenen Kontakte (`ownContactsForTasks`, geladen über
`loadContactTaskData()`) und erzeugt daraus Hinweis-Objekte — kein neues
Termin o.ä. wird angelegt. Zwei Quellen bisher:
- **Geburtstage** aus dem längst vorhandenen `contacts.geburtsdatum`
  (Patch 15) — jährlich wiederkehrend anhand reinem Monat/Tag-Vergleich
  (`geburtsdatum.slice(5)`), unabhängig vom Geburtsjahr. Ein/Aus-Schalter
  pro Person: `profiles.calendar_show_birthdays` (Default true), Checkbox
  in Einstellungen → Kalender → Arbeitszeiten (gleiche Kachel wie
  Wochenenden ausblenden).
- **Wiedervorlage** aus `contacts.naechster_kontakt` (existierte vorher
  schon als manuelles Korrekturfeld im Kontaktformular) — exakter
  Datumstreffer, kein Wiederholungsmuster. Neu seit diesem Patch: das
  "Gewonnen"-Verkaufspopup (`recordWonSalesLoop()`) fragt am Ende
  **einmal für den ganzen Abschluss** (nicht pro Produktzeile) nach einem
  Wiedervorlage-Datum, überspringbar wie die anderen Zusatzabfragen im
  Projekt.

Anzeige an zwei Stellen, beide über dieselbe `tasksForDate()`-Funktion:
Monatsansicht bekommt einen dritten Punkt-Typ (`dot-aufgabe`, gelb) neben
den bestehenden Tagebuch-/Termin-Punkten, Details erscheinen beim Antippen
eines Tages oben in der bestehenden Vorschau-Kachel (`cp-tasks`). In der
Wochenansicht sitzt eine neue schmale Zeile (`#weekTasksRow`) direkt unter
der Wochentage-Kopfzeile (beide zusammen jetzt in einem gemeinsamen
`.week-sticky-head`-Wrapper, damit sie beim Scrollen im Zeitraster zusammen
oben kleben bleiben) — pro Tag ein kleiner Chip mit Kundenname und Icon
(🎂/📞), bewusst **außerhalb** des Zeitrasters, damit normale Termine
dadurch nicht verdrängt werden (ausdrücklicher Nutzerwunsch, "soll unsere
normalen Termine nicht stören, aber der Name muss sichtbar sein").

**Produktweite Nachfass-Empfehlung**, im selben Patch: `products.
recontact_amount` (Zahl) + `products.recontact_unit` (Tage/Wochen/Monate/
Jahre, bewusst wählbar statt fest — eine Berufshaftpflicht denkt in
Monaten, eine Immobilienfinanzierung eher in Jahren bis zur Prolongation),
pflegbar in der bestehenden Produkt-Detailkachel. Reine Empfehlung, kein
Zwang: `computeRecontactDate()` errechnet aus Vertragsbeginn + Produktregel
einen Vorschlag, der das Wiedervorlage-Feld im Verkaufspopup vorbefüllt,
sobald Produkt oder Vertragsbeginn gewählt werden — aber nur, solange der
Nutzer das Feld nicht selbst angefasst hat (`wiedervorlageUserEdited`-Flag),
überschreibbar jederzeit.

**Serientermine (wiederkehrende Termine, Outlook-Stil), seit 2026-08-06
live (Patch 36, `sql/patch36_serientermine.sql`) — zweiter Baustein von
Phase 2.** Wiederholungsregel und echte Kalendertage sind bewusst getrennt:
`termin_series` (die Regel: Titel, Uhrzeit, `freq` täglich/wöchentlich/
monatlich, `interval_n`, `weekdays`-Array nur bei wöchentlich, `start_date`,
`until_date` NULL=unbegrenzt, `generated_until`) und `termine.series_id`
(Rückverweis, `on delete cascade`). Statt die Wiederholung rein virtuell zu
berechnen, werden echte `termine`-Zeilen vorausschauend **materialisiert**
— rollierend bis zu einem 6-Monats-Horizont (`SERIES_HORIZON_MONTHS`),
genau wie beim täglichen Manatrank-Nachtrag (`topUpAllSeriesForUser()`,
einmalig pro Sitzung in `enterApp()`, direkt nach `grantDailyManatrank()`).
**Kernvorteil dieses Ansatzes:** ein einzelner Tag der Serie lässt sich
danach ganz normal verschieben/löschen wie jeder andere Termin, ohne eigene
Ausnahme-Buchhaltung — `generated_until` wandert nur vorwärts, ein einmal
erzeugter (und ggf. verschobener) Tag wird nie ein zweites Mal erzeugt.

Beim **Neuanlegen** eines Termins (nur dort, nicht nachträglich beim
Bearbeiten — Outlook macht das genauso) gibt es ein "Wiederholung"-Feld im
bestehenden Termin-Popup: Häufigkeit, Intervall ("alle N ..."), bei
wöchentlich zusätzlich Wochentage-Mehrfachauswahl (voreingestellt auf den
Wochentag des angelegten Termins), Ende per Datum oder "kein Ende". Nach
dem Speichern wird die Serie sofort per `topUpSeries()` bis zum Horizont
gefüllt, nicht erst beim nächsten Login.

**Ändern und Löschen fragen bei jedem Serientermin** (neues, generisches
`askSeriesScope()`-Popup, `#seriesScopeModal` — **wichtig: eigener
`z-index:1001`**, weil es über einem bereits offenen `.loc-modal` sitzt und
alle `.loc-modal`-Elemente sonst denselben z-index teilen; ohne die
Anhebung fing das darunterliegende Termin-Popup die Klicks ab, per
Playwright-Test entdeckt und korrigiert) immer "Nur diesen Termin" oder
"Ganze Serie":
- **Löschen, ganze Serie:** löscht die `termin_series`-Zeile, per Cascade
  automatisch alle zugehörigen `termine` — inklusive vergangener Termine
  (wie Outlooks tatsächliches Verhalten beim Löschen einer Serie).
- **Ändern, ganze Serie:** aktualisiert `termin_series.start_time/end_time`
  auf die neue Uhrzeit und wendet sie auf alle Termine der Serie an, deren
  `start_at` **ab dem heutigen Tag** liegt (jeweils eigenes Datum bleibt
  erhalten, nur die Uhrzeit ändert sich) — vergangene Termine bleiben
  unangetastet, wie mit dem Nutzer abgesprochen.

End-to-end gegen die echte Datenbank verifiziert (Playwright: Serie
anlegen → 4 wöchentliche Termine korrekt materialisiert → "ganze Serie"
verschoben, vergangener Termin nachweislich unverändert, alle künftigen
korrekt aktualisiert → "ganze Serie" gelöscht, danach nichts mehr in
`termine`/`termin_series` — kein Testdaten-Rückstand).

**Bewusst weiterhin offen:** echte Erinnerungen (Push/E-Mail o.ä.), bewusst
unentschieden gelassen, keine Eile.

## UI-Audit über alle Seiten (2026-08-06/07)

Auf ausdrücklichen Nutzerwunsch ("kontrolliere die vollständige UI ...
achte auf Mobile UND Desktop") wurde die gesamte App einmal systematisch
geprüft: alle 12 Nav-Seiten, je bei 390px (Mobile) und 1440px (Desktop),
per Playwright mit echtem Login — automatisierter Overflow-Check
(`scrollWidth` vs. `clientWidth`) plus visuelle Screenshot-Sichtung. Dabei
zwei echte, bis dahin unbemerkte Bugs gefunden und behoben (beide
betrafen Mobile UND Desktop gleichermaßen, keine reinen
Responsive-Probleme):

1. **Fähigkeiten-Radar (Sigil) schnitt lange Achsenbeschriftungen am
   Rand ab** ("Fachwissen" erschien als "chwissen") — das SVG-viewBox war
   exakt so groß wie der Radar selbst, `text-anchor="middle"` ließ lange
   Labels über den sichtbaren Bereich hinausragen. Behoben durch
   großzügigeres viewBox.
2. **Chronik (Handlungen-Seite) zeigte beim Öffnen nicht die neuesten
   Einträge** — `.log` nutzt `flex-direction:column-reverse` (neuester
   Eintrag oben, ohne das Array in JS umzudrehen), aber der Browser
   initialisiert die Scrollposition dabei mit `scrollTop:0`, was hier
   einen Ausschnitt aus der Mitte der Historie zeigte statt der neuesten
   Einträge. Behoben durch explizites `scrollTop = -scrollHeight`, sowohl
   beim Rendern als auch beim tatsächlichen Anzeigen der Seite (die Seite
   war beim ersten Rendern noch unsichtbar, `scrollHeight` dort also 0 —
   deshalb zwei Stellen nötig, `render()` UND `showPage()`).

**Direkter Folgeauftrag, noch am 2026-08-07 umgesetzt** (zwei von drei
Politur-Vorschlägen aus dem Audit-Bericht, vom Nutzer freigegeben):

- **Sigil deutlich vergrößert, volle Skillnamen statt 10-Zeichen-Kürzung**
  ("ich würde die Wörter schon gerne lesen können"). `drawSigil()` in
  `index.html`: viewBox von 260×260 auf 530×530 (mit Versatz) vergrößert,
  `text-anchor` jetzt richtungsabhängig (Labels rechts vom Zentrum wachsen
  nach rechts, links vom Zentrum nach links, oben/unten bleiben zentriert)
  statt überall `middle` — dadurch passen auch "Gesprächsführung" und
  "Beziehungspflege" komplett ins Bild. `#sigil` per CSS responsiv
  (`width:100%;max-width:530px;height:auto`), skaliert auf schmalen
  Bildschirmen mit, ohne zu überlaufen.
- **Scroll-Fade an seitlich scrollbaren Leisten** (Sidebar-Nav auf Mobile,
  Feldzug-Route, Monats-Reiter Trophäenkammer) — vorher kein Hinweis, dass
  dort noch mehr kommt. Neuer, wiederverwendbarer Helfer `initScrollFade(el)`
  / `updateScrollFade(el)` in `index.html` (per `mask-image`, nicht per
  Hintergrundverlauf, damit es unabhängig von der jeweiligen
  Panel-Hintergrundfarbe funktioniert) — blendet sich automatisch an der
  Seite aus, an der gerade nichts mehr zu scrollen ist. **Bei künftigen
  neuen horizontal scrollenden Bereichen diesen Helfer wiederverwenden**
  statt eine eigene Lösung zu bauen.
- Dritter Vorschlag (Emoji-Rendering in Testscreenshots) war nur ein
  Hinweis zu meiner Testumgebung, kein App-Bug — keine Änderung nötig,
  vom Nutzer bestätigt ("keine Probleme mit den Emojis").

Methodik-Erkenntnis aus derselben Session: ein vom Nutzer gemeldetes
"Geburtsdatum wird nicht angezeigt" stellte sich bei einer direkten
Live-Prüfung (Supabase-REST + Playwright) als kein Bug heraus — der Nutzer
hatte einen Test-Kontakt in der Jägerchronik gemeint, nicht sein eigenes
Profil. Vor dem Bauen einer "Behebung" für ein gemeldetes Problem lohnt
sich ein kurzer Live-Check, bevor man dem Bug-Report unbesehen glaubt.

**Buch-/Rollen-Kachel: seit 2026-08-04 live gebaut** (setzt die oben
ursprünglich nur als Zukunftsidee notierte Umbenennung um, mit leicht
anderen finalen Namen als zuerst angedacht): unter dem Kalender ersetzt
jetzt eine einzelne, klassenabhängige Kachel (`.journal-book-tile` in
`index.html`) die vorher immer sichtbaren 5 Tagebuch-Fragen — **Zauberbuch**
(Zauberer), **Kriegsbuch** (Krieger), **Schützenrolle** (Schütze, bewusst
eine Pergamentrolle statt eines Buchs). Klick auf die Kachel klappt einen
Wrapper (`#journalEntryWrap`) mit den 5 Fragen + dem Foto-Feld darunter
auf/zu (`setJournalEntryOpen()`) — **kein Modal**, ausdrücklicher
Nutzerwunsch: der Kalender soll beim Schreiben sichtbar bleiben, anders als
die bestehenden Popups im Programm (Verkaufsabschluss etc.). Die
Tagebuch-Serie (`journalStreakTag`/`journalStreakHint`, siehe oben) sitzt
weiterhin an derselben Stelle/mit denselben IDs, nur räumlich auf der Kachel
statt in einer eigenen Karte — `loadJournalStreak()`/`renderJournalStreak()`
unverändert. Klassenzuordnung über `CLASS_JOURNAL` + `updateJournalBookTile()`,
aufgerufen in `initJournal()` und im Admin-Klassenschalter (gleiches Muster
wie `updateContactLabels()`/`updateStatistikLabels()`).

Die drei Icons sind handgezeichnete Pixel-Art (kein GandalfHardcore-Asset —
Bücher/Rollen kommen im Paket nicht vor), zweite Überarbeitung nach
Vorlage von vier vom Nutzer geschickten Referenz-Screenshots (runde Ecken,
Rücken-Farbstreifen, Titel-Plakette, Seitenkante unten, Lesezeichen-Fahne,
klassentypisches Emblem — Stern fürs Zauberbuch, Schwert fürs Kriegsbuch).
Liegen unter `img/characters/creator/journal_{zauberer,krieger,schuetze}.png`
(96×96, wie die übrigen `item_*`-Icons dort). Erzeugt über ein Python/Pillow-
Skript (Pixel-für-Pixel auf einem 24×24-Raster, per Nearest-Neighbor auf
96×96 hochskaliert) statt gezeichneter SVGs — die erste Fassung ohne
Referenzbilder wirkte laut Nutzer "nicht ganz rund", danach erst die vier
Screenshots angefordert und die Formensprache (nicht die Bilder selbst)
übernommen.

## Changelog-Popup für angewendete SQL-Patches (Patch 32, 2026-08-04)

**Status: live, seit 2026-08-04.** `sql/patch32_changelog.sql` wurde vom
Nutzer im Supabase SQL-Editor ausgeführt und per Playwright end-to-end gegen
die echte Datenbank verifiziert (nicht nur gemockt) — `last_seen_patch_number`
testweise auf 0 zurückgesetzt, echter Reload, Popup erschien korrekt mit
"Patch 32 — Changelog-Popup für angewendete SQL-Patches", App hat den Stand
danach selbst wieder korrekt auf 32 gesetzt.

**Konzept:** immer wenn ein neuer SQL-Patch angewendet wird, trägt sich der
Patch selbst in `schema_patches` ein (letzte Zeile jeder Patch-Datei,
Konvention in `PATCH_LOG.md` festgehalten). Beim nächsten Login sieht
**jedes** Team-Mitglied (nicht nur Admins — bewusste Nutzerentscheidung,
Transparenz für alle) ein Popup mit allen Patches, die seit dem eigenen
letzten Login dazugekommen sind — auch mehrere auf einmal, falls jemand
länger nicht eingeloggt war. Der angezeigte Text ist **bewusst automatisch
abgeleitet**, nicht von Hand nachformuliert (ausdrückliche Nutzer-
Entscheidung, obwohl das für nicht-technische Kolleg:innen mitunter kryptisch
klingen kann) — die Kopfzeile jeder Patch-Datei ("PATCH N — Titel"), die
ohnehin beim Schreiben jedes Patches entsteht, wird 1:1 als Popup-Titel
übernommen. Kein separater Changelog-Text-Schritt nötig.

**"Gesehen" pro Person** über `profiles.last_seen_patch_number` — wird in
dem Moment gesetzt, in dem das Popup erscheint (nicht erst beim Wegklicken).
Ein DB-Trigger (`set_initial_seen_patch()`) sorgt dafür, dass **neue**
Profile automatisch beim zu diesem Zeitpunkt aktuellen Patch-Stand starten,
damit niemand bei der ersten Anmeldung mit der kompletten Historie
überflutet wird — das Popup ist nur für echte Neuerungen ab dem eigenen
Beitritt gedacht. Bewusst **einmalig pro Version, keine Historien-Seite**
(Nutzerentscheidung) — wer es wegklickt, sieht diesen Patch nicht nochmal.

**Bekannte, akzeptierte Grenze:** die Tabelle ist bewusst organisationsweit
(kein `org_id`-Bezug, da Schema-Änderungen die ganze DB betreffen, nicht
eine Organisation) — sobald es mehrere echte Kundenorganisationen auf
derselben Datenbank gibt, würden alle Organisationen dieselben,
möglicherweise fachlich irrelevanten Änderungen angezeigt bekommen. Passt zur
bereits bekannten Lücke bei der Multi-Org-Loskopplung (`DEFAULT_ORG_ID`,
siehe "Technische Skalierungs-Schwellen") — kein neues Problem, nicht vorab
lösen.

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

## Pixel-Art-Referenzmasken-System, seit 2026-08-09

Ausgangslage: der Nutzer kündigte einen großen Ausbau an (3 Charaktere,
~30 neue Kleidungsteile je Körperteil, "vieles mehr") und äußerte dabei
explizit Misstrauen ("du bist sehr unzuverlässig in diesem Thema … du
brauchst irgendein Raster, ein Gitter, eine Basis, eine Struktur"). Der
Sprite-Bogen (siehe oben) hatte vorher gezeigt, dass freihändig pro Frame
platzierte Pixel-Art mehrere Korrekturrunden braucht — Claude "sieht" ein
gezeichnetes Ergebnis nicht automatisch richtig, ohne es aktiv nachzumessen.

**Kernidee, als drei Python-Module fest in `Design/` verankert** (nicht
mehr Wegwerf-`python3 -c`-Einzeiler wie im ersten Versuch):

- **`Design/reference_masks.py`** — zieht aus bereits korrekt sitzenden
  Original-Assets (Hemd/Corset, Hose/Rock, Stiefel/Socken, Handschuhe, je
  m/w) die exakte Alpha-Maske jedes der 8 Lauf-Frames. `SLOT_SOURCES` ist
  die einzige Stelle, die bei einem neuen Slot (z.B. Kopfbedeckung, Rücken)
  erweitert werden muss — keine Code-Änderung sonst nötig. `load_reference_mask(slot,
  gender, frame)` liefert die Maske als numpy-Array, `build_all()` schreibt
  zusätzlich Sichtkontroll-PNGs + `reference_masks.json` nach
  `Design/reference_masks/` (gitignored wie der Rest von `Design/`, reine
  Alpha-Silhouetten ohne Farbinhalt aus dem lizenzierten Originalpaket).
- **`Design/check_alignment.py`** — automatischer Grenz-Check statt reinem
  Augenmaß. `check_anchor_preserved()` prüft, ob ein definiertes Ankerband
  (z.B. die obersten 4 Zeilen = Schulteransatz) gegenüber dem Original nicht
  schrumpft/wandert. `check_no_intrusion()` prüft, ob ein neues Teil in einen
  fremden Nachbar-Slot hineinschneidet (z.B. ein verlängertes Hemd in die
  Stiefel). `run_report()`/`report_all_pass()` faßt das über alle 8 Frames
  zusammen.
- **`Design/frame_grid_preview.py`** — Sicht-Werkzeug: `grid_frame()`
  rendert einen einzelnen Frame stark vergrößert mit Koordinatenraster (alle
  4px beschriftet), damit Claude tatsächlich nachmisst statt zu schätzen;
  `run_cycle_strip()` zeigt alle 8 Frames nebeneinander für den schnellen
  Sitz-Vergleich (vorher/nachher).

**Zwei Testläufe gegen den männlichen Basiskörper durchgeführt (Ergebnis dem
Nutzer als Artifact gezeigt, 2026-08-09):**
1. **Umfärbung bei identischer Maske** (Hemd beige→dunkelgrün) — sitzt
   erwartungsgemäß perfekt über alle 8 Frames, bestätigt nur, dass die
   Maskenextraktion/Pipeline technisch funktioniert.
2. **Neue Silhouette** (Hemd→lange Tunika, Saum entlang der bereits
   korrekten Hosen-Maske bis kurz vor die Stiefel verlängert) — **beide
   automatischen Checks bestanden in allen 8 Frames** (Schulteransatz
   unverändert, kein Hineinschneiden in die Stiefel), aber der sichtbare
   Effekt war schwächer als erhofft (nur ein kleiner Zipfel an der Hüfte,
   weil der Saum bewusst konservativ vor den Stiefeln gestoppt wurde).

**Ehrlicher Status, nicht beschönigen:**
- **Zuverlässig:** Umfärbungen/Muster bei gleicher Maske, und Formen, die
  sich direkt aus einer bereits korrekten Nachbarmaske ableiten lassen
  (länger/kürzer entlang einer bestehenden Kontur) — automatisch geprüfbar.
- **Weiterhin Handarbeit mit Sichtprüfung, nur jetzt mit harten Leitplanken:**
  wirklich neue Silhouetten (lockerer Schnitt, neue Ärmelform, Kragen,
  Kapuze) — die Checks verhindern nur, dass der Ankerbereich verrutscht oder
  in einen Nachbar-Slot schneidet, nicht dass die Form selbst gut aussieht.
- **Noch nicht getestet:** weiblicher Basiskörper, die Slots Hände/Kopf/Rücken,
  ob lockere/wehende Formen (Umhänge, Röcke) sich überhaupt in dieses Schema
  pressen lassen.

**Für jedes künftige neue Kleidungsteil verbindlich:** nicht mehr freihändig
pro Frame zeichnen/positionieren. Erst `reference_masks.py` für den
betroffenen Slot/das betroffene Geschlecht ziehen (neuer Slot: einfach in
`SLOT_SOURCES` ergänzen), neue Form gegen die Maske ableiten oder zumindest
mit `check_alignment.py` gegenprüfen, mit `frame_grid_preview.py` visuell
verifizieren (selbst nachmessen, nicht nur rendern und hoffen) — erst danach
das Ergebnis dem Nutzer zeigen. Kein Rückfall auf reines Augenmaß.

## Bewusst aufgeschobene Ideen (NICHT vergessen, aber NICHT von selbst bauen)
- ~~**Outlook-artige abhakbare Aufgaben**~~ — **fertig gebaut, live,
  2026-08-20, Patch 51**, siehe eigener Abschnitt "Aufgaben-System: echte,
  abhakbare Aufgaben (Outlook-Stil)" oben. Neue Tabelle `tasks`, neuer
  Tag-Reiter im Kalender, Geburtstags-/Wiedervorlage-Aufgaben laufen
  automatisch mit. Kein offener Punkt mehr.
- **Gamification-Ausschalter (reines CRM verkaufen)** — vom Nutzer am
  2026-08-09: eine Einstellung, mit der sich das gesamte Gamification-Thema
  (XP/Level/Klassen/Quests/Gilde/Charakter) organisationsweit abschalten
  lässt, um das System auch als reines CRM ohne Spiel-Schicht verkaufen zu
  können. Passt konzeptionell zu dem am 2026-08-03 skizzierten
  `enabledModules`-Schlüssel in `rule_configs` (siehe "Frontend-Framework-
  Frage" oben) — dort ging es um einzelne Bausteine (Kanban/Dungeon/
  Tagebuch An/Aus), das hier wäre der radikalste Fall davon (alles
  Spielerische auf einmal aus). Noch nicht durchdacht: was aus CRM-Sicht
  überhaupt übrig bleibt (Kontakte/Kanban/Kalender/Statistik ja, aber
  Charakterseite/Gilde/Inventar dann komplett weg?) — braucht ein
  eigenes Gespräch, bevor irgendwas gebaut wird.
- **Verkaufsstatistik (Arkanes Kompendium) an die Gilde binden** — vom
  Nutzer am 2026-08-09 als Idee genannt, am 2026-08-10 kurz angerissen
  und **bewusst wieder zurückgestellt, weil dabei ein echtes, ungelöstes
  Problem sichtbar wurde:** Provisionssätze/Planungsziele (Patch 31)
  trägt jeder für sich selbst ein, es gibt aber **keinerlei Anstoß**,
  das je zu tun — anders als XP (kommt automatisch durchs Arbeiten),
  müsste ein neu eingeladenes Gildenmitglied diese Einstellungen aktiv
  und freiwillig ausfüllen, sonst bleiben seine Zahlen leer/verzerrt,
  sobald sie in eine Team-Ansicht einfließen. Nutzer-O-Ton: "das reißt
  etwas auf, was wir gerade nicht wollen." Vor einem erneuten Anlauf
  müsste zuerst diese Adoptions-Frage geklärt werden (z.B. ein
  einmaliger Onboarding-Hinweis Richtung Einstellungen-Seite, ähnlich
  dem Changelog-Popup-Muster) — nicht von selbst wieder aufgreifen, nur
  auf erneuten Nutzeranstoß.
- **Lern-/Zertifikatsystem für den Zauberer** — vom Nutzer am 2026-08-03 nur
  als Name angekündigt, noch ohne jegliche inhaltliche Details. **Wichtig:
  der Name "Grimoire" ist dafür reserviert** — deshalb heißt die
  Verkaufsstatistik-Seite beim Zauberer "Arkanes Kompendium" und NICHT
  "Grimoire", obwohl Letzteres thematisch nähergelegen hätte. Falls der
  Nutzer künftig von einem Lern-/Zertifikatsystem spricht, ist das dieses
  hier gemeinte Vorhaben. Nicht von selbst anfangen, nur wenn der Nutzer es
  explizit anstößt.
- **Gilden-basierte Sichtbarkeit** — Phase 1 seit 2026-08-08 live gebaut,
  siehe eigener Abschnitt "Gilden-basierte Sichtbarkeit, Phase 1" weiter
  unten. Phase 2 (Notfall-Nachfolgekette) und Phase 3 (protokollierter
  Admin-Notfallzugriff) bleiben offen, kein Zeitdruck.
- **BWS-Verrechnung (Phase 2 des Produktkatalogs)** — Formel jetzt bekannt,
  **noch nicht gebaut** (kein SQL/Code bisher). Am 2026-08-03 hat der Nutzer
  seine bestehende Excel (`~/Schreibtisch/Projekt.xlsm`, 14 Blätter:
  Datenblatt + 12 Monate + Summe, komplett leeres Formular ohne echte
  historische Verträge) geliefert und Claude Code hat sie vollständig
  ausgelesen (ZIP+XML, ohne Excel/openpyxl nötig). Drei **unabhängige**
  Werte werden direkt aus dem eingetragenen Betrag pro Vertrag berechnet
  (nicht verkettet, wie der Name "BWS→Provision→Bewertungspunkte" vermuten
  ließe):

  | Art-Code | Bedeutung | Bewertungspunkte-Faktor | Provisions-Faktor |
  |---|---|---|---|
  | LV | Lebensversicherung | ×0,05 | × (individuelle ‰-Rate ÷ 1000) |
  | KV | Krankenversicherung | ×8 | × individuelle MB-Rate |
  | SH | Sach/Hausrat (DÄV/AXA) | ×1 | ×0,1 |
  | RS | Rechtsschutz (Roland) | ×0,75 | ×0,365 |
  | KFZ | Kfz (AXA) | ×0,3 | ×0,08 |
  | D | Darlehen APO (>5J) | ×0,02 | ×0,01 |
  | DP | Darlehen Plattform | ×0,016 | ×0,008 |
  | KAP | Kapitalanlage | ×0,03 | ×0,01 |
  | pmaSUH | pma-Vermittlung SUH | ×1 | ×0,23 × 0,05 |
  | pmaKV | pma-Vermittlung KV | ×0 | ×0,75 × 0,282 |
  | KontoAPO / KontoStud | Kontoeröffnung | ×0 | 200€ / 100€ fest |

  Zusätzlich **Differenzprovision** (nur LV/KV):
  `Betrag × (Standard-Satz − individuelle Rate)` — Standard-Sätze org-weit
  40‰ (LV) bzw. 8 (KV), individuelle Rate siehe unten.

  **Drei Kernentscheidungen, mit dem Nutzer abgestimmt (2026-08-03):**
  1. **LV/KV-Provisionssätze sind individuell pro Mitarbeiter**, nicht
     organisationsweit — brauchen eigene Felder in `profiles` (z.B.
     `lv_promille_satz`, `kv_mb_satz`), nicht in `rule_configs`.
  2. **Bewertungssumme (nur LV) und Bewertungsbeitrag (alle anderen
     Sparten) bleiben begrifflich getrennt**, genau wie in der Excel —
     nicht zu einem generischen Feld zusammengelegt.
  3. **Zwei Excel-eigene Bugs werden beim Übertragen korrigiert, nicht
     nachgebaut**: pmaSUH-Provisionsfaktor korrekt auf 0,05 (die Excel-
     Formel driftete ab der zweiten Vertragszeile durch einen nicht
     fixierten Zellbezug auf falsche/leere Zellen); DP-Bewertungspunkte-
     Faktor einheitlich ×0,8 (ein Tippfehler hatte in einer einzelnen
     Zeile ×0,08 stehen).

  **Bewusst NICHT übernommen:** das "Summe"-Blatt der Excel war laut
  Nutzer nur der unfertige erste Anlauf zu einem eigenen Dashboard
  (Zielerreichungsgrad-Balken, wöchentliche FA→T1-Konversionsquote) — wird
  durch die gemeinsam gebaute Verkaufsstatistik-Seite (Kompendium/
  Kriegskasse/Trophäenkammer, siehe "Charakterklassen") ersetzt, nicht
  Zelle für Zelle nachgebaut. Die FA→T1-Wochenquote-Idee (Kaltakquise→
  Erstgespräch-Konversion) ist aber als mögliche spätere Kennzahl notiert,
  falls das Statistik-Modul das aufgreifen soll.

  **Datenmodell (Patch 30, `sql/patch30_bws_verrechnung.sql`), seit
  2026-08-03:** vierte Entscheidung — Faktoren leben als Felder direkt am
  Produkt (`products.bwp_faktor`, `products.provision_faktor`,
  `products.provision_mode` — 'fest'/'individuell_lv'/'individuell_kv'),
  nicht als fester Code-Lookup wie in der Excel. Passt zum Leitsatz
  "Organisationsspezifisches ist Daten, nicht Code" — eine neue Sparte
  braucht nur eine neue Produktzeile mit eigenen Faktoren, keine
  Code-Änderung. Individuelle Sätze (`profiles.lv_promille_satz`/
  `kv_mb_satz`) und die Diff-Provisions-Referenzsätze (`rule_configs`
  `diffProvLvPromille`/`diffProvKvMb`, Default 40/8) ebenfalls in Patch 30.
  Keine Migration bestehender Produkte — neue Spalten bleiben NULL, bis
  ein Admin sie einträgt.

  **Bedienung im "Produkte"-Reiter:** Produkte erscheinen als klickbare
  Kacheln (`.dungeon-tile`-Optik wiederverwendet, wie beim Dungeon-Klick
  und der Kontakte-nach-Dungeon-Ansicht — "Kachel statt Liste" war
  ausdrücklicher Nutzerwunsch, 2026-08-03) statt einer Liste mit inline
  sichtbaren Eingabefeldern. Klick öffnet `productDetailModal`
  (Provisions-Modus, Bewertungspunkte-/Provisions-Faktor, Aktivieren/
  Deaktivieren) — das Anlegen-Formular selbst bleibt schlank (nur Name/
  Kategorie/Unterkategorie), Faktoren werden ausschließlich über die
  Kachel-Detailansicht eines bereits angelegten Produkts gepflegt.

  **Neue Seite "Einstellungen" (Patch 31, `sql/patch31_planungsziele.sql`),
  seit 2026-08-03 — bewusster Zwischenschritt vor der eigentlichen
  Statistik-Anzeige:** individuelle Provisionssätze (LV ‰/KV-MB) UND die
  persönlichen Planungsziele (`profiles.planung_lv_bws`/`planung_kv_mb`/
  `planung_bwp`/`planung_vks`/`planung_fa`, aus der Excel "Planung ..."
  in Datenblatt!B9-B13) trägt **jeder für sich selbst** ein, nicht der
  Admin stellvertretend — bewusste Korrektur einer ersten, falschen
  Annahme (Claude hatte die individuellen Sätze zunächst admin-exklusiv im
  Produkte-Reiter gebaut, analog zur Account-Pool-Zuweisung; der Nutzer
  wollte stattdessen Selbstbedienung). Neuer, für alle sichtbarer Nav-Reiter
  "⚙️ Einstellungen" direkt nach dem Kompendium/Kriegskasse/Trophäenkammer-
  Reiter. `renderEinstellungenPage()` lädt/speichert direkt auf
  `profile`/`profiles`, kein Admin-Umweg. Diese Werte sind die
  "Grundlage", aus der das Kompendium später den Zielerreichungsgrad
  berechnet (siehe nächster Schritt).

  **Dashboard fertig gebaut, seit 2026-08-03** (kein leerer Rahmen mehr):
  Berechnung UND Anzeige leben jetzt zusammen auf der Verkaufsstatistik-
  Seite. Wie bei XP/Level (`computeTotals()`) wird **nichts gespeichert**,
  alles wird bei jedem Seitenaufruf frisch aus `sales` + `products` +
  `profile` + `rule_configs` zusammengerechnet (`aggregateStats()` in
  `index.html`, Kern-Helfer `saleBasisValue()`/`saleBwp()`/
  `saleProvision()`/`saleDiffProvision()`).

  **Noch ungeprüfte Annahme, unbedingt beim ersten Test mit echten
  Verkäufen gegenchecken:** welcher Eingabewert pro Verkauf als "E" in die
  Formel eingeht. Aktuell: `sales.bewertungssumme` bei Leben
  (`provision_mode==='individuell_lv'`), sonst `sales.laufender_beitrag`
  — UND `sales.menge` wird NICHT nochmal draufmultipliziert (Annahme: der
  eingetragene Betrag ist bereits die Summe für die ganze Zeile, nicht
  ein Pro-Stück-Wert). Falls das nicht stimmt, ist nur `saleBasisValue()`
  zu korrigieren.

  **Bedienung:** Reiter-Leiste oben (Power-BI-Stil, "Jahr" + 12 Monate,
  `renderStatTabs()`) wählt den Zeitraum, damit die Seite bei
  Monatsdaten nicht aufbläht — genau der Nutzerwunsch. Fünf KPI-Kacheln
  oben (`statHeroCard()`): drei mit Fortschritts-Ring (Bewertungssumme
  Leben, Bewertungsbeitrag sonstige, Bewertungspunkte — je gegen das
  persönliche Planungsziel aus der Einstellungen-Seite, Ring-Füllstand
  optisch bei 100% gedeckelt, die Prozentzahl daneben aber ungedeckelt),
  zwei ohne Ring (Provision, Differenzprovision — dafür gibt es
  konzeptionell kein Planungsziel). Darunter ein horizontales
  Balkendiagramm der Bewertungssumme/-beitrag je Produktkategorie
  (`renderStatCategoryChart()`) mit Legende + Hover-Tooltip + Werten
  direkt am Balken. Ganz unten reine Zahlen-Kacheln je Produkt
  (`renderStatNumberCards()`, Stück + Summe) — der vom Nutzer
  ausdrücklich gewünschte zweite Schritt "danach natürlich Zahlenkarten".

  **Farben** (dataviz-Skill befolgt, nicht nach Auge geraten): die
  Fortschritts-Ringe nutzen `var(--arcane)` — die ohnehin schon pro
  Klasse dynamische Akzentfarbe (`CLASS_THEMES`), dadurch automatisch
  lila/rot/grün je nach Zauberer/Krieger/Schütze, ohne eigenen Code. Das
  Kategorie-Balkendiagramm nutzt eine **validierte** 8-Farben-Palette
  (`STAT_CATEGORICAL`, feste Reihenfolge nach alphabetisch sortierten
  Produktkategorien, nicht nach Wert — Farbe folgt der Kategorie, nicht
  ihrem Rang) — geprüft mit dem dataviz-Skill-Validator gegen die
  tatsächliche Panel-Oberfläche der App (`#1c1830`), alle Checks
  bestanden. Mehr als 8 gleichzeitig aktive Kategorien fallen auf
  `var(--muted-2)` zurück statt eine neue Farbe zu erzeugen.

  **Datenbasis:** nur die **eigenen** gewonnenen Verkäufe des
  eingeloggten Nutzers (`created_by = profile.id`, `status = 'gewonnen'`),
  gruppiert nach `vertragsbeginn` (Fallback `datum`, falls kein
  Vertragsbeginn gesetzt ist). Passt zur Grundidee: Provision/Ziele sind
  persönlich, nicht organisationsweit.

  **Noch nicht angegangen:** Zielerreichungsgrad für Verkaufsgespräche
  (`planung_vks`) und Fachkontakte (`planung_fa`) — die Planungsfelder
  existieren bereits (Patch 31), aber es gibt noch keine Zählquelle dafür
  im Aktions-Log (die FA→T1-Wochenquote-Idee aus der Excel, siehe oben,
  ist dafür der wahrscheinliche Anknüpfungspunkt, aber bewusst noch nicht
  gebaut).

  **Echter Login für Claude Code, seit 2026-08-03:** der Nutzer hat seinen
  echten App-Zugang (nicht sein persönliches Supabase-Dashboard-Konto,
  das ist getrennt) geteilt, damit Claude Code künftig mit Playwright
  echte Screenshots statt nur Code-Review machen kann. Liegt in
  `~/.local/share/fantasyarbeit-claude-test/credentials.json` (außerhalb
  des Repos, chmod 600, nie auf GitHub). Bei Passwort-Änderungen: Nutzer
  meldet sich, Datei wird aktualisiert. Damit wurde diese Seite (leerer
  Zustand, keine Verkäufe/Ziele bisher) bereits einmal live bestätigt —
  echte Zahlen/Ring-Füllstand/Sparklines muss der Nutzer selbst gegenprüfen,
  sobald er ein erstes Produkt + einen Testverkauf angelegt hat. Bitte
  dabei besonders auf die oben genannte Annahme (BWS vs. Beitrag, keine
  Menge-Multiplikation) achten.

  **Verlaufs-Sparklines (2026-08-03):** jede der 5 KPI-Kacheln zeigt in
  der Jahresansicht zusätzlich einen kleinen Flächen-Chart der 12
  Monatswerte (`sparklineSvg()`) — bewusst als "small multiples" (eine
  Mini-Kurve pro Kachel) statt eines gemeinsamen Charts mit mehreren
  Metriken auf einer Achse (Skalen sind zu unterschiedlich: Euro vs.
  Bewertungspunkte). Bleibt unsichtbar, wenn alle Monatswerte 0 sind,
  statt eine bedeutungslose Nulllinie zu zeigen. Kein eigener Hover pro
  Datenpunkt — die exakten Zahlen bleiben über die Monats-Reiter
  abrufbar, das reicht als "Tabellen-Ansicht"-Äquivalent.
- ~~Malus-Berechnung bei gekündigten/ausgelaufenen Verträgen~~ —
  **entschieden gegen, 2026-08-10:** kein zusätzlicher Malus bei Storno,
  der Storno selbst ist schmerzhaft genug. War am 2026-07-31 nur als
  Zukunftsidee erwähnt, jetzt final verworfen, keine Wiedervorlage mehr.
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
  **Verkaufserfolge fließen mit ein, geklärt am 2026-08-03:** die Erzählung
  soll nicht nur aus dem Tagebuch, sondern auch aus echten Verkaufsabschlüssen
  (`sales`) gespeist werden. **Kein expliziter Verknüpfungs-Zwang** — der
  Nutzer stellte klar, dass `journal_entry_mentions` (@mention im Tagebuch)
  bewusst nur ein optionaler Bonus fürs persönliche Ausschütten ist ("sein
  eigenes Innenleben"), kein Pflichtfeld, um einen Verkauf mit einem
  Tagebucheintrag zu verknüpfen. Verkäufe werden vom System ohnehin
  automatisch getrackt (Datum via `vertragsbeginn`) — **die Edge Function
  zieht beide Zeitreihen (Tagebucheinträge + gewonnene Verkäufe desselben
  Jahres) unabhängig voneinander** und überlässt der KI, zeitliche
  Zusammenhänge selbst herzustellen (z.B. ein schwieriger Tagebucheintrag,
  zwei Wochen später ein Abschluss beim selben Kontakt, erkennbar über
  `sales.contact_id` = per `journal_entry_mentions` erwähnter Kontakt).
  Ein expliziter Link lohnt sich erst, falls sich beim ersten echten
  Durchlauf zeigt, dass die KI Verkäufe falschen Tagen zuordnet — vorher
  nicht von selbst bauen.
- **KI-Bildumwandlung von Tagebuch-Fotos** — z.B. "Zauberer im Rat der Weißen".
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

  Die bisherigen CLASS_OUTFIT-Klassenitems (Zauberer: Zauberstab + blaues
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

  **`reward_item_key`+`qty`-Feld für Quests:** siehe "Ein aktiver,
  paralleler Nebenstrang" → "Item-/Mengen-System-Umbau", dort
  konsolidiert.

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
  (`outfit_weapon_bow_${g}.png` als letzte/oberste Ebene, wie bei Zauberer/
  Krieger) — behebt den zuvor offenen Kosmetik-Punkt (siehe unten, jetzt
  entfernt), dass der Schütze auf dem Klassenwahl-Bildschirm bisher
  unbewaffnet aussah.

  **Asset-Quelle, seit 2026-08-01 im Testeinsatz:** heruntergeladene
  GandalfHardcore-Pakete (Basis-Körper, Arm-/Handschuh-Ebenen, Hand-Items/
  Waffen, Rücken-Ebenen, Kleidung männlich/weiblich, Hüte, Masken,
  Elfenohren, Rücken-Layer, u.a.), liegen lokal unter
  `~/Schreibtisch/GandalfHardcore *.zip` (wird laufend um weitere
  Zusatzpakete ergänzt, noch kein Bogen/Zauberstab dabei — fehlt für
  Schütze/Zauberer). Verifiziert (Python/Pillow-
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

  **Krieger-Portrait (`img/characters/krieger.png`), 2026-08-01 nur
  testweise eingeführt — inzwischen komplett überholt, nur noch historisch
  interessant:** ein einzelnes statisches Basisbild, das eine Zeit lang auf
  der Charakterseite unter den Ausrüstungs-Ebenen lag, nur für Krieger
  gefüllt (`CLASS_BASE_ART`-Map). **Mit dem Rendering-Umbau vom 2026-08-03
  (siehe "Anziehen/Ausziehen" unten) gegenstandslos geworden:** die
  Charakterseite (`#page-charakter`/`charArtStack`) nutzt seitdem
  denselben klassenunabhängigen `createSpriteRenderer()` wie überall sonst
  (`layersForCharacterProfile()`, gespeist aus `skin_tone`/`hair_style`/
  `equipped_*` — kein Bezug zu `character_class` mehr) — funktioniert
  dadurch für alle drei Klassen bereits gleichermaßen, kein Sonderfall,
  kein Hinweistext-Fallback mehr. `img/characters/krieger.png` und
  `CLASS_BASE_ART` existieren im Code nicht mehr (per Check am 2026-08-10
  bestätigt). Frühere Zwischenstände dieses Absatzes waren nicht
  konsequent nachgezogen worden, als der Umbau passierte — beim nächsten
  ähnlichen Fund direkt mit korrigieren, nicht nur den neuen Stand
  danebenschreiben.

  **Klassenwahl-Bildschirm auf 6 angezogene, animierte Beispielcharaktere
  erweitert (2026-08-02/03, seit 2026-08-03 auch im echten `index.html`):**
  `#charCreateScreen` zeigte anfangs nur für Krieger ein Bild
  (`img/characters/krieger.png`, s.o.), Zauberer/Schütze hatten Emoji. Nach
  zwei Überarbeitungen (erst statische Einzelbilder pro Klasse+Geschlecht,
  dann — auf Wunsch des Nutzers, der explizit ein **dynamisches**, nicht
  aus flachen Einzelbildern bestehendes Charakterscreen wollte — durch
  `<canvas>`-Elemente ersetzt, siehe "Aussehen-Screen" oben für die
  Technik) zeigt der Bildschirm jetzt für alle drei Klassen ein animiertes,
  live aus Ebenen zusammengesetztes Beispiel: einheitliche Basis-Kleidung
  (Hemd/Hose/Stiefel bzw. Corset/Rock/Socken) + ein klassentypisches Item
  (Zauberer: Stick + blaues Cape, Krieger: Holzschwert + Guard Helmet,
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
Supabase-Tabelle `rule_configs`. **Erster echter Schritt dieser
Übersetzung seit 2026-08-09 abends live**, siehe nächster Abschnitt.

**Unterpunkt, festgelegt 2026-08-10 — Item-/Mengen-System-Umbau folgt
NACH diesem Nebenstrang, nicht parallel.** Der Questbaum ist seit
2026-08-15 vollständig in die App übersetzt (siehe
[[project_questbaum_schema_design]]), damit ist die Wartebedingung
erfüllt. Von den drei ursprünglich gebündelten Punkten sind die ersten
beiden noch am selben Tag erledigt worden:
1. ~~**Manatrank-Vergabe an Quests knüpfen**~~ — **erledigt,
   2026-08-15.** `grantDailyManatrank()` (der automatische
   Gratis-Trank pro Kalendertag) ist komplett entfernt. Stattdessen
   hängt der Manatrank jetzt an der täglichen Quest `daily1` (3
   Ansprachen + 1 Termin vereinbart) — `config.recurringQuests`
   bekam ein `itemReward:{key:"mana_trank",qty:1}`-Feld.
2. ~~**`reward_item_key`+`qty`-Feld für Quests**~~ — **erledigt im
   selben Zug.** `checkAndAwardRecurringQuests()` unterstützte
   `q.itemReward` bereits (ungenutzt seit dem Krankenhausakquise-Pilot),
   war nur nie befüllt — reine Datenänderung, kein neuer Code nötig.
   Neuer Belohnungs-Toast (`showQuestRewardToast()`, unten links XP,
   unten rechts Icon+Name des Items) zeigt jede erfüllte
   `recurringQuest` an, nicht nur die mit Item-Belohnung.
3. ~~**`user_inventory`-RLS-Lücke**~~ — **behoben, 2026-08-15 abends**,
   siehe Abschnitt "Serverseitige Schreib-Härtung" weiter unten. Damit
   ist dieses Bündel komplett abgeschlossen.

## Questbaum-Übersetzung, erster Schritt: Termin-Kanal + Vertriebsserien (Patch 40, 2026-08-09)

Der Obsidian-Questbaum (siehe `Questbaum.canvas`,
[[reference_obsidian_vault_questbaum]] in Claudes Erinnerung) wurde in
derselben Session gemeinsam mit dem Nutzer auf Messbarkeit gegen das echte
System geprüft — die meisten Äste (Sach-/Leben-/Kranken-/Finanzierung-
Abschlüsse, Krankenhausakquise, Empfehlungsmanagement, Bestandskundenausbau)
waren schon vorher 1:1 aus bestehenden Daten ableitbar. Zwei konkrete
Lücken wurden in diesem Patch geschlossen:

**1. `termine.kanal`/`termin_series.kanal`** (nullable, Werte
`'online'|'buero'|'betrieb'`, kein DB-Constraint — gleiches Muster wie
`contacts.status`, Prüfung im Frontend): neuer `.view-switch`
(💻 Online/🏢 Büro/🏥 Im Betrieb, `.kanal-toggle-btn`) in allen drei
Termin-Popups (`terminLeadModal`, `kanbanTerminModal`,
`termineEntryModal`), erneutes Klicken des aktiven Buttons wählt ab
(bleibt optional). Wird beim Speichern mitgeschrieben, bei
Serienterminen über `termin_series.kanal` an jede materialisierte
Zeile weitergegeben (`topUpSeries()`). Sichtbar als Icon-Präfix in der
Wochenansicht (`renderDayEvents()`) und als Badge in der Kontakt-Chronik
(`kanalBadgeHtml()`, KANAL_LABELS-Konstante) — damit landet die
Information nicht nur "es gab einen Termin am Datum X", sondern auch
"online/vor Ort/im Betrieb", wie vom Nutzer für die CRM-Dokumentation
gewünscht. **Bewusst nur drei Kanäle, nicht vier**: eine ursprünglich im
Questbaum separate "Praxis"-Kategorie wurde mit "Im Betrieb"
zusammengelegt, da nur diese drei Werte am Termin selbst erfasst
werden — Krankenhaus vs. Praxis ließe sich bei Bedarf später über
`locations.type` des verknüpften Betriebs ableiten, kein eigenes Feld
nötig.

**2. Telefonakquise-/Termine-Serien als Konstanz-Anzeige** (neue
"Konstanz"-Kachel auf der Verkaufsstatistik-Seite, unter den KPI-Karten):
`computeDailyThresholdStreak()`/`computeWeeklyThresholdStreak()`, reine
Funktionen direkt neben `computeJournalStreak()` (gleiches Prinzip: kein
Speichern, live aus dem bereits geladenen eigenen `action_log`
berechnet). Zeigt die aktuelle Serie für **beide** Schwellen aus dem
Questbaum gleichzeitig — "X Tage in Folge ≥10 Nummern gewählt · Y Tage
in Folge ≥20" (Aktion `telefon_5`, ×5 pro Log-Eintrag) und "X Wochen in
Folge ≥5 Termine wahrgenommen · Y Wochen in Folge ≥7" (Aktion
`termin_wahrgenommen`). Bewusst **kein** eigener Quest-/Belohnungs-
Mechanismus, nur Sichtbarkeit — genau wie die Tagebuch-Serie ein reiner
Fortschritts-Spiegel ist, keine XP-Quelle für sich.

**Bewusst nicht Teil dieses Patches**, auf ausdrücklichen Nutzerwunsch:
der "Vertriebstrichter" (10 Ansprachen→6 Termine→3 Abschlüsse) aus dem
Questbaum ist eine reine persönliche Planungs-Daumenregel, kein
Spielziel — wurde deshalb aus dem Obsidian-Baum wieder entfernt statt
übersetzt zu werden, siehe Erinnerung `feedback_heuristic_vs_quest`.

End-to-end mit Playwright gegen den echten Account verifiziert
(`~/.local/share/playwright-portable/check_termin_kanal.mjs`): Kanal
speichern → korrekter DB-Wert → Icon in der Wochenansicht →
Vorbelegung beim erneuten Öffnen zum Bearbeiten, Testtermin danach
aufgeräumt.

## Gilden-basierte Sichtbarkeit, Phase 1 (seit 2026-08-08 live)

Löst die früher hier gelistete Lücke ("jedes Org-Mitglied sieht alle
Dungeons") und ersetzt für Kontakte den alten organisationsweiten
`contactsVisibility`-Schalter als primären Mechanismus. Entstanden aus
einer sehr ausführlichen Grundsatz-Konversation mit dem Nutzer (siehe
Git-Historie desselben Tages) — Auslöser war ein echtes, beobachtetes
Problem: Kolleg:innen, die sich neu anmeldeten, sahen sofort alle
Dungeons/Kontakte des Nutzers.

**Grundprinzip:** Bottom-up, jeder Mitarbeiter startet komplett privat
("wie sein eigenes Programm"), auch für den Admin unsichtbar im Alltag.
Sichtbarkeit entsteht ausschließlich durch **Gilden-Mitgliedschaft**
(`guilds`/`guild_members`, existierte als reine RPG-Sozialfunktion schon
vorher) — kein Alleingang mehr auf Basis eines globalen Schalters.

**Zwei komplett unabhängige Freigabe-Achsen pro Gildenmitglied**
(`guild_members.contacts_access`/`dungeons_access`, je `'read'`/`'write'`,
Standard `'read'` bei Einladung), **plus `team_rights`** (bool, für
spätere Mitverwaltung, in Phase 1 noch nicht ausgewertet):
- **Kontakte** sind der eigentliche Kern (das CRM) — Freigabe gilt
  pauschal für ALLE Kontakte eines Mitglieds auf einmal, unabhängig davon,
  ob sie einem Dungeon zugeordnet sind oder nicht. **Wichtige Korrektur
  während der Konzeptions-Diskussion:** ursprünglich fälschlich als von
  Dungeons abhängig modelliert (Kontakt erbt Sichtbarkeit vom Dungeon) —
  falsch, weil dungeon-lose Kontakte (z.B. niedergelassene Ärzte in
  eigener Praxis, kein Krankenhaus-Dungeon) sonst nie hätten geteilt
  werden können. Kontakte haben deshalb **kein eigenes `guild_id`-Feld**,
  die Prüfung läuft direkt über Eigentümer+Gilde (`guild_contact_permission()`).
- **Dungeons** sind bewusst nur die spielerische Organisationsschicht
  obendrüber ("Gimmick", O-Ton Nutzer) — `locations.guild_id` (NULL =
  privat). Neue Dungeons eines Mitglieds mit `dungeons_access='write'`
  landen automatisch im Pool seiner Gilde (`myDungeonPoolGuildId()` in
  `index.html`, an beiden Anlege-Stellen). Bringt ein neu eingeladenes
  Mitglied bereits bestehende private Dungeons mit, entscheidet **nur
  beim Beitritt** einmalig der Gildenführer, ob sie in den Pool
  aufgenommen werden (Liste mit Toggle im Rechte-Modal,
  `loadGuildRightsPoolList()`) — danach kein formaler Prüfpunkt mehr,
  läuft informell im Team.

**Bedienung:** "Hinzufügen" beim Gilden-Mitglied-Picker öffnet direkt das
neue `guildMemberRightsModal` (Kontakt-/Dungeon-Zugriff als
`.view-switch`-Toggle, Teamrechte als `.settings-switch`-Pill, plus die
Aufnahme-Liste) — derselbe Button (`data-rights`) auf jeder Mitglieder-Kachel
lässt den Gründer die Rechte jederzeit im Nachgang ändern. Gilde gründen
setzt automatisch die eigenen Rechte auf voll (`write`/`write`/`true`) und
übernimmt eigene bestehende Dungeons automatisch in den neuen Pool (keine
Prüfung nötig, es ist die eigene Welt des Gründers).

**Wichtiger RLS-Stolperstein, der viel Debugging gekostet hat (unbedingt
bei künftigen ähnlichen Policies im Kopf behalten):** eine `FOR UPDATE`-
Policy mit korrektem `USING`/`WITH CHECK` reicht NICHT aus, wenn die Zeile
nicht ZUSÄTZLICH auch über eine bestehende `SELECT`-Policy sichtbar ist —
Postgres verlangt beides, die UPDATE-eigene `USING`-Klausel ersetzt die
Sichtbarkeits-Prüfung nicht. Selbst eine testweise auf `USING(true) WITH
CHECK(true)` vereinfachte Update-Policy schlug fehl (0 betroffene Zeilen,
kein Fehler), bis `locations_select_org` um dieselbe
`guild_founder_of_member()`-Bedingung erweitert wurde, die die
Aufnahme-Policy schon nutzte — der Gildenführer musste den noch nicht
aufgenommenen, privaten Dungeon eines Mitglieds erst SEHEN können, bevor
er ihn per UPDATE aufnehmen konnte. Per Wegwerf-Testaccounts (Signup,
Profile, Kontakt/Dungeon, Cross-User-Zugriffsversuche) sauber isoliert und
verifiziert, inklusive mehrerer Zwischenschritte mit temporären
Diagnose-Funktionen (`debug_*`, alle wieder entfernt).

**Phase 2 (Notfall-Nachfolgekette) und Phase 3 (protokollierter
Admin-Notfallzugriff) sind seit 2026-08-08 abends ebenfalls live** —
eigene Abschnitte weiter unten ("Gilden-Notfall-Nachfolgekette, Phase 2"
und "Admin-Notfallzugriff, Phase 3"). Damit ist das Gilden-
Sichtbarkeits-Projekt komplett, kein offener Punkt mehr in diesem
Strang. Provisions-/Statistik-Aufteilung bei gemeinsam bearbeiteten Kontakten
war zunächst nur zurückgestellt, ist aber am 2026-08-09 auf Nutzerwunsch
("zu weit in der Zukunft") komplett gestrichen worden — läuft einfach auf
den, der den Abschluss tatsächlich macht, keine Idee mehr für später.

**Direkter Folgeauftrag, noch am selben Tag: bewegter Avatar + Sigil auf
Freundes-/Gilden-Kacheln.** Löst einen offenen Punkt aus der
Konzepts-Konversation selbst ein ("wenn man auf den Freund klickt, sieht
man auch das Sigil der Fähigkeiten"). Die Kacheln in `friendGrid` UND
`guildGrid` (`renderFriendGrid()`/`renderGuildMembers()`) zeigen jetzt
`<canvas class="gt-avatar">` statt des statischen Klassen-Emojis —
dieselbe `createSpriteRenderer()`/`layersForCharacterProfile()`-Technik
wie auf der eigenen Charakterseite, gespeist aus den ohnehin schon
organisationsweit lesbaren `profiles`-Feldern (Aussehen ist nie geheim
gewesen). Klick auf den Avatar (`mountAvatarTile()` → `openFriendSigil()`)
öffnet ein neues `friendSigilModal` mit eigenem `<svg id="friendSigilSvg">`
— `drawSigil()` bekam dafür einen vierten, optionalen Parameter (Ziel-SVG-
Id, Default weiterhin `'sigil'`), keine Verhaltensänderung auf der eigenen
Charakterseite.

Für die Skill-Zahlen selbst reicht Sichtbarkeit von Level/Klasse nicht —
die liegen im privaten `action_log`. Bewusst **keine** breite SELECT-Policy
auf `action_log` (würde auch `context`/`meta`/`location_id`/`contact_id`
offenlegen, potenziell CRM-Notizen) — stattdessen eine schmale neue
RPC-Funktion `friend_skill_totals(target_user)`, die nur die aggregierten
Skill-Summen zurückgibt, geschützt durch `socially_visible()` (Freund
[`friends.status='accepted'`] ODER gemeinsame Gilde ODER man selbst). Live
mit drei Wegwerf-Testaccounts verifiziert: Freund bekommt korrekte Summen
(inkl. `skill2`-40%-Anteil), ein unbeteiligter Dritter bekommt eine leere
Liste.

## Gilden-Notfall-Nachfolgekette, Phase 2 (seit 2026-08-08 abends live)

Löst die in Phase 1 offen gelassene Frage: fällt ein Gildenführer durch
Account-Löschung aus, wer übernimmt die Gilde? Kriterium bewusst simpel
gehalten ("wahre Regeln, sobald ein konkretes Unternehmen da ist"): das
Mitglied mit `team_rights=true`, das am längsten dabei ist (`joined_at`
aufsteigend). Gibt es niemanden mit `team_rights`, fällt es auf das
insgesamt längste Mitglied zurück — eine Gilde soll nie ohne Not
führerlos werden, solange noch irgendwer drin ist. Der Nachfolger erbt
automatisch volle Rechte (`write`/`write`/`team_rights=true`), genau wie
ein Gildengründer.

Sitzt in `handle_member_offboarding()` (`supabase/migrations/
20260808213214_gilden_notfall_nachfolge.sql`), läuft VOR der
bestehenden Pool-/Löschlogik im selben `BEFORE DELETE`-Trigger auf
`auth.users`. **Wichtige technische Korrektur dabei:**
`guilds.founder_id` war bisher `NOT NULL` mit `ON DELETE CASCADE` auf
`profiles` — hätte beim Löschen eines Gildenführer-Accounts die
komplette Gilde samt aller Mitgliedschaften mitgerissen (echtes
Datenverlust-Risiko: "das sind Unternehmensdaten, tausende Kunden",
ausdrückliche Nutzer-Vorgabe). Jetzt nullable + `ON DELETE SET NULL`
als zusätzliches Sicherheitsnetz: bleibt im Extremfall (Gildenführer war
das letzte Mitglied) niemand zum Nachrücken übrig, wird `founder_id`
einfach `NULL` — die Gilde samt allen Pool-Kontakten/-Dungeons bleibt
trotzdem bestehen, nur vorübergehend ohne Führer (siehe Phase 3 für den
Zugriff auf so eine Gilde). Frontend brauchte keine Änderung, `founder_id`
wird überall live gelesen.

End-to-end mit Wegwerf-SQL-Testdaten gegen die echte DB verifiziert (drei
Szenarien: Teamleiter rückt korrekt vor längerem Nicht-Teamleiter nach;
Fallback aufs insgesamt längste Mitglied ohne `team_rights`; Gildenführer
war letztes Mitglied → Gilde bleibt bestehen, `founder_id` wird `NULL`
statt die Gilde zu löschen). Testdaten danach vollständig aufgeräumt.

**Nachtrag 2026-08-09: End-to-End-Test des eigentlichen Offboardings
(Mitarbeiter-Abgang, `supabase/migrations/
20260808211342_mitarbeiter_offboarding_gildenpool.sql`) nachgeholt** — war
bis dahin nur per Schema-Existenz geprüft, nicht per echter
`auth.users`-Löschung. Per Wegwerf-SQL-Testdaten (`supabase db query
--linked -f ...`) drei Szenarien verifiziert, alle korrekt: gildenlos
(Kontakte/Dungeons/Verkäufe komplett weg, per CASCADE über den gelöschten
Kontakt), normales Gildenmitglied (Kontakt/Dungeon landen im Pool,
`sales.created_by` wird `NULL`, Verkauf selbst bleibt bestehen), und —
das eigentlich ungetestete Zusammenspiel — Gildenführer mit eigenen
Kontakten: Nachfolge UND Pooling der eigenen Daten laufen korrekt im
selben Trigger-Durchlauf. Testdaten vollständig aufgeräumt, 0 Reste
verifiziert. Damit ist der Mitarbeiter-Offboarding-Strang komplett
getestet, kein offener Punkt mehr.

## Admin-Notfallzugriff, Phase 3 (seit 2026-08-08 abends live)

Phase 1 hat Admins bewusst von der Standard-Sichtbarkeit ausgeschlossen
("komplett privat, auch für Admins unsichtbar im Alltag"). Phase 3 gibt
dafür einen kontrollierten Ausnahmeweg für echte Notfälle (Kollege nicht
erreichbar, dringender Kundenvorgang): **read-only** Zugriff auf die
privaten Kontakte/Dungeons eines Mitglieds — kein Schreibzugriff, keine
Rechtevergabe. Bewusst **Break-Glass-Muster** (sofortiger Zugriff gegen
Pflicht-Begründung, keine vorherige Freigabe durch eine dritte Person) —
die Kontrolle liegt in der lückenlosen Protokollierung, nicht in einer
Blockade vorher. **Journal-Einträge bleiben bewusst außen vor** — das
ist weiterhin die einzige Tabelle ganz ohne Admin-Ausnahme, daran rührt
Phase 3 nicht.

Neue Tabelle `access_audit_log` (unveränderlich, nur Admin-Select, kein
Insert/Update/Delete für normale Client-Aufrufe — Schreiben passiert
ausschließlich innerhalb der Notfallzugriff-Funktion). Neue RPC-Funktion
`admin_emergency_access(target_user, reason)` (`supabase/migrations/
20260808214213_gilden_notfallzugriff_admin.sql`, SECURITY DEFINER):
prüft `is_admin()`, erzwingt einen Pflicht-Grund, prüft dass die
Zielperson in derselben Organisation ist, loggt den Zugriff, liefert
dann die privaten Kontakte/Dungeons der Zielperson (nur `owner_id =
target_user`, keine Gilden-Pool-Daten — die sind der Gilde ohnehin schon
sichtbar) als JSON. Bewusst nur EIN Log-Eintrag pro Auslösung, nicht pro
angesehener Zeile.

Neue Admin-Seite "🚨 Notfallzugriff" in `index.html` (gleiches
Sichtbarkeits-Muster wie "Fehlerprotokoll"/"Produkte" — `navNotfallzugriffBtn`,
nur bei `profile.role==='admin'` sichtbar): Mitglied-Suche (gleiches
Muster wie der Gilden-Mitglied-Picker, `real_name`/`display_name`,
keine Volliste), Pflicht-Grund-Textfeld, Ergebnis-Anzeige, darunter eine
Protokoll-Liste aller bisherigen Notfallzugriffe (für alle Admins
einsehbar, admin_id/target_user_id via PostgREST-Embedding auf
`profiles.display_name` aufgelöst).

End-to-end gegen die echte DB verifiziert — per `supabase db query` +
`set_config('request.jwt.claim.sub', ...)`, um einen echten
Admin-RPC-Aufruf zu simulieren, ohne einen echten Login/Playwright-Lauf
zu brauchen: positiver Zugriff liefert korrekt Kontakt+Dungeon der
Zielperson UND schreibt den Audit-Log-Eintrag; Aufruf durch einen
Nicht-Admin wird abgewiesen; leerer Grund wird abgewiesen. Testdaten
danach vollständig aufgeräumt.

**Damit ist das gesamte Gilden-Sichtbarkeits-Projekt (Phase 1+2+3) vom
2026-08-08 fertig**, kein bekannter offener Punkt mehr in diesem Strang.

## Vertragsnummer-Feld an `sales` (Patch 41, 2026-08-10)

Migration `supabase/migrations/20260810184939_vertragsnummer.sql`,
**live seit 2026-08-10** (nach Go gepusht). Löst die am 2026-07-31
angekündigte B2B-Vorkehrung ein: nullable `sales.vertragsnummer` (text),
pro Verkaufszeile statt pro Abschluss — ein Abschluss kann mehrere
Produkte/Zeilen erzeugen (`recordWonSalesLoop()`), jede Police hat
üblicherweise ihre eigene Nummer. **Frontend seit demselben Tag
angebunden** (im Zuge des Kontakt-Seiten-Umbaus, siehe eigener Abschnitt
unten): optionales Textfeld `saleEntryVertragsnummer` im
Verkaufs-Popup, Anzeige direkt neben dem Produktnamen in der
Verträge-Zone der Kontakt-Seite (`renderContactSalesTab()`).

## Datei-Upload bei Kontakten (Patch 42, 2026-08-10)

Migration `supabase/migrations/20260810185923_contact_files.sql` +
Frontend in `index.html`, **live seit 2026-08-10** (nach Go gepusht).

**Kurz durchgesprochen, dann gebaut** (kein separates SQL-Vorab-Review,
siehe Kernstruktur-Regel unten): Reiter "Dateien" am Kontakt
(`renderContactFilesTab()`), gleiches `.view-switch`-Tab-Muster wie
Übersicht/Chronik/Tagebucheintrag.

- **Rechte:** kein drittes Freigabe-Level erfunden — nutzt exakt das
  bestehende Gilden-Freigabepaar für Kontakte
  (`guild_contact_permission()` aus Phase 1). Lesezugriff (`'read'`) =
  nur ansehen/herunterladen, Schreibzugriff (`'write'`) = zusätzlich
  hochladen/löschen.
- **Sichtbarkeit folgt 1:1 dem Kontakt** — kein eigenes Sichtbarkeitsmodell
  wie beim Tagebuch, bewusste Nutzerentscheidung ("Folgt dem Kontakt").
- **Grenzen** (Nutzerwunsch "best practice", von Claude konkretisiert):
  max. 10 MB pro Datei (deckt auch mehrseitige gescannte Vertrags-PDFs
  ab), erlaubte Typen PDF + JPEG/PNG/WEBP (kein HEIC, inkonsistente
  Browser-Vorschau). Durchgesetzt **direkt am Storage-Bucket**
  (`file_size_limit`/`allowed_mime_types` in `storage.buckets`, keine
  eigene Trigger-Logik nötig) plus client-seitiger Vorab-Prüfung für
  sofortiges Feedback. Mehrfach-Upload erlaubt (`<input multiple>`), kein
  künstliches Zähl-Limit pro Kontakt.
- **Technik:** privater Bucket `contact-files`, Objektpfad
  `<contact_id>/<uuid>_<dateiname>`, signierte URLs zum Herunterladen
  (`createSignedUrl`, 3600s) — gleiches Grundmuster wie `journal_photos`,
  aber mit Freigabe-Prüfung über den Kontakt statt über einen reinen
  Eigentümer-Ordner (Storage-Policies joinen auf `contacts` +
  `guild_contact_permission()`, dieselbe Bedingung wie bei der
  `contact_files`-Tabelle selbst).
- **Bekannte, bewusst nicht mitgefixte Einschränkung:** `canEdit` auf der
  Kontakt-Seite (`c.owner_id===profile.id || profile.role==='admin'`)
  entscheidet, ob die Upload-/Löschen-Buttons überhaupt angezeigt werden,
  und berücksichtigt **kein** `guild_contact_permission('write')`. Ein
  Gildenmitglied mit Schreibrecht auf einen fremden, geteilten Kontakt
  sieht die Datei-Upload-Buttons deshalb aktuell nicht, obwohl die RLS es
  erlauben würde — vorbestehende Lücke (betraf vorher schon
  "Bearbeiten"/"Löschen"), keine neue, nicht Teil dieses Patches. Bei
  Gelegenheit gemeinsam mit einer echten UI-Prüfung für
  Gilden-Schreibrechte am Kontakt beheben (betrifft dann mehrere Stellen
  auf einmal, nicht nur Dateien).

**Bugfix, noch am selben Tag (Patch 44, `supabase/migrations/
20260810194843_fix_contact_files_storage_rls.sql`):** jeder Upload schlug
live mit "new row violates row-level security policy" fehl — Bugreport
direkt nach Ausprobieren ("hab eine Datei hochgeladen. einfach
verschwunden"). Zwei Ursachen, beide behoben:
1. **Sichtbarkeits-Bug im Frontend:** `renderContactFilesTab()` löschte
   `cdFileStatus.textContent` unbedingt, bevor der Tab komplett neu
   gerendert wurde — dadurch war JEDE Fehlermeldung (und auch der letzte
   Erfolgs-Status) technisch kurz da, aber nie sichtbar, das Feld wurde
   sofort wieder leergemacht und dann ohnehin durch `wrap.innerHTML`
   ersetzt. Fix: Fehlermeldung wird nach dem Neuzeichnen auf das frische
   `cdFileStatus`-Element erneut gesetzt, statt sie vorher zu löschen.
2. **Der eigentliche Bug, den diese Sichtbarkeits-Korrektur erst
   aufgedeckt hat — echte Namenskollision in SQL:** die drei
   Storage-Policies aus Patch 42 (`contact_files_storage_select/insert/
   delete`) benutzten `(storage.foldername(name))[1]`, aber `name` ist
   dort mehrdeutig — `storage.objects` UND das in der EXISTS-Subquery
   korrelierte `public.contacts` haben BEIDE eine Spalte `name`. Postgres
   löste `name` auf das näherliegende `contacts.name` auf (den
   Kunden-Anzeigenamen, z.B. "Jrui Laev") statt auf den Datei-Pfad —
   `foldername()` eines Namens ohne "/" ergibt nie die erwartete
   Kontakt-ID, die Prüfung schlug deshalb für JEDE Datei fehl, unabhängig
   von Berechtigung. Per direkter SQL-Diagnose (`supabase db query
   --linked` + `set_config`) bestätigt: dieselbe Logik mit einem
   Literal-String statt der echten Spalte ergab korrekt `true` — die
   Berechtigungslogik selbst (`guild_contact_permission()` etc.) war nie
   das Problem. Fix: `objects.name` statt `name` — der bloße Tabellenname
   dient als eindeutige Korrelationsvariable der eigenen Zeile innerhalb
   einer RLS-Policy, unabhängig davon, was die Subquery sonst im FROM hat.
   **Lehre fürs nächste Mal:** bei RLS-Policies mit einer Subquery auf
   eine andere Tabelle immer prüfen, ob Spaltennamen kollidieren
   (`name`/`id`/`status` sind in diesem Projekt an mehreren Tabellen
   vergeben) — im Zweifel die eigene Tabelle in der Policy explizit
   qualifizieren, nicht auf unqualifizierte Referenzen verlassen.

Per Playwright end-to-end erneut verifiziert (echter Upload landet in der
Liste, Löschen räumt Storage + Tabellenzeile wieder auf, keine
Konsolenfehler).

**Direkter Folgeauftrag, noch am selben Tag: Datei-Vorschau statt nur
Download.** Klick auf den **Dateinamen** (jetzt ein Link, `.cd-file-name`)
öffnet `filePreviewModal` mit PDF im `<iframe>` bzw. Bild im `<img>` —
alle vier erlaubten Typen (PDF/JPEG/PNG/WEBP) stellt der Browser nativ
inline dar, kein Viewer-Skript nötig. **Bewusst kein dritter Button**
("Ansehen") — Nutzer wollte "Herunterladen"/"Löschen" unverändert lassen,
erste Fassung mit extra Button wurde direkt wieder verworfen. Download
bekam dabei nebenbei eine Verbesserung: `createSignedUrl(..., {download:
f.filename})` erzwingt jetzt den echten Dateinamen beim Speichern statt
des internen UUID-Pfads.

**Bugfix, noch am selben Tag: Nav-Highlight bei Direktaufruf/Reload
einer Kontakt-Seite.** `openContactPage()` setzte anders als `showPage()`
nie `.nav-btn.active` — beim Neuladen direkt auf `#kontakt/<id>` (z.B.
weil der Nutzer während eines laufenden Deploys neu lädt) blieb deshalb
der im HTML hart hinterlegte Default ("🧙 Charakter") als aktiv markiert
stehen, obwohl inhaltlich die Kontakt-Seite angezeigt wurde — Navigation
und Seiteninhalt liefen auseinander. Fix: `openContactPage()` markiert
jetzt genauso wie `showPage('kontakte')` den Kontakte-Button
(`data-page="kontakte"`) als aktiv — automatisch mit dem richtigen
Klassenlabel, da das nur die Textbeschriftung ändert
(Register/Arkanes Register/Kriegsarchiv/Jägerchronik), nicht den
`data-page`-Wert selbst. Per Playwright verifiziert: kompletter
Seiten-Reload direkt auf eine `#kontakt/...`-URL markiert exakt einen
Button korrekt, kein Nachziehen mehr nötig.

## Chronik-Sichtbarkeit folgt der Kontakt-Freigabe (Patch 45, 2026-08-10)

Löst die oben mehrfach als offen dokumentierte Lücke — Nutzerentscheidung,
klar und ohne Umweg: "keine eigene Einstellung. automatisch. wenn man
die Kontakte sehen kann, gehört die Chronik dazu." Migration
`supabase/migrations/20260810201954_chronik_gilden_sichtbarkeit.sql`,
live.

**Vier Tabellen betroffen**, keine davon kannte bis dahin die
Gilden-Freigabe:
- `action_log`/`sales` hatten schon eine "geteilter Kontakt"-Sonderregel,
  aber nur auf Basis der alten organisationsweiten
  `contacts_shared_for_org()`-Einstellung — **bleibt als Fallback
  erhalten** (genau wie bei `contacts` selbst), zusätzlich um
  `guild_contact_permission(c.owner_id, false)` ergänzt.
- `contact_activities`/`termine` hatten **gar keine** Freigabe-Regel,
  nur Eigentümer oder Admin — neue Policy `*_select_shared_contact`
  ergänzt.

`guild_contact_permission(owner_id, false)` (need_write=**false**) ist
bewusst gewählt: liefert `true` für jedes Gildenmitglied mit **Lese-
ODER Schreibrecht** auf den Kontakt — genau "kann den Kontakt sehen",
nicht nur "kann ihn bearbeiten".

**Frontend musste mitgezogen werden, RLS allein reichte nicht:**
`renderContactChronikTab()` fragte `termine`/`contact_activities` bisher
explizit mit `.eq('owner_id', profile.id)`/`.eq('user_id', profile.id)`
ab — eine im Frontend zusätzlich gesetzte Einschränkung, die selbst
nach dem RLS-Fix weiterhin nur eigene Zeilen geliefert hätte. Beide
Filter entfernt, `action_log` bekam dort zusätzlich eine eigene,
kontakt-gebundene Abfrage (`eq('contact_id', c.id)`, keine
`user_id`-Einschränkung mehr) statt wie vorher die global geladene,
bewusst eigentümerbezogene `log`-Liste (die fürs eigene XP/Level exakt
so bleiben muss). `sales` brauchte keine Frontend-Änderung — `cSales`
kam schon vorher ohne Eigentümer-Filter aus `loadContactsBundle()`.
**„Zuletzt kontaktiert (von dir)" bleibt unverändert** — explizit als
"von dir" gekennzeichnet, nicht Teil dieser Änderung.

**Verifiziert nicht nur mit dem eigenen Admin-Zugang** (der ohnehin
alles sieht), sondern mit zwei echten Kollegen-Accounts über eine
temporäre Gilden-Testmitgliedschaft (`supabase db query --linked` +
`set_config`, danach vollständig entfernt): mit Lesezugriff sah der
Kollege alle 25 `action_log`- und 7 `contact_activities`-Einträge eines
echten Kontakts korrekt, ohne Mitgliedschaft exakt 0 — inklusive des
Kontakts selbst. `guild_contact_permission(..., true)` (Schreibrecht)
lieferte für den reinen Lese-Zugriff korrekt `false`.

## Kontakt-Seite statt Popup (Patch 43, 2026-08-10)

**Auslöser:** Nutzer-Frust über ein früher genutztes CRM im sozialen
Bereich, das Kontakte nicht per Rechtsklick in einem neuen Tab öffnen
ließ ("richtig schlecht gelöst ... hätte viele Arbeitsschritte gespart").
Das bisherige `contactDetailModal`-Popup hatte exakt dieses Problem
strukturell eingebaut — keine echte URL, nur ein per JS ein-/ausgeblendetes
Overlay. Komplett ersetzt durch eine echte Unterseite mit eigenem
Hash-Pfad.

**Design-Prozess:** drei Zonen-Layout-Vorschläge (Kompakt / Seitenleiste /
Gestapelte Record-Seite) erst als Skizze im Chat, dann auf Nutzerwunsch
als reine Grau-Wireframes (keine Farben, "wirklich nur die Zonen") per
Artifact gezeigt. Nutzer wählte "Kompakt" (Kundendaten oben, Verträge
immer sichtbar in der Mitte, Reiter darunter) als Grundstruktur, dann in
einer zweiten Artifact-Runde drei konkrete Ausführungen davon (Kompakt /
Kennzahlen-Leiste / Kartenliste) — gewählt wurde **Kennzahlen-Leiste**
("die Übersicht mit den Kennzahlen find ich cool, auch das mit dem
Zuletzt kontaktiert!").

**Routing:** zweites Hash-Format neben den einfachen Seitennamen
(`VALID_PAGES`) — `#kontakt/<uuid>`, ausgewertet in `routeToHash()`
(Weiche vor `showPage()`, da der zweite Teil dynamisch ist, keine feste
Liste). `openContactPage(id)` lädt über das bereits bestehende
`loadContactsBundle()` (bewusst nicht extra für einen Einzelkontakt
optimiert — bei der aktuellen Datenmenge unnötige Vorab-Optimierung,
Rule of Three) und rendert `#page-kontakt-detail`, eine ganz normale
`.page`-Seite (kein Modal mehr, kein `contactDetailModal`,
`contactDetailClose` entfernt). Ein nicht gefundener/nicht zugänglicher
Kontakt (kaputter Link, fehlende Berechtigung) zeigt `#kdNotFound` statt
eines Fehlers. `openContactPage()` läuft sowohl beim Klick als auch bei
einem frischen Seitenaufruf mit `#kontakt/...` in der URL (Deep-Link,
z.B. aus einem neuen Tab) — per Playwright verifiziert: Reload derselben
URL zeigt exakt denselben Kontakt.

**Rechtsklick/neuer Tab funktioniert jetzt überall, wo ein Kontaktname
auftaucht** — durchgängig über echte `<a href="#kontakt/<id>">`, nicht
mehr über reine Klick-Handler:
- Kontakttabelle (`renderContactsTableInto`): **Stretched-Link-Muster**
  (`.ctable-row-link` im Namensfeld, `::after{position:absolute;inset:0}`
  streckt die Klickfläche über die ganze Zeile) — bleibt technisch ein
  einzelner `<a>`-Tag, die ganze Zeile bleibt trotzdem klickbar.
- Kanban-Karten: **kein** Stretched-Link (Konfliktrisiko mit dem
  bestehenden `draggable="true"` fürs Ziehen) — stattdessen ist gezielt
  nur `.kc-name` ein echter `<a draggable="false">`, der Rest der Karte
  bleibt ein normaler Klick-Handler (`location.hash = ...`) fürs bequeme
  große Klickziel. Zwei Mechanismen nebeneinander, bewusst kein
  Kompromiss bei der Drag-&-Drop-Zuverlässigkeit.

**Layout (Variante "Kennzahlen-Leiste"):** Kopf-Karte (Name, Status-Pill,
Berufsstatus/Betrieb, Telefon/E-Mail/Wohnort, Aktions-Buttons) →
Kennzahlen-Leiste (`renderContactStatStrip()`: Anzahl Verträge,
Chronik-Einträge, Dateien, "Zuletzt kontaktiert") → Verträge-Zone
**immer sichtbar** (vorher ein eigener Reiter "Verkaufshistorie", jetzt
in `renderContactSalesTab()` fest zwischen Kopf und Reitern verankert,
kein Tab-Umschalten mehr nötig) → Reiter Übersicht/Chronik/
Tagebucheintrag/Dateien (Übersicht enthält jetzt nur noch Geburtsdatum/
Bedarf-Ist/-Wunsch/Nächster Kontakt/Zuletzt kontaktiert/Notizen —
Berufsstatus/Betrieb/Telefon/E-Mail/Wohnort wanderten in den Kopfbereich,
um Dopplung zu vermeiden). Chronik-Anzahl für die Kennzahlen-Leiste kommt
aus `chronikItemsCache.length` (derselbe gemergte Datensatz, den
`renderContactChronikTab()` ohnehin schon aufbaut), Dateien-Anzahl über
einen schlanken `count:'exact', head:true`-Zählaufruf.

**Refresh-in-place statt Modal-Schließen:** `currentContactPageId` +
`refreshContactPageIfCurrent(id)` ersetzen das frühere Muster "Modal
schließen, Popup öffnen, danach ggf. wieder öffnen" — Aktion loggen,
Anruf/Email loggen, Termin eintragen, Verkauf eintragen und Kündigen
rendern die offene Kontakt-Seite jetzt einfach neu, statt sie zu
verstecken. "Bearbeiten" springt zur Kontakte-Seite und öffnet dort das
bestehende Inline-Formular (`startEditContact()`, unverändert), "Löschen"
navigiert danach zurück zu Kontakte.

**Bekannte, bewusst nicht mitgefixte Einschränkung (identisch zum
Datei-Upload-Punkt oben, jetzt an einer Stelle sichtbar für ALLE
Aktions-Buttons):** `canEdit` berücksichtigt weiterhin kein
`guild_contact_permission('write')`.

Per Playwright gegen den echten Account verifiziert: echter `<a
href="#kontakt/...">` mit Ziel-UUID, Klick navigiert korrekt (Hash ändert
sich, alte Seite verschwindet, neue erscheint), Kennzahlen-Leiste füllt
sich, Verträge-Zone ohne Tab-Klick sichtbar, alter
Verkaufshistorie-Reiter weg, Dateien-Reiter funktioniert, **Deep-Link per
komplettem Seiten-Reload liefert denselben Kontakt** (das ist der
eigentliche Rechtsklick-neuer-Tab-Beweis), Zurück-Button führt korrekt
zu Kontakte, Kanban-Karten-Link ebenfalls ein echter Link und
funktioniert. Kein horizontales Overflow auf 390px Mobile-Breite, keine
Konsolen-/Seitenfehler in beiden Durchläufen.

**Nachbesserung, noch am selben Tag:** die neue Seite stand beim ersten
Wurf an der alten Modal-Position im HTML (nach `</div></div></div>` des
`.content`/Sidebar-Wrappers, zwischen den übrigen `.loc-modal`-Popups) —
technisch ein `.page`-Element, aber strukturell außerhalb des
Sidebar-Layouts. Ergebnis: die Kontaktkarte rutschte auf Desktop unter
die komplette Navigationsleiste statt daneben zu sitzen ("Anordnung
gerade noch grauenhaft", Nutzer-Feedback nach dem ersten Screenshot).
Fix: den ganzen `#page-kontakt-detail`-Block innerhalb von `.content`
platziert, direkt neben den anderen `.page`-Geschwistern (nach
`#page-notfallzugriff`) — sitzt seitdem korrekt neben der Sidebar, wie
jede andere Seite auch. **Lehre:** eine neue `.page` muss strukturell
(nicht nur per Klassenname) im selben Container wie die bestehenden
Seiten stehen, sonst greift das Sidebar-Layout nicht — beim nächsten Mal
vor dem ersten Screenshot direkt gegenprüfen, nicht erst nach
Nutzer-Beschwerde.

## Serverseitige Schreib-Härtung: user_inventory / action_log / sales / locations (2026-08-15 abends)

Löst die am 2026-08-07 gefundene, damals bewusst zurückgestellte
`user_inventory`-RLS-Lücke endgültig — auf Nutzerwunsch ("will das vom
Tisch haben"), danach auf die Nachfrage "haben wir noch dringliche
Themen davon" um drei weitere, im selben Zug gefundene Stellen erweitert
(`action_log`, `sales`, `locations`). **Wiederkehrendes Muster über alle
vier:** die RLS-Regel prüfte bisher nur "gehört dir die Zeile", nicht ob
der geschriebene WERT plausibel ist — dieselbe Lückenklasse wie die
XSS-Lücke vom 2026-08-07, nur auf der Schreib- statt der Lese-Seite.

**Migrationen:** `20260815223000_user_inventory_rpc_haertung.sql` +
`20260815230000_action_log_sales_locations_haertung.sql`.

**`user_inventory`** (Items/Ausrüstung): direktes Schreiben komplett
gesperrt (`inventory_insert_own`/`inventory_update_own` entfernt). Zwei
neue `SECURITY DEFINER`-Funktionen sind der einzige verbleibende Weg:
`grant_item_to_self(item_key)` (immer exakt +1, prüft `item_key` gegen
`rule_configs.config.items`) und `consume_item_from_self(item_key)`
(immer exakt -1, lehnt ab wenn nichts mehr da ist). `grantItem(key, qty)`
in `index.html` ruft die Grant-Funktion jetzt `qty`-mal in einer Schleife
auf statt selbst eine absolute Menge zu berechnen — ein einzelner Sprung
auf einen beliebigen Wert ist dadurch strukturell unmöglich.

**`action_log`** (das komplette XP-/Level-System — **die wichtigste der
vier Stellen**, da Level nie gespeichert, sondern immer live aus dieser
Tabelle aufsummiert wird): direktes Schreiben ebenfalls komplett gesperrt
(`log_insert_own` entfernt). Drei neue Funktionen decken alle vorher 9
Insert-Stellen in `index.html` ab:
- `log_action_for_self(action_key, context, location_id, contact_id,
  meta, occurred_at)` — der Normalfall (Ansprache, Kalttelefonie,
  Kanban-Übergänge, Kontakt-Chronik-Einträge, Dungeon-Aktionen). xp/
  energy/skill/skill2/label werden IMMER aus `rule_configs.config.
  actions[action_key]` gelesen, nie vom Client übernommen — ein neuer,
  im Regelwerk noch nicht existierender `action_key` wird abgelehnt.
- `grant_quest_bonus_to_self(kind, quest_id, period_key, stage_id)` —
  tägliche/wöchentliche Quests (`kind:'recurring'`) und Quest-Ketten
  (`kind:'chain'`). Bonus-XP kommt aus `config.recurringQuests`/
  `config.questChains`, zusätzlich ein Duplikat-Schutz (kann nicht
  zweimal für denselben Zeitraum/dieselbe Stufe vergeben werden — sonst
  wäre der eigentliche Katalog-Wert zwar korrekt, aber beliebig oft
  wiederholbar gewesen).
- `log_item_energy_refill_for_self(item_key)` — der Manatrank-Effekt.
  Einziger Sonderfall mit einem nicht-festen Wert: wie viel Energie
  aufgefüllt wird, hängt von der heute schon verbrauchten Energie ab.
  Wird jetzt serverseitig aus der echten Tagessumme (Zeitzone
  `Europe/Berlin`, wie `todayKey()` im Frontend) berechnet, nicht vom
  Client übernommen.

**`sales`** (Verkäufe/Provision): anders als bei den beiden obigen gibt
es hier keinen Katalogwert zum Gegenprüfen — Bewertungssumme/laufender
Beitrag/Menge sind echte, frei einzugebende Vertragsdaten. Deshalb kein
vollständiger Verschluss, sondern CHECK-Constraints als
Plausibilitätsgrenzen (`bewertungssumme`/`laufender_beitrag` 0 bis
100 Mio./1 Mio., `menge` 1 bis 1000 — großzügig genug, um nie im echten
Betrieb zu stören, aber "9999"-artigen Unsinn zu blocken). Zusätzlich
muss `created_by` beim Anlegen die eigene ID sein (verhindert
Verkäufe unter fremdem Namen).

**`locations`** (Dungeons): `owner_id`/`created_by` dürfen beim Anlegen
nicht mehr auf eine fremde Person zeigen — die App selbst tat das nie
(setzt beide immer auf sich selbst bzw. `owner_id` NULL für den
Gilden-Pool), die Lücke war nur über einen direkten API-Aufruf
ausnutzbar und hätte höchstens zu falscher Zuordnung geführt, kein
echter Sicherheitsvorfall.

**Verbindliche Regel für neuen Code, ab jetzt:** wer eine Aktion loggen
will, ruft `log_action_for_self()`/`grant_quest_bonus_to_self()`/
`log_item_energy_refill_for_self()` per `sb.rpc(...)` auf — ein direktes
`sb.from('action_log').insert(...)` schlägt seit dieser Migration mit
einem RLS-Fehler fehl (keine Policy mehr dafür). Genauso bei Items: immer
`grant_item_to_self()`/`consume_item_from_self()`, nie direktes
insert/update/upsert auf `user_inventory`. Ein neuer `action_key` oder
Item braucht dafür KEINE Schema-Änderung — einfach im Regelwerk
(`rule_configs.config.actions`/`items`) ergänzen, die Funktionen lesen
das live.

**Bewusst nicht geschlossen (gleiche Abwägung wie beim ursprünglichen
Nutzer-Gespräch, ausführlich besprochen):** ob eine Quest/Handlung
wirklich verdient wurde, wird weiterhin nicht serverseitig nachgeprüft —
die Funktionen verhindern nur "erfundener Wert"/"erfundener Schlüssel"/
"doppelt kassiert", nicht "wurde wirklich gehandelt". Das würde die
komplette Quest-Auswertung (`evaluateLadderQuest()` & Co., aktuell nur im
Browser) zusätzlich serverseitig nachbauen — ein eigenes großes Projekt,
als künftige Skalierungs-Schwelle in Claudes Erinnerungssystem
(`project_business_fahrplan`, Phase 5) vermerkt, nicht sofort gebaut.

End-to-end gegen die echte DB verifiziert (jede Sperre UND jeder
legitime Ablauf einzeln getestet, u.a. `set_config('request.jwt.claim.
sub', ...)` + `set role authenticated` gegen den echten Admin-Account),
Testzustand danach exakt auf den Ausgangswert zurückgesetzt (alle
Zeilenzahlen unverändert).

**Direkter Folgeauftrag, noch am selben Abend: systematischer statt
zufälliger Durchgang.** Nutzerfrage "gibt es noch andere Grundregeln,
die wir übersehen haben" — alle `INSERT`/`UPDATE`-Policies im gesamten
Schema auf einen Schlag geprüft (`pg_policies`), nicht mehr nur die
Tabellen, an die zufällig gedacht wurde. Ergebnis: `rule_configs` und
`products` sind bereits sauber admin-only (der ganze Tag hing also nicht
in der Luft), aber zwei weitere echte Funde, beide live bestätigt und
behoben (Migration
`20260815233000_guild_selfjoin_und_level_cache_haertung.sql`):

- **`guild_members`-Selbstbeitritt** — die ernsteste Lücke des ganzen
  Tages, weil sie echten Zugriff auf Kolleg:innen-Daten verschafft, nicht
  nur Kosmetik: `contacts_access`/`dungeons_access`/`team_rights` waren
  beim Selbst-Beitritt (`joinGuild()`) komplett ungeprüft — ein Mitglied
  hätte sich beim Beitreten sofort Schreibzugriff auf alle geteilten
  Kontakte/Dungeons UND die Nachfolge-Berechtigung selbst geben können,
  ganz ohne Gründer-Zutun. Live bestätigt (Wegwerf-Testmitgliedschaft,
  danach entfernt). Fix: Selbst-Beitritt erzwingt jetzt die echten
  Minimalrechte (Lesen, kein Team-Recht) — außer beim Gründer der eigenen
  Gilde (`guildCreateBtn` setzt sich legitim volle Rechte, bleibt
  erlaubt).
- **`profiles.total_xp`/`level`** — reiner Anzeige-Cache (die Wahrheit
  bleibt immer `action_log`), aber direkt auf einen beliebigen Wert
  überschreibbar (Level 100 ohne einen Punkt XP, sichtbar für Freunde/
  Gilde über die Avatar-Kacheln). Live bestätigt. Fix: neue Funktion
  `sync_own_level_cache()` berechnet total_xp/level serverseitig aus der
  echten `action_log`-Summe + der echten Level-Kurve
  (`rule_configs.config.levelBase`/`levelExponent`, identische Formel wie
  `xpForLevel()`/`levelInfo()` im Frontend) neu.
  `protect_privileged_profile_fields()` (Patch 38/39) bekam dafür eine
  dritte Prüfung, erkennbar an einem Transaktions-lokalen Sitzungs-Flag
  (`app.trusted_level_sync`), das nur diese eine Funktion setzt — jeder
  andere Schreibversuch auf diese beiden Spalten wird blockiert.
  **Admin-Bypass bleibt bestehen**, wie bei role/character_class/org_id
  (konsistent mit dem Rest der Funktion) — beim Testen zunächst
  fälschlich mit dem eigenen Admin-Account geprüft (Bypass griff
  erwartungsgemäß), danach korrekt mit einem echten Nicht-Admin-Konto
  verifiziert (Blockade griff).
  `syncProfileStatsCache()` in `index.html` ruft jetzt `sb.rpc('sync_
  own_level_cache')` statt eines direkten `.update()` auf.

**Bekannter Datenverlust beim Testen, offen kommuniziert:**
`profiles.company` des Admin-Accounts wurde während eines Testschritts
mit einem Platzhalterwert überschrieben, der ursprüngliche Inhalt war
nicht mehr rekonstruierbar (rein informatives Freitextfeld, siehe
"Profil-Onboarding" oben) — auf `NULL` zurückgesetzt, Nutzer informiert,
bei Bedarf in Einstellungen neu einzutragen. **Lehre fürs nächste Mal:**
vor einem Test-Schreibvorgang auf ein Feld ohne bekannten Ausgangswert
immer zuerst den aktuellen Wert auslesen und sichern, nicht raten oder
mit `NULL` überschreiben.

## Sicherheitswarnungen (Alarm-Logging), Patch 47 (2026-08-16)

Löst Punkt 9 der BaaS-Aufgabenliste ("Logging mit echter Reaktion statt
nur Speicherung") — Auslöser: offene Selbstregistrierung + öffentlich
erreichbare App bedeuten, dass ein Angriff nicht zwingend über die
eigene Oberfläche laufen muss. Bisher landete ein abgewehrter
Manipulationsversuch nur dann im Fehlerprotokoll, wenn der **Browser**
ihn freiwillig meldete — ein direkter API-Aufruf an unserer Oberfläche
vorbei blieb komplett unsichtbar.

**Neue Tabelle `security_alerts`** (nur Admins dürfen lesen, Schreiben
ausschließlich über die neue Funktion `log_security_alert()`, die
absichtlich NICHT per RPC aufrufbar ist — siehe unten). Migration
`supabase/migrations/20260816140000_security_alerts.sql`.

**Kernidee — "korrigieren statt ablehnen", damit der Log-Eintrag
niemals durch ein Rollback verloren geht:** die beiden schwerwiegendsten,
am 2026-08-15 gehärteten Lücken (`profiles`-Rechte-Felder,
`guild_members`-Selbstbeitritt) wurden von "hart ablehnen" (`raise
exception`) auf "still auf einen sicheren Wert zurücksetzen UND
protokollieren" umgestellt — dasselbe Muster, das
`enforce_profile_insert_defaults()` (Patch 39) schon lange nutzt. Grund
für die Umstellung: ein reines `raise exception` hätte den Log-Eintrag
selbst mit in denselben Transaktions-Rollback gerissen — ein sauberer
Log-auf-Rollback-Mechanismus bräuchte eine autonome Datenbank-Verbindung
(z.B. über die `dblink`-Erweiterung), was ein eigenes
Verbindungs-Geheimnis nötig gemacht hätte. Widerspricht dem
Architekturprinzip dieses Projekts ("kein versteckter
Backend-Schlüssel", siehe Sicherheits-Durchgang 2026-08-07) — deshalb
bewusst nicht eingebaut. Für legitime Aufrufe ändert die Umstellung
nichts: kein Weg in der App schickt diese Felder je in einem normalen
Aufruf, Admins sind ohnehin ausgenommen.

**Bewusst NICHT Teil dieses Schritts, ehrliche Grenze:** die übrigen,
bereits am 2026-08-15 gehärteten Stellen ohne sinnvollen "korrigierten"
Wert (erfundener `action_key`/`item_key`, doppelt eingelöste Quest,
`sales`-Grenzwerte, `locations`-Owner-Fälschung) bleiben weiterhin
zuverlässig blockiert — der Schreibversuch kann so oder so nie
erfolgreich sein, es fehlt nur die Alarmierung selbst (reine
Aufklärung "wer probiert rum", kein Datenrisiko). Bräuchte dieselbe
Autonome-Transaktion-Frage wie oben — als Wiedervorlage vermerkt, kein
aktueller Auslöser.

**Schweregrad wird nicht gespeichert, sondern im Frontend live
berechnet** (`securityAlertSeverity()` in `index.html`, gleiches
Ableitungs-Prinzip wie `computeTotals()`): Best-Practice-Muster
rate-basierter Anomalie-Erkennung (vgl. AWS GuardDuty/Auth0) — 5+
Vorfälle derselben Person innerhalb von 15 Minuten = Kritisch, 2-4 =
Häufung, sonst Einzeln.

**Bedienung:** Popup beim nächsten Admin-Login (`securityAlertModal`,
gleiches Muster wie das Changelog-Popup, "gesehen" wird beim Erscheinen
gezählt über `profiles.last_seen_security_alert`), dauerhaft einsehbar
im umbenannten Fehlerprotokoll-Reiter (jetzt zwei Karten: "Sicherheits-
warnungen" oben, "Fehlerprotokoll" darunter).

**Wichtiger Stolperstein, selbst gefunden und behoben, bevor er zum
Problem wurde:** neue Funktionen im Schema `public` bekommen laut den
bestehenden `ALTER DEFAULT PRIVILEGES`-Regeln automatisch `EXECUTE` für
`anon`/`authenticated` (erklärt auch, warum der Advisor am 2026-08-11
"28 von anon/authenticated ausführbare Funktionen" meldete). Ohne
Gegenmaßnahme hätte jeder Nutzer eigene, erfundene Alarme per direktem
RPC-Aufruf einschleusen können — Rauschen oder gezielte Verschleierung
echter Vorfälle. `log_security_alert()` bekam deshalb ein explizites
`revoke execute ... from public, anon, authenticated`. Die beiden
Trigger-Funktionen (`protect_privileged_profile_fields`,
`enforce_guild_selfjoin_limits`) brauchen das nicht — `returns
trigger`-Funktionen kann Postgres strukturell nicht per RPC aufrufen
lassen, unabhängig von vergebenen Rechten (gleiche Begründung wie beim
Advisor-Durchgang 2026-08-11).

End-to-end mit einem Wegwerf-Testprofil gegen die echte DB verifiziert
(`set_config('request.jwt.claim.sub', ...)` + `set role authenticated`):
Selbst-Admin-Versuch UND Level-Fälschung in einem Aufruf → beide
Werte blieben unverändert, zwei Alarme protokolliert. Gilden-
Selbstbeitritt mit `write`/`write`/`true` → Mitgliedschaft wurde
angelegt, aber auf `read`/`read`/`false` zurückgesetzt, ein Alarm
protokolliert. Direkter RPC-Aufruf von `log_security_alert()` als
normaler Nutzer → `permission denied`, wie beabsichtigt. Testdaten
danach vollständig entfernt (0 Reste verifiziert).

## Questbaum: Jahres-Reset + Bonus-XP für den gesamten Baum, Patch 50 (2026-08-17)

Löst den seit der Krankenhaus-Meister-Migration (Patch 49) offenen Punkt:
bis dahin gaben nur zwei Questbaum-Stufen echte Bonus-XP, der Rest nur
Titel. Auf Nutzerwunsch jetzt konsequent zu Ende gebracht — **mit einer
wichtigen Kurskorrektur mitten in der Absprache**: Questbaum-Stufen sind
**Jahresquests**, nicht einmalige Lebensleistungen. Geschäftsjahr =
Kalenderjahr (deckt sich mit den bestehenden Jahr/Monat-Reitern im
Kompendium).

**Design-Prozess:** zwei Artifact-Runden (gleiche URL, v1→v2) mit dem
Nutzer durchgesprochen — v1 kalkulierte jede Stufe als einmalige
Lebensleistung (levelBase 4,70→5,02, +6,8%), nach dem Jahresquest-
Hinweis wurde daraus v2 mit geschätzter Häufigkeit pro Stufe über 10
Jahre (Einstiegsstufe ~9-10/10 Jahre, Top-Stufe ~1-2/10) — Ergebnis
`levelBase` 4,70→**5,80** (+23,3% Gesamt-XP bis Level 100, siehe
Abschnitt "Level-/XP-System" oben für die genaue Methodik). Die
einzelnen Bonus-XP-**Werte** pro Stufe/Epic (15-450 gestaffelt nach
Ladder-Länge/Position, Epics 100-800 je nach Anzahl/Schwere der
Voraussetzungen) blieben zwischen v1 und v2 unverändert — nur die
Interpretation "einmal vs. jährlich wiederholbar" änderte sich.

**Technik:**
- `evaluateLadderQuest`/`evaluateSalesLadderQuest`/`evaluateRatioQuest`/
  `evaluateStreakQuest` (in `index.html`) werten jetzt nur noch
  Ereignisse/Verkäufe des **laufenden Kalenderjahres** aus (neue Helfer
  `currentBusinessYear()`/`logInCurrentYear()`), nicht mehr die komplette
  Lebenszeit — Stufen resetten damit automatisch zum 1. Januar, ein
  Streak kann strukturell nicht über den Jahreswechsel hinweg laufen.
- **Epics geben jetzt echte Bonus-XP** (vorher nur Titel + Feier-Toast):
  `checkAndAwardEpics()` ist async geworden, ruft bei neu erfülltem Epic
  `grant_quest_bonus_to_self()` mit `p_stage_id = p_quest_id` auf (ein
  Epic hat kein `stages`-Array, nutzt seine eigene id doppelt als
  Erkennungsmerkmal — wichtig für spätere Auswertungen wie den
  Schatzraum, siehe unten).
- `grant_quest_bonus_to_self()` (SQL): der `questtree`-Zweig verlangt
  jetzt zwingend `p_period_key` (das Jahr, gleiches Prinzip wie beim
  `recurring`-Zweig) und verzweigt bei `type='epic'` auf ein flaches
  `bonus`-Feld am Epic selbst statt in ein `stages`-Array zu schauen.
  Duplikat-Schutz erweitert von "pro Stufe einmal" auf "pro Stufe **und
  Jahr** einmal" (`meta.year` zusätzlich zu `questTreeId`/`stageId` in
  der Duplikat-Prüfung).
- Migration `supabase/migrations/20260817120000_questbaum_jahresreset_bonus_xp.sql`
  — die komplette neue `questTree`-JSON wurde **programmatisch erzeugt**
  (Node-Skript liest die echte Live-DB-JSON, mappt Bonus-Werte per
  Stufen-/Epic-id, schreibt zurück) statt von Hand transkribiert, bei
  87 einzelnen Feldern bewusst kein Handarbeits-Risiko eingegangen.

**Dreifach verifiziert, dann per Nutzer-Go gepusht:** SQL-Dry-Run
(`begin`/`rollback`, 10 Einzeltests: korrekte Auszahlung, doppelte
Vergabe im selben Jahr blockiert, dieselbe Stufe im Folgejahr erneut
auszahlbar, Epic-Pfad, diverse Fehlerfälle), ESLint sauber, Playwright-
Simulation (synthetische Vorjahresdaten wurden korrekt ignoriert). Nach
`supabase db push`: `levelBase`=5,80, 78 Stufen + 11 Epics mit
`bonus`-Feld live bestätigt, Patch 50 in `schema_patches`. Beim ersten
echten Login danach wurden über 15 bereits erfüllte Stufen automatisch
nachgezahlt (funktioniert wie beim Krankenhaus-Meister-Vorbild).

## Schatzraum: Reliquienkammer / Ruhmeshalle / Jagdkammer (2026-08-17)

Direkter Folgeauftrag aus dem Jahres-Reset oben: sobald jede Stufe zum
1. Januar zurückspringt, verschwindet eine Vorjahres-Leistung sonst
spurlos aus der laufenden Questbaum-Ansicht. Der Schatzraum ist der Ort,
an dem sie sichtbar bleibt.

**Zwei Baurunden — die erste landete nicht, Nutzer-Feedback war
präzise genug für eine direkte Korrektur ohne neuen Artifact-Vorlauf:**

*Erster Entwurf* (inline aufklappende Kachel im Kompendium/Kriegskasse/
Trophäenkammer, ähnlich dem Zauberbuch-Muster): zeigte ALLE
`questtree_bonus`-Log-Einträge (auch einzelne Ladder-Stufen wie
"20% Türöffner-Quote") als flache `.log-entry`-Liste. Nutzer-O-Ton: "in
der jetzigen Form ist das nicht wertschätzend."

*Korrigierte Fassung, live:*
- **Öffnet als Vollbild-Unterseite** (`#trophyRoomModal`, `.qt-fullscreen`,
  identisches Muster wie `#questTreeModal` inkl. `history.pushState`/
  `popstate`-Handling — Browser-Zurück schließt nur den Raum) statt
  inline aufzuklappen. Die Kachel im Kompendium bleibt als reiner
  Türöffner bestehen.
- **Zeigt nur Epics** ("Trophäen"/Titel), keine einzelnen Ladder-/Ratio-/
  Streak-Stufen mehr. Ein Epic-Bonus ist am `action_log`-Eintrag daran
  erkennbar, dass `meta.stageId === meta.questTreeId` (`trophyEpicInfo()`
  filtert danach).
- **"In Ebenen" gruppiert:** eine Sektion pro Questbaum-**Kategorie**
  (Reihenfolge folgt `config.questTree`, nur sichtbar wenn dort im
  gewählten Jahr wirklich etwas erlangt wurde), jede Trophäe eine
  goldgerahmte `.trophy-card` (🏅-Icon, Titel, Label, Datum, XP — Optik
  1:1 vom bestehenden `.epic-toast` übernommen, keine neue Bildsprache
  erfunden).
- **Jahr prominent verankert:** groß und zentral, mit explizitem Tag
  "Laufendes Jahr" (grün) vs. "Archiviert" (amber). Der automatische
  Sprung ins neue Jahr am 1. Januar braucht keinen Cron/Trigger —
  `trophyRoomYear` initialisiert auf `new Date().getFullYear()`, die
  Obergrenze in `trophyRoomYearBounds()` ist immer
  `currentBusinessYear()`, ergibt sich rein aus dem Ladezeitpunkt.
- Darunter unverändert: kompakte Zusammenfassung der 5 bestehenden
  Kompendium-Kennzahlen fürs gewählte Jahr (neue `salesForYear(year)`-
  Funktion, füttert die bestehende `aggregateStats()`).
- Klassen-Namen (Nutzer wollte explizit 2 Vorschläge je Klasse zur
  Auswahl, kein gemeinsamer Name wie beim Zunftbuch-Präzedenzfall):
  **Reliquienkammer** (Zauberer, 💎), **Ruhmeshalle** (Krieger, 🏆),
  **Jagdkammer** (Schütze, 🏹).

Kein neues DB-Feld/keine neue Tabelle nötig — reine Ableitung aus
bereits vorhandenem `action_log` (das Jahr steckt seit Patch 50 in
`meta.year`) + `mySalesCache`. Per Playwright verifiziert (Desktop +
Mobile 390px, Negativtest dass eine Nicht-Epic-Stufe wirklich nicht
auftaucht, Jahres-Navigation vor/zurück inkl. Vorjahres-Trophäe, kein
horizontales Overflow, keine Konsolenfehler).

## RLS-Performance-Härtung (2026-08-17)

Löst den in der "Nachtrag: locName()-XSS-Lücke + Datenbank-Advisor-
Durchgang (2026-08-11)"-Notiz oben bewusst zurückgestellten Punkt
("erst bei echtem Abfrage-Volumen angehen") — auf Nutzerwunsch jetzt
vorgezogen, nachdem der Advisor-Stand seit 2026-08-11 spürbar gewachsen
war (60 `multiple_permissive_policies`, 52 `auth_rls_initplan`). Reine
Effizienz-Migration, **keine** Verhaltensänderung — wer was sehen/
bearbeiten darf, ist exakt gleich geblieben.

Migration `supabase/migrations/20260817210000_rls_performance_haertung.sql`.
Zwei Muster:
1. `auth.uid()` wird zu `(select auth.uid())` gewrappt, damit Postgres
   es einmal pro Abfrage statt einmal pro Zeile auswertet — an der
   Quelle in den 7 zentralen Hilfsfunktionen (`current_org_id`/
   `is_admin`/`guild_contact_permission`/`guild_dungeon_permission`/
   `guild_founder_of_member`/`guild_leadership_permission`/
   `socially_visible`, die praktisch jede Policy im Schema nutzt) sowie
   in 39 einzelnen Policies mit direktem `auth.uid()`-Aufruf.
2. 10 Tabellen mit mehreren permissiven Policies je Aktion (21
   Original-Policies: action_log/contact_activities/contacts×2/friends/
   guild_members/locations/profiles×2/termine SELECT) wurden zu je
   einer Policy zusammengelegt — mathematisch exakt dieselbe
   ODER-Verknüpfung, die Postgres bei mehreren permissiven Policies
   ohnehin schon bildet (USING-Klauseln separat, WITH CHECK-Klauseln
   separat), nur als eine statt mehrerer Prüfungen pro Zeile.
   Policy-Zahl insgesamt: 75→64.

**Vor dem Schreiben der Migrationsdatei in einer `begin`/`rollback`-
Transaktion gegen die echte DB getestet** (nichts blieb hängen): 35
Sichtbarkeits-Snapshots (7 echte Kolleg:innen-Accounts × die 5 am
stärksten betroffenen Tabellen) vorher/nachher exakt identisch, plus 7
gezielte Schreibproben für die kniffligsten Fälle (Kontakt-Gildenpool-
Zuweisung, Gildenführer aktualisiert Location eines Gildenmitglieds,
alle zugehörigen Verweigerungsfälle) — dabei ein eigener Testaufbau-
Fehler gefunden und korrigiert (`guild_leadership_permission()`
verlangt `team_rights=true`, nicht nur Schreibzugriff — kein Bug in der
Migration, nur ein zu lax konfigurierter Wegwerf-Testnutzer). Nach dem
`supabase db push` per erneutem Advisor-Lauf bestätigt: 0 verbleibende
`auth_rls_initplan`/`multiple_permissive_policies`-Funde (vorher
52/60), `migration list --linked` zeigt local==remote.

## Kanban-Kurzvorschau + Termin-Einladungen für Gildenmitglieder (2026-08-18)

Zwei zusammenhängende Bausteine, in derselben Session entstanden, direkt
nach dem Termin-Datumsgrenzen-Vorfall desselben Tages (siehe Abschnitt
"Kanban" oben — dort ist auch der zugrundeliegende, bei dieser Gelegenheit
gefundene und behobene Listener-Stacking-Bug beschrieben).

**Kanban-Kurzvorschau** (`#kanbanPreviewModal`, `openKanbanPreview()`):
Klick auf einen Kontakt im Kanban (egal wo auf der Karte, nicht nur exakt
auf den Namen) öffnet jetzt zuerst ein kompaktes Vorschau-Popup statt
direkt zur Kontakt-Seite zu springen — Status, aktuelle Kanban-Stufe,
Berufsstatus/Betrieb, nächster Termin (inkl. Kanal, erst beim Öffnen
nachgeladen, kein Batch-Query für alle Karten), Telefon/E-Mail,
Wiedervorlage (nur bei gewonnen/verloren/dauerbrenner sichtbar — während
aktiver Kanban-Bearbeitung redundant zum Termin selbst), zuletzt
kontaktiert. "Zum Profil →"-Link führt zur vollen Seite. **Widerspricht
nicht** der Grundregel "echte Seiten statt Modals für Datensätze" (siehe
Erinnerung `feedback_real_pages_over_modals_for_records`) — die echte
Seite bleibt ein Klick entfernt, und Strg/Cmd/Shift-Klick auf den
Namen-Link selbst öffnet weiterhin einen neuen Tab über den echten
`href`, unangetastet von der Vorschau.

**Termin-Einladungen** (`termin_invitations`, Migration
`20260818210000_termin_einladungen.sql`): aus der Kanban-Vorschau heraus
lässt sich ein Gildenmitglied zu einem bestehenden Termin einladen —
ausdrückliches Nutzer-Vorbild war Outlooks Einladungs-/Update-Mechanik.
Bewusst zweistufig, nicht wie Outlook sofort "vorläufig" im Kalender:

1. **Einladen** (`invite_to_termin()` RPC) — Einladung erscheint beim
   Eingeladenen zunächst nur als offene Anfrage auf einer neuen Karte
   "📨 Termin-Einladungen" (Abenteuerlog-Seite, ganz oben, nur sichtbar
   wenn wirklich etwas offen ist). **Noch kein Kalendereintrag.**
2. **Annehmen** (`respond_to_termin_invitation()` RPC) — erst jetzt
   entsteht eine eigene `termine`-Zeile beim Eingeladenen (`owner_id` =
   er selbst, `organizer_id` = ursprünglicher Organisator). In der
   Wochenansicht deutlich als "👥 prim. Termin von X" markiert
   (`.week-event-delegated`, gestrichelter Rahmen) und **schreibgeschützt**
   (`openTermineEntryModal()` deaktiviert Titel/Zeit-Felder und den
   Speichern-Button bei gesetztem `organizer_id`) — die Zeit wird
   ausschließlich vom Original gepflegt, sonst würde die Kopie
   abdriften. Der "Löschen"-Button wird für diesen Fall zu "Aus meinem
   Kalender entfernen" umbenannt und läuft über denselben Antwort-RPC
   (Ablehnen), nicht über ein direktes Löschen.
3. **Verschieben mit Update-Weitergabe** — verschiebt der Organisator
   danach den Termin über die normale Wochenansicht, fragt die App (bei
   vorhandenen angenommenen Einladungen) "Update an Eingeladene senden?"
   (natives `confirm()`, wie an mehreren Stellen im Projekt üblich). Bei
   Ja (`notify_termin_update()` RPC): alle angenommenen Kopien werden auf
   den neuen Stand gezogen, UND ihr Einladungs-Status springt zurück auf
   "offen" — der Eingeladene sieht die Karte erneut und muss die neue
   Zeit bestätigen oder ablehnen, exakt wie Outlooks "Update senden?".
4. **Löscht** der Organisator den Original-Termin komplett, räumt ein
   `BEFORE DELETE`-Trigger (`cleanup_termin_invitee_copies()`) eine
   bestehende angenommene Kopie automatisch mit ab — sonst bliebe sie als
   verwaiste, nie mehr aktualisierbare Karteileiche im fremden Kalender
   stehen. Bewusst **still**, keine eigene "abgesagt"-Benachrichtigung
   (siehe "Bewusste Vereinfachungen" unten).

**Schreibrechte:** alles, was die Kalenderdaten einer ANDEREN Person
berührt, läuft ausschließlich über die drei `SECURITY DEFINER`-Funktionen
oben — `termin_invitations` hat bewusst KEINE insert/update/delete-Policy
für normale Clients (gleiches Härtungsmuster wie die "Serverseitige
Schreib-Härtung" vom 2026-08-15 für `action_log`/`user_inventory`), damit
Einladung/Annahme/Update-Weitergabe nie in einem inkonsistenten
Halbzustand enden können. Einladen ist nur innerhalb der eigenen
Gilde/Freundschaft möglich (`socially_visible()`, seit Phase 1 der
Gilden-Sichtbarkeit etabliert und geprüft — kein neuer Sichtbarkeits-
Mechanismus).

**Bewusste Vereinfachungen dieser ersten Fassung** (mit Nutzer
abgestimmt, nicht vergessen falls das Thema weitergeht):
- Serientermine + Einladung sind nicht kombiniert (nur einzelne Termine).
- Die Kopie beim Eingeladenen trägt keinen `contact_id`/`location_id`-Bezug
  (nur Titel/Zeit/Kanal) — vermeidet, zusätzlich in die
  Kontakt-Sichtbarkeitsrechte reingehen zu müssen (der Eingeladene hat ja
  nicht zwingend irgendeine Berechtigung auf den Kontakt des Organisators).
- Löschen des Original-Termins räumt die Kopie still ab, ohne eigene
  "abgesagt"-Benachrichtigung (kein separater "cancelled"-Status).
- Kein Push-/Badge-Hinweis außerhalb der Kalender-Seite — die Karte ist
  nur sichtbar, wenn man die Seite tatsächlich öffnet.

**Fundament für die spätere Gildenquest** (siehe
`project_questbaum_schema_design`/Erinnerung `project-roadmap-prioritaeten`,
Punkt "Gildenleben" — vierter Quest-Typ, Team-Aggregation über eine Gilde
in einem Zeitraum, Beispiel dort war explizit "gemeinsame Termine/Monat"):
liefert erstmals ein echtes "geteilter Termin"-Signal, das ein künftiger
Quest-Typ auswerten könnte (z.B. `termin_invitations.status='angenommen'`
zählen). Noch keine Auswertungs-Logik dafür gebaut — das bleibt weiterhin
der offene, nächste Schritt.

Backend end-to-end mit Wegwerf-Testaccounts verifiziert (Einladung,
Annahme, Update-Weitergabe inkl. Status-Reset, Ablehnung inkl.
Kopien-Löschung, Sicherheitsgrenze bei Fremden ohne gemeinsame Gilde,
Lösch-Kaskade bei Original-Löschung — alle Prüfungen bestanden), Frontend
zusätzlich per Playwright gegen den echten Account getestet (Vorschau-
Popup, Einladen-Picker, Einladungs-Karte, Annehmen, schreibgeschützte
Wochenansicht-Darstellung, erneute Bestätigungs-Anfrage nach Verschieben).

**Stolperstein beim Bauen, der Vollständigkeit halber festgehalten:** ein
Versuch, die Migration vorab in einer `begin`/`rollback`-Transaktion zu
testen, führte stattdessen (falscher CLI-Aufruf) zu einer echten,
direkten Anwendung auf die Live-Datenbank, bevor das Nutzer-Go dafür
eingeholt war — im Nachhinein per `supabase migration repair` sauber ins
Migrations-Tracking eingetragen (die Migration selbst war inhaltlich
korrekt und harmlos, da reine Schema-Ergänzung ohne Auswirkung auf
bestehende Daten). Lehre: `supabase db query -f <datei>` führt IMMER
direkt aus, unabhängig vom Dateiinhalt — ein `begin`/`rollback` muss
explizit TEIL der SQL-Datei selbst sein, kann nicht durch einen separaten
Wrapper-Aufruf erzwungen werden.

**Nachtrag, noch am selben Abend — Absage-Benachrichtigung + Statusanzeige
für den Organisator (Nutzerkorrektur der ersten Fassung):** die erste
Fassung ließ eine Absage still verschwinden und zeigte dem Organisator
nirgends, ob/wie geantwortet wurde — beides vom Nutzer explizit
nachgefordert.

- **Absage-Benachrichtigung:** löscht der Organisator einen Termin mit
  offener/angenommener Einladung, bekommt der Eingeladene jetzt eine
  echte "❌ Von X abgesagt"-Meldung in der Termin-Einladungen-Karte
  (neuer Status `storniert`) statt stillem Verschwinden, mit einem
  "OK"-Button zum eigenständigen Ausblenden (löscht die eigene Zeile,
  einzige direkte Client-Schreiboperation auf `termin_invitations` —
  rein aufräumend, keine Kreuz-Nutzer-Wirkung, deshalb ausnahmsweise per
  normaler RLS-Policy statt einer eigenen RPC-Funktion erlaubt).
- **Statusanzeige für den Organisator:** an beiden Stellen, an denen er
  seinen Termin sieht (Kanban-Vorschau UND der Kalender-Termin selbst,
  `termineEntryModal`) — "👤 Eingeladen: X — Ausstehend/Angenommen/
  Abgelehnt", über einen gemeinsamen Helfer `invitationStatusLinesHtml()`.
- **Technischer Kernpunkt:** `termin_invitations` bekam eigene Titel/
  Zeit/Kanal/Organisator-Schattenfelder (gepflegt bei
  `invite_to_termin()`/`notify_termin_update()`), weil `termin_id` nach
  einer Absage `NULL` wird (FK von `ON DELETE CASCADE` auf `ON DELETE SET
  NULL` umgestellt) — ohne die Schattenfelder gäbe es nach dem Löschen
  des Original-Termins nichts mehr anzuzeigen. Zwei kleine
  Folgemigrationen am selben Abend (erst Titel/Zeit/Kanal, dann separat
  noch `organizer_id` nachgetragen, weil sonst nicht mehr feststellbar
  gewesen wäre, WER abgesagt hat).

Beide Migrationen zuerst per `begin`/`rollback`-Wrapper **innerhalb** der
SQL-Datei (Lehre aus dem Stolperstein oben) syntaktisch geprüft, dann
reguär per `supabase db push` angewendet. End-to-end mit
Wegwerf-Testaccounts verifiziert (Annehmen → Absage → Eingeladener sieht
Absage mit korrektem Titel/Zeit trotz gelöschtem Original → Ausblenden;
Organisator sieht Status nach Einladen und nach Ablehnung), Frontend
zusätzlich per Playwright gegen den echten Account getestet.

## Gilden-Einladung mit Annahme/Ablehnung + zwei UI-Politur-Fixes (2026-08-18)

Nutzer-Bugreport, noch am selben Tag: der Gildengründer konnte über den
Mitglied-Picker (`searchGuildCandidates()`) bisher jedes Org-Mitglied
**direkt und ohne dessen Zustimmung** in `guild_members` eintragen
(Policy `guild_members_insert_allowed`, Founder-Branch). Gleiches Muster
wie die Termin-Einladungen desselben Tages jetzt auch hier: eine echte
Mitgliedschaft entsteht erst nach aktiver Annahme.

**Bewusst eine GETRENNTE Tabelle** (`guild_invitations`, Migration
`supabase/migrations/20260818230000_gilden_einladungen.sql`) statt eines
Status-Felds direkt an `guild_members` — Letzteres wird an sehr vielen
Stellen im Schema (Kontakt-/Dungeon-Sichtbarkeit, Chronik-Sichtbarkeit,
Notfallzugriff, Nachfolgeregelung) als "ist wirklich Mitglied, hat
Zugriff" gelesen. Eine separate Einladungs-Tabelle lässt all das
unangetastet — eine Zeile in `guild_members` entsteht weiterhin
ausschließlich bei echter Zusage, keine bestehende Stelle musste geprüft
werden. Drei neue `SECURITY DEFINER`-Funktionen, kein direktes
Insert/Update/Delete auf `guild_invitations` für Clients (gleiches
Härtungsmuster wie `termin_invitations`/`action_log`/`user_inventory`):
- `invite_to_guild(guild_id, invited_user_id)` — nur der Gildengründer,
  nur an ein Org-Mitglied ohne bestehende Gilde (ein Nutzer kann
  höchstens einer Gilde angehören, `guild_members.member_id` ist
  Primärschlüssel). Erneutes Einladen nach einer Ablehnung setzt den
  bestehenden Datensatz einfach wieder auf "offen".
- `respond_to_guild_invitation(invitation_id, accept)` — nur der
  Eingeladene selbst. Erst bei Annahme entsteht die echte
  `guild_members`-Zeile, mit denselben Minimalrechten wie bisher beim
  Selbstbeitritt (`read`/`read`/`false`) — der Gründer passt sie danach
  wie gewohnt über den bestehenden "Rechte"-Button an, kein
  Zwangs-Dialog beim Annehmen.
- `cancel_guild_invitation(invitation_id)` — Zurückziehen einer noch
  offenen Einladung durch den Einladenden (z.B. nach einem Fehlklick).

Der bestehende **Selbst-Beitritt** über die "Gilde beitreten"-Liste
(`joinGuild()`, Selbstbeitritts-Zweig derselben Policy) bleibt
unverändert — dort ist die beitretende Person selbst die Handelnde, kein
Fremdeinfügen. Betroffen war ausschließlich der Founder-Branch.

**Frontend:** neue Karte "📨 Gilden-Einladung" oben auf der Gilde-Seite
(`loadGuildInvitationsCard()`, gleiches Muster wie die Termin-
Einladungen-Karte auf dem Kalender — nur sichtbar, wenn wirklich etwas
offen ist), wiederverwendet die bestehende `.friend-req-row`/
`freq-accept`/`freq-decline`-Optik statt neuer CSS-Klassen. Der Picker
(`searchGuildCandidates()`) zeigt für bereits offen eingeladene
Kandidaten "Einladung zurückziehen" statt "Einladen". **Nebenbei
mitbehoben:** die Kandidatenfilterung prüfte bisher nur Mitgliedschaft
in der *aktuellen* Gilde, nicht org-weit — obwohl ein Nutzer nie in zwei
Gilden gleichzeitig sein kann (latenter Bug, jetzt korrekt org-weit
gefiltert).

**Zwei kleinere, gleichzeitig gemeldete Design-Bugs mitbehoben:**
- Das Namens-Suchfeld im Gilden-Picker (`#guildPickerSearch`) hatte gar
  keine CSS-Regel — erschien als weißes Browser-Standardfeld statt im
  dunklen App-Theme. Neue `.guild-picker input`-Regel behebt das.
- Der "+ Gildenmitglied einladen"-Button in der Kanban-Kurzvorschau
  (siehe "Kanban-Kurzvorschau" oben) wurde bisher roh per
  `terminRow.after(inviteBtn)` mitten in die Feldliste eingehängt
  (zwischen "Nächster Termin" und "Telefon"/"E-Mail") — Nutzerkritik
  "klobig mitten drin". Jetzt ein eigener `#kanbanPreviewInviteZone`-
  Platzhalter am Ende der Feldliste, mit Trennlinie abgesetzt
  (`.kp-invite-zone`/`.kp-invite-btn`, kleinerer Pill-Button statt
  vollbreitem `cal-nav-btn`).

Migration vorab per `begin`/`rollback`-Wrapper mit 8 Assertions gegen
Wegwerf-Testaccounts verifiziert (Nicht-Gründer darf nicht einladen,
Annehmen erzeugt korrekte Minimalrechte, direktes Fremdeinfügen jetzt
RLS-blockiert, Ablehnen/Zurückziehen/Doppel-Mitgliedschaft-Schutz —
alle 8 bestanden), danach per Nutzer-Go gepusht. Frontend zusätzlich
per Playwright gegen den echten Account verifiziert (Input-Styling,
Feld-Reihenfolge in der Kanban-Vorschau, Einladungskarte bleibt
korrekt verborgen ohne offene Einladung).

## Kanban ist strikt die eigene Vertriebspipe, kein Gilden-Blick (2026-08-19)

Echter, live beobachteter Bug, gefunden beim Durchsprechen der geplanten
Termin-Einladung↔Kanban-Verknüpfung (siehe nächster Abschnitt): `renderKanbanBoard()`
nutzte dieselbe ungefilterte `loadContactsBundle()`-Abfrage wie die
Kontakte-Seite — für die Kontakte-Seite richtig (gemeinsame, gilden-geteilte
Kundendatenbank ist dort ausdrücklich gewollt), fürs Kanban-Board fehlte
aber seit jeher die Eigentümer-Einschränkung. Per direkter SQL-Abfrage
gegen die echte DB bestätigt: ein eigener Kontakt mit gesetzter
`kanban_stage` UND `write`-Gildenfreigabe tauchte dadurch bereits echt auf
dem Kanban-Board eines Gilden-Kollegen mit auf, inklusive Zieh-/
Verschieben-Möglichkeit im UI (serverseitig hätte `contacts_update_visible`
zwar sowieso nur bei `write`-Freigabe erlaubt geschrieben zu werden — bei
`read`-Freigabe wäre der Versuch RLS-blockiert, aber als wortloser
Fehlschlag sichtbar gewesen).

**Nutzerklärung des zugrunde liegenden Modells, "bottom up":** das Kanban
ist immer die **persönliche** Vertriebspipe jedes einzelnen Mitarbeiters —
auch innerhalb einer gemeinsamen Gilde, auch für Admins, keine Ausnahme.
Die **Kontakte-Seite** (Kundendatenbank) bleibt dagegen bewusst
gilden-geteilt wie bisher — Zweck dieser Trennung: beim Akquirieren
abgleichen können, ob ein Interessent schon bei einem Kollegen im System
steht (Dubletten-Vermeidung), ohne dass die eigene Pipeline-Ansicht mit
fremden Karten zugemüllt wird. Jeder Kontakt bleibt dabei erkennbar seinem
Eigentümer zugeordnet (unverändert, war schon vorher so).

**Fix**, rein im Frontend (`index.html`, `renderKanbanBoard()`): die
Gruppierung in die 8 Kanban-Spalten filtert jetzt zusätzlich auf
`c.owner_id === profile.id`, ohne Ausnahme für Admins. Keine Datenbank-/
RLS-Änderung nötig — die zugrunde liegende Sichtbarkeit der Kontaktdaten
selbst soll ja weiterhin geteilt bleiben, nur die Kanban-**Ansicht** grenzt
jetzt zusätzlich ein. Per Playwright gegen den echten Admin-Account
verifiziert: Board zeigt weiterhin exakt die eigene Karte, keine
Konsolenfehler (kein Testaccount für die Gegenprobe "Kollege sieht die
fremde Karte jetzt nicht mehr" verfügbar — dafür reicht aber schon die
direkte SQL-Bestätigung des vorherigen Lecks plus die triviale
Filterbedingung).

**Direkter Folgeauftrag, noch nicht gebaut:** die ursprünglich angedachte
Termin-Einladung↔Kanban-Spiegelung (Eingeladener sieht/bearbeitet eine
schreibgeschützte Kanban-Karte für den verknüpften Kontakt, kann von dort
absagen, Organisator bekommt dieselbe Benachrichtigung wie bei einer
Kalender-Absage — Punkte/Vertriebsstatistik bleiben ausschließlich beim
Organisator, der Eingeladene ist zum Mitlernen/gemeinsamen Gildenziel
dabei) muss durch diese Klarstellung neu gedacht werden: da das Kanban
jetzt (richtigerweise) strikt persönlich ist, kann sich eine Einladung
NICHT mehr einfach "for free" über die bestehende Gilden-Kontaktfreigabe
zeigen — es bräuchte eine echte, gezielte Ausnahme (genau eine Karte,
schreibgeschützt, erkennbar als "über Einladung geteilt") statt der
vorher (fälschlich) angenommenen automatischen Sichtbarkeit.

**Fertig gebaut, noch am selben Tag (2026-08-19):** genau diese gezielte
Ausnahme. `contact_id` wird jetzt bei Termin-Einladungen als weiteres
Schattenfeld auf `termin_invitations` mitgeführt (gleiche Technik wie
`title`/`start_at`/`kanal`/`organizer_id`, Migration
`20260819150000_termin_einladung_kanban_spiegel.sql`) und bei Annahme auf
die Kalenderkopie des Eingeladenen übertragen. Hat der eingeladene Termin
einen Kontaktbezug, zeigt `renderKanbanBoard()` zusätzlich zu den eigenen
Karten einen zweiten, schreibgeschützten Kartensatz (`.kanban-card-shared`,
gestrichelter Rand, kein Zieh-Griff, kein Verschieben-Knopf) für jeden
Kontakt aus einer angenommenen Einladung — live in der Spalte, in der der
Kontakt beim Organisator tatsächlich gerade steht (derselbe
`kanban_stage`-Wert, keine eigene Kopie des Status). Statt des
Verschieben-Knopfs ein `.kc-decline-btn` ("Termin absagen"), der dieselbe
`respond_to_termin_invitation()`-Funktion aufruft wie im Kalender —
Kalendereintrag UND Kanban-Spiegelkarte verschwinden dabei im selben Zug.
Hat der Eingeladene keinen Lesezugriff auf den Kontakt (z.B. Einladung nur
über eine Freundschaft ohne gemeinsame Gilde), liefert der Datenbank-Join
schlicht nichts zurück — kein Sonderfall im Code, RLS regelt das von
allein (per Testlauf mit einer reinen Freundschaft ohne Gildenfreigabe
bestätigt: kein Zugriff, keine Karte). XP/Vertriebsstatistik bleiben
unverändert ausschließlich beim Organisator, die Spiegelkarte selbst löst
nie eine Aktion aus.

**Dabei ein echter, vorbestehender Bug gefunden und behoben** (Migration
`20260819160000_termin_einladung_absage_nach_annahme_fix.sql`):
`respond_to_termin_invitation()` erlaubte eine Antwort nur noch, solange
`status='offen'` war — das blockierte nicht nur den neuen
"Termin absagen"-Knopf, sondern denselben, schon länger bestehenden
"Aus meinem Kalender entfernen"-Weg im Kalender selbst (beide rufen die
Funktion mit `p_accept=false` auf einer bereits `status='angenommen'`-
Einladung auf) — vermutlich nie mit einer wirklich schon angenommenen
Einladung durchgetestet. Fix: Annehmen bleibt nur aus `'offen'` möglich,
Ablehnen jetzt sowohl aus `'offen'` als auch nachträglich aus
`'angenommen'`.

Beide Migrationen vorab per `begin`/`rollback`-Wrapper mit echten
Nicht-Admin-Testprofilen verifiziert, danach per Nutzer-Go gepusht.
Zusätzlich ein echter Ende-zu-Ende-Test mit Playwright gegen den echten
Account (testweise reale Einladung zwischen zwei echten Profilen
aufgebaut, danach vollständig wieder entfernt): Spiegelkarte erscheint
korrekt mit Organisator-Namen, nicht ziehbar, "Termin absagen" entfernt
Kalendereintrag UND Karte im selben Zug, keine Konsolenfehler, 0
Testdaten-Reste danach bestätigt.

## Gildenleben: Team-Ziele + Gilden-Gebäude, Fundament (2026-08-19)

Löst den seit dem 2026-08-17 als nächsten Einstieg bestätigten
"Gildenleben"-Quest-Typ (siehe `project-roadmap-prioritaeten`) — nach
ausführlicher Konzept-Diskussion mit dem Nutzer (siehe
[[project_gildenleben_konzept]] in Claudes Erinnerung für die Langfassung),
bewusst nur der **erste** von mehreren Bauschritten: die Datenbank-Seite.
Regelwerk-Beispieldaten, die Frontend-Auswertungslogik und der Gilde-
Seiten-Umbau (Gebäude-Grafik oben, Reiter Mitglieder/Freunde, Team-Ziele-
Bereich darunter — siehe eigener Diskussions-Abschnitt in der Erinnerung)
folgen als eigene, noch nicht begonnene nächste Schritte.

**Kernidee, mit dem Nutzer abgestimmt:** die Gilde bekommt eigene,
verkaufsbasierte **Jahres-Team-Ziele** (mehrere gleichzeitig, je Sparte —
"nicht das eine tun ohne das andere zu lassen", z.B. Kranken UND Leben UND
Sach parallel). Erfüllung schaltet **kein XP, keinen Titel** frei, sondern
ein Bauteil eines gemeinsamen, gilden-eigenen "Gebäudes" (Schloss/Tempel/
o.ä. — Optik kommt als eigener, viel späterer Schritt, vergleichbar mit
dem Charakter-Sprite-System, aktuell komplett ungebaut). **Wichtige
Klarstellung des Nutzers, die die Architektur bestimmt:** der jährliche
Reset betrifft nur, welche Verkäufe für die *nächste offene* Stufe zählen
— der Bau-Fortschritt selbst wird **nie** zurückgesetzt, akkumuliert über
die ganzen 10 Jahre hinweg, exakt wie das individuelle Charakter-Level nie
zurückgesetzt wird. Zielwerte leben vorerst von Hand im Regelwerk
(gleiches Muster wie der restliche Questbaum) — eine echte
Self-Service-Oberfläche für Gildenführer kommt laut Nutzer bewusst erst
mit der großen, noch nicht angegangenen Automatisierung ("erst das
Programm so groß wie möglich schreiben, bevor wir abstrahieren").

**Migration `20260819180000_gildenleben_teamziele_fundament.sql`, live:**
- **`guild_quest_log`** — reines Anhänge-Protokoll, gleiches Prinzip wie
  `action_log`: nichts wird als Zahl gespeichert, jede erfüllte
  Team-Ziel-Stufe trägt sich als eine Zeile ein (`guild_id`, `quest_id`,
  `stage_id`, `period_key` für das Jahr). Der Bau-Fortschritt eines
  Gebäudes ist beim Anzeigen immer nur "wie viele Zeilen stehen für diese
  Gilde im Protokoll" — nie eine gespeicherte Zahl. Unique-Key umfasst
  bewusst `period_key` mit: dieselbe Stufe ist über mehrere Jahre hinweg
  mehrfach erreichbar (Jahresziel-Prinzip wie beim individuellen
  Questbaum seit Patch 50), nur nicht zweimal im selben Jahr. Sichtbar für
  alle Mitglieder der jeweiligen Gilde + Admins, kein direktes
  Insert/Update/Delete für Clients.
- **`guild_sales_metric_total(guild_id, field, category, year)`** —
  `SECURITY DEFINER`-Aggregat-Funktion (gleiches Schutzprinzip wie
  `friend_skill_totals()`), liefert nur eine Summe zurück, nie
  Einzelverkäufe. Nötig, weil normale `sales`-RLS nicht automatisch alle
  Verkäufe aller Gildenmitglieder zeigt (nur über zufällig geteilte
  Kontakte) — ein Team-Ziel braucht aber die echte Summe über alle
  Mitglieder. `field` ist auf eine feste Erlaubnisliste
  (`bewertungssumme`/`laufender_beitrag`) geprüft, kein freier Spaltenname
  vom Client. `category` filtert optional auf eine Produktkategorie
  (NULL = alle zusammen). Zeitraum wie auf der persönlichen
  Statistik-Seite: `vertragsbeginn`, Fallback `datum`.
- **`grant_guild_quest_completion(guild_id, quest_id, stage_id, period_key)`**
  — trägt eine erfüllte Stufe ins Protokoll ein, Duplikat-geschützt über
  den Unique-Key (`on conflict do nothing`, Rückgabewert zeigt an, ob
  wirklich neu vergeben wurde). Aufrufbar von jedem Mitglied der
  betroffenen Gilde — die eigentliche Schwellenwert-Prüfung passiert
  weiterhin im Frontend (gleiches Muster wie bei den bestehenden
  persönlichen Quest-Prüfungen), diese Funktion verhindert nur doppeltes
  Eintragen.

Vorab per `begin`/`rollback`-Wrapper mit echten Profilen gegen die echte
DB getestet (Summenbildung über einen echten Testverkauf bestätigt,
Duplikat-Schutz bestätigt, ein gildenfremdes Profil sowohl von der
Summenabfrage als auch von der Vergabe zuverlässig ausgeschlossen), danach
per Nutzer-Go gepusht.

**Schritte 2-4, noch am selben Abend, alle vier Schritte des Konzepts
damit fertig:**

- **Schritt 2** (Migration `20260819200000_gildenleben_teamziele_beispiele.sql`):
  zwei neue Top-Level-Schlüssel additiv ins bestehende `rule_configs.config`
  gemerged (bestehender Inhalt unangetastet). `guildTeamQuests` — die
  Team-Ziele selbst, bewusst flach (kein `stages`-Array wie beim
  individuellen Ladder-Typ, `stage_id` = `quest_id`, gleiche Konvention
  wie bei Epics). Zwei Beispiel-Ziele, **explizit als Testwerte markiert,
  kein echtes Geschäftsziel** — es gab beim Schreiben noch keine einzige
  eingetragene individuelle Planung (`profiles.planung_*` komplett leer,
  vorher geprüft), daher keine "×10"-Ableitung aus echten Werten möglich,
  nur runde Platzhalter. `guildBuilding` — das Bau-Rezept (4 Stufen von
  "Kleine Hütte" bis "Festung", reine Text-/Emoji-Platzhalter, keine
  echte Grafik).
- **Schritt 3**: zwei neue Frontend-Funktionen neben den bestehenden
  Quest-Check-Funktionen (`checkAndAwardEpics()` & Co.).
  `loadAndEvaluateGuildTeamQuests(guildId)` prüft UND vergibt in einem
  Rutsch (ruft `guild_sales_metric_total()`, bei Erfüllung
  `grant_guild_quest_completion()`), gibt anzeigefertige Daten zurück.
  `loadGuildBuildingProgress(guildId)` leitet den Bau-Stand rein aus der
  Zeilenzahl von `guild_quest_log` für diese Gilde ab (nie eine
  gespeicherte Zahl, gleiches Prinzip wie XP/Level).
- **Schritt 4**: Gilde-Seite (Orden/Legion/Bund) umgebaut wie mit dem
  Nutzer abgestimmt — Gebäude-Karte oben (Platzhalter-Optik: Icon +
  Titel + "X Teile bis zur nächsten Stufe"), darunter Reiter
  Mitglieder/Freunde (`.view-switch`-Muster), darunter Team-Ziele mit
  Fortschrittsbalken. **Wichtige Randbedingung, vom Nutzer bestätigt:**
  "die Seite kann so bleiben wie heute" für alle, die noch in keiner
  Gilde sind (5 von 7 echten Profilen aktuell) — Freunde bleibt für sie
  eine eigene, immer sichtbare Karte, exakt wie bisher. Technisch gelöst,
  ohne die Freunde-Logik zu duplizieren: die Freunde-Karte
  (`#friendCard`) ist ein einziges DOM-Element, das `loadGuildState()`
  per `appendChild()` zwischen zwei Ankerpunkten hin- und herschiebt —
  `#friendCardHome` (Standardposition, kein-Gilde-Fall) und
  `#guildTabFreunde` (Reiter-Inhalt, in-Gilde-Fall). `appendChild()`
  verschiebt ein bereits vorhandenes Element inklusive aller
  Event-Listener, keine Neuerzeugung nötig. Verlässt man die Gilde,
  landet die Karte automatisch wieder an ihrem Stammplatz.
  **Reihenfolge-Bug beim ersten Testlauf gefunden und behoben:** die
  Gebäude-Anzeige wurde vor der Team-Ziele-Auswertung gerendert — bei
  genau der Erfüllungs-Runde eines Ziels zeigte das Gebäude deshalb noch
  den alten Stand (der neue Protokoll-Eintrag existierte zu dem
  Zeitpunkt noch nicht). Reihenfolge in `loadGuildState()` korrigiert:
  erst `renderGuildTeamQuests()` (prüft/vergibt), dann erst
  `renderGuildBuilding()` (liest den ggf. gerade neuen Stand).

End-to-end per Playwright gegen den echten Account verifiziert: Gebäude-/
Reiter-/Team-Ziele-Anzeige korrekt, Reiter-Umschaltung funktioniert,
Freunde-Karte landet korrekt im Reiter. Danach ein echter, großer
Test-Verkauf eingefügt (Lebensversicherung, 600.000 € BWS) — Team-Ziel
schaltete korrekt auf ✅, Gebäude sprang korrekt auf "Kleine Hütte",
wiederholtes Neuladen erzeugte keinen zweiten Protokoll-Eintrag
(Duplikat-Schutz bestätigt). Test-Verkauf, -Kontakt, -Produkt und der
dadurch entstandene Protokoll-Eintrag danach vollständig entfernt, Seite
zeigt wieder exakt den Ausgangszustand.

**Damit ist die komplette, ausführlich mit dem Nutzer besprochene
Konzeptreihe zum Gildenleben-Team-Ziele-Fundament (alle 4 Schritte)
fertig.** Details/Diskussionsverlauf in Claudes Erinnerung
(`project_gildenleben_konzept`). Bewusst noch nicht angegangen: die
echte Gebäude-Grafik (Platzhalter bleibt bis auf Weiteres), eine
Self-Service-Oberfläche für Gildenführer (kommt laut Nutzer erst mit der
großen Automatisierung).

**Aktionsleiste-Politur, erledigt 2026-08-20:** die "+ hinzufügen"/
"Gilde verlassen"-Aktionsleiste saß vorher OBERHALB des Mitglieder/
Freunde-Reiters, wirkte für beide Reiter gleichermaßen gültig —
verwirrend, weil "hinzufügen" im Mitglieder-Kontext (nur Gildenführer)
etwas anderes meint als "hinzufügen" im Freunde-Kontext (das dort schon
existierende Freunde-Suchfeld, für jeden sichtbar). "+ hinzufügen" sitzt
jetzt **innerhalb** des Mitglieder-Reiters (unter dem Reiter-Umschalter,
weiterhin nur für den Gründer sichtbar), "Gilde verlassen" wanderte
stattdessen an den Gebäude-Header (gildenweite Aktion, für alle
Mitglieder). Reine HTML-Verschiebung, keine neue Logik — per Playwright
gegen den echten Account (Gründer-Rolle) verifiziert, Desktop + Mobile,
keine Konsolenfehler.

## Aufgaben-System: echte, abhakbare Aufgaben (Outlook-Stil), Patch 51 (2026-08-20)

Löst den seit 2026-08-09 unter "Bewusst aufgeschobene Ideen" notierten
Wunsch "Outlook-artige abhakbare Aufgaben" — nach ausführlicher
Konzept-Diskussion (Nutzer beschrieb genau das Outlook-Verhalten:
Aufgaben mit Termin, Abhaken lässt sie verschwinden). **Wichtig, nicht
verwechseln:** die bereits bestehenden Kalender-Hinweise
(`tasksForDate()`, Geburtstags-/Wiedervorlage-**Punkte/Chips** in Monats-
und Wochenansicht, siehe Abschnitt "Kalender-Aufgaben" oben) bleiben
unverändert bestehen — reine, nicht-interaktive Vorschau, komplett
abgeleitet wie bisher. Das neue System ist eine **zusätzliche**, echte
Tabelle mit tatsächlicher Interaktion, nur im neuen Tag-Reiter sichtbar.

**Kernentscheidung, mit dem Nutzer abgestimmt: kein "erledigt"-Zustand.**
Eine Aufgabe existiert nur, solange sie offen ist — Abhaken **löscht die
Zeile direkt** (`tasks`-Tabelle, kein `done_at`-Feld). Nutzer-Begründung:
eine Historie erledigter Aufgaben hat keinen praktischen Wert ("als ob
sich das einer anguckt") — wurde ein Anruf/Termin wirklich wahrgenommen,
steht das ohnehin schon in der Kontakt-Chronik/den Terminen.

**Datenmodell (Migration `20260820120000_aufgaben_system.sql`):** neue
Tabelle `tasks` — `title`, `due_date` (nullable, **kein Pflichtfeld**,
bewusst wie in Outlook — eine Aufgabe ohne Datum ist gültig, steht im
Tag-Reiter in einem eigenen "Ohne Termin"-Block, nie überfällig/rot),
`contact_id` (optional, `on delete set null`), `source_type`
(`'manual'`/`'geburtstag'`/`'wiedervorlage'`). RLS wie bei `termine`
(Patch 33): rein persönlich, Admin darf lesen (nicht so abgeschottet wie
`journal_entries`) — direkt im seit der RLS-Performance-Härtung
aktuellen Muster geschrieben (`(select auth.uid())`, eine SELECT-Policy),
statt es später nachoptimieren zu müssen. Bewusst **keine**
UPDATE-Policy — Aufgaben werden in Version 1 nicht nachträglich
bearbeitet, nur angelegt oder gelöscht (Rule of Three, Bearbeiten kommt
erst bei echtem Bedarf). Ein Unique-Index
(`owner_id, contact_id, source_type, due_date`, nur für die zwei
automatischen Typen) verhindert doppelte Geburtstags-/Wiedervorlage-
Aufgaben, falls sich Sync-Läufe zeitlich überschneiden.

**Wiedervorlage-Aufgaben: synchron bei jedem Speichern von
`contacts.naechster_kontakt`.** Genau das vom Nutzer beschriebene reale
Ablauf-Beispiel: Anruf, Kunde sagt "melden Sie sich nächstes Jahr" →
neues Wiedervorlage-Datum eintragen → die alte Aufgabe soll dabei nicht
als Karteileiche stehen bleiben. `syncWiedervorlageTask(contactId,
contactName, newDate)` in `index.html` löscht die bisherige offene
Wiedervorlage-Aufgabe des Kontakts und legt bei gesetztem Datum sofort
die neue an — läuft an **allen drei** Stellen, an denen
`naechster_kontakt` geschrieben wird (per Audit aller Vorkommen
gefunden, nicht nur der naheliegendsten): Kontaktformular-Speichern
(Neuanlage UND Bearbeiten, ein gemeinsamer Pfad), Kanban-Lead-Anlage am
Dungeon (`createLeadAndLogTerminVereinbart`), Wiedervorlage-Feld im
"Gewonnen"-Verkaufspopup (`recordWonSalesLoop`).

**Geburtstags-Aufgaben: täglicher Sync statt Speichervorgang**, da sie
nicht an einer Nutzeraktion hängen, sondern rein am Kalendertag.
`syncBirthdayTasksIfNeeded()` läuft beim Login UND über einen neuen
**Tageswechsel-Wächter** (`startTaskDayRolloverWatcher()`) — Auslöser
war der Nutzerhinweis, dass B2B-Laptops üblicherweise über Nacht
durchlaufen ("die Damen fahren ihren PC nicht herunter"), ein reiner
Login-Check hätte den Tageswechsel bei durchgehend offenem Tab verpasst.
Der Wächter prüft alle 5 Minuten **und** sofort, sobald das Browser-Tab
wieder sichtbar wird (`visibilitychange`/`focus`) — Best-Practice-Muster
auf ausdrücklichen Nutzerwunsch, statt nur stumpf zu pollen. Ein neues
Profilfeld `profiles.tasks_synced_date` merkt sich, für welchen Tag
zuletzt synchronisiert wurde — verhindert, dass eine am selben Tag
bereits abgehakte (= gelöschte) Geburtstags-Aufgabe durch einen zweiten
Sync-Lauf desselben Tages wiederaufersteht. Normales, unbewachtes
Profilfeld, kein Trigger-Schutz nötig (anders als
role/character_class/total_xp/level). Nur eigene Kontakte
(`owner_id` = eigene ID) — bewusst **keine** gilden-geteilten Kontakte,
ausdrückliche Nutzerklärung: "man würde ja nicht die Kunden seiner
Gildenmitglieder anrufen."

**Neuer dritter Kalender-Reiter "Tag"** (`calViewMode` jetzt
`'monat'|'woche'|'tag'`, `#calViewDayBtn` neben Monat/Woche) — Outlook-
Tagesansicht: links derselbe Zeitraster-Kalender wie die Wochenansicht
(wiederverwendet `renderDayEvents()`/`attachDragHandlers()`/
`computeOverlapLayout()`/Arbeitszeiten-Abdunklung 1:1, nur auf einen
Tag beschränkt), rechts die Aufgaben-Spalte (Eingabezeile Titel+Datum
oben, Liste mit Checkbox darunter). Zurück/Heute/Vor (`calPrevBtn`/
`calTodayBtn`/`calNextBtn`) funktionieren im Tag-Reiter jetzt tagesweise,
exakt nach demselben Muster wie zuvor schon wochenweise in der
Wochenansicht — genau der vom Nutzer selbst genannte Bauplan ("der
Heute-Knopf springt im jeweiligen Ansichtsmodus"). Doppelklick auf einen
Tag in Monats- **oder** Wochenansicht (`openDayView()`) springt
zusätzlich direkt in den Tag-Reiter mit genau diesem Tag.

**Aufgaben-Anzeige, mit dem Nutzer abgestimmt:** am **heutigen** Tag
zeigt die Spalte alle offenen Aufgaben inkl. Überfälligem (Rückstand
rollt automatisch mit, deutlich rot markiert, `var(--danger)`) — an
**jedem anderen** Tag (Doppelklick auf einen Tag in der Vergangenheit
oder Zukunft) nur die Aufgaben, die exakt für diesen Tag fällig sind,
ohne den allgemeinen Überfällig-Rückstand (der wäre dort nur
verwirrend). Aufgaben ohne Datum stehen immer in einem eigenen Block
"Ohne Termin" am Ende, unabhängig vom angezeigten Tag, nie rot.

**Layout:** `.day-view-grid` (Kalender 65% / Aufgaben 35%, unter 760px
gestapelt — gleiche Schwelle wie beim Kanban-Umbau). **Stolperstein beim
Bauen, behoben:** die wiederverwendeten Wochenraster-Klassen
(`.week-body{min-width:550px}`) sprengten als Grid-Item auf dem Handy
die 65%-Spalte, weil Grid-Items ohne explizites `min-width:0` per
Default ihre eigene Inhaltsbreite vor der Spaltenbreite respektieren —
per Playwright-Overflow-Check gefunden (`body.scrollWidth` > `390`) und
mit `.day-view-cal-col{min-width:0}` behoben, danach verifiziert sauber.

End-to-end per Playwright gegen den echten Account verifiziert: Aufgabe
anlegen ohne/mit Datum, Abhaken löscht sofort, überfällige Aufgabe rot,
Doppelklick springt korrekt in den Tag-Reiter, kein horizontales
Overflow auf 390px nach dem Fix, keine Konsolenfehler — sowie der
komplette Wiedervorlage-Ablauf über einen echten Testkontakt (Anlegen
mit Datum → Aufgabe erscheint → Datum ändern → alte Aufgabe verschwindet,
neue erscheint am neuen Tag → Testkontakt/-aufgabe wieder entfernt).

**Nachtrag, noch am selben Tag:** Nutzer-Bugreport ("Systemuhr auf
2027-06-10 vorgestellt, Kundengeburtstag taucht nirgends auf, auch nicht
im Kalender") — Ursache war die eigene Einstellung
`calendar_show_birthdays` (aus), per direkter SQL-Prüfung bestätigt
(Kontaktdaten selbst waren korrekt). Dabei eine echte, zusätzliche
Lücke gefunden und behoben: das Umschalten von "Geburtstage anzeigen" in
Einstellungen wirkte bisher nur auf die alten, rein clientseitig
berechneten Kalender-Punkte, **nicht** auf die neuen echten
Aufgaben-Zeilen — die hätten erst beim nächsten Tageswechsel oder einem
Neuladen der Seite nachgezogen (`syncBirthdayTasksIfNeeded()` läuft
sonst nur einmal pro Kalendertag, siehe `tasks_synced_date` oben).
`settingsToggleChanged()` setzt bei diesem einen Feld jetzt
`profile.tasks_synced_date` lokal zurück und erzwingt so einen
sofortigen Re-Sync. Per Playwright mit gefälschter Browser-Systemuhr
(`context.addInitScript()`, `Date` auf 2027-06-10 überschrieben — exakt
der gemeldete Sprung) gegen den echten Account verifiziert: Aufgabe UND
Kalender-Punkt erscheinen korrekt am gefälschten Datum, Umschalten des
Häkchens entfernt/erzeugt die Aufgaben-Zeile sofort ohne Neuladen.

**Zweiter Nachtrag, noch am selben Tag — zwei echte, vom Nutzer beim
manuellen Vorausblättern gefundene Bugs, beide behoben:**

1. **Monat/Woche/Tag hatten je ihr eigenes, unabhängiges Datum.**
   Doppelklick auf einen Tag in der Zukunft zeigte in der Tagesansicht
   korrekt diesen Tag, sprang aber beim Wechsel zu Woche/Monat zurück
   auf die aktuelle Woche/den aktuellen Monat — "inkonsistent", zu Recht
   gemeldet. Neue gemeinsame `calFocusDate`-Variable (in `index.html`)
   wird bei **jeder** Navigation (Vor/Zurück/Heute/Doppelklick, in allen
   drei Ansichten) aktualisiert; `setCalViewMode()` liest sie beim
   Reiter-Wechsel aus und leitet daraus `calViewYear/calViewMonth`
   bzw. `calWeekStart` bzw. `calDayDate` ab, statt dass jede Ansicht ihr
   Datum isoliert verwaltet. Betraf strukturell auch Monat↔Woche schon
   vor dem Tag-Reiter, fiel dort nur nie auf.
2. **Ein an einem NICHT-heutigen Tag liegender Geburtstag fehlte in der
   Aufgaben-Liste komplett**, obwohl der alte Kalender-Punkt ihn längst
   zeigte — Ursache: die alten Punkte rechnen live für jedes Datum, die
   neuen Aufgaben-Zeilen entstehen aber nur für den echten heutigen Tag
   (täglicher Sync). Neue, bewusst **nicht abhakbare** Vorschau-Zeile
   ("Geburtstag an diesem Tag (noch keine Aufgabe)", 🎂, dezenter
   Stil) in `renderTaskColumn()` schließt diese Lücke beim
   Vorausblättern — wird erst zur echten, abhakbaren Aufgabe, sobald der
   Tag tatsächlich "heute" ist.

**Reiner Diagnose-Fund, kein Bug:** beim Nachstellen fiel auf, dass
`calendar_show_birthdays` im echten Account zwischenzeitlich wieder auf
"aus" stand (per direkter SQL-Abfrage bestätigt) — betrifft beide
Systeme identisch und korrekt, kein Widerspruch. Für den Test über die
echte Einstellungen-UI wieder eingeschaltet, dabei belassen.

Per Playwright gegen den echten Account verifiziert (Vorblättern 10
Monate, Doppelklick auf 10.06.2027, Wechsel Tag→Woche→Monat→Heute):
Tagesansicht zeigt korrektes Datum, Wochenansicht zeigt die Woche um den
10.06.2027 (nicht die aktuelle), Monatsansicht zeigt Juni 2027, "Heute"
springt zuverlässig zurück — Geburtstags-Vorschau erscheint korrekt,
keine Checkbox/Aufgaben-ID an der Vorschau-Zeile, keine Konsolenfehler.

## Bekannte, bewusst in Kauf genommene Lücken

- ~~"Zuletzt kontaktiert"/Kontakt-Chronik zeigen nur eigene Einträge~~ —
  **behoben, Patch 45, 2026-08-10**, siehe eigener Abschnitt "Chronik-
  Sichtbarkeit folgt der Kontakt-Freigabe". "Zuletzt kontaktiert (von
  dir)" bleibt bewusst weiterhin eigentümerbezogen (so gekennzeichnet).
- Level-Kurve basiert auf geschätzten, nicht gemessenen Aktivitätswerten.
- ~~Zwei kleine Unschärfen bei den Termin-Einladungen~~ — **behoben,
  2026-08-19, Migration `20260819120000_termin_einladungen_robustheit.sql`.**
  Vor dem Push mit echten Nicht-Admin-Testprofilen (nicht dem eigenen
  Admin-Account — der erste Testlauf hatte fälschlich den Admin-Bypass
  mitgetestet und dadurch nichts bewiesen) in einer `begin`/`rollback`-
  Transaktion verifiziert: Organisator sieht seine stornierte Einladung
  jetzt über `organizer_id`, direktes Löschen der Einladungs-Kopie durch
  den Eingeladenen ist jetzt RLS-blockiert (nur noch über
  `respond_to_termin_invitation()` möglich), eigene normale Termine bleiben
  normal löschbar (keine Regression). Die vom Nutzer zusätzlich vermutete
  dritte Unschärfe (offene, noch nicht angenommene Einladung "verschwindet"
  beim Empfänger, wenn der Organisator den Termin löscht) war beim
  Nachtesten **kein Bug** — funktionierte bereits korrekt (Status wechselt
  sichtbar auf "storniert").
- Kein automatisiertes Testen — der Nutzer testet manuell selbst
  (Safari/iPhone + Brave/Desktop). **Team ist inzwischen auf 7 echte
  Profile gewachsen** (Stand 2026-08-15, per SQL bestätigt — ursprünglich
  waren hier nur "zwei Kollegen" dokumentiert), CI/CD-Schwelle aus
  "Technische Skalierungs-Schwellen" oben (mehrere Personen bearbeiten
  das Repo gleichzeitig) betrifft weiterhin nur Code-Bearbeitung, nicht
  App-Nutzung — bleibt also unverändert nicht ausgelöst.

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
