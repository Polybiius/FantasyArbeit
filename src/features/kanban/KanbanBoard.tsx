import { useState, type ReactNode } from 'react';
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
import { useKanbanBoardQuery, type KanbanBoardColumns, type KanbanContact } from './kanbanApi';
import { decideKanbanTransition, KANBAN_STAGES, type KanbanStage } from './kanbanTransitions';

/**
 * VORSCHAU-STAND (Block 5, erster UI-Baustein) — bewusst noch KEIN
 * Schreibzugriff. Ziehen prüft den Zug gegen die echte Zustandsmaschine
 * (`decideKanbanTransition`, docs/adr/0007) und verschiebt die Karte nur
 * LOKAL (React-State, kein `contacts`-Update, kein `log_action_for_self`).
 *
 * Grund für den bewussten Stopp genau hier: ein echter Schreibvorgang
 * würde XP/Energie ändern, aber die Brücke (docs/adr/0002) hat aktuell
 * KEINEN Weg, den Vanilla-Header danach zur Neuberechnung zu bewegen --
 * `useCharacterStats()` liest nur, was Vanillas eigener `render()`-Lauf
 * zuletzt berechnet hat (`onStatsChange` feuert ausschließlich NACH
 * einem Vanilla-`render()`). Ein React-Kartenzug, der `action_log`
 * direkt beschreibt, würde die Anzeige also bis zum nächsten Vanilla-
 * Render (z.B. Seitenwechsel) veraltet stehen lassen -- ein echter,
 * sichtbarer Bug. Bevor der eigentliche Schreibpfad drankommt, muss das
 * geklärt sein (vermutlich eine neue, kleine Bridge-Ausnahme analog zu
 * `notifyProfilePatch`) -- absichtlich noch nicht selbst entschieden.
 *
 * Wegen der fehlenden Energie-/Trichter-Daten (noch kein `action_log`
 * geladen) läuft die Zug-Prüfung mit einem bewusst DURCHLÄSSIGEN Kontext
 * (unbegrenzte Energie, keine Trichter-Duplikate) -- sie greift trotzdem
 * für die einzige rein herkunftsbezogene Regel ("Nicht erschienen" nur
 * vom Ersttermin/Zweittermin aus), die von Live-Daten unabhängig ist.
 */
const PREVIEW_TRANSITION_CONTEXT_BASE = {
  energyRemaining: Number.POSITIVE_INFINITY,
  actionEnergyCost: () => 0,
  hasFunnelMarkerThisYear: () => false,
};

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

/**
 * `currentStage` ist die ANGEZEIGTE Spalte (der äußere Schleifen-Index in
 * `KanbanBoard`, der über `displayColumns` iteriert) -- bewusst NICHT
 * `contact.kanban_stage` (das serverseitige, noch unveränderte Feld).
 * Fund einer unabhängigen Zweitmeinung: nach einer ersten, rein lokalen
 * Verschiebung (siehe `localOverride`) bliebe `contact.kanban_stage`
 * stehen, ein zweiter Zug derselben Karte würde dann fälschlich gegen
 * ihre ursprüngliche statt ihre gerade sichtbare Spalte geprüft.
 */
function DraggableCard({ contact, currentStage }: { contact: KanbanContact; currentStage: KanbanStage }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: contact.id,
    data: { stage: currentStage },
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
  // Rein lokale Vorschau-Verschiebung, siehe Dateikopf-Kommentar --
  // überschreibt `columns` nur für die Anzeige, kein Persistieren.
  const [localOverride, setLocalOverride] = useState<Record<string, KanbanStage>>({});
  const [rejection, setRejection] = useState<string | null>(null);

  function handleDragStart() {
    setRejection(null);
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over) return;
    const fromStage = (active.data.current?.stage as KanbanStage | undefined) ?? null;
    const toStage = over.id as KanbanStage;
    if (!fromStage || fromStage === toStage) return;

    const plan = decideKanbanTransition(fromStage, toStage, {
      ...PREVIEW_TRANSITION_CONTEXT_BASE,
      isKunde: findContact(columns, String(active.id))?.status === 'kunde',
    });
    if (!plan.allowed) {
      setRejection(plan.rejectionReason);
      return;
    }
    setLocalOverride((prev) => ({ ...prev, [String(active.id)]: toStage }));
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

  const displayColumns = applyLocalOverride(columns, localOverride);

  return (
    <div className="tw:flex tw:flex-col tw:gap-3">
      {rejection && (
        <div className="tw:rounded-sm tw:border tw:border-danger tw:bg-danger/10 tw:px-3 tw:py-2 tw:text-xs tw:text-danger">
          {rejection}
        </div>
      )}
      <div className="tw:rounded-sm tw:border tw:border-arcane tw:bg-arcane-glow/10 tw:px-3 tw:py-2 tw:text-xs tw:text-muted">
        Vorschau — Ziehen wird geprüft, aber noch nicht gespeichert (nächster Bauschritt).
      </div>
      <DndContext sensors={sensors} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
        <div className="tw:flex tw:gap-3 tw:overflow-x-auto tw:pb-2">
          {KANBAN_STAGES.map((stage) => (
            <DroppableColumn key={stage} stage={stage} count={displayColumns[stage].length}>
              {displayColumns[stage].map((contact) => (
                <DraggableCard key={contact.id} contact={contact} currentStage={stage} />
              ))}
            </DroppableColumn>
          ))}
        </div>
      </DndContext>
    </div>
  );
}

function findContact(columns: KanbanBoardColumns | undefined, id: string): KanbanContact | undefined {
  if (!columns) return undefined;
  for (const stage of KANBAN_STAGES) {
    const found = columns[stage].find((c) => c.id === id);
    if (found) return found;
  }
  return undefined;
}

function applyLocalOverride(
  columns: KanbanBoardColumns,
  overrides: Record<string, KanbanStage>,
): KanbanBoardColumns {
  if (Object.keys(overrides).length === 0) return columns;
  const next = {} as KanbanBoardColumns;
  for (const stage of KANBAN_STAGES) next[stage] = [];
  for (const stage of KANBAN_STAGES) {
    for (const contact of columns[stage]) {
      const overriddenStage = overrides[contact.id] ?? stage;
      next[overriddenStage].push(contact);
    }
  }
  return next;
}
