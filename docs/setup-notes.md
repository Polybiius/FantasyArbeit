# Setup-Notizen (Werkzeug-Versionen + warum)

Der blinde Review (`project_framework_migration_plan`, Fund "Technische
Stolpersteine") verlangt: kritische Werkzeug-Versionen **exakt pinnen**
und die Begründung festhalten, sonst driftet das über viele einzelne
Bau-Sitzungen. Diese Datei ist dieser Festhalte-Ort.

## Gepinnt (exakt, kein `^`)

| Paket | Version | Warum exakt |
|---|---|---|
| `typescript` | **5.9.3** | Nicht 7.0 (das native GA-`tsc`), obwohl es „latest" ist: **`typescript-eslint@8` unterstützt nur `typescript <6.1.0`** (Peer-Dependency). typescript-eslint ist laut Review der strukturelle Ersatz für menschliches Code-Review — es MUSS laufen. Revisit: sobald typescript-eslint TS 7 unterstützt (v9?), dann auf 7.x. |
| `typescript-eslint` | **8.69.0** | Neuestes; gibt den TS-Deckel oben vor. |
| `vite` | **8.2.2** | |
| `@vitejs/plugin-react` | **6.1.1** | Babel-Variante (nicht `-swc`) — maximale Kompatibilität, Build-Tempo bei dieser Projektgröße egal. |

## Nicht gepinnt (`^`, stabil innerhalb Major)

`react`/`react-dom` 19, `react-router-dom` 7 (hat `HashRouter`,
`docs/adr/0003`), `@tanstack/react-query` 5, `react-hook-form` 7,
`zod` 4 + `@hookform/resolvers` 5 (**geprüft: resolvers 5 nennt
`zod: ^3.25.0 || ^4.0.0` als Peer — passendes Paar**, der im Review
genannte Zod-3/4-Bruch ist damit abgedeckt).

## Bewusst NICHT installiert

- **Tailwind / shadcn / Radix** — die Styling-Entscheidung ist offen bis
  zum Spike (`docs/adr` 0006). Erst danach.
- **Storybook, i18n, SSR** — siehe `docs/adr/0001` „Bewusst NICHT jetzt".

## Struktur

- Vite-Einstieg ist **`app.html`** (nicht `index.html` — die ist die
  produktive Vanilla-Seite). `vite.config.ts` setzt das über
  `rollupOptions.input`.
- `tsconfig.json` ist nur ein Verweis-Container; die echten Optionen
  stehen in `tsconfig.app.json` (Browser/`src/`) und `tsconfig.node.json`
  (`vite.config.ts`). `strict` + `noUncheckedIndexedAccess` +
  `noUnusedLocals/Parameters` von Anfang an.
- Import-Alias `@/` → `src/` (in `tsconfig.app.json` UND `vite.config.ts`
  — beide Stellen pflegen). Kein `baseUrl` (in TS 7 deprecated;
  `paths` funktioniert mit `moduleResolution: bundler` auch ohne).
- **Skript-Reihenfolge:** der React-Bundle (`dist/assets/react.js`) muss
  NACH dem Vanilla-`<script>` in `index.html` geladen werden, sonst
  fehlt `window.__bridge` beim Mount. Als `type="module"`-Skript ist er
  ohnehin deferred → läuft nach dem klassischen Inline-Skript. Den Tag
  also nicht in den `<head>` ziehen.
- **Auslieferung:** `dist/` ist mitversioniert (kein CI), stabile Namen
  (`assets/react.js`). Siehe `docs/adr/0002` Nachtrag 2026-09-03.

## Prüf-Befehle

```
npm run typecheck   # tsc -b (beide tsconfig-Projekte)
npm run lint        # eslint . -- alle Code-Welten (src / index.html / tests / *.mjs)
npm run build       # tsc -b && vite build  -> dist/  (VOR jedem src/-Commit, Block 3+)
npm run gen:types   # Schema-Typen neu erzeugen (nach jeder Migration)
npm run dev         # Vite-Dev-Server auf app.html
npm test            # Regressions-Suiten (unverändert)
```
