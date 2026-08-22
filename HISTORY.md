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

## 2026-08-04 bis 2026-08-07: Kalender-Aufbau + UI-Audit, Entstehung

**Häppchen 5 (Abenteuerlog-Seite bis UI-Audit, ursprünglich CLAUDE.md-
Zeile 1085–1412), fertig 2026-08-22.** Größter/dichtester Häppchen
bisher inhaltlich, aber auch der technisch wichtigste — die
Kalender-/Termin-Architektur (Wochenansicht, Serientermine,
Kalender-Aufgaben) wird an vielen späteren Stellen in CLAUDE.md
vorausgesetzt, deshalb bewusst NICHT so aggressiv gekürzt wie Häppchen
4 (reine Business-/Technik-Fakten bleiben fast komplett in CLAUDE.md,
nur die Bau-/Debugging-Erzählung wandert hierher).

**Reihenfolge-Layout-Wunsch, 2026-08-04:** Kalender oben → Tagebuch-
Serie → 5 Fragen → Foto ganz unten (vorher umgekehrt) — reiner
Layout-Wunsch, keine Logik-Änderung.

**Bugfix 2026-08-04, "hat einen Eintrag"-Stolperstein:** ein `upsert`
beim Leeren aller 5 Tagebuch-Felder überschreibt die
`journal_entries`-Zeile nur mit leeren Strings, löscht sie aber nicht
— und ein echtes Löschen wäre wegen `journal_entry_mentions`
`on delete cascade` (@mention-Markierungen sollen bewusst NICHT
löschbar sein) ohnehin nicht die richtige Lösung gewesen. Das aktuell
gültige Prinzip (`journalRowHasContent(row)` statt reiner
Zeilen-Existenz-Prüfung) steht in CLAUDE.md.

**Termin-Kalender Wochenansicht, Entstehung (Patch 33, seit 2026-08-05
live):** Phase 1 der am 2026-08-04 nur als Vision notierten Idee, nach
ausführlicher Absprache gebaut. Zwei Stolpersteine dabei gefunden und
gelöst:
- Ob ein Klick einen bestehenden Termin öffnet oder einen neuen
  erzeugt, wurde zunächst über `e.target.closest('.week-event')` im
  `pointerdown` entschieden — dadurch ließ sich kein zweiter,
  überschneidender Termin mehr über einem bereits voll-breiten
  bestehenden Termin aufziehen. Korrigiert auf Ziehstrecke (>6px
  Bewegung = neuer Termin), aktuell gültiges Verhalten: CLAUDE.md.
- Dieselbe Sticky-Zeitachsen-Bug-Klasse wie vorher schon bei der
  Kontakt-Tabelle: der erste Wurf hatte `overflow-x:hidden` auf
  `.week-view-wrap` gesetzt, wodurch Samstag/Sonntag auf dem Handy
  unsichtbar abgeschnitten waren statt scrollbar zu sein — auf
  `overflow-x:auto` korrigiert, gegen die echte App auf 390px
  verifiziert.

**Kanban-Integration, wie es entstand:** die Kanban-Übergänge
"Ersttermin vereinbart"/"Zweittermin" fragen seit diesem Patch nach
Datum+Uhrzeit (`promptKanbanTermin()`), sowohl am Dungeon-Button als
auch beim Ziehen einer bestehenden Karte (vorher dort komplett ohne
Datumsabfrage). Der "Termin eintragen"-Button im Kontaktformular
(`cdTerminBtn`) nutzt denselben Baustein — Nutzerwunsch, "das hat was
Bequemliches". **Seit 2026-08-09 abends** holt derselbe Button eine auf
Gewonnen/Verloren stehende Karte zusätzlich auf Ersttermin zurück
(vorher passierte das nur beim Ziehen im Board, was der Nutzer als Bug
meldete — seitdem konsistent).

**Nachbesserung Patch 34 (`sql/patch34_wochenende_ausblenden.sql`,
2026-08-05), noch am selben Tag, ausgelöst durch echtes Nutzer-Feedback**
("ich hab meine Arbeitszeit nun von Montag bis Freitag gelegt, der
Kalender zeigt immer noch Samstag und Sonntag"): ein Wochentag ganz ohne
Arbeitszeiten-Eintrag galt fälschlich als ungegraut statt komplett
arbeitsfrei — behoben. Gleichzeitig `calendar_hide_weekends` als neue
Einstellung ergänzt (aktueller Stand: CLAUDE.md).

**Serientermine, End-to-End-Verifikation (Patch 36, 2026-08-06):** per
Playwright gegen die echte Datenbank bestätigt — Serie anlegen → 4
wöchentliche Termine korrekt materialisiert → "ganze Serie" verschoben,
vergangener Termin nachweislich unverändert, alle künftigen korrekt
aktualisiert → "ganze Serie" gelöscht, danach nichts mehr in
`termine`/`termin_series`, kein Testdaten-Rückstand. Das
`askSeriesScope()`-Popup brauchte dabei einen eigenen `z-index:1001`
(über einem bereits offenen `.loc-modal`) — ohne die Anhebung fing das
darunterliegende Termin-Popup die Klicks ab, per Playwright-Test
entdeckt.

## 2026-08-06/07: UI-Audit über alle Seiten + Buch-/Rollen-Kachel

Auf ausdrücklichen Nutzerwunsch ("kontrolliere die vollständige UI ...
achte auf Mobile UND Desktop") wurde die gesamte App einmal systematisch
geprüft: alle 12 Nav-Seiten, je bei 390px (Mobile) und 1440px (Desktop),
per Playwright mit echtem Login — automatisierter Overflow-Check plus
visuelle Screenshot-Sichtung. Zwei echte, bis dahin unbemerkte Bugs
gefunden und behoben:
1. Fähigkeiten-Radar (Sigil) schnitt lange Achsenbeschriftungen am Rand
   ab ("Fachwissen" erschien als "chwissen") — das SVG-viewBox war
   exakt so groß wie der Radar selbst, `text-anchor="middle"` ließ
   lange Labels über den sichtbaren Bereich hinausragen.
2. Chronik (Handlungen-Seite) zeigte beim Öffnen nicht die neuesten
   Einträge — `.log` nutzt `flex-direction:column-reverse`, aber der
   Browser initialisiert die Scrollposition mit `scrollTop:0`. Behoben
   durch explizites `scrollTop = -scrollHeight`, an zwei Stellen nötig
   (`render()` UND `showPage()`, da die Seite beim ersten Rendern noch
   unsichtbar war und `scrollHeight` dort 0 ergab).

**Direkter Folgeauftrag, noch am 2026-08-07 umgesetzt** (zwei von drei
Politur-Vorschlägen aus dem Audit-Bericht, vom Nutzer freigegeben):
Sigil deutlich vergrößert (viewBox 260×260→530×530, richtungsabhängiges
`text-anchor` statt überall `middle` — "ich würde die Wörter schon
gerne lesen können"); neuer, wiederverwendbarer Helfer
`initScrollFade(el)`/`updateScrollFade(el)` für seitlich scrollbare
Leisten (Sidebar-Nav Mobile, Feldzug-Route, Monats-Reiter
Trophäenkammer) — **bei künftigen neuen horizontal scrollenden
Bereichen weiterverwenden statt eine eigene Lösung zu bauen** (aktuell
gültige Regel, auch in CLAUDE.md). Dritter Vorschlag (Emoji-Rendering
in Testscreenshots) war nur ein Hinweis zur Testumgebung, keine
Änderung nötig.

**Methodik-Erkenntnis aus derselben Session** (generelle Lehre lebt
dauerhaft in Claudes Erinnerung, `feedback_verify_live_before_acting`):
ein vom Nutzer gemeldetes "Geburtsdatum wird nicht angezeigt" stellte
sich bei einer direkten Live-Prüfung als kein Bug heraus — der Nutzer
hatte einen Test-Kontakt gemeint, nicht sein eigenes Profil.

**Buch-/Rollen-Kachel, Asset-Entstehung (seit 2026-08-04 live):** die
drei Icons (Zauberbuch/Kriegsbuch/Schützenrolle) sind handgezeichnete
Pixel-Art (kein GandalfHardcore-Asset — Bücher/Rollen kommen im Paket
nicht vor), zweite Überarbeitung nach Vorlage von vier vom Nutzer
geschickten Referenz-Screenshots (runde Ecken, Rücken-Farbstreifen,
Titel-Plakette, Seitenkante unten, Lesezeichen-Fahne, klassentypisches
Emblem). Erzeugt über ein Python/Pillow-Skript (Pixel-für-Pixel auf
einem 24×24-Raster, per Nearest-Neighbor auf 96×96 hochskaliert) statt
gezeichneter SVGs — die erste Fassung ohne Referenzbilder wirkte laut
Nutzer "nicht ganz rund", danach erst die vier Screenshots angefordert
und die Formensprache (nicht die Bilder selbst) übernommen.

## 2026-08-03/04/09: Changelog-Popup, Sprite-Labor, Pixel-Art-Referenzmasken

**Häppchen 6 (Changelog-Popup bis Pixel-Art-Referenzmasken-System,
ursprünglich CLAUDE.md-Zeile 1315–1483), fertig 2026-08-22.** Drei
Tool-/Feature-Referenz-Abschnitte, deren Kernarchitektur größtenteils in
CLAUDE.md bleibt (aktiv genutzte Werkzeuge/Regeln) — nur die
Entstehungs-/Test-Erzählung wandert hierher.

**Changelog-Popup, Live-Verifikation (Patch 32, 2026-08-04):** per
Playwright end-to-end gegen die echte Datenbank verifiziert (nicht nur
gemockt) — `last_seen_patch_number` testweise auf 0 zurückgesetzt,
echter Reload, Popup erschien korrekt mit "Patch 32 — Changelog-Popup
für angewendete SQL-Patches", App hat den Stand danach selbst wieder
korrekt auf 32 gesetzt.

**Sprite-Labor, Entstehung (seit 2026-08-03):** der Schützen-Bogen
brauchte in einer früheren Session drei Runden Live-Testen im echten,
deployten Programm, bis Größe/Spiegelung/Ankerpunkt stimmten — jedes
Mal: Bild bauen, committen, pushen, Nutzer lädt neu, meldet zurück, was
noch falsch aussieht. Zu langsam für ein rein visuelles Problem, daraus
entstand `Design/sprite_lab.html` (aktuelle Funktionsweise: CLAUDE.md).
Ursprünglich war dafür ein Claude-Code-"Artifact" angedacht — verworfen,
weil Artifacts keinen Schreibzugriff auf lokale Ordner haben und
Bild-Assets nicht extern nachladen dürfen (strikte CSP); ein lokales
Live-Server-Tool kann beides (generelle Lehre dazu:
`feedback_local_tools_need_direct_pipe` in Claudes Erinnerung).
Beim allerersten Bogen-Bake wurde zusätzlich sicherheitshalber direkt
per Canvas (Playwright-Skript, nicht Python) gebacken, um jedes Risiko
einer Python/Canvas-Konventions-Abweichung für das erste echte Ergebnis
auszuschließen — das Python-Skript (`bake_sprite_lab_export.py`) wurde
daran kalibriert/verifiziert und ist seitdem der Standardweg.

**Pixel-Art-Referenzmasken-System, Entstehung (2026-08-09):** der
Nutzer kündigte einen großen Ausbau an (3 Charaktere, ~30 neue
Kleidungsteile je Körperteil) und äußerte dabei explizit Misstrauen
("du bist sehr unzuverlässig in diesem Thema … du brauchst irgendein
Raster, ein Gitter, eine Basis, eine Struktur"). Der Sprite-Bogen hatte
vorher gezeigt, dass freihändig pro Frame platzierte Pixel-Art mehrere
Korrekturrunden braucht. Zwei Testläufe gegen den männlichen
Basiskörper (Ergebnis dem Nutzer als Artifact gezeigt):
1. Umfärbung bei identischer Maske (Hemd beige→dunkelgrün) — sitzt
   erwartungsgemäß perfekt über alle 8 Frames, bestätigt nur, dass die
   Maskenextraktion/Pipeline technisch funktioniert.
2. Neue Silhouette (Hemd→lange Tunika, Saum entlang der bereits
   korrekten Hosen-Maske bis kurz vor die Stiefel verlängert) — beide
   automatischen Checks bestanden in allen 8 Frames, aber der sichtbare
   Effekt war schwächer als erhofft (nur ein kleiner Zipfel an der
   Hüfte, weil der Saum bewusst konservativ vor den Stiefeln gestoppt
   wurde).

Aktueller Fähigkeits-Status (was zuverlässig automatisch geprüft werden
kann vs. was weiterhin Handarbeit mit Sichtprüfung bleibt) und die
daraus abgeleitete verbindliche Arbeitsregel: CLAUDE.md. Ausführlichere
Projekt-Doku zu diesem System auch in Claudes Erinnerung,
`project_pixelart_reference_mask_system`/
`feedback_pixelart_verify_dont_eyeball`.

## 2026-08-08/09/10: Gilden-Sichtbarkeit (Phase 1-3) + Questbaum-Übersetzung Start

**Häppchen 7 (aktiver Nebenstrang/Questbaum-Übersetzung erster Schritt
bis Admin-Notfallzugriff Phase 3, ursprünglich CLAUDE.md-Zeile
1874–2158), fertig 2026-08-22.** Kernsicherheits-/Business-Architektur
(Gilden-Sichtbarkeitsmodell) — bewusst konservativ gekürzt wie Häppchen
5, da an vielen späteren Stellen vorausgesetzt. Nur Entstehungs-,
Debugging- und Verifikations-Erzählung wandert hierher.

**"Ein aktiver, paralleler Nebenstrang"-Bündel, Abschluss 2026-08-15:**
drei ursprünglich gebündelte Punkte (Item-/Mengen-System-Umbau, wartete
auf die Questbaum-Übersetzung) alle erledigt:
1. Manatrank-Vergabe an Quests geknüpft — `grantDailyManatrank()` (der
   automatische Gratis-Trank pro Kalendertag) komplett entfernt,
   hängt jetzt an der täglichen Quest `daily1`.
2. `reward_item_key`+`qty`-Feld für Quests befüllt — `checkAndAwardRecurringQuests()`
   unterstützte `q.itemReward` bereits (ungenutzt seit dem
   Krankenhausakquise-Pilot), war nur nie befüllt.
3. `user_inventory`-RLS-Lücke behoben (siehe "Serverseitige
   Schreib-Härtung" weiter unten in CLAUDE.md).

**Questbaum-Übersetzung, Session-Kontext (Patch 40, 2026-08-09):** der
Obsidian-Questbaum (`Questbaum.canvas`) wurde gemeinsam mit dem Nutzer
auf Messbarkeit gegen das echte System geprüft — die meisten Äste
(Sach-/Leben-/Kranken-/Finanzierung-Abschlüsse, Krankenhausakquise,
Empfehlungsmanagement, Bestandskundenausbau) waren schon vorher 1:1 aus
bestehenden Daten ableitbar, nur `termine.kanal` und die Konstanz-
Anzeige waren echte Lücken (aktuelle Funktionsweise: CLAUDE.md). Der
"Vertriebstrichter" (10 Ansprachen→6 Termine→3 Abschlüsse) wurde
bewusst NICHT übersetzt — reine persönliche Planungs-Daumenregel, kein
Spielziel (siehe `feedback_heuristic_vs_quest`). End-to-end mit
Playwright verifiziert (Kanal speichern → korrekter DB-Wert → Icon in
der Wochenansicht → Vorbelegung beim erneuten Öffnen), Testtermin
danach aufgeräumt.

**Gilden-basierte Sichtbarkeit Phase 1, Entstehung (seit 2026-08-08
live):** löste die Lücke "jedes Org-Mitglied sieht alle Dungeons" —
Auslöser war ein echtes, beobachtetes Problem (neu angemeldete
Kolleg:innen sahen sofort alle Dungeons/Kontakte des Nutzers). Entstand
aus einer sehr ausführlichen Grundsatz-Konversation. **Wichtige
Korrektur während der Konzeptions-Diskussion:** Kontakte waren
ursprünglich fälschlich als von Dungeons abhängig modelliert (Kontakt
erbt Sichtbarkeit vom Dungeon) — falsch, weil dungeon-lose Kontakte
(z.B. niedergelassene Ärzte ohne Krankenhaus-Dungeon) sonst nie hätten
geteilt werden können; das aktuell korrekte Modell (kein `guild_id` an
Kontakten, Prüfung über Eigentümer+Gilde) steht in CLAUDE.md.

**Wichtiger RLS-Stolperstein, viel Debugging gekostet** (die daraus
gezogene generelle Lehre steht kompakt in CLAUDE.md): eine `FOR UPDATE`-
Policy mit korrektem `USING`/`WITH CHECK` reichte nicht aus, solange die
Zeile nicht zusätzlich über eine bestehende `SELECT`-Policy sichtbar
war — selbst eine testweise auf `USING(true) WITH CHECK(true)`
vereinfachte Update-Policy schlug fehl (0 betroffene Zeilen, kein
Fehler), bis `locations_select_org` um dieselbe
`guild_founder_of_member()`-Bedingung erweitert wurde. Per Wegwerf-
Testaccounts (Signup, Profile, Kontakt/Dungeon, Cross-User-
Zugriffsversuche) sauber isoliert und verifiziert, inklusive mehrerer
Zwischenschritte mit temporären Diagnose-Funktionen (`debug_*`, alle
wieder entfernt).

**Bewegter Avatar + Sigil auf Freundes-/Gilden-Kacheln, direkter
Folgeauftrag noch am selben Tag:** löste einen offenen Punkt aus der
Konzepts-Konversation selbst ein ("wenn man auf den Freund klickt,
sieht man auch das Sigil der Fähigkeiten"). Live mit drei Wegwerf-
Testaccounts verifiziert: Freund bekommt korrekte Skill-Summen (inkl.
`skill2`-40%-Anteil) über `friend_skill_totals()`, ein unbeteiligter
Dritter bekommt eine leere Liste (aktuelle Funktionsweise: CLAUDE.md).

**Gilden-Notfall-Nachfolgekette Phase 2, Verifikation (seit 2026-08-08
abends live):** end-to-end mit Wegwerf-SQL-Testdaten gegen die echte DB
verifiziert — drei Szenarien: Teamleiter rückt korrekt vor längerem
Nicht-Teamleiter nach; Fallback aufs insgesamt längste Mitglied ohne
`team_rights`; Gildenführer war letztes Mitglied → Gilde bleibt
bestehen, `founder_id` wird `NULL` statt die Gilde zu löschen.
**Nachtrag 2026-08-09:** End-to-End-Test des eigentlichen Mitarbeiter-
Offboardings nachgeholt (war bis dahin nur per Schema-Existenz geprüft)
— drei Szenarien verifiziert (gildenlos: alles per CASCADE weg;
normales Mitglied: Kontakt/Dungeon landen im Pool, `sales.created_by`
wird NULL; Gildenführer mit eigenen Kontakten: Nachfolge UND Pooling im
selben Trigger-Durchlauf). Testdaten vollständig aufgeräumt.

**Admin-Notfallzugriff Phase 3, Verifikation (seit 2026-08-08 abends
live):** end-to-end gegen die echte DB verifiziert per `supabase db
query` + `set_config('request.jwt.claim.sub', ...)` (echten Admin-RPC-
Aufruf simuliert, ohne echten Login/Playwright-Lauf) — positiver
Zugriff liefert korrekt Kontakt+Dungeon der Zielperson UND schreibt den
Audit-Log-Eintrag, Aufruf durch Nicht-Admin wird abgewiesen, leerer
Grund wird abgewiesen. Testdaten danach vollständig aufgeräumt.

## 2026-08-10: Vertragsnummer, Datei-Upload, Chronik-Sichtbarkeit, Kontakt-Seite

**Häppchen 8 (Vertragsnummer-Feld bis Kontakt-Seite statt Popup,
ursprünglich CLAUDE.md-Zeile 2076–2349), fertig 2026-08-22.** Der
Kontakt-Seite-statt-Popup-Umbau ist die aktiv am meisten referenzierte
Architektur-Entscheidung in diesem Bereich (Vorbild für spätere
"echte Seite statt Modal"-Entscheidungen, siehe
`feedback_real_pages_over_modals_for_records`) — bewusst konservativ
gekürzt, nur Design-Prozess/Verifikation/Bugstorys wandern hierher.

**Datei-Upload, Bugfix Patch 44 (noch am selben Tag):** jeder Upload
schlug live mit "new row violates row-level security policy" fehl —
Bugreport direkt nach Ausprobieren ("hab eine Datei hochgeladen.
einfach verschwunden"). Zwei Ursachen:
1. Sichtbarkeits-Bug im Frontend: `renderContactFilesTab()` löschte den
   Status-Text unbedingt, bevor der Tab komplett neu gerendert wurde —
   jede Fehlermeldung war technisch kurz da, aber nie sichtbar.
2. Der eigentliche Bug, den diese Korrektur erst aufdeckte — echte
   Namenskollision in SQL: die Storage-Policies aus Patch 42 benutzten
   `(storage.foldername(name))[1]`, aber `name` war dort mehrdeutig —
   `storage.objects` UND das in der EXISTS-Subquery korrelierte
   `public.contacts` haben BEIDE eine Spalte `name`. Postgres löste
   `name` auf `contacts.name` (den Kunden-Anzeigenamen) statt auf den
   Datei-Pfad auf — die Prüfung schlug deshalb für JEDE Datei fehl,
   unabhängig von Berechtigung. Per direkter SQL-Diagnose bestätigt,
   Fix: `objects.name` statt unqualifiziertem `name`. Die daraus
   gezogene generelle Lehre (bei RLS-Policies mit Subquery immer auf
   Spaltennamen-Kollisionen prüfen) steht kompakt in CLAUDE.md. Per
   Playwright end-to-end erneut verifiziert.

**Nav-Highlight-Bugfix, noch am selben Tag:** `openContactPage()`
setzte anders als `showPage()` nie `.nav-btn.active` — beim Neuladen
direkt auf `#kontakt/<id>` blieb der im HTML hart hinterlegte Default
("🧙 Charakter") als aktiv markiert stehen, obwohl inhaltlich die
Kontakt-Seite angezeigt wurde. Fix (aktuelles Verhalten: CLAUDE.md) per
Playwright verifiziert: kompletter Seiten-Reload direkt auf eine
`#kontakt/...`-URL markiert exakt einen Button korrekt.

**Chronik-Sichtbarkeit, Frontend-Korrektur:** `renderContactChronikTab()`
fragte `termine`/`contact_activities` vorher explizit mit
`.eq('owner_id', profile.id)`/`.eq('user_id', profile.id)` ab — eine im
Frontend zusätzlich gesetzte Einschränkung, die selbst nach dem RLS-Fix
weiterhin nur eigene Zeilen geliefert hätte. Beide Filter entfernt.
**Verifiziert nicht nur mit dem eigenen Admin-Zugang**, sondern mit
zwei echten Kollegen-Accounts über eine temporäre Gilden-
Testmitgliedschaft: mit Lesezugriff sah der Kollege alle 25
`action_log`- und 7 `contact_activities`-Einträge eines echten
Kontakts korrekt, ohne Mitgliedschaft exakt 0.

**Kontakt-Seite statt Popup, Auslöser:** Nutzer-Frust über ein früher
genutztes CRM im sozialen Bereich, das Kontakte nicht per Rechtsklick
in einem neuen Tab öffnen ließ ("richtig schlecht gelöst ... hätte
viele Arbeitsschritte gespart"). Das bisherige `contactDetailModal`-
Popup hatte exakt dieses Problem strukturell eingebaut.

**Design-Prozess:** drei Zonen-Layout-Vorschläge (Kompakt / Seitenleiste
/ Gestapelte Record-Seite) erst als Skizze im Chat, dann auf
Nutzerwunsch als reine Grau-Wireframes ("wirklich nur die Zonen") per
Artifact gezeigt. Nutzer wählte "Kompakt" als Grundstruktur, dann in
einer zweiten Artifact-Runde drei konkrete Ausführungen davon (Kompakt
/ Kennzahlen-Leiste / Kartenliste) — gewählt wurde **Kennzahlen-Leiste**
("die Übersicht mit den Kennzahlen find ich cool, auch das mit dem
Zuletzt kontaktiert!").

**Verifikation:** per Playwright gegen den echten Account — echter `<a
href="#kontakt/...">` navigiert korrekt, Kennzahlen-Leiste füllt sich,
Verträge-Zone ohne Tab-Klick sichtbar, Deep-Link per komplettem
Seiten-Reload liefert denselben Kontakt (der eigentliche Rechtsklick-
neuer-Tab-Beweis), Kanban-Karten-Link funktioniert ebenfalls. Kein
horizontales Overflow auf 390px, keine Konsolenfehler.

**Nachbesserung, noch am selben Tag:** die neue Seite stand beim ersten
Wurf an der alten Modal-Position im HTML — technisch ein `.page`-
Element, aber strukturell außerhalb des Sidebar-Layouts. Ergebnis: die
Kontaktkarte rutschte auf Desktop unter die komplette Navigationsleiste
statt daneben zu sitzen ("Anordnung gerade noch grauenhaft", Nutzer-
Feedback nach dem ersten Screenshot). Fix: den ganzen Block innerhalb
von `.content` platziert, direkt neben den anderen `.page`-Geschwistern.
Die daraus gezogene Lehre (eine neue `.page` muss strukturell im
selben Container wie bestehende Seiten stehen, sonst greift das
Sidebar-Layout nicht) steht kompakt in CLAUDE.md.

## 2026-08-15/16: Serverseitige Schreib-Härtung + Sicherheitswarnungen

**Häppchen 9 (Serverseitige Schreib-Härtung bis Sicherheitswarnungen,
ursprünglich CLAUDE.md-Zeile 2262–2485), fertig 2026-08-22.** Die
zentrale Write-Hardening-Architektur des Projekts (RPC-Pflicht für
`action_log`/`user_inventory`, "korrigieren statt ablehnen"-Muster) —
wird an vielen späteren Stellen vorausgesetzt, bewusst konservativ
gekürzt. Nur Entstehungs-/Test-/Incident-Erzählung wandert hierher.

**Auslöser (2026-08-15 abends):** löste die am 2026-08-07 gefundene,
damals bewusst zurückgestellte `user_inventory`-RLS-Lücke endgültig —
auf Nutzerwunsch ("will das vom Tisch haben"), danach auf die
Nachfrage "haben wir noch dringliche Themen davon" um drei weitere, im
selben Zug gefundene Stellen erweitert (`action_log`, `sales`,
`locations`). Wiederkehrendes Muster über alle vier (aktuelle Lösung:
CLAUDE.md): die RLS-Regel prüfte bisher nur "gehört dir die Zeile",
nicht ob der geschriebene WERT plausibel ist — dieselbe Lückenklasse
wie die XSS-Lücke vom 2026-08-07, nur auf der Schreib- statt der
Lese-Seite.

**Verifikation:** end-to-end gegen die echte DB (jede Sperre UND jeder
legitime Ablauf einzeln getestet, `set_config('request.jwt.claim.
sub', ...)` + `set role authenticated` gegen den echten Admin-Account),
Testzustand danach exakt auf den Ausgangswert zurückgesetzt.

**Folgeauftrag, noch am selben Abend: systematischer statt zufälliger
Durchgang.** Nutzerfrage "gibt es noch andere Grundregeln, die wir
übersehen haben" — alle `INSERT`/`UPDATE`-Policies im gesamten Schema
auf einen Schlag geprüft (`pg_policies`), nicht mehr nur die Tabellen,
an die zufällig gedacht wurde. `rule_configs`/`products` waren bereits
sauber admin-only, aber zwei weitere echte Funde, beide live bestätigt
und behoben:
- **`guild_members`-Selbstbeitritt** — die ernsteste Lücke des ganzen
  Tages: `contacts_access`/`dungeons_access`/`team_rights` waren beim
  Selbst-Beitritt (`joinGuild()`) komplett ungeprüft — ein Mitglied
  hätte sich beim Beitreten sofort Schreibzugriff auf alle geteilten
  Kontakte/Dungeons UND die Nachfolge-Berechtigung selbst geben können.
  Live bestätigt mit Wegwerf-Testmitgliedschaft.
- **`profiles.total_xp`/`level`** — direkt auf einen beliebigen Wert
  überschreibbar (Level 100 ohne einen Punkt XP). Live bestätigt, dann
  behoben (aktueller Mechanismus `sync_own_level_cache()`: CLAUDE.md).
  Beim Testen zunächst fälschlich mit dem eigenen Admin-Account geprüft
  (Bypass griff erwartungsgemäß, bewies nichts), danach korrekt mit
  einem echten Nicht-Admin-Konto verifiziert (Blockade griff).

**Bekannter Datenverlust beim Testen, offen kommuniziert:**
`profiles.company` des Admin-Accounts wurde während eines Testschritts
mit einem Platzhalterwert überschrieben, der ursprüngliche Inhalt war
nicht mehr rekonstruierbar — auf `NULL` zurückgesetzt, Nutzer
informiert. Die daraus gezogene Lehre (vor einem Test-Schreibvorgang
auf ein Feld ohne bekannten Ausgangswert immer zuerst den aktuellen
Wert auslesen und sichern) steht kompakt in CLAUDE.md.

**Sicherheitswarnungen, Auslöser (Patch 47, 2026-08-16):** löst Punkt 9
der BaaS-Aufgabenliste ("Logging mit echter Reaktion statt nur
Speicherung") — offene Selbstregistrierung + öffentlich erreichbare
App bedeuten, dass ein Angriff nicht zwingend über die eigene
Oberfläche laufen muss. Bisher landete ein abgewehrter
Manipulationsversuch nur dann im Fehlerprotokoll, wenn der Browser ihn
freiwillig meldete — ein direkter API-Aufruf daran vorbei blieb
komplett unsichtbar.

**Verifikation:** end-to-end mit einem Wegwerf-Testprofil gegen die
echte DB (`set_config('request.jwt.claim.sub', ...)` + `set role
authenticated`) — Selbst-Admin-Versuch UND Level-Fälschung in einem
Aufruf → beide Werte blieben unverändert, zwei Alarme protokolliert;
Gilden-Selbstbeitritt mit vollen Rechten → Mitgliedschaft angelegt,
aber auf Minimalrechte zurückgesetzt, ein Alarm protokolliert; direkter
RPC-Aufruf von `log_security_alert()` als normaler Nutzer →
`permission denied`. Testdaten danach vollständig entfernt (0 Reste
verifiziert).

## 2026-08-17: Questbaum-Jahresreset, Schatzraum, RLS-Performance-Härtung

**Questbaum Jahres-Reset (Patch 50), Design-Prozess:** löste den seit
der Krankenhaus-Meister-Migration (Patch 49) offenen Punkt, dass nur
zwei Questbaum-Stufen echte Bonus-XP gaben, der Rest nur Titel. Zwei
Artifact-Runden (gleiche URL, v1→v2) mit dem Nutzer durchgesprochen —
v1 kalkulierte jede Stufe als einmalige Lebensleistung (`levelBase`
4,70→5,02, +6,8%), **mit einer wichtigen Kurskorrektur mitten in der
Absprache**: Questbaum-Stufen sind eigentlich Jahresquests, nicht
einmalige Lebensleistungen (Geschäftsjahr = Kalenderjahr, deckt sich
mit den Jahr/Monat-Reitern im Kompendium). Daraus wurde v2 mit
geschätzter Häufigkeit pro Stufe über 10 Jahre (Einstiegsstufe ~9-10/10
Jahre, Top-Stufe ~1-2/10) — Ergebnis `levelBase` 4,70→**5,80** (+23,3%
Gesamt-XP bis Level 100). Die einzelnen Bonus-XP-Werte pro Stufe/Epic
blieben zwischen v1 und v2 unverändert, nur die Interpretation
"einmal vs. jährlich wiederholbar" änderte sich. Migration
`supabase/migrations/20260817120000_questbaum_jahresreset_bonus_xp.sql`
— die komplette neue `questTree`-JSON wurde programmatisch erzeugt
(Node-Skript liest die echte Live-DB-JSON, mappt Bonus-Werte per
Stufen-/Epic-id, schreibt zurück) statt von Hand transkribiert, bei 87
einzelnen Feldern bewusst kein Handarbeits-Risiko eingegangen.

**Verifikation:** dreifach — SQL-Dry-Run (`begin`/`rollback`, 10
Einzeltests: korrekte Auszahlung, doppelte Vergabe im selben Jahr
blockiert, dieselbe Stufe im Folgejahr erneut auszahlbar, Epic-Pfad,
diverse Fehlerfälle), ESLint sauber, Playwright-Simulation
(synthetische Vorjahresdaten wurden korrekt ignoriert). Nach `supabase
db push`: `levelBase`=5,80, 78 Stufen + 11 Epics mit `bonus`-Feld live
bestätigt, Patch 50 in `schema_patches`. Beim ersten echten Login
danach wurden über 15 bereits erfüllte Stufen automatisch nachgezahlt
(funktioniert wie beim Krankenhaus-Meister-Vorbild).

**Schatzraum (Reliquienkammer/Ruhmeshalle/Jagdkammer), zwei Baurunden:**
direkter Folgeauftrag aus dem Jahres-Reset — sobald jede Stufe zum 1.
Januar zurückspringt, verschwindet eine Vorjahres-Leistung sonst
spurlos aus der laufenden Questbaum-Ansicht. Erster Entwurf (inline
aufklappende Kachel im Kompendium, ähnlich dem Zauberbuch-Muster)
zeigte ALLE `questtree_bonus`-Log-Einträge (auch einzelne Ladder-Stufen
wie "20% Türöffner-Quote") als flache `.log-entry`-Liste. Nutzer-O-Ton:
"in der jetzigen Form ist das nicht wertschätzend." Nutzer-Feedback war
präzise genug für eine direkte Korrektur ohne neuen Artifact-Vorlauf —
die korrigierte, live gegangene Fassung (Vollbild-Unterseite, nur
Epics, Gruppierung nach Kategorie) steht in CLAUDE.md.

Kein neues DB-Feld/keine neue Tabelle nötig — reine Ableitung aus
bereits vorhandenem `action_log` (das Jahr steckt seit Patch 50 in
`meta.year`) + `mySalesCache`. Per Playwright verifiziert (Desktop +
Mobile 390px, Negativtest dass eine Nicht-Epic-Stufe wirklich nicht
auftaucht, Jahres-Navigation vor/zurück inkl. Vorjahres-Trophäe, kein
horizontales Overflow, keine Konsolenfehler).

**RLS-Performance-Härtung:** löste den in der Nachtrag-Notiz zum
Datenbank-Advisor-Durchgang vom 2026-08-11 bewusst zurückgestellten
Punkt ("erst bei echtem Abfrage-Volumen angehen") — auf Nutzerwunsch
jetzt vorgezogen, nachdem der Advisor-Stand seit 2026-08-11 spürbar
gewachsen war (60 `multiple_permissive_policies`, 52
`auth_rls_initplan`). Reine Effizienz-Migration, keine
Verhaltensänderung — wer was sehen/bearbeiten darf, blieb exakt
gleich. Migration
`supabase/migrations/20260817210000_rls_performance_haertung.sql`
wendete die zwei in CLAUDE.md dokumentierten Muster an: `auth.uid()`
zu `(select auth.uid())` gewrappt (7 zentrale Hilfsfunktionen + 39
einzelne Policies), und 10 Tabellen mit mehreren permissiven Policies
je Aktion (21 Original-Policies) zu je einer zusammengelegt —
Policy-Zahl insgesamt 75→64.

**Verifikation, vor dem Schreiben der Migrationsdatei in einer
`begin`/`rollback`-Transaktion gegen die echte DB getestet** (nichts
blieb hängen): 35 Sichtbarkeits-Snapshots (7 echte Kolleg:innen-
Accounts × die 5 am stärksten betroffenen Tabellen) vorher/nachher
exakt identisch, plus 7 gezielte Schreibproben für die kniffligsten
Fälle (Kontakt-Gildenpool-Zuweisung, Gildenführer aktualisiert Location
eines Gildenmitglieds, alle zugehörigen Verweigerungsfälle) — dabei ein
eigener Testaufbau-Fehler gefunden und korrigiert
(`guild_leadership_permission()` verlangt `team_rights=true`, nicht nur
Schreibzugriff — kein Bug in der Migration, nur ein zu lax
konfigurierter Wegwerf-Testnutzer). Nach dem `supabase db push` per
erneutem Advisor-Lauf bestätigt: 0 verbleibende `auth_rls_initplan`/
`multiple_permissive_policies`-Funde (vorher 52/60), `migration list
--linked` zeigt local==remote.

## 2026-08-18: Kanban-Kurzvorschau, Termin-Einladungen, Gilden-Einladungen

**Kanban-Kurzvorschau + Termin-Einladungen, Entstehung:** zwei
zusammenhängende Bausteine, in derselben Session entstanden, direkt
nach dem Termin-Datumsgrenzen-Vorfall desselben Tages (Listener-
Stacking-Bug, siehe Häppchen-9-Eintrag des Bugfix-Durchgangs in
CLAUDE.md, Abschnitt "Kanban"). Migration
`20260818210000_termin_einladungen.sql`. Backend end-to-end mit
Wegwerf-Testaccounts verifiziert (Einladung, Annahme, Update-
Weitergabe inkl. Status-Reset, Ablehnung inkl. Kopien-Löschung,
Sicherheitsgrenze bei Fremden ohne gemeinsame Gilde, Lösch-Kaskade bei
Original-Löschung — alle Prüfungen bestanden), Frontend zusätzlich per
Playwright gegen den echten Account getestet (Vorschau-Popup,
Einladen-Picker, Einladungs-Karte, Annehmen, schreibgeschützte
Wochenansicht-Darstellung, erneute Bestätigungs-Anfrage nach
Verschieben).

**Stolperstein beim Bauen:** ein Versuch, die Migration vorab in einer
`begin`/`rollback`-Transaktion zu testen, führte stattdessen (falscher
CLI-Aufruf) zu einer echten, direkten Anwendung auf die Live-Datenbank,
bevor das Nutzer-Go dafür eingeholt war — im Nachhinein per `supabase
migration repair` sauber ins Migrations-Tracking eingetragen (die
Migration selbst war inhaltlich korrekt und harmlos, reine
Schema-Ergänzung ohne Auswirkung auf bestehende Daten). Die daraus
gezogene Lehre (`begin`/`rollback` muss Teil der SQL-Datei selbst
sein) steht jetzt dauerhaft im Abschnitt "Supabase-CLI-
Migrationstoolchain" in CLAUDE.md.

**Nachtrag, noch am selben Abend — Absage-Benachrichtigung +
Statusanzeige (Nutzerkorrektur der ersten Fassung):** die erste
Fassung ließ eine Absage still verschwinden und zeigte dem Organisator
nirgends, ob/wie geantwortet wurde — beides vom Nutzer explizit
nachgefordert, beides noch am selben Abend nachgebaut (Details/
aktueller Stand: CLAUDE.md). Technisch brauchte das zwei kleine
Folgemigrationen (erst Titel/Zeit/Kanal, dann separat noch
`organizer_id` nachgetragen, weil sonst nicht mehr feststellbar
gewesen wäre, WER abgesagt hat) — beide zuerst per `begin`/`rollback`-
Wrapper innerhalb der SQL-Datei syntaktisch geprüft, dann regulär per
`supabase db push` angewendet. End-to-end mit Wegwerf-Testaccounts
verifiziert (Annehmen → Absage → Eingeladener sieht Absage mit
korrektem Titel/Zeit trotz gelöschtem Original → Ausblenden;
Organisator sieht Status nach Einladen und nach Ablehnung), Frontend
zusätzlich per Playwright gegen den echten Account getestet.

**Gilden-Einladung, Auslöser:** Nutzer-Bugreport, noch am selben Tag —
der Gildengründer konnte über den Mitglied-Picker bisher jedes
Org-Mitglied direkt und ohne dessen Zustimmung in `guild_members`
eintragen. Migration
`supabase/migrations/20260818230000_gilden_einladungen.sql`, vorab per
`begin`/`rollback`-Wrapper mit 8 Assertions gegen Wegwerf-Testaccounts
verifiziert (Nicht-Gründer darf nicht einladen, Annehmen erzeugt
korrekte Minimalrechte, direktes Fremdeinfügen jetzt RLS-blockiert,
Ablehnen/Zurückziehen/Doppel-Mitgliedschaft-Schutz — alle 8 bestanden),
danach per Nutzer-Go gepusht. **Nebenbei mitbehoben:** die
Kandidatenfilterung prüfte bisher nur Mitgliedschaft in der aktuellen
Gilde, nicht org-weit — latenter Bug (ein Nutzer kann nie in zwei
Gilden gleichzeitig sein), jetzt korrekt org-weit gefiltert.

**Zwei kleinere, gleichzeitig gemeldete Design-Bugs mitbehoben:** das
Namens-Suchfeld im Gilden-Picker (`#guildPickerSearch`) hatte gar keine
CSS-Regel (erschien als weißes Browser-Standardfeld statt im dunklen
App-Theme, neue `.guild-picker input`-Regel behebt das); der
"+ Gildenmitglied einladen"-Button in der Kanban-Kurzvorschau wurde
bisher roh per `terminRow.after(inviteBtn)` mitten in die Feldliste
eingehängt (zwischen "Nächster Termin" und "Telefon"/"E-Mail") —
Nutzerkritik "klobig mitten drin", seitdem im eigenen
`#kanbanPreviewInviteZone`-Platzhalter am Ende der Feldliste (aktueller
Stand: CLAUDE.md).

Frontend zusätzlich per Playwright gegen den echten Account verifiziert
(Input-Styling, Feld-Reihenfolge in der Kanban-Vorschau, Einladungskarte
bleibt korrekt verborgen ohne offene Einladung).

## 2026-08-19: Kanban strikt persönlich + Gildenleben-Fundament

**Kanban-Leck, Fund und Fix:** echter, live beobachteter Bug, gefunden
beim Durchsprechen der geplanten Termin-Einladung↔Kanban-Verknüpfung.
`renderKanbanBoard()` nutzte dieselbe ungefilterte
`loadContactsBundle()`-Abfrage wie die Kontakte-Seite — dort richtig
(gilden-geteilte Kundendatenbank ist gewollt), fürs Kanban-Board
fehlte aber seit jeher die Eigentümer-Einschränkung. Per direkter
SQL-Abfrage gegen die echte DB bestätigt: ein eigener Kontakt mit
gesetzter `kanban_stage` UND `write`-Gildenfreigabe tauchte dadurch
bereits echt auf dem Kanban-Board eines Gilden-Kollegen mit auf,
inklusive Zieh-/Verschieben-Möglichkeit im UI (serverseitig hätte
`contacts_update_visible` nur bei `write`-Freigabe erlaubt
geschrieben zu werden — bei `read`-Freigabe wäre der Versuch
RLS-blockiert, aber als wortloser Fehlschlag sichtbar gewesen). Fix
rein im Frontend, keine RLS-Änderung nötig (aktueller Stand:
CLAUDE.md). Per Playwright gegen den echten Admin-Account verifiziert
(kein Testaccount für die Gegenprobe "Kollege sieht die fremde Karte
jetzt nicht mehr" verfügbar — dafür reicht die direkte SQL-Bestätigung
des vorherigen Lecks plus die triviale Filterbedingung).

**Kanban-Spiegelung, Denkweg:** der Fix warf die Frage auf, wie die
ursprünglich angedachte Termin-Einladung↔Kanban-Verknüpfung (Eingelade-
ner sieht/bearbeitet eine schreibgeschützte Kanban-Karte, kann von dort
absagen) jetzt funktionieren soll, da eine Einladung nicht mehr "for
free" über die bestehende Gilden-Kontaktfreigabe sichtbar sein kann —
noch am selben Tag als gezielte Ausnahme gebaut (Migration
`20260819150000_termin_einladung_kanban_spiegel.sql`, aktueller Stand:
CLAUDE.md). Per Testlauf mit einer reinen Freundschaft ohne
Gildenfreigabe bestätigt: kein Zugriff, keine Karte.

**Dabei ein echter, vorbestehender Bug gefunden und behoben** (Migration
`20260819160000_termin_einladung_absage_nach_annahme_fix.sql`):
`respond_to_termin_invitation()` erlaubte eine Antwort nur noch,
solange `status='offen'` war — das blockierte nicht nur den neuen
"Termin absagen"-Knopf, sondern denselben, schon länger bestehenden
"Aus meinem Kalender entfernen"-Weg im Kalender selbst (beide rufen
die Funktion mit `p_accept=false` auf einer bereits `status=
'angenommen'`-Einladung auf) — vermutlich nie mit einer wirklich schon
angenommenen Einladung durchgetestet. Fix: Annehmen bleibt nur aus
`'offen'` möglich, Ablehnen jetzt sowohl aus `'offen'` als auch
nachträglich aus `'angenommen'` (aktueller Stand, implizit in der
"Termin-Einladungen"-Beschreibung in CLAUDE.md).

Beide Migrationen vorab per `begin`/`rollback`-Wrapper mit echten
Nicht-Admin-Testprofilen verifiziert, danach per Nutzer-Go gepusht.
Zusätzlich ein echter Ende-zu-Ende-Test mit Playwright gegen den echten
Account (testweise reale Einladung zwischen zwei echten Profilen
aufgebaut, danach vollständig wieder entfernt): Spiegelkarte erscheint
korrekt mit Organisator-Namen, nicht ziehbar, "Termin absagen" entfernt
Kalendereintrag UND Karte im selben Zug, keine Konsolenfehler, 0
Testdaten-Reste danach bestätigt.

**Gildenleben-Fundament, Entstehung:** löst den seit 2026-08-17 als
nächsten Einstieg bestätigten "Gildenleben"-Quest-Typ — nach
ausführlicher Konzept-Diskussion mit dem Nutzer (Langfassung: Claudes
Erinnerung `project_gildenleben_konzept`), in vier Schritten gebaut,
alle noch am selben Abend fertig: Schritt 1 (Datenbank-Fundament,
Migration `20260819180000_gildenleben_teamziele_fundament.sql`) vorab
per `begin`/`rollback`-Wrapper mit echten Profilen getestet
(Summenbildung über einen echten Testverkauf bestätigt, Duplikat-
Schutz bestätigt, ein gildenfremdes Profil sowohl von der
Summenabfrage als auch von der Vergabe zuverlässig ausgeschlossen),
danach per Nutzer-Go gepusht. Schritt 2 (Migration
`20260819200000_gildenleben_teamziele_beispiele.sql`): die zwei
Beispiel-Team-Ziele sind **explizit als Testwerte markiert, kein
echtes Geschäftsziel** — es gab beim Schreiben noch keine einzige
eingetragene individuelle Planung (`profiles.planung_*` komplett leer,
vorher geprüft), daher keine "×10"-Ableitung aus echten Werten
möglich, nur runde Platzhalter. Schritt 3: die zwei neuen Frontend-
Funktionen. Schritt 4: der Gilde-Seiten-Umbau — **wichtige
Randbedingung, vom Nutzer bestätigt:** "die Seite kann so bleiben wie
heute" für alle, die noch in keiner Gilde sind (5 von 7 echten
Profilen zu dem Zeitpunkt).

**Reihenfolge-Bug beim ersten Testlauf gefunden und behoben:** die
Gebäude-Anzeige wurde vor der Team-Ziele-Auswertung gerendert — bei
genau der Erfüllungs-Runde eines Ziels zeigte das Gebäude deshalb noch
den alten Stand (der neue Protokoll-Eintrag existierte zu dem
Zeitpunkt noch nicht). Reihenfolge in `loadGuildState()` korrigiert:
erst `renderGuildTeamQuests()` (prüft/vergibt), dann erst
`renderGuildBuilding()` (liest den ggf. gerade neuen Stand).

End-to-end per Playwright gegen den echten Account verifiziert:
Gebäude-/Reiter-/Team-Ziele-Anzeige korrekt, Reiter-Umschaltung
funktioniert, Freunde-Karte landet korrekt im Reiter. Danach ein
echter, großer Test-Verkauf eingefügt (Lebensversicherung, 600.000 €
BWS) — Team-Ziel schaltete korrekt auf ✅, Gebäude sprang korrekt auf
"Kleine Hütte", wiederholtes Neuladen erzeugte keinen zweiten
Protokoll-Eintrag (Duplikat-Schutz bestätigt). Test-Verkauf, -Kontakt,
-Produkt und der dadurch entstandene Protokoll-Eintrag danach
vollständig entfernt, Seite zeigt wieder exakt den Ausgangszustand.

**Aktionsleiste-Politur, noch am 2026-08-20:** die "+ hinzufügen"/
"Gilde verlassen"-Aktionsleiste saß vorher OBERHALB des Mitglieder/
Freunde-Reiters, wirkte für beide Reiter gleichermaßen gültig —
verwirrend, weil "hinzufügen" im Mitglieder-Kontext (nur
Gildenführer) etwas anderes meint als "hinzufügen" im Freunde-Kontext
(das dort schon existierende Freunde-Suchfeld, für jeden sichtbar).
Reine HTML-Verschiebung, keine neue Logik (aktueller Stand: CLAUDE.md)
— per Playwright gegen den echten Account (Gründer-Rolle) verifiziert,
Desktop + Mobile, keine Konsolenfehler.
