export function App() {
  return (
    <main style={{ font: '14px/1.5 system-ui, sans-serif', maxWidth: 640, margin: '48px auto', padding: '0 20px' }}>
      <h1 style={{ fontSize: 20 }}>React-Grundgerüst steht</h1>
      <p>
        Etappe 1 der Migration (docs/adr/0001): React, TypeScript (strikt),
        Vite, TanStack Query und React Hook Form + Zod sind eingerichtet, die
        Ordnerstruktur nach docs/adr/0005 ist angelegt.
      </p>
      <p>
        Es ist noch <strong>keine Seite umgebaut</strong>. Die App läuft
        weiterhin vollständig über die bestehende <code>index.html</code>.
        Diese Seite hier ist nur der Entwicklungs-Einstieg (<code>dev.html</code>).
      </p>
    </main>
  );
}
