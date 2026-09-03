import { useState } from 'react';

import { useOwnProfileQuery, useUpdateOwnProfileMutation } from '../api';

/**
 * `undoValue` -- der Wert VOR der letzten erfolgreichen Speicherung, oder
 * `null` wenn nichts rückgängig zu machen ist. Behebt einen vom
 * unabhängigen Review 2026-09-03 gefundenen Regressions-Fund: Vanillas
 * `settingsToggleChanged()` zeigt nach jedem Toggle-Speichern 5 Sekunden
 * lang einen Toast mit funktionierendem "Rückgängig"-Knopf
 * (`settingsShowToast()`), das React-Gegenstück hatte davon zunächst gar
 * nichts -- bewusst einfacher nachgebaut (dauerhafter Inline-Link statt
 * zeitgesteuertem Toast, passt zum Wegwerf-Layout), aber die eigentliche
 * FUNKTION (rückgängig machen können) ist jetzt wieder da.
 */
export function ChronikSection() {
  const { data: profile } = useOwnProfileQuery();
  const updateChronik = useUpdateOwnProfileMutation();
  const [undoValue, setUndoValue] = useState<boolean | null>(null);

  if (!profile) return null;
  const checked = profile.chronik_show_xp;

  const onChange = (next: boolean) => {
    const previous = checked;
    updateChronik.mutate({ chronik_show_xp: next }, { onSuccess: () => setUndoValue(previous) });
  };
  const onUndo = () => {
    if (undoValue === null) return;
    updateChronik.mutate({ chronik_show_xp: undoValue }, { onSuccess: () => setUndoValue(null) });
  };

  return (
    <section className="ein-card">
      <h2>📖 Kontakt-Chronik</h2>
      <label className="ein-toggle-row">
        <input
          type="checkbox"
          checked={checked}
          disabled={updateChronik.isPending}
          onChange={(e) => onChange(e.target.checked)}
        />
        <span>
          XP-Werte anzeigen
          <div className="ein-toggle-desc">
            Zeigt XP-Zahlen zusätzlich zu den CRM-Fakten in der Kontakt-Chronik.
          </div>
        </span>
      </label>
      {undoValue !== null && !updateChronik.isPending && (
        <div className="ein-status" style={{ marginTop: 8 }}>
          Gespeichert.{' '}
          <button type="button" className="ein-undo-link" onClick={onUndo}>
            Rückgängig
          </button>
        </div>
      )}
      {updateChronik.isError && (
        <div className="ein-status is-error" style={{ marginTop: 8 }}>
          Speichern fehlgeschlagen — bitte erneut versuchen.
        </div>
      )}
    </section>
  );
}
