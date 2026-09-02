import { useSyncExternalStore } from 'react';

import {
  DEFAULT_CHARACTER_CLASS,
  isCharacterClass,
  type CharacterClass,
} from '@/shared/design-tokens/classTheme';
import { getBridge } from '@/shared/lib/bridge';

function subscribe(onChange: () => void): () => void {
  try {
    return getBridge().onAuthChange(onChange);
  } catch {
    return () => {};
  }
}

function getSnapshot(): CharacterClass {
  try {
    const cls = getBridge().getProfile()?.character_class;
    return isCharacterClass(cls) ? cls : DEFAULT_CHARACTER_CLASS;
  } catch {
    return DEFAULT_CHARACTER_CLASS;
  }
}

/**
 * Aktuelle Charakterklasse, aus dem Vanilla-Profil über die Brücke.
 * Aktualisiert sich bei Login/Logout.
 *
 * Ein Live-Wechsel über den versteckten Admin-Klassenschalter erfordert
 * derzeit ein Neuladen — reicht, solange keine React-Komponente die
 * Klasse JS-seitig auswertet. Die Farb-CSS-Variablen wechseln ohnehin
 * ohne Re-Render (Vanilla `applyClassTheme()` setzt sie am Dokument).
 * Sobald eine React-Komponente eine echte Live-Reaktion braucht, kriegt
 * `applyClassTheme()` ein `window.dispatchEvent(new CustomEvent(...))`
 * und dieser Hook hört zusätzlich darauf.
 */
export function useCharacterClass(): CharacterClass {
  return useSyncExternalStore(subscribe, getSnapshot, () => DEFAULT_CHARACTER_CLASS);
}
