import { useSyncExternalStore } from 'react';

import { getBridge, type NavState } from '@/shared/lib/bridge';

const DEFAULT_NAV_STATE: NavState = { activePage: 'charakter', isGuildFounder: false };

function subscribe(onChange: () => void): () => void {
  try {
    return getBridge().onNavChange(onChange);
  } catch {
    return () => {};
  }
}

function getSnapshot(): NavState {
  try {
    return getBridge().getNavState();
  } catch {
    return DEFAULT_NAV_STATE;
  }
}

/**
 * Von Vanillas `showPage()` aufgelöste aktive Seite + Gildengründer-
 * Status (ADR-0002-Nachtrag 4). Alle anderen Nav-Sichtbarkeitsregeln
 * (Admin-Rolle, Pool-Zustand) liest die Sidebar direkt aus dem Profil
 * (`getBridge().getProfile()`), siehe `src/app/navItems.ts`.
 */
export function useNavState(): NavState {
  return useSyncExternalStore(subscribe, getSnapshot, () => DEFAULT_NAV_STATE);
}
