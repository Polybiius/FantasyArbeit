import { Component, type ReactNode } from 'react';

interface Props {
  children: ReactNode;
  /** Optionaler Ersatz-Inhalt. Default: schlichte Meldung mit Neu-laden-Knopf. */
  fallback?: ReactNode;
  /**
   * Ändert sich dieser Wert, setzt sich die Boundary zurück und zeigt
   * ihre Kinder erneut. Typisch: `useLocation().key` — ein Routenwechsel
   * soll einen vorübergehenden Render-Fehler nicht dauerhaft einfrieren.
   */
  resetKey?: string;
}

interface State {
  hasError: boolean;
  seenResetKey: string | undefined;
}

/**
 * Fängt Render-Fehler im React-Teilbaum ab und zeigt einen Ersatz-Inhalt,
 * statt die Seite weiß werden zu lassen.
 *
 * Das **Protokollieren** ins `error_log` macht NICHT diese Komponente,
 * sondern `createRoot(..., { onCaughtError })` in `main.tsx` — ein Owner
 * pro Fehler (sonst zwei `error_log`-Zeilen).
 *
 * Klassenkomponente, weil React (auch 19) für Error-Boundaries kein
 * Hook-Äquivalent hat.
 */
export class ErrorBoundary extends Component<Props, State> {
  override state: State = { hasError: false, seenResetKey: this.props.resetKey };

  static getDerivedStateFromError(): Partial<State> {
    return { hasError: true };
  }

  static getDerivedStateFromProps(props: Props, state: State): Partial<State> | null {
    if (props.resetKey !== state.seenResetKey) {
      return { hasError: false, seenResetKey: props.resetKey };
    }
    return null;
  }

  override render(): ReactNode {
    if (!this.state.hasError) return this.props.children;
    if (this.props.fallback !== undefined) return this.props.fallback;
    return (
      <div style={{ font: '14px system-ui', padding: 24 }}>
        <p>Etwas ist schiefgelaufen. Bitte die Seite neu laden.</p>
        <button type="button" onClick={() => window.location.reload()}>
          Neu laden
        </button>
      </div>
    );
  }
}
