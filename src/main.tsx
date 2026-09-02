import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClientProvider } from '@tanstack/react-query';
import { HashRouter } from 'react-router-dom';

import { App } from '@/app/App';
import { ErrorBoundary } from '@/app/ErrorBoundary';
import { queryClient } from '@/app/queryClient';
import { logToErrorLog } from '@/shared/lib/errorLog';

// Einstiegspunkt des React-Teils.
//   - HashRouter: Deep-Links wie #kontakt/<id> bleiben bookmark-fähig und
//     GitHub-Pages-404-sicher (docs/adr/0003).
//   - QueryClientProvider: docs/adr/0004.
//   - ErrorBoundary + createRoot-Callbacks: Render-Fehler landen im
//     error_log statt spurlos die Seite weiß werden zu lassen.
// Das Klassen-Theme und der eigentliche Bezug zum Vanilla-Code
// (window.__bridge) kommen in den folgenden Block-2-Stücken hinzu.
const rootEl = document.getElementById('react-root');
if (!rootEl) throw new Error('#react-root nicht gefunden');

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
          <App />
        </HashRouter>
      </QueryClientProvider>
    </ErrorBoundary>
  </StrictMode>,
);
