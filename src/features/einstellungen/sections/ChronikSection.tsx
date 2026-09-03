import { useOwnProfileQuery, useUpdateOwnProfileMutation } from '../api';

export function ChronikSection() {
  const { data: profile } = useOwnProfileQuery();
  const updateChronik = useUpdateOwnProfileMutation();

  if (!profile) return null;
  const checked = profile.chronik_show_xp;

  return (
    <section className="ein-card">
      <h2>📖 Kontakt-Chronik</h2>
      <label className="ein-toggle-row">
        <input
          type="checkbox"
          checked={checked}
          disabled={updateChronik.isPending}
          onChange={(e) => updateChronik.mutate({ chronik_show_xp: e.target.checked })}
        />
        <span>
          XP-Werte anzeigen
          <div className="ein-toggle-desc">
            Zeigt XP-Zahlen zusätzlich zu den CRM-Fakten in der Kontakt-Chronik.
          </div>
        </span>
      </label>
      {updateChronik.isError && (
        <div className="ein-status is-error" style={{ marginTop: 8 }}>
          Speichern fehlgeschlagen — bitte erneut versuchen.
        </div>
      )}
    </section>
  );
}
