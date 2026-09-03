import { useEffect, useRef, type RefObject } from 'react';

import { useCharacterClass } from '@/shared/hooks/useCharacterClass';
import { useNavState } from '@/shared/hooks/useNavState';
import { useProfileFlags } from '@/shared/hooks/useProfileFlags';
import { getBridge } from '@/shared/lib/bridge';

import { isNavItemVisible, NAV_ITEMS, resolveNavLabel } from './navItems';

const ACTIVE_BG = 'color-mix(in srgb, var(--arcane) 15%, transparent)';
const ACTIVE_BORDER = 'color-mix(in srgb, var(--arcane) 40%, transparent)';
const HOVER_BG = 'color-mix(in srgb, var(--arcane) 8%, transparent)';

/**
 * Portierung von Vanillas `updateScrollFade()`/`initScrollFade()`
 * (`index.html`) für den mobilen, horizontal scrollbaren Zustand dieser
 * Sidebar -- Vanillas eigener Aufruf `initScrollFade(document.
 * querySelector('.sidebar'))` liefe seit dem Scharfschalten ins Leere
 * (die Klasse `.sidebar` existiert nicht mehr, `initScrollFade` hat zwar
 * einen `if(!el) return`-Guard, tut also nichts Schädliches, aber auch
 * nichts Nützliches mehr). `useEffect`-Cleanup macht hier das
 * Listener-Stacking, gegen das Vanilla ein eigenes Guard-Flag brauchte,
 * strukturell überflüssig.
 */
function useScrollFade(ref: RefObject<HTMLElement | null>) {
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = () => {
      const canLeft = el.scrollLeft > 4;
      const canRight = el.scrollLeft < el.scrollWidth - el.clientWidth - 4;
      let mask = 'none';
      if (canLeft && canRight) mask = 'linear-gradient(to right, transparent, black 24px, black calc(100% - 24px), transparent)';
      else if (canLeft) mask = 'linear-gradient(to right, transparent, black 24px)';
      else if (canRight) mask = 'linear-gradient(to left, transparent, black 24px)';
      el.style.maskImage = mask;
      el.style.webkitMaskImage = mask;
    };
    update();
    el.addEventListener('scroll', update);
    window.addEventListener('resize', update);
    return () => {
      el.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
    };
  }, [ref]);
}

/**
 * React-Entsprechung von `<nav class="sidebar">` in `index.html`.
 * Navigation läuft über echte `<a href="#seite">`-Links, wie überall
 * sonst im Projekt (ADR-0003) -- Rechtsklick/neuer Tab/Bookmark
 * funktionieren unverändert. Vanillas `showPage()` bleibt über den
 * bestehenden `hashchange`-Listener die einzige Instanz, die eine Seite
 * tatsächlich anzeigt/verbietet -- diese Sidebar entscheidet nur, welche
 * Knöpfe angezeigt werden und welcher aktiv aussieht
 * (`useNavState().activePage`, von `showPage()` NACH allen
 * Weiterleitungsregeln aufgelöst).
 *
 * EINZIGE AUSNAHME: "Abenteuerlog" (tagebuch) bekommt zusätzlich einen
 * `onClick`+`preventDefault()`, der `getBridge().navigateToTagebuch()`
 * statt der reinen Hash-Navigation aufruft -- ein blindes
 * `location.hash='tagebuch'` würde den von `updateCalendarHash()`
 * gepflegten Ansicht+Tag-Unterhash verwerfen (derselbe Sonderfall, den
 * schon der frühere Vanilla-Klick-Handler brauchte). `href` bleibt
 * trotzdem gesetzt, für Mittelklick/Strg-Klick/neuer-Tab (die den
 * Klick-Handler ohnehin nie ausgelöst haben -- kein Verhaltensunterschied
 * zu vorher).
 */
export function Sidebar() {
  const characterClass = useCharacterClass();
  const { isPool, isAdmin } = useProfileFlags();
  const { activePage, isGuildFounder } = useNavState();
  const navRef = useRef<HTMLElement | null>(null);
  useScrollFade(navRef);

  return (
    <nav
      ref={navRef}
      data-testid="app-sidebar"
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
            // "active" bewusst als reine Marker-Klasse mitgeführt (ohne
            // eigene CSS-Regel dafür -- die optische Wirkung kommt
            // vollständig aus dem style-Attribut unten): die bestehende
            // Regressions-Suite prüft `classList.contains('active')`,
            // exakt wie bei der alten Vanilla-.nav-btn.active-Klasse.
            className={`tw:flex-none tw:whitespace-nowrap tw:rounded-sm tw:border tw:border-transparent tw:px-3.5 tw:py-2.5 tw:font-sans tw:text-[13.5px] tw:font-medium tw:no-underline tw:transition-colors${active ? ' active' : ''}`}
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
            onClick={
              item.page === 'tagebuch'
                ? (e) => {
                    e.preventDefault();
                    getBridge().navigateToTagebuch();
                  }
                : undefined
            }
          >
            {item.icon} {resolveNavLabel(item, characterClass)}
          </a>
        );
      })}
    </nav>
  );
}
