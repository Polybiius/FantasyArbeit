# `einstellungen/` — Block-3-Pilot

Entspricht `#page-einstellungen` in `index.html` (Nav "⚙️ Einstellungen").
Testet die komplette Brücken-Infrastruktur aus Block 1+2 im echten Betrieb,
bevor Block 5 (Kanban+Kontakte, das eigentliche Kernstück) drankommt —
siehe `docs/migration-status.md` und ADR-0001–0004.

## Wie das Mounten funktioniert

`index.html` hat unter `#page-einstellungen` einen `<div id="react-root">`
(ersetzt das frühere `#settingsGroupsWrap`). `showPage()` ruft für
`'einstellungen'` bewusst **nicht mehr** `renderEinstellungenPage()` auf —
die vanilla Funktion bleibt vorerst als toter Code stehen (Lint-Warnung
akzeptiert), wird entfernt, sobald dieser Ordner vollständig ist. Sichtbar/
unsichtbar wird die React-Seite exakt wie jede andere `.page` über
`display:none`/`block` auf dem umgebenden Vanilla-Div — React selbst
muss dafür nichts Eigenes tun. Der einzige globale `#react-root`
(`main.tsx`) sitzt damit physisch innerhalb von `#page-einstellungen`;
das ist eine bewusste Block-3-Verkürzung, kein Zielzustand — Block 4
(App-Rahmen) baut die Mount-Strategie neu, sobald mehr als eine Seite
React ist.

## Stand

**Alle vier SETTINGS_GROUPS sind fertig migriert (2026-09-03, Chunk 2):**

| Gruppe (SETTINGS_GROUPS) | Status | Komponente |
|---|---|---|
| 👤 Profil (real_name, company) | ✅ React | `sections/ProfilSection.tsx` |
| 📖 Kontakt-Chronik (chronik_show_xp) | ✅ React | `sections/ChronikSection.tsx` |
| 📊 Provision & Planungsziele (8 Zahlenfelder) | ✅ React | `sections/ProvisionSection.tsx` |
| 📅 Kalender (2 Toggles, Zeitzone, Arbeitszeiten) | ✅ React | `sections/KalenderSection.tsx` |
| Danger Zone | bewusst dauerhaft Vanilla (`leaveOrgBtn`/`deleteAccountBtn`, eigene Listener außerhalb von `renderEinstellungenPage()`) | — |

**Suche (`settingsApplySearch`) bewusst NICHT nachgebaut** — die gab es in
Vanilla nur, weil Felder hinter Kachel+Modal versteckt waren. Im flachen
Wegwerf-Layout liegt alles offen auf einer Seite, eine Suche darüber hätte
kaum Mehrwert. Kein "noch zu tun", sondern eine Layout-bedingte
Vereinfachung.

**Vanilla-Gegenstück ist damit komplett funktional tot** (`SETTINGS_REGISTRY`/
`SETTINGS_GROUPS`, `renderEinstellungenPage()` + alle ausschließlich davon
aufgerufenen Helfer wie `openSettingsGroupModal()`/`settingsToggleChanged()`/
`wireArbeitszeitenExtras()` etc.) — **bewusst nicht gelöscht**, das passiert
erst gebündelt am Ende der gesamten Migration, wenn der komplette
`<script>`-Block aus `index.html` entfernt wird (`docs/migration-status.md`,
Abschnitt "Fertig"-Definition). Ein einzelnes Feature isoliert
herauszuschneiden wäre unnötiges Risiko in einer noch aktiv genutzten
11.000-Zeilen-IIFE, ohne dass es jemand sieht (tote Funktionen laufen nie).
Einzige Spur: eine akzeptierte `no-unused-vars`-Lint-Warnung auf
`renderEinstellungenPage`.

## Bridge-Erweiterung: `notifyProfilePatch()`

`profiles` ist die einzige Tabelle, in die React direkt schreibt (kein
`*_locked`-RPC nötig, siehe CLAUDE.md "Konflikt-Schutz" — `profiles` hat
strukturell nur einen möglichen Schreiber). Nach jeder erfolgreichen
Mutation ruft `api.ts` `getBridge().notifyProfilePatch(patch)` auf — die
einzige Ausnahme von "die Brücke ist nur lesbar" (ADR-0002-Nachtrag):
React liefert nur den vom Server bestätigten Patch, der Vanilla-Code
selbst mutiert sein `profile`-Objekt damit (`Object.assign`). Ohne das
würde z.B. `chronik_show_xp` im Vanilla-Objekt stehenbleiben, bis die
Seite neu lädt, während React schon den neuen Wert zeigt.

## Bekannte, bewusst in Kauf genommene Abweichung

`KalenderSection.tsx` zeigt beim Zeitzone-Dropdown `Europe/Berlin` fest
verdrahtet als "Standard der Organisation" statt `org.timezone` zu lesen
(Vanilla liest das echte Feld). Grund: `window.__bridge` reicht bisher
kein `org`-Objekt durch (nur `sb`/Session/Profil, siehe ADR-0002) — eine
Erweiterung nur für diese eine Anzeige-Zeile war hier nicht gerechtfertigt.
**Aktuell folgenlos:** `organizations.timezone` ist projektweit für JEDE
Organisation fix `Europe/Berlin` (CLAUDE.md, "internationale Skalierung"
ist vorbereitet, aber nicht genutzt). Wird das je konfigurierbar, muss die
Bridge um einen `getOrg()`-Zugriff erweitert werden (gleiches Muster wie
`getProfile()`).

## Query-Keys

`qk.einstellungen.self()` (in `queryKeys.ts` bereits als Block-3-Beispiel
angelegt) — ein einziger Key für "mein Profil", da Einstellungen keine
Liste sind und keine Sichtbarkeits-Schichten wie Kontakte/Kanban kennen.
