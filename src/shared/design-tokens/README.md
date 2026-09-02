# `src/shared/design-tokens/`

Die Quelle der Wahrheit für alles Farbige/Maßliche im React-Teil.

## Aktueller Stand (Block 2)

| Datei | Inhalt |
|---|---|
| `classTheme.ts` | die drei Charakterklassen (`CharacterClass`, `CLASS_LABELS`), die Namen der 9 Theme-CSS-Variablen (`THEME_VARS`), `getThemeColor()` zum Auslesen eines aufgelösten Farbwerts. |

## Wie das Farbthema funktioniert

Die **Farbwerte selbst leben nicht hier**, sondern als CSS-Variablen im
`:root` von `index.html` — und der Vanilla-Code (`applyClassTheme()`)
schreibt zur Laufzeit je nach Charakterklasse 9 davon auf
`document.documentElement` um (`--void`, `--panel`, `--panel-2`,
`--border`, `--arcane`, `--arcane-glow`, `--mana`, `--bg-glow-1`,
`--bg-glow-2`).

React-Komponenten rendern in dasselbe Dokument und **erben diese
Variablen automatisch** (CSS-Kaskade). Ein Klassenwechsel färbt die
React-UI ohne Re-Render um.

## Regeln

- In React-Styles **nur `var(--x)`**, nie einen Hex-Wert hartcodieren.
- Braucht Code einen echten Farb-String (Canvas, dynamisches SVG):
  `getThemeColor('--arcane')`.
- Neue Radius-/Schatten-Werte: die bestehenden `--radius-*` / `--shadow-*`
  weiterverwenden (aus `:root`), keine neuen erfinden.

## Noch offen

Der vollständige Token-Satz (Cinzel-Schrift, Radius/Schatten als
TS-Konstanten, die Abbildung auf das gewählte Styling-System) entsteht
mit dem **Styling-Spike** — `docs/adr` 0006, noch offen. Ebenso die
Lint-Regel gegen rohe Farbwerte außerhalb dieses Ordners.
