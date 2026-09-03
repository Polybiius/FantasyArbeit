import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect } from 'react';
import { useForm } from 'react-hook-form';

import { useOwnProfileQuery, useUpdateOwnProfileMutation } from './api';
import './EinstellungenPage.css';
import { profilFormSchema, type ProfilFormValues } from './schema';

/**
 * Block-3-Pilot (docs/migration-status.md). Deckt bisher zwei der vier
 * Einstellungs-Gruppen ab -- Profil (Text-Felder, Speichern-Button) und
 * Kontakt-Chronik (ein Toggle, sofortiges Speichern) -- weil sie zusammen
 * beide Speicher-Muster aus SETTINGS_REGISTRY testen. Provision &
 * Planungsziele, Kalender (inkl. der beiden Sonder-Widgets Zeitzone/
 * Arbeitszeiten) und die Suche folgen als eigener Schritt, siehe
 * README.md. Danger Zone bleibt unverändert Vanilla (index.html,
 * `leaveOrgBtn`/`deleteAccountBtn`).
 */
export function EinstellungenPage() {
  const { data: profile, isLoading, isError: profileLoadError } = useOwnProfileQuery();
  const updateProfil = useUpdateOwnProfileMutation();
  const updateChronik = useUpdateOwnProfileMutation();

  const form = useForm<ProfilFormValues>({
    resolver: zodResolver(profilFormSchema),
    defaultValues: { real_name: '', company: '' },
  });
  const { reset } = form;

  useEffect(() => {
    if (profile) reset({ real_name: profile.real_name ?? '', company: profile.company ?? '' });
  }, [profile, reset]);

  if (isLoading) return <p>Lädt …</p>;
  if (profileLoadError || !profile) return <p>Profil konnte nicht geladen werden.</p>;

  const onSubmitProfil = form.handleSubmit((values) => {
    updateProfil.mutate({ real_name: values.real_name, company: values.company });
  });

  const chronikChecked = profile.chronik_show_xp;

  return (
    <div className="ein-wrap">
      <div className="ein-pilot-note">
        🚧 React-Pilot (Block 3) — nur „Profil" und „Kontakt-Chronik" sind
        schon umgebaut. Provision/Planungsziele, Kalender (Zeitzone,
        Arbeitszeiten) und die Suche kommen im nächsten Schritt. „Organisation
        verlassen" / „Account löschen" unten sind unverändert.
      </div>

      <section className="ein-card">
        <h2>👤 Profil</h2>
        <form onSubmit={(e) => void onSubmitProfil(e)} style={{ display: 'grid', gap: 12 }}>
          <label className="ein-field">
            Echter Name
            <input
              {...form.register('real_name')}
              className="ein-input"
              maxLength={60}
              placeholder="Dein Name"
              autoComplete="off"
            />
            {form.formState.errors.real_name && (
              <span className="ein-error">{form.formState.errors.real_name.message}</span>
            )}
          </label>
          <label className="ein-field">
            Unternehmen
            <input
              {...form.register('company')}
              className="ein-input"
              maxLength={80}
              placeholder="Unternehmen (optional)"
              autoComplete="off"
            />
            {form.formState.errors.company && (
              <span className="ein-error">{form.formState.errors.company.message}</span>
            )}
          </label>
          <button type="submit" className="ein-btn" disabled={updateProfil.isPending || !form.formState.isDirty}>
            {updateProfil.isPending ? 'Speichert …' : 'Speichern'}
          </button>
          {updateProfil.isSuccess && !form.formState.isDirty && <span className="ein-status">Gespeichert.</span>}
          {updateProfil.isError && <span className="ein-status is-error">Speichern fehlgeschlagen — bitte erneut versuchen.</span>}
        </form>
      </section>

      <section className="ein-card">
        <h2>📖 Kontakt-Chronik</h2>
        <label className="ein-toggle-row">
          <input
            type="checkbox"
            checked={chronikChecked}
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
    </div>
  );
}
