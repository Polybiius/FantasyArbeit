import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Der React-Umbau (docs/adr/0001) laeuft als Strangler-Fig PARALLEL zur
// bestehenden Vanilla-index.html. Vite bekommt deshalb einen EIGENEN
// HTML-Einstieg (dev.html), damit nichts mit der produktiven index.html
// kollidiert. Wie der gebaute Bundle spaeter von der echten index.html
// geladen wird, entscheidet Block 2 (die Bruecke, docs/adr/0002).
//
// Assets (Schriftarten, Charakter-Sprites) bleiben vorerst an ihrem
// bestehenden Ort im Repo-Wurzelverzeichnis -- die produktive index.html
// referenziert sie mit relativen Pfaden. Der public/-Ordner fuer die
// React-Seite wird in Block 3/5 eingerichtet (siehe docs/adr/0005,
// "Asset-Pipeline-Falle": Sprite-Pfade werden zur Laufzeit als String
// gebaut, muessen also nach public/ statt src/assets/).
export default defineConfig({
  base: './',
  plugins: [react()],
  resolve: {
    alias: { '@': resolve(import.meta.dirname, 'src') },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: resolve(import.meta.dirname, 'dev.html'),
    },
  },
});
