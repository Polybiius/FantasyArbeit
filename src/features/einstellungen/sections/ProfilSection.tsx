import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect } from 'react';
import { useForm } from 'react-hook-form';

import { useOwnProfileQuery, useUpdateOwnProfileMutation } from '../api';
import { profilFormSchema, type ProfilFormValues } from '../schema';

export function ProfilSection() {
  const { data: profile } = useOwnProfileQuery();
  const updateProfil = useUpdateOwnProfileMutation();

  const form = useForm<ProfilFormValues>({
    resolver: zodResolver(profilFormSchema),
    defaultValues: { real_name: '', company: '' },
  });
  const { reset } = form;

  useEffect(() => {
    if (profile) reset({ real_name: profile.real_name ?? '', company: profile.company ?? '' });
  }, [profile, reset]);

  if (!profile) return null;

  const onSubmit = form.handleSubmit((values) => {
    updateProfil.mutate({ real_name: values.real_name, company: values.company });
  });

  return (
    <section className="ein-card">
      <h2>👤 Profil</h2>
      <form onSubmit={(e) => void onSubmit(e)} style={{ display: 'grid', gap: 12 }}>
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
        {updateProfil.isError && (
          <span className="ein-status is-error">Speichern fehlgeschlagen — bitte erneut versuchen.</span>
        )}
      </form>
    </section>
  );
}
