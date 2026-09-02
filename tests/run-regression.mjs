// Selbst-enthaltener Läufer für die Regressions-Suiten.
//
//   npm test           -> beide Suiten (Admin + Nicht-Admin)
//   npm run test:admin  -> nur regression_suite.mjs
//   npm run test:member -> nur regression_suite_member.mjs
//
// Startet selbst einen lokalen Static-Server (python3 -m http.server) im
// Repo-Wurzelverzeichnis, wartet bis er erreichbar ist, lässt die
// gewählte(n) Suite(n) dagegen laufen und räumt den Server danach wieder
// ab. Exit-Code != 0, sobald eine Suite fehlschlägt.
//
// Zugangsdaten: tests/regression_suite.mjs liest sie aus
//   $FANTASYARBEIT_TEST_CREDS  (Default: ~/.local/share/fantasyarbeit-claude-test/credentials.json)
//   $FANTASYARBEIT_TEST_CREDS_MEMBER (Default: .../credentials_member.json)
// -- bewusst außerhalb des Repos (gitignore-Pfad), nie mitversioniert.

import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..');

const which = (process.argv[2] || 'both').toLowerCase();
const PORT = Number(process.env.FANTASYARBEIT_TEST_PORT || 8971);

const suites = [];
if (which === 'both' || which === 'admin') suites.push(['regression_suite.mjs', 'Admin-Suite']);
if (which === 'both' || which === 'member') suites.push(['regression_suite_member.mjs', 'Nicht-Admin-Suite']);
if (!suites.length) {
  console.error(`Unbekanntes Ziel "${which}" -- erlaubt: both | admin | member`);
  process.exit(2);
}

// --- Static-Server starten ---
const server = spawn('python3', ['-m', 'http.server', String(PORT)], {
  cwd: repoRoot,
  stdio: 'ignore', // python http.server loggt jeden Request auf stderr -- unterdrücken
});
let serverDown = false;
server.on('exit', () => { serverDown = true; });

async function stopServer() {
  if (serverDown) return;
  server.kill('SIGTERM');
  await sleep(200);
  if (!serverDown) server.kill('SIGKILL');
}
process.on('SIGINT', async () => { await stopServer(); process.exit(130); });

async function waitForServer(timeoutMs = 10000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (serverDown) throw new Error('http.server ist sofort wieder beendet (python3 vorhanden?)');
    try {
      const res = await fetch(`http://localhost:${PORT}/index.html`, { method: 'HEAD' });
      if (res.ok) return;
    } catch { /* noch nicht bereit */ }
    await sleep(150);
  }
  throw new Error(`http.server auf Port ${PORT} nicht erreichbar nach ${timeoutMs} ms`);
}

function runSuite(file) {
  return new Promise(resolve => {
    const child = spawn(process.execPath, [join(__dirname, file), String(PORT)], {
      cwd: repoRoot,
      stdio: 'inherit',
    });
    child.on('exit', code => resolve(code ?? 1));
  });
}

let failed = false;
try {
  await waitForServer();
  for (const [file, label] of suites) {
    console.log(`\n──────── ${label} (${file}) ────────`);
    const code = await runSuite(file);
    if (code !== 0) failed = true;
  }
} catch (e) {
  console.error('Läufer-Fehler:', e.message);
  failed = true;
} finally {
  await stopServer();
}

process.exit(failed ? 1 : 0);
