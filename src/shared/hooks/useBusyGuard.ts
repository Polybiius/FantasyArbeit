import { useCallback, useRef, useState } from 'react';

export interface BusyGuard {
  /** true, solange irgendeine über `run()` gestartete Aktion läuft. */
  busy: boolean;
  /** Führt `fn` aus, außer eine vorige über denselben Hook gestartete Aktion läuft noch. */
  run: <T>(fn: () => Promise<T>) => Promise<T | undefined>;
}

/**
 * Wie `useGuardedAction()` (Doppelklick-Schutz, Ref-basiert synchron),
 * aber mit Rückgabewert UND Fehler-Weitergabe statt automatischem
 * Schlucken/Loggen — für Modale, die einen Fehler selbst als
 * Inline-Status-Text anzeigen wollen (`useGuardedAction` passt dafür
 * nicht: „der Hook Fehler verschluckt und nichts zurückgibt", Fund einer
 * unabhängigen Zweitmeinung, `kanban/README.md`).
 *
 * Nimmt bewusst `run(fn)` statt einer vorab gebundenen Aktion entgegen
 * (anders als `useGuardedAction`) — mehrere unterschiedliche Aktionen in
 * einem Modal (z.B. "+ Produkt hinzufügen" UND "Fertig") teilen sich so
 * eine einzige `busy`-Sperre, genau wie die manuell geschriebene Fassung
 * in den vier Kanban-Verkaufs-/Termin-/Zusatzaktions-Modalen vorher.
 */
export function useBusyGuard(): BusyGuard {
  const [busy, setBusy] = useState(false);
  const busyRef = useRef(false);

  const run = useCallback(async <T,>(fn: () => Promise<T>): Promise<T | undefined> => {
    if (busyRef.current) return undefined;
    busyRef.current = true;
    setBusy(true);
    try {
      return await fn();
    } finally {
      busyRef.current = false;
      setBusy(false);
    }
  }, []);

  return { busy, run };
}
