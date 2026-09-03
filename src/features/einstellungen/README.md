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

| Gruppe (SETTINGS_GROUPS) | Status |
|---|---|
| 👤 Profil (real_name, company) | ✅ React |
| 📖 Kontakt-Chronik (chronik_show_xp) | ✅ React |
| 📊 Provision & Planungsziele | offen (Vanilla-Registry-Einträge unverändert, aber unerreichbar seit React die Seite übernommen hat — siehe unten) |
| 📅 Kalender (Zeitzone, Arbeitszeiten, 2 Toggles) | offen |
| Suche (`settingsApplySearch`) | offen |
| Danger Zone | bewusst unverändert Vanilla (`leaveOrgBtn`/`deleteAccountBtn`, eigene Listener außerhalb von `renderEinstellungenPage()`) |

**Wichtig, bis die Tabelle oben komplett ist:** die drei noch nicht
migrierten Gruppen sind über die UI aktuell **nicht erreichbar** — sie
brauchen aber niemand ohne Vorwarnung zu verlieren, weil `#page-einstellungen`
nur den React-Teil zeigt, keine kaputten Reste. Der Pilot-Hinweis oben auf
der Seite sagt das explizit. Nächster Schritt: dieselben zwei Muster
(RHF+Zod-Formular für Text-/Zahlenfelder, sofort speichernder Toggle) auf
die restlichen Felder anwenden, plus die beiden Sonder-Widgets
(Zeitzonen-Dropdown, Arbeitszeiten-Wochenraster) als eigene Komponenten.

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

## Query-Keys

`qk.einstellungen.self()` (in `queryKeys.ts` bereits als Block-3-Beispiel
angelegt) — ein einziger Key für "mein Profil", da Einstellungen keine
Liste sind und keine Sichtbarkeits-Schichten wie Kontakte/Kanban kennen.
