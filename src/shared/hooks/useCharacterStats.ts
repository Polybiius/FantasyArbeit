import { useSyncExternalStore } from 'react';

import { getBridge, type CharacterStats } from '@/shared/lib/bridge';

function subscribe(onChange: () => void): () => void {
  try {
    return getBridge().onStatsChange(onChange);
  } catch {
    return () => {};
  }
}

function getSnapshot(): CharacterStats | null {
  try {
    return getBridge().getCharacterStats();
  } catch {
    return null;
  }
}

/**
 * Live-Snapshot von Level/XP/Energie, aus Vanillas `render()` über die
 * Brücke (ADR-0002-Nachtrag 3). `null`, solange noch kein Vanilla-
 * `render()` gelaufen ist (z.B. kurz während des Logins) -- Aufrufer
 * zeigen dafür einen Lade-/Platzhalterzustand, keinen Fehler.
 *
 * Aktualisiert sich automatisch nach JEDER geloggten Aktion, egal ob sie
 * von einer Vanilla-Seite oder (künftig) einer React-Seite ausgelöst
 * wurde -- render() ruft `__bridgeNotifyStats()` bei jedem eigenen Lauf.
 */
export function useCharacterStats(): CharacterStats | null {
  return useSyncExternalStore(subscribe, getSnapshot, () => null);
}
