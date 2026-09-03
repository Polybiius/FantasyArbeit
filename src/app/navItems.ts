import type { CharacterClass } from '@/shared/design-tokens/classTheme';

/**
 * 1:1-Portierung der Nav-Struktur aus `index.html` (`<nav class="sidebar">`,
 * `VALID_PAGES`, `CLASS_KANBAN_LABELS`/`CLASS_CONTACT_LABELS`/
 * `CLASS_GUILD_LABELS`/`CLASS_STATISTIK_LABELS`, `POOL_HIDDEN_NAV_PAGES`,
 * die drei `profile.role==='admin'`-Sichtbarkeitszeilen und
 * `navTeamReportingBtn`). Reine Daten, keine Logik -- welche Regel pro
 * Eintrag gilt, steht in `visibility`, ausgewertet von `Sidebar.tsx`
 * gegen `useProfileFlags()`/`useNavState()`.
 *
 * Bei jeder künftigen Nav-Änderung in `index.html` (neue Seite, neues
 * Label) MUSS diese Datei mitgezogen werden, bis der jeweilige Bereich
 * migriert ist und die Vanilla-Seite entfällt -- sonst zeigen alte und
 * neue Sidebar unterschiedliche Einträge.
 */

const CLASS_KANBAN_LABELS: Record<CharacterClass, string> = {
  zauberer: 'Questpfad',
  krieger: 'Gildenbrett',
  schuetze: 'Feldzug',
};

const CLASS_CONTACT_LABELS: Record<CharacterClass, string> = {
  zauberer: 'Arkanes Register',
  krieger: 'Kriegsarchiv',
  schuetze: 'Jägerchronik',
};

const CLASS_GUILD_NAV_LABELS: Record<CharacterClass, string> = {
  zauberer: 'Orden',
  krieger: 'Legion',
  schuetze: 'Bund',
};

const CLASS_STATISTIK_LABELS: Record<CharacterClass, string> = {
  zauberer: 'Arkanes Kompendium',
  krieger: 'Kriegskasse',
  schuetze: 'Trophäenkammer',
};

export type NavPageId =
  | 'organisation'
  | 'charakter'
  | 'handlungen'
  | 'kontakte'
  | 'dungeons'
  | 'kanban'
  | 'inventar'
  | 'gilde'
  | 'tagebuch'
  | 'statistik'
  | 'einstellungen'
  | 'produkte'
  | 'fehlerprotokoll'
  | 'notfallzugriff'
  | 'team-reporting';

/**
 * Vier UNABHÄNGIGE Sichtbarkeitsregeln, exakt wie in `index.html`
 * (`setPoolNavVisibility()` + die drei Admin-Zeilen + `navTeamReportingBtn`)
 * -- keine Regel schließt eine andere ein, bewusst nicht zu einer
 * kombinierten Bedingung zusammengefasst, um genau dasselbe Verhalten
 * (inkl. Randfälle) zu spiegeln.
 */
export type NavVisibility =
  | 'always' // sichtbar außer im Pool-Zustand (POOL_HIDDEN_NAV_PAGES)
  | 'poolOnly' // NUR im Pool-Zustand sichtbar (nur "organisation")
  | 'admin' // profile.role==='admin' UND nicht im Pool-Zustand
  | 'guildFounder'; // nur bei mindestens einer gegründeten Gilde, nicht im Pool-Zustand

export interface NavItemDef {
  readonly page: NavPageId;
  readonly icon: string;
  readonly label: string | Record<CharacterClass, string>;
  readonly visibility: NavVisibility;
}

export const NAV_ITEMS: readonly NavItemDef[] = [
  { page: 'organisation', icon: '🏛', label: 'Organisation', visibility: 'poolOnly' },
  { page: 'charakter', icon: '🧙', label: 'Charakter', visibility: 'always' },
  { page: 'handlungen', icon: '⚔', label: 'Handlungen', visibility: 'always' },
  { page: 'kontakte', icon: '📇', label: CLASS_CONTACT_LABELS, visibility: 'always' },
  { page: 'dungeons', icon: '🗺', label: 'Dungeons', visibility: 'always' },
  { page: 'kanban', icon: '🗂', label: CLASS_KANBAN_LABELS, visibility: 'always' },
  { page: 'inventar', icon: '🎒', label: 'Inventar', visibility: 'always' },
  { page: 'gilde', icon: '🛡', label: CLASS_GUILD_NAV_LABELS, visibility: 'always' },
  { page: 'tagebuch', icon: '📖', label: 'Abenteuerlog', visibility: 'always' },
  { page: 'statistik', icon: '📊', label: CLASS_STATISTIK_LABELS, visibility: 'always' },
  { page: 'einstellungen', icon: '⚙️', label: 'Einstellungen', visibility: 'always' },
  { page: 'produkte', icon: '📦', label: 'Produkte', visibility: 'admin' },
  { page: 'fehlerprotokoll', icon: '🛠', label: 'Fehlerprotokoll', visibility: 'admin' },
  { page: 'notfallzugriff', icon: '🚨', label: 'Notfallzugriff', visibility: 'admin' },
  { page: 'team-reporting', icon: '👥', label: 'Team-Reporting', visibility: 'guildFounder' },
];

export function resolveNavLabel(item: NavItemDef, characterClass: CharacterClass): string {
  return typeof item.label === 'string' ? item.label : item.label[characterClass];
}

export function isNavItemVisible(
  item: NavItemDef,
  flags: { readonly isPool: boolean; readonly isAdmin: boolean; readonly isGuildFounder: boolean },
): boolean {
  // Härtung über die 1:1-Portierung von index.html hinaus (unabhängige
  // Zweitmeinung, 2026-09-03): Vanillas admin-Zeilen prüften nur
  // profile.role, unabhängig vom Pool-Zustand -- ein Admin, der (auf
  // welchem Weg auch immer) in den Pool wechselt, hätte weiterhin
  // Produkte/Fehlerprotokoll/Notfallzugriff in der Sidebar gesehen.
  // Heute strukturell unerreichbar (jeder Weg in den Pool erzwingt
  // role='member'), aber ohne Funktionsverlust zu schließen.
  if (flags.isPool && (item.visibility === 'admin' || item.visibility === 'guildFounder')) return false;
  switch (item.visibility) {
    case 'poolOnly':
      return flags.isPool;
    case 'admin':
      return flags.isAdmin;
    case 'guildFounder':
      return flags.isGuildFounder;
    case 'always':
      return !flags.isPool;
  }
}
