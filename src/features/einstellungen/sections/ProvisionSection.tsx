import { useEffect } from 'react';
import { useForm } from 'react-hook-form';

import type { Profile } from '@/shared/lib/bridge';

import { useOwnProfileQuery, useUpdateOwnProfileMutation } from '../api';
import {
  decimalValidate,
  displayGermanDecimal,
  displayPlainNumber,
  numberValidate,
  parseGermanDecimal,
  parsePlainNumber,
} from '../numberFields';

interface ProvisionFormValues {
  taetig_seit_jahr: string;
  lv_prozent_satz: string;
  kv_mb_satz: string;
  pma_suh_satz: string;
  pma_kv_satz: string;
  planung_lv_bws: string;
  planung_kv_mb: string;
  planung_bwp: string;
}

function toDefaults(profile: Profile): ProvisionFormValues {
  return {
    taetig_seit_jahr: displayPlainNumber(profile.taetig_seit_jahr),
    lv_prozent_satz: displayGermanDecimal(profile.lv_prozent_satz),
    kv_mb_satz: displayPlainNumber(profile.kv_mb_satz),
    pma_suh_satz: displayPlainNumber(profile.pma_suh_satz),
    pma_kv_satz: displayPlainNumber(profile.pma_kv_satz),
    planung_lv_bws: displayPlainNumber(profile.planung_lv_bws),
    planung_kv_mb: displayPlainNumber(profile.planung_kv_mb),
    planung_bwp: displayPlainNumber(profile.planung_bwp),
  };
}

/**
 * Bewusst ohne Zod-Resolver (anders als ProfilSection) -- die Felder sind
 * reine optionale Zahlen ohne Wertebereichs-Vorgabe (SETTINGS_REGISTRY
 * kannte auch in Vanilla keine), RHFs eingebautes `validate` reicht dafür
 * ohne zusätzliches Schema.
 */
export function ProvisionSection() {
  const { data: profile } = useOwnProfileQuery();
  const updateProvision = useUpdateOwnProfileMutation();
  const form = useForm<ProvisionFormValues>({
    defaultValues: { taetig_seit_jahr: '', lv_prozent_satz: '', kv_mb_satz: '', pma_suh_satz: '', pma_kv_satz: '', planung_lv_bws: '', planung_kv_mb: '', planung_bwp: '' },
  });
  const { reset, register, formState } = form;

  useEffect(() => {
    if (profile) reset(toDefaults(profile));
  }, [profile, reset]);

  if (!profile) return null;

  const onSubmit = form.handleSubmit((values) => {
    updateProvision.mutate({
      taetig_seit_jahr: parsePlainNumber(values.taetig_seit_jahr),
      lv_prozent_satz: parseGermanDecimal(values.lv_prozent_satz),
      kv_mb_satz: parsePlainNumber(values.kv_mb_satz),
      pma_suh_satz: parsePlainNumber(values.pma_suh_satz),
      pma_kv_satz: parsePlainNumber(values.pma_kv_satz),
      planung_lv_bws: parsePlainNumber(values.planung_lv_bws),
      planung_kv_mb: parsePlainNumber(values.planung_kv_mb),
      planung_bwp: parsePlainNumber(values.planung_bwp),
    });
  });

  return (
    <section className="ein-card">
      <h2>📊 Provision &amp; Planungsziele</h2>
      <form onSubmit={(e) => void onSubmit(e)} style={{ display: 'grid', gap: 12 }}>
        <h3 className="ein-subheading">Rechnungsgrundlage</h3>
        <p className="ein-hint">Aktuelles Jahr: {new Date().getFullYear()} (automatisch erkannt, kein Eingabefeld).</p>
        <label className="ein-field">
          Tätig seit (Jahr)
          <input {...register('taetig_seit_jahr', { validate: numberValidate })} type="number" step="1" className="ein-input" placeholder="z.B. 2020" />
          {formState.errors.taetig_seit_jahr && <span className="ein-error">{formState.errors.taetig_seit_jahr.message}</span>}
        </label>

        <h3 className="ein-subheading">Individuelle Provision</h3>
        <p className="ein-hint">Nur bei Leben/Kranken/PMA relevant — andere Sparten nutzen den festen Faktor am Produkt.</p>
        <label className="ein-field">
          Leben-Satz (%)
          <input {...register('lv_prozent_satz', { validate: decimalValidate })} type="text" inputMode="decimal" className="ein-input" placeholder="z.B. 2,5" />
          {formState.errors.lv_prozent_satz && <span className="ein-error">{formState.errors.lv_prozent_satz.message}</span>}
        </label>
        <label className="ein-field">
          Kranken-MB-Satz
          <input {...register('kv_mb_satz', { validate: numberValidate })} type="number" step="0.001" className="ein-input" placeholder="z.B. 6" />
          {formState.errors.kv_mb_satz && <span className="ein-error">{formState.errors.kv_mb_satz.message}</span>}
        </label>
        <label className="ein-field">
          Provision PMA SUH
          <input {...register('pma_suh_satz', { validate: numberValidate })} type="number" step="0.001" className="ein-input" placeholder="z.B. 0.05" />
          {formState.errors.pma_suh_satz && <span className="ein-error">{formState.errors.pma_suh_satz.message}</span>}
        </label>
        <label className="ein-field">
          Provision PMA KV
          <input {...register('pma_kv_satz', { validate: numberValidate })} type="number" step="0.001" className="ein-input" placeholder="z.B. 0.282" />
          {formState.errors.pma_kv_satz && <span className="ein-error">{formState.errors.pma_kv_satz.message}</span>}
        </label>

        <h3 className="ein-subheading">Persönliche Planungsziele</h3>
        <p className="ein-hint">Deine eigenen Jahresziele — daraus berechnet das Kompendium später deinen Zielerreichungsgrad.</p>
        <label className="ein-field">
          Planung Leben-BWS
          <input {...register('planung_lv_bws', { validate: numberValidate })} type="number" step="0.01" className="ein-input" placeholder="Ziel-Bewertungssumme Leben" />
          {formState.errors.planung_lv_bws && <span className="ein-error">{formState.errors.planung_lv_bws.message}</span>}
        </label>
        <label className="ein-field">
          Planung Kranken-Beitrag
          <input {...register('planung_kv_mb', { validate: numberValidate })} type="number" step="0.01" className="ein-input" placeholder="Ziel-Bewertungsbeitrag Kranken" />
          {formState.errors.planung_kv_mb && <span className="ein-error">{formState.errors.planung_kv_mb.message}</span>}
        </label>
        <label className="ein-field">
          Planung Bewertungspunkte
          <input {...register('planung_bwp', { validate: numberValidate })} type="number" step="0.01" className="ein-input" placeholder="Ziel-Bewertungspunkte" />
          {formState.errors.planung_bwp && <span className="ein-error">{formState.errors.planung_bwp.message}</span>}
        </label>

        <button type="submit" className="ein-btn" disabled={updateProvision.isPending || !formState.isDirty}>
          {updateProvision.isPending ? 'Speichert …' : 'Speichern'}
        </button>
        {updateProvision.isSuccess && !formState.isDirty && <span className="ein-status">Gespeichert.</span>}
        {updateProvision.isError && (
          <span className="ein-status is-error">Speichern fehlgeschlagen — bitte erneut versuchen.</span>
        )}
      </form>
    </section>
  );
}
