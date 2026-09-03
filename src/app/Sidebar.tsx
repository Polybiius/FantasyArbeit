import { useCharacterClass } from '@/shared/hooks/useCharacterClass';
import { useNavState } from '@/shared/hooks/useNavState';
import { useProfileFlags } from '@/shared/hooks/useProfileFlags';

import { isNavItemVisible, NAV_ITEMS, resolveNavLabel } from './navItems';

const ACTIVE_BG = 'color-mix(in srgb, var(--arcane) 15%, transparent)';
const ACTIVE_BORDER = 'color-mix(in srgb, var(--arcane) 40%, transparent)';
const HOVER_BG = 'color-mix(in srgb, var(--arcane) 8%, transparent)';

/**
 * React-Entsprechung von `<nav class="sidebar">` in `index.html` (Block 4,
 * isoliert gebaut/getestet -- noch NICHT in der produktiven Seite scharf
 * geschaltet). Navigation läuft über echte `<a href="#seite">`-Links, wie
 * überall sonst im Projekt (ADR-0003) -- kein `onClick`/`location.hash=`,
 * damit Rechtsklick/neuer Tab/Bookmark unverändert funktionieren. Vanillas
 * `showPage()` bleibt über den bestehenden `hashchange`-Listener die
 * einzige Instanz, die eine Seite tatsächlich anzeigt/verbietet -- diese
 * Sidebar entscheidet nur, welche Knöpfe angezeigt werden und welcher
 * aktiv aussieht (`useNavState().activePage`, von `showPage()` NACH allen
 * Weiterleitungsregeln aufgelöst).
 */
export function Sidebar() {
  const characterClass = useCharacterClass();
  const { isPool, isAdmin } = useProfileFlags();
  const { activePage, isGuildFounder } = useNavState();

  return (
    <nav
      className="tw:flex tw:flex-row tw:gap-1.5 tw:overflow-x-auto tw:rounded-lg tw:border tw:border-border tw:bg-panel tw:p-3
        tw:min-[721px]:sticky tw:min-[721px]:top-5 tw:min-[721px]:w-[190px] tw:min-[721px]:flex-none tw:min-[721px]:flex-col tw:min-[721px]:overflow-visible"
    >
      {NAV_ITEMS.filter((item) => isNavItemVisible(item, { isPool, isAdmin, isGuildFounder })).map((item) => {
        const active = item.page === activePage;
        return (
          <a
            key={item.page}
            href={`#${item.page}`}
            data-page={item.page}
            className="tw:flex-none tw:whitespace-nowrap tw:rounded-sm tw:border tw:border-transparent tw:px-3.5 tw:py-2.5 tw:font-sans tw:text-[13.5px] tw:font-medium tw:no-underline tw:transition-colors"
            style={{
              color: active ? 'var(--text)' : 'var(--muted)',
              background: active ? ACTIVE_BG : undefined,
              borderColor: active ? ACTIVE_BORDER : undefined,
            }}
            onMouseEnter={(e) => {
              if (!active) e.currentTarget.style.background = HOVER_BG;
            }}
            onMouseLeave={(e) => {
              if (!active) e.currentTarget.style.background = '';
            }}
          >
            {item.icon} {resolveNavLabel(item, characterClass)}
          </a>
        );
      })}
    </nav>
  );
}
