# Regressions-Suiten

Zwei Playwright-Skripte, die die echte App in einem Headless-Chromium
durchklicken und ~44 Dinge prüfen (Login/Rollen, XP→Level, Kanban-
Spalten, zentrale Navigation inkl. Deep-Links, Kalender/Termine,
Kontakt-Chronik, Verkauf/Statistik, mobiles/Touch-Verhalten).

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

## Bekannte Baustelle (Stand 2026-09-02)

Die Suiten nutzen an vielen Stellen feste `page.waitForTimeout(...)`-
Wartezeiten statt auf eine echte Bedingung zu warten — das erzeugt unter
Last gelegentliche, nicht-deterministische Fehlschläge (wechselnde
Tests). Wird im Zuge der React-Migration behoben (feste Wartezeiten →
`waitForSelector`/`waitForFunction`), zusammen mit dem Setzen von
`data-testid`-Attributen an den ~32 aktuell über Klassennamen/IDs
angesteuerten Stellen (damit die Selektoren die Migration überleben).
Siehe `project_framework_migration_plan`, Fund S2.

## Die losen `check_*.mjs`/`shot_*.mjs` (nicht hier)

Unter `~/.local/share/playwright-portable/` liegen ~180 einmalige
Prüf-/Screenshot-Skripte aus einzelnen Bau-/Debug-Sessions. Die sind
**nicht** Teil dieser Suite und werden bei der Migration triagiert oder
für aufgegeben erklärt (Fund S2). Die kanonische, gepflegte Fassung der
Regressions-Suiten ist ab jetzt die hier im Repo.
