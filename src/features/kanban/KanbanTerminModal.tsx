import { useState } from 'react';

import { getBridge } from '@/shared/lib/bridge';
import { logSilentError } from '@/shared/lib/errorLog';
import { toError } from '@/shared/lib/toError';
import { resolveTimeZone } from '@/shared/lib/timezone';
import { useBusyGuard } from '@/shared/hooks/useBusyGuard';
import { formInputClass as inputClass, formLabelClass as labelClass } from '@/shared/ui/formStyles';
import { Modal } from '@/shared/ui/Modal';

import { contactDisplayName } from '@/shared/domain/contactCard/contactDisplay';
import type { KanbanContact } from './kanbanApi';
import { computeTerminRange, insertKanbanTermin, type KanbanKanal } from './kanbanTerminWrite';

const KANAL_OPTIONS: { value: KanbanKanal; label: string }[] = [
  { value: 'online', label: '💻 Online' },
  { value: 'buero', label: '🏢 Büro' },
  { value: 'betrieb', label: '🏥 Im Betrieb' },
];

export interface KanbanTerminModalProps {
  contact: KanbanContact;
  /** "Ersttermin" oder "Zweittermin" — bestimmt Titel-Text und den Titel des angelegten Kalendertermins. */
  label: string;
  /** Der tatsächlich verwendete Kanal (`null` bei Abbruch ohne Speichern) — analog zum Rückgabewert von `promptKanbanTermin()`. */
  onResolve: (usedKanal: KanbanKanal | null) => void;
}

/**
 * 1:1-Portierung von `promptKanbanTermin()` (`index.html`) — kleines,
 * überspringbares Termin-Fenster für Ersttermin/Zweittermin beim Ziehen
 * einer bestehenden Kanban-Karte. Datum/Start/Ende sind optional (nur
 * bei allen drei ausgefüllten Feldern entsteht ein Kalendertermin) — der
 * Kartenzug selbst ist davon unabhängig bereits passiert.
 */
export function KanbanTerminModal({ contact, label, onResolve }: KanbanTerminModalProps) {
  const profile = getBridge().getProfile();
  const timeZone = resolveTimeZone(profile?.timezone);

  const [datum, setDatum] = useState('');
  const [start, setStart] = useState('');
  const [ende, setEnde] = useState('');
  const [kanal, setKanal] = useState<KanbanKanal | null>(null);
  const [status, setStatus] = useState('');
  const { busy, run } = useBusyGuard();

  function close() {
    if (busy) return;
    onResolve(null);
  }

  async function save() {
    if (!datum || !start || !ende) {
      setStatus('Bitte Datum, Start- und Endzeit eingeben.');
      return;
    }
    if (!profile?.org_id) {
      setStatus('Keine Organisation.');
      return;
    }
    const range = computeTerminRange(datum, start, ende, timeZone);
    if (range === null) {
      setStatus('Bitte Datum, Start- und Endzeit eingeben.');
      return;
    }
    if (range === 'invalid') {
      setStatus('Ende muss nach dem Start liegen.');
      return;
    }
    await run(async () => {
      try {
        await insertKanbanTermin(profile.org_id!, profile.id, contact.id, `${label}: ${contactDisplayName(contact)}`, range, kanal);
        onResolve(kanal);
      } catch (err) {
        logSilentError('Termin speichern', err);
        setStatus(toError(err).message);
      }
    });
  }

  return (
    <Modal
      title={<>{label} für {contactDisplayName(contact)}</>}
      onClose={close}
      testId="kanban-termin-modal"
      closeTestId="kanban-termin-close"
    >
      <div className="tw:flex tw:flex-col tw:gap-2">
        <label className={labelClass}>Datum</label>
        <input type="date" min="2020-01-01" max="2040-12-31" className={inputClass} value={datum} onChange={(e) => setDatum(e.target.value)} />
        <div className="tw:flex tw:gap-2">
          <div className="tw:flex-1">
            <label className={labelClass}>Von</label>
            <input type="time" className={`${inputClass} tw:w-full`} value={start} onChange={(e) => setStart(e.target.value)} />
          </div>
          <div className="tw:flex-1">
            <label className={labelClass}>Bis</label>
            <input type="time" className={`${inputClass} tw:w-full`} value={ende} onChange={(e) => setEnde(e.target.value)} />
          </div>
        </div>
        <label className={labelClass}>Kanal (optional)</label>
        <div className="tw:flex tw:gap-1.5">
          {KANAL_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              type="button"
              className={`tw:flex-1 tw:rounded-sm tw:border tw:px-2 tw:py-1.5 tw:text-xs ${
                kanal === opt.value ? 'tw:border-arcane tw:bg-arcane/10 tw:text-text' : 'tw:border-border tw:bg-panel-2 tw:text-muted'
              }`}
              onClick={() => setKanal((prev) => (prev === opt.value ? null : opt.value))}
            >
              {opt.label}
            </button>
          ))}
        </div>
        {status && <div className="tw:text-xs tw:text-danger">{status}</div>}
      </div>
      <button
        type="button"
        className="tw:mt-3 tw:w-full tw:rounded-sm tw:border tw:border-arcane tw:bg-arcane/10 tw:px-2 tw:py-1.5 tw:text-sm tw:font-semibold tw:text-text"
        disabled={busy}
        onClick={() => void save()}
      >
        Termin speichern
      </button>
    </Modal>
  );
}
