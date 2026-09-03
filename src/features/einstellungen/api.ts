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
 * den React-Query-Cache als auch -- über die einzige erlaubte Ausnahme in
 * ADR-0002 -- das im Vanilla-Code lebende `profile`-Objekt.
 *
 * **Unabhängiger Review (2026-09-03) fand zwei echte Bugs hier, beide
 * behoben:**
 * 1. `setQueryData(key, data)` ersetzte die GESAMTE gecachte Zeile durch
 *    die Antwort dieser einen Mutation. Laufen zwei Mutationen auf
 *    verschiedenen Feldern (z.B. beide Kalender-Toggles) knapp
 *    hintereinander, kann die zuletzt VERARBEITETE (nicht: zuletzt
 *    gesendete) Antwort die andere, bereits bestätigte Änderung wieder
 *    aus dem Cache verdrängen -- ein Race, das die Anzeige kurzzeitig
 *    falsch zeigt (die DB selbst bleibt korrekt). Fix: nur die Felder
 *    mergen, die dieser Aufruf tatsächlich geändert hat
 *    (`confirmedFields`), nie die volle Zeile überschreiben.
 * 2. `notifyProfilePatch(patch)` bekam den ANGEFRAGTEN (noch nicht vom
 *    Server bestätigten) Wert, obwohl die eigene Doku in bridge.ts einen
 *    bereits bestätigten Patch verspricht. Fix: dieselben
 *    `confirmedFields` (aus `data`, nicht `patch`) auch hier -- engt den
 *    Seiteneffekt-Bereich nicht aus (gleiche Schlüsselmenge wie `patch`),
 *    liefert aber echte Server-Werte.
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
      const confirmedFields = Object.fromEntries(
        Object.keys(patch).map((key) => [key, (data as Record<string, unknown>)[key]]),
      ) as Partial<Profile>;
      queryClient.setQueryData<Profile>(qk.einstellungen.self(), (old) => (old ? { ...old, ...confirmedFields } : data));
      getBridge().notifyProfilePatch(confirmedFields);
    },
  });
}
