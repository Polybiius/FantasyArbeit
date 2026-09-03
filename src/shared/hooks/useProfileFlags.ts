import { useSyncExternalStore } from 'react';

import { getBridge } from '@/shared/lib/bridge';

/**
 * Einfache, direkte Profil-Feldabfragen (kein eigener Rechenweg) für die
 * Sidebar-Sichtbarkeit: Pool-Zustand (`org_id === null`) und Admin-Rolle.
 * Reagiert wie `useCharacterClass()` auf Login/Logout -- ein Live-Wechsel
 * mitten in der Sitzung (Org gründen/verlassen, Rolle ändert sich) braucht
 * bewusst weiterhin ein Neuladen, dieselbe akzeptierte Einschränkung wie
 * dort dokumentiert.
 */
export interface ProfileFlags {
  readonly isPool: boolean;
  readonly isAdmin: boolean;
}

const DEFAULT_FLAGS: ProfileFlags = { isPool: false, isAdmin: false };

// Modul-Singleton-Cache, DAMIT useSyncExternalStore nicht bei jedem Render
// ein neues Objekt sieht (sonst hält React es fälschlich für "geändert").
let cached: ProfileFlags = DEFAULT_FLAGS;

function subscribe(onChange: () => void): () => void {
  try {
    return getBridge().onAuthChange(onChange);
  } catch {
    return () => {};
  }
}

function getSnapshot(): ProfileFlags {
  try {
    const p = getBridge().getProfile();
    const next: ProfileFlags = { isPool: p?.org_id == null, isAdmin: p?.role === 'admin' };
    if (next.isPool !== cached.isPool || next.isAdmin !== cached.isAdmin) {
      cached = next;
    }
    return cached;
  } catch {
    return DEFAULT_FLAGS;
  }
}

export function useProfileFlags(): ProfileFlags {
  return useSyncExternalStore(subscribe, getSnapshot, () => DEFAULT_FLAGS);
}
