import { CLASS_LABELS } from '@/shared/design-tokens/classTheme';
import { useCharacterClass } from '@/shared/hooks/useCharacterClass';

export function App() {
  const characterClass = useCharacterClass();

  return (
    <main style={{ font: '14px/1.5 system-ui, sans-serif', maxWidth: 640, margin: '48px auto', padding: '0 20px' }}>
      {/* var(--arcane) wird vom Vanilla-Code je nach Klasse gesetzt;
          der Fallback greift nur im Vite-Standalone (dev.html). */}
      <h1 style={{ fontSize: 20, color: 'var(--arcane, #8b5cf6)' }}>React-Grundgerüst steht</h1>
      <p>
        Etappe 2 der Migration (docs/adr/0001): das React-Gerüst kennt jetzt die
        Brücke zum Vanilla-Code — geteilter Datenbank-Client, Login-Status,
        Fehlerprotokoll, Adress- und Datenzugriffs-Verwaltung, und das
        Klassen-Farbthema.
      </p>
      <p>
        Aktive Klasse (über die Brücke gelesen): <strong>{CLASS_LABELS[characterClass]}</strong>
      </p>
      <p>
        Es ist noch <strong>keine Seite umgebaut</strong>. Die App läuft
        weiterhin vollständig über die bestehende <code>index.html</code>.
        Diese Seite hier ist nur der Entwicklungs-Einstieg (<code>dev.html</code>).
      </p>
    </main>
  );
}
