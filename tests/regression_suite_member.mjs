// Ergaenzung zu regression_suite.mjs, 2026-08-23: die Hauptsuite laeuft
// bisher immer mit dem Admin-Testkonto (credentials.json) -- Admin ist aber
// die SELTENERE Rolle im echten Team, nicht die Regel. Dieses Skript prueft
// gezielt die rollenabhaengigen Stellen noch einmal mit einem echten
// Nicht-Admin-Konto (credentials_member.json), statt die ganze,
// groesstenteils rollen-unabhaengige Hauptsuite ein zweites Mal komplett
// durchlaufen zu lassen (XP-Berechnung, Kanban-Spalten, Chronik-Merge etc.
// haengen nicht an der Rolle -- doppelt pruefen waere reine Verschwendung).
//
// Schreibt nichts an der echten Datenbank -- reine Lese-/Sichtbarkeitspruefungen.
//
// Aufruf: normalerweise ueber `npm test` / `npm run test:member`
// (tests/run-regression.mjs startet den Static-Server selbst).
// Direkt: python3 -m http.server <port> im Repo-Ordner, dann
//   node tests/regression_suite_member.mjs <port>

import { chromium } from 'playwright';
import { readFileSync } from 'fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const PORT = process.argv[2] || 8940;
const CREDS_PATH = process.env.FANTASYARBEIT_TEST_CREDS_MEMBER
  || join(homedir(), '.local/share/fantasyarbeit-claude-test/credentials_member.json');
const creds = JSON.parse(readFileSync(CREDS_PATH, 'utf8'));

const results = [];
function record(name, pass, detail) {
  results.push({ name, pass, detail });
  console.log((pass ? 'PASS' : 'FAIL') + ' - ' + name + (detail ? ' (' + detail + ')' : ''));
}

// data-testid-Selektor -- stabiler Vertrag über die React-Migration hinweg
// (siehe tests/README.md, "testid-Register").
const tid = (name) => `[data-testid="${name}"]`;

const browser = await chromium.launch({ args: ['--no-sandbox'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 1000 } });
const consoleErrors = [];
page.on('pageerror', e => consoleErrors.push('pageerror: ' + e.message));
page.on('console', msg => { if (msg.type() === 'error') consoleErrors.push('console: ' + msg.text()); });

// Gleiche Erkennung wie in regression_suite.mjs: die eigene Profilzeile ist
// die einzige profiles-Abfrage, die "role"+"timezone" mitselektiert.
let capturedRole = null;
await page.route('**/rest/v1/profiles*', async route => {
  const response = await route.fetch();
  const body = await response.json();
  if (capturedRole === null && Array.isArray(body) && body.length === 1 && body[0] && 'role' in body[0] && 'timezone' in body[0]) {
    capturedRole = body[0].role;
  }
  await route.fulfill({ response, json: body });
});

// ---- Login ----
await page.goto(`http://localhost:${PORT}/index.html`, { waitUntil: 'load' });
await page.fill(tid('auth-email'), creds.email);
await page.fill(tid('auth-password'), creds.password);
await page.click(tid('auth-submit'));
await page.waitForSelector(tid('level-num'), { state: 'visible', timeout: 15000 }).catch(() => {});
await page.waitForFunction(() => {
  const t = document.querySelector('[data-testid="level-num"]');
  return t && t.offsetParent !== null && t.textContent.trim() !== '';
}, null, { timeout: 12000 }).catch(() => {});

record('Login mit Nicht-Admin-Konto gelingt', await page.locator(tid('level-num')).isVisible().catch(() => false));
record('Testkonto hat tatsaechlich die Rolle "member" (kein versehentliches Admin-Konto)', capturedRole === 'member', 'capturedRole=' + capturedRole);

// ---- Admin-exklusive Nav-Buttons duerfen fuer Nicht-Admins nicht sichtbar sein ----
for (const [dataPage, label] of [['produkte', 'Produkte'], ['fehlerprotokoll', 'Fehlerprotokoll'], ['notfallzugriff', 'Notfallzugriff'], ['team-reporting', 'Team-Reporting']]) {
  const hidden = await page.locator(`[data-page="${dataPage}"]`).isHidden().catch(() => false);
  record(`Nicht-Admin sieht Nav-Button "${label}" nicht`, hidden);
}

// ---- Admin-exklusive Seiten-Hashes werfen zurueck UND korrigieren die
// Adresszeile (dieselbe Pruefung wie in regression_suite.mjs, dort aber nur
// mit dem Admin-Konto lauffaehig fuer den "darf rein"-Zweig) ----
for (const [hash, page_id] of [['#produkte', 'page-produkte'], ['#fehlerprotokoll', 'page-fehlerprotokoll'], ['#notfallzugriff', 'page-notfallzugriff'], ['#team-reporting', 'page-team-reporting']]) {
  await page.evaluate((h) => { window.location.hash = h; }, hash);
  await page.waitForFunction(() => window.location.hash === '#charakter', null, { timeout: 5000 }).catch(() => {});
  const pageVisible = await page.locator(tid(page_id)).evaluate(el => el.style.display !== 'none').catch(() => true);
  const hashCorrected = await page.evaluate(() => window.location.hash) === '#charakter';
  record(`Nicht-Admin wird von ${hash} auf Charakter zurueckgeworfen (inkl. Adresszeile)`, !pageVisible && hashCorrected, 'hash: ' + (await page.evaluate(() => window.location.hash)));
}

record('Keine Konsolen-/Seitenfehler während des Laufs', consoleErrors.length === 0, consoleErrors.join(' | '));

// Alle route()-Handler abhaengen, bevor der Browser schliesst -- sonst kann
// ein noch laufendes route.fetch() beim close() einen TargetClosedError
// werfen (unhandled rejection -> Exit != 0, obwohl alle Tests bestanden).
await page.unrouteAll({ behavior: 'ignoreErrors' }).catch(() => {});
await browser.close();

const failed = results.filter(r => !r.pass);
console.log('\n=== Ergebnis: ' + (results.length - failed.length) + '/' + results.length + ' bestanden ===');
if (failed.length) {
  console.log('Fehlgeschlagen:', failed.map(f => f.name).join(', '));
  process.exit(1);
}
