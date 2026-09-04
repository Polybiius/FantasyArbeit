import type { KanbanStage } from './kanbanTransitions';

/**
 * 1:1-Portierung von `KANBAN_STAGE_META` aus `index.html` — Icon+Label
 * pro Spalte, klassen-UNabhängig (nur der Seitentitel selbst ist
 * klassenabhängig, siehe `navItems.ts` `CLASS_KANBAN_LABELS` — Fragen/
 * Gildenbrett/Feldzug -- die Spaltennamen bleiben über alle drei Klassen
 * hinweg identisch).
 */
export const KANBAN_STAGE_META: Record<KanbanStage, { icon: string; label: string }> = {
  neuer_lead: { icon: '🚩', label: 'Neuer Lead' },
  ersttermin_vereinbart: { icon: '📜', label: 'Ersttermin vereinbart' },
  angebot_versendet: { icon: '✉️', label: 'Angebot versendet' },
  zweittermin: { icon: '🤝', label: 'Zweittermin' },
  nicht_erschienen: { icon: '🌫', label: 'Nicht erschienen' },
  gewonnen: { icon: '🏆', label: 'Gewonnen' },
  verloren: { icon: '❌', label: 'Verloren' },
  dauerbrenner: { icon: '🔥', label: 'Dauerbrenner' },
};
