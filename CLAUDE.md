# Projekt: Vertriebs-Quest (Gamifiziertes CRM für Vertriebsteams)

Dieses Dokument ist der Gedächtnis-Ersatz für eine lange Chat-Konversation, in der
dieses Projekt von Grund auf entstanden ist. Lies es vollständig, bevor du an
irgendetwas im Repo arbeitest.

## Wegweiser: wo was steht

- **Hier (CLAUDE.md)** — der aktuelle Zustand des Projekts, evergreen,
  wird bei Änderungen ersetzt statt angehängt. Was eine Session JETZT
  braucht, um korrekt weiterzubauen.
- **`HISTORY.md`** (Repo-Root) — das chronologische Verlaufsprotokoll:
  Bau-Geschichten, Debugging-Verläufe, Nutzer-Zitate, Verifikations-
  Details, Commit-Hashes. Wird NICHT automatisch geladen — gezielt
  lesen, wenn eine Session nachvollziehen muss, *wie/wann/warum* etwas
  entstanden ist.
- **`sql/PATCH_LOG.md`** — eingefrorenes Archiv der ursprünglichen,
  manuellen SQL-Patches 1–39 (vor der Supabase-CLI-Migrationstoolchain,
  siehe unten). Nicht mehr aktiv fortgeführt.
- **Claudes Erinnerungssystem** (`memory/`, außerhalb des Git-Repos) —
  sitzungsübergreifender Kontext, der bewusst nicht hier im Repo steht:
  Geschäfts-/Preis-/Marktfahrplan (`project_business_fahrplan`), reine
  Arbeitsweise-Lehren (`feedback_*`), sowie Verweise auf externe Quellen
  (z.B. den Obsidian-Questbaum-Vault).
- **`businessvorbereitung/`** (Repo-Root, seit 2026-08-25) — echte
  Rechts-/Compliance-Arbeitsprodukte (Datenschutzerklärung- und
  VVT-Entwurf), bewusst im Git-Repo (nicht im Erinnerungssystem, das ist
  Geschäftsstrategie/-diskussion, hier geht's um versionierte Dokumente).
  Beide Entwürfe sind explizit als Entwurf markiert — vor echtem
  Kundeneinsatz durch Rechtsberatung gegenprüfen.

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
  über die öffentliche Nominatim-API (kostenlos, kein Key). Beide senden bei
  jeder Nutzung die Besucher-IP an einen externen Dienst (CartoDB/OSM) — in
  der Datenschutzerklärung als externe Dienste aufgeführt (siehe
  `businessvorbereitung/`), technisch bewusst nicht selbst gehostet (anders
  als die Schriftarten unten) — Karten-Kacheln/Geocoding-Datenbank
  selbst vorzuhalten wäre ein deutlich größerer, nicht gerechtfertigter aufwand.
- **Schriftarten**: Cinzel/Inter/JetBrains Mono liegen seit 2026-08-25 lokal
  unter `fonts/*.woff2` (per `@font-face` in `index.html` eingebunden),
  **nicht mehr live von `fonts.googleapis.com`/`fonts.gstatic.com` geladen**
  — vermeidet die Übertragung der Besucher-IP an Google ohne Einwilligung
  (bekanntes rechtliches Risiko, LG München I 2022). Dateien sind
  byte-identisch zu dem, was Google vorher ausgeliefert hat (nur
  `latin`-Subset, deckt deutsche Umlaute/ß ab), keine Verhaltensänderung.
  Bei künftigem Bedarf an weiteren Schriftschnitten: gleiches Verfahren
  (Google-Fonts-CSS mit Browser-UA abrufen, `latin`-Subset-Blöcke
  extrahieren, `.woff2`-Dateien herunterladen, lokal einbinden) statt
  einfach einen neuen `<link>` auf Google zu setzen.
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
- **Radius-/Schatten-System**: einheitliche CSS-Variablen im `:root`-Block
  von `index.html` statt roher Werte — `--radius-xs/sm/md/lg/pill`
  (4/8/12/14/999px, nach Element-Größe: kleine Bedienelemente=sm,
  Karten/Kacheln=md, große Container/Panels=lg) und `--shadow-rest`/
  `--shadow-raised` (dezenter Schatten im Ruhezustand auf Panels/Karten,
  kräftigerer beim Hover auf klickbaren Kacheln). **Neue UI-Elemente sollten
  diese Variablen weiterverwenden statt neue Radius-/Schatten-Werte zu
  erfinden.**
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
- **Regressions-Suite** (`~/.local/share/playwright-portable/
  regression_suite.mjs` + `regression_suite_member.mjs`, Entstehung/
  Ausbau: HISTORY.md): zwei wiederverwendbare Skripte gegen die echte
  App — die Hauptsuite (33 Einzelprüfungen über acht Bereiche: Login/
  Rollen, XP-/Level-Berechnung, Kanban, zentrale Navigation inkl.
  Deep-Links, Kalender/Termine, Kontakt-Chronik, Verkauf/Statistik,
  mobiles/Touch-Verhalten) läuft mit dem Admin-Testkonto, das zweite
  Skript prüft dieselben rollenabhängigen Stellen noch einmal mit einem
  echten Nicht-Admin-Konto. Nutzt `page.route()`-Interception statt
  echter Schreibvorgänge — schreibt nichts an der echten Datenbank.
  Zwei getrennte, gitignorte Zugangsdaten-Dateien unter
  `~/.local/share/fantasyarbeit-claude-test/` (`credentials.json` =
  Admin, `credentials_member.json` = Nicht-Admin).
  **Aufruf:** vorher `python3 -m http.server <port>` im Repo-Ordner
  starten (beide Skripte können denselben Server nutzen), dann
  `node regression_suite.mjs <port>` und
  `node regression_suite_member.mjs <port>`.
  **Verbindliche Regel (seit 2026-08-23, analog zum Blankoscheck für
  `git push`, siehe "Wie mit dem Nutzer arbeiten" unten):** Claude Code
  lässt beide Skripte automatisch vor jedem `git push` laufen, ohne
  vorher zu fragen. Schlägt dabei ein Test fehl, NICHT einfach pushen —
  den Fund kurz melden und gemeinsam klären, ob es ein echter Bug oder
  ein veralteter Test ist.
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
- **Workflow**: Commits/Pushes laufen automatisch durch Claude Code (ein
  GitHub Personal Access Token liegt im `credential.helper store` des
  Nutzers). SQL-Schema-Änderungen laufen über die echte Migrations-
  Toolchain, siehe eigener Abschnitt "Supabase-CLI-Migrationstoolchain"
  unten (Details zum davor genutzten manuellen Workflow: HISTORY.md).
- **Frontend-Framework-Frage (React/Vue/etc.):** die "eine `index.html`,
  kein Framework"-Linie ist eine bewusste Entscheidung nach dem
  Rule-of-Three-Prinzip ("nicht vorbeugend wechseln, erst bei echtem
  Auslöser"), keine technische Zwangslage. **Wichtige Klarstellung:**
  Konfigurierbarkeit (welche Bausteine sind je Organisation aktiv — löst
  sich über `rule_configs`, z.B. ein `enabledModules`-Schlüssel) und die
  Frage "Framework oder nicht" (betrifft nur, wie wartbar/wiederverwendbar
  der Code innerhalb eines Bausteins ist) sind zwei unabhängige Fragen —
  ein Framework schaltet keine Module für Kunde A ab und für Kunde B an,
  das bleibt so oder so Config-Arbeit. **Konkrete Alarmglocken-Schwellen,
  ab denen das Framework-Thema aktiv wieder aufgegriffen werden sollte**
  (nicht vorher, nicht von selbst; Entstehung/Baseline-Messung: HISTORY.md):
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

Dasselbe Prinzip wie bei der Frontend-Framework-Schwelle oben (konkrete,
prüfbare Auslöser statt vagem "irgendwann später"), angewendet auf die
übrige Infrastruktur (Entstehung: HISTORY.md).
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
- ~~**Vollständige Zeitraster-Engine (Termin-Zeiten geräteunabhängig statt
  Browser-lokal)**~~ — **fertig gebaut, noch am selben Tag, 2026-08-21**,
  siehe eigener Abschnitt "Zeitzonen: pro Nutzer, geräteunabhängig"
  unten. Ursprünglich hier als Zukunfts-Schwelle mit explizitem
  Auslöser ("erst wenn ein Teammitglied real reist/aus einer anderen
  Zeitzone arbeitet") vermerkt — der Nutzer hat sich nach kurzer
  Rückfrage bewusst dagegen entschieden zu warten: die Zeitraster-Engine
  wird laufend weiter ausgebaut (jedes neue Kalender-Feature vergrößert
  den Umstellungs-Umfang), es gibt noch keine echten Produktions-Nutzer
  (nur Tester, siehe Erinnerung `feedback_no_production_users_yet`), und
  die Anforderung war durch die Salesforce-Nachfrage klar genug, um
  direkt zu bauen statt zu spekulieren. **Lehre für ähnliche Fälle:**
  eine dokumentierte "warten auf Auslöser"-Schwelle ist kein Dogma — wenn
  sich die zugrundeliegenden Annahmen (hier: Produktionsrisiko) als
  falsch herausstellen, lohnt sich ein zweites Nachfragen, keine stures
  Festhalten an der ursprünglichen Einschätzung.

Diese Liste ist absichtlich nicht abschließend — ein neues Thema verdient
erst dann eine eigene Schwelle, wenn es wichtig genug wird, statt vage
"später" zu bleiben.

## Datenbank — aktueller Stand

**Falls der unten beschriebene Zustand nicht mit der echten DB übereinstimmt,
sofort korrigieren, bevor irgendetwas gebaut wird** — sonst versucht Claude
Code eventuell, Dinge doppelt anzulegen oder Migrationen in falscher
Reihenfolge zu bauen. Aktuelle Schema-Änderungen laufen über
`supabase/migrations/` (siehe "Supabase-CLI-Migrationstoolchain" unten,
`supabase migration list --linked` zeigt den echten Stand). Die alten
`sql/patchN_....sql`-Dateien + `PATCH_LOG.md` sind ein eingefrorenes
Archiv der ursprünglichen, manuellen Patches 1–39 — nicht mehr der
aktive Ablageort für Neues (Entstehungsgeschichte des alten Workflows:
HISTORY.md).

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

### Supabase-CLI-Migrationstoolchain

Supabase-CLI liegt als normale Dev-Abhängigkeit im `package.json`
(`npm install` holt sie automatisch mit). Projekt ist per `supabase
link --project-ref aaqbbkcghxldsbhqwcyh` verknüpft, Login-Zugang liegt
lokal beim Nutzer (kein Token je durch den Chat geschickt).

**Wichtige technische Einschränkung:** `supabase db pull`/`db diff`
brauchen im Hintergrund Docker (lokale Schatten-Datenbank zum Diffen) —
in der Claude-Code-Sandbox nicht erreichbar, nur im echten Terminal des
Nutzers möglich. **`supabase db push` braucht dagegen KEIN Docker** (nur
eine direkte Postgres-Verbindung) — funktioniert deshalb direkt aus der
Sandbox heraus. Entstehungsgeschichte/Baseline-Migration: HISTORY.md.

**Workflow für Schema-Änderungen:**
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

**Vor jedem Push Dry-Run gegen die echte DB, mit `begin`/`rollback`
als Teil der SQL-Datei selbst:** `supabase db query -f <datei>` führt
IMMER direkt aus, unabhängig vom Dateiinhalt — ein `begin`/`rollback`
muss explizit TEIL der SQL-Datei sein (Entstehung dieser Lehre: ein
Versuch, das über einen externen Wrapper-Aufruf zu erzwingen, wandte
eine Migration versehentlich direkt auf die Live-DB an, siehe
HISTORY.md), kann nicht durch den Aufruf selbst erzwungen werden. Bei
inhaltlich riskanteren Migrationen zusätzlich Assertions/Testfälle
gegen echte Wegwerf-Testprofile in denselben Dry-Run einbauen.

**Verbindliche Regel, seit 2026-08-24, Kernbestandteil der Arbeitsweise
ab sofort** (Auslöser/Bewährung: HISTORY.md, [[project_optimistic_locking_enforcement_gap]]):
bei jeder Migration, die RLS-Policies, `GRANT`/`REVOKE`,
`SECURITY DEFINER`-Funktionen oder sonstige Berechtigungslogik anfasst,
holt Claude Code vor dem `supabase db push` eine **unabhängige
Zweitmeinung** ein — ein frischer Agent/eine frische Sitzung ohne
Kontext der Bau-Session liest den Diff blind gegen (`/code-review` bzw.
das Agent-Werkzeug mit `subagent_type: claude-code-guide`/
`general-purpose`, je nach Bedarf; wenn sinnvoll mit einem anderen
Modell als die Bau-Session, z.B. `model:'opus'`). Reine Struktur-/
Optik-Migrationen (neue Spalte ohne Berechtigungsbezug, reine Indizes)
brauchen das nicht — der Maßstab ist "berührt diese Migration, wer
schreiben/lesen darf", nicht "ist es eine Schema-Änderung". Ein
lokaler, unversionierter `pre-push`-Git-Hook (`.git/hooks/pre-push`)
warnt zusätzlich beim `git push`, wenn eine gepushte Migration
Berechtigungslogik enthält — bewusst nicht blockierend, reine
strukturelle Erinnerung.

**Zweite verbindliche Regel, selber Auslöser:** der Dry-Run-Schritt
prüft ab jetzt auch, ob ein Rückbau tatsächlich möglich ist — bei
Policy-Änderungen die alte Definition testweise innerhalb derselben
`begin`/`rollback`-Transaktion wiederherstellen, oder zumindest
sicherstellen, dass sie vollständig im Migrations-Kommentar/der
git-Historie dokumentiert bleibt.

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

- Aktuelle Kurve (seit 2026-08-26, Akquise-Trichter-Neukalibrierung):
  `levelBase = 6.75`, `levelExponent = 1.5` → `XP für Level L = 6.75 *
  L^1.5`. Ziel: bei durchschnittlicher Vertriebsleistung soll Level 100
  nach **10 Jahren** erreicht werden (200 Arbeitstage/Jahr angenommen).
- Diese Kalibrierung wurde mehrfach neu gerechnet, wenn sich das Regelwerk
  änderte (z.B. als Quest-Boni dazukamen, als "Ansprache" vereinheitlicht
  wurde, als Konversions-Bonus/-Malus eingeführt wurde). **Jede substanzielle
  Änderung an XP-Werten oder Quest-Häufigkeit sollte die Kurve neu
  kalibrieren** — Methode: wöchentliches XP-Budget aus angenommener
  Aktivität hochrechnen, `levelBase` so wählen, dass die Summe aller
  Level-Schwellen 1–99 dem 10-Jahres-Gesamt-XP entspricht.
- **Größte bisherige Neukalibrierung (Patch 50):** alle 76 Questbaum-
  Stufen + 11 Epics bekamen ein `bonus`-Feld, gleichzeitig wurde
  klargestellt, dass Questbaum-Stufen **Jahresquests** sind
  (Geschäftsjahr = Kalenderjahr, siehe "Questbaum: Jahres-Reset..."
  unten) — dieselbe Stufe ist damit pro Jahr einmal, aber über mehrere
  Jahre hinweg mehrfach verdienbar. `levelBase` stieg deshalb von 4,70
  auf 5,80 (+23,3% Gesamt-XP bis Level 100). Volle Methodik als
  Rechenbeispiel: HISTORY.md.
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

**Hinweis zur Terminologie:** die Klasse heißt "Zauberer"/"Zauberin", NICHT
"Hexer" — bewusst so gewählt (die einzige weibliche Form wäre "Hexe", negativ
konnotiert), betrifft auch interne Schlüssel (`profiles.character_class`,
Item-Keys `zauberer_stab`/`zauberer_cape`). Entstehung/Umbenennung: HISTORY.md.

Klassenabhängige Begriffe für dieselbe Funktion:
| Funktion | Zauberer | Krieger | Schütze |
|---|---|---|---|
| Gilde | Orden | Legion | Bund |
| Mitglied hinzufügen | Arkanisten hinzufügen | Legionäre hinzufügen | Bundesbrüder hinzufügen |
| Kundendatenbank | Arkanes Register | Kriegsarchiv | Jägerchronik |
| Kanban | Questpfad | Gildenbrett | Feldzug |
| Verkaufsstatistik | Arkanes Kompendium | Kriegskasse | Trophäenkammer |

**Verkaufsstatistik-Seite** (`#page-statistik`, Nav-Reiter "Kompendium"/
"Kriegskasse"/"Trophäenkammer" je Klasse, `updateStatistikLabels()` in
`index.html`, gleiches Muster wie `updateKanbanLabels()`/
`updateContactLabels()` — Nav-Button-Text UND Seiten-Überschrift ändern
sich mit der Klasse). In der Navigation direkt unter "Abenteuerlog"
einsortiert. Vollständig gebaut inkl. KPI-Kacheln/Diagrammen — siehe
Abschnitt "BWS-Verrechnung: Provision & Bewertungspunkte" weiter unten.

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
einem Klick ohne Auswahl. Löst **keinen** `profiles`-Insert aus — blättert
nur weiter zum Aussehen-Screen, der eigentliche atomare Insert (alle Felder
inkl. `skin_tone`/`hair_style`) passiert dort ganz am Ende, siehe
"Aussehen-Screen" unten. Die Werte aus dem Profil-/Klassenwahl-Screen
werden dafür beim finalen Insert aus den (nur visuell versteckten, nicht
entfernten) Input-Feldern gelesen.

**`.btn-disabled` statt natives `disabled`-Attribut, bewusst so** (bei
`profileNextBtn` UND `charCreateBtn`): ein echtes `disabled`-Attribut
unterdrückt Klick-Events komplett, dann könnte kein Wobble-Hinweis beim
Versuch ausgelöst werden. Die CSS-Regel `.auth-btn:disabled,.auth-btn.btn-disabled`
sorgt dafür, dass beide Zustände (natives Attribut UND die neue Klasse)
gleich aussehen (gedimmt, kein Leucht-Gradient) — betrifft auch den
`authSubmitBtn`, falls der je ein `disabled`-Attribut bekommen sollte.

**Admin-Debug-Zugang zu diesen Screens:** der Admin-Knopf "🎭 Neu
erschaffen" springt für Admins zurück auf `profileScreen` →
`charCreateScreen` → `appearanceScreen` und aktualisiert am Ende das
bestehende Profil statt ein neues anzulegen — damit lassen sich diese
drei Onboarding-Screens (die ein normaler Account nur einmalig
durchläuft) jederzeit im echten, laufenden Programm ansehen/testen,
ohne Dummy-Datei. Entstehung/Hintergrund: HISTORY.md, sowie Claudes
Erinnerung `feedback_dummy_first_prototyping` für die generelle Lehre.
**Achtung, wiederholt gefundene Bug-Klasse:** dieser Knopf ruft am Ende
erneut `enterApp()` auf — Init-Funktionen, die Listener ohne Guard-Flag
neu registrieren, häufen bei jedem Klick weitere Listener/Timer an
(mehrfach in Bugfix-Häppchen gefunden und gefixt, siehe
`project_full_bugfix_sweep`). Neue Init-Funktionen entsprechend mit
einem Guard-Flag gegen Mehrfachaufruf absichern.

## Aussehen-Screen (Hautfarbe/Frisur)

Vierter Onboarding-Schritt, direkt nach der Klassenwahl, vor dem Sprung ins
Programm: `authScreen` → `profileScreen` → `charCreateScreen` → **`appearanceScreen`**
→ App. Der eigentliche `profiles`-Insert (inkl. `character_class`/
`real_name`/`gender`/`company`/`skin_tone`/`hair_style`) passiert ganz am
Ende, im Klick-Handler von `appearanceDoneBtn` — die Klassenwahl selbst
löst keinen Insert aus, sondern blättert nur weiter zum Aussehen-Screen.

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

**Live-Vorschau: animiert, dynamisch aus Ebenen zusammengesetzt** — ein
`<canvas>`, das jeden Frame per `drawImage()` aus den einzelnen
Ebenen-Sheets neu zusammensetzt (kein statisches `<img>`-Übereinanderlegen
— generelle Lehre dazu: Erinnerung `feedback_dynamic_over_static_rendering`).

Technik (`createSpriteRenderer(canvas, scale)`):
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
Buttons, Frisuren-Raster) — nicht mehr für die Vorschau selbst (die läuft
über die vollen Sheets, siehe oben).

**Datenbank:** `profiles.skin_tone`/`hair_style` (nullable) — reine
Schlüssel in den fest im Frontend hinterlegten Katalog (`SKIN_CATALOG`/
`HAIR_CATALOG`, nur in `index.html` gepflegt), keine eigene Farbspalte
nötig (Farbe steckt schon in der gewählten Frisur).

**`Design/`-Ordner (gitignored) enthält bewusst nur noch:** die rohen
GandalfHardcore-Zips + `extracted/` (Quellmaterial für künftige Assets)
sowie die zwei aktiv gebrauchten Erzeuger-Skripte
`export_creator_assets.py` und `export_full_sheets.py` (erzeugen die im
Produkt verwendeten `img/characters/creator/`- und
`img/characters/sheets/`-Bilder — bei Bedarf erneut ausführbar). Alle
früheren Wegwerf-Vorschau-/Entscheidungswerkzeuge aus der Bau-Phase
wurden nach Übernahme ihrer Ergebnisse gelöscht (Liste/Details:
HISTORY.md).

## Kanban (Questpfad / Gildenbrett / Feldzug), seit Patch 18

Acht feste Spalten (Reihenfolge in `KANBAN_STAGES` in `index.html`, seit
2026-08-26): Neuer Lead → Ersttermin vereinbart → Angebot versendet →
Zweittermin → Nicht erschienen → Gewonnen / Verloren → Dauerbrenner.
**Bewusst fest im Code**, nicht konfigurierbar (Rule of Three — erst wenn
eine zweite Organisation ansteht, lohnt sich die Abstraktion; vorher würden
wir nur raten). "Nicht erschienen" saß ursprünglich direkt hinter
Ersttermin vereinbart — seit "Nicht erschienen" auch vom Zweittermin aus
erreichbar ist (siehe "Akquise-Trichter" unten), sitzt es jetzt als
gemeinsames Auffangbecken hinter beiden "echten Treffen"-Spalten.

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
- → Nicht erschienen: seit 2026-08-26 **von Ersttermin vereinbart ODER
  Zweittermin aus**, sonst Abbruch. Loggt `termin_nicht_wahrgenommen`
  (Herkunft Ersttermin) bzw. `zweittermin_nicht_wahrgenommen` (Herkunft
  Zweittermin, neuer Aktions-Schlüssel), beide −2 XP.
- → Angebot versendet: Aktion `pitch`, danach optionales Popup
  "Bedarfsanalyse geführt?" (kann übersprungen werden). **Kein**
  Termin-Popup — ein verschicktes Angebot ist kein Treffen.
- → Zweittermin: dieselbe Aktion `pitch` + dieselbe Bedarfsanalyse-Nachfrage
  wie Angebot versendet, zusätzlich aber (seit Patch 33, extra entkoppelt)
  dasselbe überspringbare Termin-Popup wie bei Ersttermin — ein Zweittermin
  ist ein echtes Treffen. Loggt seit 2026-08-26 zusätzlich `zweittermin_
  vereinbart` (0 XP, reine Zähl-Markierung fürs Akquise-Trichter-Diagramm,
  siehe eigener Abschnitt unten) — vorher teilte sich Zweittermin die
  Aktion `pitch` mit Angebot versendet, ließ sich also nicht separat zählen.
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

## Akquise-Trichter (Statistik-Seite), seit 2026-08-26

Neue Kachel auf der Verkaufsstatistik-Seite (Kompendium/Kriegskasse/
Trophäenkammer, zwischen "Konstanz" und dem Kategorie-Balkendiagramm):
Ansprachen → Ersttermin vereinbart → Ersttermin wahrgenommen →
Zweittermin vereinbart → Zweittermin wahrgenommen → Gewonnen, als
schmaler werdende Balken (Trichter-Optik), plus zwei Kennzahlen darunter
("Ansprachen pro Abschluss", "Ersttermine (wahrgenommen) pro Abschluss").
Ursprung: der Nutzer nutzt privat eine Excel-Vorlage
(`Conversion_Funnel_Blanko.xlsx`) für genau diese Kennzahl, wollte sie
als echte, live berechnete Statistik im Programm.

**Bewusst kein Kanal-Unterschied** (Krankenhaus vor Ort vs. Telefon) —
ursprünglich in der Excel-Vorlage vorhanden, vom Nutzer explizit
verworfen ("wie der Termin zustande gekommen ist, ist egal, Akquise ist
Akquise"). "Ansprachen" zählt deshalb jede Form der Erstkontaktaufnahme
zusammen: Aktion `ansprache` (vor Ort) + `kalttelefonie` + `telefon_5`
(×5, ein Log-Eintrag steht für 5 gewählte Nummern, gleicher Faktor wie
bei der Konstanz-Kachel).

**Reine Ableitung aus dem eigenen `action_log`**, nichts wird extra
gespeichert (`computeAcquisitionFunnel()`/`logForPeriod()` in
`index.html`, gleiches Zeitraum-Prinzip wie der Rest der Seite — Jahr-
oder Monats-Reiter, org-lokales Kalenderjahr). "Ersttermin wahrgenommen"/
"Zweittermin wahrgenommen" sind KEINE manuellen Zusatzklicks mehr,
sondern werden von `moveKanbanCard()` automatisch mitgeloggt, sobald
eine Karte vom jeweiligen Termin aus **weiterwandert** — auch wenn das
Ziel "Verloren" ist ("Termin fand statt, hat aber zu nichts geführt",
ausdrückliche Nutzer-Entscheidung). Genauer:
- Ersttermin vereinbart → {Angebot versendet, Zweittermin, Gewonnen,
  Verloren}: loggt zusätzlich `termin_wahrgenommen` (bestehende Aktion,
  vorher praktisch nie automatisch ausgelöst).
- Zweittermin → {Gewonnen, Verloren}: loggt zusätzlich
  `zweittermin_wahrgenommen` (neue Aktion, 12 XP).
- → Zweittermin (aus beliebiger Herkunft): loggt zusätzlich
  `zweittermin_vereinbart` (neue Aktion, 0 XP, reine Zähl-Markierung —
  die eigentliche Belohnung bleibt bei der unveränderten `pitch`-Aktion,
  15 XP, sonst würde derselbe Kanban-Schritt doppelt kassieren).

Diese drei abgeleiteten Markierungen laufen seit 2026-08-27 über
`logKanbanAction(..., {defer:true})` — `moveKanbanCard()` bündelt bis zu
4 Log-Aufrufe pro Kartenzug und zieht Quest-Check + `render()` genau
**einmal** nach (`flushKanbanActionPost()`), statt pro Aufruf. Zusätzlich
werden `termin_wahrgenommen`/`zweittermin_wahrgenommen`/
`zweittermin_vereinbart` **je Kontakt und Geschäftsjahr nur einmal**
automatisch geloggt (`hasFunnelMarkerThisYear()`) — mehrfaches
Hin-und-Her-Ziehen einer Karte kann die Trichterzahlen/XP dadurch nicht
mehr vervielfachen. Manuelle Pfade (Dauerbrenner-`offerExtraAction`)
sind davon nicht betroffen.

**Level-Kurve neu kalibriert, weil `termin_wahrgenommen`/
`zweittermin_wahrgenommen` jetzt eine häufige statt einer seltenen
XP-Quelle sind** (Nutzer-Entscheidung: die automatische XP bleibt
bestehen, dafür wird die Kurve angepasst). `levelBase` 5,80 → **6,75**
(+16,5%, Methodik wie bei Patch 50 — wöchentliches Zusatz-XP-Budget
geschätzt aus der bereits bestehenden Konstanz-Schwelle "5–7 Termine
wahrgenommen/Woche", hält "Level 100 nach 10 Jahren" stabil trotz der
neuen automatischen Quelle). Migration
`supabase/migrations/20260826180000_zweittermin_actions_und_levelkurve.sql`.

**Farbe: ein einfarbiger Verlauf hell → dunkel aus der aktiven
Klassenfarbe**, per CSS `color-mix()` gegen die live gesetzte
`--arcane`-Variable (`FUNNEL_RAMP` in `index.html`) — passt sich dadurch
automatisch jeder der drei Klassen an, ohne einen eigenen Farbsatz pro
Klasse im JS zu brauchen. Entspricht der etablierten Diagramm-Richtlinie
für Rang-/Trichterdaten (eine Farbe, monotone Helligkeitsstufen, nicht
mehrere Kategorie-Farben).

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

## Einstellungen: Registry-getriebenes Fundament

Registry-getriebener Aufbau (Entstehung: HISTORY.md; Nutzer verstand das
Registry-Prinzip nicht vollständig, gab aber Best-Practice-Grünes-Licht —
generelle Lehre dazu in Claudes Erinnerung,
[[feedback_defer_to_best_practice_when_confused]]).

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

**Aktuelle Optik/Layout** (Entstehung/Nutzer-Feedback dazu: HISTORY.md):
echter Pill-Schalter (`.settings-switch`, folgt der Klassen-Akzentfarbe),
volle-Breite dunkle Inputs (`.settings-input`), normale Fließschrift für
Beschreibungen (`.settings-field-desc`). Startseite zeigt die 4 Gruppen
als kompakte Icon-Kacheln (`buildSettingsTileGridHtml()` — Symbol, Name,
Untertitel = Feldanzahl oder "N geändert"), Klick öffnet
`openSettingsGroupModal(gid)` — ein `.loc-modal` mit den Feldern dieser
EINEN Gruppe, exakt wie beim Produkt-Detail-Modal. Danger Zone bleibt
eine eigene rote Karte außerhalb des Kachel-Rasters. Save-Bar/Toast haben
`z-index:1002` (über dem Modal, `z-index:1000`). Suche filtert die
Kacheln UND hebt passende Felder hervor, sobald das jeweilige
Gruppen-Modal offen ist (`settingsHighlightFieldsInScope()`). Die
Arbeitszeiten-Tagesreihen nutzen ein kompaktes `.az-day-row`-Layout
(Label links, beide Uhrzeiten rechts als Paar) — bricht auch im
schmaleren Modal (480px) nicht um.

## Sicherheitsprinzipien: XSS-Escaping + RLS-Schreibschutz

**Escaping-Regel, ohne Ausnahme:** jeder neue Rendering-Code, der
Datenbank-Text per `innerHTML` einfügt, muss `escHtml()` (oder den
neueren `html`-Tag, siehe Bugfix-Durchgang-Fazit weiter unten)
verwenden — `escHtml()` escapt sowohl Text- als auch Attribut-Kontexte
(inkl. Anführungszeichen). Ausnahme: Inhalte aus `rule_configs`
(Quest-/Aktions-Namen) — kommen nicht aus In-App-Formularen, sondern
werden vom Admin direkt per SQL gepflegt, vertrauenswürdige
Konfiguration. Trotz mehrerer großer, gezielter Sicherheitsdurchgänge
(Entstehung/Funde: HISTORY.md) tauchte diese Lücke bei neuem Code
wiederholt erneut auf, siehe die Bugfix-Durchgang-Bilanz weiter unten.

**RLS-Design-Prinzip für neue Tabellen:** eine `using`-Bedingung, die
direkt die Eigentümer-Spalte referenziert (`owner_id = auth.uid()`),
ist automatisch sicher gegen Fremdumbiegung dieser Spalte. Hängt die
Bedingung dagegen an einer ANDEREN Spalte (klassisch: `id = auth.uid()`
bei `profiles`), sind alle ÜBRIGEN Spalten ungeschützt, sofern keine
explizite `with check`-Klausel oder ein Trigger das abdeckt — genau
dieses Muster hat wiederholt echte Rechte-Eskalations-Lücken erzeugt
(`profiles.role`/`character_class`/`org_id`, `user_inventory`, siehe
"Serverseitige Schreib-Härtung" weiter unten für die aktuell gültige,
umfassendere Lösung). Bei jeder neuen Tabelle mit sensiblen Spalten
diesen Fall gezielt gegenprüfen.

**Werkzeug für Sicherheits-/Performance-Audits:** `supabase db
advisors --linked --type all --level info` (Supabases offizieller
Linter gegen die echte, verlinkte DB — `export
PATH="$HOME/.local/share/nodejs-portable/bin:$PATH" &&
./node_modules/.bin/supabase db advisors --linked ...`, JSON-Output gut
mit `jq` auswertbar). Deutlich zuverlässiger als eigenes Grep-Raten —
bei künftigen Audits zuerst hiermit starten. `returns trigger`-Funktionen
können von Postgres strukturell nicht per RPC aufgerufen werden,
unabhängig von vergebenen Ausführungsrechten — als "von anon/
authenticated ausführbar" gemeldete Trigger-Funktionen sind deshalb
i.d.R. unbedenklich.

**Stolperstein beim `revoke execute ... from anon`:** eine neue
`CREATE FUNCTION` bekommt von Postgres automatisch einen zusätzlichen
`EXECUTE`-Grant für die Pseudo-Rolle `PUBLIC` (unabhängig von den
projekteigenen `ALTER DEFAULT PRIVILEGES`-Regeln für `anon`/
`authenticated`). Ein reines `revoke execute ... from anon` wirkt
deshalb NICHT — `anon` behält den Zugriff über den `PUBLIC`-Eintrag.
Immer `revoke execute ... from public, anon` schreiben und per
`has_function_privilege('anon', ..., 'EXECUTE')` im Dry-Run verifizieren
(Fund/Beleg: Supabase-Advisor-Triage 2026-08-26, siehe HISTORY.md und
Claudes Erinnerung `project_supabase_advisor_triage`).

**Feldlängen-Konvention** für neue Freitextfelder (reine UX-Hygiene,
kein Sicherheitsmechanismus): Namen/Orte/Titel 60–150 Zeichen,
Notizfelder 1000–3000, bewusst großzügige Felder (z.B. die 5
Tagebuch-Fragen) bis 5000. Reine Such-/Autocomplete-Felder und der
admin-only `configEditor` (roher JSON) bleiben unbegrenzt.

**"Leaked Password Protection" im Supabase-Dashboard ist aus — bewusst,
kein offener Punkt:** das Feature ist ein Pro-Plan-Feature, auf dem
aktuellen Free Plan nicht einschaltbar (gleiches Muster wie die
fehlenden automatischen Backups, siehe Claudes Erinnerung
`project_supabase_backups`). Taucht bei jedem `supabase db advisors`-
Lauf weiterhin als Fund auf — das ist kein neuer Hinweis, nicht von
selbst als Handlungsaufforderung vorschlagen, erst wieder relevant bei
einem ohnehin anstehenden Plan-Upgrade.

## Abenteuerlog-Seite (Kalender/Tagebuch/Foto)

Reihenfolge auf `#page-tagebuch` ist bewusst: **Kalender oben →
Tagebuch-Serie → die 5 Tagebuch-Fragen → Foto ganz unten**.

**Tagebuch-Serie** (Kachel zwischen Kalender und Tagebuch-Fragen,
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

**Wichtiges Prinzip:** "hat einen Eintrag" heißt NICHT "eine
`journal_entries`-Zeile für den Tag existiert" (ein `upsert` beim Leeren
aller 5 Felder überschreibt die Zeile nur mit leeren Strings, löscht sie
aber nicht — und ein echtes Löschen ist wegen `journal_entry_mentions`
`on delete cascade` ohnehin nicht die richtige Lösung, @mention-
Markierungen sollen bewusst NICHT löschbar sein). `journalRowHasContent(row)`
prüft deshalb an allen Stellen, die "Tag hat einen Eintrag" auswerten
(`renderCalendar()`, `loadJournalStreak()`, `scheduleJournalSave()`), ob
mindestens eines der 5 Felder noch echten Text enthält, statt auf
Zeilen-Existenz zu prüfen — bei jeder künftigen Änderung an dieser Logik
dasselbe Prinzip weiterverwenden (Entstehung: HISTORY.md).

**Echter Termin-Kalender (Wochenansicht, Outlook-Stil):** der Kalender
bleibt in der Monatsansicht ein reiner Tagebuch-Rückblick, bekommt aber
eine umschaltbare **Wochenansicht** dazu (`calViewMode`
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
native HTML5-Drag&Drop — funktioniert zuverlässig auch auf Touch) öffnet
ein Popup (Titel, Start/Ende, optional Kontakt-/Betrieb-Suche über
`initGenericAutocomplete()`, wiederverwendet den `contactLocationSearch`-
Stil). Ob ein Klick einen bestehenden Termin öffnet oder einen neuen
erzeugt, entscheidet die **Ziehstrecke** (>6px Bewegung = neuer Termin),
nicht das Element unter dem Finger — sonst ließe sich kein zweiter,
überschneidender Termin über einem bereits voll-breiten bestehenden
Termin aufziehen. Zeitachse bleibt beim seitlichen Scrollen sticky
(`.week-time-col{position:sticky;left:0}`), Wochenansicht nutzt
`overflow-x:auto` (nicht `hidden` — sonst wären Samstag/Sonntag auf
schmalen Bildschirmen unsichtbar abgeschnitten statt scrollbar,
Entstehung dieses Stolpersteins: HISTORY.md).

**Kanban-Integration:** die Kanban-Übergänge "Ersttermin vereinbart" und
"Zweittermin" fragen beide (überspringbar, `promptKanbanTermin()`) nach
Datum+Uhrzeit und legen bei Eingabe einen echten Kalendertermin an — an
**beiden** Auslösern: dem Dungeon-Button (`terminLeadModal`) UND beim
Ziehen einer bestehenden Karte im Board. **"Angebot versendet" bekommt
bewusst KEIN Termin-Popup** (teilt sich zwar die Aktion `pitch` mit
Zweittermin, ist aber bewusst entkoppelt — ein Angebot verschicken ist
kein Treffen). Derselbe `promptKanbanTermin()`-Baustein sitzt zusätzlich
als "Termin eintragen"-Button im Kontaktformular (`cdTerminBtn`) —
holt eine auf Gewonnen/Verloren stehende Karte dabei zusätzlich auf
Ersttermin zurück (gleiche `kundenausbau`-Aktion wie beim Ziehen im
Kanban, kein neuer Kontakt, Entstehung: HISTORY.md).

**Bewusst NICHT gebaut, Konzept für einen künftigen Quest-Typ:** ein
Rücksprung Gewonnen/Verloren → Ersttermin (Kundenausbau) soll im
Hintergrund mitzählen können, der wievielte Termin es der Reihe nach
für den Kontakt ist (eine durchlaufende Nummer pro Kontakt) — **bewusst
nirgends in der UI anzeigen**, die Chronik zeigt Kontaktintensität für
Menschen schon ausreichend über Datum/Art jeder Zeile. Zweck ist rein,
dass ein künftiger Kundenausbau-Quest-Typ (Kategorie "Advance", siehe
Questbaum-Notiz) diese Zahl als Schwellenwert nutzen kann. Solange keine
Quest das braucht, absichtlich nicht gecodet (Rule of Three) — bei
Bedarf live aus `action_log` ableiten (kein neues Speicherfeld nötig,
gleiches Prinzip wie `computeJournalStreak()`).

**Bewusst noch nicht gebaut (Phase 2, siehe "Bewusst aufgeschobene Ideen"-
Prinzip):** wiederkehrende Termine, Erinnerungen, Tagesansicht. Nicht von
selbst anfangen, nur auf expliziten Anstoß.

**Arbeitsfreie Tage:** ein Wochentag ganz ohne Arbeitszeiten-Eintrag gilt
als komplett arbeitsfrei, in der Wochenansicht ganztägig abgedunkelt
(`week-nonwork-overlay`, Entstehungs-Bugfix: HISTORY.md). Einstellung
`profiles.calendar_hide_weekends` (boolean, Default false) blendet
Samstag/Sonntag statt nur grau auch **komplett aus** (wie Outlooks
"Arbeitswoche"-Ansicht) — das Wochenraster passt seine Spaltenzahl/
-breite dafür dynamisch an (`grid-template-columns` pro
`renderWeekView()`-Aufruf per JS gesetzt).

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

**Bewusst weiterhin offen:** echte Erinnerungen (Push/E-Mail o.ä.), bewusst
unentschieden gelassen, keine Eile.

## UI-Konventionen: Sigil-Größe, Scroll-Fade, Buch-/Rollen-Kachel

**Sigil (Fähigkeiten-Radar):** großzügiges SVG-viewBox (530×530),
richtungsabhängiges `text-anchor` (Labels rechts vom Zentrum wachsen
nach rechts, links nach links, oben/unten zentriert) statt überall
`middle` — verhindert abgeschnittene lange Achsenbeschriftungen.
Responsiv per CSS (`width:100%;max-width:530px;height:auto`).

**Scroll-Fade an seitlich scrollbaren Leisten:** wiederverwendbarer
Helfer `initScrollFade(el)`/`updateScrollFade(el)` (per `mask-image`,
unabhängig von der Panel-Hintergrundfarbe) — blendet sich automatisch
an der Seite aus, an der nichts mehr zu scrollen ist. **Bei künftigen
neuen horizontal scrollenden Bereichen diesen Helfer wiederverwenden**
statt eine eigene Lösung zu bauen (Entstehung/Audit-Funde: HISTORY.md).

**Buch-/Rollen-Kachel:** unter dem Kalender ersetzt eine einzelne,
klassenabhängige Kachel (`.journal-book-tile`) die 5 Tagebuch-Fragen —
**Zauberbuch** (Zauberer), **Kriegsbuch** (Krieger), **Schützenrolle**
(Schütze, bewusst eine Pergamentrolle statt eines Buchs). Klick klappt
einen Wrapper (`#journalEntryWrap`) mit den 5 Fragen + Foto-Feld auf/zu
(`setJournalEntryOpen()`) — **kein Modal**, der Kalender soll beim
Schreiben sichtbar bleiben. Klassenzuordnung über `CLASS_JOURNAL` +
`updateJournalBookTile()`, aufgerufen in `initJournal()` und im
Admin-Klassenschalter. Die drei Icons sind handgezeichnete Pixel-Art
(kein GandalfHardcore-Asset), liegen unter
`img/characters/creator/journal_{zauberer,krieger,schuetze}.png`
(96×96, wie die übrigen `item_*`-Icons — Entstehung/Asset-Pipeline:
HISTORY.md).

## Changelog-Popup für angewendete SQL-Patches

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

## Sprite-Labor: Asset-Erstellungs-Werkzeug für neue Items

**`Design/sprite_lab.html`** — ein lokales, nicht versioniertes Werkzeug
(liegt im gitignoreten `Design/`-Ordner wie die Export-Skripte), über
Live Server geöffnet. Löst das Problem, dass neue Item-Sprites (Größe/
Spiegelung/Ankerpunkt) sonst nur per Live-Testen im deployten Programm
abstimmbar wären (Entstehung: HISTORY.md).

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

**Vom Export zum echten Sheet:** `Design/bake_sprite_lab_export.py`
nimmt `sprite_lab_export.json` + das Kandidaten-PNG und backt daraus
das echte 800×448-`outfit_*`-Sheet — item-unabhängig, wiederverwendbar
für jedes neue Item. **Wichtiger technischer Stolperstein:** PIL's
`Image.rotate(winkel)` dreht im bildschirmtypischen y-nach-unten-
Koordinatensystem optisch GEGENLÄUFIG zu Canvas' `ctx.rotate()`
(dieselbe Konvention, die das Sprite-Labor und `index.html` verwenden)
— im Skript deshalb bewusst mit umgedrehtem Vorzeichen
(`rotate(-winkel)`), gegen einen Canvas-Referenzlauf abgeglichen.

**Vor dem Zeichnen eines neuen Kandidaten weiterhin gültig:** Ankerpunkt
NICHT die Bounding-Box-Mitte der gesamten Form (kann deutlich neben dem
tatsächlichen Handgriff liegen), Mirror-Frage früh an einem einzelnen Frame
prüfen statt erst am fertigen Sheet — beides jetzt interaktiv im Sprite-Labor
prüfbar statt im Kopf vorausgeplant werden zu müssen.

## Pixel-Art-Referenzmasken-System

Löst das Problem, dass freihändig pro Frame platzierte Pixel-Art
mehrere Korrekturrunden braucht — Claude "sieht" ein gezeichnetes
Ergebnis nicht automatisch richtig, ohne es aktiv nachzumessen
(Entstehung: HISTORY.md, ausführlichere Doku auch in Claudes
Erinnerung `project_pixelart_reference_mask_system`).

**Kernidee, als drei Python-Module fest in `Design/` verankert:**

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

**Ehrlicher Status, nicht beschönigen** (Testläufe/Herleitung: HISTORY.md):
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

## BWS-Verrechnung: Provision & Bewertungspunkte

Übersetzt einen gewonnenen Verkauf (`sales` + sein `product`) in drei
**unabhängige** Kennzahlen — Bewertungspunkte, Provision,
Differenzprovision (nur LV/KV) — nie gespeichert, sondern wie XP/Level
bei jedem Seitenaufruf frisch aus `sales`+`products`+`profile`+
`rule_configs` berechnet (`aggregateStats()`/`saleBasisValue()`/
`saleBwp()`/`saleProvision()`/`saleDiffProvision()`, alle in
`index.html`, direkt neben der Verkaufsstatistik-Seite).

**`laufender_beitrag` ist die einzige echte Eingabe pro Verkauf.**
`sales.menge` wird nicht mehr multipliziert und ist bei Neuanlagen fest
auf 1 (Stückzahl-Feld entfernt — "man kauft nicht 2× dieselbe
Lebensversicherung, man erhöht den Beitrag"). Für Leben
(`provision_mode==='individuell_lv'`) wird die Bewertungssumme aus dem
Beitrag abgeleitet (`Beitrag × 360`, also × 12 Monate × 30 Jahre —
Beispiel: 200€ Beitrag → 72.000€ BWS), NICHT mehr separat erfasst;
`sales.bewertungssumme` bleibt als Spalte bestehen, wird aber nicht
mehr beschrieben.

**Produktanlage: nur Name + "Art"**, kein manuelles Faktoren-Einstellen
mehr. `PRODUCT_ART_CONFIG` (`index.html`) leitet Kategorie,
Provisions-Modus und beide Faktoren automatisch aus der gewählten Art
ab (`.view-switch`-Tastenreihe beim Anlegen, kein natives `<select>`):

| Art | Bedeutung | Provisions-Modus | Provisions-Faktor | Bewertungspunkte-Faktor |
|---|---|---|---|---|
| LV | Lebensversicherung | individuell (Leben-%-Satz) | — | ×0,05 |
| KV | Krankenversicherung | individuell (Kranken-MB-Satz) | — | ×8 |
| SH | Sach/Hausrat | fest | ×0,1 | ×1 |
| KFZ | Kfz | fest | ×0,08 | ×0,3 |
| RS | Rechtsschutz | fest | ×0,365 | ×0,75 |
| pmaSUH | pma-Vermittlung SUH | individuell (PMA-SUH-Satz) | ×0,23 (fester Teilfaktor) | ×1 |
| pmaKV | pma-Vermittlung KV | individuell (PMA-KV-Satz) | ×0,75 (fester Teilfaktor) | ×0 |
| D | Darlehen | fest | ×0,01 | ×0,02 |

Die 4 übrigen Excel-Arten (DP/KAP/KontoAPO/KontoStud) sind bewusst noch
nicht aufgenommen (Nutzerwunsch). **Individuelle Sätze** (nicht
organisationsweit, jeder trägt sie in den Einstellungen für sich
selbst ein): `profiles.lv_prozent_satz` (Leben, **Prozent** — Eingabe
mit deutschem Komma, `type:'decimal'`-Feld), `profiles.kv_mb_satz`
(Kranken, MB-Multiplikator), `profiles.pma_suh_satz`/`pma_kv_satz`
(PMA-Vermittlungssätze). Zusätzlich **Differenzprovision** (nur
LV/KV): `Betrag × (org-weiter Standard-Satz − individuelle Rate)` —
`rule_configs.diffProvLvPromille`/`diffProvKvMb` sind die
Referenzsätze (Leben in ‰, deshalb wird der persönliche %-Satz beim
Vergleich ×10 auf ‰ umgerechnet).

**Einstellungen-Seite** (Gruppe "Provision & Planungsziele", jeder
pflegt seine eigenen Werte, kein Admin-Umweg): die Sätze oben plus
persönliche Planungsziele (`profiles.planung_lv_bws`/`planung_kv_mb`/
`planung_bwp`) — Grundlage für die Fortschritts-Ringe auf der
Statistik-Seite.

**Verkaufsstatistik-Seite (Kompendium/Kriegskasse/Trophäenkammer):**
Reiter-Leiste oben (Jahr + 12 Monate) wählt den Zeitraum. **Sechs**
KPI-Kacheln (`statHeroCard()`): Bewertungssumme Leben,
Bewertungsbeitrag Kranken, Bewertungsbeitrag sonstige (SH/Kfz/RS/
pmaSUH/pmaKV/Darlehen zusammen — Kranken bewusst **eigene** Sparte,
nicht mit hineingemischt, siehe Bugfix-Sweep-Häppchen 6a), Bewertungs-
punkte, Provision, Differenzprovision — die ersten vier mit
Fortschritts-Ring gegen das persönliche Planungsziel (Ring optisch bei
100% gedeckelt, Prozentzahl daneben ungedeckelt; Provision/
Differenzprovision ohne Ring, dafür gibt es konzeptionell kein Ziel).
Jede Kachel zeigt in der Jahresansicht zusätzlich eine kleine
Sparkline der 12 Monatswerte. Darunter ein horizontales Balkendiagramm
der Bewertungssumme/-beitrag je Produktkategorie (validierte
8-Farben-Palette `STAT_CATEGORICAL`, feste Reihenfolge nach
alphabetisch sortierten Kategorien), ganz unten reine Zahlen-Kacheln
je Produkt (Stück + Summe). Datenbasis: nur die **eigenen** gewonnenen
Verkäufe des Nutzers (`created_by = profile.id`, `status='gewonnen'`),
gruppiert nach `vertragsbeginn` (Fallback `datum`).

## Bewusst aufgeschobene Ideen (NICHT vergessen, aber NICHT von selbst bauen)
- ~~**Notfall-Quest vor automatischer Kontakt-Löschung**~~ — **fertig
  gebaut, live, 2026-08-26**, siehe eigener Abschnitt "Sonderquest-
  Hinweise: automatisiertes Erkennungssystem" unten. Kein offener Punkt
  mehr.
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
- **Ausrüstungs-Charakterbilder / echter Charakterscreen** — **fertig
  gebaut, seit 2026-08-03** (Entstehung/verworfene Ansätze/Bogen-
  Iterationen: HISTORY.md). Ausrüstung nutzt dieselbe Sprite-Sheet-
  Technik wie der Aussehen-Screen (`items.sheet`, `{g}`-Platzhalter für
  Geschlecht): `layersForCharacterProfile()` baut live die Ebenen-Liste
  aus den angezogenen Items (`profiles.equipped_weapon/armor/
  accessory`), gerendert über `createSpriteRenderer()`. Anziehen/
  Ausziehen (`toggleEquip(itemKey, slotField)`) ist reine Kosmetik ohne
  XP/`action_log`, verbraucht das Item in `user_inventory` nicht. Item-
  Katalog unterscheidet `category:'waffen'|'ruestung'|'accessories'`
  (Ausrüstung) von Verbrauchsgütern mit `effect`-Feld (siehe `useItem()`).
  Die drei Klassenitems (Zauberer: Stab + Cape, Krieger: Holzschwert +
  Guard Helmet, Schütze: Rucksack + Bogen) sind echte Katalog-Items,
  werden neuen Charakteren automatisch ins Inventar gelegt UND
  angezogen (`grantClassStarterEquipment()`). `CLASS_OUTFIT`/
  `layersForClassPortrait` bleiben separat bestehen für die
  Onboarding-Vorschauen (Klassenwahl/Aussehen-Screen), wo es noch kein
  Inventar gibt — zeigen inzwischen für alle drei Klassen ein
  animiertes, aus Ebenen zusammengesetztes Beispiel (`<canvas>`, kein
  statisches Bild). **Asset-Quelle:** GandalfHardcore-Pakete
  (`~/Schreibtisch/GandalfHardcore *.zip`, gitignored) — Lizenz erlaubt
  kommerzielle Nutzung/Verändern, verbietet Weiterverkauf der Rohdaten;
  Multi-Tenant-SaaS-Lizenzfrage bewusst zurückgestellt bis zum ersten
  echten Verkauf an eine zweite Organisation. **`reward_item_key`+
  `qty`-Feld für Quests:** siehe "Ein aktiver, paralleler Nebenstrang" →
  "Item-/Mengen-System-Umbau", dort konsolidiert.

  **Zurückgestellte Alternative, falls mehrere Organisationen später
  einen jeweils eigenen Look brauchen:** ein riggtes 3D-Charaktermodell
  (z.B. Reallusion Character Creator) statt 2D-Ebenen — löst
  Bild-Ausrichtung strukturell, höherer Einstiegsaufwand, deshalb
  bewusst zurückgestellt, solange die 2D-Ebenen-Lösung für die
  aktuellen 3 Klassen ausreicht.

- **Multi-Org-Charakter-Portabilität**: die Idee, dass ein Nutzer den
  Charakter (Level/Skills/Tagebuch) über einen Arbeitgeberwechsel hinweg
  mitnehmen könnte, während Dungeons/Items/Quests bei der alten Organisation
  bleiben. **Echte strukturelle Weiche** (aktuell ist ein Profil fest an
  GENAU EINE Organisation gekettet) — bewusst nicht angefasst, nur
  dokumentiert.
- **Automatisiertes Anruf-Verzeichnis** ("wen sollte ich als Nächstes
  anrufen") — nur als Idee erwähnt, nichts geplant.

## Ein aktiver, paralleler Nebenstrang

Der Nutzer baut **außerhalb dieses Chats** parallel an einem größeren
Quest-Baum (Quest-Ketten wie "Krankenhaus-Meister", aber viel mehr davon) —
in Obsidian Canvas (`Questbaum.canvas`,
[[reference_obsidian_vault_questbaum]] in Claudes Erinnerung). Bringt der
Nutzer eine Quest-Baum-Änderung mit, geht es darum, sie ins
`recurringQuests`/`questChains`-JSON-Schema im Regelwerk zu übersetzen —
Format siehe bestehende Beispiele direkt in der Supabase-Tabelle
`rule_configs`. Der Questbaum ist seit 2026-08-15 vollständig übersetzt
(siehe [[project_questbaum_schema_design]]) — der tägliche Manatrank
hängt seitdem an der täglichen Quest `daily1` statt an einem separaten
Kalendertag-Mechanismus, jede erfüllte `recurringQuest` zeigt einen
Belohnungs-Toast (`showQuestRewardToast()`, Entstehung dieses ganzen
Bündels: HISTORY.md).

## Questbaum-Übersetzung, erster Schritt: Termin-Kanal + Vertriebsserien (Patch 40)

Der Obsidian-Questbaum wurde gemeinsam mit dem Nutzer auf Messbarkeit
gegen das echte System geprüft — die meisten Äste waren schon vorher
1:1 aus bestehenden Daten ableitbar (Entstehung/Session-Kontext:
HISTORY.md). Zwei konkrete Lücken wurden geschlossen:

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

## Gilden-basierte Sichtbarkeit, Phase 1

Ersetzt für Kontakte den alten organisationsweiten
`contactsVisibility`-Schalter als primären Mechanismus (Entstehung:
HISTORY.md).

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
  ob sie einem Dungeon zugeordnet sind oder nicht (auch dungeon-lose
  Kontakte, z.B. niedergelassene Ärzte ohne Krankenhaus-Dungeon, müssen
  teilbar sein). Kontakte haben deshalb **kein eigenes `guild_id`-Feld**,
  die Prüfung läuft direkt über Eigentümer+Gilde (`guild_contact_permission()`,
  Entstehung/Modellierungs-Korrektur: HISTORY.md).
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

**Wichtiges RLS-Design-Prinzip, aus echtem Debugging gelernt:** eine
`FOR UPDATE`-Policy mit korrektem `USING`/`WITH CHECK` reicht NICHT aus,
wenn die Zeile nicht ZUSÄTZLICH auch über eine bestehende `SELECT`-
Policy sichtbar ist — Postgres verlangt beides, die UPDATE-eigene
`USING`-Klausel ersetzt die Sichtbarkeits-Prüfung nicht (Debugging-
Verlauf: HISTORY.md). Bei künftigen ähnlichen Policies im Kopf behalten.

**Phase 2 (Notfall-Nachfolgekette) und Phase 3 (protokollierter
Admin-Notfallzugriff) sind ebenfalls live** — eigene Abschnitte weiter
unten. Provisions-/Statistik-Aufteilung bei gemeinsam bearbeiteten
Kontakten wurde bewusst komplett gestrichen ("zu weit in der Zukunft")
— läuft einfach auf den, der den Abschluss tatsächlich macht.

**Bewegter Avatar + Sigil auf Freundes-/Gilden-Kacheln:** die Kacheln in
`friendGrid` UND `guildGrid` (`renderFriendGrid()`/`renderGuildMembers()`)
zeigen `<canvas class="gt-avatar">` statt eines statischen Klassen-
Emojis — dieselbe `createSpriteRenderer()`/`layersForCharacterProfile()`-
Technik wie auf der eigenen Charakterseite, gespeist aus den ohnehin
schon organisationsweit lesbaren `profiles`-Feldern. Klick auf den
Avatar (`mountAvatarTile()` → `openFriendSigil()`) öffnet ein
`friendSigilModal` mit eigenem `<svg id="friendSigilSvg">` —
`drawSigil()` hat dafür einen vierten, optionalen Parameter (Ziel-SVG-
Id, Default `'sigil'`).

Für die Skill-Zahlen selbst reicht Sichtbarkeit von Level/Klasse nicht —
die liegen im privaten `action_log`. Bewusst **keine** breite SELECT-Policy
auf `action_log` (würde auch `context`/`meta`/`location_id`/`contact_id`
offenlegen, potenziell CRM-Notizen) — stattdessen eine schmale RPC-
Funktion `friend_skill_totals(target_user)`, die nur die aggregierten
Skill-Summen zurückgibt, geschützt durch `socially_visible()` (Freund
[`friends.status='accepted'`] ODER gemeinsame Gilde ODER man selbst).

## Gilden-Notfall-Nachfolgekette, Phase 2

Löst die in Phase 1 offen gelassene Frage: fällt ein Gildenführer durch
Account-Löschung aus, wer übernimmt die Gilde? Kriterium bewusst simpel
gehalten ("wahre Regeln, sobald ein konkretes Unternehmen da ist"): das
Mitglied mit `team_rights=true`, das am längsten dabei ist (`joined_at`
aufsteigend). Gibt es niemanden mit `team_rights`, fällt es auf das
insgesamt längste Mitglied zurück — eine Gilde soll nie ohne Not
führerlos werden, solange noch irgendwer drin ist. Der Nachfolger erbt
automatisch volle Rechte (`write`/`write`/`team_rights=true`), genau wie
ein Gildengründer.

Sitzt in `handle_member_offboarding()` (läuft VOR der bestehenden Pool-/
Löschlogik im selben `BEFORE DELETE`-Trigger auf `auth.users`).
`guilds.founder_id` ist nullable mit `ON DELETE SET NULL` (bewusst
NICHT `CASCADE` — würde beim Löschen eines Gildenführer-Accounts sonst
die komplette Gilde samt aller Mitgliedschaften mitreißen, echtes
Datenverlust-Risiko: "das sind Unternehmensdaten, tausende Kunden").
Bleibt im Extremfall (Gildenführer war das letzte Mitglied) niemand zum
Nachrücken übrig, wird `founder_id` einfach `NULL` — die Gilde samt
allen Pool-Kontakten/-Dungeons bleibt trotzdem bestehen, nur
vorübergehend ohne Führer (Zugriff auf so eine Gilde: siehe Phase 3).
Verifikations-Verlauf (inkl. Mitarbeiter-Offboarding-Nachtest):
HISTORY.md.

## Admin-Notfallzugriff, Phase 3

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

Verifikations-Verlauf: HISTORY.md.

**Damit ist das gesamte Gilden-Sichtbarkeits-Projekt (Phase 1+2+3)
fertig**, kein bekannter offener Punkt mehr in diesem Strang.

## Team-Reporting: Gildengründer = realer Teamleiter

Neue Seite "Team-Reporting" (`#page-team-reporting`), zeigt je Mitglied
der **eigenen gegründeten Gilde(n)** die Anzahl Dungeons/Kontakte —
reine Anzeige, kein neues Datenmodell, folgt direkt aus
`locations.owner_id`/`contacts.owner_id`.

**Sichtbarkeit bewusst NICHT an die `admin`-Rolle gekoppelt, sondern an
`guilds.founder_id`** (`myFoundedGuildIds`, geladen in `enterApp()` via
`loadMyFoundedGuilds()`) — der reale Teamleiter im Vertrieb IST der
Gildengründer, es braucht dafür keine eigene, neue Rolle (Entstehung/
verworfene admin-only-Erstfassung: HISTORY.md). **Wichtiges
Implementierungsdetail:** die Abfrage schränkt `locations`/`contacts`
**explizit** per `.in('owner_id', memberIds)` auf die eigenen
Gildenmitglieder ein, statt sich darauf zu verlassen, dass die
RLS-Policy schon zufällig eng genug filtert — ein Gildengründer ist im
echten Team oft zugleich Admin, über den `is_admin()`-Zweig der Policy
hätte eine ungefilterte Abfrage sonst doch wieder org-weite Daten
geliefert.

## Vertragsnummer-Feld an `sales`

Nullable `sales.vertragsnummer` (text), pro Verkaufszeile statt pro
Abschluss — ein Abschluss kann mehrere Produkte/Zeilen erzeugen
(`recordWonSalesLoop()`), jede Police hat üblicherweise ihre eigene
Nummer. Optionales Textfeld `saleEntryVertragsnummer` im Verkaufs-Popup,
Anzeige direkt neben dem Produktnamen in der Verträge-Zone der
Kontakt-Seite (`renderContactSalesTab()`).

## Datei-Upload bei Kontakten

Reiter "Dateien" am Kontakt (`renderContactFilesTab()`), gleiches
`.view-switch`-Tab-Muster wie Übersicht/Chronik/Tagebucheintrag.

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

**RLS-Lehre aus einem echten Bugfix** (Debugging-Verlauf: HISTORY.md):
bei RLS-Policies mit einer Subquery auf eine andere Tabelle immer
prüfen, ob Spaltennamen kollidieren (`name`/`id`/`status` sind in
diesem Projekt an mehreren Tabellen vergeben) — im Zweifel die eigene
Tabelle in der Policy explizit qualifizieren (`objects.name` statt
unqualifiziertem `name`), nicht auf unqualifizierte Referenzen
verlassen. Der bloße Tabellenname dient als eindeutige
Korrelationsvariable der eigenen Zeile innerhalb einer RLS-Policy,
unabhängig davon, was die Subquery sonst im FROM hat.

**Datei-Vorschau statt nur Download:** Klick auf den **Dateinamen**
(`.cd-file-name`) öffnet `filePreviewModal` mit PDF im `<iframe>` bzw.
Bild im `<img>` — alle vier erlaubten Typen stellt der Browser nativ
inline dar. **Bewusst kein dritter Button** ("Ansehen") — Nutzer wollte
"Herunterladen"/"Löschen" unverändert lassen. `createSignedUrl(...,
{download: f.filename})` erzwingt den echten Dateinamen beim Speichern
statt des internen UUID-Pfads.

**Nav-Highlight bei Direktaufruf/Reload einer Kontakt-Seite:**
`openContactPage()` markiert wie `showPage('kontakte')` den Kontakte-
Button (`data-page="kontakte"`) als aktiv — sonst blieb beim Neuladen
direkt auf `#kontakt/<id>` der im HTML hart hinterlegte Default
("🧙 Charakter") aktiv markiert, obwohl inhaltlich die Kontakt-Seite
angezeigt wurde (Bugfix-Verlauf: HISTORY.md).

## Storage-Aufräum-Warteschlange für gelöschte Kontakt-Dateien

Schließt die früher dokumentierte Lücke (siehe "Bekannte, bewusst in
Kauf genommene Lücken" oben): die automatische Löschung inaktiver
Kontakte (`auto_delete_inactive_contacts()`, DSGVO-Vorbereitung) lässt
`contact_files`-Zeilen kaskadieren, aber das eigentliche Objekt im
Storage-Bucket `contact-files` blieb bisher liegen — Supabase blockiert
eine direkte SQL-Löschung von `storage.objects`
(`storage.protect_delete()`-Trigger), nur die Storage-API kann wirklich
löschen, die von reinem SQL/pg_cron aus nicht ohne ein zusätzliches
Geheimnis in der Datenbank erreichbar ist (widerspräche dem
Architekturprinzip "kein versteckter Backend-Schlüssel").

**Lösung: Warteschlange + Admin-Login-Aufräumung**, gleiches Muster wie
der Geburtstags-/Manatrank-Nachtrag — kein neues Geheimnis nötig, die
Storage-API wird weiterhin nur über die normale, authentifizierte
Browser-Sitzung eines Admins aufgerufen
(`supabase/migrations/20260826160000_contact_files_storage_cleanup_queue.sql`).

**Erste Fassung hatte zwei echte, blockierende Lücken** — von einer
unabhängigen Zweitmeinung (blinder Review, kein Kontext der Bau-Sitzung)
gefunden, siehe Konvention `feedback_independent_review_and_rollback_gate`:

1. Die bestehenden Storage-Policies (`contact_files_storage_select`/
   `_delete`) hängen an "gehört noch ein passender `contacts`-Datensatz
   zum Pfad" — nach der Kontakt-Löschung existiert der per Definition
   nicht mehr, die Aufräumung hätte RLS-bedingt **nichts** gelöscht
   (Supabase Storage liefert bei einem per RLS leer gefilterten
   `remove()`-Aufruf `200 OK` mit leerem Ergebnis statt eines Fehlers —
   die Warteschlange wäre trotzdem geleert worden, ohne dass je etwas
   entfernt wurde). **Fix:** beide Policies bekommen einen zweiten,
   warteschlangen-verankerten Zweig (Admin der eigenen Organisation UND
   ein passender Eintrag in `contact_file_deletion_queue`).
2. `contact_files.storage_path` wurde beim Insert nie gegen `contact_id`
   geprüft — ein Gildenmitglied mit Lesezugriff auf einen fremden
   Kontakt (kennt dadurch dessen `storage_path`) hätte unter einem
   eigenen, beschreibbaren Kontakt eine `contact_files`-Zeile mit dem
   fremden Pfad anlegen und sofort wieder löschen können; die
   Warteschlange hätte beim nächsten Admin-Login die noch aktiv
   referenzierte Fremd-Datei gelöscht (erst durch Fund 1s Fix überhaupt
   ausnutzbar, aber unabhängig davon eine echte Lücke). **Fix:**
   `CHECK`-Constraint, `storage_path` muss mit `<contact_id>/` beginnen
   — exakt die Konvention, nach der der Pfad im Frontend ohnehin immer
   gebildet wird (0 betroffene Bestandszeilen, per Abfrage bestätigt).

**Zusätzliche Härtung beim Beheben von Fund 1** (kein eigener Fund,
aber naheliegend): der Trigger queued nur, wenn der Eltern-Kontakt
tatsächlich nicht mehr existiert. Verhindert, dass ein Mitarbeiter-
Offboarding (`contact_files.uploaded_by ... on delete cascade` — der
Kontakt selbst bleibt am Leben, wandert nur in den Gilden-Pool) künftig
aktiv genutzte Dateien lebender Kontakte löscht. Vorher wäre so ein
Objekt ohnehin nur "verwaist", jetzt würde es durch die neue
Warteschlange sonst tatsächlich entfernt.

**Bausteine der finalen Fassung:**

- **`contact_file_deletion_queue`** — neue Tabelle, admin-lesbar (eigene
  Organisation), kein Insert/Update/Delete für normale Clients.
- **`queue_contact_file_for_storage_cleanup()`** — `BEFORE DELETE`-
  Trigger auf `contact_files`, trägt `storage_path`+`org_id` einer
  gelöschten Zeile NUR ein, wenn `contacts` den Eltern-Kontakt nicht
  mehr enthält (echter Cascade-Waisenfall). Feuert bei Cascade- UND
  bei direkten Löschungen gleichermaßen (Postgres führt Cascade-
  Löschungen über echte `DELETE`-Befehle auf der Kind-Tabelle aus,
  Zeilen-Trigger feuern dabei normal mit) — der Kontakt-Existenz-Check
  filtert die Fälle heraus, in denen nichts zu tun ist (manuelles
  Löschen im Dateien-Reiter räumt den Speicher ohnehin bereits selbst,
  Mitarbeiter-Offboarding betrifft einen weiterhin lebenden Kontakt).
- **`contact_files_storage_path_matches_contact`** — `CHECK`-Constraint
  gegen Fund 2 (siehe oben).
- **`clear_contact_file_cleanup_queue(p_ids)`** — einzige Möglichkeit,
  Zeilen aus der Warteschlange zu entfernen, `SECURITY DEFINER`,
  admin-only, org-scoped.
- **Storage-Policies** — die beiden bestehenden Policies aus Patch 42
  bekommen den warteschlangen-verankerten Zweig gegen Fund 1 (siehe
  oben) per `ALTER POLICY` dazu, unverändert ansonsten.
- **Frontend:** `cleanupQueuedContactFilesIfAdmin()` (`index.html`,
  läuft nur für Admins, ungefragt/still im Hintergrund beim Login,
  gleiches Aufrufmuster wie `loadUnseenSecurityAlerts()`) liest die
  Warteschlange, ruft `sb.storage.remove()` mit allen ausstehenden
  Pfaden auf einmal auf, und leert über die RPC **nur** die Zeilen,
  deren Pfad `remove()` tatsächlich bestätigt hat (nicht blind alle
  angefragten) — bleibt ein Pfad aus irgendeinem Grund aus, bleibt der
  Eintrag stehen und wird beim nächsten Login erneut versucht, statt
  stillschweigend verloren zu gehen.

**Dry-Run-Verifikation vor dem Push** (gegen echte Testprofile,
`set_config('request.jwt.claim.sub', ...)` + `set role authenticated`
für RLS/RPC-Fälle, ein fingiertes `storage.objects`-Testobjekt für die
Storage-Policy-Fälle, komplett zurückgerollt): Trigger queued korrekt
NUR bei echter Cascade-Löschung über den Eltern-Kontakt, NICHT bei
einer Löschung mit weiterhin existierendem Kontakt; `CHECK`-Constraint
weist einen nicht zum Kontakt passenden `storage_path` zurück; Admin
sieht Warteschlangen-Einträge der eigenen Organisation, Nicht-Admin und
Admin einer fremden Organisation sehen keine; weder Nicht-Admin noch
Admin können die Warteschlange direkt per `DELETE` leeren (keine Policy
dafür, nur die RPC), die RPC selbst leert korrekt; die erweiterte
Storage-Policy lässt ein warteschlangen-verankertes Objekt für den
zuständigen Admin sichtbar werden, für einen fremd-org-Admin nicht.

## Chronik-Sichtbarkeit folgt der Kontakt-Freigabe

Nutzerentscheidung, klar und ohne Umweg: "keine eigene Einstellung.
automatisch. wenn man die Kontakte sehen kann, gehört die Chronik dazu."

**Vier Tabellen betroffen**, keine davon kannte vorher die
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

Verifikations-Verlauf (echte Kollegen-Accounts, nicht nur Admin):
HISTORY.md.

## Kontakt-Seite statt Popup

**Prinzip:** Kontakte brauchen echte URLs (Rechtsklick/neuer Tab muss
funktionieren) — kein JS-Popup mehr (`contactDetailModal` entfernt),
sondern eine echte Unterseite mit eigenem Hash-Pfad. Generelles Prinzip
dahinter lebt dauerhaft in Claudes Erinnerung,
`feedback_real_pages_over_modals_for_records` (Auslöser/Design-Prozess:
HISTORY.md).

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

Verifikations-Verlauf: HISTORY.md.

**Lehre, aus einer echten Layout-Nachbesserung:** eine neue `.page` muss
strukturell (nicht nur per Klassenname) im selben Container wie die
bestehenden Seiten stehen (`.content`-Wrapper), sonst greift das
Sidebar-Layout nicht — vor dem ersten Screenshot direkt gegenprüfen,
nicht erst nach Nutzer-Beschwerde (Bug-Verlauf: HISTORY.md).

## Serverseitige Schreib-Härtung: user_inventory / action_log / sales / locations

**Wiederkehrendes Muster über alle vier Tabellen** (Entstehung:
HISTORY.md): die RLS-Regel prüfte bisher nur "gehört dir die Zeile",
nicht ob der geschriebene WERT plausibel ist — dieselbe Lückenklasse
wie XSS-Lücken, nur auf der Schreib- statt der Lese-Seite.

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

**Systematischer statt zufälliger Durchgang:** alle `INSERT`/`UPDATE`-
Policies im gesamten Schema geprüft (`pg_policies`), nicht nur die
Tabellen, an die zufällig gedacht wurde (Entstehung/Verifikation:
HISTORY.md) — zwei weitere echte Funde, beide behoben:

- **`guild_members`-Selbstbeitritt** — `contacts_access`/
  `dungeons_access`/`team_rights` waren beim Selbst-Beitritt
  (`joinGuild()`) komplett ungeprüft — ein Mitglied hätte sich beim
  Beitreten sofort Schreibzugriff auf alle geteilten Kontakte/Dungeons
  UND die Nachfolge-Berechtigung selbst geben können. Fix: Selbst-
  Beitritt erzwingt die echten Minimalrechte (Lesen, kein Team-Recht) —
  außer beim Gründer der eigenen Gilde (`guildCreateBtn` setzt sich
  legitim volle Rechte, bleibt erlaubt).
- **`profiles.total_xp`/`level`** — reiner Anzeige-Cache (die Wahrheit
  bleibt immer `action_log`), war aber direkt auf einen beliebigen Wert
  überschreibbar. Fix: `sync_own_level_cache()` berechnet total_xp/level
  serverseitig aus der echten `action_log`-Summe + der echten
  Level-Kurve neu. `protect_privileged_profile_fields()` (Patch 38/39)
  hat dafür eine dritte Prüfung, erkennbar an einem Transaktions-
  lokalen Sitzungs-Flag (`app.trusted_level_sync`), das nur diese eine
  Funktion setzt — jeder andere Schreibversuch auf diese beiden Spalten
  wird blockiert. **Admin-Bypass bleibt bestehen**, wie bei
  role/character_class/org_id. `syncProfileStatsCache()` in `index.html`
  ruft `sb.rpc('sync_own_level_cache')` statt eines direkten `.update()`
  auf.

**Lehre aus einem Testing-Vorfall** (Details: HISTORY.md): vor einem
Test-Schreibvorgang auf ein Feld ohne bekannten Ausgangswert immer
zuerst den aktuellen Wert auslesen und sichern, nicht raten oder mit
`NULL` überschreiben.

## Sicherheitswarnungen (Alarm-Logging)

Löst das Problem, dass ein abgewehrter Manipulationsversuch bisher nur
dann im Fehlerprotokoll landete, wenn der **Browser** ihn freiwillig
meldete — ein direkter API-Aufruf an der Oberfläche vorbei blieb
komplett unsichtbar (Entstehung: HISTORY.md).

**Neue Tabelle `security_alerts`** (nur Admins dürfen lesen, Schreiben
ausschließlich über die neue Funktion `log_security_alert()`, die
absichtlich NICHT per RPC aufrufbar ist — siehe unten).

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

Verifikations-Verlauf: HISTORY.md.

## Questbaum: Jahres-Reset + Bonus-XP für den gesamten Baum, Patch 50

Questbaum-Stufen sind **Jahresquests**, nicht einmalige
Lebensleistungen — Geschäftsjahr = Kalenderjahr (deckt sich mit den
Jahr/Monat-Reitern im Kompendium). `evaluateLadderQuest`/
`evaluateSalesLadderQuest`/`evaluateRatioQuest`/`evaluateStreakQuest`
(in `index.html`) werten nur Ereignisse/Verkäufe des **laufenden
Kalenderjahres** aus (`currentBusinessYear()`/`logInCurrentYear()`) —
Stufen resetten automatisch zum 1. Januar, ein Streak kann strukturell
nicht über den Jahreswechsel hinweg laufen.

**Epics geben echte Bonus-XP** (nicht nur Titel + Feier-Toast):
`checkAndAwardEpics()` ruft bei neu erfülltem Epic
`grant_quest_bonus_to_self()` mit `p_stage_id = p_quest_id` auf (ein
Epic hat kein `stages`-Array, nutzt seine eigene id doppelt als
Erkennungsmerkmal — wichtig für den Schatzraum, siehe unten).
`grant_quest_bonus_to_self()` verlangt im `questtree`-Zweig zwingend
`p_period_key` (das Jahr, gleiches Prinzip wie beim `recurring`-Zweig)
und verzweigt bei `type='epic'` auf ein flaches `bonus`-Feld am Epic
selbst statt in ein `stages`-Array zu schauen. Duplikat-Schutz: pro
Stufe **und Jahr** einmal (`meta.year` zusätzlich zu `questTreeId`/
`stageId` in der Prüfung).

Aktuelle Kalibrierung: `levelBase`=6,75 (siehe "Level-/XP-System"
oben), 78 Stufen + 11 Epics mit `bonus`-Feld (15-450 XP je Stufe,
100-800 je Epic, gestaffelt nach Ladder-Länge/Position bzw. Anzahl/
Schwere der Voraussetzungen).

## Schatzraum: Reliquienkammer / Ruhmeshalle / Jagdkammer

Zeigt Vorjahres-Questbaum-Leistungen, die beim Jahres-Reset (siehe
oben) sonst spurlos aus der laufenden Questbaum-Ansicht verschwinden
würden.

- **Öffnet als Vollbild-Unterseite** (`#trophyRoomModal`,
  `.qt-fullscreen`, gleiches Muster wie `#questTreeModal` inkl.
  `history.pushState`/`popstate` — Browser-Zurück schließt nur den
  Raum), erreichbar über eine Kachel im Kompendium/Kriegskasse/
  Trophäenkammer.
- **Zeigt nur Epics** ("Trophäen"/Titel), keine einzelnen Ladder-/
  Ratio-/Streak-Stufen. Ein Epic-Bonus ist am `action_log`-Eintrag
  daran erkennbar, dass `meta.stageId === meta.questTreeId`
  (`trophyEpicInfo()` filtert danach).
- **"In Ebenen" gruppiert:** eine Sektion pro Questbaum-**Kategorie**
  (Reihenfolge folgt `config.questTree`, nur sichtbar wenn dort im
  gewählten Jahr wirklich etwas erlangt wurde), jede Trophäe eine
  goldgerahmte `.trophy-card` (🏅-Icon, Titel, Label, Datum, XP — Optik
  1:1 vom bestehenden `.epic-toast`).
- **Jahr prominent verankert:** groß und zentral, mit explizitem Tag
  "Laufendes Jahr" (grün) vs. "Archiviert" (amber). Springt beim Laden
  automatisch aufs aktuelle Jahr (`trophyRoomYear` initialisiert auf
  `new Date().getFullYear()`, Obergrenze in `trophyRoomYearBounds()`
  ist immer `currentBusinessYear()`) — kein Cron/Trigger nötig.
- Darunter: kompakte Zusammenfassung der 5 Kompendium-Kennzahlen fürs
  gewählte Jahr (`salesForYear(year)`, füttert `aggregateStats()`).
- Klassen-Namen: **Reliquienkammer** (Zauberer, 💎), **Ruhmeshalle**
  (Krieger, 🏆), **Jagdkammer** (Schütze, 🏹).

Kein neues DB-Feld/keine neue Tabelle — reine Ableitung aus bereits
vorhandenem `action_log` (das Jahr steckt seit Patch 50 in
`meta.year`) + `mySalesCache`.

## RLS-Performance-Härtung

Zwei wiederverwendbare Muster für RLS-Policy-Performance, angewendet
über praktisch das ganze Schema (reine Effizienz, keine
Verhaltensänderung — wer was sehen/bearbeiten darf, bleibt exakt
gleich):
1. `auth.uid()` wird zu `(select auth.uid())` gewrappt, damit Postgres
   es einmal pro Abfrage statt einmal pro Zeile auswertet — gilt in
   den zentralen Hilfsfunktionen (`current_org_id`/`is_admin`/
   `guild_contact_permission`/`guild_dungeon_permission`/
   `guild_founder_of_member`/`guild_leadership_permission`/
   `socially_visible`, die praktisch jede Policy im Schema nutzt) und
   in jeder Policy mit direktem `auth.uid()`-Aufruf.
2. Mehrere permissive Policies je Tabelle/Aktion werden zu einer
   einzigen zusammengelegt (USING-Klauseln per OR verknüpft, WITH
   CHECK-Klauseln separat) — mathematisch exakt dieselbe
   ODER-Verknüpfung, die Postgres bei mehreren permissiven Policies
   ohnehin bildet, nur als eine statt mehrerer Prüfungen pro Zeile.

**Bei jeder neuen Policy/Hilfsfunktion beide Muster von Anfang an
anwenden**, nicht erst nachträglich optimieren.

## Kanban-Kurzvorschau + Termin-Einladungen für Gildenmitglieder

**Kanban-Kurzvorschau** (`#kanbanPreviewModal`, `openKanbanPreview()`):
Klick auf einen Kontakt im Kanban (egal wo auf der Karte) öffnet ein
kompaktes Vorschau-Popup statt direkt zur Kontakt-Seite zu springen —
Status, aktuelle Kanban-Stufe, Berufsstatus/Betrieb, nächster Termin
(inkl. Kanal, erst beim Öffnen nachgeladen), Telefon/E-Mail,
Wiedervorlage (nur bei gewonnen/verloren/dauerbrenner sichtbar),
zuletzt kontaktiert. "Zum Profil →"-Link führt zur vollen Seite.
**Widerspricht nicht** der Grundregel "echte Seiten statt Modals für
Datensätze" (Erinnerung `feedback_real_pages_over_modals_for_records`)
— die echte Seite bleibt ein Klick entfernt, Strg/Cmd/Shift-Klick auf
den Namen-Link öffnet weiterhin einen neuen Tab über den echten `href`.

**Termin-Einladungen** (`termin_invitations`): aus der Kanban-Vorschau
heraus lässt sich ein Gildenmitglied zu einem bestehenden Termin
einladen (Vorbild: Outlooks Einladungs-/Update-Mechanik). Bewusst
zweistufig, nicht wie Outlook sofort "vorläufig" im Kalender:

1. **Einladen** (`invite_to_termin()` RPC) — Einladung erscheint beim
   Eingeladenen zunächst nur als offene Anfrage auf einer Karte
   "📨 Termin-Einladungen" (Abenteuerlog-Seite, nur sichtbar wenn
   wirklich etwas offen ist). **Noch kein Kalendereintrag.**
2. **Annehmen** (`respond_to_termin_invitation()` RPC) — erst jetzt
   entsteht eine eigene `termine`-Zeile beim Eingeladenen (`owner_id` =
   er selbst, `organizer_id` = ursprünglicher Organisator). In der
   Wochenansicht als "👥 prim. Termin von X" markiert
   (`.week-event-delegated`) und **schreibgeschützt**
   (`openTermineEntryModal()` deaktiviert Titel/Zeit-Felder und den
   Speichern-Button bei gesetztem `organizer_id`) — die Zeit wird
   ausschließlich vom Original gepflegt. Der "Löschen"-Button heißt
   für diesen Fall "Aus meinem Kalender entfernen" und läuft über den
   Antwort-RPC (Ablehnen), nicht über direktes Löschen.
3. **Verschieben mit Update-Weitergabe** — verschiebt der Organisator
   danach den Termin, fragt die App bei vorhandenen angenommenen
   Einladungen "Update an Eingeladene senden?" (`confirm()`). Bei Ja
   (`notify_termin_update()` RPC): alle angenommenen Kopien werden auf
   den neuen Stand gezogen, ihr Einladungs-Status springt zurück auf
   "offen" — der Eingeladene muss die neue Zeit erneut bestätigen.
4. **Löscht** der Organisator den Original-Termin, räumt ein
   `BEFORE DELETE`-Trigger (`cleanup_termin_invitee_copies()`) eine
   bestehende angenommene Kopie automatisch mit ab. Der Eingeladene
   bekommt dabei eine "❌ Von X abgesagt"-Meldung (Status `storniert`)
   in der Termin-Einladungen-Karte statt stillem Verschwinden, mit
   "OK"-Button zum eigenständigen Ausblenden (einzige direkte
   Client-Schreiboperation auf `termin_invitations`, rein aufräumend).
   Der Organisator sieht den Einladungs-Status an beiden Stellen, an
   denen er seinen Termin sieht (Kanban-Vorschau UND
   `termineEntryModal`) über `invitationStatusLinesHtml()`.

**Schreibrechte:** `termin_invitations` hat KEINE insert/update/delete-
Policy für normale Clients (gleiches Härtungsmuster wie "Serverseitige
Schreib-Härtung") — alles läuft über die `SECURITY DEFINER`-Funktionen
oben. Einladen ist nur innerhalb der eigenen Gilde/Freundschaft möglich
(`socially_visible()`). Eigene Titel/Zeit/Kanal/Organisator-
Schattenfelder (gepflegt bei `invite_to_termin()`/`notify_termin_
update()`), weil `termin_id` nach einer Absage `NULL` wird (`ON DELETE
SET NULL`) — ohne Schattenfelder gäbe es nach dem Löschen des
Original-Termins nichts mehr anzuzeigen.

**Bewusste Vereinfachungen dieser Fassung:**
- Serientermine + Einladung sind nicht kombiniert (nur einzelne Termine).
- Die Kopie beim Eingeladenen trägt keinen `contact_id`/`location_id`-
  Bezug (nur Titel/Zeit/Kanal).
- Kein Push-/Badge-Hinweis außerhalb der Kalender-Seite.

**Fundament für die spätere Gildenquest** (siehe
`project_questbaum_schema_design` — vierter Quest-Typ, Team-Aggregation
über eine Gilde in einem Zeitraum): liefert ein echtes "geteilter
Termin"-Signal, das ein künftiger Quest-Typ auswerten könnte (z.B.
`termin_invitations.status='angenommen'` zählen). Noch keine
Auswertungs-Logik dafür gebaut.

## Gilden-Einladung mit Annahme/Ablehnung

Gleiches Prinzip wie bei den Termin-Einladungen: eine echte
Gilden-Mitgliedschaft entsteht erst nach aktiver Annahme, nicht mehr
direkt über den Mitglied-Picker (`searchGuildCandidates()`,
Founder-Branch der `guild_members_insert_allowed`-Policy).

**Eine GETRENNTE Tabelle** (`guild_invitations`) statt eines
Status-Felds direkt an `guild_members` — Letzteres wird an sehr vielen
Stellen im Schema (Kontakt-/Dungeon-Sichtbarkeit, Chronik-Sichtbarkeit,
Notfallzugriff, Nachfolgeregelung) als "ist wirklich Mitglied, hat
Zugriff" gelesen, eine separate Einladungs-Tabelle lässt all das
unangetastet. Drei `SECURITY DEFINER`-Funktionen, kein direktes
Insert/Update/Delete auf `guild_invitations` für Clients:
- `invite_to_guild(guild_id, invited_user_id)` — nur der Gildengründer,
  nur an ein Org-Mitglied ohne bestehende Gilde. Erneutes Einladen
  nach einer Ablehnung setzt den bestehenden Datensatz wieder auf
  "offen".
- `respond_to_guild_invitation(invitation_id, accept)` — nur der
  Eingeladene selbst. Erst bei Annahme entsteht die echte
  `guild_members`-Zeile, mit denselben Minimalrechten wie beim
  Selbstbeitritt (`read`/`read`/`false`) — der Gründer passt sie danach
  über den bestehenden "Rechte"-Button an.
- `cancel_guild_invitation(invitation_id)` — Zurückziehen einer noch
  offenen Einladung durch den Einladenden.

Der bestehende **Selbst-Beitritt** über die "Gilde beitreten"-Liste
(`joinGuild()`) bleibt unverändert — betroffen war nur der
Founder-Branch. Kandidatenfilterung (`searchGuildCandidates()`) prüft
Mitgliedschaft org-weit, nicht nur in der aktuellen Gilde.

**Frontend:** Karte "📨 Gilden-Einladung" oben auf der Gilde-Seite
(`loadGuildInvitationsCard()`, gleiches Muster wie die Termin-
Einladungen-Karte, nur sichtbar wenn wirklich etwas offen ist),
wiederverwendet `.friend-req-row`/`freq-accept`/`freq-decline`. Der
Picker zeigt für bereits offen eingeladene Kandidaten "Einladung
zurückziehen" statt "Einladen". Der "+ Gildenmitglied einladen"-Button
in der Kanban-Kurzvorschau sitzt in einem eigenen
`#kanbanPreviewInviteZone`-Platzhalter am Ende der Feldliste, mit
Trennlinie abgesetzt (`.kp-invite-zone`/`.kp-invite-btn`).

## Kanban ist strikt die eigene Vertriebspipe, kein Gilden-Blick

Das Kanban ist immer die **persönliche** Vertriebspipe jedes einzelnen
Mitarbeiters — auch innerhalb einer gemeinsamen Gilde, auch für
Admins, keine Ausnahme. Die **Kontakte-Seite** (Kundendatenbank) bleibt
dagegen bewusst gilden-geteilt — Zweck der Trennung: beim Akquirieren
abgleichen können, ob ein Interessent schon bei einem Kollegen im
System steht (Dubletten-Vermeidung), ohne dass die eigene Pipeline-
Ansicht mit fremden Karten zugemüllt wird. `renderKanbanBoard()`
filtert die Gruppierung in die 8 Kanban-Spalten zusätzlich auf
`c.owner_id === profile.id`, ohne Ausnahme für Admins — die
Kontaktdaten-Sichtbarkeit selbst bleibt geteilt, nur die Kanban-
**Ansicht** grenzt zusätzlich ein.

**Gezielte Ausnahme: Termin-Einladung↔Kanban-Spiegelung.** Hat ein
eingeladener Termin (siehe "Termin-Einladungen" oben) einen
Kontaktbezug (`contact_id` als weiteres Schattenfeld auf
`termin_invitations`, bei Annahme auf die Kalenderkopie übertragen),
zeigt `renderKanbanBoard()` zusätzlich zu den eigenen Karten einen
zweiten, schreibgeschützten Kartensatz (`.kanban-card-shared`,
gestrichelter Rand, kein Zieh-Griff, kein Verschieben-Knopf) für jeden
Kontakt aus einer angenommenen Einladung — live in der Spalte, in der
der Kontakt beim Organisator tatsächlich gerade steht (derselbe
`kanban_stage`-Wert, keine eigene Kopie des Status). Statt des
Verschieben-Knopfs ein `.kc-decline-btn` ("Termin absagen"), der
dieselbe `respond_to_termin_invitation()`-Funktion aufruft wie im
Kalender — Kalendereintrag UND Kanban-Spiegelkarte verschwinden dabei
im selben Zug. Hat der Eingeladene keinen Lesezugriff auf den Kontakt
(z.B. Einladung nur über eine Freundschaft ohne gemeinsame Gilde),
liefert der Datenbank-Join schlicht nichts zurück — kein Sonderfall im
Code, RLS regelt das von allein. XP/Vertriebsstatistik bleiben
unverändert ausschließlich beim Organisator, die Spiegelkarte selbst
löst nie eine Aktion aus.

## Gildenleben: Team-Ziele + Gilden-Gebäude, Fundament

Erster Baustein des "Gildenleben"-Quest-Typs (Langfassung des Konzepts:
Claudes Erinnerung `project_gildenleben_konzept`). Bewusst noch nicht
angegangen: die echte Gebäude-Grafik (Platzhalter bleibt bis auf
Weiteres), eine Self-Service-Oberfläche für Gildenführer (kommt laut
Nutzer erst mit der großen, noch nicht angegangenen Automatisierung —
"erst das Programm so groß wie möglich schreiben, bevor wir
abstrahieren").

**Kernidee:** die Gilde bekommt eigene, verkaufsbasierte
**Jahres-Team-Ziele** (mehrere gleichzeitig, je Sparte — nicht das
eine tun ohne das andere zu lassen, z.B. Kranken UND Leben UND Sach
parallel). Erfüllung schaltet **kein XP, keinen Titel** frei, sondern
ein Bauteil eines gemeinsamen, gilden-eigenen "Gebäudes". **Wichtige
Architektur-Klarstellung:** der jährliche Reset betrifft nur, welche
Verkäufe für die *nächste offene* Stufe zählen — der Bau-Fortschritt
selbst wird **nie** zurückgesetzt, akkumuliert über die ganzen 10 Jahre
hinweg, exakt wie das individuelle Charakter-Level. Zielwerte leben
vorerst von Hand im Regelwerk (gleiches Muster wie der restliche
Questbaum).

**Datenmodell:**
- **`guild_quest_log`** — reines Anhänge-Protokoll, gleiches Prinzip
  wie `action_log`: nichts wird als Zahl gespeichert, jede erfüllte
  Team-Ziel-Stufe trägt sich als eine Zeile ein (`guild_id`,
  `quest_id`, `stage_id`, `period_key` für das Jahr). Der
  Bau-Fortschritt eines Gebäudes ist beim Anzeigen immer nur "wie
  viele Zeilen stehen für diese Gilde im Protokoll" — nie eine
  gespeicherte Zahl. Unique-Key umfasst `period_key` mit: dieselbe
  Stufe ist über mehrere Jahre hinweg mehrfach erreichbar, nur nicht
  zweimal im selben Jahr. Sichtbar für alle Mitglieder der jeweiligen
  Gilde + Admins, kein direktes Insert/Update/Delete für Clients.
- **`guild_sales_metric_total(guild_id, field, category, year)`** —
  `SECURITY DEFINER`-Aggregat-Funktion (gleiches Schutzprinzip wie
  `friend_skill_totals()`), liefert nur eine Summe zurück, nie
  Einzelverkäufe — normale `sales`-RLS zeigt nicht automatisch alle
  Verkäufe aller Gildenmitglieder. `field` ist auf eine feste
  Erlaubnisliste (`bewertungssumme`/`laufender_beitrag`) geprüft,
  `category` filtert optional auf eine Produktkategorie (NULL = alle
  zusammen). Zeitraum wie auf der persönlichen Statistik-Seite:
  `vertragsbeginn`, Fallback `datum`.
- **`grant_guild_quest_completion(guild_id, quest_id, stage_id,
  period_key)`** — trägt eine erfüllte Stufe ins Protokoll ein,
  Duplikat-geschützt über den Unique-Key (`on conflict do nothing`).
  Aufrufbar von jedem Mitglied der betroffenen Gilde — die eigentliche
  Schwellenwert-Prüfung passiert im Frontend (gleiches Muster wie bei
  den bestehenden persönlichen Quest-Prüfungen), diese Funktion
  verhindert nur doppeltes Eintragen.
- `rule_configs.config` hat zwei zusätzliche Top-Level-Schlüssel:
  `guildTeamQuests` (die Team-Ziele, bewusst flach — kein
  `stages`-Array, `stage_id` = `quest_id`, gleiche Konvention wie bei
  Epics) und `guildBuilding` (das Bau-Rezept, 4 Stufen von "Kleine
  Hütte" bis "Festung", reine Text-/Emoji-Platzhalter).

**Frontend:** `loadAndEvaluateGuildTeamQuests(guildId)` prüft UND
vergibt in einem Rutsch (ruft `guild_sales_metric_total()`, bei
Erfüllung `grant_guild_quest_completion()`). `loadGuildBuildingProgress
(guildId)` leitet den Bau-Stand rein aus der Zeilenzahl von
`guild_quest_log` für diese Gilde ab (nie eine gespeicherte Zahl,
gleiches Prinzip wie XP/Level). Gilde-Seite (Orden/Legion/Bund):
Gebäude-Karte oben (Icon + Titel + "X Teile bis zur nächsten Stufe"),
darunter Reiter Mitglieder/Freunde (`.view-switch`-Muster), darunter
Team-Ziele mit Fortschrittsbalken. Wer noch in keiner Gilde ist, sieht
weiterhin nur die eigenständige Freunde-Karte — `#friendCard` ist ein
einziges DOM-Element, das `loadGuildState()` per `appendChild()`
zwischen zwei Ankerpunkten hin- und herschiebt (`#friendCardHome`
Standardposition ohne Gilde, `#guildTabFreunde` Reiter-Inhalt bei
Mitgliedschaft) statt die Freunde-Logik zu duplizieren — verlässt man
die Gilde, landet die Karte automatisch wieder an ihrem Stammplatz.
"+ hinzufügen" (nur für den Gildenführer) sitzt innerhalb des
Mitglieder-Reiters unter dem Reiter-Umschalter, "Gilde verlassen"
(gildenweite Aktion, alle Mitglieder) am Gebäude-Header.

## Aufgaben-System: echte, abhakbare Aufgaben (Outlook-Stil), Patch 51

Ergänzt die bereits bestehenden, rein abgeleiteten Kalender-Hinweise
(`tasksForDate()`, Geburtstags-/Wiedervorlage-**Punkte/Chips** in
Monats-/Wochenansicht, siehe "Kalender-Aufgaben" oben — bleiben
unverändert bestehen, reine nicht-interaktive Vorschau) um eine
**zusätzliche**, echte Tabelle mit tatsächlicher Interaktion, sichtbar
im neuen Tag-Reiter.

**Kernentscheidung: kein "erledigt"-Zustand.** Eine Aufgabe existiert
nur, solange sie offen ist — Abhaken **löscht die Zeile direkt**
(`tasks`-Tabelle, kein `done_at`-Feld). Eine Historie erledigter
Aufgaben hat keinen praktischen Wert — wurde ein Anruf/Termin wirklich
wahrgenommen, steht das ohnehin in der Kontakt-Chronik/den Terminen.

**Datenmodell:** Tabelle `tasks` — `title`, `due_date` (nullable, kein
Pflichtfeld, wie in Outlook — eine Aufgabe ohne Datum steht im
Tag-Reiter in einem eigenen "Ohne Termin"-Block, nie überfällig/rot),
`contact_id` (optional, `on delete set null` — **Lehre:** bei
`ON DELETE SET NULL`/`CASCADE`-Fremdschlüsseln immer erst abhängige
Aufräumarbeiten durchführen, dann erst löschen, nie umgekehrt, sonst
ist die Referenz beim Aufräumen bereits weg), `source_type`
(`'manual'`/`'geburtstag'`/`'wiedervorlage'`). RLS wie bei `termine`:
rein persönlich, Admin darf lesen. Bewusst **keine** UPDATE-Policy —
Aufgaben werden nur angelegt oder gelöscht, nicht bearbeitet (Rule of
Three). Ein Unique-Index (`owner_id, contact_id, source_type,
due_date`, nur für die zwei automatischen Typen) verhindert doppelte
Geburtstags-/Wiedervorlage-Aufgaben bei überlappenden Sync-Läufen.

**Wiedervorlage-Aufgaben: synchron bei jedem Speichern von
`contacts.naechster_kontakt`.** `syncWiedervorlageTask(contactId,
contactName, newDate)` löscht die bisherige offene Wiedervorlage-
Aufgabe des Kontakts und legt bei gesetztem Datum sofort die neue an —
läuft an allen drei Stellen, an denen `naechster_kontakt` geschrieben
wird: Kontaktformular-Speichern, Kanban-Lead-Anlage am Dungeon
(`createLeadAndLogTerminVereinbart`), Wiedervorlage-Feld im
"Gewonnen"-Verkaufspopup (`recordWonSalesLoop`).

**Geburtstags-Aufgaben: täglicher Sync statt Speichervorgang.**
`syncBirthdayTasksIfNeeded()` läuft beim Login UND über einen
**Tageswechsel-Wächter** (`startTaskDayRolloverWatcher()`, prüft alle
5 Minuten UND sofort bei `visibilitychange`/`focus` — B2B-Laptops
laufen üblicherweise über Nacht durch, ein reiner Login-Check würde den
Tageswechsel bei durchgehend offenem Tab verpassen). `profiles.
tasks_synced_date` merkt sich, für welchen Tag zuletzt synchronisiert
wurde (verhindert, dass eine am selben Tag bereits abgehakte
Geburtstags-Aufgabe durch einen zweiten Sync-Lauf wiederaufersteht) —
normales, unbewachtes Profilfeld, kein Trigger-Schutz nötig. Nur eigene
Kontakte (`owner_id` = eigene ID), bewusst **keine** gilden-geteilten
Kontakte — "man würde ja nicht die Kunden seiner Gildenmitglieder
anrufen." Das Umschalten der Einstellung "Geburtstage anzeigen" setzt
`profile.tasks_synced_date` lokal zurück und erzwingt so einen
sofortigen Re-Sync, statt erst beim nächsten Tageswechsel zu greifen.

**Dritter Kalender-Reiter "Tag"** (`calViewMode` jetzt
`'monat'|'woche'|'tag'`) — Outlook-Tagesansicht: links derselbe
Zeitraster-Kalender wie die Wochenansicht (nur auf einen Tag
beschränkt), rechts die Aufgaben-Spalte (Eingabezeile oben, Liste mit
Checkbox darunter). Zurück/Heute/Vor funktionieren tagesweise. Eine
gemeinsame `calFocusDate`-Variable wird bei **jeder** Navigation (Vor/
Zurück/Heute/Doppelklick) in allen drei Ansichten aktualisiert;
`setCalViewMode()` leitet beim Reiter-Wechsel daraus `calViewYear/
calViewMonth` bzw. `calWeekStart` bzw. `calDayDate` ab, statt dass jede
Ansicht ihr Datum isoliert verwaltet — Monat/Woche/Tag zeigen dadurch
immer denselben fokussierten Tag. Doppelklick auf einen Tag in Monats-
oder Wochenansicht (`openDayView()`) springt direkt in den Tag-Reiter
mit genau diesem Tag.

**Aufgaben-Anzeige:** am **heutigen** Tag zeigt die Spalte alle offenen
Aufgaben inkl. Überfälligem (rollt automatisch mit, rot markiert) — an
**jedem anderen** Tag nur die Aufgaben, die exakt für diesen Tag fällig
sind, ohne den Überfällig-Rückstand. Aufgaben ohne Datum stehen immer
in einem eigenen Block "Ohne Termin". Ein an einem Nicht-heutigen Tag
liegender Geburtstag (der noch keine echte, tägliche Sync-Aufgabe hat)
erscheint zusätzlich als bewusst **nicht abhakbare** Vorschau-Zeile
("Geburtstag an diesem Tag (noch keine Aufgabe)", 🎂) — wird erst zur
echten, abhakbaren Aufgabe, sobald der Tag tatsächlich "heute" ist.

**Layout:** `.day-view-grid` (Kalender 65% / Aufgaben 35%, unter 760px
gestapelt). Grid-Items ohne explizites `min-width:0` respektieren per
Default ihre eigene Inhaltsbreite vor der Spaltenbreite — bei
wiederverwendeten Wochenraster-Klassen relevant, `.day-view-cal-col{
min-width:0}` verhindert das.

**Betrachteter Tag übersteht ein Neuladen der Seite:** drittes
Hash-Format `#tagebuch/<monat|woche|tag>/<YYYY-MM-DD>` neben
`#kontakt/<id>` und den einfachen Seitennamen. `updateCalendarHash()`
schreibt es bei jeder Kalender-Navigation über `history.replaceState()`
— bewusst **kein** `location.hash=...` (würde den eigenen
`hashchange`-Listener sofort erneut auslösen) und **kein** neuer
Browser-History-Eintrag pro Klick (sonst müsste "zurück" im Browser
durch jeden Vor/Zurück-Klick im Kalender zurückspulen).

## Bugfix-Konventionen: withClickGuard() + html-Tag

Entstanden aus einem systematischen, 12-teiligen Bugfix-Durchgang übers
gesamte `index.html` (57 echte Bugs gefunden und behoben, alle
SQL-Fixes live — Methodik/Einzelfunde je Häppchen: HISTORY.md). Die
Bugs fielen fast alle in eine Handvoll wiederkehrender Klassen —
fehlender Doppelklick-Schutz bei Buttons mit Datenbank-Schreiboperation,
vergessenes `escHtml()` bei neuem Rendering-Code (Stored-XSS), Async-
Race-Conditions ohne Staleness-Guard, Listener-Stacking bei
wiederholtem Init. Grund: das "Rezept" für einen neuen Button/eine neue
Render-Funktion hatte den Schutz nie strukturell eingebaut.

**Zwei verbindliche Helfer, direkt gebaut statt nur dokumentiert:**
- **`withClickGuard(btnId, handler)`** (neben `reportError`/
  `logSilentError`): umhüllt einen Klick-Handler so, dass der Button
  synchron vor dem Ausführen deaktiviert und danach garantiert (auch
  bei Exception, `finally`) wieder aktiviert wird. Nimmt bewusst die
  Button-ID statt eines Element-Verweises entgegen (bei jedem Klick
  frisch aufgelöst), damit derselbe Aufruf sowohl bei
  `addEventListener('click', ...)` als auch bei `btn.onclick=...`
  funktioniert (z.B. bei pro Modal-Öffnung neu zugewiesenen Handlern).
- **`html`/`raw()`** (neben `escHtml()`): escaping-sicheres
  Tagged-Template — jeder interpolierte Wert wird automatisch
  `escHtml()`-behandelt, außer er ist über `raw(str)` (bewusst
  vertraute, fest im Code stehende Fragmente wie Emoji/style-Attribute)
  oder als Ergebnis eines verschachtelten `html\`...\``-Aufrufs bereits
  als sicher markiert. Arrays (z.B. `${liste.map(x=>html\`...\`)}`)
  werden Element für Element behandelt und korrekt verkettet —
  **wichtig: die einzelnen Elemente nicht selbst per `.join('')` zu
  einem rohen String verketten und DEN interpolieren**, sonst greift
  die Auto-Escaping-Prüfung nicht mehr richtig.

**Verbindliche Regel ab sofort:** jeder NEUE Button, der eine
Datenbank-Schreiboperation auslöst, wird mit `withClickGuard()`
verdrahtet; jeder NEUE Rendering-Code, der Datenbank-Text per
`innerHTML` einfügt, nutzt den `html`-Tag statt roher Template-Literale
+ einzelner `escHtml()`-Aufrufe. **Bestehende, bereits einzeln gefixte
Stellen werden NICHT automatisch mitgezogen** — ein Massenumbau wäre
ein eigenes, riskantes Vorhaben ohne zusätzlichen Bugfix-Nutzen (die
sind ja schon korrekt) — bei Gelegenheit (nächster Umbau in der Nähe
einer bestehenden Stelle) kann sie mitgezogen werden, kein eigener
Rückbau-Häppchen dafür.

## Zeitzonen-Inkonsistenz `dateKeyLocal()` vs. `todayKey()`

**Kernunterscheidung, bei jedem neuen `Date`-Objekt im Kalender-/
Termin-Code gegenprüfen:** `dateKeyLocal(d)` extrahiert Jahr/Monat/Tag
über die Browser-lokalen Date-Getter — korrekt und unproblematisch für
Date-Objekte, die der eigene Code selbst rein aus Kalender-Arithmetik
konstruiert hat (Wochenraster-Iteration, `calFocusDate`/`calDayDate`,
Serientermine-Generierung — "Typ B"), aber falsch für Date-Objekte, die
aus einem echten Zeitstempel (`start_at`, `created_at`, `new Date()`
als "jetzt") geparst wurden ("Typ A") — dort hängt der extrahierte
Kalendertag vom Zeitzone des BETRACHTENDEN GERÄTS ab, nicht von der
aufgelösten Nutzer-/Org-Zeitzone, obwohl `todayKey()`/`localPartsInTZ()`
genau dafür existieren und an den meisten Stellen im Projekt (Streaks,
Aufgaben-Sync, Quests) korrekt genutzt werden.

**Helferfunktion `orgLocalNoonDay(ts)`** (neben `todayKey()`): wandelt
einen Zeitstempel in den aufgelösten Kalendertag, verankert auf 12 Uhr
mittags lokal — sichere Grundlage für nachfolgende reine Kalendertag-
Arithmetik ohne Mitternachts-/DST-Fallstricke, gleiches Muster wie
`computeRecontactDate()` für Vertrags-Nachfass-Termine.

Termin-Uhrzeit-Anzeige/-Positionierung im Zeitraster und die UTC-
Grenzen der Tag-/Wochen-Datenbankabfragen sind ebenfalls zeitzonen-
bewusst umgestellt — siehe "Zeitzonen: pro Nutzer, geräteunabhängig"
unten.

## Zeitzonen: pro Nutzer, geräteunabhängig

Jeder Nutzer hat ein eigenes, optionales Zeitzone-Feld
(`profiles.timezone`), das vor der Organisations-Zeitzone
(`organizations.timezone`, Default `Europe/Berlin`) greift — Termine
werden weiterhin als UTC-Zeitstempel gespeichert, aber jedem Nutzer in
seiner eigenen aufgelösten Zeitzone angezeigt (Modell 1:1 von
Salesforce/Outlook/Google Calendar übernommen). `tz()` liest
`profile.timezone` zuerst — das wirkt automatisch auch auf die
bestehende Kalendertag-Logik (`todayKey()`/`dateKeyLocal()`-Kette,
siehe "Zeitzonen-Inkonsistenz" oben).

**Zwei Helfer neben `todayKey()`/`localPartsInTZ()`:**
- `fullPartsInTZ(d, tz)` — wie `localPartsInTZ()`, zusätzlich Stunde/
  Minute (per `Intl.DateTimeFormat`, `hourCycle:'h23'`).
- `zonedTimeToUtc(y,m,d,hh,mm,tz)` — kehrt das um: aus Wandzeit-
  Komponenten in einer beliebigen IANA-Zeitzone den korrekten UTC-
  Zeitpunkt konstruieren (gleiches Näherungsverfahren wie Bibliotheken
  wie `date-fns-tz`, hier ohne zusätzliche Abhängigkeit direkt mit
  `Intl`-Bordmitteln umgesetzt, inkl. zweitem Durchlauf für den
  Sonderfall einer DST-Umstellung mitten in der Korrektur).

**Jeder App-weite Zeitstempel-Anzeige-/Erzeugungspfad ist umgestellt,
kein bekannter Browser-lokaler Rest offen:**
- `timeHHMM()`/`minutesSinceMidnight()` (Termin-Uhrzeit-Anzeige und
  Zeitraster-Positionierung/Drag&Drop).
- Termin-Erzeugung an allen Stellen (Haupt-Speicherdialog, Kanban-
  Lead-/Kanban-Termin-Popup, Serientermine-Generierung, "ganze Serie
  ändern") baut `start_at`/`end_at` über `zonedTimeToUtc()`.
- DB-Abfragegrenzen für Monats-/Wochen-/Tagesansicht.
- `fmtTime()` (die allgemeine App-weite "wann war das"-Anzeige —
  Kontakt-Chronik, Fehlerprotokoll, Sicherheitswarnungen, Changelog).
- Das `<input type="datetime-local">`-Feld beim Anruf/Email-Loggen
  (`contactActivityModal`) — `localDatetimeInputValue()` befüllt es
  über `fullPartsInTZ()`, der Speicher-Handler parst die Eingabe
  manuell und konstruiert den UTC-Zeitstempel über `zonedTimeToUtc()`
  statt eines naiven `new Date(zeitpunktVal)`, das den Feldtext als
  Browser-lokale Zeit interpretiert hätte.

**Neue Einstellungen-Kachel "Zeitzone"** (Gruppe Kalender): Dropdown
mit der vollen `Intl.supportedValuesOf('timeZone')`-Liste (Rückfall auf
eine kuratierte Liste gängiger Geschäfts-Zeitzonen bei älteren Browsern
ohne diese API). Leerauswahl = "Standard der Organisation verwenden",
Speichern schreibt direkt auf `profiles.timezone`.

## Idempotenz-Härtung: Duplikatschutz gegen Netzwerk-Retries

`withClickGuard()` (siehe "Bugfix-Konventionen" oben) schützt nur gegen
einen Doppelklick im selben Tab — nicht gegen einen Netzwerk-Retry
(Antwort geht verloren, Nutzer versucht es erneut), einen zweiten
offenen Tab, oder eine verzögerte zweite Anfrage. Drei serverseitige
Ergänzungen dazu, seit 2026-08-24 (Entstehung/Verifikation: HISTORY.md):

- **`grant_quest_bonus_to_self()`**: drei partielle Unique-Indizes
  (Quest+Zeitraum / Kette+Stufe / Questbaum+Stufe+Jahr) +
  `INSERT ... ON CONFLICT ... DO NOTHING` — atomar, ersetzt einen
  vorherigen "erst zählen, dann einfügen"-Ansatz mit Race-Window.
- **`log_action_for_self()`**: ein exakt identischer Aufruf (gleicher
  Nutzer/Aktions-Schlüssel/context/location/contact/meta) innerhalb der
  letzten 5 Sekunden gibt die bereits geloggte Zeile zurück statt sie
  zu duplizieren — bewusst ein Zeitfenster statt eines harten
  Unique-Constraints, da dieselbe Aktion mehrfach am Tag zu loggen der
  Normalfall ist.
- **`sales`**: `BEFORE INSERT`-Trigger
  (`prevent_duplicate_sale_submission()`), gleiches Zeitfenster-Prinzip
  — ein exakt identischer Verkauf innerhalb von 5 Sekunden wird still
  übersprungen (`RETURN NULL`) statt einen zweiten Vertrag anzulegen.

**Bewusst NICHT umgesetzt:** der Mehrfach-Produkt-Verkauf
(`recordWonSalesLoop()`) bleibt ein sequenzieller Insert pro Produkt
statt einer gebündelten Transaktion — das Retry-Risiko ist über den
`sales`-Trigger abgedeckt, mehr Atomarität wäre hier der falsche Fix.

**Im selben Aufwasch behoben:** Path Traversal beim Datei-Upload
(`contact-files`) — der Speicherpfad nutzte den rohen `file.name`
unsanitisiert. Jetzt nur noch UUID + geprüfte Dateiendung
(`/\.[A-Za-z0-9]{1,10}$/`), der Anzeigename lebt separat in
`contact_files.filename`.

## Konflikt-Schutz bei gleichzeitiger Bearbeitung (optimistisches Sperren)

Löst "wer zuletzt speichert, gewinnt ohne Warnung" — zu unterscheiden
von der Idempotenz-Härtung oben (die schützt gegen denselben Request,
nicht gegen zwei unterschiedliche echte Bearbeitungen). **Vollständig
umgesetzt und strukturell gehärtet für alle vier Tabellen mit echtem
Mehrfach-Schreiber-Risiko** — `contacts`, `locations`, `sales`,
`termine`/`termin_series` (Entstehung inkl. einer zunächst nur im
Frontend verdrahteten Zwischenfassung und deren Härtung: HISTORY.md,
[[project_optimistic_locking_enforcement_gap]]). Bewusst NICHT für
`journal_entries`/`profiles`/`products`/`organizations`/`rule_configs`/
`friends`/`guild_members` — dort kann strukturell nur eine Person je
Zeile schreiben, kein echter Bedarf.

**Technik:** jede der vier Tabellen hat `updated_at`, gepflegt von
`BEFORE UPDATE`-Triggern (`touch_contacts_updated_at()`/
`touch_updated_at()`), die JEDEN vom Client mitgeschickten Wert
ignorieren und immer `now()` setzen. **Keine RLS-UPDATE-Policy mehr auf
diesen vier Tabellen** — der einzige Schreibweg läuft über
tabellenspezifische `SECURITY DEFINER`-Funktionen, die Eigentümer-/
Admin-Prüfung + Sperr-Wert-Vergleich (`p_expected_updated_at`) in einem
Rutsch machen: `update_contact_locked()` (breite Allowlist mit den 15
Feldern, die die 8 echten Kontakt-Schreibstellen anfassen — `owner_id`/
`guild_id`/`org_id` bewusst NICHT patchbar, die ändern sich nur über
bestehende Trigger), `admit_location_to_guild_pool_locked()`/
`assign_location_owner_locked()`, `cancel_sale_locked()`,
`update_termin_locked()`/`update_termin_series_locked()`. Jede
Berechtigungs-Basis (`contacts_writable()`/`locations_writable()`/
`sales_writable()`/`termine_writable()`/`termin_series_writable()`)
prüft zusätzlich `target.org_id = current_org_id()` — fehlte anfangs bei
vier der fünf Funktionen und wurde von der neu eingeführten
Zweitmeinungs-Pflicht sofort gefunden (siehe HISTORY.md).

**Frontend-Seite:** `alertConflict(subject)` zeigt die einfache Meldung
"X wurde inzwischen von jemand anderem geändert, bitte neu laden" —
bewusst kein Zusammenführen/keine Merge-Oberfläche. Tabellenspezifische
dünne Wrapper (`updateContactWithLockCheck()`,
`admitLocationToGuildPoolLocked()`, `assignLocationOwnerLocked()`,
`cancelSaleLocked()`, `updateTerminLocked()`,
`updateTerminSeriesLocked()`) rufen alle denselben generischen
`rpcLockedUpdate()`-Kern auf. **Wichtiger Stolperstein, gilt für jeden
künftigen Aufruf einer dieser Funktionen:** PostgREST liefert einen
SQL-NULL-Rückgabewert bei einem zusammengesetzten Rückgabetyp NICHT als
JSON `null`, sondern als Objekt mit lauter `null`-Feldern
(`{id:null,...}`, "truthy" in JS) — `rpcLockedUpdate()` prüft deshalb
`!data || data.id === null`, ein reiner `!data`-Check würde den
Konflikt-Fall verpassen. Jede Schreibstelle aktualisiert nach Erfolg
auch das lokale, im Speicher gehaltene Objekt (`*.updated_at = ...`),
damit eine zweite Aktion auf demselben Objekt in derselben Sitzung
nicht sofort fälschlich in einen Selbst-Konflikt läuft.

**Verbindliche Regel für neuen Code, ab jetzt:** wer eine dieser vier
Tabellen beschreibt, ruft eine der obigen Locked-Funktionen per
`sb.rpc(...)` auf — ein direktes `sb.from(...).update(...)` schlägt mit
einem RLS-Fehler fehl (keine Policy mehr dafür), genau wie bei
`action_log`/`user_inventory`.

## DSGVO-Vorbereitung: Einwilligung + automatische Löschung inaktiver Kontakte

Erster technischer Baustein aus Phase 1 des Business-Fahrplans
(rechtliche Grundlage vor dem ersten echten Kunden) — Entwürfe für
Datenschutzerklärung/VVT liegen unter `businessvorbereitung/` (Repo,
nicht im Erinnerungssystem, da es sich um echte Arbeitsprodukte
handelt, keine Geschäftsstrategie).

**Einwilligungs-Häkchen** (`contacts.consent_obtained`, boolean, Default
`false`): bewusst einfaches Ja/Nein ohne Datum/Zweckangabe
(Nutzerentscheidung — gleiche Praxis wie beim bestehenden AXA-Vertrieb
des Nutzers), im Kontaktformular (Anlegen + Bearbeiten) sowie im
Übersicht-Reiter sichtbar. Läuft wie alle Kontakt-Schreibvorgänge über
`update_contact_locked()`.

**Automatische Löschung** (`auto_delete_inactive_contacts()`, täglicher
pg_cron-Lauf 03:17 UTC): löscht Kontakte ohne jemals gewonnenen Vertrag,
deren letzte erkennbare Aktivität (Anlage, letzte Bearbeitung,
Wiedervorlage-Datum, letzter Anruf/E-Mail, letzter Termin, letzte
geloggte Aktion, letzter Datei-Upload — das Späteste aus allen zählt)
länger als die pro Organisation konfigurierte Frist zurückliegt
(`rule_configs.config.contactAutoDelete: {enabled, monthsInactive}`,
Standard beim Nutzer selbst: 6 Monate — **Standard bei neuen
Organisationen bewusst `enabled: false`**, muss aktiv scharf geschaltet
werden). **Kontakte mit irgendeinem jemals gewonnenen Vertrag (auch
längst gekündigt) sind komplett ausgenommen** — eine Kaskaden-Löschung
würde sonst rückwirkend Kompendium-/Schatzraum-Zahlen vergangener Jahre
verändern, und echte Ex-Kunden haben typischerweise eine
handelsrechtliche Aufbewahrungspflicht (§257 HGB), die einer Löschung
ohnehin entgegenstünde. **Für diesen Fall ist der eigentlich richtige,
noch nicht gebaute Mechanismus eine "Einschränkung der Verarbeitung"
statt Löschung (Art. 18 DSGVO, umgangssprachlich Sperrvermerk)** — Daten
bleiben bestehen, werden aber für den Alltagsbetrieb unsichtbar/nur noch
für Admins zu Nachweiszwecken einsehbar, erst nach Ablauf der echten
gesetzlichen Frist (6–10 Jahre) tatsächlich gelöscht. Bewusst noch nicht
gebaut, eigener, größerer Baustein — bei Bedarf anstoßen.

Jeder Lauf protokolliert nur die Anzahl gelöschter Kontakte pro
Organisation (`contact_auto_delete_log`, admin-lesbar, keine
personenbezogenen Daten) — reine Nachweisbarkeit, dass der Mechanismus
zuverlässig läuft. Entstehung/Verifikation (zwei Runden unabhängiger
Zweitmeinung fanden echte Logikfehler der jeweiligen Vorfassung):
HISTORY.md.

## Sonderquest-Hinweise: automatisiertes Erkennungssystem

Erster Baustein, der auf der automatischen Kontakt-Löschung (siehe oben)
aufsetzt statt sie nur zu protokollieren: 1 Monat bevor ein eigener
Kontakt ohne jemals gewonnenen Vertrag automatisch gelöscht wird,
erscheint in den täglichen Quests (`#page-handlungen`) eine zusätzliche
Kachel "Sonderquest — Vorname Nachname kontaktieren", Rahmen dezent in
der Klassenfarbe (`--arcane`) hervorgehoben, Löschdatum als Unterzeile.
Jede betroffene eigene Person bekommt das für ihre eigenen Kontakte,
nicht nur eine Ansicht für Admins.

**Optik:** dieselbe drei-Zeilen-Struktur (Kategorie/Name, Balken,
Fußzeile) wie jede normale Tages-Quest-Kachel — der Fortschrittsbalken
zeigt einen Countdown der verbleibenden Tage bis zur Löschung (voll bei
30 Tagen Vorlauf, leer am Fälligkeitstag, in der Klassenfarbe), die
Fußzeile zeigt statt einer XP-Zahl "🛡️ Kontakt retten" (Entstehung/
Optik-Korrektur: HISTORY.md).

**Datenquelle:** `contacts_pending_deletion_for_self()`, eine reine
Lese-`SECURITY DEFINER`-Funktion, fest auf `auth.uid()` verdrahtet.
Spiegelt exakt denselben Aktivitäts-Anker wie
`auto_delete_inactive_contacts()` — **bei künftigen Änderungen an diesem
Anker beide Funktionen anfassen**, sonst laufen Warnung und tatsächliche
Löschung auseinander. Fenster: `deletion_date` liegt zwischen heute
(inklusive) und heute+30 Tage.

**Bewusst kein Extra-XP-Bonus fürs Retten** — die normale Aktions-XP,
mit der der Kontakt berührt wird, reicht als Belohnung. **Kein
"erledigt"-Feld nötig**: sobald der Kontakt wieder angefasst wird, rückt
sein Aktivitäts-Anker vor, die Kachel verschwindet beim nächsten Laden
von selbst. Geladen einmal pro Login (`enterApp()`) und zusätzlich bei
jedem Öffnen der Handlungen-Seite, bewusst NICHT nach jeder einzelnen
Aktion neu abgefragt.

**Frontend bewusst generisch gehalten** (`specialQuestItems`/
`specialQuestTilesHtml()`, neben `renderDailyQuestTiles()`): ein
künftiger zweiter Hinweistyp reiht seine Einträge einfach in dasselbe
Array ein, ohne die Render-Logik anzufassen. **Schwellenwert für eine
echte Verallgemeinerung (Rule of Three):** solange es nur diesen einen
Hinweistyp gibt, bleibt das Backend eine eigene, schmale Funktion (wie
`log_action_for_self`/`grant_quest_bonus_to_self`/
`friend_skill_totals`) — erst beim DRITTEN Sonderquest-Hinweistyp lohnt
sich ein gemeinsames Backend-Muster.

## Bekannte, bewusst in Kauf genommene Lücken

- ~~Dateien in `contact-files` überleben die automatische Kontakt-
  Löschung~~ — **behoben, 2026-08-26**, siehe eigener Abschnitt
  "Storage-Aufräum-Warteschlange für gelöschte Kontakt-Dateien" unten.
- ~~"Zuletzt kontaktiert"/Kontakt-Chronik zeigen nur eigene Einträge~~ —
  **behoben, Patch 45, 2026-08-10**, siehe eigener Abschnitt "Chronik-
  Sichtbarkeit folgt der Kontakt-Freigabe". "Zuletzt kontaktiert (von
  dir)" bleibt bewusst weiterhin eigentümerbezogen (so gekennzeichnet).
- ~~Zwei kleine Unschärfen bei den Termin-Einladungen~~ — **behoben,
  2026-08-19** (Details/Verifikation: HISTORY.md). Organisator sieht
  seine stornierte Einladung über `organizer_id`, direktes Löschen der
  Einladungs-Kopie durch den Eingeladenen ist RLS-blockiert (nur noch
  über `respond_to_termin_invitation()` möglich).
- Kein automatisiertes Testen — der Nutzer testet manuell selbst
  (Safari/iPhone + Brave/Desktop). **Team ist inzwischen auf 7 echte
  Profile gewachsen** (Stand 2026-08-15, per SQL bestätigt — ursprünglich
  waren hier nur "zwei Kollegen" dokumentiert), CI/CD-Schwelle aus
  "Technische Skalierungs-Schwellen" oben (mehrere Personen bearbeiten
  das Repo gleichzeitig) betrifft weiterhin nur Code-Bearbeitung, nicht
  App-Nutzung — bleibt also unverändert nicht ausgelöst.
- ~~Kein Konflikt-Schutz bei gleichzeitiger Bearbeitung~~ — **komplett
  behoben, 2026-08-23/24**, für alle vier Tabellen mit echtem Mehrfach-
  Schreiber-Risiko (`contacts`, `locations`, `sales`, `termine`/
  `termin_series`), siehe eigener Abschnitt "Konflikt-Schutz bei
  gleichzeitiger Bearbeitung" oben. Kein offener Punkt mehr in diesem
  Strang.

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
  **Ergänzung, 2026-08-23:** vor jedem Push laufen zusätzlich automatisch
  beide Regressions-Skripte (`regression_suite.mjs` +
  `regression_suite_member.mjs`, siehe Tech-Stack-Abschnitt
  "Regressions-Suite" oben) — ebenfalls ohne vorher zu fragen. Schlägt
  dabei ein Test fehl, nicht einfach pushen, sondern den Fund erst kurz
  melden.
