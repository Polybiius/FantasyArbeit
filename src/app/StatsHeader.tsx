import { useCharacterStats } from '@/shared/hooks/useCharacterStats';

/**
 * React-Entsprechung des Level-/XP-/Energie-Teils von `<div class="header">`
 * in `index.html` (Block 4, isoliert gebaut/getestet). Zeigt NUR den
 * Kennzahlen-Teil -- Name-Feld, Admin-/Klassenschalter, Abmelden-Knopf
 * (alles mit eigenen Schreib-/Interaktionspfaden) sind bewusst nicht Teil
 * dieses Schritts, kommen mit dem eigentlichen Scharfschalten.
 *
 * Alle Werte kommen fertig berechnet aus `useCharacterStats()` (ADR-0002-
 * Nachtrag 3) -- kein eigener Level-/Energie-Rechenweg hier.
 */
export function StatsHeader() {
  const stats = useCharacterStats();

  if (!stats) {
    return <div className="tw:h-[74px] tw:animate-pulse tw:rounded-lg tw:bg-panel" />;
  }

  const xpPct = stats.xpNeededForLevel > 0 ? Math.round((100 * stats.xpIntoLevel) / stats.xpNeededForLevel) : 0;
  const xpToNext = stats.xpNeededForLevel - stats.xpIntoLevel;

  return (
    <div className="tw:flex tw:flex-col tw:gap-2 tw:rounded-lg tw:border tw:border-border tw:bg-panel tw:p-4">
      <div className="tw:flex tw:items-center tw:justify-between">
        <div className="tw:flex tw:flex-col tw:items-center tw:rounded-sm tw:border tw:border-border tw:bg-panel-2 tw:px-3.5 tw:py-1.5">
          <div className="tw:font-mono-brand tw:text-lg tw:font-bold tw:text-text">{stats.level}</div>
          <div className="tw:text-[10px] tw:uppercase tw:tracking-wide tw:text-muted">Level</div>
        </div>
      </div>
      <div className="tw:flex tw:justify-between tw:font-mono-brand tw:text-xs tw:text-muted">
        <span>
          {stats.xpIntoLevel} / {stats.xpNeededForLevel} XP
        </span>
        <span>
          {xpToNext} XP bis Level {stats.level + 1}
        </span>
      </div>
      <div className="tw:h-2 tw:overflow-hidden tw:rounded-pill tw:bg-panel-2">
        <div
          className="tw:h-full tw:rounded-pill tw:transition-[width] tw:duration-300"
          style={{ width: `${xpPct}%`, background: 'var(--arcane)' }}
        />
      </div>
      <div className="tw:flex tw:items-center tw:gap-1">
        {Array.from({ length: stats.energyMax }).map((_, i) => (
          <div
            key={i}
            className="tw:h-2.5 tw:w-2.5 tw:rounded-pill"
            style={{ background: i < stats.energyRemaining ? 'var(--arcane)' : 'var(--border)' }}
          />
        ))}
      </div>
      <div className="tw:text-xs" style={{ color: stats.energyRemaining > 0 ? 'var(--muted)' : 'var(--danger)' }}>
        {stats.energyRemaining > 0
          ? `${stats.energyRemaining} / ${stats.energyMax} Energie verfügbar (regeneriert morgen)`
          : '⚡ Mana verbraucht — keine weiteren Kommandos möglich, regeneriert morgen früh.'}
      </div>
    </div>
  );
}
