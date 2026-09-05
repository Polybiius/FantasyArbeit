import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';

import { sb } from '@/shared/lib/bridge';
import { qk } from '@/shared/lib/queryKeys';

/**
 * Laufzeit-Vertrag für GENAU den Teil von `rule_configs.config`, den der
 * Kanban-Schreibpfad braucht (docs/adr/0011) — Energiekosten je Aktion,
 * für die `decideKanbanTransition()`-Prüfung (`kanbanTransitions.ts`).
 * `config` trägt noch viele weitere Schlüssel (skills, levelBase,
 * recurringQuests, ...) — `z.object()` ohne `.strict()` lässt unbekannte
 * Schlüssel beim Parsen einfach unangetastet durchfallen, es wird
 * bewusst NICHT die ganze Konfiguration abgebildet.
 */
const ruleConfigActionsSchema = z.object({
  actions: z.record(
    z.string(),
    z.object({
      energy: z.number(),
      xp: z.number(),
      label: z.string(),
    }),
  ),
});

export type KanbanActionCosts = Record<string, { energy: number; xp: number; label: string }>;

/**
 * Lädt die Energiekosten je Aktion aus dem Regelwerk der eigenen
 * Organisation — dieselbe Quelle, die Vanillas `config.actions[key]`
 * beim Login lädt (`index.html`, `sb.from('rule_configs')...`).
 */
export async function fetchOrgActionCosts(orgId: string): Promise<KanbanActionCosts> {
  const { data, error } = await sb().from('rule_configs').select('config').eq('org_id', orgId).maybeSingle();
  if (error) throw error;
  if (!data) throw new Error('Kein Regelwerk für diese Organisation gefunden.');
  return ruleConfigActionsSchema.parse(data.config).actions;
}

/**
 * Reaktive Fassung von `fetchOrgActionCosts()` für UI-Code (z.B.
 * `KanbanExtraActionModal.tsx`, das XP/Energie je Zusatzaktion anzeigt)
 * — **gleicher Query-Key** wie `useMoveKanbanCardMutation()`s
 * `queryClient.fetchQuery()`-Aufruf, teilt sich also denselben Cache.
 */
export function useOrgActionCostsQuery(orgId: string | undefined) {
  return useQuery({
    queryKey: qk.kanban.actionCosts(orgId ?? ''),
    queryFn: () => fetchOrgActionCosts(orgId!),
    enabled: orgId != null,
    staleTime: 5 * 60_000,
  });
}
