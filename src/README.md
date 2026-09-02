# `src/` — der React-Teil (im Aufbau)

Entsteht schrittweise neben der bestehenden `index.html` (Strangler-Fig,
`docs/adr/0001`). Solange ein Bereich hier noch nicht existiert, läuft er
weiter über die Vanilla-`index.html`. Stand: `docs/migration-status.md`.

## Struktur (`docs/adr/0005`)

```
src/
  app/          Routing (Hash), Seitenrahmen/Vollbreite-Layout, globale Anbieter
  shared/       bereichsübergreifend genutzt -- siehe shared/README.md
  features/     EIN Ordner pro Geschäftsbereich -- siehe features/README.md
```

**Feature-basiert, nicht layer-basiert:** ein `features/<bereich>/`-Ordner
enthält alles zu diesem Bereich (Komponenten, Hooks, Typen, Queries). Eine
neue Sitzung öffnet einen Ordner und sieht alles Relevante, statt zwischen
`components/`, `hooks/`, `pages/` zu springen.

## Import-Alias

`@/` zeigt auf `src/` (in `tsconfig.app.json` und `vite.config.ts`).
Also `import { X } from '@/shared/lib/...'`, nicht `../../../shared/...`.

## Regeln

- **Striktes TypeScript**, `@typescript-eslint/no-explicit-any` ist ein
  Fehler. Kein `any` als Ausweg.
- Neuer Code, der die Datenbank liest/schreibt, läuft über TanStack Query
  (`docs/adr/0004`) -- kein direktes `fetch`/`sb.from(...)` in Komponenten.
- Keine hartcodierten Farbwerte -- nur die Design-Tokens aus
  `shared/design-tokens/` (kommt mit Block 3 / dem Styling-Spike,
  `docs/adr` 0006).
- Prüfungen vor jedem Commit: `npm run typecheck` + `npm run lint`.
