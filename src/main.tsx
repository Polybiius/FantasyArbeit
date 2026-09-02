import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';

import { App } from '@/app/App';

// Einstiegspunkt des React-Teils. Die globalen Anbieter (TanStack Query,
// HashRouter, Klassen-Theme, Bruecke zum Vanilla-Code) kommen in Block 2
// hier hinzu -- Block 1 mountet nur ein leeres Geruest.
const rootEl = document.getElementById('react-root');
if (!rootEl) throw new Error('#react-root nicht gefunden');

createRoot(rootEl).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
