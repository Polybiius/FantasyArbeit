import { useState } from 'react';

import type { Profile } from '@/shared/lib/bridge';

import {
  parseArbeitszeiten,
  WEEKDAY_KEYS,
  WEEKDAY_LABELS_FULL,
  type Arbeitszeiten,
  type WeekdayKey,
} from '../arbeitszeiten';
import { useOwnProfileQuery, useUpdateOwnProfileMutation } from '../api';
import { allTimezones } from '../timezones';

/**
 * Kalender-Gruppe: zwei sofort speichernde Toggles + zwei Sonder-Widgets
 * (Zeitzone, Arbeitszeiten). Beide Toggles haben in Vanilla einen
 * Seiteneffekt auf die Kalender-Seite (`renderCalTasksNow()`, bei
 * `calendar_show_birthdays` zusätzlich einen Aufgaben-Resync) -- das
 * übernimmt jetzt `window.__bridge.notifyProfilePatch()` selbst
 * (bridge.ts/index.html), nicht diese Komponente.
 */
export function KalenderSection() {
  const { data: profile } = useOwnProfileQuery();
  if (!profile) return null;
  return (
    <section className="ein-card">
      <h2>📅 Kalender</h2>
      <div style={{ display: 'grid', gap: 14 }}>
        <TimezoneBlock profile={profile} />
        <ArbeitszeitenBlock profile={profile} />
        <CalendarTogglesBlock profile={profile} />
      </div>
    </section>
  );
}

function CalendarTogglesBlock({ profile }: { profile: Profile }) {
  const updateHideWeekends = useUpdateOwnProfileMutation();
  const updateShowBirthdays = useUpdateOwnProfileMutation();
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <label className="ein-toggle-row">
        <input
          type="checkbox"
          checked={profile.calendar_hide_weekends}
          disabled={updateHideWeekends.isPending}
          onChange={(e) => updateHideWeekends.mutate({ calendar_hide_weekends: e.target.checked })}
        />
        <span>
          Wochenenden ausblenden
          <div className="ein-toggle-desc">Samstag/Sonntag in der Wochenansicht komplett ausblenden statt nur grau.</div>
        </span>
      </label>
      <label className="ein-toggle-row">
        <input
          type="checkbox"
          checked={profile.calendar_show_birthdays !== false}
          disabled={updateShowBirthdays.isPending}
          onChange={(e) => updateShowBirthdays.mutate({ calendar_show_birthdays: e.target.checked })}
        />
        <span>
          Geburtstage anzeigen
          <div className="ein-toggle-desc">Geburtstage deiner Kontakte als Hinweis im Kalender.</div>
        </span>
      </label>
      {(updateHideWeekends.isError || updateShowBirthdays.isError) && (
        <span className="ein-status is-error">Speichern fehlgeschlagen — bitte erneut versuchen.</span>
      )}
    </div>
  );
}

function TimezoneBlock({ profile }: { profile: Profile }) {
  // Kein useEffect-Resync nötig: `profile` kommt bereits beim ersten Render
  // synchron aus der Bridge (useOwnProfileQuery-`initialData`), und die
  // einzige Quelle für spätere Änderungen ist die eigene Mutation weiter
  // unten (deren neuer Wert bereits im lokalen `value`-State steckt, wenn
  // sie erfolgreich ist -- kein externer Divergenz-Fall wie bei einer
  // geteilten Liste).
  const [value, setValue] = useState(profile.timezone ?? '');
  const updateTz = useUpdateOwnProfileMutation();
  const orgTz = 'Europe/Berlin'; // Organisations-Standard -- react-Pilot kennt `org` (noch) nicht über die Brücke, siehe README "Noch offen"

  return (
    <div>
      <h3 className="ein-subheading">Zeitzone</h3>
      <p className="ein-hint">
        Wirkt sich auf die Termin-Anzeige im Kalender aus (Uhrzeit, Tages-/Wochenzuordnung) — nützlich, wenn du
        gerade nicht in deiner Standard-Zeitzone bist. Ohne Auswahl gilt die Standard-Zeitzone der Organisation.
      </p>
      <select value={value} onChange={(e) => setValue(e.target.value)} className="ein-input">
        <option value="">– Standard der Organisation ({orgTz}) –</option>
        {allTimezones().map((z) => (
          <option key={z} value={z}>
            {z}
          </option>
        ))}
      </select>
      <button
        type="button"
        className="ein-btn"
        style={{ marginTop: 8 }}
        disabled={updateTz.isPending || value === (profile.timezone ?? '')}
        onClick={() => updateTz.mutate({ timezone: value || null })}
      >
        {updateTz.isPending ? 'Speichert …' : 'Zeitzone speichern'}
      </button>
      {updateTz.isSuccess && value === (profile.timezone ?? '') && <span className="ein-status" style={{ marginLeft: 8 }}>Gespeichert.</span>}
      {updateTz.isError && <span className="ein-status is-error" style={{ marginLeft: 8 }}>Fehlgeschlagen.</span>}
    </div>
  );
}

function ArbeitszeitenBlock({ profile }: { profile: Profile }) {
  // Kein useEffect-Resync -- gleiche Begründung wie in TimezoneBlock oben.
  const [rows, setRows] = useState<Arbeitszeiten>(() => parseArbeitszeiten(profile.arbeitszeiten));
  const [bulkStart, setBulkStart] = useState('09:00');
  const [bulkEnde, setBulkEnde] = useState('18:00');
  const updateAz = useUpdateOwnProfileMutation();

  const setDay = (k: WeekdayKey, patch: Partial<{ active: boolean; start: string; end: string }>) => {
    setRows((prev) => {
      const current = prev[k] ?? { start: '', end: '' };
      if (patch.active === false) {
        const next = { ...prev };
        delete next[k];
        return next;
      }
      return { ...prev, [k]: { start: patch.start ?? current.start, end: patch.end ?? current.end } };
    });
  };

  const applyBulk = () => {
    if (!bulkStart || !bulkEnde) return;
    setRows((prev) => {
      const next = { ...prev };
      (['mon', 'tue', 'wed', 'thu', 'fri'] as const).forEach((k) => {
        next[k] = { start: bulkStart, end: bulkEnde };
      });
      return next;
    });
  };

  const save = () => {
    // Nur Tage mit vollständigem Start+Ende gehen mit -- ein Tag ohne
    // beide Zeiten zählt als arbeitsfrei (genau wie in Vanilla).
    const obj: Arbeitszeiten = {};
    for (const k of WEEKDAY_KEYS) {
      const v = rows[k];
      if (v && v.start && v.end) obj[k] = v;
    }
    // Json (generischer Supabase-Spaltentyp) verlangt strukturell ein
    // Index-Signature, das ein einfaches Interface wie Arbeitszeiten/
    // DaySpan nicht hat -- der Cast ist sicher, weil beide Typen nur aus
    // Strings bestehen (gültiges JSON).
    updateAz.mutate({ arbeitszeiten: obj as Profile['arbeitszeiten'] });
  };

  return (
    <div>
      <h3 className="ein-subheading">Arbeitszeiten</h3>
      <p className="ein-hint">
        Wirkt sich nur auf die Wochenansicht im Kalender aus (Zeiten außerhalb werden abgedunkelt dargestellt) —
        Termine lassen sich trotzdem jederzeit überall eintragen.
      </p>
      <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end', marginBottom: 12, flexWrap: 'wrap' }}>
        <label className="ein-field" style={{ flex: '1 1 auto' }}>
          Mo–Fr auf einmal setzen
          <input type="time" value={bulkStart} onChange={(e) => setBulkStart(e.target.value)} className="ein-input" />
        </label>
        <input type="time" value={bulkEnde} onChange={(e) => setBulkEnde(e.target.value)} className="ein-input" style={{ marginTop: 'auto' }} />
        <button type="button" className="ein-btn" onClick={applyBulk}>
          Übernehmen
        </button>
      </div>
      <div style={{ display: 'grid', gap: 6 }}>
        {WEEKDAY_KEYS.map((k) => {
          const v = rows[k];
          const active = !!v;
          return (
            <div key={k} className="ein-az-row">
              <label className="ein-az-check">
                <input type="checkbox" checked={active} onChange={(e) => setDay(k, { active: e.target.checked, start: '09:00', end: '18:00' })} />
                {WEEKDAY_LABELS_FULL[k]}
              </label>
              <div className="ein-az-times">
                <input
                  type="time"
                  className="ein-input"
                  disabled={!active}
                  value={v?.start ?? ''}
                  onChange={(e) => setDay(k, { start: e.target.value })}
                />
                <span>–</span>
                <input
                  type="time"
                  className="ein-input"
                  disabled={!active}
                  value={v?.end ?? ''}
                  onChange={(e) => setDay(k, { end: e.target.value })}
                />
              </div>
            </div>
          );
        })}
      </div>
      <button type="button" className="ein-btn" style={{ marginTop: 10 }} disabled={updateAz.isPending} onClick={save}>
        {updateAz.isPending ? 'Speichert …' : 'Arbeitszeiten speichern'}
      </button>
      {updateAz.isSuccess && <span className="ein-status" style={{ marginLeft: 8 }}>Gespeichert.</span>}
      {updateAz.isError && <span className="ein-status is-error" style={{ marginLeft: 8 }}>Fehlgeschlagen.</span>}
    </div>
  );
}
