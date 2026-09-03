import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// Der React-Umbau (docs/adr/0001) läuft als Strangler-Fig PARALLEL zur
// bestehenden Vanilla-index.html. Vite bekommt deshalb einen EIGENEN
// HTML-Einstieg (app.html), damit nichts mit der produktiven index.html
// kollidiert.
//
// Auslieferung (docs/adr/0002, Nachtrag 2026-09-03): der Build erzeugt
// dist/ mit STABILEN Dateinamen -- assets/react.js (Entry-JS) und
// assets/app.css (aus dem app.html-Entry extrahiertes CSS). dist/ ist
// mitversioniert, GitHub Pages serviert es aus dem Repo-Wurzelverzeichnis.
// Ab Block 3 lädt index.html beide per festen Tags. `npm run build` läuft
// vor jedem Commit, der src/ ändert (sobald die Tags stehen). GitHub
// Actions als automatischer Build+Deploy bleibt der spätere Zielzustand.
//
// Assets (Schriftarten, Charakter-Sprites) bleiben vorerst an ihrem
// bestehenden Ort im Repo-Wurzelverzeichnis. Der public/-Ordner für die
// React-Seite kommt in Block 3/5 (docs/adr/0005, "Asset-Pipeline-Falle").
// tailwindcss()-Plugin: Styling-Grundlage ab Block 4 (docs/adr/0006).
export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': resolve(import.meta.dirname, 'src') },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: resolve(import.meta.dirname, 'app.html'),
      output: {
        entryFileNames: 'assets/react.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
      },
    },
  },
});
