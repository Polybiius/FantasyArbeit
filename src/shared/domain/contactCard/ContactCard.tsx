import type { ComponentPropsWithRef } from 'react';

import { contactDisplayName } from './contactDisplay';

export interface ContactCardData {
  readonly id: string;
  readonly name: string | null;
  readonly vorname: string;
  readonly nachname: string;
  /** Aufgelöster Betriebsname (`locations.name`), `null` = kein Dungeon zugeordnet. */
  readonly locationName: string | null;
}

export interface ContactCardProps {
  contact: ContactCardData;
  variant: 'kanban';
  /** Während des Ziehens gedimmt, 1:1 `.kanban-card.dragging{opacity:.4}` im Vanilla-Original. */
  isDragging?: boolean;
  /** Von `dnd-kit`s `useDraggable`/`useSortable` durchgereichte Props (ref/listeners/attributes/style). */
  rootProps?: ComponentPropsWithRef<'div'>;
}

/**
 * Die eine gemeinsame Kontakt-Karte (siehe `shared/domain/README.md`).
 * Rein präsentational — kein Datenzugriff, kein Zieh-Verhalten selbst
 * (das bringt der Aufrufer über `rootProps` mit, siehe `KanbanBoard.tsx`).
 *
 * Bewusst 1:1 gegen die echte Vanilla-Karte gehalten (`index.html`
 * `.kanban-card`): Name als Link auf die echte Kontakt-Seite
 * (`feedback_real_pages_over_modals_for_records` — Rechtsklick/neuer Tab
 * muss funktionieren, kein reiner Klick-Handler), optional der
 * Betriebsname darunter. `data-testid="kanban-card"` identisch zum
 * Vanilla-Original (Konvention aus `tests/README.md`).
 */
export function ContactCard({ contact, isDragging = false, rootProps }: ContactCardProps) {
  const { className, style, ...restRootProps } = rootProps ?? {};
  return (
    <div
      data-testid="kanban-card"
      className={`tw:relative tw:cursor-grab tw:rounded-sm tw:border tw:border-border tw:bg-panel tw:px-2.5 tw:py-2 tw:text-xs tw:shadow-rest tw:transition-colors tw:hover:border-arcane tw:hover:shadow-raised ${isDragging ? 'tw:opacity-40' : ''} ${className ?? ''}`}
      style={style}
      {...restRootProps}
    >
      <a
        href={`#kontakt/${contact.id}`}
        draggable={false}
        className="tw:block tw:font-semibold tw:text-text tw:no-underline"
        // Ziehen soll den Link nicht mit auslösen -- gleiche Absicht wie
        // die dnd-kit-Sensor-Aktivierungsdistanz in KanbanBoard.tsx, hier
        // zusätzlich als zweite Sicherung direkt am Link.
        onPointerDown={(e) => e.stopPropagation()}
      >
        {contactDisplayName(contact)}
      </a>
      {contact.locationName && (
        <span className="tw:mt-0.5 tw:block tw:font-mono-brand tw:text-[10.5px] tw:text-muted-2">
          {contact.locationName}
        </span>
      )}
    </div>
  );
}
