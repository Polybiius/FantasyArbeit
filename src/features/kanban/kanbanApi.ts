import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';

import { getBridge, sb } from '@/shared/lib/bridge';
import { qk } from '@/shared/lib/queryKeys';

import { KANBAN_STAGES, type KanbanStage } from './kanbanTransitions';

/**
 * Laufzeit-Vertrag für die Kanban-Lesegrenze (docs/adr/0011) — deckt nur
 * genau die Felder ab, die das Board tatsächlich braucht (keine
 * 1:1-Kopie der ganzen `contacts`-Tabelle). `kanban_stage` wird über
 * `z.enum(KANBAN_STAGES)` geprüft, weil die Abfrage unten `.not(
 * 'kanban_stage', 'is', null)` filtert -- ein `null` an dieser Stelle
 * wäre bereits ein Zeichen für Schema-/Abfrage-Drift, kein normaler Fall.
 */
const kanbanContactSchema = z.object({
  id: z.string(),
  name: z.string().nullable(),
  vorname: z.string(),
  nachname: z.string(),
  status: z.string(),
  updated_at: z.string(),
  kanban_stage: z.enum(KANBAN_STAGES),
  location_id: z.string().nullable(),
  locations: z.object({ name: z.string() }).nullable(),
});

export type KanbanContact = z.infer<typeof kanbanContactSchema>;

export type KanbanBoardColumns = Record<KanbanStage, KanbanContact[]>;

function emptyColumns(): KanbanBoardColumns {
  const cols = {} as KanbanBoardColumns;
  for (const stage of KANBAN_STAGES) cols[stage] = [];
  return cols;
}

/**
 * Lädt die eigene Kanban-Pipe. Bewusst zwei Filter, nicht nur einer:
 * `.not('kanban_stage','is',null)` (nur Kontakte, die überhaupt im
 * Board stehen -- CLAUDE.md "NULL = kein Kanban-Kontakt") UND
 * `.eq('owner_id', ownerId)` (Kanban ist strikt die eigene Pipe, RLS
 * allein würde auch gilden-geteilte Kontakte durchlassen, siehe CLAUDE.md
 * "Kanban ist strikt die eigene Vertriebspipe, kein Gilden-Blick" --
 * `renderKanbanBoard()` im Vanilla-Code filtert aus genau demselben
 * Grund zusätzlich clientseitig).
 *
 * **Noch nicht Teil dieses Ausbauschritts:** die geteilten,
 * schreibgeschützten Karten aus angenommenen Termin-Einladungen
 * (`.kanban-card-shared` im Vanilla-Original) -- eigener, unabhängiger
 * Datenpfad (`termin_invitations`), kommt mit einem späteren Schritt.
 */
async function fetchOwnKanbanContacts(ownerId: string): Promise<KanbanBoardColumns> {
  const { data, error } = await sb()
    .from('contacts')
    .select('id,name,vorname,nachname,status,updated_at,kanban_stage,location_id,locations(name)')
    .eq('owner_id', ownerId)
    .not('kanban_stage', 'is', null);
  if (error) throw error;

  const columns = emptyColumns();
  for (const raw of data) {
    const parsed = kanbanContactSchema.parse(raw);
    columns[parsed.kanban_stage].push(parsed);
  }
  return columns;
}

export function useKanbanBoardQuery() {
  const profile = getBridge().getProfile();
  const ownerId = profile?.id ?? '';
  return useQuery({
    queryKey: qk.kanban.board(ownerId),
    queryFn: () => fetchOwnKanbanContacts(ownerId),
    enabled: ownerId !== '',
  });
}
