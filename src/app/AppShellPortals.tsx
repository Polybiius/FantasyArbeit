import { createPortal } from 'react-dom';

import { Sidebar } from './Sidebar';
import { StatsHeader } from './StatsHeader';

/**
 * Produktive Verdrahtung von Header+Sidebar in die echte `index.html`
 * (im Unterschied zu `AppShell.tsx`, das nur für die isolierte Vorschau
 * gebaut wurde und selbst den Grid-Container rendert).
 *
 * WARUM PORTALE STATT EINES GEMEINSAMEN REACT-CONTAINERS: Vanillas
 * `.content`-Div (mit allen `.page`-Kindern) bleibt ein von React
 * komplett unangetastetes, an Ort und Stelle verbleibendes DOM-Element --
 * kein Reparenting eines riesigen, aktiv genutzten Teilbaums (Canvas-
 * Sprites, Leaflet-Karte, ...), kein Risiko, dass daran hängende
 * Zustände/Event-Listener beim Verschieben kaputtgehen. Das Grid selbst
 * lebt deshalb als reines, ungerahmtes HTML+CSS direkt in `index.html`
 * (dieselben `tw:`-Klassen, die `AppShell.tsx` schon in der isolierten
 * Vorschau bewiesen hat) -- React reicht nur zwei fertige Komponenten in
 * zwei dafür vorgesehene, leere Anker-Divs hinein
 * (`#reactStatsHeaderAnchor`/`#reactSidebarAnchor`), die an ihrer festen
 * Stelle im Grid stehen.
 *
 * Eigener, zweiter React-Root (siehe `main.tsx`) statt Erweiterung des
 * bestehenden `#react-root` (Einstellungen-Pilot) -- dieser hier ist
 * NICHT routenabhängig, muss auf jeder Seite (auch Vanilla-Seiten)
 * bestehen bleiben, der bestehende Root ist an eine Route gebunden.
 */
export function AppShellPortals() {
  const headerAnchor = document.getElementById('reactStatsHeaderAnchor');
  const sidebarAnchor = document.getElementById('reactSidebarAnchor');

  return (
    <>
      {headerAnchor ? createPortal(<StatsHeader />, headerAnchor) : null}
      {sidebarAnchor ? createPortal(<Sidebar />, sidebarAnchor) : null}
    </>
  );
}
