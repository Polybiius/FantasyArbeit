import { useCharacterStats } from '@/shared/hooks/useCharacterStats';

/**
 * React-Entsprechung des Level-/XP-Teils von `<div class="header">` in
 * `index.html`. Zeigt NUR Level + XP-Balken -- beim genauen Nachlesen der
 * echten Seite (vor dem Scharfschalten) stellte sich heraus, dass die
 * Energie-Anzeige (`#energyRow`/`#energyLabel`) entgegen der ursprünglichen
 * Annahme dieser Komponente GAR NICHT im dauerhaften Kopfbereich sitzt,
 * sondern Teil der "Handlungen"-Seite ("Manareserve"-Karte) ist -- bleibt
 * dort bewusst unverändert Vanilla, bis diese Seite migriert wird. Diese
 * Komponente hier zeigt deshalb absichtlich WENIGER als ursprünglich
 * gebaut, um exakt dem heutigen Verhalten zu entsprechen (keine
 * Verhaltensänderung durchs Scharfschalten).
 *
 * Name-Feld, Admin-/Klassenschalter, Abmelden-Knopf bleiben Vanilla-
 * Elemente, unverändert an ihrem Platz im Kopfbereich.
 *
 * `data-testid="level-num"` wandert hierher (von der jetzt versteckten
 * Vanilla-Entsprechung) -- Konvention aus `tests/README.md`: ein
 * migrierter Bereich bekommt denselben testid-Wert wie die Vanilla-Fassung.
 */
export function StatsHeader() {
  const stats = useCharacterStats();

  if (!stats) {
    return <div className="tw:h-[70px] tw:animate-pulse tw:rounded-lg tw:bg-panel" />;
  }

  const xpPct = stats.xpNeededForLevel > 0 ? Math.round((100 * stats.xpIntoLevel) / stats.xpNeededForLevel) : 0;
  const xpToNext = stats.xpNeededForLevel - stats.xpIntoLevel;

  return (
    <div className="tw:flex tw:flex-col tw:gap-2 tw:min-[480px]:flex-row tw:min-[480px]:items-center tw:min-[480px]:gap-4">
      <div className="tw:flex tw:flex-none tw:flex-row tw:items-center tw:gap-2 tw:rounded-sm tw:border tw:border-border tw:bg-panel-2 tw:px-3.5 tw:py-1.5 tw:min-[480px]:flex-col">
        <div className="tw:font-mono-brand tw:text-lg tw:font-bold tw:text-text" data-testid="level-num">
          {stats.level}
        </div>
        <div className="tw:text-[10px] tw:uppercase tw:tracking-wide tw:text-muted">Level</div>
      </div>
      <div className="tw:min-w-0 tw:flex-1">
        <div className="tw:flex tw:flex-wrap tw:justify-between tw:gap-x-2 tw:font-mono-brand tw:text-xs tw:text-muted">
          <span>
            {stats.xpIntoLevel} / {stats.xpNeededForLevel} XP
          </span>
          <span>
            {xpToNext} XP bis Level {stats.level + 1}
          </span>
        </div>
        <div className="tw:mt-1 tw:h-2 tw:overflow-hidden tw:rounded-pill tw:bg-panel-2">
          <div
            className="tw:h-full tw:rounded-pill tw:transition-[width] tw:duration-300"
            style={{ width: `${xpPct}%`, background: 'var(--arcane)' }}
          />
        </div>
      </div>
    </div>
  );
}
