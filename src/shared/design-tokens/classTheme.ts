/**
 * Die drei Charakterklassen und ihr Farbthema.
 *
 * WICHTIG: die eigentlichen Farbwerte sind hier NICHT dupliziert. Sie
 * leben als CSS-Variablen, die der Vanilla-Code (`applyClassTheme()` in
 * index.html) zur Laufzeit auf `document.documentElement` schreibt --
 * abhängig von `profile.character_class`. React-Komponenten im selben
 * Dokument erben diese Variablen automatisch (CSS-Kaskade), es braucht
 * dafür KEIN Re-Render.
 *
 * Regel für React (wird mit dem Styling-Spike / docs/adr 0006 auch per
 * Lint erzwungen): in Styles immer `var(--arcane)` etc. verwenden, nie
 * einen Hex-Wert hartcodieren. Wo ein aufgelöster Farb-String gebraucht
 * wird (z.B. `<canvas>`-Zeichnen), `getThemeColor()` benutzen.
 */
export const CHARACTER_CLASSES = ['zauberer', 'krieger', 'schuetze'] as const;
export type CharacterClass = (typeof CHARACTER_CLASSES)[number];

export const DEFAULT_CHARACTER_CLASS: CharacterClass = 'zauberer';

export const CLASS_LABELS: Record<CharacterClass, string> = {
  zauberer: 'Zauberer',
  krieger: 'Krieger',
  schuetze: 'Schütze',
};

/** Die 9 CSS-Variablen, die `applyClassTheme()` pro Klasse umschreibt. */
export const THEME_VARS = [
  '--void',
  '--panel',
  '--panel-2',
  '--border',
  '--arcane',
  '--arcane-glow',
  '--mana',
  '--bg-glow-1',
  '--bg-glow-2',
] as const;

export function isCharacterClass(value: unknown): value is CharacterClass {
  return typeof value === 'string' && (CHARACTER_CLASSES as readonly string[]).includes(value);
}

/**
 * Aufgelöster Farbwert einer Theme-CSS-Variablen (z.B. `'--arcane'`) --
 * für Stellen, die einen echten Farb-String brauchen statt `var(...)`
 * (Canvas, dynamisch erzeugtes SVG). Liest den Live-Wert vom Dokument,
 * den der Vanilla-Code gesetzt hat.
 */
export function getThemeColor(cssVar: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(cssVar).trim();
}
