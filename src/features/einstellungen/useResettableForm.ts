import { useEffect, useRef } from 'react';
import { useForm, type DefaultValues, type FieldValues, type UseFormProps, type UseFormReturn } from 'react-hook-form';

/**
 * RHF-Formular, das seine `defaultValues` EINMAL setzt, sobald `source`
 * (das Profil) zum ersten Mal verfügbar ist -- NICHT bei jeder späteren
 * Änderung von `source`.
 *
 * **Behebt einen echten, vom unabhängigen Review bestätigten Bug
 * (2026-09-03):** `ProfilSection`/`ProvisionSection` hatten ursprünglich
 * `useEffect(() => reset(...), [profile, reset])` -- weil alle vier
 * Einstellungen-Sektionen denselben Query-Key (`qk.einstellungen.self()`)
 * teilen, bekommt `profile` bei JEDER erfolgreichen Mutation IRGENDEINER
 * Sektion eine neue Objekt-Referenz. Das feuerte den Reset auch dann,
 * wenn z.B. nur ein Kalender-Toggle gespeichert wurde -- und löschte
 * dabei still ungespeicherte Eingaben im Profil-/Provisions-Formular.
 *
 * Der EIGENE erfolgreiche Speichervorgang ruft `form.reset(...)` selbst
 * auf (mit dem vom Server bestätigten Stand, siehe die Sektionen), nicht
 * dieser Hook -- der deckt nur die initiale Befüllung ab.
 */
export function useResettableForm<TFieldValues extends FieldValues, TSource>(
  source: TSource | undefined,
  toDefaults: (source: TSource) => DefaultValues<TFieldValues>,
  // `options.defaultValues` bleibt erlaubt -- das ist der Platzhalter-
  // Zustand, bevor `source` zum ersten Mal ankommt (praktisch nie
  // sichtbar dank `initialData` aus der Bridge, aber RHF braucht trotzdem
  // einen Startwert, sonst kippt ein Input von unkontrolliert auf
  // kontrolliert um, sobald `reset()` greift).
  options?: UseFormProps<TFieldValues>,
): UseFormReturn<TFieldValues> {
  const form = useForm<TFieldValues>(options);
  const initialized = useRef(false);
  const { reset } = form;

  useEffect(() => {
    if (source && !initialized.current) {
      reset(toDefaults(source));
      initialized.current = true;
    }
  }, [source, reset, toDefaults]);

  return form;
}
