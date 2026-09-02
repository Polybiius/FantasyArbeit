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

## 2026-08-03 bis 2026-08-14: BWS-Verrechnung, Entstehung + Rework

**Nachträglich beim Häppchen-12-Durchgang eingefügt (2026-08-23):** die
"Bewusst aufgeschobene Ideen"-Liste in CLAUDE.md enthielt bis dahin
noch die komplette, 168 Zeilen lange Original-Beschreibung dieser
Funktion mit der Einleitung "Formel jetzt bekannt, noch nicht gebaut" —
faktisch falsch, da die Funktion längst fertig gebaut, live UND am
2026-08-14 grundlegend überarbeitet worden war (bestätigt gegen den
echten Code: `PRODUCT_ART_CONFIG`, `profiles.lv_prozent_satz`/
`pma_suh_satz`/`pma_kv_satz` existieren, `sales.bewertungssumme` wird
nicht mehr beschrieben). Klassischer Fall eines später nie
zurücksynchronisierten Abschnitts, gleiche Bug-Klasse wie der Profil-
Onboarding/Aussehen-Screen-Widerspruch aus Häppchen 2 und der
Verkaufsstatistik-Fund aus Häppchen 2 — hier nur besonders groß, weil
zwei ganze Baurunden (2026-08-03 und 2026-08-14) nie in den "aktueller
Stand"-Text zurückgeflossen sind. Der alte, jetzt entfernte Text (169
Zeilen, ursprünglicher Excel-Auslese-/Formel-Bau-Bericht vom
2026-08-03) liegt zur Vollständigkeit als Rohtext bei Bedarf im
Commit-Diff dieses Häppchens. Die korrigierte, aktuelle Fassung steht
jetzt als eigener Abschnitt "BWS-Verrechnung: Provision &
Bewertungspunkte" in CLAUDE.md (vorher fälschlich unter "Bewusst
aufgeschobene Ideen" einsortiert).

**Kurzfassung der Entstehung** (volle Details in Claudes Erinnerung
`project_bws_verrechnung`, dort bereits mit dem "Stand 2026-08-14"-Fazit
dokumentiert — hier nur die Eckpunkte, damit HISTORY.md eigenständig
lesbar bleibt): am 2026-08-03 lieferte der Nutzer seine bestehende Excel
(`~/Schreibtisch/Projekt.xlsm`, 14 Blätter), Claude Code las sie
vollständig aus (ZIP+XML, ohne Excel/openpyxl), Formel + Datenmodell
(Patch 30) + Einstellungen-Seite (Patch 31) + Kompendium-Dashboard
entstanden in derselben Session. Am 2026-08-14 räumte der Nutzer ein,
dass er Claude die Excel anfangs "ohne ausreichende Rückfragen" hatte
interpretieren lassen ("das war doof von mir") — daraufhin ein
grundlegender Rework in einer eigenen Session, Stück für Stück mit
expliziter Rückfrage vor jeder Änderung: Produktanlage radikal
vereinfacht (nur noch Name+Art), PMA-Sätze zu echten persönlichen
Feldern gemacht (vorher fest im Produkt verbacken — ein Fehler
gegenüber der Excel), Leben-Satz von ‰ auf % umgestellt, Bewertungs-
summe (Leben) wird seitdem live aus dem Beitrag berechnet statt manuell
erfasst, Stückzahl-Feld komplett entfernt. Dabei drei echte,
vorbestehende Bugs beim Live-Testen mit dem Nutzer gefunden und
behoben (Verkaufs-Popup verwarf einen Verkauf still ohne "+ Produkt
hinzufügen", `kanban_stage` wurde beim Verkauf-Eintragen auf der
Kontakt-Seite nie gesetzt, offene Kontakt-Seite zeigte neue Verträge
erst nach manuellem Reload, ein Modal-Stapel-Bug, eine CSS-Lücke bei
`<select>`-Elementen in `.kanban-newlead-form`). Alles per Playwright
end-to-end gegen die echte DB verifiziert (u.a. 150€ Beitrag → 54.000€
BWS → 1.350€ Provision bei 2,5% → 810€ Differenzprovision, exakt
nachgerechnet).

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

**Termin-Einladungen-Robustheit, noch am 2026-08-19:** zwei kleine
Unschärfen behoben, Migration
`20260819120000_termin_einladungen_robustheit.sql`. Vor dem Push mit
echten Nicht-Admin-Testprofilen (nicht dem eigenen Admin-Account — der
erste Testlauf hatte fälschlich den Admin-Bypass mitgetestet und
dadurch nichts bewiesen) in einer `begin`/`rollback`-Transaktion
verifiziert: Organisator sieht seine stornierte Einladung jetzt über
`organizer_id`, direktes Löschen der Einladungs-Kopie durch den
Eingeladenen ist jetzt RLS-blockiert (nur noch über
`respond_to_termin_invitation()` möglich), eigene normale Termine
bleiben normal löschbar (keine Regression). Aktueller Stand: CLAUDE.md,
Abschnitt "Bekannte, bewusst in Kauf genommene Lücken". Die vom Nutzer
zusätzlich vermutete dritte Unschärfe (offene, noch nicht angenommene
Einladung "verschwindet" beim Empfänger, wenn der Organisator den
Termin löscht) war beim Nachtesten **kein Bug** — funktionierte bereits
korrekt (Status wechselt sichtbar auf "storniert").

## 2026-08-20: Aufgaben-System (Patch 51) + Code-Review-Durchgang

**Aufgaben-System, Entstehung:** löst den seit 2026-08-09 unter
"Bewusst aufgeschobene Ideen" notierten Wunsch "Outlook-artige
abhakbare Aufgaben" — nach ausführlicher Konzept-Diskussion (Nutzer
beschrieb genau das Outlook-Verhalten: Aufgaben mit Termin, Abhaken
lässt sie verschwinden). Migration `20260820120000_aufgaben_system.sql`.
End-to-end per Playwright gegen den echten Account verifiziert: Aufgabe
anlegen ohne/mit Datum, Abhaken löscht sofort, überfällige Aufgabe rot,
Doppelklick springt korrekt in den Tag-Reiter, kein horizontales
Overflow auf 390px nach dem `min-width:0`-Fix, keine Konsolenfehler —
sowie der komplette Wiedervorlage-Ablauf über einen echten Testkontakt
(Anlegen mit Datum → Aufgabe erscheint → Datum ändern → alte Aufgabe
verschwindet, neue erscheint am neuen Tag → Testkontakt/-aufgabe
wieder entfernt).

**Nachtrag 1:** Nutzer-Bugreport ("Systemuhr auf 2027-06-10
vorgestellt, Kundengeburtstag taucht nirgends auf, auch nicht im
Kalender") — Ursache war die eigene Einstellung
`calendar_show_birthdays` (aus), per direkter SQL-Prüfung bestätigt
(Kontaktdaten selbst waren korrekt). Dabei eine echte, zusätzliche
Lücke gefunden: das Umschalten von "Geburtstage anzeigen" wirkte
bisher nur auf die alten, rein clientseitig berechneten Kalender-
Punkte, nicht auf die neuen echten Aufgaben-Zeilen — die hätten erst
beim nächsten Tageswechsel oder Neuladen nachgezogen. Fix (aktueller
Stand: CLAUDE.md) per Playwright mit gefälschter Browser-Systemuhr
(`context.addInitScript()`, `Date` auf 2027-06-10 überschrieben)
verifiziert: Aufgabe UND Kalender-Punkt erscheinen korrekt am
gefälschten Datum, Umschalten des Häkchens entfernt/erzeugt die
Aufgaben-Zeile sofort ohne Neuladen.

**Nachtrag 2, zwei Bugs beim manuellen Vorausblättern gefunden:**
(1) Monat/Woche/Tag hatten je ihr eigenes, unabhängiges Datum —
Doppelklick auf einen Tag in der Zukunft zeigte in der Tagesansicht
korrekt diesen Tag, sprang aber beim Wechsel zu Woche/Monat zurück auf
die aktuelle Woche/den aktuellen Monat, "inkonsistent". Behoben durch
die gemeinsame `calFocusDate`-Variable (aktueller Stand: CLAUDE.md) —
betraf strukturell auch Monat↔Woche schon vor dem Tag-Reiter, fiel
dort nur nie auf. (2) Ein an einem NICHT-heutigen Tag liegender
Geburtstag fehlte in der Aufgaben-Liste komplett, obwohl der alte
Kalender-Punkt ihn längst zeigte — die alten Punkte rechnen live für
jedes Datum, die neuen Aufgaben-Zeilen entstehen aber nur für den
echten heutigen Tag. Behoben durch die nicht-abhakbare Vorschau-Zeile
(aktueller Stand: CLAUDE.md). Reiner Diagnose-Fund nebenbei (kein
Bug): `calendar_show_birthdays` stand im echten Account zwischenzeit-
lich wieder auf "aus" — für den Test wieder eingeschaltet. Per
Playwright verifiziert (Vorblättern 10 Monate, Doppelklick auf
10.06.2027, Wechsel Tag→Woche→Monat→Heute): alle drei Ansichten
zeigen konsistent den 10.06.2027 bzw. Juni 2027, "Heute" springt
zuverlässig zurück, Geburtstags-Vorschau erscheint korrekt ohne
Checkbox/Aufgaben-ID, keine Konsolenfehler.

**Nachtrag 3, Reload-Persistenz:** Nutzerwunsch, klar begründet: "ich
bin bei einem Datum, trage dort was ein, lade neu, soll dort bleiben —
für 'heute' hab ich ja den Knopf." Löste das dritte Hash-Format
(aktueller Stand: CLAUDE.md). Beim Umsetzen zwei echte Race-Bugs
gefunden und behoben, beide Folge davon, dass `initJournal()` in
`enterApp()` bewusst unawaited aufgerufen wird (damit der restliche
Login-Ablauf nicht auf das Tagebuch warten muss): die Kalender-
Grundvariablen wurden bisher erst nach dem ersten `await` in
`initJournal()` gesetzt — je nach Netzwerk-Timing konnte
`restoreLastPage()` (das per Hash `calFocusDate` auf einen fremden Tag
setzt) vorher laufen, die wiederhergestellte Ansicht dann beim
späteren Fortsetzen still wieder auf "heute" zurückwerfen; jetzt steht
der komplette Block ganz am Anfang, vor dem ersten `await`. Ein
unbedingtes `renderCalendar()` am Ende von `initJournal()` überschrieb
außerdem die schon korrekt wiederhergestellte `calMonthLabel`-
Kopfzeile wieder mit dem Monat von "heute" — jetzt modusabhängig
(`renderDayView`/`renderWeekView`/`renderCalendar`). Beide Bugs wurden
erst durch einen echten End-to-End-Test mit tatsächlichem Seiten-
Reload sichtbar, nicht durch Code-Lesen — per Playwright verifiziert:
Doppelklick auf 10.08.2027 → Aufgabe eintragen → echter Reload →
Tag-Reiter, Datum UND Aufgabe korrekt erhalten; Wochenansicht-Wechsel
→ Reload → richtige Woche erhalten; normale Seiten-Navigation bleibt
unberührt; "Heute"-Knopf springt weiterhin zuverlässig zurück.

**Code-Review-Durchgang übers gesamte `index.html`, Patch-Nachtrag:**
auf Nutzeranstoß ("wo gehobelt wird fallen Späne", nach einer Session
mit sehr viel neuem Code auf einmal) `/code-review high` gegen die
komplette `index.html` laufen lassen (5 parallele Hintergrund-Agenten:
Altitude/Konventionen, Wiederverwendung/Effizienz, Cross-File-Tracing,
Zeile-für-Zeile-Diff-Scan, entferntes-Verhalten-Audit). Alle 9
gemeldeten Funde vor dem Weiterreichen selbst gegengeprüft (nicht
blind übernommen), 3 als echte, spürbare Bugs eingestuft und sofort
behoben, jeweils per Playwright end-to-end verifiziert:

1. **Reiter-Wechsel verwarf den gerade erst gebauten Kalender-Hash** —
   ein normaler Klick auf "Abenteuerlog" rief `showPage('tagebuch')`
   ohne den `updateHash`-Schutz auf, wodurch `location.hash` stumm auf
   das generische `#tagebuch` zurückfiel. Fix: der Nav-Klick-Handler
   behandelt `tagebuch` als Sonderfall (`showPage('tagebuch', false)`
   + `updateCalendarHash()`).
2. **Termin speichern/löschen aus der Tagesansicht aktualisierte die
   sichtbare Tagesansicht nie** — vier Stellen riefen immer
   `renderWeekView(false)`/`renderCalendar()`, nie `renderDayView()`.
   Alle vier nutzen jetzt einheitlich `renderCalTasksNow()` (bereits
   vorhandener 3-Wege-Dispatcher).
3. **Kontakt mit offener Wiedervorlage löschen hinterließ eine
   Aufgaben-Karteileiche für immer.** Erster Fix-Versuch (Aufräumen
   NACH dem Löschen) griff im Playwright-Test nachweislich NICHT —
   Ursache: die `ON DELETE SET NULL`-Fremdschlüsselregel auf
   `tasks.contact_id` setzt die Spalte schon im selben Löschvorgang
   auf `NULL`, `syncWiedervorlageTask()` findet die Zeile über
   `contact_id` danach nicht mehr. Reihenfolge umgedreht (die daraus
   gezogene, generalisierbare Lehre steht jetzt dauerhaft im
   Aufgaben-System-Abschnitt in CLAUDE.md).

**Bewusst zurückgestellt** (kleinere, im selben Durchgang gefundene
Punkte, kein akuter Nutzer-Schmerz — Stand der Zurückstellung, einige
inzwischen behoben, siehe jeweils referenzierte Abschnitte): veraltete
Kopfzeile beim Wechsel Tag→Woche; die Zeitzonen-Inkonsistenz zwischen
`dateKeyLocal()` und `todayKey()` (vollständig behoben, 2026-08-21,
Commit `ca8d896`, siehe CLAUDE.md-Abschnitt "Zeitzonen-Inkonsistenz");
doppeltes Laden beim Login mit gespeichertem Kalender-Hash; spürbare
Code-Duplikation zwischen `renderDayView()` und `renderWeekView()`;
eine tote `.task-contact-icon`-CSS-Regel; ein vorbestehender (nicht
neu eingeführter, nur durch den Umbau vergrößerter) Listener-Stapel-
Bug bei mehrfachem `enterApp()`-Aufruf über die Admin-Debug-Funktion
"🎭 Neu erschaffen".

## 2026-08-21/22: Systematischer Bugfix-Durchgang übers gesamte `index.html`, in Häppchen

Nutzerwunsch: "die Bugfixes des GANZEN Systems in angemessen große
Häppchen kleinteilen und schon mal anfangen — soll mit meinem Claude Pro
Kontingent passen." Direkter Nachfolger des Code-Review-Durchgangs vom
2026-08-20 (siehe oben) — dort lief EIN `/code-review high`-Durchgang mit
5 parallelen Hintergrund-Agenten über die ganze Datei auf einmal. Diesmal
bewusst in 12 kleinere Häppchen zerlegt (nach den bestehenden
`// ----`-Abschnittsmarkierungen im `<script>`-Block), über mehrere
Sitzungen verteilt abgearbeitet, damit ein einzelner Durchgang nicht das
ganze Nutzungskontingent einer Sitzung verbraucht. **Methodik-Anpassung:**
der `code-review`-Skill reviewt standardmäßig nur den aktuellen Diff, auch
mit Datei-Pfad als Zusatzargument — für einen Vollständigkeits-Audit von
bereits committetem Code laufen stattdessen pro Häppchen 5 selbst
formulierte, parallele Hintergrund-Agenten (Agent-Tool) mit fünf festen
Blickwinkeln: **Korrektheit/Logikfehler, Wiederverwendung/Effizienz,
Cross-File-Konsistenz (JS↔SQL/RPC), akribischer Zeile-für-Zeile-Scan,
totes/inkonsistentes Verhalten** — jeder gemeldete Fund wird vor dem
Fixen selbst im Code gegengeprüft, nicht blind übernommen. Laufender
Fortschritt/Häppchen-Einteilung: siehe Erinnerung
`project_full_bugfix_sweep` (Claude), nicht hier — dieser Abschnitt hält
nur die tatsächlich gefundenen und behobenen Bugs fest.

**Häppchen 1 (Fundament/Onboarding, Commit 713ee4d):**
`enterProfileOnboarding()` (Alt-Account-Nachtrag + Admin-"Neu erschaffen")
wählte die Klasse beim Fortsetzen eines bestehenden Profils nicht vor —
ein Klick auf eine andere Klassenkarte hätte `character_class` entgegen
"einmalig, dauerhaft" überschreiben können. Behoben: Klasse wird jetzt
aus dem bestehenden Profil vorausgewählt.

**Häppchen 2 (Sigil/Aktionsraster/Questbaum-Engine, Commits 2bc429a +
c89e135):**
- `lastQuestActivity()` verglich `action_key` per strikter Gleichheit,
  obwohl `metric.denominator` bei Ratio-Quests laut eigenem Code-Kommentar
  auch ein Array sein darf (z.B. anruf_erreicht/nicht_erreicht) — solche
  Ketten hatten dadurch immer `lastActivity:null` und rutschten in der
  Questbaum-Schnellansicht fälschlich ans Ende. Fix: nutzt jetzt
  `questActionMatches()` wie der Rest der Engine.
- `logTallyAction()` (5er-Anruf-Zähler) setzte den Zähler VOR dem
  RPC-Aufruf zurück — schlug der Aufruf fehl, gingen alle 5 gesammelten
  Taps stillschweigend verloren. Fix: Reset erst nach Erfolg.
- `drawSigil()` hatte einen nie gelesenen `totalXp`-Parameter (tote
  Signatur seit der Umstellung auf eine feste, vom Gesamt-XP unabhängige
  Obergrenze) — entfernt, inkl. einer dadurch überflüssigen Summierung in
  `openFriendSigil()`.
- **Kanban-Kanal-Nachtrag schlug seit der RLS-Härtung vom 2026-08-15 immer
  still fehl:** `attachKanalToLoggedAction()` versuchte ein direktes
  `.update()` auf `action_log`, wofür es seitdem keine Schreib-Policy mehr
  gibt. Per Drag&Drop auf eine BESTEHENDE Kanban-Karte gebuchte Termine
  bekamen dadurch nie einen Kanal (online/büro/betrieb) ins Log und
  fielen aus den Kanal-Questbaum-Ketten heraus. Neue Migration
  `20260821120000_action_log_kanal_nachtrag_rpc.sql` fügt
  `attach_kanal_to_own_action()` als SECURITY-DEFINER-RPC hinzu (mergt
  `meta.kanal` statt zu überschreiben, feste Kanal-Erlaubnisliste) —
  selbes Härtungsmuster wie `log_action_for_self()`. Per
  `begin`/`rollback`-Dry-Run mit drei Testfällen verifiziert, dann per
  Nutzer-Go gepusht.

**Häppchen 3 (Zunftbuch/Changelog/Quest-Belohnungen, Commit 8b5df18) —
wichtigster Fund des bisherigen Durchgangs:**
`checkAndAwardEpics()` gab beim ALLERERSTEN Check einer Sitzung
(`celebratedEpicIds===null`) sofort komplett auf, VOR der eigentlichen
Vergabe-Schleife — der Code-Kommentar sagte explizit, das solle NUR die
Feier-Animation unterdrücken, nicht die XP-Vergabe. Tatsächlich bekam
dadurch JEDES zu diesem Zeitpunkt schon erfüllte Epic nie seinen Bonus
(100–800 XP laut Regelwerk) — dauerhaft, seit Patch 50 (2026-08-17), weil
ein bereits erfülltes Epic sofort in den neuen Sitzungs-Baseline-Snapshot
wandert und dadurch für immer als "schon gesehen" gilt. Fix: die
Vergabe-Schleife läuft jetzt immer (weiterhin durch lokalen +
serverseitigen Duplikat-Schutz abgesichert), nur der Toast wird beim
ersten Sitzungs-Check ausgelassen — betroffene Nutzer bekommen die
ausstehende XP beim nächsten Login nachgezahlt. Zweiter, kleinerer Fund:
`checkAndAwardRecurringQuests()` fehlte beim Login (`enterApp()`), obwohl
alle 6 anderen Aufrufstellen alle drei Quest-Check-Funktionen zusammen
aufrufen — ergänzt.

**Häppchen 4 (Tagebuch/Abenteuerlog + Aufgaben-System, Commit fbb2ed4):**
- `refreshDotForDate()` entfernte nur den ERSTEN `.dot` statt des ganzen
  `.cal-day-dots`-Wrappers — an Tagen mit mehreren Punkt-Typen (Termin +
  Wiedervorlage/Geburtstag) gleichzeitig blieb beim nächsten Tagebuch-/
  Foto-Save der Rest-Punkt als Karteileiche stehen, während ein zweiter,
  kompletter Wrapper danebengesetzt wurde (sichtbar doppelte Punkte). Fix:
  entfernt jetzt den ganzen Wrapper vor dem Neu-Einfügen.
- `syncWiedervorlageTask()`/`syncBirthdayTasksIfNeeded()` prüften den
  Rückgabewert ihrer `.delete()`-Aufrufe nicht, entgegen der sonstigen
  Projekt-Konvention — schlug das Löschen fehl, blieb die alte Aufgabe
  unbemerkt als Karteileiche stehen, genau der Fall, den
  `syncWiedervorlageTask()` laut eigenem Kommentar verhindern soll. Fix:
  beide Aufrufe loggen jetzt über `logSilentError()`.
- `syncBirthdayTasksIfNeeded()` bekam zusätzlich einen einfachen
  In-Flight-Schutz gegen echte Überlappung innerhalb derselben Sitzung
  (z.B. schneller Doppelklick auf den Geburtstage-Schalter in den
  Einstellungen) — der rein clientseitige `tasks_synced_date`-Check
  allein greift erst nach mehreren `await`-Punkten.
- `startTaskDayRolloverWatcher()` bekam einen Mehrfachaufruf-Schutz (2x
  unabhängig von den Review-Agenten gefunden) — ohne ihn häufte der
  Admin-Debug-Knopf "Neu erschaffen" bei jedem Durchlauf ein weiteres
  paralleles 5-Minuten-Intervall plus weitere
  `visibilitychange`/`focus`-Listener an.

**Korrektur, noch am selben Tag:** die reinen Effizienzfunde (mehrfache
Neuberechnung, doppelte Lookups, sequenzielle statt parallele
Ladeaufrufe) waren hier ursprünglich als "bewusst nicht angefasst"
protokolliert ("bei der aktuellen Datenmenge nicht spürbar"). Der Nutzer
hat das ausdrücklich zurückgewiesen — Effizienz-/Aufräumfunde aus einem
Review werden ab sofort standardmäßig mitgefixt, nicht selbst als
"lohnt sich noch nicht" abgewertet (siehe Erinnerung
`feedback_fix_efficiency_findings_dont_defer`). Alle in Häppchen 2-4
gefundenen Effizienzfunde wurden daraufhin nachträglich umgesetzt:
`logInCurrentYear()` memoisiert, `matchingSalesForArt()`/
`isBirthdayOn()`-Helfer lösen Code-Dopplung auf, Streak-Totals
(`dailyActionTotals`/`weeklyActionTotals`) werden pro Kette einmal statt
pro Stufe neu aufgebaut, `computeQuestTreeStages()` +
`checkAndAwardQuestTreeAndEpics()` + `grantQuestTreeStageBonus()`
bündeln die vorher mehrfach unabhängig traversierte Questbaum-Auswertung,
`renderCalendar()`/`showDayPreview()` laden per `Promise.all` parallel,
`initJournalMentions()` nutzt einen delegierten statt fünf einzelner
Klick-Listener. Alle Aufrufstellen einzeln nachverfolgt, ESLint +
Syntax-Check sauber, keine Verhaltensänderung. Die damals bewusst
zurückgestellte Zeitzonen-Inkonsistenz (`dateKeyLocal()` vs.
`todayKey()`) — anders als die Effizienzfunde eine echte, wenn auch
seltene Verhaltens-Abweichung, die der Nutzer bewusst gebündelt statt
Stelle für Stelle angehen wollte — ist seit 2026-08-21 vollständig
behoben, siehe eigener Abschnitt unten.

**Nachtrag, noch am selben Tag:** ein letzter zurückgestellter Fund
(doppelter `journal_entries`-Schreibzugriff in `confirmMention()` —
ein eigener sofortiger Upsert fürs @mention-Fremdschlüssel-Erfordernis
UND derselbe Schreibvorgang nochmal 700ms später über den Tagebuch-
Debounce) wurde dem Nutzer als echter Grenzfall vorgelegt (Fix würde den
vielgenutzten Debounce-Mechanismus anfassen, Gewinn klein). Antwort:
"das was langfristig am besten ist. irgendwann werden tausende Menschen
das System nutzen. programmier es dementsprechend." Der eigentliche
Speicher-Code ist jetzt in `saveJournalEntryNow()` extrahiert — sowohl
der Debounce (`scheduleJournalSave()`, Tippen) als auch `confirmMention()`
(sofort, kein Debounce bei einem einzelnen Klick sinnvoll) rufen dieselbe
Funktion auf. Ergebnis: nur noch EIN Schreibzugriff pro @mention-
Bestätigung statt zwei, plus sofortiges "gespeichert"-Feedback/Kalender-/
Serien-Update statt erst nach 700ms verzögert. Tiebreaker-Regel für
künftige ähnliche Grenzfälle (sicherer Fix möglich, nur Aufwand/kleiner
Gewinn heute dagegen): langfristige Nutzerzahl-Perspektive gewinnt,
"reicht für jetzt" wird nicht akzeptiert — siehe Erinnerung
`feedback_fix_efficiency_findings_dont_defer`. Gilt nur für Code-
Sauberkeit innerhalb der bestehenden Architektur, keine Abkehr vom
"nicht vorbeugend optimieren"-Prinzip bei echten Infrastruktur-
Entscheidungen (siehe "Technische Skalierungs-Schwellen" oben).

**Häppchen 5 (Inventar/Freunde/Gilde-Basics/Kontakte-Einstieg, Commit
9a05d3d, 2026-08-21):**
- Admin-Klassenschalter aktualisierte `updateKanbanLabels()` nicht mit —
  Nav-Button/Seitenüberschrift des Kanban blieben nach einem Klassenwechsel
  auf dem alten Begriff stehen (z.B. "Questpfad" statt "Gildenbrett"), bis
  die Seite neu geladen wurde, während alle fünf anderen abhängigen
  Update-Aufrufe korrekt liefen. Ergänzt.
- `createSpriteRenderer()` (die animierte Sprite-Technik hinter jedem
  bewegten Avatar) startete pro Aufruf ein `setInterval`, das nie gestoppt
  wurde — echter, unbegrenzt wachsender Leak: jedes Neu-Rendern der
  Freundes-/Gildenkacheln (nach Annehmen/Entfernen einer Freundschaft,
  neuer Anfrage) ersetzte die Canvas-Elemente per `innerHTML`, ihre alten
  Animations-Timer liefen aber unsichtbar für die längst entfernten
  Elemente weiter. Fix: `createSpriteRenderer()` gibt jetzt zusätzlich
  `stop()` zurück, `mountAvatarTile()` merkt sich das pro Canvas
  (`canvas._stopSprite`), neuer Helfer `stopGridAvatarRenderers(gridEl)`
  wird vor jedem `innerHTML`-Ersatz in `renderFriendGrid()` UND
  `renderGuildMembers()` aufgerufen (gleicher Helfer, beide Stellen
  betroffen).
- `syncProfileStatsCache()` übernahm `profile.total_xp`/`level` lokal,
  BEVOR der `sync_own_level_cache()`-RPC-Aufruf sein Ergebnis kannte —
  schlug der Sync fehl, verhinderte der Kurzschluss-Guard beim nächsten
  Aufruf mit denselben (unveränderten) Werten jeden weiteren Versuch
  innerhalb derselben Sitzung. Fix: lokale Übernahme erst nach
  bestätigtem RPC-Erfolg.
- `openFriendSigil()` setzte den Modal-Titel sofort, ließ aber bei einem
  RPC-Fehler (`friend_skill_totals`) das SVG der zuvor geöffneten Person
  unverändert stehen — Titel und Sigil-Inhalt konnten dadurch
  auseinanderdriften. Fix: bei Fehler wird das Sigil jetzt explizit auf 0
  zurückgesetzt statt den alten Stand zu behalten.

Cross-File-Agent (JS↔SQL/RPC) fand in diesem Häppchen ausnahmsweise
**keine** Diskrepanzen — alle Aufrufe gegen `user_inventory`/`profiles`/
`friends`/die RPCs stimmten mit den tatsächlichen Migrationen überein.
Effizienzfunde direkt mitgefixt (kein Zurückstellen mehr, siehe
`feedback_fix_efficiency_findings_dont_defer`): Doppelklick-Schutz bei
Inventar-Buttons (`btn.disabled` synchron vor dem `await`, damit ein
zweiter Klick während eines laufenden RPC-Aufrufs nicht doppelt feuert),
`initFriends()` lädt Anfragen+Freundesliste jetzt per `Promise.all`
parallel statt sequenziell, `searchFriendByName()`s zwei sequenzielle
"gibt es schon eine Freundschaft"-Abfragen (eine je Richtung) zu einer
einzigen `.or()`-Abfrage zusammengefasst (Muster von `removeFriend()`
übernommen), ungenutztes `character_class` aus `AVATAR_PROFILE_FIELDS`
entfernt (in beiden Konsumenten nie gelesen — der Avatar rendert nur aus
den Sprite-Layer-Feldern).

Per Playwright gegen den echten Account verifiziert: Klassenwechsel zeigt
den Kanban-Label-Fix live, danach korrekt auf die Ausgangsklasse
zurückgesetzt; Doppelklick auf einen Ausrüstungs-Button löst keine
Exception aus; Sigil-Modal öffnet korrekt; drei Reiter-Wechsel zwischen
Charakter- und Gilde-Seite ohne Fehlerhäufung; 0 Konsolenfehler
durchgehend. Ein durch den Doppelklick-Test versehentlich ausgezogenes
Holzschwert wurde danach wieder angezogen, Testzustand exakt
wiederhergestellt.

**Häppchen 6a (Verkaufsstatistik + Schatzraum, Commit 284b48e,
2026-08-21) — Häppchen 6 wegen Kontingent-Sorge in 6a/6b gesplittet,
siehe Erinnerung `project_full_bugfix_sweep`:**
- `renderStatCategoryChart()` escapte den admin-editierbaren
  Produktkategorienamen an drei Stellen nicht — Legende,
  Balkenbeschriftung, UND das `title`-Attribut (dort am gefährlichsten,
  Ausbruch aus dem Attribut-Kontext möglich). Echte, ausnutzbare
  Stored-XSS-Lücke, gleiche Klasse wie der Sicherheits-Durchgang vom
  2026-08-07/die `locName()`-Lücke vom 2026-08-11 — und **keine**
  `rule_configs`-Ausnahme, da `products.category` über das In-App-
  Produktformular gepflegt wird, nicht per SQL-Editor. Fix: `escHtml()`
  an allen drei Stellen ergänzt.
- Der Schatzraum sprang beim Wiederöffnen nicht mehr aufs laufende Jahr
  zurück, wenn zuvor per Vor/Zurück navigiert wurde — `trophyRoomYear`
  wurde beim Öffnen nie zurückgesetzt, entgegen dem eigenen
  Code-Kommentar ("heute ist der naheliegende Startpunkt"). Fix: Klick-
  Handler setzt `trophyRoomYear = currentBusinessYear()` vor dem Öffnen.
- Drei Stellen (`salesForPeriod()`, `trophyRoomYear`-Initialisierung,
  `renderStatTabs()`) nutzten `new Date().getFullYear()` statt dem im
  selben Feature-Bereich bereits vorhandenen `currentBusinessYear()`-
  Helfer — vereinheitlicht (reiner Cleanup, keine Verhaltensänderung).

Effizienz direkt mitgefixt: `renderStatistikPage()` filterte für die 12
Monats-Sparklines bisher den KOMPLETTEN `mySalesCache` zwölfmal neu nach
Jahr+Monat, obwohl die bereits jahresgefilterte `salesList` längst da
war — jetzt ein einziger Durchlauf, der `salesList` in 12 Monats-Buckets
aufteilt. `enterApp()` lud Produkte/Ortstypen/eigene Verkäufe bisher
sequenziell, obwohl es drei unabhängige Tabellen-Reads ohne
gemeinsamen Zustand sind — jetzt per `Promise.all` parallel, spart zwei
Netzwerk-Rundlaufzeiten bei jedem Login.

**Zwei Funde bewusst NICHT selbst entschieden, liegen dem Nutzer vor:**
1. Der Cross-File-Agent fand eine SQL-Lücke: `products_provision_mode_
   check` erlaubt nur `'fest'`/`'individuell_lv'`/`'individuell_kv'`,
   obwohl `PRODUCT_ART_CONFIG` (Zeile ~8394) für die Arten pmaSUH/pmaKV
   seit dem BWS-Verrechnungs-Rework (2026-08-14) bereits
   `'individuell_pma_suh'`/`'individuell_pma_kv'` setzt — ein Admin, der
   ein Produkt dieser beiden Arten anlegt, bekommt seither zwingend eine
   CHECK-Constraint-Verletzung. Diese zwei Produktarten waren dadurch nie
   tatsächlich anlegbar, obwohl `saleProvision()` längst vollständig
   dafür vorbereitet ist. Migration
   `supabase/migrations/20260821140000_products_provision_mode_pma_check_fix.sql`
   liegt bereit (erweitert die Erlaubnisliste um die beiden fehlenden
   Werte, per `begin`/`rollback`-Dry-Run inkl. Testinsert verifiziert) —
   **seit demselben Tag live**, siehe Nachtrag am Ende dieses Abschnitts
   ("Kranken als eigene Sparte").
2. Der Korrektheits-Agent fand eine echte Business-Logik-Frage: der KPI
   "Bewertungsbeitrag sonstige" (`aggregateStats()`, summiert JEDE
   nicht-Leben-Sparte: Kranken+Sach/Hausrat+Kfz+Rechtsschutz+pmaSUH+
   pmaKV+Darlehen zusammen) wird im Fortschritts-Ring gegen
   `profile.planung_kv_mb` gemessen — ein Zielfeld, das in den
   Einstellungen explizit "Planung **Kranken**-Beitrag" heißt und laut
   Platzhaltertext nur das Kranken-Ziel meint. Verkauft ein Nutzer
   überwiegend Sach/Kfz/RS statt Kranken, ist der Ring-Füllstand
   irreführend (zu hoch oder zu niedrig, je nach Mix). Bewusst nicht
   code-seitig entschieden (Kategorie trennen? Zielfeld umbenennen/neues
   Feld für "sonstige" einführen?) — braucht ein Gespräch mit dem Nutzer,
   passt zur bestehenden Linie bei BWS-Verrechnungs-Themen (siehe
   Erinnerung `project_bws_verrechnung`).

Per Playwright gegen den echten Account verifiziert (Statistik-Seite,
Jahr/Monat-Reiter-Wechsel, Schatzraum öffnen/schließen/erneut öffnen,
0 Konsolenfehler). Die eigentlich noch offene Kontakte-Kernseite
(~830 Zeilen, ursprünglich fälschlich als Teil des "Schatzraum"-Blocks
mitgezählt) ist ein eigenes, noch nicht begonnenes Häppchen 6b, siehe
Erinnerung `project_full_bugfix_sweep`.

**Nachtrag, noch am selben Tag: Kranken als eigene Sparte statt in
"Bewertungsbeitrag sonstige" gemischt (Commit `d1277b9`).** Direkte
Nutzerkorrektur zum offen vorgelegten Fund oben — "alles zusammenfassen
macht gar kein Sinn, Kranken muss eine eigene Sparte sein". `aggregateStats()`
summiert jetzt `beitragKranken` (nur `individuell_kv`) getrennt von
`beitragSonstige` (SH/Kfz/RS/pmaSUH/pmaKV/Darlehen). Beide Kartensätze
(Verkaufsstatistik-Seite UND Schatzraum-Zusammenfassung, beide nutzen
denselben `aggregateStats()`-Kern) zeigen seitdem 6 statt 5 Karten — die
neue "Bewertungsbeitrag Kranken"-Karte trägt den Fortschrittsring gegen
`profile.planung_kv_mb`, "sonstige" bleibt eine Karte ohne Ziel (wie
Provision/Differenzprovision). Per Playwright verifiziert (beide Seiten
zeigen korrekt 6 Karten mit Kranken-Trennung, 0 Konsolenfehler). Die
zusätzlich gepushte `products_provision_mode_check`-Migration (Fund 1
oben) wurde im selben Zug per Nutzer-Go angewendet, Commit `e6d5f4b`
(nachträglich, war zunächst nur gepusht, nicht committet — nachgeholt).

**Häppchen 6b-1 (Kontakte-Kernseite, Grundgerüst-Hälfte, Commit `43d15dd`,
2026-08-21) — Zeilen 5291-5695:** vier echte Bugs: Stored-XSS in
`searchLocationSuggestions()` (Betriebs-Suchtext floss ungeescapt in
`innerHTML`, `escHtml()` fehlte genau in der Zeile direkt unter einer
Nachbarzeile, die es korrekt macht); `jumpToJournalDay()` ließ
`calFocusDate`/den Kalender-Hash unangetastet, brach damit das seit dem
"Dritter Nachtrag" (siehe Aufgaben-System-Abschnitt oben) etablierte
Navigations-Muster; `openContactPage()` hatte keinen Staleness-Guard nach
dem asynchronen `loadContactsBundle()` — eine schnelle Doppelnavigation
zwischen zwei Kontakten konnte Anzeige/Edit-Buttons auf den falschen
Kontakt binden; aktiver Detail-Reiter (Chronik/Dateien/Tagebucheintrag)
sprang bei jedem Refresh der Kontaktseite zurück auf "Übersicht",
entgegen der am Refresh-Aufruf dokumentierten Absicht — neue Variable
`currentContactDetailTab` merkt sich den zuletzt gewählten Reiter, wird
nur bei echtem Kontaktwechsel auf "Übersicht" zurückgesetzt. Dazu ein
Listener-Stacking-Fund (`initContactFormToggle()`/
`initContactLocationAutocomplete()` bei jedem `initContacts()`-Aufruf,
erreichbar über den Admin-Debug-Knopf "Neu erschaffen") und drei
Effizienzfunde (`loadContactsBundle()` per `Promise.all`, doppelte
`contact_files`-Zählabfrage entfernt, `betriebCreateBtn`-Doppelklick-
Schutz).

**Häppchen 6b-2 (Kontakte-Kernseite, Tabs/Bearbeiten/Aktionsdialog-
Hälfte, Commit `55b712f`, 2026-08-21) — Zeilen 5702-6138:** fünf echte
Bugs: derselbe Stored-XSS-Fehltyp beim Produktnamen (`products.name`) an
zwei Stellen (Verträge-Zone, Chronik-Verkaufszeilen); `logActionForContact()`/
`openContactActionModal()` hatten keinen Doppelklick-Schutz — ein
schneller Doppelklick konnte die Tages-Energie-Prüfung umgehen (beide
Klicks lasen denselben, noch nicht aktualisierten `log`-Array-Stand) und
dieselbe Aktion doppelt loggen, per Playwright bestätigt behoben
(Energie sank nach Doppelklick nur um den einfachen Wert); `contactAddBtn`
hatte denselben fehlenden Schutz, konnte bei Neuanlage zwei identische
Kontakte erzeugen; Formular-Reset nach dem Speichern vergaß drei
Auswahlfelder (Rolle/Status/Kanban-Stufe) — nach einer Bearbeitung
blieben deren Werte stehen und flossen unbemerkt in den nächsten neu
angelegten Kontakt; toter Copy-Paste-Rest (`bossClass`/`bossIcon`, nie
erreichbar) entfernt. Effizienz: dreifach duplizierter "Kontaktliste +
Detailseite neu rendern"-Ablauf zu einem gemeinsamen
`refreshContactsAndDetail()`-Helfer zusammengefasst (läuft seitdem
parallel statt sequenziell, an mehreren Stellen im Projekt weiter
genutzt); Datei-Uploads bei Mehrfachauswahl laufen jetzt parallel statt
nacheinander. **Häppchen 6 (6a+6b-1+6b-2) damit komplett fertig** — die
gesamte Kontakte-Kernseite ist durch.

**Häppchen 7 (Anruf/Email am Kontakt loggen + Gilden-Rechte-Modal,
Commit `346fcba`, 2026-08-21) — Zeilen 6158-6668:** drei echte Bugs:
`guildNoGuildView` (Beitrittsliste) wurde nie wieder ausgeblendet,
sobald eine Mitgliedschaft entstand (Gilde beitreten/Einladung
annehmen) — "Keine Gilde"-Ansicht und Mitgliedsansicht liefen dadurch
gleichzeitig sichtbar übereinander; `activitySaveBtn` (Anruf/Email
loggen) hatte keinen Doppelklick-Schutz — `log_action_for_self()` hat
für normale Aktionen bewusst KEINEN serverseitigen Duplikat-Schutz (nur
Quest-Boni haben einen), ein schneller Doppelklick konnte dieselbe
Aktivität doppelt loggen, per Playwright über drei Testläufe hinweg
konsistent bestätigt behoben; Reiter-Default "Mitglieder" beim Betreten
der Gildenansicht war fälschlich an den Einmal-Listener-Guard
(`wireGuildAreaTabsOnce`) gekoppelt und griff nach einem Verlassen+Neu-
Beitreten derselben Sitzung nicht mehr — als eigene, bei jedem
`loadGuildState()`-Aufruf laufende Funktion
(`resetGuildAreaTabToMitglieder()`) herausgelöst (die konkrete
Leave/Rejoin-Randbedingung selbst bewusst nicht live simuliert, hätte
echte Gildenmitgliedschaft mutieren müssen). Zusätzlich
`guildCreateBtn`/`guildRightsSaveBtn`/`joinGuild` um denselben
Doppelklick-Schutz ergänzt. Fünf Effizienzfunde (unabhängige,
sequenzielle Supabase-Abfragen in `initGuild()`, dem Einladung-annehmen-
Handler, `renderJoinableGuilds()`, `searchGuildCandidates()` und
`loadGuildState()`s Mitglieder-/Team-Ziele-Laden) auf `Promise.all`
umgestellt. **Ein bekannter, bewusst nicht behobener Grenzfall:**
schlägt der `contact_activities`-Insert NACH erfolgreicher XP-Buchung
fehl, bleibt die XP-Gutschrift ohne Kompensationslogik bestehen —
bräuchte eine neue SQL-Funktion (kombinierte RPC oder Rollback), kein
reiner UI-Fix, daher nur dokumentiert.

Alle drei Häppchen liefen nach demselben Muster (5 parallele Review-
Agenten: Korrektheit/Effizienz/Cross-File-JS↔SQL/Zeile-für-Zeile/totes
Verhalten, jeder Fund selbst gegen den Code verifiziert, keiner blind
übernommen), jeweils per Playwright gegen den echten Account bestätigt,
0 Konsolenfehler, Testdaten (soweit erzeugt) wieder aufgeräumt — Details
und der laufende Fortschritt über alle 12 Häppchen in Claudes Erinnerung
(`project_full_bugfix_sweep`), nicht hier dupliziert. Stand nach diesem
Durchgang: 7 von 12 Häppchen fertig, 27 echte Bugs insgesamt gefunden
und behoben.

**Häppchen 8 (Dungeons/Karte, Leaflet, Zeilen 6715-6981) — 2026-08-22:**
fünf echte Bugs: `locAddBtn`/`terminLeadSaveBtn`/`kanbanTerminSaveBtn`
hatten keinen Doppelklick-Schutz (konnten doppelte Dungeons, doppelte
Kontakte+doppeltes XP-Log+doppelte Termine bzw. doppelte Termine
erzeugen); die Aktions-Buttons im Dungeon-Modal (`data-locaction`) UND
im Kontakt-Aktionsdialog (`data-contactaction` — geteiltes `locActionModal`,
derselbe Bugtyp, mitgefixt) wurden von der globalen Energie-Sperre in
`render()` nie erfasst (die liest nur `data-action`) — bei leerer
Tagesenergie blieben beide Button-Sätze klickbar, ein Klick wurde
serverseitig zwar abgelehnt, aber komplett ohne Rückmeldung; die
Lead-Anlage am Dungeon verschluckte eine ungültige Zeitspanne
(Ende vor Start) still — der Kontakt wurde trotzdem angelegt und als
"hinzugefügt" gemeldet, nur der gewünschte Kalendertermin fehlte
unbemerkt (`promptKanbanTermin()` zeigte für denselben Fall dagegen
korrekt eine Fehlermeldung). Neuer gemeinsamer Helfer
`computeTerminRange()` (Datum+Uhrzeiten → UTC-Zeitraum, `'invalid'` bei
Ende≤Start) läuft jetzt in beiden Termin-Funktionen statt doppelt
gepflegter Umrechnungslogik, `refreshActionGridEnergyState()` deckt
beide Aktionsraster-Varianten ab. Ein sechster, echter Bug betraf die
Seite selbst: `ensureDungeonMap()` lud Standorte/Account-Pool nur beim
allerersten Besuch der Sitzung — kehrte man zur Karte zurück, blieb der
Stand vom ersten Aufruf stehen, auch wenn zwischenzeitlich ein neuer
Dungeon angelegt oder ein Account umverteilt wurde. Kartenerzeugung
(einmalig) und Datenstand (bei jedem Besuch) sind jetzt sauber getrennt
(`refreshDungeonData()`), was nebenbei auch den vom Effizienz-Agenten
gefundenen doppelten `locations`-Abruf behebt (`renderAccountPool()`
bekommt die von `loadAndRenderLocations()` ohnehin schon geladenen Zeilen
übergeben, statt sie ein zweites Mal zu holen).

**Siebter Fund, SQL-seitig, seit 2026-08-22 live:** der Cross-File-Agent
fand eine seit 2026-08-08 bestehende, bisher nicht dokumentierte
RLS-Lücke bei `locations.owner_id` — die konsolidierte
`locations_update_visible`-Policy (RLS-Performance-Härtung,
2026-08-17) prüft in ihrer `WITH CHECK`-Klausel für Nicht-Admins nur
`guild_id`, nicht `owner_id`. Ein Gildenführer konnte dadurch per
direktem API-Aufruf `owner_id` eines Dungeons, den ein eigenes
Gildenmitglied besitzt, auf einen beliebigen Wert setzen (inkl. sich
selbst) — obwohl "Umverteilen bleibt Admin-exklusiv" (Patch 14,
`renderAccountPool()` ist auch nur für Admins sichtbar) das explizit
verhindern sollte. Die Lücke steckte bereits in der ursprünglichen
`locations_update_guild_admission`-Policy vom 2026-08-08, die
Performance-Härtung hat sie nur unverändert mit übernommen. Migration
`supabase/migrations/20260822120000_locations_owner_tamper_schutz.sql`,
gleiches "korrigieren statt ablehnen"-Muster wie
`protect_privileged_profile_fields()` (Patch 38/47): ein
BEFORE-UPDATE-Trigger setzt `owner_id` bei Nicht-Admins still auf den
alten Wert zurück und protokolliert den Versuch über
`log_security_alert()`. Per `begin`/`rollback`-Dry-Run mit zwei echten,
guildenlosen Nicht-Admin-Testprofilen (Enerfuqi als Gildenführer, kf als
Mitglied/Dungeon-Eigentümer) gegen die echte DB verifiziert: Kaperversuch
wird zuverlässig zurückgesetzt UND protokolliert (auch kombiniert mit
einer legitimen Namensänderung im selben Update — die geht durch, nur
`owner_id` bleibt geschützt), Admin-Umverteilung bleibt unverändert
erlaubt. Nach dem Push per direkter Trigger-Abfrage gegen die echte DB
bestätigt: `trg_protect_location_owner` steht live auf `locations`.

Fünf parallele Review-Agenten (Korrektheit/Effizienz/Cross-File-JS↔SQL/
Zeile-für-Zeile/totes Verhalten), jeder Fund selbst verifiziert (u.a.
Zeile-für-Zeile-Agent fand nichts Neues, Effizienz-Agent bestätigt durch
den Datenfluss-Umbau miterledigt). Per Playwright gegen den echten
Account verifiziert: `locations`-Netzwerkabfragen verdoppeln sich beim
zweiten Seitenbesuch (Beweis für den Reload-Fix), Doppelklick auf einen
Dungeon-Aktions-Button senkt die Energie nur um den einfachen Wert,
ungültige Zeitspanne wird jetzt korrekt gemeldet UND blockiert die
Kontaktanlage, gültiges Speichern trotz Doppelklick funktioniert normal
und schließt das Modal, 0 Konsolenfehler, Testkontakt danach entfernt.
Stand nach diesem Durchgang: 8 von 12 Häppchen fertig, 33 echte Bugs
insgesamt gefunden und behoben, alle bisher aufgelaufenen SQL-Fixes aus
diesem Durchgang sind live (auf ausdrücklichen Nutzerwunsch "mach alle
aufgeschobenen sql dinge fertig", 2026-08-22 — betraf zu diesem
Zeitpunkt nur diese eine Migration, die PMA-Migration aus Häppchen 6a
war bereits am 2026-08-21 im selben Zug wie die Kranken-Sparten-Trennung
angewendet worden).

**Häppchen 9 (Termin-Kalender: Wochenansicht + Serientermine, Zeilen
7050-7506) — 2026-08-22:** vier echte Bugs, alle rein clientseitig (kein
SQL nötig): `attachDragHandlers()` (Zeitraster-Ziehen zum Termin-Anlegen)
hatte keinen `pointercancel`-Handler — bricht der Browser eine laufende
Zeiger-Geste ab (Touch-Scroll-Erkennung, System-Geste, Tab-Wechsel
während gehaltenem Finger), blieb das `.week-drag-ghost`-Element
dauerhaft im DOM stehen und `dragging` hing auf `true` fest, von zwei
unabhängigen Agenten gefunden; derselbe Agent fand zusätzlich, dass die
Ziehzustands-Variablen nicht nach `pointerId` unterschieden waren — ein
zweiter Finger während einer laufenden Geste in derselben Tagesspalte
konnte den Zustand des ersten überschreiben und zu einem falsch
positionierten/geöffneten Termin führen. Beides behoben: `activePointerId`
verfolgt den aktiven Zeiger (ein zweiter `pointerdown` während `dragging`
wird jetzt ignoriert), `pointercancel` räumt Ghost+Zustand genauso auf wie
`pointerup`, nur ohne einen Termin zu öffnen/anzulegen. `askSeriesScope()`
(Serientermin-Ändern/Löschen-Auswahl "Nur diesen"/"Ganze Serie") ließ
seine zurückgegebene Promise für immer unaufgelöst, wenn der Nutzer statt
eines der drei Buttons auf die abgedunkelte Fläche daneben klickte — der
bestehende globale Backdrop-Handler blendete das Modal zwar aus, kannte
aber die Promise nicht. Ein wartender `await askSeriesScope(...)` in
`termineEntrySaveBtn`/`termineEntryDeleteBtn` (strukturell schon im
nächsten Häppchen, Tag-Reiter-Abschnitt) blieb dadurch für diesen Klick
für immer hängen, ohne Fehlermeldung, ohne dass der Termin
gespeichert/gelöscht wurde. Fix: ein pro Aufruf frisch registrierter,
in `finish()` wieder entfernter Backdrop-Klick-Listener löst die Promise
jetzt mit `null` auf — bestehende Aufrufer behandeln `null` bereits
korrekt als Abbruch (`if(!scope) return`), keine Änderung an den
Aufrufern nötig. Direkter Folgefund, außerhalb des Zeilenbereichs, aber
unmittelbar die hier besprochene Kalender-Navigation betreffend:
`initJournal()` (Tagebuch/Abenteuerlog-Abschnitt, bereits als Häppchen 4
abgeschlossen dokumentiert) registrierte die Klick-Handler für
`calPrevBtn`/`calNextBtn`/`calTodayBtn` sowie `journalBookTile` und die
5 Tagebuch-Eingabefelder bei JEDEM Aufruf neu, ohne Guard — erreichbar
über den wiederholbaren Admin-Debug-Knopf "Neu erschaffen"
(`charRespawnBtn`, ruft am Ende erneut `enterApp()` → `initJournal()`
auf), gleiche Bug-Klasse wie `createSpriteRenderer()`/
`initContactFormToggle()` in früheren Häppchen. Neuer Guard
`journalListenersWired` wrappt alle fünf Listener-Registrierungen, der
Rest der Funktion (Kalender-Grundzustand, Tagebuch laden, Rendern) läuft
weiterhin bei jedem Aufruf.

Effizienzfund direkt mitgefixt: `renderWeekView()` lud eigene Kontakte
(für die Aufgaben-Chips, `loadContactTaskData()`) und die Termine der
Woche bisher sequenziell — beide Abfragen sind komplett unabhängig,
laufen jetzt per `Promise.all` parallel, spart eine Netzwerk-
Rundlaufzeit bei jedem Wochenwechsel (Vor/Zurück/Heute), nicht nur beim
ersten Laden. Cross-File-Agent und Zeile-für-Zeile-Agent fanden keine
weiteren echten Funde (u.a. explizit bestätigt: `dateKeyLocal()`/
`todayKey()` werden in diesem Abschnitt überall korrekt verwendet, keine
Vertauschung; alle RLS-Policies/Spalten für `termine`/`termin_series`
stimmen mit dem Frontend überein).

Per Playwright gegen den echten Account verifiziert: `calNextBtn` bewegt
die Woche vor UND nach einem vollständigen Admin-Respawn-Durchlauf um
exakt 7 Tage (kein Doppel-Fire); ein synthetischer `pointercancel` nach
`pointerdown` entfernt das Ghost-Element zuverlässig, ohne fälschlich ein
Termin-Modal zu öffnen, ein nachfolgender `pointerdown` funktioniert
danach normal; ein echter, materialisierter Serientermin wurde angelegt,
bearbeitet, beim Speichern erschien der Scope-Dialog, ein Klick auf die
abgedunkelte Fläche schloss ihn OHNE jeden Schreibvorgang auf
`termine`/`termin_series` (0 zusätzliche Requests) UND ohne hängenden
Zustand (ein erneuter Speichern-Klick zeigte den Dialog korrekt wieder);
`contacts`- und `termine`-Abfrage feuerten beim Wochenwechsel im Abstand
von 2ms (Beweis für echte Parallelität). Testserie danach vollständig
entfernt (0 Reste), 0 Konsolenfehler. Stand nach diesem Häppchen: 9 von
12 fertig, 37 echte Bugs insgesamt, keine offenen SQL-Fixes. Nächstes
Häppchen: 10 (Tag-Reiter: Tagesansicht + Aufgaben-UI).

**Häppchen 10 (Tag-Reiter: Tagesansicht + Aufgaben-UI + Termin-Popup,
Zeilen 7557-7961) — 2026-08-22:** **wichtigster Fund:** `singleTerminUpdated`
(das Flag hinter der "Update an Eingeladene senden?"-Nachfrage aus dem
Termin-Einladungen-Feature vom 2026-08-18) wurde nur im Nicht-Serien-Zweig
des Speichern-Handlers gesetzt — sowohl "Nur diesen Termin ändern" als auch
"Ganze Serie ändern" bei einem Serientermin ließen die Nachfrage seither
dauerhaft ausfallen, unabhängig davon, ob eine angenommene Einladung
existierte. Fix: das Flag wurde durch ein Array `updatedTerminIds` ersetzt,
das in allen drei Update-Pfaden (Einzeltermin, "nur diesen" bei einer
Serie, "ganze Serie") korrekt befüllt wird; die Prüfung läuft jetzt über
`.in('termin_id', updatedTerminIds)` statt eines einzelnen `termin_id`.
**Live verifiziert** (Playwright + `supabase db query --linked`, echte
per SQL eingeschleuste `angenommen`-Einladung an einer vergangenen UND
einer künftigen Serien-Instanz): beide Szenarien lösten danach korrekt den
Bestätigungsdialog aus, vorher keines von beiden.

Vier weitere echte Bugs: eine wöchentliche Serie mit 0 ausgewählten
Wochentagen wurde lautlos angelegt, ohne je einen Folgetermin zu erzeugen
(`generated_until` rückt trotzdem auf den vollen Horizont vor, kein
späterer Nachhol-Lauf hilft) — jetzt eine Validierung vor dem Speichern
("Bitte mindestens einen Wochentag ... auswählen"), live verifiziert;
`taskAddBtn`/`termineEntrySaveBtn`/`termineEntryDeleteBtn` hatten keinen
Doppelklick-Schutz (Live-verifiziert: ein simultaner Doppelklick erzeugt
danach nur noch 1 Aufgabe bzw. 1 Termin statt 2); ein totes Code-Fragment
(eine Delete-Button-Sichtbarkeits-Zeile, die eine Zeile später unbedingt
überschrieben wurde) entfernt; `invitationStatusLinesHtml()` hatte keinen
Staleness-Guard (Race Condition beim schnellen Wechsel zwischen zwei
Termin-Popups, gleiche Bug-Klasse wie `openContactPage()` in Häppchen
6b-1) — derselbe Fix-Ansatz übernommen (Termin-ID beim Anfragen merken,
beim Auflösen gegen den dann aktuellen Bearbeitungszustand prüfen).

Effizienzfunde direkt mitgefixt: `renderDayView()` lud Kontakte+Termine
sequenziell, obwohl `renderWeekView()` (Häppchen 9) genau das schon per
`Promise.all` parallelisiert hatte — der Fix war hier nicht nachgezogen
worden, jetzt nachgeholt; `renderTaskColumn()` lud nach jedem Abhaken/
Neuanlegen einer Aufgabe unnötig die komplette Liste neu von der DB, obwohl
der lokale Cache bereits aktuell war — in `renderTaskColumn()` (mit Reload)
und `renderTaskColumnDom()` (reines Rendern aus dem Cache) aufgeteilt,
Checkbox- und Anlege-Handler nutzen jetzt Letzteres; fehlende
Fehlerbehandlung in der `Promise.all`-Zeilen-Update-Schleife beim
Serien-Ändern ergänzt (ein einzelner fehlgeschlagener Zeilen-Update blieb
vorher unbemerkt). Ein von einem Agenten gemeldeter Scroll-Unterschied
zwischen Tag- und Wochen-Navigation (`renderDayView(false)` vs.
`renderWeekView(true)`) wurde geprüft und NICHT als Bug gewertet — nur 1
von 5 Agenten fand ihn, plausibel absichtlich (Tage-Blättern behält die
Scrollposition, weil man vermutlich dieselbe Tageszeit vergleicht;
Wochen-Wechsel ist ein größerer Sprung, der neu zur Standardzeit springt).

Kein SQL nötig, alle Fixes rein clientseitig, Commit `30f4dc3`. Stand
nach diesem Häppchen: 10 von 12 fertig, 42 echte Bugs insgesamt, keine
offenen SQL-Fixes. Nächstes Häppchen: 11 (Kanban).

**Häppchen 11a (Kanban, erste Hälfte: Board-Rendering/Vorschau/
Einladungen/Drag&Drop, Zeilen 8030-8417) — 2026-08-22:** das Kanban-Board
war mit 700 Zeilen deutlich größer als übliche Häppchen, deshalb wie schon
bei Häppchen 6 in zwei Hälften gesplittet. Vier echte Bugs: die Kanban-
Kurzvorschau (`openKanbanPreview()`) und die Termin-Einladungen-Karte
(`loadTerminInvitesCard()`) zeigten den Termin-Zeitpunkt Browser-lokal
statt über die aufgelöste Zeitzone (`tz()`/`fullPartsInTZ()`) — derselbe
Bug-Typ wie die große Zeitzonen-Vereinheitlichung vom 2026-08-21, hier an
zwei Stellen nicht mitgezogen. Neuer gemeinsamer Helfer `terminRangeLabel()`,
live mit `profiles.timezone='Pacific/Honolulu'` (Gerät auf Europe/Berlin)
verifiziert: zeigte danach korrekt die Honolulu-Zeit statt der
Berlin-Zeit. `openKanbanPreview()` hatte außerdem KEINEN Staleness-Guard —
eine spät ankommende Antwort für Kontakt A konnte die inzwischen für
Kontakt B geöffnete Vorschau überschreiben, dabei sogar den "Einladen"-
Button fälschlich an den Termin von A binden (3 von 5 Agenten unabhängig
gefunden). Neue Variablen `kanbanPreviewRequestId`/`kanbanPreviewOpenTerminId`,
gleiches Muster wie `currentContactPageId` aus Häppchen 6b-1. Dritter Bug:
`openTerminInviteModal()` (der Einladen-Picker) zeigte NUR Gildenmitglieder,
obwohl die Backend-Funktion `invite_to_termin()` über `socially_visible()`
laut CLAUDE.md ausdrücklich auch Freunde erlaubt — ein Nutzer ohne Gilde,
aber mit Freunden, konnte dadurch niemanden einladen. Fix: Gildenmitglieder
UND Freunde werden jetzt zusammengeführt und dedupliziert, live verifiziert
(ein Freund, der zufällig auch Gildenmitglied ist, erscheint korrekt nur
einmal). Vierter Bug: nach erfolgreicher Einladung aktualisierte sich die
dahinterliegende Kanban-Vorschau nicht automatisch — jetzt über
`refreshKanbanPreviewInviteZone()` behoben. Zusätzlich ein Doppelklick-
Schutz im Verschieben-Menü (Touch-Ersatz fürs Ziehen) ergänzt, live per
Netzwerk-Mitschnitt verifiziert (nur noch 1 statt 2 `contacts`-PATCH-
Aufrufe bei simultanem Doppelklick). Effizienzfund direkt mitgefixt:
`renderKanbanBoard()` lud Kontakt-Bundle + geteilte Karten jetzt per
`Promise.all` parallel statt sequenziell. Kleinere Funde: geteilte
Kanban-Karten zeigten den Betriebsnamen nicht, obwohl geladen (jetzt
Feature-Parität zu eigenen Karten); ein in diesem Kontext nie erreichbarer
`storniert`-Eintrag in `INVITATION_STATUS_LABELS` entfernt.

Kein SQL nötig, alle Fixes rein clientseitig, Commit `cb6eabf`. Stand
nach diesem Häppchen: 10/12 + 11a fertig, 47 echte Bugs insgesamt, keine
offenen SQL-Fixes. Nächstes Häppchen: 11b (Kanban, zweite Hälfte:
Aktionen-Logging/Verkauf/Win-Loss/Move-Logik).

**Häppchen 11b (Kanban, zweite Hälfte: Aktionen-Logging/Verkauf/Win-Loss/
Move-Logik/Neuer-Lead, Zeilen 8493-8804) — 2026-08-22:** drei echte Bugs.
`recordWinOrLoss()` (gemeinsame Funktion für Kanban-Drop UND den normalen
Kontakt-Aktionsdialog) setzte `contacts.status` auf 'kunde'/'verloren'
**unbedingt** — auch wenn das Verkaufs-Popup (`recordLostSale()`/
`recordWonSalesLoop()`) mit "✕" geschlossen wurde, ohne je ein Produkt
einzutragen. Ein Kontakt konnte dadurch als "Kunde" mit 0 Verträgen in der
Verträge-Zone landen — beim Testen live bestätigt (ein Testkontakt aus
einer früheren Session hatte genau diesen Fehlerzustand: `status='kunde'`
bei 0 `sales`-Zeilen). Fix: beide Verkaufs-Popups geben jetzt zurück, ob
wirklich mindestens ein Produkt erfasst wurde, `recordWinOrLoss()`
überspringt den Statuswechsel sonst — live verifiziert (Status blieb nach
Abbruch ohne Produkt korrekt auf dem alten Wert). `populateCategorySelect()`
(Kategorie-Dropdown in beiden Verkaufs-Popups) escapte die admin-editierbare
Produktkategorie nicht — echte Stored-XSS-Lücke, derselbe Bug-Typ wie in
Häppchen 6a bei `renderStatCategoryChart()` gefunden, dort aber nur diese
eine Nachbarstelle gefixt, `populateCategorySelect()` blieb übersehen.
Live mit echtem `<img src=x onerror=alert(1)>`-Testprodukt verifiziert:
0 Ausführungen, Kategorie blieb als sichtbarer Text escaped. Dritter Bug:
`kanbanTerminKanal` (die Kanal-Auswahl im Ersttermin-Popup während eines
Kanban-Übergangs) wurde beim Öffnen zurückgesetzt, aber nicht beim
Abbrechen (✕ statt Speichern) — wählte der Nutzer einen Kanal und brach
dann ab, blieb der Wert stehen und wurde trotzdem per
`attachKanalToLoggedAction()` an den `termin_vereinbart`/`kundenausbau`-
Log-Eintrag gehängt, obwohl gar kein Termin existierte, dem er zuzuordnen
gewesen wäre. Fix: `promptKanbanTermin()` gibt jetzt den tatsächlich
verwendeten Kanal zurück (`null` bei Abbruch), der Aufrufer verlässt sich
nicht mehr auf die geteilte Variable — live verifiziert (`action_log.meta`
blieb korrekt `null` nach Kanal-Klick + Abbruch, vorher hätte der Kanal
fälschlich gestanden). Ein vierter, von mehreren Agenten gemeldeter
vermeintlicher Fund (Zweittermin bekommt nie einen Kanal ins `action_log`,
anders als Ersttermin) wurde geprüft und als **bewusstes Design**
verworfen: `questMatchesKanal()` dokumentiert im Code explizit, dass der
Kanal nur bei der Aktion `termin_vereinbart` mitgeschrieben wird, nicht
bei `pitch` (das Zweittermin loggt) — kein Fund, keine Änderung.
Effizienzfunde direkt mitgefixt: Doppelklick-Schutz für
`kanbanNewLeadSaveBtn`, `recordLostSale()`s Bestätigen-Button,
`recordWonSalesLoop()`s "+ Produkt hinzufügen"/"Fertig" (ein gemeinsamer
Sperr-Zustand für beide, da beide auf `sales` schreiben und ein Klick auf
"Fertig" während laufendem "+ Produkt hinzufügen" sonst ebenfalls hätte
kollidieren können), `offerExtraAction()`s Zusatzaktions-Buttons (bekamen
zusätzlich die schon an anderer Stelle etablierte Energie-Sperre
`refreshActionGridEnergyState()`, vorher blieben sie bei leerer
Tagesenergie klickbar) — alle live per simultanem Doppelklick verifiziert
(nur 1 statt 2 Schreibvorgänge). Ein von einem Agenten selbst als "nicht
risikofrei" eingestufter Merge-Vorschlag (zwei sequenzielle
`contacts`-Updates in `moveKanbanCard()`/`recordWinOrLoss()`
zusammenlegen) wurde bewusst NICHT umgesetzt.

Kein SQL nötig, alle Fixes rein clientseitig, Commit `f348a3f`. **Kanban
(Häppchen 11a+11b) damit komplett fertig.** Stand nach diesem Häppchen:
11 von 12 fertig, 50 echte Bugs insgesamt, keine offenen SQL-Fixes.

**Häppchen 12 (Produkte, Einstellungen, Sicherheitswarnungen,
Fehlerprotokoll, Notfallzugriff, Seitennavigation, Z. 8865-9719) —
letztes Häppchen, 2026-08-22:** 5 parallele Agenten — sieben echte Bugs:
Stored-XSS bei `products.subcategory` (`renderProductsPage()`, Zeile
~8902) — die Gruppenüberschrift rendert `category + ' — ' + subcategory`
ungeescaped, obwohl `p.name` zwei Zeilen darunter korrekt escaped wird,
von 2 unabhängigen Agenten gefunden, mit echtem `<img onerror>`-
Testprodukt live verifiziert (0 Ausführungen, Text blieb sichtbar
escaped); fehlender Doppelklick-Schutz bei `prodAddBtn` (live per
simultanem Doppelklick verifiziert: nur 1 statt 2 Produkte) und
`eaRequestBtn` (CLAUDE.md dokumentiert "bewusst nur EIN Log-Eintrag pro
Auslösung" — ein Doppelklick hätte das gebrochen; Fix nach Code-Review
angewendet, nicht live gegen einen echten Kollegen getestet, um dessen
private Daten nicht unnötig per Notfallzugriff abzurufen); Race
Condition in `searchEaCandidates()` (Notfallzugriff-Personensuche) ohne
Staleness-Guard — der bestehende Debounce verhindert nur mehrfaches
Timer-Feuern, bricht aber keine bereits laufende Anfrage ab, eine
langsame ältere Suche konnte eine schnellere neuere überschreiben (neue
`eaSearchRequestId`-Variable, gleiches Muster wie
`kanbanPreviewRequestId`/`currentContactPageId` aus früheren Häppchen);
stiller `NaN`→`null`-Datenverlust bei `settingsSaveBarSave()` —
Dezimal-/Zahlenfelder in den Einstellungen (z.B. "Leben-Satz (%)") sind
`type="text"`, eine ungültige Eingabe (`parseFloat("abc")`) wurde
bisher kommentarlos als `null` gespeichert statt eine Fehlermeldung zu
zeigen, jetzt live verifiziert (Meldung "Ungültige Zahl bei ... — bitte
korrigieren", kein Speichervorgang); `SECURITY_EVENT_LABELS` fehlte der
am 2026-08-22 (Häppchen 8) neu hinzugekommene `location_owner_tamper`-
Event-Typ — wäre nur als roher Schlüssel statt deutschem Label
angezeigt worden, ergänzt; Hash blieb nach einem Berechtigungs-Redirect
in `showPage()` dauerhaft falsch stehen — `routeToHash()`/
`restoreLastPage()` rufen `showPage(..., false)` auf, um einen
gespeicherten Hash nicht zu überschreiben, aber genau dieser Hash war
gerade als ungültig/verboten erkannt worden (z.B. `#notfallzugriff` als
Nicht-Admin per Bookmark/Direktaufruf) — die Adressleiste blieb dann
dauerhaft falsch stehen, bis zum nächsten echten Nav-Klick, obwohl
intern schon die Charakter-Seite gezeigt wurde. Fix: Hash wird jetzt
zusätzlich zu `updateHash!==false` auch dann geschrieben, wenn ein
Redirect stattgefunden hat (nicht live mit einem Nicht-Admin-
Zweitaccount getestet, nur code-seitig verifiziert — Aufwand/Risiko
eines Wegwerf-Onboarding-Durchlaufs für diesen kosmetischen URL-Bug
bewusst nicht betrieben). Zwei Aufräumfunde: veralteter Kommentar bei
`PRODUCT_ART_CONFIG` (behauptete, `D` [Darlehen] sei "noch nicht
aufgenommen", obwohl der Eintrag längst existiert) korrigiert; toter
Ternary in `settingsTileSubtitle()` (beide Zweige lieferten identisch
`' geändert'`) vereinfacht. Effizienzfunde direkt mitgefixt:
Doppelklick-Schutz zusätzlich bei `productDetailSaveBtn`/`toggleBtn`/
`tzSaveBtn`/`azSaveBtn` (Updates sind zwar idempotent, aber unnötiger
doppelter Netzwerk-Schreibzugriff, inkonsistent mit dem sonst im
Projekt etablierten Muster); doppelte DOM-Lookups in
`wireArbeitszeitenExtras()`s Mo–Fr-Übernehmen-Schleife und
`openProductDetailModal()` (Modal-Element dreifach gesucht) in lokale
Variablen gecacht. Cross-File-Agent bestätigte ansonsten volle
Konsistenz zwischen `index.html` und den SQL-Migrationen (inkl. der
bereits am 2026-08-21 live gepushten `products_provision_mode`-PMA-
Erweiterung). Kein neuer SQL-Fix nötig. Per Playwright gegen den echten
Account verifiziert (XSS-Testprodukt, Doppelklick-Anlage bei prodAddBtn,
NaN-Validierung, Regressionstest eines gültigen Speichervorgangs, 0
Konsolenfehler) — Testprodukt danach vollständig gelöscht, Test-
Einstellungswert exakt auf den Ausgangszustand (leer) zurückgesetzt.

**Damit ist der gesamte 12-teilige systematische Bugfix-Durchgang
(Häppchen 1-12) über die komplette `index.html` abgeschlossen** —
Gesamtbilanz: 57 echte Bugs gefunden und behoben, alle SQL-Fixes live,
kein offenes Häppchen mehr. Details siehe Claudes Erinnerung
`project_full_bugfix_sweep`.

**Fazit-Gespräch direkt im Anschluss, 2026-08-22: die 57 Bugs sind kein
Zufall, sondern fallen fast alle in eine Handvoll wiederkehrender
Klassen** — mit Abstand am häufigsten fehlender Doppelklick-Schutz bei
Buttons, die eine Datenbank-Schreiboperation auslösen (~20+
Fundstellen über praktisch jedes Häppchen verteilt), dazu vergessenes
`escHtml()` bei neuem Rendering-Code (Stored-XSS, ~7 Fundstellen NACH
der bereits großen Sicherheits-Sweep vom 2026-08-07), Async-Race-
Conditions ohne Staleness-Guard (~4 Fundstellen) und Listener-Stacking
bei wiederholtem Init (~5 Fundstellen, nur über den Admin-Debug-Knopf
"Neu erschaffen" erreichbar, geringes Praxisrisiko). Grund: das
"Rezept" für einen neuen Button/eine neue Render-Funktion hatte den
Schutz nie strukturell eingebaut, sondern verließ sich jedes Mal aufs
Erinnern — bei den ersten beiden Klassen weit über die im Projekt
selbst verwendete Rule-of-Three-Schwelle hinaus wiederholt.

**Zwei neue, verbindliche Helfer, direkt gebaut statt nur dokumentiert
("mach"):**
- **`withClickGuard(btnId, handler)`** (neben `reportError`/
  `logSilentError`, Zeile ~2110): umhüllt einen Klick-Handler so, dass
  der Button synchron vor dem Ausführen deaktiviert und danach
  garantiert (auch bei Exception, `finally`) wieder aktiviert wird.
  Nimmt bewusst die Button-ID statt eines Element-Verweises entgegen
  (bei jedem Klick frisch aufgelöst), damit derselbe Aufruf sowohl bei
  `addEventListener('click', ...)` als auch bei `btn.onclick=...`
  funktioniert (z.B. bei pro Modal-Öffnung neu zugewiesenen Handlern).
- **`html`/`raw()`** (neben `escHtml()`, Zeile ~7150): escaping-
  sicheres Tagged-Template — jeder interpolierte Wert wird automatisch
  `escHtml()`-behandelt, außer er ist über `raw(str)` (bewusst
  vertraute, fest im Code stehende Fragmente wie Emoji/style-Attribute)
  oder als Ergebnis eines verschachtelten `html\`...\``-Aufrufs bereits
  als sicher markiert. Arrays (z.B. `${liste.map(x=>html\`...\`)}`)
  werden Element für Element behandelt und korrekt verkettet — **wichtig:
  die einzelnen Elemente nicht selbst per `.join('')` zu einem rohen
  String verketten und DEN interpolieren**, sonst greift die
  Auto-Escaping-Prüfung nicht mehr richtig.

**Live angewendet statt nur deklariert** (damit die Helfer sofort
echten, getesteten Code betreffen statt unbenutzt zu bleiben — sonst
hätte ESLint sie ohnehin als unused geflaggt): alle 6 Doppelklick-Fixes
aus Häppchen 12 (`prodAddBtn`, `productDetailSaveBtn`/`toggleBtn`,
`tzSaveBtn`, `azSaveBtn`, `eaRequestBtn`) auf `withClickGuard`
umgestellt, `renderProductsPage()` auf den `html`-Tag umgestellt (löst
dieselbe XSS-Stelle bei `products.subcategory`/`p.name` jetzt
strukturell statt durch manuelles `escHtml()`). Per Playwright
verifiziert: dreifacher simultaner Klick auf `prodAddBtn` legt weiterhin
nur 1 Produkt an, XSS-Payload bleibt escaped, `raw()` liefert korrekt
das leere/gefüllte `style`-Attribut ohne Doppel-Escaping, ein
synthetischer Doppelklick auf `productDetailToggleBtn` (per
`dispatchEvent`, da Playwrights `page.click()` bei einem sich
schließenden Modal in einen eigenen Retry-Deadlock läuft) kippt den
Status nur einmal (per direkter DB-Abfrage bestätigt: `false→true`,
kein Zurückspringen), Einstellungen-Zeitzone/Arbeitszeiten speichern
weiterhin normal, 0 Konsolenfehler. Testprodukt danach vollständig
gelöscht, Zeitzone auf Ausgangszustand zurückgesetzt.

**Verbindliche Regel ab sofort:** jeder NEUE Button, der eine
Datenbank-Schreiboperation auslöst, wird mit `withClickGuard()`
verdrahtet; jeder NEUE Rendering-Code, der Datenbank-Text per
`innerHTML` einfügt, nutzt den `html`-Tag statt roher Template-Literale
+ einzelner `escHtml()`-Aufrufe. **Bestehende, bereits einzeln gefixte
Stellen werden NICHT automatisch mitgezogen** — ein Massenumbau der
~100+ bestehenden `innerHTML`-Stellen bzw. der übrigen ~15 bereits
korrekt manuell gefixten Doppelklick-Stellen wäre ein eigenes, riskantes
Vorhaben ohne zusätzlichen Bugfix-Nutzen (die sind ja schon korrekt) —
bei Gelegenheit (nächster Umbau in der Nähe einer bestehenden Stelle)
kann sie mitgezogen werden, kein eigener Rückbau-Häppchen dafür.

## 2026-08-21: Zeitzonen-Inkonsistenz `dateKeyLocal()` vs. `todayKey()` behoben

Löst den seit dem Code-Review-Durchgang vom 2026-08-20 bekannten,
damals bewusst zurückgestellten Fund vollständig auf ("ein rein in
Europe/Berlin ansässiges Team hat aktuell ohne praktische Auswirkung,
aber ein echter Konventionsbruch") — auf ausdrücklichen Nutzerwunsch
("mach das zeitzonen thema komplett") nicht nur die ursprünglich
gemeldete eine Stelle (Tag-Reiter-Aufgabenspalte) gefixt, sondern alle
16 `dateKeyLocal()`-Aufrufstellen im gesamten Kalender-/Termin-/
Konstanz-Code einzeln klassifiziert (Kernunterscheidung Typ A/Typ B:
aktueller Stand CLAUDE.md).

**Fünf echte Fundstellen behoben:**
- **Wurzelursache:** `calWeekStart`/`calDayDate`/`calFocusDate` wurden
  bei `initJournal()` und im "Heute"-Knopf direkt aus `new Date()`
  (Browser-lokal) gesetzt — obwohl im SELBEN Codeblock `calViewYear`/
  `calViewMonth` für die Monatsansicht bereits korrekt über
  `localPartsInTZ()` liefen. Monats- vs. Wochen-/Tagesansicht konnten
  dadurch von unterschiedlichen "heute"-Referenzen ausgehen.
- `calTermineDates` (Monatsansicht-Kalenderpunkte) und die Termin-Tag-
  Zuordnung in der Wochenansicht nutzten `dateKeyLocal(new
  Date(t.start_at))` auf echten Zeitstempeln statt `todayKey(t.
  start_at)`.
- Der "today"-Vergleich (CSS-Hervorhebung) in Wochen- und Tagesansicht
  nutzte `dateKeyLocal(new Date())` statt `todayKey(new Date())`.
- `weeklyActionTotals()`/`streakFromWeeklyTotals()` (Konstanz-Kachel,
  Wochen-Schwellenwert) nutzten Browser-lokale Zeit, während das direkt
  danebenstehende Tages-Pendant `dailyActionTotals()` schon immer
  `todayKey()` nutzte.
- `termineEntryDateForSave` beim Bearbeiten eines bestehenden Termins
  (Basis für eine daraus neu erstellte Serie) las den Kalendertag
  Browser-lokal statt zeitzonenbewusst.

**Ursprünglich bewusst NICHT Teil dieser Änderung** (die restlichen
`dateKeyLocal()`-Aufrufstellen auf Typ-B-Objekten blieben korrekt so;
Termin-Uhrzeit-Anzeige/-Positionierung und die UTC-Grenzen der Tag-/
Wochen-Datenbankabfragen blieben zunächst Browser-lokal, "eine
vollständige Umstellung wäre ein größerer, eigener architektonischer
Schritt") — **noch am selben Tag doch angegangen**, siehe nächster
Eintrag "Vollständige geräteunabhängige Zeitraster-Engine".

**Verifikation, bewusst nicht nur mit der echten aktuellen Uhrzeit**
(die zufällig zu keiner Tagesgrenzen-Überschneidung geführt hätte): per
Playwright mit `context.addInitScript()` manipulierter Systemzeit
(`2026-08-21T23:30:00Z`, in Europe/Berlin bereits der 22.08., in der
Geräte-Zeitzone `Pacific/Honolulu`, UTC−10, noch der 21.08. — ein
garantierter Tagesgrenzen-Konflikt) UND vor dem Fix gegen den
vorherigen Commit getestet (`git stash`): Tag-Reiter zeigte davor
fälschlich "Freitag 21.08.", danach korrekt "Samstag 22.08." — bewiesen
echter Fix, kein Zufallstreffer. Zusätzlich mit zwei realen Zeitzonen
(Europe/Berlin, Pacific/Honolulu) zur echten aktuellen Uhrzeit gegen
Monats-/Wochen-/Tagesansicht plus "Heute"-Knopf getestet, keine
Konsolenfehler, ESLint sauber. Commit `ca8d896`.

## 2026-08-21: Vollständige geräteunabhängige Zeitraster-Engine

Direkte Fortsetzung des `dateKeyLocal()`/`todayKey()`-Zeitzonenfixes
vom selben Tag (siehe CLAUDE.md-Abschnitt "Zeitzonen-Inkonsistenz") —
ursprünglich als "erst bei echtem Auslöser" zurückgestellte
Skalierungs-Schwelle (siehe gestrichener Eintrag bei "Technische
Skalierungs-Schwellen" in CLAUDE.md), dann nach kurzer Diskussion doch
direkt gebaut: die Zeitraster-Engine wird laufend weiter ausgebaut
(jedes neue Feature vergrößert später den Umstellungs-Umfang), es gibt
noch keine echten Produktions-Nutzer (nur Tester, siehe Erinnerung
`feedback_no_production_users_yet`), und auf die Frage "wie macht das
Salesforce?" gab es eine klare Antwort statt einer offenen Anforderung.
Migration `20260821160000_profil_zeitzone.sql`. Aktuelles Modell/
Helfer/umgestellte Stellen: CLAUDE.md, Abschnitt "Zeitzonen: pro
Nutzer, geräteunabhängig".

Ursprünglich blieben zwei Stellen bewusst außen vor (`fmtTime()`, das
Anruf/Email-Zeitfeld) — auf Nachfrage noch am selben Tag ("mach
fertig, wenn es das beste für das system ist") ebenfalls umgestellt,
CLAUDE.md zeigt bereits den fertigen, vollständigen Endzustand.

**Verifikation, per Playwright gegen den echten Account, in mehreren
Runden über den Tag verteilt:**
- Einstellungen-Kachel zeigt 419 Zeitzonen-Optionen (`Intl.
  supportedValuesOf('timeZone')`), Speichern funktioniert
  (`profiles.timezone` live gesetzt/bestätigt).
- **Kernbeweis:** Nutzer-Zeitzone auf `Pacific/Honolulu` gesetzt,
  Geräte-Zeitzone bewusst auf `Europe/Berlin` belassen (Playwright
  `timezoneId`), Systemzeit auf `2026-08-21T23:30:00Z` fixiert — Kalender
  zeigte korrekt den Honolulu-Tag (21.08.), NICHT den Berlin-/Org-Tag
  (22.08.), obwohl das Gerät selbst Berlin ist — beweist, dass
  `profile.timezone` tatsächlich Vorrang vor Organisations- UND
  Geräte-Zeitzone hat.
- Per Drag im Wochenraster ein Termin auf "14:00" (Honolulu-Anzeige)
  gelegt, gespeichert, direkt in der DB nachgeprüft: `start_at` exakt
  `2026-08-22T00:00:00Z` — mathematisch korrekt (14:00 UTC−10 = 00:00
  UTC am Folgetag), kein Zufallstreffer durch bloßes Round-Trip-Display.
- Für `fmtTime()`/das Anruf/Email-Zeitfeld separat, beide Enden
  unabhängig voneinander bestätigt (Systemzeit `2026-08-21T20:00:00Z` =
  22:00 Berlin = 10:00 Honolulu): vorbefülltes Zeitpunkt-Feld zeigte
  korrekt `2026-08-21T10:00` (nicht 22:00); die gespeicherte Zeile
  landete in der DB exakt bei `2026-08-21 20:00:00+00`; die Chronik
  zeigte anschließend "heute 10:00" (nicht 22:00) — Schreiben und
  Anzeigen getrennt verifiziert, kein zufälliger Round-Trip-Treffer.
- Regressionstest im Normalfall (kein Override, echte Systemzeit, reale
  Geräte-/Org-Zeitzone Berlin): Zeitzone-Feld korrekt leer nach Reset,
  Wochenansicht/Terminanlage round-trip-korrekt, 0 Konsolenfehler.
- Alle Testdaten (Testtermine, `contact_activities`+`action_log`-
  Testzeilen, `profiles.timezone`-Override) danach vollständig
  entfernt, ESLint sauber.

## 2026-08-01 bis 2026-08-03: Ausrüstungs-/Charakterbild-System

KI-Bildgenerierung pro Einzelteil wurde als Ansatz verworfen (Thema
abgeschlossen, 2026-08-01): unabhängig generierte Bilder halten
Proportion/Ankerpunkte nicht zuverlässig ein, die Ebenen müssen aber
pixelgenau zueinander passen — ein technisches, kein Geschmacksproblem.
Einziger tragfähiger Weg: fertige, bereits in Ebenen aufgeteilte
Asset-Pakete (GandalfHardcore, itch.io). Assets liegen lokal unter
`~/Schreibtisch/GandalfHardcore *.zip`, Lizenz erlaubt kommerzielle
Projekte/Verändern, kein Namensnennungszwang, verbietet aber
Weiterverkauf der Rohdaten, KI-Training und Einbau in "Game Tools".
Multi-Tenant-SaaS-Lizenzfrage bewusst zurückgestellt bis zum ersten
echten Verkauf an eine zweite Organisation. Korrektur 2026-08-02: die
anfängliche Linie, freizügige Teile (Bikini/Unterwäsche) aus "Female
Clothing" auszusortieren, wieder aufgehoben — passt zum B2B-Kontext.

**Anziehen/Ausziehen, fertig 2026-08-03** (Design seit 2026-08-01
festgelegt): `toggleEquip(itemKey, slotField)` existierte als
Code-Gerüst schon seit Patch 5, lief aber ins Leere, weil kein
Ausrüstungs-Item im Katalog existierte (nur der Manatrank). Bewusst
keine geloggte Aktion (kein XP) — reine Kosmetik. Verbraucht das Item
NICHT (anders als Verbrauchsgüter). Item-Katalog unterscheidet
`category:'waffen'|'ruestung'|'accessories'` (→ `EQUIP_SLOT_FIELD` auf
`profiles.equipped_weapon/armor/accessory`) von Verbrauchsgütern mit
`effect`-Feld.

**Rendering-Ansatz geändert:** statt des ursprünglich geplanten flachen
`items.image`-Felds (statisches PNG-Overlay) nutzt Ausrüstung dieselbe
Sprite-Sheet-Technik wie der Aussehen-Screen — `items.sheet`
(Dateiname unter `img/characters/sheets/`, `{g}`-Platzhalter für
Geschlecht). `layersForCharacterProfile()` baut die Ebenen-Liste live
aus `profiles.equipped_*`. Das alte `items.image`-Feld/die
`<img>`-Overlay-Logik wurden ersatzlos entfernt.

Die bisherigen CLASS_OUTFIT-Klassenitems (Zauberer: Zauberstab + blaues
Cape, Krieger: Holzschwert + Guard Helmet, Schütze: kleiner Rucksack)
wurden echte Katalog-Items (`sql/patch26_klassenitems.sql`). Neue
Charaktere bekommen sie automatisch bei der Erschaffung ins Inventar
gelegt UND angezogen (`grantClassStarterEquipment()`, `justCreated
Character`-Flag in `enterApp()`), bestehende Profile bekamen ihr
Klassenitem einmalig per SQL nachträglich.

**Schützen-Bogen (`schuetze_bogen`, Patch 28), zwei Iterationen:** kein
GandalfHardcore-Asset (im Paket nicht enthalten) — handgezeichnetes
Pixel-Sprite. Erste, formelbasierte Version (`make_bow_sprite()`,
Sinus-Kurve, Positions-Spur 1:1 vom Schwert übernommen) wurde vom
Nutzer als zu klobig/hässlich verworfen. Ersetzt durch eine von Hand
gezeichnete, schlankere Silhouette (Entwurf archiviert unter
`Design/ItemKonzept/bogen_konzept_v1.png`), Position UND Rotation
wurden pro Laufzyklus-Frame im neuen Sprite-Labor (siehe eigener
CLAUDE.md-Abschnitt) von Hand abgestimmt — der Bogen schwingt jetzt
sichtbar mit (0° bis −75° über 8 Frames), Werte liegen dauerhaft in
`Design/ItemKonzept/bogen_export.json`, gebacken über
`Design/bake_sprite_lab_export.py`. Weiblicher Bogen ist nur eine
Näherung (dieselben Werte 1:1 auf `outfit_weapon_bow_w.png`
übernommen, bewusste Nutzer-Entscheidung, sitzt nicht ganz exakt).
`layersForClassPortrait('schuetze', g)` zeigt den Bogen seitdem auch
auf dem Klassenwahl-Bildschirm.

**Klassenwahl-Bildschirm, zwei Überarbeitungen:** zeigte anfangs nur für
Krieger ein Bild (`img/characters/krieger.png`), Zauberer/Schütze
hatten Emoji. Erst statische Einzelbilder pro Klasse+Geschlecht, dann
— auf ausdrücklichen Nutzerwunsch nach einem dynamischen statt
flachen Screen — durch `<canvas>`-Elemente ersetzt
(`layersForClassPortrait`/`portraitRenderers`). `img/characters/
krieger.png` und die sechs zwischenzeitlich erzeugten statischen
`hexer_m.png`/etc. wurden komplett aus dem Repo entfernt, sobald die
Charakterseite denselben Canvas-Renderer nutzte (bestätigt per Check
am 2026-08-10) — `CLASS_BASE_ART` existiert im Code nicht mehr.

## 2026-08-17 bis 2026-08-23: Regressions-Suite aufgebaut und erweitert

Nutzerwunsch "best practice? dann bitte" (kein CI/CD, dessen Auslöser
noch nicht erreicht war). `~/.local/share/playwright-portable/
regression_suite.mjs` entstand als wiederverwendbares Skript gegen die
echte App, ursprünglich mit drei Kernpfaden, am 2026-08-23 auf 33
Einzelprüfungen über acht Bereiche ausgeweitet (Login/Rollen, XP-/
Level-Berechnung, Kanban, zentrale Navigation inkl. Deep-Links,
Kalender/Termine, Kontakt-Chronik, Verkauf/Statistik, mobiles/Touch-
Verhalten). Nutzt `page.route()`-Interception statt echter
Schreibvorgänge — schreibt nichts an der echten DB, nach dem Ausbau per
`supabase db query --linked` gegengeprüft (0 Treffer für alle
synthetischen Test-IDs).

**Echter Bug im alten Test selbst gefunden:** `window.profile`
existiert nicht (die App läuft in einer eigenen IIFE-Klammer, `profile`
ist darin ein rein lokales `let`) — der ursprüngliche Admin-
Sichtbarkeits-Check fiel dadurch immer auf "übersprungen", testete
faktisch nie die rollenbasierte UI. Fix: Rolle/Zeitzone werden über
eine Strukturprüfung der `profiles`-REST-Antwort abgefangen.

**Mobiles/Touch-Verhalten (sechs weitere Prüfungen):** bewusst nur bis
zum Öffnen/Prüfen/Schließen des Verschieben-Menüs getestet, keine
abgeschlossene Verschiebung — die würde über `moveKanbanCard()` ein
echtes RPC + PATCH auf `contacts` auslösen, das am echten Konto hängen
würde.

**Zweites Skript `regression_suite_member.mjs`:** prüft die
rollenabhängigen Stellen noch einmal mit einem echten Nicht-Admin-
Konto (Admin ist im echten Team die Ausnahme). Bewusst NICHT die ganze
Hauptsuite ein zweites Mal durchlaufen lassen — die meisten der 33
Prüfungen hängen nicht an der Rolle. Zwei getrennte Zugangsdaten-
Dateien im gitignorten Ordner `~/.local/share/fantasyarbeit-claude-test/`
(`credentials.json` = Admin, `credentials_member.json` = Nicht-Admin).

Am 2026-08-23 legte der Nutzer fest, dass beide Skripte künftig
automatisch vor jedem `git push` laufen sollen, ohne vorher zu fragen —
aktuelle Regel dazu: CLAUDE.md, Abschnitt "Wie mit dem Nutzer arbeiten".

## 2026-08-23/24: Optimistisches Sperren (Konflikt-Schutz bei gleichzeitiger Bearbeitung)

Löste die bisher bewusst in Kauf genommene Lücke "wer zuletzt speichert,
gewinnt ohne Warnung". Umgesetzt für die vier Tabellen mit echtem
Mehrfach-Schreiber-Risiko: `contacts` zuerst (höchstes Risiko,
gilden-geteilt), dann `locations`, `sales`, `termine`/`termin_series`.

**Erste Fassung, rein im Frontend:** `contacts.updated_at` existierte
schon, die drei anderen Tabellen bekamen das Feld per Migration neu
(`20260824130000_contacts_konflikt_schutz.sql` +
`20260824140000_locations_sales_termine_konflikt_schutz.sql`).
`BEFORE UPDATE`-Trigger stempeln `now()`, ignorieren dabei jeden vom
Client mitgeschickten Wert. Ein generischer Frontend-Helfer
`updateRowWithLockCheck(table, id, patch, expectedUpdatedAt)` hängte
`.eq('updated_at', expectedUpdatedAt)` an die WHERE-Bedingung —
Schreibrechte regelte noch die normale RLS-Policy je Tabelle.
Insgesamt 16 Schreibstellen umgestellt (8 contacts, 2 locations, 1
sales, 5 termine/termin_series).

**Live-Verifikation** (`check_contact_lock.mjs` + `check_multi_table_
lock.mjs`, echte Schreibvorgänge an Wegwerf-Testdaten): für `contacts`/
`termine` das volle Konflikt-Szenario mit zwei unabhängigen HTTP-
Clients — Kollege ändert die Zeile, Speichern löst korrekt die Warnung
aus, Kollegen-Änderung bleibt erhalten. Für `locations`/`sales` ein
Rauchtest. **Zwei handwerkliche Lücken bei der Aufräum-Kontrolle
gefunden:** ein Testlauf versuchte fälschlich ein DELETE auf `products`
(nie löschbar, nur deaktivierbar — schlug still fehl, Testskript auf
`active:false` umgestellt); ein Wegwerf-Kontakt aus einem an einem
Playwright-Dialog-Bug gescheiterten Testlauf blieb unbemerkt liegen,
bis eine abschließende DB-Stichprobe ihn aufdeckte. Beide Testskripte
liefen danach in try/finally, Test-Produkt-`key` bekam einen
Zeitstempel statt eines festen Werts.

**Architektonische Lücke, noch am 2026-08-24 erkannt und geschlossen:**
der Schutz war nur im Frontend verdrahtet, nicht wie bei `action_log`/
`user_inventory` durch RLS strukturell erzwungen — ein vergessener
Aufruf des Frontend-Helfers wäre lautlos ins alte "letzter gewinnt"-
Verhalten zurückgefallen. Auf Nutzeranstoß ("langfristig denken
überschreibt kurzfristigen Bauaufwand") umgebaut:

- **`contacts`** (`20260824160000_contacts_locked_write_rpc.sql`): die
  RLS-Policy `contacts_update_visible` komplett entfernt, einziger
  verbleibender Weg ist `update_contact_locked(p_id, p_patch,
  p_expected_updated_at)` (`SECURITY DEFINER`). `contacts_writable(target
  contacts)` übernimmt die alte USING-Bedingung 1:1 und wird nur noch
  von dieser einen Funktion aufgerufen. Bewusst schmale Feld-Allowlist
  (nur die 15 Felder, die die 8 echten Schreibstellen tatsächlich
  anfassen) statt generischem Patch — `owner_id`/`guild_id`/`org_id`
  bleiben unpatchbar, ändern sich nur über bestehende Trigger. Dry-Run
  mit 7 Assertions bestanden. **Wichtiger Live-Fund beim REST-Test:**
  PostgREST liefert einen SQL-NULL-Rückgabewert bei zusammengesetztem
  Rückgabetyp NICHT als JSON `null`, sondern als Objekt mit lauter
  `null`-Feldern (`{id:null,...}`) — ein reiner `!data`-Check hätte den
  Konflikt-Fall nicht erkannt. `rpcLockedUpdate()` prüft seitdem
  `!data || data.id === null`.
- **`locations`/`sales`/`termine`/`termin_series`**
  (`20260824180000_locations_sales_termine_locked_write_rpc.sql`):
  mehrere schmale Funktionen statt einer breiten (`admit_location_to_
  guild_pool_locked()`, `assign_location_owner_locked()`,
  `cancel_sale_locked()`, `update_termin_locked()`, `update_termin_
  series_locked()`). Anon-Rechte diesmal von Anfang an mit-eingeschränkt.
  SQL-Dry-Run mit 15 Assertions + REST-Test mit 24 Assertions
  (`check_locations_sales_termine_locked_rpc.mjs`). Beide
  Regressionssuiten liefen danach weiterhin grün (33/33 + 9/9). Die
  alte generische `updateRowWithLockCheck()` wurde komplett entfernt.

**Erster echter Beweis für die neu eingeführte Zweitmeinungs-Pflicht
(siehe eigener Eintrag unten), noch am selben Tag**
(`20260824190000_locked_write_org_boundary_fix.sql`): die Zweitmeinung
fand sofort einen echten Fehler — `contacts_writable()`/
`sales_writable()`/`termine_writable()`/`termin_series_writable()`
übernahmen nur die USING-Klausel der entfernten Policy, nicht die
WITH-CHECK-Klausel, in der die Org-Grenze für den Admin-Zweig steckte.
Ein Admin hätte theoretisch eine Zeile jeder Organisation anfassen
können, sofern er ihre UUID kennt — live gegen eine echte,
zurückgerollte Test-Transaktion nachgewiesen (`notes` einer fremden
Test-Org wurde tatsächlich verändert), praktisch folgenlos, solange nur
eine Organisation live ist. Fix: alle vier Funktionen prüfen jetzt
zusätzlich `target.org_id = current_org_id()`, vor UND nach dem Fix
live gegen die Produktions-DB (in `begin`/`rollback`) bewiesen.

**Nachtrag, `supabase db advisors` nachgeholt:** beide neuen Trigger-
Funktionen (`touch_contacts_updated_at`/`touch_updated_at`) hatten
keinen fest verankerten `search_path` ("Function Search Path Mutable").
Migration `20260824150000_touch_trigger_search_path_fix.sql` behebt
das, per Dry-Run bestätigt.

## 2026-08-24: Idempotenz-Härtung (Duplikatschutz gegen Netzwerk-Retries)

Ausgelöst durch eine vom Nutzer mitgebrachte generische Engineering-
Checkliste, Cross-Check gegen den echten Code bestätigte drei Lücken
(Migration `20260824120000_idempotenz_haertung.sql`):

- **`grant_quest_bonus_to_self()`:** der Duplikat-Schutz war "erst
  zählen, dann einfügen" (`SELECT COUNT(*) ... IF > 0 THEN RAISE`) —
  ein klassisches Race-Window ohne echten Constraint. Jetzt drei
  partielle Unique-Indizes (Quest+Zeitraum / Kette+Stufe / Questbaum+
  Stufe+Jahr) + `INSERT ... ON CONFLICT ... DO NOTHING`.
- **`log_action_for_self()`:** hatte zuvor GAR KEINEN Duplikatschutz —
  die Funktion hinter fast jeder XP-Aktion. Ein exakt identischer
  Aufruf innerhalb der letzten 5 Sekunden gibt jetzt die bereits
  geloggte Zeile zurück statt sie zu duplizieren (Zeitfenster statt
  hartem Unique-Constraint, da dieselbe Aktion mehrfach am Tag zu
  loggen der Normalfall ist).
- **`sales`:** neuer `BEFORE INSERT`-Trigger
  (`prevent_duplicate_sale_submission()`), gleiches Zeitfenster-
  Prinzip — ein exakt identischer Verkauf innerhalb von 5 Sekunden wird
  still übersprungen (`RETURN NULL`) statt einen zweiten Vertrag
  anzulegen.

Bewusst NICHT umgesetzt: der Mehrfach-Produkt-Verkauf
(`recordWonSalesLoop()`) bleibt ein sequenzieller Insert pro Produkt
statt einer gebündelten Transaktion — die Schritt-für-Schritt-Anzeige
macht Fehler sichtbar, das eigentliche Risiko (Retry) ist über den
`sales`-Trigger abgedeckt.

**Im selben Aufwasch behoben:** Path Traversal beim Datei-Upload
(`contact-files`) — der Speicherpfad nutzte den rohen `file.name`
unsanitisiert. Jetzt nur noch UUID + geprüfte Dateiendung, der
Anzeigename lebt separat in `contact_files.filename`.

Migration per `begin`/`rollback`-Dry-Run mit 6 Assertions verifiziert
(Dedup greift in allen drei Fällen, legitime unterschiedliche
Aktionen/Verkäufe werden nicht fälschlich blockiert), danach live
gepusht und erneut bestätigt (`schema_patches` Patch 52 eingetragen).

## 2026-08-24: Migrations-Zweitmeinung-Pflicht + Rückbau-Nachweis eingeführt

Auslöser: beim Konflikt-Schutz-Umbau (siehe oben) war eine einzelne
Sitzung Autor UND einziger Prüfer der eigenen Migration — eine
Selbst-Review-Lücke. Neue, verbindliche Regel: bei jeder Migration, die
RLS-Policies, `GRANT`/`REVOKE`, `SECURITY DEFINER`-Funktionen oder
sonstige Berechtigungslogik anfasst, holt Claude Code vor dem
`supabase db push` eine unabhängige Zweitmeinung ein (frischer Agent/
frische Sitzung ohne Kontext der Bau-Session). Zweite Regel, selber
Tag: der Dry-Run prüft ab jetzt auch, ob ein Rückbau tatsächlich
möglich ist (alte Policy-Definition testweise wiederherstellen, oder
zumindest vollständig im Migrations-Kommentar/git-Historie dokumentiert
lassen).

Zwei zusätzliche, bewusst gewählte Verstärkungen, noch am selben Tag
nach echter Bewährung der Regel (die Zweitmeinung fand sofort den
Org-Grenze-Fehler, siehe Eintrag "Optimistisches Sperren" oben):
Modell-Vielfalt beim Review (Bau mit Sonnet, Review-Agent wenn sinnvoll
explizit mit `model:'opus'`), und ein lokaler, unversionierter
`pre-push`-Git-Hook (`.git/hooks/pre-push`), der beim `git push` warnt,
wenn eine gepushte Migration Berechtigungslogik enthält — bewusst nicht
blockierend, reine strukturelle Erinnerung.

Aktuelle, gültige Regelformulierung: CLAUDE.md, Abschnitt
"Supabase-CLI-Migrationstoolchain".

## Team-Reporting: Gildengründer statt Admin-Rolle als Sichtbarkeits-Anker

Neue Seite "Team-Reporting" zeigt je Mitglied der eigenen gegründeten
Gilde(n) die Anzahl Dungeons/Kontakte. **Erste Fassung war admin-only
und org-weit** — eine unabhängige Zweitmeinung fand darin einen echten
Verstoß gegen das Gilden-Sichtbarkeitsmodell (Admins sollen private
Mitarbeiter-Daten nur über den begründungspflichtigen, protokollierten
Notfallzugriff sehen, nicht beiläufig über eine Reporting-Seite).
Umgebaut: Sichtbarkeit hängt jetzt an `guilds.founder_id`
(`myFoundedGuildIds`) statt an der `admin`-Rolle — der reale Teamleiter
im Vertrieb IST der Gildengründer. Die Abfrage schränkt `locations`/
`contacts` zusätzlich explizit per `.in('owner_id', memberIds)` ein,
statt sich auf die RLS-Policy allein zu verlassen — ein Gildengründer
ist im echten Team oft zugleich Admin, über den `is_admin()`-Zweig der
Policy hätte eine ungefilterte Abfrage sonst wieder org-weite Daten
geliefert. Aktueller Stand: CLAUDE.md, Abschnitt "Team-Reporting".

## 2026-08-25/26: DSGVO-Vorbereitung (Einwilligung + automatische Löschung inaktiver Kontakte)

Erster technischer Baustein aus Phase 1 des Business-Fahrplans
(rechtliche Grundlage vor dem ersten echten Kunden), Entwürfe für
Datenschutzerklärung/VVT liegen unter `businessvorbereitung/`.
Einwilligungs-Häkchen (`contacts.consent_obtained`) bewusst einfaches
Ja/Nein ohne Datum/Zweckangabe (gleiche Praxis wie beim bestehenden
AXA-Vertrieb des Nutzers).

**Automatische Löschung** (`auto_delete_inactive_contacts()`, täglicher
pg_cron-Lauf 03:17 UTC): löscht Kontakte ohne jemals gewonnenen Vertrag,
deren letzte erkennbare Aktivität länger als die pro Organisation
konfigurierte Frist zurückliegt (`rule_configs.config.contactAutoDelete`,
Standard beim Nutzer 6 Monate, bei neuen Organisationen bewusst
`enabled:false`). Kontakte mit irgendeinem jemals gewonnenen Vertrag
sind komplett ausgenommen (Kaskaden-Löschung würde rückwirkend
Kompendium-/Schatzraum-Zahlen verändern, echte Ex-Kunden haben eine
handelsrechtliche Aufbewahrungspflicht nach §257 HGB). Der eigentlich
richtige Mechanismus für diesen Fall (Art. 18 DSGVO, Einschränkung der
Verarbeitung statt Löschung) ist bewusst noch nicht gebaut.

Entstanden über zwei Runden unabhängiger Zweitmeinung (Pflicht bei
`SECURITY DEFINER`-Funktionen) — beide fanden echte Logikfehler der
jeweiligen Vorfassung (fehlender Aktivitäts-Anker, fehlender
Ex-Kunden-Ausschluss, fehlende Untergrenze gegen einen Konfigurations-
Tippfehler), alle behoben und per Dry-Run mit 9 Testszenarien
verifiziert. Aktueller Stand: CLAUDE.md, Abschnitt "DSGVO-Vorbereitung".

## 2026-08-26: Sonderquest-Hinweise (Notfall-Quest vor automatischer Kontakt-Löschung)

Setzt auf der automatischen Kontakt-Löschung auf: 1 Monat bevor ein
eigener Kontakt ohne jemals gewonnenen Vertrag automatisch gelöscht
wird, erscheint eine Sonderquest-Kachel bei den täglichen Quests.

**Optik-Korrektur, noch am selben Tag** (Nutzer-Feedback: die erste
Fassung ohne Balken/Fußzeile "sah aus wie 2 verschiedene Dinge" neben
normalen Tages-Quest-Kacheln): Fortschrittsbalken zeigt jetzt einen
Countdown der verbleibenden Tage, Fußzeile zeigt "🛡️ Kontakt retten"
statt einer XP-Zahl — dieselbe drei-Zeilen-Struktur wie jede normale
Kachel. Bewusst kein Extra-XP-Bonus fürs Retten (die normale
Aktions-XP reicht als Belohnung).

Datenquelle `contacts_pending_deletion_for_self()` spiegelt exakt
denselben Aktivitäts-Anker wie `auto_delete_inactive_contacts()`.
Frontend generisch gehalten (`specialQuestItems`-Array), Rule-of-Three-
Schwelle für ein gemeinsames Backend-Muster erst beim dritten
Hinweistyp. Live per Dry-Run verifiziert (7 Testkontakte inkl.
Grenzfall "Löschung exakt heute") — eine unabhängige Zweitmeinung fand
einen echten Off-by-one-Fehler an der Datumsgrenze (`>` statt `>=`)
sowie zwei Konventions-Abweichungen (fehlender `html`-Tag, fehlender
Staleness-Schutz), alle drei behoben. Aktueller Stand: CLAUDE.md,
Abschnitt "Sonderquest-Hinweise".

## 2026-08-26: Supabase-Advisor-Triage

Systematischer Lauf von `supabase db advisors --linked --type all
--level info` gegen die echte, verlinkte DB (Supabases offizieller
Linter). Ergebnis: 11 fehlende Fremdschlüssel-Indizes ergänzt
(Postgres indiziert Fremdschlüssel nicht automatisch), 15 der 33
anon-ausführbaren Schreib-RPCs gesperrt (Migration `20260826103300_
advisor_anon_revoke_schreibfunktionen.sql`) — die übrigen 18 bewusst
offen gelassen (8 sind `returns trigger`-Fehlalarme, die Postgres
strukturell nicht per RPC aufrufen kann, 10 sind Lese-Hilfsfunktionen,
die aus RLS-Policies heraus als aufrufende Rolle ausgewertet werden).

**Stolperstein, selbst gefunden bevor er zum Problem wurde:** eine neue
`CREATE FUNCTION` bekommt von Postgres automatisch einen zusätzlichen
`EXECUTE`-Grant für die Pseudo-Rolle `PUBLIC`, unabhängig von den
projekteigenen `ALTER DEFAULT PRIVILEGES`-Regeln — ein reines `revoke
execute ... from anon` wirkt deshalb NICHT, `anon` behält den Zugriff
über den `PUBLIC`-Eintrag. Immer `revoke execute ... from public,
anon` schreiben und per `has_function_privilege('anon', ...,
'EXECUTE')` im Dry-Run verifizieren. Zweitmeinung bei dieser Migration
lief sauber durch. Advisor-Fundzahl sank von 112 auf 97 — verbleibende
Funde bewusst unangetastet (siehe Claudes Erinnerung
`project_supabase_advisor_triage`), einzig der Dashboard-Passwortschalter
("Leaked Password Protection") bleibt offen, weil er ein Pro-Plan-
Feature ist, das auf dem aktuellen Free Plan gar nicht einschaltbar
ist.

## 2026-08-26: Storage-Aufräum-Warteschlange für gelöschte Kontakt-Dateien

Schloss die bis dahin dokumentierte, bewusst in Kauf genommene Lücke:
Dateien im `contact-files`-Bucket überlebten die automatische Löschung
inaktiver Kontakte, nur die `contact_files`-DB-Zeile kaskadierte mit.
Lösung wie in CLAUDE.md skizziert: Warteschlangen-Tabelle
(`contact_file_deletion_queue`) + `BEFORE DELETE`-Trigger auf
`contact_files` + Admin-Login-Aufräumung über die normale,
authentifizierte Storage-API — kein neues Geheimnis in der Datenbank.

**Erste Fassung hatte zwei echte, blockierende Lücken**, gefunden von
einer unabhängigen Zweitmeinung (blinder Review, kein Kontext der
Bau-Sitzung):
1. Die bestehenden Storage-Policies hingen an "gehört noch ein
   passender `contacts`-Datensatz zum Pfad" — nach der Kontakt-Löschung
   existiert der nicht mehr, die Aufräumung hätte RLS-bedingt **nichts**
   gelöscht, die Warteschlange aber trotzdem geleert (Supabase Storage
   liefert bei leer gefiltertem `remove()` `200 OK` statt Fehler). Fix:
   ein zweiter, warteschlangen-verankerter Policy-Zweig.
2. `contact_files.storage_path` wurde beim Insert nie gegen
   `contact_id` geprüft — ein Gildenmitglied mit nur Lesezugriff auf
   einen fremden Kontakt hätte dessen Pfad unter einem eigenen,
   beschreibbaren Kontakt einschleusen und die Warteschlange zur
   Löschung einer fremden, noch aktiv referenzierten Datei missbrauchen
   können. Fix: `CHECK`-Constraint, `storage_path` muss mit
   `<contact_id>/` beginnen (0 betroffene Bestandszeilen).

Zusätzlich naheliegend beim Beheben von Fund 1: der Trigger queued nur,
wenn der Eltern-Kontakt tatsächlich weg ist — sonst hätte ein
Mitarbeiter-Offboarding (`contact_files.uploaded_by ... on delete
cascade`, Kontakt selbst bleibt am Leben) künftig aktiv genutzte
Dateien lebender Kontakte gelöscht statt sie nur (wie bisher) zu
verwaisen. Dry-Run mit 13 Testfällen gegen echte Testprofile
(`set_config('request.jwt.claim.sub', ...)`, ein fingiertes
`storage.objects`-Testobjekt für die Policy-Fälle) bestätigte alle
Fixes vor dem Push. Details/Endzustand: CLAUDE.md, Abschnitt
"Storage-Aufräum-Warteschlange für gelöschte Kontakt-Dateien".

## 2026-08-26: Nie fertig definierte Planungsfelder entfernt

Beim Versuch, die seit Längerem in den Einstellungen sichtbaren, aber
funktionslosen Felder "Planung Verkaufsgespräche"/"Planung
Fachkontakte (FA)" (`planung_vks`/`planung_fa`) endlich mit einer
echten Zählquelle zu verbinden (nächster Punkt der Roadmap), stellte
sich nach mehreren Rückfragen heraus: der Nutzer wusste selbst nicht
mehr, wofür die beiden Felder ursprünglich gedacht waren — "hat sich
hereingeschlichen". Statt zu raten: komplett entfernt (Einstellungs-UI,
`profiles`-Spalten, CLAUDE.md-Erwähnung). Ungefährlich, da 0 von 8
Profilen je einen Wert eingetragen hatten.

## 2026-08-26/27: Akquise-Trichter — Conversion-Funnel als echte Statistik-Kachel

Der Nutzer zeigte eine private Excel-Vorlage
(`Conversion_Funnel_Blanko.xlsx`, Kennzahl Ansprachen→Ersttermin→
Zweittermin→Won/Lost, je Kanal Krankenhaus/Telefon) und wollte sie als
echte, live berechnete Statistik im Programm. Mehrere Klärungsrunden
vor dem Bauen (Nutzer-Wunsch "lass uns langsam anfangen, was hast du
erst rausgefunden" — Erklärung vor Multiple-Choice-Fragen):

- **Kein Kanal-Unterschied**: "wie der Termin zustande gekommen ist,
  ist egal, Akquise ist Akquise" — vereinfachte die Statistik auf eine
  einzige, undifferenzierte Trichter-Kette.
- **Ersttermin/Zweittermin "wahrgenommen"** wird jetzt automatisch aus
  dem Kanban abgeleitet: verschiebt sich eine Karte vom jeweiligen
  Termin aus WEITER (auch nach Verloren — "Termin fand statt, hat aber
  zu nichts geführt"), gilt er als wahrgenommen. Dafür bekam der
  Zweittermin eigene, neue Aktions-Schlüssel (`zweittermin_vereinbart`/
  `_wahrgenommen`/`_nicht_wahrgenommen`) statt sich weiter die Aktion
  `pitch` mit "Angebot versendet" zu teilen, und "Nicht erschienen" ist
  jetzt auch vom Zweittermin aus erreichbar (Nutzer-Wunsch: die
  Kanban-Spalte "Nicht erschienen" gleich zwei Positionen nach hinten
  verschieben, hinter beide "echte Treffen"-Spalten — "wäre etwas
  eleganter").
- **XP-Konsequenz durchgesprochen, bevor gebaut wurde**: automatische
  XP für die jetzt viel häufigere "Termin wahrgenommen"-Aktion hätte
  die Level-Kurve ungeplant beschleunigt. Nutzer bestätigte explizit
  "wenn aus dem Kanban ersichtlich wird, dass ein Termin wahrgenommen
  worden ist, dann gibt es die XP" — `levelBase` deshalb von 5,80 auf
  6,75 neu kalibriert (Methodik wie bei Patch 50: wöchentliches
  Zusatz-XP-Budget aus der bestehenden Konstanz-Schwelle "5–7 Termine
  wahrgenommen/Woche" geschätzt, hält "Level 100 nach 10 Jahren"
  stabil).
- **Optik**: Nutzer verwies auf ein Referenz-Dashboard
  (windsor.ai/Salesforce-Trichter, per Screenshot statt Live-Fetch
  geteilt, da die Seite selbst nur Marketing-Text lieferte) — "ein
  eleganter Trichter von groß zu klein, 5 Abschnitte farblich
  absteigend im selben Ton, an den Schnittstellen absolute Zahlen mit
  Statistik". Zwei Artifact-Mockup-Runden (`dataviz`-Skill bestätigte:
  Trichterstufen sind der Lehrbuchfall für eine Ordinal-Farbskala, ein
  Farbton mit monotonen Helligkeitsstufen) vor dem echten Bauen — erste
  Runde zeigte Schritt-für-Schritt-Umwandlung, zweite (auf Nutzer-
  Wunsch) zeigte stattdessen den Anteil jeder Stufe an den
  ursprünglichen Ansprachen (100%-Basis) plus zwei Kennzahlen-Kacheln
  ("Ansprachen pro Abschluss", "Ersttermine (wahrgenommen) pro
  Abschluss").
- **Farbe im echten Produkt**: `color-mix()` gegen die live gesetzte
  `--arcane`-CSS-Variable statt fester Hex-Werte — passt sich dadurch
  automatisch allen drei Klassenfarben an, per Playwright-Screenshot in
  allen dreien bestätigt (Zauberer-Lila/Krieger-Rot/Schütze-Grün).

**Nachtrag 2026-08-27, nach einer über Nacht abgebrochenen Sitzung:**
Nutzerfrage "ist Sicherheit, Effizienz, zweiter Agent, und Bugs alles
geprüft?" — ehrliche Antwort: nein, noch nicht (die Regressionssuiten
sind reine Lese-Tests, hätten einen Bug in der neuen Schreiblogik gar
nicht gefangen). `/code-review high` mit vier parallelen Prüf-Agenten
nachgeholt, fand zwei echte, bestätigte Bugs: (1) die
Zweittermin-vereinbart-Markierung feuerte auch beim
Kundenausbau-Rücksprung (Gewonnen/Verloren zurück auf Zweittermin) mit,
obwohl kein neuer Zweittermin zustande kam, verfälschte den Trichter;
(2) die drei neuen 0-Energie-Markierungen konnten fälschlich am
Tagesenergie-Budget scheitern, wenn die direkt zuvor geloggte
Hauptaktion desselben Kanban-Zugs das Budget schon ausgeschöpft hatte.
Beide behoben (Commit `653d96b`). Drei weitere Funde (Mehrfach-Ziehen
kann Wahrgenommen-XP theoretisch vervielfachen, mehrere sequenzielle
Re-Renders pro Kanban-Zug, `auth.uid()` in den Storage-Policies der
Datei-Aufräumung vom Vortag nicht performance-gewrappt) bewusst nicht
behoben — keine Korrektheitslücke bzw. zu klein für einen eigenen
Rückbau-Aufwand. `supabase db advisors` bestätigte: keine neuen
Sicherheits-Funde durch den Trichter selbst. Details:
CLAUDE.md, Abschnitt "Akquise-Trichter (Statistik-Seite)".

**Nachtrag 2026-08-27, zweite Sitzung — die drei zurückgestellten Funde
doch abgearbeitet** (Nutzer: "du darfst solche Performance- und
Optimierungsdinger nie liegen lassen"):
- **Fund 1 (Mehrfach-Ziehen vervielfacht Wahrgenommen-XP):** neuer
  Guard `hasFunnelMarkerThisYear(contactId, actionKey)` in `index.html`
  neben `logKanbanAction()` — `termin_wahrgenommen` /
  `zweittermin_wahrgenommen` / `zweittermin_vereinbart` werden pro
  Kontakt und Geschäftsjahr nur einmal automatisch geloggt (deckt sich
  mit der zeitraumbezogenen Zählweise des Trichters). Manuelle Pfade
  (Dauerbrenner-`offerExtraAction`) unberührt.
- **Fund 2 (mehrere Re-Renders pro Kanban-Zug):** `logKanbanAction()`
  bekam `opts.defer` — bei `true` nur loggen, Quest-Check + `render()`
  auslassen. `moveKanbanCard()` ruft alle bis zu 4 Log-Aufrufe mit
  `{defer:true}` und zieht die Nacharbeit über `flushKanbanActionPost()`
  genau einmal nach. Commit `55533c2`.
- **Fund 3 (`auth.uid()` nicht gewrappt):** Migration
  `20260827120000_contact_files_storage_policy_authuid_wrap.sql`
  (schema_patch 56) wrappt `auth.uid()` -> `(select auth.uid())` in
  **allen 6** Policies auf `storage.objects` (die Zweitmeinung wies
  darauf hin, dass auch `photo_select/update/insert_own_folder` und
  `contact_files_storage_insert` betroffen sind, nicht nur die zwei aus
  dem Fund). Reine Performance (InitPlan statt Pro-Zeile-Auswertung),
  keine Verhaltensänderung — mechanisch als identisch nachgewiesen,
  Dry-Run mit `begin`/`rollback` gegen die echte DB (alle 6 Policies:
  Metadaten unverändert, `auth.uid()`-Anzahl je Policy unverändert,
  jetzt alle gewrappt; queue-Zweig/guild-Flags/bucket-Filter erhalten;
  Rückbau auf Rohform getestet). Unabhängige blinde Zweitmeinung (Opus):
  "PUSH OK … kein Sicherheits- oder Berechtigungsrisiko". Angewendet per
  `supabase db push`, live verifiziert (alle 6: `wrapped_uid=1`).
  Commit `f3bc6a6`. Beide Regressionssuiten grün (33/33, 11/11).
  `supabase db advisors --type performance` danach: keine
  `auth_rls_initplan`-Funde mehr (storage.objects war die letzte Quelle),
  nur noch die bekannten `unused_index`-INFOs (Testdatenmenge).

**Direkt danach, gleiche Sitzung — Bestandskunden-Termine aus dem
Trichter genommen.** Nutzer-Hinweis: "wir zählen ja auch in der
Kundendokumentation 3./4. Termin. Diese sind für den Trichter nicht
relevant, weil dort ein Kunde bereits Kunde ist und wir keine
Erfolgsmessung brauchen." Analyse ergab: der `!fromTerminal`-Schutz
(2026-08-26) fing nur den direkten Gewonnen→Zweittermin-Rücksprung ab —
sobald die Karte eines Kunden danach wieder vorwärts wanderte
(Ersttermin→Angebot/Zweittermin, der eigentliche 3./4. Termin), feuerten
`termin_wahrgenommen` (+5 XP) / `zweittermin_vereinbart` /
`zweittermin_wahrgenommen` (+12 XP) erneut und blähten den Trichter auf.
Fix (`0d6124a`): `const isKunde = contact.status === 'kunde'` vor dem
Marker-Block, alle drei Marker mit `!isKunde` gated. Reihenfolge stimmt —
die Marker werden vor `recordWinOrLoss()` ausgewertet, das den Status
erst danach auf `kunde` setzt, der Erst-Abschluss zählt also voll.
Nutzer-Entscheidungen dazu: (1) nur `'kunde'` ausschließen, `'verloren'`
bleibt drin ("wenn ein verlorener Kunde doch noch kommt, war doch mehr
richtig als gedacht"); (2) Kundenausbau-`abschluss` zählt vorerst weiter
im "Gewonnen"-Balken — "wir bleiben zunächst nur im Kanban und tracken
primär diese Themen über Kanban, die Handlungen werden noch überarbeitet"
(siehe Erinnerung `project_b2c_to_b2b_action_rework`). Regressionssuiten
grün (33/33, 11/11).

## 2026-08-27, dritte Sitzung — Rechtemodell-Lücke + Löschanfrage-Workflow

Aufsetzend auf die "Nächster struktureller Schritt"-Reflexion vom
Touchdown der Vortagessitzung: der Nutzer wollte einen der beiden
Kandidaten (Rechtemodell-Lücke vs. Mandantentrennung) angehen. Ausführliches
Vorgespräch zu beiden Themen zuerst (siehe Erinnerung
`project_naechster_struktureller_schritt` für die vollständige Mandanten-
trennungs-Anforderungssammlung, kein Baubeginn dort) — dann konkret:
"Lücke schließen. Auf Sicherheit und Performance achten. Abdecken mit
einem anderen Agent und es langfristig denken."

**Teil 1: canEdit berücksichtigt Gilden-Schreibrecht.** `canEdit` auf der
Kontakt-Seite prüfte seit der Gilden-Sichtbarkeit Phase 1 (2026-08-08)
nie das dritte, von der RLS längst erlaubte Recht (Gildenmitglied mit
`contacts_access='write'`) — Preload-Ansatz (`myGuildContactWriteMemberIds`,
neu geladen bei Login + jeder Gilden-Zustandsänderung, kein Extra-Request
pro Kontakt-Seitenaufruf, da `guild_members.member_id` Primärschlüssel
ist). Fünf parallele Zweitmeinungsrunden (`/code-review high`, jede
Runde mehrere gleichzeitige Finder-Agenten) fanden nacheinander: drei
Backend-Berechtigungsstellen (Kontakt-Löschen, `sales_writable()`/
`cancel_sale_locked()`, Sales-Insert) kannten `guild_contact_permission()`
noch nicht und hätten stille bzw. harte Fehlschläge produziert; eine seit
jeher fehlende `org_id`-Grenze bei `contacts_delete_owner_or_admin`
(hätte theoretisch organisationsübergreifendes Admin-Löschen erlaubt);
eine fehlende Pool-Kontakt-Ausnahme bei den Sales-Policies; ein
Ladefehler-Edgecase, der Schreibrechte fälschlich hätte leeren können;
ein stiller 0-Zeilen-Delete bei zwischenzeitlich entzogenem Schreibrecht.
Alle behoben, per Dry-Run gegen echte Testprofile verifiziert (Vorher/
Nachher, Negativ-Kontrolle ohne Gildenmitgliedschaft). Migration
`20260827174618_gilden_schreibrecht_delete_sales_erweiterung.sql`,
Commit `444f464`. Nebenbei eine veraltete CLAUDE.md-Aussage korrigiert
(`contacts.guild_id` existiert entgegen der alten Notiz doch, seit dem
Mitarbeiter-Offboarding-Pool), Commit `44ac812`.

**Teil 2: Löschanfrage statt Direktlöschung für Gildenmitglieder.**
Direkte Nutzer-Reaktion auf Teil 1: "Die Löschanfrage eines
Gildenmitglieds soll nicht direkt löschen, sondern erst beim Admin
landen. Sonst könnte ein verprellter Mitarbeiter einfach die Datenbank
löschen." `contacts_delete_owner_or_admin` verliert den Gilden-Zweig aus
Teil 1 wieder (Eigentümer/Admin bleiben unverändert direkt löschberechtigt),
neue Tabelle `contact_deletion_requests` + drei `SECURITY DEFINER`-
Funktionen (`request_contact_deletion`/`approve_contact_deletion_request`/
`reject_contact_deletion_request`, gleiches Härtungsmuster wie
`guild_invitations`/`termin_invitations`) + ein `BEFORE DELETE`-Trigger
(`resolve_orphaned_deletion_requests()`), der eine offene Anfrage
automatisch auflöst, falls der Kontakt auf einem anderen Weg verschwindet
(sonst hätte eine verwaiste Anfrage später einen stillen Leerlauf beim
"Genehmigen" produziert). Zwei weitere Zweitmeinungsrunden fanden: eine
fehlende `ON DELETE`-Aktion auf `requested_by`/`reviewed_by` (hätte ein
künftiges Mitarbeiter-Offboarding blockiert, jetzt `on delete cascade`
wie beim strukturell gleichen `access_audit_log`), eine Race-Condition
beim gleichzeitigen Genehmigen (UPDATE bekam dieselbe
`status='offen'`-Bedingung wie beim Ablehnen), fehlendes Wiedervorlage-
Aufräumen vor dem eigentlichen Löschen (reproduzierte einen früher schon
einmal gefundenen Karteileichen-Bug), `withClickGuard()` beim neuen
Button-Zweig nachgerüstet, ein totes `data-request`-Attribut entfernt.
Eine Review-Anregung bewusst nicht übernommen (Wiedervorlage-Aufräumen
NICHT auf `owner_id` der handelnden Person einschränken, da der ganze
Kontakt verschwindet, nicht nur eine Bearbeitung — Begründung in
CLAUDE.md). Migrationen `20260827181923_kontakt_loeschanfrage_admin_
freigabe.sql` + `20260827184155_loeschanfrage_fk_indizes.sql` (zwei
fehlende FK-Indizes, direkter Advisor-Nachlauf), Commit `d27402f`.

Beide Teile: `supabase db advisors` nach jedem Push geprüft (keine neuen
Sicherheits-Funde außer den erwarteten/bereits triagierten Kategorien),
beide Regressionssuiten vor jedem Push grün (33/33 + 11/11). Volle
technische Details in CLAUDE.md, Abschnitte "Rechtemodell-Lücke: canEdit
berücksichtigt Gilden-Schreibrecht" und "Löschanfrage statt
Direktlöschung für Gildenmitglieder". Damit ist der erste der beiden am
Vortag reflektierten strukturellen Kandidaten vollständig abgeschlossen —
Mandantentrennung bleibt der einzige offene Punkt in
`project_naechster_struktureller_schritt`.

## 2026-08-28/29: Org-Grenze-Audit + Pool-Feature (Multi-Org-Loskopplung fertig)

Zwei Sitzungen, direkt aufeinander aufbauend.

**Erste Sitzung (2026-08-28):** Nutzer wollte "das Fundament fertig
bauen" für eine echte zweite, zahlende Organisation. Erster Plan-Entwurf
(Einladungscode pro Org, `org_invitations`-Tabelle) wurde noch vor dem
Bauen verworfen — Nutzer stellte klar: "jeder soll einfach im Pool
landen. In einem neutralen Pool. Von dort aus kann dann jeder eingeladen
werden. So war die Vorstellung eigentlich von Anfang an." Bei der
Umsetzungsplanung fand eine unabhängige Zweitmeinung, dass 22 RLS-
Policies + 1 Funktion nur "ist Admin" statt "Admin von welcher Org"
prüfen — bei einer Org folgenlos, aber ein echtes Cross-Org-Datenleck
sobald eine zweite Org mit eigenem Admin existiert (also genau beim
geplanten Pool-Feature). Nutzer-Entscheidung: dieser Audit zuerst.
Gebaut: neue Hilfsfunktion `is_admin_of(org_id)`, Migration
`20260828140000_org_grenze_fuer_bare_is_admin_policies.sql`, zwei
Dry-Run-Runden + Zweitmeinung mit vier echten, nicht-ausnutzbaren
Funden, beide Regressionssuiten grün, Commit `db99405`.

**Zweite Sitzung (2026-08-29), nach `/clear`:** Nutzer bat "stell mir
alle Fragen zum Pool-Feature" — Claude stellte 10 gebündelte Fragen,
alle in einer Nachricht beantwortet, plus eine gezielte
`AskUserQuestion`-Nachfrage zur zentralen Scope-Gabelung: **Gilde-
Gründung durch einen Pool-Nutzer ist Self-Service und erzeugt
automatisch eine neue Org mit kopiertem Standard-Regelwerk** — bestätigt
mit "Ja, Self-Service (Empfohlen)". Direkte Folgerunde klärte
Mehrfach-Gilden-Orgs: eine Org kann mehrere Gilden haben (Org-Pool als
dritter Kontakt-Zustand, aber "nur Datenmodell jetzt, Verteilungs-UI
später"), aber innerhalb einer bestehenden Org gründet NICHT mehr jedes
Mitglied selbst — "die Organisation muss schon als übergeordneter Admin
zustimmen." Design vollständig geklärt, Plan-Mode-Runde (drei parallele
Explore-Agenten + ein Plan-Agent) fand dabei mehrere Korrekturen
gegenüber der ursprünglichen Skizze: `profiles.org_id` war `NOT NULL`
(Schema-Migration nötig), `protect_privileged_profile_fields()`s
Admin-Bypass hätte `found_own_org()`/`leave_own_org()` blockiert (Fix:
Sitzungs-Flag-Erweiterung), `user_inventory`/`action_log` waren bereits
vollständig portabel (keine Migration nötig, ursprüngliche Sorge
unbegründet), und die vermutete neue SELECT-Policy für den Org-Pool
erwies sich als unnötig (bestehende Policies gewähren `is_admin_of()`
bereits unbedingt).

**Gebaut:** sechs Migrationen (`20260829090000` bis `20260829095000`) —
`found_own_org()`, `admin_create_guild()`, `org_pool_invitations` + 3
Einladungs-RPCs, `search_org_pool_candidates()` (exact-match statt
`ilike()`), `leave_own_org()`, `admin_reassign_contact()`. Dry-Run gegen
die echte, verlinkte DB fand dabei selbst zwei echte Bugs (Ambiguous-
Column-Kollision in der Such-Funktion, fehlendes explizites
`founder_id=NULL`-Setzen im aus dem Account-Löschungs-Trigger
herausgezogenen Nachfolge-Code), beide sofort behoben. Unabhängige
Zweitmeinung (`/code-review high`) fand sechs weitere echte Funde,
darunter zwei kritische (eine neue interne Funktion ohne Revoke, per RPC
von jedem Nutzer zum Gildenführer-Kapern missbrauchbar; ein
Jahre-alter Admin-Bypass in `protect_privileged_profile_fields()`, der
mit Selbst-Gründung zu einem echten Cross-Org-Eskalationsweg geworden
wäre) — alle behoben, erneut per Dry-Run verifiziert.

**Direkter Nutzer-Rückfrage-Dialog danach, zwei Runden:** erste Frage
("was passiert mit den Kontakten eines gildenlosen Mitarbeiters bei
Account-Löschung, hart löschen oder Org-Pool?") führte zunächst zu
Verwirrung ("diese können ja als Freunde einfach in seiner Kontaktliste
bleiben... verstehst du das?") — Klärung ergab, der Nutzer sprach über
die SOZIALE Freunde-Funktion (bereits unberührt), nicht die CRM-Kunden-
Kontakte. Nach präzisierter Nachfrage die eigentliche Antwort: "die
bleiben bei der Firma, weil die Verträge laufen ja über die Firma" +
Folgeerklärung "der Verkäufer hat natürlich Kundenschutz, wenn er seine
Verträge macht, aber nach dem Verlassen der Firma brauchen die ja
weiterhin Betreuung." `handle_member_offboarding()`s "gildenlos"-Zweig
entsprechend von hart löschen auf Org-Pool umgestellt. **Beim
End-to-End-Dry-Run dieser Änderung (echter Wegwerf-Testaccount, nicht
nur isolierte RPC-Tests) ein weiterer, komplett unabhängiger, seit
2026-08-22 bestehender Bug gefunden:** `protect_location_owner_field()`
(Tamper-Schutz gegen unbefugte `owner_id`-Änderungen an Dungeons)
korrigierte JEDE nicht-admin-initiierte Änderung still zurück — hätte
sowohl die Account-Löschung als auch `leave_own_org()` selbst
wirkungslos gemacht (ein austretendes Nicht-Admin-Mitglied ist ja selbst
kein Admin). Fix im selben Zug: weitere Sitzungs-Flag-Erweiterung
(`app.trusted_location_owner_change`).

**Zweite Rückfrage (Frontend):** die erste Warteraum-Fassung war eine
komplett eigenständige Screen außerhalb der normalen App — Nutzer-
Korrektur: "die Anmeldungen dürfen schon auf unsere Plattform. Dort
können die ja bereits Freunde und so adden. Haben halt noch keine
Questbäume, Dungeons und Vertriebsstatistiken (wenn das gerade eine zu
große Baustelle ist, dann schieben wir das auf)." Per `AskUserQuestion`
geklärt: Freunde-Feature bleibt vorerst zurückgestellt (`friends.org_id`
ist `NOT NULL`, bräuchte eine eigene Migration), der Rest wird
umgebaut — Pool-Nutzer sehen jetzt die normale App-Oberfläche (Header/
Sidebar), landen aber zwangsweise auf einer neuen Seite "🏛 Organisation"
(alle anderen Nav-Buttons ausgeblendet, `showPage()` erzwingt das
unabhängig vom angefragten Hash/Deep-Link). Per Playwright visuell
verifiziert (echter Login, `profiles`-Antwort synthetisch auf
`org_id: null` gesetzt, nichts an der echten DB verändert).

**Verifikation vor dem Push:** kompletter End-to-End-Dry-Run
(Haupttestblock + alle 6 Zweitmeinungs-Fix-Verifikationen + zwei echte
Wegwerf-Account-Tests für beide Offboarding-Pfade) grün, `npm run lint`
sauber. Ein zwischenzeitlicher, verwirrender Testlauf-Fehlschlag stellte
sich als eigener Test-Harness-Fehler heraus (veraltete Zwischenkopie der
Migrationen in der kombinierten Testdatei, nicht der eigentliche Code) —
nach frischem Neuaufbau lief alles grün durch. `supabase db push`
angewendet (sechs Migrationen), beide Regressionssuiten danach grün
(33/33 + 11/11, jeweils erster Lauf mit einem transienten "Unexpected
end of JSON input"-Netzwerk-Hänger, beim Retry sauber). Volle technische
Details in CLAUDE.md, Abschnitt "Pool-Feature: Selbst-Gründung von
Organisationen/Gilden + Org-Austritt". Damit ist die in "Technische
Skalierungs-Schwellen" dokumentierte Multi-Org-Loskopplung fertig — die
Registrierungsstelle trägt niemanden mehr fest auf `DEFAULT_ORG_ID` ein.


## 2026-08-29/30: Verbindlicher Fahrplan Phase 1+2 — Pool-Feature-Folgefragen + 5-Agenten-Tiefenprüfung des CRM-Kernstücks

Direkt im Anschluss an den Touchdown des Pool-Features (siehe oben,
Abschnitt "2026-08-28/29") formulierte der Nutzer einen straffen
Fahrplan, wörtlich: "Wo gehobelt wird, fallen Späne. Wir brauchen nun
einen straffen Fahrplan... alles was mit dem Aufreißen dieser Thematik
entstanden ist, müssen wir in den nächsten Sitzungen komplett
durchdenken. Danach brauchen wir wieder die 5 Agents, weil das
Kernstück des CRM absolut genial funktionieren muss. Wenn wir alle
Baustellen beseitigt haben, gehen wir an die Anwenderoberfläche und das
Framework ran." Drei Phasen: Phase 1 (die acht durchs Pool-Feature offen
gelassenen Folgefragen einzeln bewerten), Phase 2 (5-Agenten-
Tiefenprüfung Kanban/Verkauf/Dungeons/Kontakte), Phase 3 (Anwender-
oberfläche + Framework-Migration). Dieser Abschnitt dokumentiert Phase 1
und 2 vollständig — beide 2026-08-30 abgeschlossen. Volle Herleitung der
acht Fäden/warum welche vier davon Bauaufgaben wurden: Claudes
Erinnerungssystem, `project_naechster_struktureller_schritt`,
Abschnitt 9.

### Phase 1 — vier Bauaufgaben, gebaut/gehärtet/live (Commit `3ae6592`, Migrationen `20260830090000`–`20260830100000`)

- **Org-Pool-Verteilungsoberfläche** — Dropdown-Zuweisung für Kontakte
  UND Dungeons in `renderAccountPool()`, nutzbar durch Org-Admin ODER
  den alleinigen Gildenführer einer Ein-Gilde-Org (nur für echte
  Pool-Einträge, nicht für aktiv gehaltene private Kontakte/Dungeons
  von Kolleg:innen). Protokoll (`pool_zuweisung_log`) + Badge bei
  neuer Zuweisung.
- **Freunde-Feature app-weit** statt org-gebunden (`friends.org_id`
  entfernt), neue `search_profile_for_friend()`-RPC für die
  Cross-Org-Suche.
- **Plattformadmin-Fundament** — `platform_admins`/`is_platform_admin()`,
  Regelwerk-Editor kann für Plattformadmins jetzt fremde Organisationen
  bearbeiten. Notfallzugriff-Backend vollständig, bewusst noch ohne
  eigene Oberfläche.
- **Org-Soft-Delete-Fundament** — `organizations.dissolved_at`
  (Platzhalter) + `profiles_org_id_fkey` CASCADE→RESTRICT (verhindert
  versehentliches Mitlöschen aller Accounts einer Org). Volles
  Auflösungs-Feature bleibt ein späteres, eigenes Vorhaben.

Nebenbei ein echter, seit dem Pool-Feature-Launch (29.08.) aktiv
laufender Bug gefunden und mitbehoben: `enforce_profile_insert_defaults()`
zwang jede neue Registrierung weiterhin in die alte Standard-Org statt
in den Pool. Details, inkl. der 6 Funde einer Zweitmeinungsrunde:
`project_naechster_struktureller_schritt`, Abschnitt 10.

**Bewusst nicht Teil von Phase 1, weiterhin offen/vertagt** (keine der
acht ursprünglichen Fragen wurde vergessen, diese vier sind bewusste
Verschiebungen mit Begründung): Zweistufiges Rollenmodell ist als
schlanke Variante gebaut (kein Support-Stufen-System). Automatisierte
Regelwerk-Erzeugung, Level-Kurven-Divergenz zwischen Orgs (bewusst mit
der Automatisierungs-Frage verknüpft) und Weltunternehmen-Vision bleiben
eigene, größere, zukünftige Vorhaben.

### Phase 2 — 5-Agenten-Tiefenprüfung des CRM-Kernstücks

Nutzer-Vorgabe: "das Kernstück des CRM muss absolut genial
funktionieren" — gleiches Muster wie der systematische
12-Häppchen-Bugfix-Durchgang 2026-08-21/22 (siehe oben): mehrere
parallele Review-Agenten pro Bereich (Korrektheit/Effizienz/Cross-File/
Zeile-für-Zeile/totes Verhalten), gezielt auf das CRM-Kernstück
(Kontakte/Kanban/Verkauf/Dungeons — nicht Gamification-Beiwerk). Start
bewusst budgetbedingt klein (3 statt 5 parallele Agenten, Effizienz/
totes Verhalten in einem zweiten Häppchen nachgeholt) — bei Kanban so
gemacht. Der Nutzer korrigierte das bei Verkauf/Statistik ("haben wir
das nicht immer mit 5 gemacht?") und wollte für diesen Bereich gleich
alle 5 auf einmal — bei Dungeons und Kontakte lief entsprechend gleich
mit allen 5 Linsen.

**Kanban** (Commit `cf94df5` + ein weiterer Commit später am selben
Tag): Korrektheit/Zeile-für-Zeile/Cross-File zuerst, 3 echte Bugs
behoben — Doppel-Escaping bei Organisator-Namen; XP/Quest-Boni wurden
vor der eigentlichen, sperr-geprüften Zustandsänderung gebucht statt
danach, gleicher Fehler in zwei Einstiegspunkten
(`moveKanbanCard()`/`logActionForContact()`); "Gewonnen"-XP wurde auch
ohne bestätigten Verkauf gebucht — neuer gemeinsamer Helfer
`moveContactToGewonnenAndRecordSale()` behebt beides. Effizienz + totes
Verhalten (2 parallele Agenten, dieselbe Sitzung): 3 weitere echte
Funde — voller Netzwerk-Refetch + Voll-Rebuild aller 8 Spalten nach
JEDEM einzelnen Kartenzug (`renderKanbanBoard()` bekam ein
`opts.skipFetch`, `moveKanbanCard()` nutzt danach den bereits im
Speicher aktualisierten Cache); unbegrenzt wachsende Scroll-/Resize-
Listener-Anhäufung durch `initScrollFade()` ohne Mehrfachaufruf-Guard
(betraf auch `renderStatTabs()`, an der Wurzel in `initScrollFade()`
selbst gefixt); ein dritter, vom Refactor übersehener "+Verkauf
eintragen"-Knopf auf der Kontakt-Seite (`cdAddSaleBtn`) rief bei
"Gewonnen" weiterhin direkt `recordWinOrLoss()` auf statt
`moveContactToGewonnenAndRecordSale()` — jetzt vereinheitlicht.

**Verkauf/Statistik** (Commits `1fef12f`/`9d30614`, alle 5 Linsen in
einem Rutsch): Zeile-für-Zeile keine Funde (BWS-Kette/
`PRODUCT_ART_CONFIG` exakt wie dokumentiert). Cross-File keine
Sicherheitslücken, ein dokumentierter Rand-Fall (`guild_sales_metric_
total()` verknüpft über `sales.created_by`, das bei echter
Account-Löschung — nicht Org-Verlassen — auf NULL fällt) — praktisch
nur relevant, wenn die Löschung innerhalb desselben, noch laufenden
Geschäftsjahres passiert, BEVOR die Team-Ziel-Schwelle erreicht wurde
(Nutzer-Klarstellung: ein einmal erreichtes Teamziel steht
unveränderlich im `guild_quest_log`-Protokoll, ein Austritt nach
Jahresende ist für das abgeschlossene Jahr folgenlos). Korrektheit: 2
echte Bugs — `guild_sales_metric_total()` summierte für Team-Ziele die
seit der BWS-Umstellung (2026-08-14) tote Spalte `sales.bewertungssumme`,
jedes Lebensversicherungs-Team-Ziel blieb dadurch dauerhaft bei 0
(Migration `20260830110000`, unabhängige Zweitmeinung freigegeben,
Dry-Run mit 6 Assertions grün, live, Funktionskörper direkt gegen die
verlinkte DB verifiziert); `currentBusinessYear()` nutzte das reine
Browser-lokale Jahr statt `tz()` — betraf praktisch die gesamte
Verkaufsstatistik-Jahresgrenze (Kompendium, Akquise-Trichter,
Jahresquest-Reset, Gilden-Team-Ziele, Schatzraum). Effizienz: 2 echte
Funde — `loadAndEvaluateGuildTeamQuests()` fragte Team-Ziel-Summen
sequentiell statt parallel ab; `initTrophyRoom()` hatte keinen Guard
gegen Mehrfachaufruf. Totes Verhalten: bestätigte den
`bewertungssumme`-Fund, dazu ein nie fertiggestellter Anzeige-Stub
("ausgeschüttete Provision: —" zeigte hart einen Strich statt der
längst vorhandenen `saleProvision()`-Berechnung).

**Dungeons** (2026-08-29, Commit `f5a338b`, alle 5 Linsen auf einmal, 5
parallele Agenten): kritischer Fund, von Korrektheit UND Cross-File
unabhängig bestätigt — `assign_location_owner_locked()` (Migration
`20260830091000_org_pool_verteilung_gildenfuehrer.sql` vom Vortag,
erweitert die Funktion um einen Zweig für nicht-admin alleinige
Gildenführer) vergaß, das Trusted-Flag `app.trusted_location_owner_
change` zu setzen, das der bestehende Schutz-Trigger
`protect_location_owner_field()` seit `20260829094000_leave_own_org.sql`
verlangt. Folge: ein Gildenführer bekam beim Zuweisen eines
Pool-Dungeons Erfolg gemeldet, der Trigger setzte `owner_id` still
zurück UND protokollierte einen falschen `location_owner_tamper`-
Sicherheitsalarm gegen die eigentlich berechtigte Person — die Hälfte
des als "live" dokumentierten Org-Pool-Verteilungs-Features war für
Dungeons faktisch wirkungslos, ohne dass ein Fehler zurückkam.
`20260829094000` hatte sogar wörtlich dokumentiert,
`assign_location_owner_locked()` sei "admin-only" und deshalb von
diesem Trigger nicht betroffen — eine Annahme, die durch die
Gildenführer-Erweiterung genau einen Tag später falsch wurde, ohne
nachgezogen zu werden. Migration
`20260830150000_dungeon_review_permission_fixes.sql` behebt das (+ eine
kleinere, von der Cross-File-Linse gefundene Lücke: fehlende Prüfung,
ob die neue `owner_id` überhaupt zur Organisation gehört). Dry-Run mit
4 Assertions gegen die echte, verlinkte DB (echte Testprofile temporär
in eine Wegwerf-Org verschoben) grün, unabhängige Zweitmeinung (zwei
getrennte Agenten für SQL und JS) fand keine weiteren Probleme, live
gepusht. Weitere echte Funde direkt im Frontend behoben: fehlendes
`escHtml()` bei Rolle/Status in der Kontakttabelle, veralteter "nur
admin"-Hinweis auf der Account-Pool-Karte (Karte ist seit dem
Org-Pool-Feature auch für Nicht-Admins sichtbar), doppeltes Leerzeichen
in der Adresse bei leerer PLZ, kompletter Re-Fetch+Rebuild nach einer
einzelnen Kontakt-Zuweisung ersetzt durch gezielte DOM-Aktualisierung +
parallel statt sequenziell ladende `refreshDungeonData()`. Eine
Race-Condition in der neuen DOM-Aktualisierung (veraltete Closure bei
überlappendem Neu-Render) wurde von der Zweitmeinungsrunde zum eigenen
Fix selbst gefunden und ebenfalls behoben — Beleg, dass die
Zweitmeinungs-Pflicht auch auf den eigenen Fix angewendet werden
sollte, nicht nur auf den ursprünglichen Fund.

**Kontakte** (2026-08-30, alle 5 Linsen, 5 parallele Agenten): größte,
am stärksten verzahnte Lückenklasse der ganzen Phase 2. Kontakte aus
dem Mitarbeiter-Offboarding ("Gilden-Pool" — herrenlos, aber einer
Gilde zugeordnet, `owner_id IS NULL AND guild_id IS NOT NULL`) waren
serverseitig an neun Stellen unsichtbar/unbearbeitbar (`sales`,
`contact_activities`, `termine`, `action_log`, `contact_files` inkl.
Storage, `request_contact_deletion()`, `admin_reassign_contact()`).
Cross-File- UND Korrektheits-Linse fanden unabhängig, dass `canEdit`
auf der Kontakt-Seite diesen dritten Fall (neben Eigentümer/Admin) nie
kannte — "Bearbeiten"/"Löschanfrage stellen"/"+ Verkauf eintragen"/
Datei-Upload blieben für die zuständige Gildenführung unsichtbar.
Migration `20260830160000_kontakte_review_permission_fixes.sql` (nach
eigener Zweitmeinungsrunde von ursprünglich 6 auf 9 behobene Stellen
erweitert — die Zweitmeinung fand `contact_files` komplett vergessen,
dazu `termine`/`action_log`, sowie eine Inkonsistenz zwischen Lese- und
Schreibrecht) vereinheitlicht das Modell: lesen darf jedes
Gildenmitglied (wie beim Kontakt-Datensatz selbst,
`contacts_select_visible`), schreiben/hochladen/löschen nur die
Gildenführung (kein Eigentümer vorhanden, der delegieren könnte). Neue
Helferfunktion `guild_pool_read_permission()` neben dem bestehenden
`guild_leadership_permission()`. Zwei Dry-Run-Runden gegen die echte,
verlinkte DB (zweite mit echten Test-Rollenwechseln für "einfaches
Mitglied"/"Gildenführung"/"Außenstehender", inkl. `storage.objects`)
grün, live gepusht.

Weitere echte Funde direkt im Frontend behoben: XP wurde an zwei
Kontakt-Seiten-Einstiegspunkten vor statt nach der sperr-geprüften
Kanban-Änderung gebucht (gleiche Bug-Klasse wie beim Kanban-Review, hier
übersehen); ein `getElementById('waitingRoomScreen')`-Zugriff auf ein
nicht mehr existierendes Element ließ "Organisation gründen"/
"Org-Einladung annehmen" mit stillem JS-Fehler abbrechen — ein echter,
seit dem Pool-Feature-Launch aktiver Show-Stopper, der Betroffene auf
der Warteseite hängen ließ, obwohl die Aktion serverseitig erfolgreich
war (nur ein Neuladen half); `#kontakt/<id>`- und `#tagebuch/...`-Deep-
Links umgingen die Pool-Navigationssperre; eine Rennbedingung beim
schnellen Kontaktwechsel konnte Chronik/Dateien/Kennzahlen des falschen
Kontakts anzeigen; Formular zuklappen ohne zu speichern setzte den
Bearbeitungszustand nicht zurück (ein neuer Kontakt hätte den vorherigen
sonst überschrieben); eine tote CSS-Klasse ließ Vertrags-/Dateizeilen
unstyled; die Adresszeile kollabierte durch mehrfache Leerzeichen.
Effizienz: Kontaktliste/Kanban laden nicht mehr die Verkaufshistorie
*aller* sichtbaren Kontakte mit (nur noch die offene Detailseite lädt
gezielt für den einen Kontakt), Kontaktliste+Detailseite teilen sich
eine Ladung statt sie zu verdoppeln.

**Direkter Nachtrag, noch am selben Tag — Nutzer-Korrektur der
Auto-Löschungs-Ausnahme.** Ein ursprünglicher Zwischenstand hatte
Gilden-Pool-Kontakte komplett von der automatischen Inaktivitäts-
Löschung ausgenommen (Sorge: die 30-Tage-Sonderquest-Vorwarnung ist
eigentümergebunden und kann für einen Pool-Kontakt nie greifen, ein
stilles Löschen ohne jede Vorwarnungsmöglichkeit widerspräche dem
"niemals gelöscht"-Versprechen). Nutzer stellte klar: "Herrenlose
Kontakte in einer Gilde im Pool dürfen nach einem halben Jahr gelöscht
werden, wenn es keine Verträge gibt. Gibt es Verträge, sind das einfach
Kunden ohne Betreuung, aber sind ja immer noch Kunden der Firma." Ein
Pool-Kontakt OHNE jemals gewonnenen Vertrag ist also ein schlicht
liegengebliebener Lead und wird wie jeder andere Kontakt ohne Vertrag
ganz normal automatisch gelöscht — der eigentlich schützenswerte Fall
(Vertrag vorhanden) war schon vorher unabhängig vom Eigentümer-Zustand
geschützt (`not exists (sales where status='gewonnen')`), die
Eigentümer-Ausnahme war also zu weitgehend. Migration
`20260830170000_pool_kontakte_auto_delete_praezisierung.sql` nimmt sie
vollständig zurück (Funktionskörper wieder byte-identisch zur
Ur-Fassung aus `20260825201448`), erneut Dry-Run + unabhängige
Zweitmeinung (keine Funde), live gepusht.

Beide Regressions-Suiten liefen vor jedem der Pushes in Phase 1 und 2
grün.

### B2C→B2B-Aktions-Rework der Handlungen-Seite — Konzeptgespräch, 2026-08-30

Zusätzlich zur 5-Agenten-Prüfung ergänzte der Nutzer am 2026-08-29
explizit ein reines Konzeptgespräch (kein Code) zum längst
angekündigten B2C→B2B-Aktions-Rework der Handlungen-Seite — geführt am
2026-08-30, voller Gesprächsverlauf in Claudes Erinnerungssystem,
`project_b2c_to_b2b_action_rework`. Ausgangspunkt: die Handlungen-Seite
stammt aus einer ursprünglich B2C geplanten Frühphase (freistehende,
kontaktlose Aktions-Knöpfe zum Anklicken, XP dafür) — im B2B soll
nichts, was tatsächlich beim Kunden passiert, mehr anonym im System
landen.

Nutzer-Kernbeobachtung: das Kanban ist praktisch schon das echte
Herzstück der Handlungen — Kunden-Aktionen werden dort dokumentiert,
nachverfolgt, mit XP belohnt, UND dieselben Aktionen lassen sich schon
heute direkt am Kontakt loggen ("Aktion loggen"/"Anruf-Email loggen").
Durchgesprochen Knopf für Knopf: Ansprache bleibt unverändert
Dungeon-gebunden (echte Vor-Ort-Kaltakquise ohne existierenden
Kontakt). Kalttelefonie/"5 Nummern gewählt" ist die einzige echte
strukturelle Änderung — Nutzer-Klarstellung, B2B-Kaltakquise läuft bei
ihm praktisch immer über vorher recherchierte (LinkedIn/
Firmenwebsite), schon im System stehende Kontakte ("kalt" heißt nur
"kennt uns noch nicht persönlich", nicht "steht nicht in der
Datenbank") — die Zählung soll deshalb künftig aus echten, am Kontakt
geloggten Anrufen abgeleitet werden statt manuell per Extra-Knopf.
Bedarfsanalyse/Pitch/E-Mail liefen schon korrekt kontaktgebunden.
Fachinfo recherchiert bleibt bewusst unangetastet fürs künftige Lern-/
Zertifikatsystem ("Grimoire").

Wichtige Architektur-Vorgabe des Nutzers (Bild: "ein Karton auf den
Dachboden"): der Code, der freistehende, kontaktlose Aktionen überhaupt
ermöglicht, darf beim Umbau nicht gelöscht, gestört oder so verbogen
werden, dass er nur noch für einen Spezialfall funktioniert — Grund: in
einer weiter entfernten Zukunft ist eine eigene B2C-"Life"-App angedacht
(Sport/Yoga/Joggen, sowie echte, bewusst CRM-lose Kalttelefonie ohne
Dateneintrag jeder einzelnen Nummer — "sonst ist das nur Datenmüll").
Passt bereits zur bestehenden Architektur (Aktionen leben als Daten im
Regelwerk je Organisation, nicht hart im Code) — für die aktuelle
B2B-Organisation verschwinden Kalttelefonie/"5 Nummern gewählt" einfach
aus dem aktiven Regelwerk, der generische Code bleibt bestehen, eine
künftige B2C-Organisation bekäme einfach ihr eigenes Regelwerk.

Bewusst offen gelassen, keine Details: eine vom Nutzer angedeutete Idee,
die Handlungen-Seite künftig um "modernere, zukunftssichere
Vertriebs-Automatismen" zu erweitern, die jedem Mitarbeiter am
Tagesanfang eine Arbeitsrichtung geben — ausdrücklich noch keine
Gedanken dazu, nicht nachgehakt, bei nächstem Anstoß neu erfragen.

Bau folgt laut ausdrücklicher Nutzerentscheidung erst als Teil der
Phase-3-React-Migration, nicht vorher in Vanilla JS, damit nicht
zweimal gebaut wird — siehe Claudes Erinnerungssystem,
`project_framework_migration_plan`.

**Damit sind Phase 1 und Phase 2 des Verbindlichen Fahrplans komplett
abgeschlossen.** Weiter mit Phase 3 (Anwenderoberfläche +
Frontend-Framework-Frage) — kompletter Fahrplan dafür bereits in einer
eigenen Planungssitzung erarbeitet, siehe Claudes Erinnerungssystem,
`project_framework_migration_plan`.

## 2026-09-01: Drei Bugreports vom ersten echten Kollegen-Onboarding

Ein Kollege hat sich auf der Plattform registriert (landete also im
Pool, `org_id` NULL). Der Nutzer hat ihn per Org-Pool-Einladung in seine
Organisation geholt und sich als Freund hinzugefügt. Dabei drei Fehler,
alle behoben.

**1+2 — „Im Zentrum steht weiterhin, ich sei in keiner Organisation",
Einladung verschwindet erst nach Reload.** Gleiche Wurzel:
`renderWaitingRoom()` ruft `showPage('organisation')` und setzt damit den
URL-Hash auf `#organisation`. Nimmt der Pool-Nutzer die Einladung an,
läuft `enterApp()` neu durch (Sidebar wird korrekt freigeschaltet,
`setPoolNavVisibility(false)`), am Ende stellt `restoreLastPage()` aber
den Hash `#organisation` wieder her — und `organisation` steht in
`VALID_PAGES`, also blieb die Warteraum-Seite im Zentrum sichtbar,
obwohl der Nutzer längst in der Org war. Fix in `showPage()`: der
bestehende `if(profile.org_id === null) pageName = 'organisation'` bekam
ein `else if(pageName==='organisation') pageName = 'charakter'` — wer eine
Org hat, wird von der Warteraum-Seite weg auf die Charakterseite geleitet,
der Hash wird dabei korrigiert (`pageName !== requestedPage`). Deckt
Annehmen, Gründen, Reload und Deep-Link gleichermaßen ab.

**3 — „Sind angeblich Freunde, aber ich sehe dich nirgends."** Folgefehler
zu Patch 58 (`20260830090000_friends_org_unabhaengig.sql`): dort wurden
Freundschafts-Tabelle und -Suche firmenübergreifend gemacht, die
**Anzeige** nicht. `renderFriendGrid()` / `renderFriendRequests()` holten
das Profil der Gegenseite weiter per direktem
`sb.from('profiles').select(...).in('id', ids)` — org-gebunden über
`profiles_select_visible`. Ein Freund aus einer anderen Org oder aus dem
Pool erzeugt zwar eine echte `friends`-Zeile, fiel aber aus beiden
Listen raus. Fix: neue `SECURITY DEFINER`-Lesefunktion
`friend_link_profiles()` (Patch 60,
`20260901120000_friend_link_profiles_appweit.sql`) nach dem Muster von
`search_profile_for_friend()` / `friend_skill_totals()` — liefert nur
Anzeigename/Klasse/Level + Avatar-/Sigil-Felder, und nur für Personen
mit echter `friends`-Verbindung (accepted beide Richtungen, oder
eingehende offene Anfrage; die eigene ausgehende offene Anfrage bewusst
NICHT). Frontend beide Renderer auf `sb.rpc('friend_link_profiles')`
umgestellt, Ergebnis clientseitig gegen die eigene `friends`-Abfrage
gefiltert.

Zusatzfund der unabhängigen Zweitmeinung (Opus, blind, Pflichtregel für
berechtigungsrelevante Migrationen): `friends_insert_own` prüfte den
`status` beim INSERT gar nicht — ein Nutzer konnte per rohem REST-Aufruf
`insert friends {owner_id: ich, friend_id: <opfer>, status: 'accepted'}`
eine einseitig „bestätigte" Freundschaft erzeugen und damit sowohl
`friend_link_profiles()` als auch das schon länger bestehende,
weiterreichende `friend_skill_totals()` / `socially_visible()` auslösen
(Opfer-UUID app-weit über `search_profile_for_friend()` beschaffbar).
Vorbestehende Lücke, nicht von dieser Migration verursacht — aber im
selben Aufwasch geschlossen: `friends_insert_own` WITH CHECK jetzt
`owner_id = auth.uid() AND status = 'pending'`. Annehmen läuft ohnehin
ausschließlich über `friends_update_recipient_accepts` (Empfänger-UPDATE),
nie über den Absender-INSERT — legitimer Ablauf unberührt (Frontend fügt
immer `status:'pending'` ein). Dry-Run gegen die verlinkte DB
(`begin/rollback`, 6 echte Testprofile, 11 Checks) grün, u.a.: forged
`accepted`-INSERT wird jetzt von RLS blockiert, legitimer
`pending`-INSERT geht weiter.

**4 — Abenteuerlog: Seite lässt sich nicht ganz scrollen, mal so, mal so,
nach Reload weg.** `initJournal()` rendert den Kalender im
`enterApp()`-Ablauf oft noch, während `#page-tagebuch` `display:none`
ist. Die Monatsansicht (`.cal-day` mit `aspect-ratio` im Grid) berechnet
ihre Zeilenhöhen dann teils falsch und reflowt beim späteren Einblenden
nicht von selbst nach — die letzte Woche ragt unter den sichtbaren
Bereich, der Seiten-Scroll klemmt davor. Ein Reload auf dem
`#tagebuch/<mode>/<datum>`-Hash rendert über `routeToHash` →
`setCalViewMode()` sichtbar neu (deshalb „nach Reload tutti"), ein Klick
auf den Nav-Reiter tat es nicht. Fix: `showPage('tagebuch')` rendert den
Kalender jetzt mode-bewusst neu (`renderDayView`/`renderWeekView`/
`renderCalendar` je nach `calViewMode`), sobald die Seite sichtbar wird —
gleiches Muster wie nach jedem Tagebuch-Speichern.

`npm run lint` sauber, beide Regressions-Suiten grün (33/33 + 11/11; die
Suiten haben eine bekannte Flakiness — kein `try/catch` um
`response.json()` nach `route.fetch()`, ein Netzwerk-Blip lässt sie
gelegentlich beim Laden abstürzen, unabhängig vom Code, per
Stash-Gegenprobe bestätigt).

## 2026-09-01: Review-Runde Freunde/Pool/Gildeneinladungen (nach dem Kollegen-Onboarding)

Nutzer wollte nach den drei Onboarding-Bugs vom selben Tag einen
gezielten Code-Review über genau diese drei Bereiche ("war gestern ein
wenig peinlich"). Vier Commits.

**A — `/code-review` über die letzten 3 Commits, drei Funde, Commit
`758f2c3`:**
1. **Abenteuerlog-Race:** `routeToHash()`/`jumpToJournalDay()` riefen
   erst `showPage('tagebuch')` (rendert den Kalender mit noch STALEM
   `calViewMode`/`calWeekStart`) und direkt danach `setCalViewMode()`
   mit dem korrekten Ziel-Tag. Zwei async `renderWeekView`/`renderDayView`
   parallel — kam die alte `termine`-Abfrage nach der neuen zurück,
   überschrieb sie die Ansicht mit der falschen Woche. `showPage()`
   bekam `skipCalRender`, den diese beiden Aufrufer setzen.
2. Derselbe Pfad lud den Kalender bei jedem Deep-Link/Reload doppelt —
   durch (1) miterledigt.
3. `friend_link_profiles()` wurde pro `initFriends()` zweimal parallel
   aufgerufen (`renderFriendRequests` + `renderFriendGrid`), identische
   Daten. Einmal via `loadFriendLinkProfiles()` geholt und
   durchgereicht.

**B — Zweitmeinung fand: `skipCalRender` fixt nur die zwei bekannten
Aufrufer, Commit `1adceac`:** `renderCalendar`/`renderWeekView`/
`renderDayView` selbst hatten keinen Staleness-Schutz — jeder andere
überlappende Render (schnelles Vor/Zurück, Reiter-Wechsel mitten im
Laden) konnte weiter stale Daten setzen. Modul-Zähler `calRenderGen`:
jeder Renderer merkt sich beim Start `++calRenderGen` und bricht nach
jedem `await` ab, wenn inzwischen ein neuerer lief.

**C — Migration `20260901180000` (Patch 61), Commit `1cc3e6d` — zwei
Org-Grenze-Funde, live gepusht:** siehe CLAUDE.md, Abschnitt "Org-Grenze
für nackte is_admin()-Prüfungen", Nachtrag 2026-09-01. Kurz:
- `guild_members` konnte per direktem REST-Insert (`joinGuild()`) ODER
  per `invite_to_guild()`/`respond_to_guild_invitation()` eine Zeile in
  der Gilde einer **fremden Org** bekommen — die `guild_*_permission()`-
  Helfer sind reine `guild_members`-Joins ohne Org-Recheck → Cross-Org-
  Sichtbarkeit von Kontakten/Dungeons/Chronik. Fix: `BEFORE INSERT OR
  UPDATE OF guild_id, org_id`-Trigger `enforce_guild_members_org_
  consistency()` (strukturelle Invariante `guild_members.org_id =
  guilds.org_id`, greift auch bei den `SECURITY DEFINER`-Funktionen)
  + Org-Prüfung direkt in beiden Einladungsfunktionen.
- `search_profile_for_friend()` (seit Patch 58 app-weit) nutzte `ilike
  p_name` ohne `%`-Neutralisierung → `p_name='%'` dumpte jedes Profil
  jeder Org. Fix: exact-match + Leerstring-Guard + `limit 25`.

**Prozess:** Der Selbst-Beitritts-Weg (Tür b oben) wurde erst von der
blinden Zweitmeinung (Opus) gefunden — die erste Fassung der Migration
härtete nur die Einladungsfunktionen und hätte die Lücke offen
gelassen. Dry-Run wuchs dabei von 13 auf 19 Fälle (u.a. gefälschter
Self-Join von Trigger blockiert, gefälschter Self-Join mit fremder
`org_id` von der RLS-Policy blockiert, legitimer Same-Org-Self-Join
funktioniert). Zweitmeinung nach der Überarbeitung: Approve. Beide
Regressions-Suiten grün vor jedem Push (Suite-Flakiness einmal
getriggert durch ein falsches Server-Arbeitsverzeichnis im Testaufruf,
nicht durch Code — mit `--directory` behoben, danach 33/33 + 11/11).

**Weiterhin offen, bewusst (kein Regress):** die `guild_*_permission()`/
`socially_visible()`-Helfer joinen `guild_members` weiter ohne
internen Org-Recheck — durch die neue Trigger-Invariante an der Quelle
neutralisiert, aber architektonisch implizit. Und ein Enumerations-
Orakel für exakte Anzeigenamen über die Firmengrenze bleibt der Preis
der app-weiten Freundes-Suche.

---

## 2026-09-02: Phase 3 gestartet — blinder Review, Brücken-Vorbereitung, React-Etappen 1+2

Nach dem erfolgreichen Pitch bei einem IT-Unternehmen hat der Nutzer den
Baustart für Phase 3 (React-Migration, siehe `project_framework_
migration_plan`) freigegeben. Eine Sitzung, 10 Commits (`3b38c0c` …
`b982dcb`), alle mit grüner Regressions-Suite (33/33 + 11/11),
`npm run lint` und (ab Etappe 1) `npm run typecheck` gepusht.

### Blinder Review des konsolidierten Plans

Der Nutzer fragte gezielt nach ("Hast du eine Zweitmeinung zu exakt
diesem Fahrplan eingeholt?"). Die 3 Spezialisten-Reviews vom 2026-08-29
liefen iterativ *während* der Planung — es gab keinen blinden
Gegenlese-Durchgang der fertigen Fassung. Also: Opus-Agent, kein
Sitzungskontext, Prüfung gegen den echten Code. Urteil "tragfähig mit
Korrekturen", 3 davon vor Block 1 zu lösen. Wichtigste Funde:

- **S1 — "ein geteilter Supabase-Client" ist unmöglich:** der gesamte
  `<script>` ist eine geschlossene IIFE (`grep -c "window\.\w* *="` →
  0), nichts exportiert, und **kein `onAuthStateChange`-Listener** —
  die Session wird genau einmal beim Init gelesen. Entscheidung (Nutzer:
  "wenn das best practice ist, dann weg a"): Weg A, ein bewusstes
  benanntes Fenster `window.__bridge` + den fehlenden Listener
  nachrüsten.
- **S2 — die Regressions-Suite lag nicht im Repo** (`~/.local/share/
  playwright-portable/`), an Klassennamen/IDs gekoppelt (`grep -c
  data-testid index.html` → 0), und im Strangler-Fig sagt "grün" nicht,
  welche Implementierung getestet wurde. Entscheidung: lokaler
  Vor-Push-Check bleibt (kein CI für Tests), aber Suite ins Repo +
  `data-testid` + Flakiness-Fix vor Block 1.
- **S3 — kein Plan für Feature-Velocity:** `index.html` wuchs ~1.750
  Zeilen/Woche über 6 Wochen, 150 Commits/30 Tage. Entscheidung:
  **harter Feature-Stopp im Alt-Code bis Ende Block 3** (nur Bugfixes),
  Blöcke 1–3 zeitboxen.
- **S4 — Reihenfolge:** Block 3 (App-Rahmen, `render()` von 9 Stellen,
  XP/Level/Energie) kam vor dem Pilot, der ihn entschärfen soll →
  getauscht. Neue Reihenfolge: Grundgerüst → Brücke → **Pilot im
  Wegwerf-Layout** → App-Rahmen → Kanban+Kontakte → **5b B2C→B2B-Rework
  (erste Prio danach, Nutzer: "notier das aber sauber")** → Rest.
- **S6:** Baseline-Zahlen im Plan ~15 % veraltet — `index.html` 11.175
  (nicht 9.800), `<script>` 9.013, 102 Migrationen (nicht "~60+").
- **S7:** `loadContactsBundle()` ohne `.limit()` — geprüft, KEIN
  aktueller Bug (größte Tabelle 274 Zeilen), aber echte serverseitige
  Paginierung gehört fest in Block 5.
- **S8 — Tailwind vs. das Runtime-CSS-Variablen-Theme ist eine
  ungescopte Kollision.** Entscheidung: Styling-Ansatz (Tailwind ja/
  nein) offen bis zu einem Praxis-Spike (`docs/adr` 0006), CSS-Variablen
  bleiben Quelle der Wahrheit.
- Kleineres: TanStack Query + Tailwind sind KEIN "austauschbares
  Kleingeld" → eigene ADRs; React-vs-Vue-Begründung von "Hireability" auf
  Trainingsdaten-Dichte geschärft; "striktes TS ersetzt Code-Review" als
  Overclaim entschärft; Vorschau-Deployments von "erwägen" auf Pflicht;
  `@supabase/supabase-js`-CDN pinnen; GDPR-Nebengewinn (npm-Bundling
  entfernt jsDelivr+unpkg).

Alle Entscheidungen in `project_framework_migration_plan` (Abschnitt "⭐
BLINDER REVIEW") + als ADRs 0001–0005 in `docs/adr/` + `docs/migration-
status.md` festgehalten (`3b38c0c`).

### Sicherung vor Baustart

git-Tag `demo-2026-09-02-pre-react` (annotiert, gepusht) + Desktop-Ordner
`~/Schreibtisch/FantasyArbeit-Backup-2026-09-02/` (`git bundle` mit
kompletter Historie + `git archive`-Snapshot + `index.html` + README).

### Vor-Block-1-Vorbereitung

- **`32a8a94` — `window.__bridge`** (~27 Zeilen in `index.html`, rein
  additiv): `{ sb, getSession, getProfile, onAuthChange }` als einziger
  Übergabepunkt (ADR-0002), plus der bisher komplett fehlende
  `sb.auth.onAuthStateChange`-Listener (hielt die `session`-Variable u.a.
  bei Token-Refresh nie nach — eigenständige Lücke).
- **`2634e6e` — Suiten ins Repo** unter `tests/`, `tests/run-
  regression.mjs` startet den `python3 -m http.server` selbst → `npm
  test`. Playwright als exakte devDependency (`1.62.1`, Chromium über
  die normale Auflösung gefunden, kein Download). Zugangsdaten bleiben
  außerhalb des Repos (per Env überschreibbar).
- **`fade371` — `data-testid` + Entflackerung:** an ~30 von den Suiten
  angesteuerten Stellen `data-testid` gesetzt (statisches HTML + 5
  `render*`-Templates), Suiten laufen nur noch über `tid('...')` bzw.
  `data-page`. Register in `tests/README.md` — **ein migrierter Bereich
  bekommt denselben testid-Wert.** Flakiness: feste `waitForTimeout()`
  → `waitForSelector`/`waitForFunction` auf echte Zustände, Helfer
  `gotoHash()`. Fund unterwegs: die Suiten warfen manchmal einen
  `TargetClosedError` aus einem laufenden `route.fetch()` beim
  `browser.close()` → `page.unrouteAll({behavior:'ignoreErrors'})` davor.
  Vorher ~jeder 6. Lauf verlor einen wechselnden Test, danach 22 Läufe
  hintereinander grün.

### Etappe 1 — Grundgerüst (`bd96246`)

React 19 / Vite 8 / TanStack Query 5 / RHF 7 + Zod 4. **Stolperstein
genau wie im Review vorhergesagt:** `npm i typescript@latest` zog TS
**7.0.2** (das native GA-`tsc`), aber `typescript-eslint@8` hat Peer
`typescript <6.1.0`. typescript-eslint ist laut Review der strukturelle
Ersatz fürs Code-Review → muss laufen → **TS exakt auf 5.9.3 gepinnt**,
volle Begründung in `docs/setup-notes.md`. Vite-Einstieg **`dev.html`**
(kollidiert nicht mit der produktiven `index.html`). `tsconfig` strict +
`noUncheckedIndexedAccess` + `noUnused*` von Anfang an, aufgeteilt in
`tsconfig.app.json` / `tsconfig.node.json`. `eslint.config.js` in drei
gescopte Blöcke (src / index.html / tests). `src/`-Struktur nach
ADR-0005 mit README-Stubs. `npm run dev|build|typecheck` dazu. Verifiziert
inkl. headless-Render von `dev.html`.

### Etappe 2 — die Brücke (4 Stücke, alle einzeln committbar)

Auf ausdrücklichen Nutzerwunsch ("du musst an angemessenen stellen halt
machen … überheb dich nicht", Erinnerung `feedback_commit_sized_chunks_
pause_often`) in 4 gepushte Teilstücke zerlegt, nach jedem gemeldet:

- **`a9169e6`** — `npm run gen:types` (`supabase gen types typescript
  --linked` → `src/shared/types/supabase.ts`, mitversioniert, 2.622
  Zeilen, nie von Hand ändern). `@supabase/supabase-js` als devDep
  **exakt `2.114.0`** (nur Typen — der Runtime-Client kommt aus der
  Brücke), `index.html`-CDN von `@2` auf `@2.114.0` gepinnt (Review-
  Blindspot, Regressions-Suite grün nach dem Pin). `src/shared/lib/
  bridge.ts`: typisierter `getBridge()`/`sb()`, wirft mit klarer Meldung
  ohne Brücke.
- **`13e7e0e`** — `src/app/queryClient.ts` (`refetchOnWindowFocus:
  false` wie Vanilla, Mutations `retry: 0` damit die `updated_at`-
  Sperrprüfung nicht doppelt läuft, Query- UND Mutation-Fehler global
  → `error_log`). `src/shared/lib/errorLog.ts` (`logSilentError`/
  `logToErrorLog`, schreibt in dieselbe Tabelle wie `reportError()`).
  `src/app/ErrorBoundary.tsx` + `createRoot`-`onUncaughtError`/
  `onCaughtError` (React 19). `main.tsx`: ErrorBoundary >
  QueryClientProvider > HashRouter > App.
- **`ba43e8c`** — `src/shared/design-tokens/classTheme.ts` (typisierte
  `CharacterClass`, `CLASS_LABELS`, `THEME_VARS`, `getThemeColor()` —
  Farbwerte bewusst NICHT dupliziert, die CSS-Variablen sind die Quelle
  der Wahrheit, Vanilla `applyClassTheme()` setzt sie, React im selben
  Dokument erbt sie). `src/shared/hooks/useCharacterClass.ts`
  (`useSyncExternalStore` auf `onAuthChange`, fällt ohne Brücke sauber
  auf Default). `App.tsx` nutzt beides als Nachweis.
- **`b982dcb`** — `src/shared/hooks/useGuardedAction.ts` (`{ pending,
  run }`, `busy`-Ref synchron — wie `withClickGuard()`).
  `src/shared/lib/notifyConflict.ts` (`window.alert` wie
  `alertConflict()`, wird Toast mit adr 0006). `src/shared/lib/
  lockedUpdate.ts` (`rpcLockedUpdate` inkl. der PostgREST-NULL-als-
  Objekt-Eigenheit + `lockedUpdate` mit Konfliktmeldung + `error_log`,
  typisiert gegen die 6 `*_locked`-Funktionen). Cast an der supabase-js-
  Grenze nötig, weil `.rpc()` die Signatur nicht aus einem generischen
  Funktionsnamen ableiten kann; öffentliche API bleibt voll typisiert.

**Stand am Sitzungsende:** Etappen 1+2 fertig, **keine einzige Seite
migriert**, `index.html` außer dem CDN-Pin unberührt, die echte App
läuft unverändert. Offen: Vorschau-Deployment (Nutzer-Account nötig),
dann Etappe 3 (Pilot).
