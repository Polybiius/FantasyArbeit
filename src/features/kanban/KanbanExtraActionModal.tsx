import { useState } from 'react';

import { getBridge } from '@/shared/lib/bridge';
import { logSilentError } from '@/shared/lib/errorLog';
import { toError } from '@/shared/lib/toError';
import { useBusyGuard } from '@/shared/hooks/useBusyGuard';
import { useCharacterStats } from '@/shared/hooks/useCharacterStats';
import { Modal } from '@/shared/ui/Modal';

import { contactDisplayName } from '@/shared/domain/contactCard/contactDisplay';
import { logAndNotify } from './kanbanActionLog';
import type { KanbanContact } from './kanbanApi';
import type { KanbanExtraActionOption } from './kanbanLabels';
import { useOrgActionCostsQuery } from './kanbanRuleConfig';

export interface KanbanExtraActionModalProps {
  contact: KanbanContact;
  options: readonly KanbanExtraActionOption[];
  /** Löst immer auf, unabhängig davon, ob eine Zusatzaktion gewählt wurde — 1:1 zu `offerExtraAction()`, das ebenfalls keinen Wert zurückgibt. */
  onResolve: () => void;
}

function fmtXp(xp: number): string {
  return xp >= 0 ? `+${xp}` : `${xp}`;
}

/**
 * 1:1-Portierung von `offerExtraAction()` (`index.html`) — ein kleines
 * Popup mit optionalen Zusatzaktionen (Bedarfsanalyse bei Angebot/
 * Zweittermin, vier Optionen bei Dauerbrenner). "✕" oder ein Klick
 * daneben loggt bewusst nichts. Buttons zeigen XP/Energie aus dem
 * Regelwerk (wie die übrige Aktionsleiste) und sind gesperrt, wenn die
 * Tagesenergie für genau diese Aktion nicht mehr reicht
 * (`refreshActionGridEnergyState()`-Entsprechung im echten Code) — ODER
 * solange das Regelwerk selbst noch lädt (`costsLoading`, Fund einer
 * unabhängigen Zweitmeinung: ohne diese Sperre war `cost` kurz
 * `undefined` und die Energie-Prüfung griff in diesem Zeitfenster gar
 * nicht, ein eigentlich zu teurer Klick kam durch).
 */
export function KanbanExtraActionModal({ contact, options, onResolve }: KanbanExtraActionModalProps) {
  const profile = getBridge().getProfile();
  const { data: actionCosts, isLoading: costsLoading } = useOrgActionCostsQuery(profile?.org_id ?? undefined);
  const stats = useCharacterStats();
  const energyRemaining = stats?.energyRemaining ?? 0;
  const { busy, run } = useBusyGuard();
  const [status, setStatus] = useState('');

  async function pick(key: KanbanExtraActionOption['key']) {
    const ok = await run(async () => {
      try {
        await logAndNotify(contact, key);
        return true;
      } catch (err) {
        // Fund einer unabhängigen Zweitmeinung: ein fehlschlagender
        // `logAndNotify()` schloss das Popup vorher trotzdem (via
        // `finally`), der Fehler wurde zu einer unbehandelten Promise-
        // Ablehnung ohne sichtbaren Hinweis. Vanilla zeigt hier einen
        // Alert + schreibt ins Fehlerprotokoll -- hier: sichtbarer
        // Status-Text (gleiches Muster wie die Verkaufs-/Termin-Popups)
        // + `logSilentError`, Popup bleibt offen statt zu schließen.
        logSilentError('Zusatzaktion loggen', err);
        setStatus(toError(err).message);
        return false;
      }
    });
    if (ok) onResolve();
  }

  return (
    <Modal
      title={<>Zusätzlich loggen für {contactDisplayName(contact)}?</>}
      onClose={() => {
        if (!busy) onResolve();
      }}
      testId="kanban-extra-action-modal"
      closeTestId="kanban-extra-action-close"
    >
      <div className="tw:grid tw:grid-cols-1 tw:gap-2 tw:sm:grid-cols-2">
        {options.map((option) => {
          const cost = actionCosts?.[option.key];
          const disabled = busy || costsLoading || (cost != null && cost.energy > 0 && cost.energy > energyRemaining);
          return (
            <button
              key={option.key}
              type="button"
              disabled={disabled}
              onClick={() => void pick(option.key)}
              className="tw:flex tw:flex-col tw:items-start tw:gap-0.5 tw:rounded-sm tw:border tw:border-border tw:bg-panel-2 tw:px-2.5 tw:py-2 tw:text-left tw:text-sm tw:text-text tw:hover:border-arcane tw:disabled:cursor-not-allowed tw:disabled:opacity-40"
            >
              <span>{option.label}</span>
              {cost && (
                <span className="tw:font-mono-brand tw:text-[10.5px] tw:text-muted-2">
                  {fmtXp(cost.xp)} XP · {cost.energy} Energie
                </span>
              )}
            </button>
          );
        })}
      </div>
      {status && <div className="tw:mt-2 tw:text-xs tw:text-danger">{status}</div>}
    </Modal>
  );
}
