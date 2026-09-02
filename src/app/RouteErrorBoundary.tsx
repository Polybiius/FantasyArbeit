import type { ReactNode } from 'react';
import { useLocation } from 'react-router-dom';

import { ErrorBoundary } from '@/app/ErrorBoundary';

/**
 * Error-Boundary, die sich bei jedem Routenwechsel zurücksetzt — muss
 * INNERHALB von `<HashRouter>` sitzen (nutzt `useLocation`). Verhindert,
 * dass ein vorübergehender Render-Fehler (langsame Query liefert kurz
 * `null`, kaputte UUID im Deep-Link) den React-Teil dauerhaft auf „Bitte
 * neu laden" festnagelt.
 */
export function RouteErrorBoundary({ children }: { children: ReactNode }) {
  const location = useLocation();
  return <ErrorBoundary resetKey={location.key}>{children}</ErrorBoundary>;
}
