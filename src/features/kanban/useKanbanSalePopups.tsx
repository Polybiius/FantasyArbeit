import type { ReactNode } from 'react';

import { usePendingPopup } from '@/shared/hooks/usePendingPopup';

import type { KanbanContact } from './kanbanApi';
import { KanbanLostSaleModal } from './KanbanLostSaleModal';
import { KanbanWonSaleModal, type WonSaleResult } from './KanbanWonSaleModal';

export interface KanbanSalePopups {
  requestWonSale(contact: KanbanContact): Promise<WonSaleResult>;
  requestLostSale(contact: KanbanContact): Promise<boolean>;
}

/**
 * Hält das aktuell offene Verkaufs-Popup (höchstens eines gleichzeitig —
 * ein Kanban-Zug ist immer eine einzelne, blockierende Nutzerinteraktion,
 * genau wie im Vanilla-Original) und liefert der Mutation
 * (`kanbanMutations.ts`) zwei Promise-basierte Einstiegspunkte, die erst
 * auflösen, wenn der Nutzer das Popup tatsächlich beantwortet hat —
 * dieselbe Promise-Choreografie wie `recordWonSalesLoop()`/
 * `recordLostSale()` in `index.html`.
 *
 * Baut seit einer unabhängigen Zweitmeinung (`kanban/README.md`) auf dem
 * generischen `usePendingPopup()`-Baustein auf (vorher eine eigene,
 * duplizierte Discriminated-Union-Fassung) — je eine Instanz pro
 * Verkaufs-Ausgang, kein gemeinsamer Bool-Rückgabetyp mehr nötig.
 */
export function useKanbanSalePopups(): { popups: KanbanSalePopups; modal: ReactNode } {
  const won = usePendingPopup<KanbanContact, WonSaleResult>();
  const lost = usePendingPopup<KanbanContact, boolean>();

  let modal: ReactNode = null;
  if (won.pending) {
    modal = <KanbanWonSaleModal contact={won.pending} onResolve={won.respond} />;
  } else if (lost.pending) {
    modal = <KanbanLostSaleModal contact={lost.pending} onResolve={lost.respond} />;
  }

  return { popups: { requestWonSale: won.request, requestLostSale: lost.request }, modal };
}
