/**
 * Wiederverwendbare Tailwind-Klassen für einfache `<select>`/`<input>`/
 * `<label>`-Elemente in Modalen — vorher an drei Stellen im Kanban-Feature
 * (`KanbanWonSaleModal`/`KanbanLostSaleModal`/`KanbanTerminModal`) einzeln
 * dupliziert (Fund einer unabhängigen Zweitmeinung, `kanban/README.md`).
 */
export const formSelectClass =
  'tw:rounded-sm tw:border tw:border-border tw:bg-panel-2 tw:px-2 tw:py-1.5 tw:text-sm tw:text-text';
export const formInputClass = formSelectClass;
export const formLabelClass = 'tw:mt-1 tw:block tw:text-xs tw:text-muted';
