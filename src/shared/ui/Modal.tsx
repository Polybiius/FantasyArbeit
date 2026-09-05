import type { ReactNode } from 'react';

export interface ModalProps {
  title: ReactNode;
  onClose: () => void;
  children: ReactNode;
  testId?: string;
  closeTestId?: string;
}

/**
 * Reiner, unbestylter Modal-Rahmen (`shared/ui` — kein Geschäftswissen,
 * siehe `shared/README.md`) — Entsprechung zu Vanillas `.loc-modal`.
 * Klick auf den Hintergrund UND das ✕ rufen beide `onClose()`, genau wie
 * die meisten `.loc-modal`-Instanzen im echten Code (z.B. `saleEntryModal`,
 * dessen `closeBtn` denselben `finish()`-Pfad wie „Fertig“ nimmt — der
 * Aufrufer entscheidet über `onClose`, was das im Einzelfall bedeutet).
 */
export function Modal({ title, onClose, children, testId, closeTestId }: ModalProps) {
  return (
    <div
      className="tw:fixed tw:inset-0 tw:z-50 tw:flex tw:items-center tw:justify-center tw:bg-void/70 tw:p-4"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        data-testid={testId}
        className="tw:w-full tw:max-w-md tw:rounded-md tw:border tw:border-border tw:bg-panel tw:p-4 tw:shadow-raised"
      >
        <div className="tw:mb-3 tw:flex tw:items-center tw:justify-between tw:gap-2">
          <span className="tw:text-sm tw:font-semibold tw:text-text">{title}</span>
          <button
            type="button"
            data-testid={closeTestId}
            onClick={onClose}
            aria-label="Schließen"
            className="tw:rounded-sm tw:px-1.5 tw:py-0.5 tw:text-muted tw:hover:text-text"
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
