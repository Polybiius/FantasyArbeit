import type { ReactNode } from 'react';

import { Sidebar } from './Sidebar';
import { StatsHeader } from './StatsHeader';

/**
 * Der eigentliche App-Rahmen (Block 4, "Vollbreite-Layout"): löst den
 * dokumentierten Schmerzpunkt "nicht die ganze Seite wird auf der
 * Desktopversion genutzt" -- Ursache ist `.wrap{max-width:1040px;margin:
 * 0 auto}` in `index.html`, das den kompletten `#app`-Inhalt (Header +
 * Sidebar + Seiteninhalt) auf 1040px deckelt. Dieses Grid ersetzt das
 * (Header oben über die volle Breite, Sidebar+Inhalt darunter
 * nebeneinander) OHNE äußere Breitenobergrenze -- jede einzelne Vanilla-
 * Seite behält ihre eigenen internen Layout-/Kartenbreiten unverändert,
 * nur der äußere Rahmen nutzt jetzt den ganzen Viewport.
 *
 * `children` ist hier bewusst ein generischer Platzhalter für den
 * eigentlichen Seiteninhalt -- reicht für den isolierten Test dieses
 * Schritts. Beim echten Scharfschalten (eigener, noch nicht gebauter
 * Schritt) übernimmt NICHT `children` diese Rolle: Vanillas `.content`-
 * Div (mit allen `.page`-Kindern) bleibt ein von React unangetastetes
 * DOM-Element. Der geplante Weg dafür (noch nicht umgesetzt): ein
 * statisches Grid-Gerüst in `index.html` mit drei Grid-Bereichen
 * (`header`/`sidebar`/`content`), React rendert Header+Sidebar per
 * `createPortal()` in zwei eigene Anker-Elemente, `.content` bleibt an
 * Ort und Stelle im dritten Bereich -- keine DOM-Neuverschachtelung,
 * kein Risiko für den bestehenden Vanilla-Code.
 */
/**
 * 720px-Umbruch identisch zum bestehenden `@media (max-width:720px)` in
 * `index.html` (Sidebar wird dort horizontal/scrollbar statt Spalte
 * links) -- bewusst dieselbe Schwelle, damit sich beim Scharfschalten
 * nichts an der Stelle verschiebt, an der die App auf "mobil" umschaltet.
 * Kein `grid-template-areas` nötig: Kopfbereich bekommt `col-span-full`
 * (spannt beide Spalten), Sidebar/Inhalt folgen einfach der
 * Quellcode-Reihenfolge -- bei einer Spalte (mobil) stapeln sie sich
 * automatisch, bei zwei Spalten (Desktop) füllt Grid-Auto-Placement sie
 * von links nach rechts.
 */
export function AppShell({ children }: { children: ReactNode }) {
  return (
    // content-start: OHNE das würde `min-h-screen` bei kurzem Inhalt
    // (z.B. mobil, wo Sidebar+Header wenig Höhe brauchen) den restlichen
    // Leerraum gleichmäßig auf alle drei Zeilen verteilen (Grids
    // Default-`align-content` verhält sich wie `stretch`) -- die Sidebar-
    // Zeile bläht sich dann auf, und weil ihr `<nav>` ein Flex-*Row* ist
    // (mobil), zieht dessen Default-`align-items:stretch` jeden Nav-Knopf
    // auf diese aufgeblähte Höhe mit. Empirisch als echter Bug gefunden
    // (Playwright-Screenshot bei 700px Breite: der aktive Knopf ragte
    // sichtbar heraus, weil nur er einen sichtbaren Hintergrund hat).
    <div className="tw:grid tw:min-h-screen tw:content-start tw:grid-cols-1 tw:gap-4.5 tw:bg-void tw:p-5 tw:min-[721px]:grid-cols-[220px_1fr]">
      <div className="tw:col-span-full">
        <StatsHeader />
      </div>
      <Sidebar />
      <div className="tw:min-w-0">{children}</div>
    </div>
  );
}
