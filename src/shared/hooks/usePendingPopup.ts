import { useCallback, useRef, useState } from 'react';

interface PendingEntry<TPayload, TResult> {
  payload: TPayload;
  resolve: (result: TResult) => void;
}

export interface PendingPopup<TPayload, TResult> {
  /** Die Nutzdaten des gerade offenen Popups, `null` wenn keines offen ist. */
  pending: TPayload | null;
  /** Öffnet das Popup mit `payload`, die zurückgegebene Promise löst erst bei `respond()` auf. */
  request: (payload: TPayload) => Promise<TResult>;
  /** Beantwortet das offene Popup und schließt es. */
  respond: (result: TResult) => void;
}

/**
 * Generische Grundlage für "ein Popup offen halten, per Promise auflösen,
 * sobald der Nutzer antwortet" — vorher in `useKanbanSalePopups.tsx` UND
 * `useKanbanExtraPopups.tsx` unabhängig voneinander dupliziert (Fund
 * einer unabhängigen Zweitmeinung, `kanban/README.md`). Höchstens ein
 * Popup pro Hook-Instanz gleichzeitig — Aufrufer, die mehrere Popup-Arten
 * brauchen, nutzen mehrere Instanzen (siehe die beiden Kanban-Hooks).
 */
export function usePendingPopup<TPayload, TResult>(): PendingPopup<TPayload, TResult> {
  const [pending, setPending] = useState<TPayload | null>(null);
  const pendingRef = useRef<PendingEntry<TPayload, TResult> | null>(null);

  const request = useCallback((payload: TPayload) => {
    return new Promise<TResult>((resolve) => {
      pendingRef.current = { payload, resolve };
      setPending(payload);
    });
  }, []);

  const respond = useCallback((result: TResult) => {
    pendingRef.current?.resolve(result);
    pendingRef.current = null;
    setPending(null);
  }, []);

  return { pending, request, respond };
}
