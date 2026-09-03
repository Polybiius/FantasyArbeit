import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { getBridge, sb, type Profile } from '@/shared/lib/bridge';
import { qk } from '@/shared/lib/queryKeys';

/**
 * `profiles` ist bewusst NICHT Teil der Locked-Update-RPCs
 * (`src/shared/lib/lockedUpdate.ts`) -- genau wie im Vanilla-Code kann
 * strukturell nur eine Person je Profilzeile schreiben, ein direktes
 * `update()` ist hier korrekt (siehe CLAUDE.md, Abschnitt "Konflikt-Schutz
 * bei gleichzeitiger Bearbeitung").
 */
async function fetchOwnProfile(): Promise<Profile> {
  const session = getBridge().getSession();
  if (!session) throw new Error('Keine Session -- Profil kann nicht geladen werden.');
  const { data, error } = await sb().from('profiles').select('*').eq('id', session.user.id).single();
  if (error) throw error;
  return data;
}

/**
 * Liest das eigene Profil. `initialData` aus der Brücke (der Vanilla-Code
 * hat es beim Login längst geladen) sorgt für sofortige Anzeige ohne
 * Lade-Zustand -- ein `refetch` läuft trotzdem im Hintergrund (React
 * Query behandelt `initialData` wie jeden anderen Cache-Eintrag,
 * `staleTime` aus queryClient.ts gilt normal).
 */
export function useOwnProfileQuery() {
  const bridgeProfile = getBridge().getProfile();
  return useQuery({
    queryKey: qk.einstellungen.self(),
    queryFn: fetchOwnProfile,
    initialData: bridgeProfile ? ({ ...bridgeProfile } satisfies Profile) : undefined,
  });
}

/**
 * Schreibt einen Patch aufs eigene Profil. Aktualisiert nach Erfolg sowohl
 * den React-Query-Cache (mit der vom Server zurückgegebenen, bestätigten
 * Zeile) als auch -- über die einzige erlaubte Ausnahme in ADR-0002 -- das
 * im Vanilla-Code lebende `profile`-Objekt, damit beide Hälften
 * synchron bleiben.
 */
export function useUpdateOwnProfileMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: qk.einstellungen.self(),
    mutationFn: async (patch: Partial<Profile>): Promise<Profile> => {
      const session = getBridge().getSession();
      if (!session) throw new Error('Keine Session -- Einstellung kann nicht gespeichert werden.');
      const { data, error } = await sb()
        .from('profiles')
        .update(patch)
        .eq('id', session.user.id)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: (data, patch) => {
      queryClient.setQueryData(qk.einstellungen.self(), data);
      getBridge().notifyProfilePatch(patch);
    },
  });
}
