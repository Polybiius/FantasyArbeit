# Regressions-Suiten

Zwei Playwright-Skripte, die die echte App in einem Headless-Chromium
durchklicken und ~61 Dinge prüfen (Login/Rollen, XP→Level, Kanban-
Spalten, Kanban-Übergänge inkl. RPC-Verträgen, zentrale Navigation
inkl. Deep-Links, Kalender/Termine, Kontakt-Chronik, Verkauf/Statistik,
mobiles/Touch-Verhalten).

**Es wird nichts an der echten Datenbank geschrieben.** Alle Testdaten
werden per `page.route()` in die REST-Antworten eingeschleust; der
einzige POST (Serientermine-Autofüllung) wird abgefangen statt
durchgelassen. Login ist ein echter Auth-Roundtrip mit den Testkonten.

## Aufruf

```
npm test            # beide Suiten (Admin + Nicht-Admin)
npm run test:admin  # nur regression_suite.mjs (Admin-Konto)
npm run test:member # nur regression_suite_member.mjs (Nicht-Admin-Konto)
```

`tests/run-regression.mjs` startet selbst einen `python3 -m http.server`
im Repo-Wurzelverzeichnis, wartet bis er erreichbar ist, lässt die
Suite(n) laufen und räumt den Server wieder ab. Exit-Code `!= 0`, sobald
eine Prüfung fehlschlägt.

Voraussetzungen: `python3` auf dem PATH, `npm install` gelaufen
(Playwright ist eine `devDependency`; das Chromium-Binary wird über
Playwrights normale Auflösung gefunden — ggf. einmalig
`npx playwright install chromium`).

## Zugangsdaten

Die Testkonten liegen **außerhalb des Repos** und werden nie
mitversioniert:

| Env-Variable | Default |
|---|---|
| `FANTASYARBEIT_TEST_CREDS` | `~/.local/share/fantasyarbeit-claude-test/credentials.json` |
| `FANTASYARBEIT_TEST_CREDS_MEMBER` | `~/.local/share/fantasyarbeit-claude-test/credentials_member.json` |

Format: `{ "email": "...", "password": "..." }`.

## Verbindliche Regel

Beide Suiten laufen **automatisch vor jedem `git push`** (Blankoscheck,
siehe `CLAUDE.md`). Schlägt eine Prüfung fehl: **nicht pushen**, den Fund
erst melden und klären, ob es ein echter Bug, ein veralteter Test oder
Flakiness ist.

## testid-Register (stabiler Vertrag über die React-Migration)

Die Suiten sprechen die App **ausschließlich über `data-testid`** an (plus
die semantischen Attribute `data-page` / `data-movestage` / `data-contact`
/ `data-event-id`, die auch die App-Logik selbst nutzt). Wird ein Bereich
nach React migriert, bekommt die neue Komponente **denselben
`data-testid`** — dann bleibt der Suite-Selektor unverändert, nur die
Prüf-Logik (z.B. `style.display` → aktive Route) passt sich an.

| testid | Ort (Vanilla) | Zweck |
|---|---|---|
| `auth-email` / `auth-password` / `auth-submit` | Login-Screen | Anmeldung |
| `level-num` | App-Shell | XP/Level-Anzeige, „App bereit"-Signal |
| `page-charakter` / `page-produkte` / `page-fehlerprotokoll` / `page-notfallzugriff` / `page-team-reporting` | `<div class="page">` | Seiten-Sichtbarkeit / Redirect-Prüfung |
| `kanban-board` | `#kanbanBoard` | Kanban-Container, Layout-Umschaltung 760px |
| `kanban-card` | `renderKanbanBoard()` | Kanban-Karte (+ `data-contact` / `data-stage`) |
| `kanban-move-btn` | `renderKanbanBoard()` | Touch-Verschieben-Knopf |
| `kanban-move-modal` / `kanban-move-close` / `kanban-move-grid` | Verschieben-Popup | Zielspalten-Menü |
| `kanban-extra-action-modal` / `kanban-extra-action-close` | Zusatzaktion-Popup (Bedarfsanalyse/Dauerbrenner) | Ohne Zusatzaktion schließen |
| `sale-entry-modal` / `sale-entry-category` / `sale-entry-product` / `sale-entry-vertragsbeginn` / `sale-entry-done` | Verkaufs-Popup „Gewonnen" (`recordWonSalesLoop()`) | Kanban-Übergang „-> Gewonnen" |
| `sale-lost-modal` / `sale-lost-category` / `sale-lost-product` / `sale-lost-confirm` | Verkaufs-Popup „Verloren" (`recordLostSale()`) | Kanban-Übergang „-> Verloren" |
| `kanban-termin-modal` / `kanban-termin-close` | Termin-Popup (`promptKanbanTermin()`) | Ohne Termin überspringen (Kanban-Übergang „Kundenausbau") |
| `contact-detail-content` / `contact-detail-notfound` | Kontakt-Seite | Deep-Link vorhanden / Fehlerseite |
| `contact-detail-title` | Kontakt-Seite | Name des geladenen Kontakts |
| `contact-detail-chronik` | Kontakt-Seite | zusammengeführte Chronik |
| `contact-stat-strip` / `contact-stat-value` | `renderContactStatStrip()` | Kennzahlen-Leiste (Verträge/Chronik/…) |
| `cal-month-view` / `cal-week-view` | Kalender | Ansichts-Umschaltung |
| `week-header-row` | Wochenansicht | Tages-Kopfzeile |
| `week-event` / `week-event-time` | `renderDayEvents()` | Termin-Kachel (+ `data-event-id`) / Uhrzeit |
| `stat-card` | `statHeroCard()` | KPI-Kachel (+ `data-label` = Kennzahl-Name) |
| `day-view-grid` | Tagesansicht | Kalender/Aufgaben-Raster, Stapelung 760px |

Neue Suite-Prüfungen: immer über `tid('...')` (Helfer oben in beiden
Skripten), nie über rohe Klassennamen/IDs.

## Warten auf Zustand statt auf Zeit

Die Suiten warten über `waitForSelector` / `waitForFunction` auf echte
Bedingungen (Element sichtbar, Text stimmt, Karten gerendert) statt über
feste `waitForTimeout(...)`. Der Helfer `gotoHash(hash, testid)` navigiert
per Hash und wartet, bis das Ziel sichtbar ist. Vor `browser.close()` wird
`page.unrouteAll({ behavior: 'ignoreErrors' })` aufgerufen, sonst kann ein
noch laufendes `route.fetch()` einen `TargetClosedError` werfen (Exit != 0
trotz bestandener Tests). Ergebnis: 20+ Läufe hintereinander grün, wo
vorher ~jeder 6. Lauf einen wechselnden Test verlor.

## Die losen `check_*.mjs`/`shot_*.mjs` (nicht hier)

Unter `~/.local/share/playwright-portable/` liegen ~180 einmalige
Prüf-/Screenshot-Skripte aus einzelnen Bau-/Debug-Sessions. Die sind
**nicht** Teil dieser Suite und werden bei der Migration triagiert oder
für aufgegeben erklärt (Fund S2). Die kanonische, gepflegte Fassung der
Regressions-Suiten ist ab jetzt die hier im Repo.
