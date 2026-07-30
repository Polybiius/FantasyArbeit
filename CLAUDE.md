# Projekt: Vertriebs-Quest (Gamifiziertes CRM für Vertriebsteams)

Dieses Dokument ist der Gedächtnis-Ersatz für eine lange Chat-Konversation, in der
dieses Projekt von Grund auf entstanden ist. Lies es vollständig, bevor du an
irgendetwas im Repo arbeitest.

## Die Grundidee

Der Nutzer (Vertrieb, aktuell akademische Heilberufe/Krankenhäuser) wollte die
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
- **Bisheriger Workflow**: Der Nutzer hat NICHT lokal mit Git gearbeitet, sondern
  jede neue `index.html`-Version über den GitHub-Web-Upload hochgeladen, und jeden
  SQL-Patch manuell im Supabase SQL-Editor ausgeführt. Das ändert sich jetzt mit
  Claude Code.

## Datenbank — aktueller Stand (Annahme: Patch 1–20 sind alle eingespielt)

**Wenn das nicht stimmt, sofort korrigieren, bevor irgendetwas gebaut wird** — sonst
versucht Claude Code eventuell, Dinge doppelt anzulegen oder Migrationen in falscher
Reihenfolge zu bauen.

Alle SQL-Patches liegen im Ordner `sql/` (chronologisch benannt, `schema.sql` +
`patch.sql` sind die ursprüngliche Basis, danach `patch2_...` bis `patch20_...`).
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
- `sales` — echte Verkaufshistorie (nicht nur ein Feld!): mehrere Produkte pro
  Kontakt über die Zeit, je mit Datum und `status` ('gewonnen'/'verloren').
  Produktkatalog ist bewusst noch **nicht** gebaut — `produkt` ist Freitext,
  ein echter Katalog (wie `items`) ist ein bewusst aufgeschobener nächster
  Schritt.
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

**Spaltenübergänge und was sie auslösen** (Logik in `moveKanbanCard()`):
- → Ersttermin vereinbart: Aktion `termin_vereinbart`. Auch erreichbar per
  Klick auf "Termin vereinbart" an einem Dungeon (fragt dann nach
  Vorname/Nachname und legt den Kontakt live an, statt anonym zu loggen).
- → Nicht erschienen: **nur von Ersttermin vereinbart aus**, sonst Abbruch.
  Loggt `termin_nicht_wahrgenommen` (−2 XP, der lange geplante
  Konversions-Malus).
- → Angebot versendet / Zweittermin: Aktion `pitch`, danach optionales Popup
  "Bedarfsanalyse geführt?" (Kann übersprungen werden).
- → Gewonnen: Aktion `abschluss`, danach Produkt-Abfrage → Eintrag in `sales`
  (gewonnen), `contacts.status` → 'kunde'.
- → Verloren: **keine XP-Aktion** ("Verloren ist verloren"), nur
  Produkt-Abfrage → Eintrag in `sales` (verloren), `contacts.status` →
  'verloren'.
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

## Bewusst aufgeschobene Ideen (NICHT vergessen, aber NICHT von selbst bauen)
- **Produktkatalog** (wie `items`, aber für `sales.produkt`) — aktuell Freitext.
- **Jahresend-Dramatisierung**: alle Tagebucheinträge (+ ggf. Fotos) eines
  Nutzers werden am Jahresende per LLM zu einer zusammenhängenden
  Heldenreise-Erzählung verdichtet. Braucht eine Supabase Edge Function
  (Anthropic-API-Key darf nicht im Client landen). Bewusst NICHT laufend pro
  Eintrag, sondern **einmal am Jahresende** — hält Kosten niedrig.
- **KI-Bildumwandlung von Tagebuch-Fotos** — z.B. "Hexer im Rat der Weißen".
  `journal_photos.transformed_path` ist als Platzhalter schon da. Selbes
  Kostenprinzip: on-demand statt pro Foto.
- **Ausrüstungs-Charakterbilder** ("wie in Elden Ring"). Wichtige Erkenntnis
  aus der Diskussion: handgezeichnete SVGs von Claude sind KEINE brauchbare
  Grundlage für echte Charakterkunst (Qualitätsproblem, nicht Architektur-
  problem). Empfohlener Weg: entweder (a) fertige, bereits in Ebenen
  aufgeteilte Asset-Pakete (z.B. itch.io), oder (b) Bild-KI **pro Einzelteil**
  statt pro Kombination generieren lassen (kein kombinatorisches
  Kostenproblem). Technisches Fundament ist **fertig**: `profiles.
  equipped_weapon/armor/accessory`, `items.image`-Feld (aktuell leer) — sobald
  eine Bild-URL im Regelwerk hinterlegt wird, rendert die Charakter-Seite sie
  automatisch als Ebene, ohne Code-Änderung.
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
- Der Nutzer denkt gerne "groß"/langfristig (Skalierbarkeit auf andere
  Vertriebe, Templating), will aber in **kleinen, funktionierenden Schritten**
  bauen — nicht alles auf einmal.
- Der Nutzer ist vorsichtig bei destruktiven SQL-Operationen (`DROP`,
  `DELETE`) — immer explizit warnen, wenn ein Patch sowas enthält, und den
  Unterschied zu harmlosen `DROP POLICY`-Fällen erklären.
- SQL-Patches wurden bisher immer als eigene, nummerierte, kommentierte
  Dateien geliefert (nicht in bestehende Migrationen eingemischt) — dieses
  Muster beibehalten, bis eine echte Migrations-Toolchain eingeführt wird.
