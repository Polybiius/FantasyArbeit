# Verlaufsprotokoll: Vertriebs-Quest

Dieses Dokument ist das chronologische Gegenstück zu `CLAUDE.md`.
**CLAUDE.md** beschreibt den aktuellen Zustand des Projekts (Referenz,
wird bei Änderungen ersetzt) — **hier** steht die Geschichte, wie dieser
Zustand entstanden ist: Baustorys, Debugging-Verläufe, Verifikations-
Details, Nutzer-Zitate, Commit-Hashes, konkrete Zwischenschritte.

**Wird von Claude Code NICHT automatisch geladen** (anders als
CLAUDE.md) — nur gezielt lesen, wenn eine Session tatsächlich
nachvollziehen muss, *wie/wann/warum* etwas entstanden ist, nicht für
den normalen Arbeitsalltag.

**Schreibregeln:**
- Append-only, chronologisch (älteste Einträge oben). Bestehende
  Einträge werden nicht rückwirkend umgeschrieben (Ausnahme:
  Tippfehler-Korrekturen).
- Jeder Eintrag mit Datum/Thema als Überschrift.
- Darf ausführlich sein — das ist explizit der Ort dafür.
- Wechselt eine Regel/ein Verhalten sich in CLAUDE.md, wird das NICHT
  hier nochmal als "aktueller Stand" wiederholt — nur die Änderung
  selbst (was war, was wurde draus, warum) gehört hierher.

**Verwandte, aber eigenständige Archive:** `sql/PATCH_LOG.md` (nur die
alten SQL-Patches 1–39, eingefroren, kein Teil dieser Datei). Claudes
privates Erinnerungssystem (`memory/`, nicht im Repo) verweist ab jetzt
auf Einträge hier, statt Ereignisse ein drittes Mal nachzuerzählen.

---

## 2026-08-22: CLAUDE.md/HISTORY.md-Trennung begonnen

CLAUDE.md war auf 5.008 Zeilen gewachsen — wird komplett bei jeder
Session geladen (eigener Auftrag ganz oben: "Lies es vollständig").
Auslöser: Nutzerfrage "was hälst du von unserer CLAUDE.md", direkt nach
Abschluss des 12-teiligen Bugfix-Durchgangs (57 Bugs, siehe unten).
Konkreter Stale-Fund als Beleg: die Datei behauptete `escHtml()` sei
"ganz oben im Skript" definiert, lag tatsächlich bei Zeile ~7150.
Nutzer bestätigte das Problem und bat um exakte Leitplanken für eine
saubere Zwei-Dokumente-Trennung.

**Guardrails, gemeinsam entworfen:** Drei-Ebenen-Modell (CLAUDE.md =
Referenz/evergreen, HISTORY.md = Verlauf/append-only, Claudes
Erinnerungssystem = unverändert), Klassifikations-Test ("braucht eine
künftige Session das JETZT, um weiterzubauen — unabhängig davon,
wann/warum es entstand?"), Zielgröße für CLAUDE.md ehrlich hergeleitet
auf ~2.235 Zeilen (Kategorien-Aufschlüsselung, nicht die ursprüngliche,
zu niedrig gegriffene 1.500er-Schätzung). Migration in Häppchen wie der
Bugfix-Durchgang, um das Kontingent zu schonen. Vollständiger Plan lag
zwischen den Sitzungen in Claudes Erinnerung (`project_claude_md_
history_split`) bereit, bis zum tatsächlichen Start hier.

**Häppchen 1 (Grundidee bis Sicherheitsmodell/Level-System/Sigil,
ursprünglich CLAUDE.md-Zeile 1–573):** erster Durchgang, wenig
Trennarbeit nötig (dieser Bereich war schon vorher fast reine
Referenz). Konkrete Funde/Verschiebungen hierher:

- **Datenbank-Abschnitts-Kopfzeile war stale:** hieß "Datenbank —
  aktueller Stand (Annahme: Patch 1–25 eingespielt)" — diese Annahme
  war seit Langem überholt (die Tabellenliste selbst dokumentierte
  längst Features bis Patch 51/Migrationen 2026-08-22). In CLAUDE.md
  auf reine "Datenbank — aktueller Stand" ohne Patch-Zahl-Anker
  korrigiert.
- **"Wichtig zu Patch 25"-Absatz** (CLAUDE.md, alter Datenbank-
  Abschnitt): beschrieb die alte, längst abgelöste Regel "SQL-Patches
  werden künftig erst nach explizitem Go ausgeführt" — bezog sich auf
  den manuellen `sql/patchN.sql`-Workflow, der seit der
  Supabase-CLI-Migrationstoolchain (2026-08-08) nicht mehr genutzt
  wird. Die äquivalente, aktuell gültige Regel ("Claude Code führt
  `supabase db push` immer erst nach explizitem Go aus") stand ohnehin
  schon separat im CLI-Abschnitt — der alte Absatz war damit
  redundant/veraltet, komplett hierher verschoben statt in CLAUDE.md zu
  bleiben.
- **Supabase-CLI-Migrationstoolchain, Entstehungsgeschichte:** löste das
  in CLAUDE.md selbst lange angekündigte Ziel ein ("dieses Muster
  beibehalten, bis eine echte Migrations-Toolchain eingeführt wird") —
  auf Nutzerwunsch eingerichtet, nachdem die Dashboard-Warnung
  `42P01: relation "supabase_migrations.schema_migrations" does not
  exist` den Anstoß gab.
  - Setup: Supabase-CLI als normale Dev-Abhängigkeit im `package.json`
    (bewusst NICHT wie Playwright als separates portables Tool außerhalb
    des Repos, weil dies echtes Projekt-Werkzeug ist). Projekt per
    `supabase link --project-ref aaqbbkcghxldsbhqwcyh` verknüpft. Login
    lief einmalig über `supabase login` im echten Terminal des Nutzers
    (Browser-OAuth) — der lokal gespeicherte Zugang wird von der
    Claude-Code-Sandbox automatisch mitverwendet, kein Token wurde je
    durch den Chat geschickt.
  - Baseline: der komplette bisherige DB-Stand (20 Tabellen, Patch
    1–39) wurde per `supabase db pull` einmalig als erste Migration
    eingefroren (`supabase/migrations/20260808145403_remote_schema.sql`),
    "Update remote migration history table?" mit Ja bestätigt — behebt
    dabei die eingangs erwähnte Dashboard-Warnung.
  - Stolperstein: `supabase db pull`/`db diff` brauchen im Hintergrund
    Docker (lokale Schatten-Datenbank), das ist in der Claude-Code-
    Sandbox (VS-Code-Flatpak) nicht erreichbar, selbst wenn Docker/
    Podman auf dem eigentlichen System läuft. Der Nutzer hat deshalb den
    einmaligen `db pull` in seinem eigenen echten Terminal ausgeführt
    (dort Docker 29.6.2 + Podman 5.8.4 vorhanden). `supabase db push`
    braucht dagegen KEIN Docker (nur eine direkte Postgres-Verbindung) —
    funktioniert deshalb direkt aus der Sandbox heraus, per Testmigration
    verifiziert (`20260808150221_claude_push_test.sql`, folgenlos, nur
    `SELECT 1`).
- **Radius-/Schatten-System (seit 2026-08-02):** vorher liefen
  `border-radius` auf 9 verschiedenen unsystematischen Werten und
  Schatten fast nirgends außer bei den Dungeon-Kacheln, bis die
  einheitlichen CSS-Variablen eingeführt wurden (siehe CLAUDE.md für die
  aktuellen Werte/die Regel, neue Elemente sollen sie weiterverwenden).
- **Regressions-Suite, Erweiterungs-Anstoß (2026-08-20):** Nutzerfrage
  "hast du alle Funktionen getestet, oder nur die von heute" machte den
  damaligen Umfang (nur drei Kernpfade) sichtbar zu schmal — besonders
  bei Änderungen an zentralen, überall mitgenutzten Stellen (z.B.
  `showPage()`/`routeToHash()`/`initJournal()`, wie beim Aufgaben-
  System-Umbau am selben Tag). Der Ausbau-Wunsch selbst steht als
  offener Punkt weiterhin in CLAUDE.md/der Roadmap-Erinnerung.
- **Bisheriger Arbeits-Workflow, vor Claude Code:** der Nutzer hat
  ursprünglich NICHT lokal mit Git gearbeitet, sondern jede neue
  `index.html`-Version über den GitHub-Web-Upload hochgeladen und jeden
  SQL-Patch manuell im Supabase SQL-Editor ausgeführt. Das änderte sich
  mit Claude Code: Commits/Pushes laufen seit 2026-07-31 automatisch
  (GitHub Personal Access Token im `credential.helper store` des
  Nutzers, dadurch kein `ksshaskpass`-Problem mehr — anfangs, vor
  diesem Fix, scheiterte automatisches Pushen genau daran).
- **Frontend-Framework-Frage, geklärt am 2026-08-03:** die "eine
  `index.html`, kein Framework"-Linie war ursprünglich eine praktische
  Zwangslage aus der Zeit vor Claude Code (Copy-Paste in GitHubs
  Web-Upload), keine Grundsatzentscheidung. Der Nutzer wollte dabei
  ausdrücklich groß denken: viele B2B-Kunden werden künftig
  unterschiedliche Bausteine brauchen (Kanban, Kundendatenbank,
  Gamification, Statistik, Tagebuch, Dungeon, Questbaum). Wichtige an
  diesem Tag herausgearbeitete Klarstellung: Konfigurierbarkeit (welche
  Bausteine sind je Organisation aktiv) ist eine andere Frage als
  "Framework oder nicht" — ein Framework schaltet keine Module für
  Kunde A ab und für Kunde B an, das bleibt so oder so Config-Arbeit.
  Baseline-Messung an diesem Tag (inzwischen weit überholt): `index.html`
  3.845 Zeilen/208 KB, 139 benannte Funktionen, `.contact-card`-Markup
  real nur an EINER Stelle verwendet — damals noch kein echtes
  Duplikations-Problem. Die vier daraus abgeleiteten Alarmglocken-
  Schwellen stehen weiterhin aktuell in CLAUDE.md.
- **Technische Skalierungs-Schwellen, Festlegung am 2026-08-04:** auf
  ausdrücklichen Nutzerwunsch, nach einer Diskussion über einen "Vibe
  Coding"-Kritik-Post (Buzzword-Liste: Kubernetes, Docker, S3, SQS,
  CI/CD, Terraform, Rate Limiting, Load Balancer, High Availability,
  RPC, u.a.) — Ziel war, dasselbe Prinzip wie bei der Frontend-
  Framework-Schwelle (konkrete, prüfbare Auslöser statt vagem
  "irgendwann später") auch auf die übrige Infrastruktur auszuweiten.
- **Vollständige geräteunabhängige Zeitraster-Engine — Kurswechsel bei
  einer eigenen Schwelle:** ursprünglich als Zukunfts-Schwelle mit
  explizitem Auslöser ("erst wenn ein Teammitglied real reist/aus einer
  anderen Zeitzone arbeitet") vermerkt. Der Nutzer hat sich nach kurzer
  Rückfrage bewusst dagegen entschieden zu warten und sie am 2026-08-21
  direkt gebaut (siehe eigener Abschnitt in CLAUDE.md für die Technik) —
  Begründung: die Engine wird laufend weiter ausgebaut (jedes neue
  Kalender-Feature vergrößert später den Umstellungs-Umfang), es gab
  noch keine echten Produktions-Nutzer (nur Tester), und die Anforderung
  war durch eine Salesforce-Nachfrage klar genug. **Lehre, die als
  generelles Prinzip in CLAUDE.md übernommen wurde:** eine dokumentierte
  "warten auf Auslöser"-Schwelle ist kein Dogma — wenn sich die
  zugrundeliegenden Annahmen als falsch herausstellen, lohnt sich ein
  zweites Nachfragen statt starres Festhalten.
- **Größte Level-Kurven-Neukalibrierung, Patch 50 (2026-08-17), volle
  Methodik:** alle 76 Questbaum-Stufen + 11 Epics bekamen ein
  `bonus`-Feld, gleichzeitig wurde klargestellt, dass Questbaum-Stufen
  Jahresquests sind (Geschäftsjahr = Kalenderjahr) — dieselbe Stufe ist
  damit pro Jahr einmal, aber über mehrere Jahre hinweg mehrfach
  verdienbar. Weil das reale zusätzliches Lebenszeit-XP bedeutet (nicht
  nur eine Verschiebung wie bei der Krankenhaus-Meister-Migration),
  stieg `levelBase` von 4,70 auf 5,80 (+23,3% Gesamt-XP bis Level 100:
  185.656→228.876). Methodik-Detail: pro Stufe wurde geschätzt, in wie
  vielen der 10 Jahre eine konstant gute Person sie realistisch erreicht
  (Einstiegsstufe ~9-10/10, Top-Stufe ~1-2/10), diese erwarteten
  Lebenszeit-Summen wurden zur Gesamt-Zielsumme addiert, dann `levelBase`
  neu gelöst.

**Häppchen 2 (Charakterklassen bis Kanban, ursprünglich CLAUDE.md-Zeile
510–869), fertig 2026-08-22.** Deutlich mehr Trennarbeit als Häppchen 1
— besonders "Profil-Onboarding" und "Aussehen-Screen" bestanden zu
einem großen Teil aus reinen "Entstehungsweg"-Erzählungen.

- **Umbenennung "Hexer" → "Zauberer" (Patch 29, 2026-08-03):** es gibt
  keine "Hexerin" — die einzige echte weibliche Form wäre "Hexe", und
  die ist negativ konnotiert. Deshalb komplett auf Zauberer/Zauberin
  umbenannt, nicht nur der Anzeige-Text, sondern auch der interne
  Schlüssel (`profiles.character_class`, Item-Keys `hexer_stab`/
  `hexer_cape` → `zauberer_stab`/`zauberer_cape` samt Bilddateien) —
  siehe `sql/patch29_zauberer_umbenennung.sql`. Historische Verweise auf
  den alten Namen in älteren Abschnitten dieses Dokuments (z.B. längst
  gelöschte Dateien wie `hexer_m.png`) sind bewusst unverändert
  gelassen, sie beschreiben, wie etwas zum jeweiligen Zeitpunkt hieß.
- **Verkaufsstatistik-Seite, Status am 2026-08-03:** damals noch ein
  leerer Seiten-Rahmen, "die eigentlichen Verkaufsstatistiken sind ein
  separater, noch offener Bauschritt" — **inzwischen überholt** (der
  Stale-Fund wurde beim Migrieren bemerkt und in CLAUDE.md korrigiert):
  das Dashboard wurde am selben Tag noch fertig gebaut (KPI-Kacheln mit
  Fortschrittsringen, Kategorie-Balkendiagramm, Sparklines — siehe
  CLAUDE.md, Abschnitt "Bewusst aufgeschobene Ideen" → BWS-Verrechnung),
  die alte "noch offen"-Formulierung stand nur versehentlich seitdem
  unverändert im Charakterklassen-Abschnitt.
- **Profil-Onboarding, Entstehungsweg:** die komplette Änderung
  (Profil-Screen mit echtem Name/Geschlecht/Unternehmen/Charaktername)
  wurde zuerst in einer separaten, nicht versionierten Datei
  `dummy-anmeldung.html` (Projekt-Root, lokal, nicht committed)
  durchgespielt und optisch geprüft, bevor sie ins echte `index.html`
  übertragen wurde. Grund war NICHT Risiko-Minimierung, sondern
  Sichtbarkeit: der Nutzer hatte längst ein eigenes Profil und konnte
  Anmelde-/Charaktererstellungs-Bildschirme im echten Programm gar
  nicht mehr erreichen, um Änderungen zu begutachten. Dieses Muster
  lohnt sich gezielt für Bildschirme, die nur einmalig VOR einem
  bestimmten Zustand erscheinen (Erstanmeldung, Ersteinrichtung) — nicht
  pauschal für jede riskante Änderung an normal erreichbaren Seiten
  (die Lehre daraus lebt dauerhaft in Claudes Erinnerung,
  `feedback_dummy_first_prototyping`, nicht nur hier).
  `dummy-anmeldung.html` wurde seit 2026-08-03 wieder gelöscht: der
  Admin-Knopf "🎭 Neu erschaffen" (Commit `0a27220`) schließt seitdem
  dieselbe Sichtbarkeits-Lücke strukturell und dauerhaft (springt für
  Admins zurück auf `profileScreen` → `charCreateScreen` →
  `appearanceScreen`, aktualisiert am Ende das bestehende Profil statt
  ein neues anzulegen) — der Nutzer kann sich seitdem jede künftige
  Änderung an diesen drei Screens direkt im echten, laufenden Programm
  ansehen. **Lehre:** bevor eine neue Dummy-Datei für ein "unerreichbar
  gewordenes" Onboarding-Bildschirm gebaut wird, erst prüfen, ob ein
  kleiner, dauerhafter Admin-Debug-Zugang (wie dieser Knopf) die
  Sichtbarkeits-Lücke nicht direkter und dauerhaft schließt.
- **Aussehen-Screen, Entstehung der Canvas-Animation:** ursprünglich
  `<img>`-Ebenen übereinandergelegt, dann (2026-08-03, zweite
  Überarbeitung) durch ein `<canvas>` ersetzt, das jeden Frame per
  `drawImage()` aus den Ebenen-Sheets neu zusammensetzt — der Nutzer
  wollte explizit keine statischen Einzelbilder ("wir wollten ja ein
  dynamisches Charakterscreen") und dass der Charakter sichtbar auf der
  Stelle läuft statt (wie bei einem ersten, verworfenen CSS-`steps()`-
  Versuch) unsauber zu wirken (generelle Lehre dazu lebt in
  `feedback_dynamic_over_static_rendering`).
- **`Design/`-Sandkasten, Aufräumen am 2026-08-03:** alle Wegwerf-
  Vorschau-/Entscheidungswerkzeuge aus der Bau-Phase gelöscht, nachdem
  ihre Ergebnisse ins echte Produkt übernommen waren — `gallery.html` +
  `thumbs/` (Asset-Katalog), `concept.html` + `concept/` (Klassen-
  Outfit-Composites), `anim_demo.html` + `anim/` (erster, verworfener
  CSS-Animationsversuch), `hair_review.html` + `hair_thumbs/`
  (Frisuren-Farbsichtung), `canvas_test.html` (Debug beim Animations-
  Bug), `creator_catalog.json`, sowie die Erzeuger-Skripte
  `compose_concept.py`/`export_outfit_layers.py`/`export_walk_anim.py`/
  `make_thumbs.py`. Ebenfalls entfernt: die frühere Zwischenstufe
  `export_outfit_layers.py` (eng zugeschnittene Basis-Kleidung/
  Klassenitem-Bilder unter `creator/outfit_*`), mit dem Canvas-Umbau
  überflüssig geworden, sowie die sechs statischen
  `img/characters/{hexer,krieger,schuetze}_{m,w}.png` von der ersten
  Klassenwahl-Bildschirm-Version — beides durch die Canvas-Animation
  ersetzt. Aktueller Stand von `Design/` (was übrig bleibt/warum): siehe
  CLAUDE.md.

**Häppchen 3 (Produktkatalog & Verkaufshistorie bis Einstellungen,
ursprünglich CLAUDE.md-Zeile 818–1063), fertig 2026-08-22.** Produktkatalog
und Kontakt-Chronik waren schon vorher lean (Business-Regeln, kaum
Erzählung) — der Hauptfund war der Einstellungen-Abschnitt.

- **Einstellungen-Registry, Entstehung (2026-08-07):** umgebaut auf
  Nutzerwunsch ("ich möchte mir dir heute eine grundidee ein fundament
  für die einstellungen gießen"), bevor die Seite über die bisher 3
  Themen-Kacheln hinauswuchs — Auslöser war ein vom Nutzer gesehenes
  Video mit einer als vorbildlich empfundenen Einstellungen-UX, aus der
  er Stichworte mitbrachte (instant-apply Toggles, Save-Bar bei
  Identitätsfeldern, Gruppierung statt langer Liste, Advanced-Klappe,
  Suche mit Highlighting, Modified-Badge, Undo, Danger Zone). Der
  Nutzer verstand das Registry-Prinzip trotz zweier Erklärversuche
  nicht wirklich — gab aber grünes Licht, nachdem klar war, dass es
  Industriestandard ist ("wenn das best practice ist ... dann bitte").
  Generelle Lehre daraus lebt dauerhaft in Claudes Erinnerung,
  `feedback_defer_to_best_practice_when_confused`, nicht nur hier.
- **Zwei Nachbesserungen, noch am selben Tag (2026-08-07), Entstehung:**
  1. Optik-Politur: native Checkboxen/zu schmale Eingabefelder/
     Monospace-Fließtext wirkten laut Nutzer "klobig" — ersetzt durch
     den heutigen Pill-Schalter/volle-Breite-Inputs/normale Fließschrift
     (aktueller Stand: CLAUDE.md).
  2. Startseite von Balken auf Kacheln umgebaut: die anfängliche
     Gruppen-Übersicht (4 volle-Breite aufklappbare Balken) fühlte sich
     laut Nutzer nicht stimmig an ("diese großen Rechtecke... ist nicht
     meins") — passte auch nicht ins sonstige Kachel-Vokabular der App
     (Dungeons, Gilde, Inventar, Produkte laufen alle über
     `.dungeon-tile-grid`/`.dungeon-tile`, "Kachel statt Liste" war
     schon beim Produktkatalog ausdrücklicher Nutzerwunsch, 2026-08-03).
     Heutiger Stand (Kachel-Grid, Klick öffnet Gruppen-Modal): CLAUDE.md.

## 2026-08-07/2026-08-11: Sicherheits-Durchgänge (XSS-Escaping, RLS, Advisor)

**Häppchen 4 (Sicherheits-Durchgang XSS-Escaping + Advisor-Nachtrag,
ursprünglich CLAUDE.md-Zeile 1038–1214), fertig 2026-08-22.** Größter
Trennaufwand-Gewinn bisher — beide Abschnitte waren fast komplett reine,
datierte Audit-Berichte. CLAUDE.md behält nur die daraus abgeleiteten,
dauerhaften Prinzipien/Werkzeuge (Escaping-Regel, RLS-Design-Prinzip,
`supabase db advisors`-Befehl, Feldlängen-Konvention) — hier die
vollständigen Audit-Verläufe:

**Sicherheits-Durchgang 2026-08-07** (auf Nutzeranfrage "codebasescan
für key tokens api ... full security audit" — zwei getrennte Prüfungen
gemacht statt vorschnell Infrastruktur zu bauen, die laut den
"Technische Skalierungs-Schwellen" noch nicht gebraucht wird):

1. **Secret-Scan** (`grep -r` nach Service-Role-/Private-/API-Key-
   Mustern übers ganze Repo): sauber. Der einzige Key im Code ist der
   Supabase-Anon-Key (absichtlich öffentlich, RLS statt Geheimhaltung).
2. **XSS-Escaping-Lücke, echt und verbreitet gefunden und behoben:**
   `escHtml()` wurde an sehr vielen Stellen, an denen Datenbank-Text
   per `innerHTML` gerendert wird, schlicht vergessen — betraf u.a. den
   zentralen `field()`-Helfer in der Kontaktdetail-Ansicht (Telefon/
   E-Mail/Wohnort/Bedarf-Ist/-Wunsch/Notizen auf einen Schlag), die
   Kontakttabelle, Kanban-Karten, die Handlungen/Chronik-Listen
   (`action_log.context`), Anruf/Email-Notizen, Termin-Titel, Gilden-/
   Freundes-Namen, zwei ältere Autocomplete-Boxen und mehr (~20 Stellen
   insgesamt). Ein böswillig benannter Kontakt (z.B. Vorname
   `<img src=x onerror="...">`) hätte beim Anzeigen durch jedes
   Team-Mitglied ausgeführt werden können — echte, ausnutzbare
   Stored-XSS-Lücke. `escHtml()` selbst war zusätzlich unvollständig
   (escapte kein `"`/`'`, dadurch in Attribut-Kontexten wie
   `data-name="${...}"` weiterhin ausbrechbar) — seitdem escapt es auch
   Anführungszeichen. Per Playwright end-to-end verifiziert: echter
   Testkontakt mit `<img onerror>`/`<svg onload>`/`<script>`-Payloads
   in Vorname/Nachname/Notizen angelegt, Payload blieb in Tabelle UND
   Detailansicht als sichtbarer Text statt auszuführen,
   `window.__xssFired` blieb bei 0, Testkontakt danach wieder gelöscht.
   Nebenbei aufgefallen (keine Handlung nötig): drei leicht
   unterschiedliche Autocomplete-Implementierungen für Kontakt-/Ort-
   Suche, organisch entstanden — Rule of Three gerade erst erreicht,
   noch kein Grund zum Vereinheitlichen.
3. **`maxlength` auf bisher unbegrenzten Freitextfeldern nachgetragen**
   (noch selber Tag, Nutzerwunsch) — reine UX-Hygiene, kein
   Sicherheitsmechanismus (aktuelle Werte: CLAUDE.md).

**Nachtrag noch am selben Tag: RLS-Durchgang** (statische Analyse aller
`sql/*.sql`-Policies + Live-Bestätigung per direktem PostgREST-Aufruf
mit echtem Session-Token, nicht nur gelesen/vermutet):

- **`sql/patch38_profile_privilege_schutz.sql`, seit 2026-08-07 live:**
  `profiles_update_own` hatte `using (id = auth.uid())` ohne eigene
  `with check` — schützte nur `id`, keine andere Spalte. Erstbestätigung:
  eigener Account per PATCH auf `/rest/v1/profiles` von `role:'admin'`
  auf `'member'` gesetzt und sofort zurück — ein normaler Nutzer hätte
  sich selbst zum Admin machen können, ebenso `character_class`/`org_id`
  frei ändern. Patch 38 fügt einen BEFORE-UPDATE-Trigger hinzu, der
  diese drei Spalten blockiert, außer der Ausführende ist bereits Admin.
  Nach dem Einspielen mit einem frischen Wegwerf-Testaccount erneut
  verifiziert: Selbst-Beförderungsversuch korrekt abgelehnt.
- **Zweite, verwandte Lücke direkt beim erneuten Testen gefunden —
  `sql/patch39_profile_insert_privilege_schutz.sql`, seit 2026-08-07
  live:** Patch 38 deckte nur UPDATE ab, nicht die allererste Zeile.
  `profiles_insert_self` prüfte beim Anlegen ebenfalls nur
  `id = auth.uid()` — ein direktes INSERT mit `role:'admin'` legte
  sofort ein fertiges Admin-Profil an, komplett am
  Registrierungsbildschirm vorbei, von jedem Internet-Besucher aus
  nutzbar (offene Selbstregistrierung, kein Einladungszwang). Patch 39
  erzwingt `role='member'` und die Standard-`org_id` per BEFORE-INSERT-
  Trigger, unabhängig vom mitgeschickten Wert. Erneut mit einem
  frischen Wegwerf-Account verifiziert: `role:'admin'` + fremde
  `org_id` im Payload, gespeicherte Zeile hatte trotzdem `role:'member'`
  und korrekte Standard-Org.
- `user_inventory` hatte dieselbe Lücke bei `item_key`/`quantity` —
  damals noch offen, behoben am 2026-08-15 (siehe "Serverseitige
  Schreib-Härtung" in CLAUDE.md).
- Alle Testzeilen/Wegwerf-Testprofile danach vollständig entfernt,
  zuletzt am 2026-08-10 per `supabase db query --linked` gegengeprüft
  (0 Treffer).

**Nachtrag 2026-08-11: `locName()`-XSS-Lücke + Datenbank-Advisor-
Durchgang** (auf die Frage "was könnten wir bei diesem Tempo übersehen
haben"):
- `locName()` (Dungeon-/Betriebsname) escapte seinen Rückgabewert
  nicht — drei Renderstellen betroffen (Kontakte-nach-Dungeon-Kacheln,
  Kontakttabelle, Kanban-Karten). Gleiche Lückenklasse wie der
  Sicherheits-Durchgang vom 2026-08-07, dort aber nicht erfasst
  (Locations waren nicht im Scope). Gefixt.
- Passwortfeld (`authPassword`) ohne `maxlength` nachgetragen.
- **`supabase db advisors`-Werkzeug an diesem Tag entdeckt** (aktuelle
  Nutzungsanleitung: CLAUDE.md). Ergebnis dieses ersten Laufs: 33
  fehlende Fremdschlüssel-Indizes bei neueren Tabellen gefixt
  (Migration `20260811202349_fk_indizes_und_search_path_haertung.sql`,
  plus fester `search_path` auf 7 privilegierte Funktionen), 28 als
  "von anon/authenticated ausführbar" gemeldete Funktionen geprüft und
  als unbedenklich eingestuft. **Damals bewusst zurückgestellt, echte
  "erst bei Skalierung"-Kandidaten** (60× mehrere permissive
  RLS-Policies pro Tabelle, 54× `auth.uid()` statt
  `(select auth.uid())`) — **später tatsächlich behoben**, siehe
  "RLS-Performance-Härtung" weiter unten in CLAUDE.md (2026-08-17).
