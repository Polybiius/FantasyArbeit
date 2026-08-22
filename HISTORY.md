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
