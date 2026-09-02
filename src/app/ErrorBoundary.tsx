import { Component, type ErrorInfo, type ReactNode } from 'react';

import { logToErrorLog } from '@/shared/lib/errorLog';

interface Props {
  children: ReactNode;
  /** Optionaler Ersatz-Inhalt. Default: schlichte Meldung mit Neu-laden-Knopf. */
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
}

/**
 * Fängt Render-Fehler im React-Teilbaum ab, protokolliert sie ins
 * `error_log` (wie `reportError()` im Vanilla-Code) und zeigt einen
 * Ersatz-Inhalt, statt die ganze Seite weiß werden zu lassen.
 *
 * Klassenkomponente, weil React (auch 19) für Error-Boundaries kein
 * Hook-Äquivalent hat.
 */
export class ErrorBoundary extends Component<Props, State> {
  override state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  override componentDidCatch(error: Error, info: ErrorInfo): void {
    logToErrorLog(
      'React ErrorBoundary',
      `${error.message}\n${info.componentStack ?? ''}`.trim(),
    );
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
