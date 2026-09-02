import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClientProvider } from '@tanstack/react-query';
import { HashRouter } from 'react-router-dom';

import '@/styles/tokens.css';

import { App } from '@/app/App';
import { ErrorBoundary } from '@/app/ErrorBoundary';
import { RouteErrorBoundary } from '@/app/RouteErrorBoundary';
import { queryClient } from '@/app/queryClient';
import { logToErrorLog } from '@/shared/lib/errorLog';

// Einstiegspunkt des React-Teils.
//   - HashRouter: Deep-Links wie #kontakt/<id> bleiben bookmark-fähig und
//     GitHub-Pages-404-sicher (docs/adr/0003).
//   - QueryClientProvider: docs/adr/0004.
//   - Zwei Boundaries: die äußere fängt katastrophale Mount-Fehler (kein
//     Reset), die innere (RouteErrorBoundary, in der Router-Umgebung)
//     setzt sich bei jedem Routenwechsel zurück.
//   - createRoot onUncaughtError/onCaughtError: DER EINE Ort, der
//     Render-Fehler ins error_log schreibt (nicht die Boundary selbst,
//     sonst zwei Zeilen).
// Klassen-Theme + window.__bridge-Bezug: siehe die shared/-Dateien.
const rootEl = document.getElementById('react-root');
if (!rootEl) {
  // Im produktiven index.html sollte das nie passieren; nicht die ganze
  // Seite mit einem Modul-Fehler mitreißen.
  console.error('#react-root nicht gefunden — React wird nicht gemountet.');
} else {
  createRoot(rootEl, {
    onUncaughtError: (error) => {
      logToErrorLog('React onUncaughtError', String(error));
    },
    onCaughtError: (error) => {
      logToErrorLog('React onCaughtError', String(error));
    },
  }).render(
    <StrictMode>
      <ErrorBoundary>
        <QueryClientProvider client={queryClient}>
          <HashRouter>
            <RouteErrorBoundary>
              <App />
            </RouteErrorBoundary>
          </HashRouter>
        </QueryClientProvider>
      </ErrorBoundary>
    </StrictMode>,
  );
}
