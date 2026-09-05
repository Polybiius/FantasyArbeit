import { useCallback, type ReactNode } from 'react';

import { usePendingPopup } from '@/shared/hooks/usePendingPopup';

import { KanbanExtraActionModal } from './KanbanExtraActionModal';
import type { KanbanContact } from './kanbanApi';
import type { KanbanExtraActionOption } from './kanbanLabels';
import { KanbanTerminModal } from './KanbanTerminModal';
import type { KanbanKanal } from './kanbanTerminWrite';

interface ExtraActionPayload {
  contact: KanbanContact;
  options: readonly KanbanExtraActionOption[];
}

interface TerminPayload {
  contact: KanbanContact;
  label: string;
}

export interface KanbanExtraPopups {
  /** 1:1 zu `offerExtraAction()` — löst immer auf, egal ob eine Zusatzaktion gewählt wurde. */
  offerExtraAction(contact: KanbanContact, options: readonly KanbanExtraActionOption[]): Promise<void>;
  /** 1:1 zu `promptKanbanTermin()` — liefert den verwendeten Kanal (`null` bei Abbruch ohne Speichern). */
  promptTermin(contact: KanbanContact, label: string): Promise<KanbanKanal | null>;
}

/**
 * Hält das aktuell offene Zusatz-Popup (Bedarfsanalyse/Dauerbrenner-
 * Zusatzaktionen ODER Termin-Eintragung, höchstens eines gleichzeitig —
 * `kanbanMutations.ts` ruft diese Popups ohnehin nacheinander auf, nie
 * parallel, gleiche Choreografie wie `moveKanbanCard()` im Original).
 *
 * Baut seit einer unabhängigen Zweitmeinung (`kanban/README.md`) auf dem
 * generischen `usePendingPopup()`-Baustein auf (vorher eine eigene,
 * duplizierte Discriminated-Union-Fassung, dieselbe wie in
 * `useKanbanSalePopups.tsx`) — je eine Instanz pro Popup-Art.
 */
export function useKanbanExtraPopups(): { popups: KanbanExtraPopups; modal: ReactNode } {
  const extra = usePendingPopup<ExtraActionPayload, void>();
  const termin = usePendingPopup<TerminPayload, KanbanKanal | null>();

  const offerExtraAction = useCallback(
    (contact: KanbanContact, options: readonly KanbanExtraActionOption[]) => extra.request({ contact, options }),
    [extra],
  );
  const promptTermin = useCallback(
    (contact: KanbanContact, label: string) => termin.request({ contact, label }),
    [termin],
  );

  let modal: ReactNode = null;
  if (extra.pending) {
    modal = (
      <KanbanExtraActionModal
        contact={extra.pending.contact}
        options={extra.pending.options}
        onResolve={() => extra.respond(undefined)}
      />
    );
  } else if (termin.pending) {
    modal = <KanbanTerminModal contact={termin.pending.contact} label={termin.pending.label} onResolve={termin.respond} />;
  }

  return { popups: { offerExtraAction, promptTermin }, modal };
}
