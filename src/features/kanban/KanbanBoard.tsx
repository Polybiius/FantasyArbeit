import type { ReactNode } from 'react';
import {
  DndContext,
  KeyboardSensor,
  PointerSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core';
import { CSS } from '@dnd-kit/utilities';

import { ContactCard } from '@/shared/domain/contactCard/ContactCard';

import { KANBAN_STAGE_META } from './kanbanLabels';
import { useKanbanBoardQuery, type KanbanContact } from './kanbanApi';
import { useMoveKanbanCardMutation } from './kanbanMutations';
import { KANBAN_STAGES, type KanbanStage } from './kanbanTransitions';

/**
 * Echter Schreibpfad seit diesem Baustein (Block 5) — siehe
 * `kanbanMutations.ts` für den vollen Ablauf (Sperr-geprüfte
 * Spaltenänderung, dann `log_action_for_self` für Hauptaktion+
 * Trichter-Marken, dann `notifyActionLogged()` an die Brücke, damit
 * Vanillas XP-/Energie-Anzeige synchron bleibt — `docs/adr/0002`).
 *
 * Bewusst KEIN optimistisches lokales Verschieben (Projekt-Konvention,
 * siehe `queryClient.ts`: naive optimistische Updates würden der
 * serverseitigen Sperrlogik vorgreifen) — die Karte springt erst nach
 * bestätigtem Server-Erfolg in die neue Spalte (`onSuccess` invalidiert
 * die Board-Abfrage). Während des Speicherns ist das Board per
 * `aria-busy` markiert, ein zweiter Zug wird ignoriert statt eine
 * parallele Mutation zu starten.
 *
 * **Noch nicht Teil dieses Bausteins:** "Gewonnen"/"Verloren" (brauchen
 * ein Verkaufs-Popup, siehe `kanbanMutations.ts`-Kommentar) und die
 * geteilten, schreibgeschützten Karten aus Termin-Einladungen.
 */
function DroppableColumn({
  stage,
  count,
  children,
}: {
  stage: KanbanStage;
  count: number;
  children: ReactNode;
}) {
  const { setNodeRef, isOver } = useDroppable({ id: stage });
  const meta = KANBAN_STAGE_META[stage];
  return (
    <div
      ref={setNodeRef}
      className={`tw:flex tw:w-64 tw:flex-none tw:flex-col tw:gap-2 tw:rounded-md tw:border tw:p-2 ${
        isOver ? 'tw:border-arcane tw:bg-arcane-glow/10' : 'tw:border-border tw:bg-panel-2'
      }`}
    >
      <div className="tw:flex tw:items-center tw:justify-between tw:px-1 tw:text-xs tw:font-semibold tw:text-muted">
        <span>
          {meta.icon} {meta.label}
        </span>
        <span className="tw:font-mono-brand tw:text-muted-2">{count}</span>
      </div>
      <div className="tw:flex tw:min-h-16 tw:flex-col tw:gap-2">{children}</div>
    </div>
  );
}

function DraggableCard({ contact, disabled }: { contact: KanbanContact; disabled: boolean }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: contact.id,
    data: { stage: contact.kanban_stage },
    disabled,
  });
  return (
    <ContactCard
      variant="kanban"
      contact={{
        id: contact.id,
        name: contact.name,
        vorname: contact.vorname,
        nachname: contact.nachname,
        locationName: contact.locations?.name ?? null,
      }}
      isDragging={isDragging}
      rootProps={{
        ref: setNodeRef,
        style: { transform: CSS.Translate.toString(transform) },
        ...attributes,
        ...listeners,
      }}
    />
  );
}

export function KanbanBoard() {
  const { data: columns, isLoading, error } = useKanbanBoardQuery();
  const moveMutation = useMoveKanbanCardMutation();

  function handleDragStart() {
    moveMutation.reset();
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || moveMutation.isPending) return;
    const contact = findContact(columns, String(active.id));
    const toStage = over.id as KanbanStage;
    if (!contact || contact.kanban_stage === toStage) return;
    moveMutation.mutate({ contact, toStage });
  }

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor),
  );

  if (isLoading) {
    return <div className="tw:animate-pulse tw:text-sm tw:text-muted">Lade Kanban-Board …</div>;
  }
  if (error || !columns) {
    return <div className="tw:text-sm tw:text-danger">Kanban-Board konnte nicht geladen werden.</div>;
  }

  return (
    <div className="tw:flex tw:flex-col tw:gap-3" aria-busy={moveMutation.isPending}>
      {moveMutation.error && (
        <div className="tw:rounded-sm tw:border tw:border-danger tw:bg-danger/10 tw:px-3 tw:py-2 tw:text-xs tw:text-danger">
          {moveMutation.error.message}
        </div>
      )}
      <DndContext sensors={sensors} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
        <div className="tw:flex tw:gap-3 tw:overflow-x-auto tw:pb-2">
          {KANBAN_STAGES.map((stage) => (
            <DroppableColumn key={stage} stage={stage} count={columns[stage].length}>
              {columns[stage].map((contact) => (
                <DraggableCard key={contact.id} contact={contact} disabled={moveMutation.isPending} />
              ))}
            </DroppableColumn>
          ))}
        </div>
      </DndContext>
    </div>
  );
}

function findContact(columns: ReturnType<typeof useKanbanBoardQuery>['data'], id: string): KanbanContact | undefined {
  if (!columns) return undefined;
  for (const stage of KANBAN_STAGES) {
    const found = columns[stage].find((c) => c.id === id);
    if (found) return found;
  }
  return undefined;
}
