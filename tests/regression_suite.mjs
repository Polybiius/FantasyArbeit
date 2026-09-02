// Regressions-Suite, urspruenglich 2026-08-17 gebaut ("best practice? dann
// bitte"), am 2026-08-24 auf Nutzerwunsch ausgeweitet ("Punkt 11" der
// Roadmap -- die alten drei Kernpfade waren zu schmal, seit auch zentrale,
// ueberall mitgenutzte Stellen wie routeToHash()/showPage() geaendert
// werden). Kein CI/CD, dessen Ausloeser noch nicht erreicht ist -- nur ein
// wiederverwendbares Skript nach demselben Muster wie die uebrigen
// check_*.mjs hier, das vor jeder groesseren Aenderung laufen sollte.
//
// Abgedeckte Bereiche:
// 1) Login/Auth + rollenbasierte Sichtbarkeit
// 2) XP-/Level-Berechnung (computeTotals/levelInfo im Frontend)
// 3) Kanban-Spalten-Zuordnung (kanban_stage -> richtige Spalte)
// 4) Zentrale Navigation (showPage()/routeToHash(), Deep-Links, Fallbacks)
// 5) Kalender/Termine (Wochenansicht-Positionierung, Serientermine-Autofuellung)
// 6) Kontakt-Seite/Chronik (Zusammenfuehrung mehrerer Quellen, Kennzahlen-Leiste)
// 7) Verkauf/Statistik (BWS-/Provisions-Aggregation)
// 8) Mobiles/Touch-Verhalten (Kanban-Layout-Umschaltung + Verschieben-Menue
//    bei 760px, gestapeltes Tagesansicht-Raster) -- reine CSS-/Erreichbarkeits-
//    Pruefung mit demselben Konto, siehe regression_suite_member.mjs fuer den
//    separaten Rollen-Test (Nicht-Admin) mit einem zweiten Testkonto.
//
// Alle Tests arbeiten mit synthetischen, per page.route() eingeschleusten
// Daten -- NICHTS wird an der echten Datenbank geschrieben oder veraendert
// (auch der Serientermine-Test faengt den POST ab, statt ihn durchzulassen).
//
// Aufruf: normalerweise ueber `npm test` / `npm run test:admin`
// (tests/run-regression.mjs startet den Static-Server selbst).
// Direkt: python3 -m http.server <port> im Repo-Ordner, dann
//   node tests/regression_suite.mjs <port>

import { chromium } from 'playwright';
import { readFileSync } from 'fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const PORT = process.argv[2] || 8940;
const CREDS_PATH = process.env.FANTASYARBEIT_TEST_CREDS
  || join(homedir(), '.local/share/fantasyarbeit-claude-test/credentials.json');
const creds = JSON.parse(readFileSync(CREDS_PATH, 'utf8'));

const results = [];
function record(name, pass, detail) {
  results.push({ name, pass, detail });
  console.log((pass ? 'PASS' : 'FAIL') + ' - ' + name + (detail ? ' (' + detail + ')' : ''));
}

// data-testid-Selektor -- stabiler Vertrag ueber die React-Migration hinweg
// (siehe tests/README.md, Abschnitt "testid-Register"). Alle Suite-Selektoren
// laufen darueber statt ueber Klassennamen/IDs, die die Migration umbenennt.
const tid = (name) => `[data-testid="${name}"]`;

// Playwright kann eine Antwort auch ganz ohne echten Netzwerk-Roundtrip
// fuellen (kein `response` von route.fetch() noetig) -- fuer Faelle, in
// denen NICHTS Echtes erreicht werden soll (z.B. der Serientermine-Insert).
async function fulfillJson(route, data, status) {
  await route.fulfill({ status: status || 200, contentType: 'application/json', body: JSON.stringify(data) });
}

// YYYY-MM-DD in einer bestimmten Zeitzone -- 'en-CA' formatiert praktischerweise
// direkt in dieser Reihenfolge, kein manuelles Parsen noetig.
function ymdInTZ(d, tzName) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tzName, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
}
function hmInTZ(d, tzName) {
  const parts = new Intl.DateTimeFormat('de-DE', { timeZone: tzName, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(d);
  const h = parts.find(p => p.type === 'hour').value, m = parts.find(p => p.type === 'minute').value;
  return `${h}:${m}`;
}
// Host-lokales YYYY-MM-DD (kein TZ-Parameter) -- fuer reine Kalendertag-
// Arithmetik (Serientermine-Vorbereitung), spiegelt dateKeyLocal() in
// index.html, das bewusst Browser-lokal statt TZ-aufgeloest rechnet.
function ymdHostLocal(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const browser = await chromium.launch({ args: ['--no-sandbox'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 1000 } });
const consoleErrors = [];
page.on('pageerror', e => consoleErrors.push('pageerror: ' + e.message));
page.on('console', msg => { if (msg.type() === 'error') consoleErrors.push('console: ' + msg.text()); });

// Navigiert per Hash und wartet auf eine echte Bedingung (Ziel-Element
// sichtbar), statt auf eine feste Zeit -- ersetzt das fruehere fragile
// "hash setzen + waitForTimeout(...)", das unter Last nicht-deterministische
// Fehlschlaege erzeugte. waitFor = testid-Name oder roher Selektor; bei
// negativem Ausgang (Redirect erwartet) waitFor weglassen und danach kurz
// auf den Redirect-Zielzustand warten.
async function gotoHash(hash, waitFor, { timeout = 8000 } = {}) {
  await page.evaluate((h) => { window.location.hash = h; }, hash);
  if (waitFor) {
    const sel = waitFor.startsWith('[') || waitFor.startsWith('#') || waitFor.startsWith('.') ? waitFor : tid(waitFor);
    await page.waitForSelector(sel, { state: 'visible', timeout }).catch(() => {});
  } else {
    await page.waitForTimeout(400); // Redirect-/Ablehnungs-Fall: kurzer Ausklang
  }
}

// ---- Test 2 Vorbereitung: bekannte XP-Summe einschleusen ----
let levelBase = null, levelExponent = null;
let knownXp = null;

await page.route('**/rest/v1/rule_configs*', async route => {
  const response = await route.fetch();
  const body = await response.json();
  if (Array.isArray(body) && body[0] && body[0].config) {
    levelBase = body[0].config.levelBase;
    levelExponent = body[0].config.levelExponent;
  }
  await route.fulfill({ response, json: body });
});

function xpForLevel(level) { return Math.round(levelBase * Math.pow(level, levelExponent)); }
function expectedLevel(totalXp) {
  let level = 1, remaining = totalXp, need = xpForLevel(level);
  while (remaining >= need) { remaining -= need; level++; need = xpForLevel(level); }
  return level;
}

let uid = null, oid = null;
await page.route('**/rest/v1/action_log*', async route => {
  const response = await route.fetch();
  const body = await response.json();
  if (Array.isArray(body) && body.length && !uid) { uid = body[0].user_id; oid = body[0].org_id; }
  if (levelBase && knownXp === null) {
    knownXp = xpForLevel(1) + xpForLevel(2) + xpForLevel(3) + xpForLevel(4) + 37;
    const synthetic = [{
      id: 'zzz-regress-1', user_id: uid, org_id: oid, action_key: 'ansprache',
      label: 'Regressionstest', xp: knownXp, energy: 0, skill: null, skill2: null,
      context: null, location_id: null, contact_id: null, meta: null,
      created_at: new Date().toISOString(),
    }];
    await route.fulfill({ response, json: synthetic });
  } else {
    await route.fulfill({ response, json: body });
  }
});

// ---- NEU: eigenes Profil/Organisation beobachten (Rolle + Zeitzone) ----
// window.profile ist NICHT ansprechbar (die ganze App laeuft in einer
// eigenen (function(){...})()-Klammer, "profile" ist dort ein rein lokales
// let -- kein window.profile existiert). Der alte Test 1 pruefte deshalb
// bislang faktisch nie wirklich die Admin-Sichtbarkeit (window.profile war
// immer undefined, Zweig fiel automatisch auf "uebersprungen"). Fix hier:
// PostgREST liefert auch bei .maybeSingle() ein Array mit einem Element
// (empirisch gegen die echte API geprueft, keine Objekt-Antwort) -- die
// eigene Profilzeile ist stattdessen daran erkennbar, dass sie als einzige
// profiles-Abfrage im ganzen Code "role"+"timezone" mitselektiert
// (select('*') an genau einer Stelle, alle anderen Abfragen holen nur
// wenige, namentlich gelistete Felder fuer Freundes-/Gildenlisten).
let capturedRole = null, capturedProfileTz = null, capturedOrgTz = null;
await page.route('**/rest/v1/profiles*', async route => {
  const response = await route.fetch();
  const body = await response.json();
  if (capturedRole === null && Array.isArray(body) && body.length === 1 && body[0] && 'role' in body[0] && 'timezone' in body[0]) {
    capturedRole = body[0].role;
    capturedProfileTz = body[0].timezone || null;
  }
  await route.fulfill({ response, json: body });
});
await page.route('**/rest/v1/organizations*', async route => {
  const response = await route.fetch();
  const body = await response.json();
  if (capturedOrgTz === null && Array.isArray(body) && body.length === 1 && body[0] && 'timezone' in body[0]) {
    capturedOrgTz = body[0].timezone || null;
  }
  await route.fulfill({ response, json: body });
});

// ---- Test 3 Vorbereitung: drei synthetische Kanban-Kontakte + ein vierter
// fuer den neuen Kontakt-Seite/Chronik-Testblock (kanban_stage:null, taucht
// im Kanban absichtlich nicht auf) ----
const KANBAN_TEST_ROWS = [
  { id: 'aaaaaaaa-1111-4111-8111-111111111111', stage: 'neuer_lead' },
  { id: 'aaaaaaaa-2222-4222-8222-222222222222', stage: 'ersttermin_vereinbart' },
  { id: 'aaaaaaaa-3333-4333-8333-333333333333', stage: 'gewonnen' },
];
const CHRONIK_CONTACT_ID = 'aaaaaaaa-4444-4444-8444-444444444444';
const CHRONIK_CONTACT_NAME = 'Regress Chronikkontakt';
const MISSING_CONTACT_ID = 'aaaaaaaa-9999-4999-8999-999999999999';

function makeSyntheticContact(id, vorname, nachname, stage) {
  return {
    id, org_id: oid, owner_id: uid, vorname, nachname,
    name: vorname + ' ' + nachname, kanban_stage: stage, location_id: null,
    status: 'kalt', role: null, telefon: null, email: null,
    wohnort_strasse: null, wohnort_ort: null, geburtsdatum: null,
    bedarf_ist: null, bedarf_wunsch: null, naechster_kontakt: null,
    notes: null, guild_id: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
  };
}
await page.route('**/rest/v1/contacts*', async route => {
  const response = await route.fetch();
  const body = await response.json();
  if (Array.isArray(body)) {
    KANBAN_TEST_ROWS.forEach(r => body.push(makeSyntheticContact(r.id, 'Regress', r.stage, r.stage)));
    body.push(makeSyntheticContact(CHRONIK_CONTACT_ID, 'Regress', 'Chronikkontakt', null));
  }
  await route.fulfill({ response, json: body });
});

// ---- NEU: Produktkatalog um ein synthetisches "fest"-Produkt ergaenzen ----
// provision_mode:'fest' braucht keinen individuellen persoenlichen Satz
// (anders als LV/KV/pma) -- einfachster Fall fuer eine deterministische
// BWS-/Provisions-Rechnung ohne von profile.*_satz abzuhaengen.
const PRODUCT_ID_SH = 'bbbbbbbb-0001-4001-8001-000000000001';
await page.route('**/rest/v1/products*', async route => {
  const response = await route.fetch();
  const body = await response.json();
  if (Array.isArray(body)) {
    body.push({
      id: PRODUCT_ID_SH, org_id: oid, key: 'regress_sh', name: 'RegressTestProdukt',
      category: 'RegressTestKategorie', subcategory: null, active: true,
      provision_mode: 'fest', provision_faktor: 0.1, bwp_faktor: 1,
      recontact_amount: null, recontact_unit: null,
    });
  }
  await route.fulfill({ response, json: body });
});

// ---- NEU: sales hat zwei unterschiedliche Abfrage-Formen im echten Code,
// die beide auf denselben REST-Pfad gehen -- am Query-String unterscheidbar:
// - loadContactDetailExtras() (Kontakt-Detailseite, seit dem Kontakte-
//   Effizienz-Review 2026-08-30 ein gezielter `contact_id=eq.<id>`-Fetch
//   statt des vorherigen `contact_id=in.(alleSichtbarenIds)` ueber die
//   gesamte Kontaktliste): ECHTE Daten (real leer, da CHRONIK_CONTACT_ID
//   synthetisch ist) + synthetische Verkaufszeile fuer den Chronik-
//   Testkontakt ANHAENGEN.
// - loadMySales() (Statistik-Seite): `created_by=eq....&status=eq.gewonnen`
//   -> komplett ERSETZEN durch zwei bekannte synthetische Verkaeufe, sonst
//   waere die erwartete Summe von echten Bestandsdaten des Testaccounts
//   abhaengig und der Test nicht deterministisch.
const SALE_ID_CHRONIK = 'cccccccc-0001-4001-8001-000000000001';
const SALE_ID_STAT_A = 'cccccccc-0002-4002-8002-000000000002';
const SALE_ID_STAT_B = 'cccccccc-0003-4003-8003-000000000003';
let statYear = null; // erst nach Login bekannt (host-lokales "heute" reicht)
await page.route('**/rest/v1/sales*', async route => {
  const url = route.request().url();
  if (url.includes('contact_id=eq.' + CHRONIK_CONTACT_ID)) {
    const response = await route.fetch();
    const body = await response.json();
    if (Array.isArray(body)) {
      body.push({
        id: SALE_ID_CHRONIK, org_id: oid, contact_id: CHRONIK_CONTACT_ID, product_id: PRODUCT_ID_SH,
        created_by: uid, status: 'gewonnen', menge: 1, laufender_beitrag: 1000, bewertungssumme: null,
        vertragsbeginn: ymdHostLocal(new Date()), vertragsende: null, datum: ymdHostLocal(new Date()),
        vertragsnummer: null,
      });
    }
    await route.fulfill({ response, json: body });
  } else if (url.includes('created_by=eq.')) {
    const year = statYear || new Date().getFullYear();
    await fulfillJson(route, [
      { id: SALE_ID_STAT_A, org_id: oid, contact_id: null, product_id: PRODUCT_ID_SH, created_by: uid,
        status: 'gewonnen', menge: 1, laufender_beitrag: 1000, bewertungssumme: null,
        vertragsbeginn: `${year}-03-15`, vertragsende: null, datum: `${year}-03-15`, vertragsnummer: null },
      { id: SALE_ID_STAT_B, org_id: oid, contact_id: null, product_id: PRODUCT_ID_SH, created_by: uid,
        status: 'gewonnen', menge: 1, laufender_beitrag: 500, bewertungssumme: null,
        vertragsbeginn: `${year}-11-05`, vertragsende: null, datum: `${year}-11-05`, vertragsnummer: null },
    ]);
  } else {
    const response = await route.fetch();
    const body = await response.json();
    await route.fulfill({ response, json: body });
  }
});

// ---- NEU: termine -- drei unterscheidbare Aufrufe am selben REST-Pfad ----
// 1) GET contact_id=eq.<Chronik-Testkontakt>  -> synthetischer Chronik-Termin
// 2) GET owner_id=eq....&start_at=gte....     -> Wochenansicht-Ladevorgang
// 3) POST (Serientermine-Autofuellung)        -> abfangen, NIE wirklich schreiben
const TERMIN_CHRONIK_ID = '11111111-aaaa-4aaa-8aaa-000000000001';
const WEEK_EVENT_ID = 'dddddddd-1111-4111-8111-111111111111';
let weekEventStart = null, weekEventEnd = null; // erst kurz vor dem Test gesetzt
const seriesInsertedRows = [];
await page.route('**/rest/v1/termine*', async route => {
  const method = route.request().method();
  if (method === 'POST') {
    let rows = [];
    try { rows = route.request().postDataJSON(); } catch { /* rows bleibt [] */ }
    if (Array.isArray(rows)) rows.forEach(r => { if (r.series_id === SERIES_ID) seriesInsertedRows.push(r); });
    await fulfillJson(route, [], 201); // App liest nur { error }, Daten werden ignoriert -- leer reicht
    return;
  }
  const url = route.request().url();
  if (method === 'GET' && url.includes('contact_id=eq.' + CHRONIK_CONTACT_ID)) {
    await fulfillJson(route, [
      { id: TERMIN_CHRONIK_ID, org_id: oid, owner_id: uid, contact_id: CHRONIK_CONTACT_ID, location_id: null,
        title: 'RegressChronikTermin', start_at: new Date().toISOString(), end_at: new Date(Date.now() + 30 * 60000).toISOString(),
        kanal: 'online', series_id: null, organizer_id: null },
    ]);
    return;
  }
  if (method === 'GET' && url.includes('owner_id=eq.') && url.includes('start_at=gte.')) {
    await fulfillJson(route, weekEventStart ? [
      { id: WEEK_EVENT_ID, org_id: oid, owner_id: uid, contact_id: null, location_id: null,
        title: 'RegressWeekEvent', start_at: weekEventStart, end_at: weekEventEnd,
        kanal: null, series_id: null, organizer_id: null, contact: null, location: null, organizer: null },
    ] : []);
    return;
  }
  const response = await route.fetch();
  const body = await response.json();
  await route.fulfill({ response, json: body });
});

// ---- NEU: contact_activities -- Anruf/Email-Teil des Chronik-Tests ----
const ACTIVITY_ID = 'ffffffff-0001-4001-8001-000000000001';
await page.route('**/rest/v1/contact_activities*', async route => {
  const url = route.request().url();
  if (url.includes('contact_id=eq.' + CHRONIK_CONTACT_ID)) {
    await fulfillJson(route, [
      { id: ACTIVITY_ID, org_id: oid, user_id: uid, contact_id: CHRONIK_CONTACT_ID, type: 'anruf',
        outcome: 'erreicht', betreff: null, inhalt: 'Regressionstest-Notiz', occurred_at: new Date().toISOString(),
        action_log_id: null, action_log: null },
    ]);
    return;
  }
  const response = await route.fetch();
  const body = await response.json();
  await route.fulfill({ response, json: body });
});

// ---- NEU: termin_series -- synthetische taegliche Serie fuer den
// Autofuellungs-Test. GET wird komplett ERSETZT (nicht ergaenzt) -- faellt
// der Testaccount zufaellig echte Serien haben, werden die fuer DIESEN Lauf
// bewusst nicht angefasst/aufgefuellt (sicherer als ein echtes Auffuellen
// auszuloesen). Der PATCH danach (generated_until fortschreiben) laeuft
// unveraendert echt durch -- betrifft eine Zeile mit einer ID, die es in
// der echten DB nie gibt, also wirkungslos (0 Zeilen getroffen).
const SERIES_ID = 'eeeeeeee-1111-4111-8111-111111111111';
let seriesStartDate = null, seriesUntilDate = null, seriesGeneratedUntil = null; // nach Login gesetzt
await page.route('**/rest/v1/termin_series*', async route => {
  if (route.request().method() !== 'GET') { await route.continue(); return; }
  await fulfillJson(route, [
    { id: SERIES_ID, org_id: oid, owner_id: uid, contact_id: null, location_id: null,
      title: 'RegressSerientermin', kanal: null, freq: 'taeglich', interval_n: 1, weekdays: null,
      start_date: seriesStartDate, until_date: seriesUntilDate, generated_until: seriesGeneratedUntil,
      start_time: '09:00', end_time: '09:30' },
  ]);
});
// Serien-Daten muessen VOR dem ersten Login-Request feststehen (topUpAllSeriesForUser
// laeuft automatisch waehrend enterApp()) -- host-lokale Kalendertage wie
// dateKeyLocal() in index.html.
{
  const today = new Date();
  const yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1);
  const fiveDaysAgo = new Date(today); fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);
  seriesUntilDate = ymdHostLocal(today);
  seriesGeneratedUntil = ymdHostLocal(yesterday);
  seriesStartDate = ymdHostLocal(fiveDaysAgo);
}

// ---- Login ----
await page.goto(`http://localhost:${PORT}/index.html`, { waitUntil: 'load' });
await page.fill(tid('auth-email'), creds.email);
await page.fill(tid('auth-password'), creds.password);
await page.click(tid('auth-submit'));
await page.waitForSelector(tid('level-num'), { state: 'visible', timeout: 15000 }).catch(() => {});
// App-Shell ist da -- abwarten, bis enterApp() den ersten render() gefahren hat
// (level-num hat dann echten Inhalt statt des HTML-Platzhalters)
await page.waitForFunction(() => {
  const t = document.querySelector('[data-testid="level-num"]');
  return t && t.offsetParent !== null && t.textContent.trim() !== '';
}, null, { timeout: 12000 }).catch(() => {});
statYear = new Date().getFullYear();

// ---- Test 1: Login/Rauchtest ----
const levelNumVisible = await page.locator(tid('level-num')).isVisible().catch(() => false);
record('Login gelingt, App-Shell rendert (level-num sichtbar)', levelNumVisible);

// ---- Test: Rollenbasierte Nav-Sichtbarkeit (fixiert -- window.profile
// existiert nicht, siehe Kommentar oben; nutzt jetzt die echte, ueber die
// profiles-Route abgefangene Rolle) ----
if (capturedRole === 'admin') {
  const produkteVisible = await page.locator('[data-page="produkte"]').isVisible().catch(() => false);
  record('Admin-Nav "Produkte" sichtbar (rollenbasierte UI)', produkteVisible, 'Rolle: admin');
} else if (capturedRole === 'member') {
  const produkteHidden = await page.locator('[data-page="produkte"]').isHidden().catch(() => false);
  record('Nicht-Admin sieht "Produkte" nicht (rollenbasierte UI)', produkteHidden, 'Rolle: member');
} else {
  record('Rollenbasierte Nav-Sichtbarkeit konnte Rolle nicht bestimmen', false, 'capturedRole=' + capturedRole);
}

// ---- Test 2: XP-/Level-Berechnung ----
await gotoHash('#charakter', 'page-charakter');
await page.waitForFunction(() => {
  const t = document.querySelector('[data-testid="level-num"]');
  return t && t.textContent.trim() !== '' && t.textContent.trim() !== '1';
}, null, { timeout: 6000 }).catch(() => {});
const shownLevel = await page.locator(tid('level-num')).textContent().catch(() => null);
if (levelBase && knownXp !== null) {
  const expected = expectedLevel(knownXp);
  record(
    `XP→Level-Berechnung korrekt (${knownXp} XP → Level ${expected} erwartet)`,
    String(shownLevel).trim() === String(expected),
    `angezeigt: ${shownLevel}`
  );
} else {
  record('XP-Test konnte levelBase/levelExponent nicht lesen', false);
}

// ---- Test 3: Kanban-Spalten-Zuordnung ----
await gotoHash('#kanban', 'kanban-board');
// Warten bis die synthetischen Karten wirklich gerendert sind (statt fester Zeit)
await page.waitForFunction(
  (ids) => ids.every(id => document.querySelector(`[data-testid="kanban-card"][data-contact="${id}"]`)),
  KANBAN_TEST_ROWS.map(r => r.id),
  { timeout: 8000 },
).catch(() => {});
for (const r of KANBAN_TEST_ROWS) {
  const card = page.locator(`${tid('kanban-card')}[data-contact="${r.id}"][data-stage="${r.stage}"]`);
  const found = await card.count().catch(() => 0);
  record(`Kanban-Kontakt landet in Spalte "${r.stage}"`, found === 1, `gefunden: ${found}`);
}

// ---- Test 4 (NEU): Ungueltiger Seiten-Hash faellt auf Charakter zurueck
// und korrigiert die Adresszeile. Schuetzt genau den in Haeppchen 12
// gefundenen/behobenen Bug (dauerhaft falsch stehender Hash nach einem
// Berechtigungs-/Gueltigkeits-Redirect). ----
await page.evaluate(() => { window.location.hash = '#does-not-exist-xyz'; });
await page.waitForFunction(() => window.location.hash === '#charakter', null, { timeout: 5000 }).catch(() => {});
{
  const charVisible = await page.locator(tid('page-charakter')).evaluate(el => el.style.display !== 'none').catch(() => false);
  const hashCorrected = await page.evaluate(() => window.location.hash) === '#charakter';
  record('Ungueltiger Seiten-Hash faellt auf Charakter zurueck', charVisible, 'sichtbar: ' + charVisible);
  record('Adresszeile wird bei ungueltigem Hash korrigiert', hashCorrected, 'hash: ' + (await page.evaluate(() => window.location.hash)));
}

// ---- Test 5 (NEU): Rechte-gebundener Seiten-Hash ("#produkte") passend
// zur echten Rolle -- Admin darf rein, Nicht-Admin wird zurueckgeworfen. ----
await page.evaluate(() => { window.location.hash = '#produkte'; });
if (capturedRole === 'admin') {
  await page.waitForSelector(tid('page-produkte'), { state: 'visible', timeout: 6000 }).catch(() => {});
} else {
  await page.waitForFunction(() => window.location.hash === '#charakter', null, { timeout: 5000 }).catch(() => {});
}
{
  const produkteVisible = await page.locator(tid('page-produkte')).evaluate(el => el.style.display !== 'none').catch(() => false);
  const hashNow = await page.evaluate(() => window.location.hash);
  if (capturedRole === 'admin') {
    record('Admin darf #produkte oeffnen', produkteVisible && hashNow === '#produkte', 'hash: ' + hashNow);
  } else {
    record('Nicht-Admin wird von #produkte zurueck auf Charakter geworfen', !produkteVisible && hashNow === '#charakter', 'hash: ' + hashNow);
  }
}

// ---- Test 6+7 (NEU): Kontakt-Deep-Link zeigt den richtigen Kontakt,
// Chronik fuehrt mehrere Quellen zusammen, Kennzahlen-Leiste stimmt ----
await gotoHash('#kontakt/' + CHRONIK_CONTACT_ID, 'contact-detail-content');
await page.waitForFunction(
  (name) => document.querySelector('[data-testid="contact-detail-title"]')?.textContent === name,
  CHRONIK_CONTACT_NAME,
  { timeout: 6000 },
).catch(() => {});
{
  const title = await page.locator(tid('contact-detail-title')).textContent().catch(() => null);
  record('Kontakt-Deep-Link zeigt den richtigen Namen', title === CHRONIK_CONTACT_NAME, 'angezeigt: ' + title);

  // Chronik lädt async mehrere Quellen zusammen -- auf die erwartete Zeile warten
  await page.waitForFunction(
    () => (document.querySelector('[data-testid="contact-detail-chronik"]')?.textContent || '').includes('RegressChronikTermin'),
    null, { timeout: 6000 },
  ).catch(() => {});
  const chronikText = await page.locator(tid('contact-detail-chronik')).innerText().catch(() => '');
  const hasCall = chronikText.includes('Anruf') && chronikText.includes('erreicht');
  const hasTermin = chronikText.includes('RegressChronikTermin');
  const hasSale = chronikText.includes('RegressTestProdukt');
  record('Chronik zeigt Anruf-Aktivitaet', hasCall);
  record('Chronik zeigt Termin', hasTermin);
  record('Chronik zeigt Verkauf', hasSale);

  // Kennzahlen-Leiste rendert nach der Chronik (chronikCount kommt aus deren
  // Cache) -- auf die deterministischen Sollwerte warten statt auf eine Zeit.
  await page.waitForFunction(() => {
    const els = document.querySelectorAll('[data-testid="contact-stat-strip"] [data-testid="contact-stat-value"]');
    return els.length >= 2 && els[0].textContent === '1' && els[1].textContent === '3';
  }, null, { timeout: 8000 }).catch(() => {});
  const chips = await page.locator(`${tid('contact-stat-strip')} ${tid('contact-stat-value')}`).allTextContents().catch(() => []);
  // Reihenfolge lt. renderContactStatStrip(): Vertraege, Chronik-Eintraege, Dateien, Zuletzt kontaktiert
  record('Kennzahlen-Leiste: Vertraege = 1', chips[0] === '1', 'chips: ' + JSON.stringify(chips));
  record('Kennzahlen-Leiste: Chronik-Eintraege = 3', chips[1] === '3', 'chips: ' + JSON.stringify(chips));
}

// ---- Test 8 (NEU): Deep-Link uebersteht ein echtes Neuladen der Seite
// (derselbe Kontakt muss ohne erneuten Klick wieder erscheinen) ----
await page.reload({ waitUntil: 'load' });
await page.waitForSelector(tid('level-num'), { state: 'visible', timeout: 15000 }).catch(() => {});
// Kalt-Reload: init -> afterLogin -> enterApp -> routeToHash(#kontakt/..) ->
// openContactPage -> loadContactsBundle (laedt ALLE Kontakte) -> render.
// Kann unter Last laenger dauern -- grosszuegig, und auf title ODER
// notFound warten (letzteres waere ein echter Fehler, kein Timing).
await page.waitForFunction(
  (name) => {
    const t = document.querySelector('[data-testid="contact-detail-title"]')?.textContent;
    const nf = document.querySelector('[data-testid="contact-detail-notfound"]');
    return t === name || (nf && nf.offsetParent !== null);
  },
  CHRONIK_CONTACT_NAME,
  { timeout: 25000 },
).catch(() => {});
{
  const title = await page.locator(tid('contact-detail-title')).textContent().catch(() => null);
  const navActive = await page.locator('[data-page="kontakte"]').evaluate(el => el.classList.contains('active')).catch(() => false);
  record('Kontakt-Deep-Link uebersteht Reload (gleicher Kontakt, kein Klick noetig)', title === CHRONIK_CONTACT_NAME, 'angezeigt: ' + title);
  record('Nav-Highlight nach Reload korrekt auf "Kontakte"', navActive);
}

// ---- Test 9 (NEU): Nicht existierender Kontakt-Link zeigt Fehlerseite
// statt eines Absturzes ----
await gotoHash('#kontakt/' + MISSING_CONTACT_ID, 'contact-detail-notfound');
{
  const notFoundVisible = await page.locator(tid('contact-detail-notfound')).evaluate(el => el.style.display !== 'none').catch(() => false);
  const contentHidden = await page.locator(tid('contact-detail-content')).evaluate(el => el.style.display === 'none').catch(() => false);
  record('Nicht existierender Kontakt zeigt Fehlerseite', notFoundVisible && contentHidden, 'notFound sichtbar: ' + notFoundVisible);
}

// ---- Test 10+11 (NEU): Kalender-Deep-Link oeffnet die Wochenansicht auf
// dem richtigen Tag, Termin wird zeitzonen-korrekt positioniert ----
const resolvedTz = capturedProfileTz || capturedOrgTz || 'Europe/Berlin';
// "Jetzt" kann auf ein Wochenende fallen -- blendet das Testkonto Sa/So aus
// (profiles.calendar_hide_weekends), wuerde der Tag in der Wochenansicht
// gar keine Spalte bekommen und der Test faelschlich als Bug erscheinen.
// Deshalb in Tagesspruengen (echte 24h, wie ein Kalendertag weiter) auf den
// naechsten Werktag vorruecken, bis ein Mo-Fr in der aufgeloesten Zeitzone
// erreicht ist -- betrifft nur die Testvorbereitung, keine App-Logik.
function weekdayShortInTZ(d, tzName) { return new Intl.DateTimeFormat('en-US', { timeZone: tzName, weekday: 'short' }).format(d); }
let nowForEvent = new Date();
while (['Sat', 'Sun'].includes(weekdayShortInTZ(nowForEvent, resolvedTz))) {
  nowForEvent = new Date(nowForEvent.getTime() + 24 * 3600000);
}
weekEventStart = nowForEvent.toISOString();
weekEventEnd = new Date(nowForEvent.getTime() + 30 * 60000).toISOString();
const todayInResolvedTz = ymdInTZ(nowForEvent, resolvedTz);
await gotoHash('#tagebuch/woche/' + todayInResolvedTz, 'cal-week-view');
await page.waitForFunction(
  (eid) => document.querySelector(`[data-testid="week-event"][data-event-id="${eid}"]`),
  WEEK_EVENT_ID,
  { timeout: 6000 },
).catch(() => {});
{
  const weekVisible = await page.locator(tid('cal-week-view')).evaluate(el => el.style.display !== 'none').catch(() => false);
  const monthHidden = await page.locator(tid('cal-month-view')).evaluate(el => el.style.display === 'none').catch(() => false);
  record('Kalender-Deep-Link oeffnet die Wochenansicht', weekVisible && monthHidden);

  const [, mm, dd] = todayInResolvedTz.split('-');
  const headerText = await page.locator(tid('week-header-row')).innerText().catch(() => '');
  record('Wochenansicht zeigt den richtigen Tag in der Kopfzeile', headerText.includes(`${dd}.${mm}.`), `Kopfzeile: ${headerText.replace(/\n/g, ' ')}`);

  const eventTimeText = await page.locator(`${tid('week-event')}[data-event-id="${WEEK_EVENT_ID}"] ${tid('week-event-time')}`).textContent().catch(() => null);
  const expectedStart = hmInTZ(nowForEvent, resolvedTz);
  const expectedEnd = hmInTZ(new Date(nowForEvent.getTime() + 30 * 60000), resolvedTz);
  const timeOk = eventTimeText && eventTimeText.includes(expectedStart) && eventTimeText.includes(expectedEnd);
  record('Termin in der Wochenansicht zeigt die zeitzonen-korrekte Uhrzeit', timeOk, `angezeigt: ${eventTimeText}, erwartet: ${expectedStart}–${expectedEnd} (tz: ${resolvedTz})`);
}

// ---- Test 12 (NEU): Verkaufsstatistik summiert mehrere Verkaeufe
// verschiedener Monate im Jahres-Reiter korrekt (BWS-/Provisions-Aggregation) ----
await gotoHash('#statistik', 'stat-card');
await page.waitForFunction(
  () => document.querySelector('[data-testid="stat-card"][data-label="Provision"]'),
  null, { timeout: 6000 },
).catch(() => {});
{
  const sonstigeCard = page.locator(`${tid('stat-card')}[data-label="Bewertungsbeitrag sonstige"]`);
  const bwpCard = page.locator(`${tid('stat-card')}[data-label="Bewertungspunkte"]`);
  const provisionCard = page.locator(`${tid('stat-card')}[data-label="Provision"]`);
  const sonstigeText = await sonstigeCard.innerText().catch(() => '');
  const bwpText = await bwpCard.innerText().catch(() => '');
  const provisionText = await provisionCard.innerText().catch(() => '');
  // 2 synthetische Verkaeufe: 1000 (Maerz) + 500 (November), provision_mode
  // 'fest', provision_faktor 0.1, bwp_faktor 1 -> Beitrag 1500, BWP 1500, Provision 150.
  const expectedBeitrag = (1000 + 500).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
  const expectedBwp = (1500).toLocaleString('de-DE', { maximumFractionDigits: 1 });
  const expectedProvision = (150).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
  record('Statistik: Bewertungsbeitrag sonstige summiert beide Verkaeufe', sonstigeText.includes(expectedBeitrag), `Karte: ${sonstigeText.replace(/\n/g, ' ')} | erwartet: ${expectedBeitrag}`);
  record('Statistik: Bewertungspunkte korrekt aggregiert', bwpText.includes(expectedBwp), `Karte: ${bwpText.replace(/\n/g, ' ')} | erwartet: ${expectedBwp}`);
  record('Statistik: Provision korrekt aus fest-Faktor berechnet', provisionText.includes(expectedProvision), `Karte: ${provisionText.replace(/\n/g, ' ')} | erwartet: ${expectedProvision}`);
}

// ---- Test 13 (NEU): Serientermine-Autofuellung erzeugt die richtige,
// korrekt getaggte Zeile -- lief bereits automatisch beim Login/Reload,
// hier nur noch die aufgefangenen POST-Payloads auswerten. ----
{
  const matchingRow = seriesInsertedRows.find(r => r.title === 'RegressSerientermin');
  record('Serientermine-Autofuellung sendet mindestens eine Zeile fuer die Serie', !!matchingRow, `erfasste Zeilen: ${seriesInsertedRows.length}`);
  if (matchingRow) {
    const rowLocalDate = ymdHostLocal(new Date(matchingRow.start_at));
    record('Serientermin-Zeile faellt auf den erwarteten Kalendertag', rowLocalDate === seriesUntilDate, `Zeile: ${rowLocalDate}, erwartet: ${seriesUntilDate}`);
  }
}

// ---- Test 14+15+16 (NEU, 2026-08-23): mobiles/Touch-Verhalten. Braucht
// keinen neuen Login/Kontext -- die drei geprueften Stellen sind reine
// CSS-Media-Query-Umschaltungen bei 760px, page.setViewportSize() auf der
// bereits eingeloggten Seite reicht. Das Antippen des Verschieben-Menues
// wird bewusst NUR bis zum Oeffnen/Pruefen/Schliessen getestet, nicht bis zu
// einer abgeschlossenen Verschiebung -- ein echter Zug wuerde ueber
// logKanbanAction()/moveKanbanCard() eine RPC (log_action_for_self) und ein
// PATCH auf contacts ausloesen, die (anders als die synthetischen GET-
// Antworten oben) nicht abgefangen sind und am echten Konto haengen
// wuerden. Reines Oeffnen+Schliessen deckt trotzdem den eigentlichen Kern
// der Frage ab: kommt man per Antippen ueberhaupt an die Touch-Alternative
// zum (auf Touch nicht zuverlaessigen) nativen Ziehen heran?
await gotoHash('#kanban', 'kanban-board');
await page.waitForSelector(tid('kanban-card'), { timeout: 6000 }).catch(() => {});
const desktopBoardDir = await page.locator(tid('kanban-board')).evaluate(el => getComputedStyle(el).flexDirection).catch(() => null);
const desktopMoveBtnDisplay = await page.locator(tid('kanban-move-btn')).first().evaluate(el => getComputedStyle(el).display).catch(() => null);

await page.setViewportSize({ width: 390, height: 844 });
await page.waitForFunction(
  () => getComputedStyle(document.querySelector('[data-testid="kanban-board"]')).flexDirection === 'column',
  null, { timeout: 4000 },
).catch(() => {});
{
  const mobileBoardDir = await page.locator(tid('kanban-board')).evaluate(el => getComputedStyle(el).flexDirection).catch(() => null);
  const mobileMoveBtnDisplay = await page.locator(tid('kanban-move-btn')).first().evaluate(el => getComputedStyle(el).display).catch(() => null);
  record('Kanban-Layout schaltet unter 760px auf gestapelt um', desktopBoardDir === 'row' && mobileBoardDir === 'column', `desktop: ${desktopBoardDir}, mobil: ${mobileBoardDir}`);
  record('Verschieben-Knopf (Touch-Alternative) nur mobil sichtbar', desktopMoveBtnDisplay === 'none' && mobileMoveBtnDisplay !== 'none', `desktop: ${desktopMoveBtnDisplay}, mobil: ${mobileMoveBtnDisplay}`);

  const firstRow = KANBAN_TEST_ROWS[0];
  const moveBtn = page.locator(`${tid('kanban-card')}[data-contact="${firstRow.id}"] ${tid('kanban-move-btn')}`);
  await moveBtn.click({ trial: false }).catch(() => {});
  await page.waitForSelector(`${tid('kanban-move-modal')}`, { state: 'visible', timeout: 4000 }).catch(() => {});
  const menuVisible = await page.locator(tid('kanban-move-modal')).evaluate(el => el.style.display !== 'none').catch(() => false);
  const optionCount = await page.locator(`${tid('kanban-move-grid')} [data-movestage]`).count().catch(() => 0);
  record('Antippen des Verschieben-Knopfs oeffnet das Zielspalten-Menue', menuVisible);
  record('Menue listet alle uebrigen Kanban-Spalten als Ziel', optionCount === 7, `Optionen: ${optionCount} (erwartet: 7, KANBAN_STAGES.length-1)`);
  await page.locator(tid('kanban-move-close')).click().catch(() => {});
  await page.waitForFunction(
    () => document.querySelector('[data-testid="kanban-move-modal"]').style.display === 'none',
    null, { timeout: 3000 },
  ).catch(() => {});
  const menuClosedAgain = await page.locator(tid('kanban-move-modal')).evaluate(el => el.style.display === 'none').catch(() => false);
  record('Verschieben-Menue laesst sich ohne Aktion wieder schliessen', menuClosedAgain);
}

// Tag-Reiter: Kalender-/Aufgaben-Spalten stapeln sich mobil (dieselbe
// 760px-Schwelle wie oben).
await gotoHash('#tagebuch/tag/' + todayInResolvedTz, 'day-view-grid');
{
  const mobileCols = await page.locator(tid('day-view-grid')).evaluate(el => getComputedStyle(el).gridTemplateColumns.trim().split(/\s+/).length).catch(() => null);
  await page.setViewportSize({ width: 1280, height: 1000 });
  await page.waitForFunction(
    () => getComputedStyle(document.querySelector('[data-testid="day-view-grid"]')).gridTemplateColumns.trim().split(/\s+/).length === 2,
    null, { timeout: 4000 },
  ).catch(() => {});
  const desktopCols = await page.locator(tid('day-view-grid')).evaluate(el => getComputedStyle(el).gridTemplateColumns.trim().split(/\s+/).length).catch(() => null);
  record('Tagesansicht-Raster stapelt Kalender/Aufgaben mobil (1 statt 2 Spalten)', mobileCols === 1 && desktopCols === 2, `mobil: ${mobileCols} Spalte(n), desktop: ${desktopCols} Spalte(n)`);
}

// ---- Konsolenfehler ----
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
