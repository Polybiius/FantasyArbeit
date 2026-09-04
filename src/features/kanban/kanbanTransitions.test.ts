import { describe, expect, it } from 'vitest';
import {
  KANBAN_STAGES,
  decideKanbanTransition,
  resolveLostOutcome,
  resolveWonOutcome,
  type KanbanTransitionContext,
} from './kanbanTransitions';

function makeContext(overrides: Partial<KanbanTransitionContext> = {}): KanbanTransitionContext {
  return {
    isKunde: false,
    hasFunnelMarkerThisYear: () => false,
    energyRemaining: 1000,
    actionEnergyCost: () => 5,
    ...overrides,
  };
}

describe('decideKanbanTransition — erschöpfend alle 8×8 Kombinationen', () => {
  it('ist nur beim "Nicht erschienen"-Herkunftsschutz abgelehnt, sonst immer erlaubt', () => {
    for (const from of KANBAN_STAGES) {
      for (const to of KANBAN_STAGES) {
        const plan = decideKanbanTransition(from, to, makeContext());
        const shouldReject = to === 'nicht_erschienen' && from !== 'ersttermin_vereinbart' && from !== 'zweittermin';
        expect(plan.allowed, `${from} -> ${to}`).toBe(!shouldReject);
        if (shouldReject) {
          expect(plan.rejectionReason, `${from} -> ${to}`).toContain('Nicht erschienen');
        } else {
          expect(plan.rejectionReason, `${from} -> ${to}`).toBeNull();
        }
      }
    }
  });
});

describe('decideKanbanTransition — "Nicht erschienen": Hauptaktion je Herkunft', () => {
  it('von Ersttermin: termin_nicht_wahrgenommen', () => {
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'nicht_erschienen', makeContext());
    expect(plan.mainAction).toBe('termin_nicht_wahrgenommen');
  });
  it('von Zweittermin: zweittermin_nicht_wahrgenommen', () => {
    const plan = decideKanbanTransition('zweittermin', 'nicht_erschienen', makeContext());
    expect(plan.mainAction).toBe('zweittermin_nicht_wahrgenommen');
  });
});

// Diese Bloecke spiegeln bewusst 1:1 die Namen/Faelle aus dem Playwright-
// "Kanban-Uebergangs-Vertrag" (tests/regression_suite.mjs) -- beide Suiten
// muessen bei jeder kuenftigen Regelwerk-Aenderung uebereinstimmen.
describe('decideKanbanTransition — Ersttermin vereinbart -> Angebot versendet', () => {
  it('pitch + termin_wahrgenommen + Bedarfsanalyse-Popup', () => {
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'angebot_versendet', makeContext());
    expect(plan.mainAction).toBe('pitch');
    expect(plan.funnelMarkers).toEqual(['termin_wahrgenommen']);
    expect(plan.popups).toEqual(['bedarfsanalyse-optional']);
    expect(plan.specialFlow).toBe('none');
  });
});

describe('decideKanbanTransition — -> Zweittermin', () => {
  it('bei frischem Kontakt (nicht Kunde): pitch + BEIDE Marken gleichzeitig', () => {
    // Fund: dieser Fall kam im Playwright-Vertrag nie zur Beobachtung, weil
    // der dortige Testkontakt zu diesem Zeitpunkt der Kette bereits Kunde
    // war (isKunde-Schutz) -- genau der Wert einer erschoepfenden, reinen
    // Pruefung unabhaengig vom Reihenfolge-Zufall eines E2E-Testverlaufs.
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'zweittermin', makeContext());
    expect(plan.mainAction).toBe('pitch');
    expect([...plan.funnelMarkers].sort()).toEqual(['termin_wahrgenommen', 'zweittermin_vereinbart']);
    expect(plan.popups).toEqual(['bedarfsanalyse-optional', 'termin-zweittermin']);
  });

  it('bei Bestandskunde: keine Marken (isKunde-Schutz)', () => {
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'zweittermin', makeContext({ isKunde: true }));
    expect(plan.mainAction).toBe('pitch');
    expect(plan.funnelMarkers).toEqual([]);
  });

  it('vom Kundenausbau-Pfad aus (fromTerminal): keine "zweittermin_vereinbart"-Marke', () => {
    const plan = decideKanbanTransition('gewonnen', 'zweittermin', makeContext());
    expect(plan.funnelMarkers).toEqual([]);
  });
});

describe('decideKanbanTransition — Kundenausbau (Gewonnen/Verloren -> aktive Spalte)', () => {
  it('loggt "kundenausbau" statt der sonst ueblichen Aktion der Zielspalte, keine Trichter-Marke', () => {
    for (const from of ['gewonnen', 'verloren'] as const) {
      const plan = decideKanbanTransition(from, 'ersttermin_vereinbart', makeContext());
      expect(plan.mainAction, from).toBe('kundenausbau');
      expect(plan.funnelMarkers, from).toEqual([]);
      expect(plan.popups, from).toEqual(['termin-ersttermin']);
    }
  });

  it('gilt auch fuer Angebot versendet/Zweittermin als Ziel', () => {
    expect(decideKanbanTransition('gewonnen', 'angebot_versendet', makeContext()).mainAction).toBe('kundenausbau');
    expect(decideKanbanTransition('verloren', 'zweittermin', makeContext()).mainAction).toBe('kundenausbau');
  });
});

describe('decideKanbanTransition — -> Verloren', () => {
  it('keine Hauptaktion ("Verloren ist verloren"), aber Trichter-Marke feuert SOFORT', () => {
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'verloren', makeContext());
    expect(plan.mainAction).toBeNull();
    expect(plan.specialFlow).toBe('verloren');
    expect(plan.funnelMarkers).toEqual(['termin_wahrgenommen']);
    expect(plan.funnelMarkersIfWon).toEqual([]);
  });

  it('von Zweittermin aus: zweittermin_wahrgenommen', () => {
    const plan = decideKanbanTransition('zweittermin', 'verloren', makeContext());
    expect(plan.funnelMarkers).toEqual(['zweittermin_wahrgenommen']);
  });
});

describe('decideKanbanTransition — -> Gewonnen', () => {
  it('keine Hauptaktion vorab, Trichter-Marke wird nur "versprochen" (funnelMarkersIfWon)', () => {
    const plan = decideKanbanTransition('zweittermin', 'gewonnen', makeContext());
    expect(plan.mainAction).toBeNull();
    expect(plan.funnelMarkers).toEqual([]);
    expect(plan.funnelMarkersIfWon).toEqual(['zweittermin_wahrgenommen']);
    expect(plan.specialFlow).toBe('gewonnen');
  });
});

describe('decideKanbanTransition — -> Dauerbrenner', () => {
  it('keine automatische Hauptaktion, optionales Zusatz-Popup', () => {
    const plan = decideKanbanTransition('zweittermin', 'dauerbrenner', makeContext());
    expect(plan.mainAction).toBeNull();
    expect(plan.popups).toEqual(['dauerbrenner-optional']);
    expect(plan.funnelMarkers).toEqual([]);
  });
});

describe('decideKanbanTransition — isKunde-Schutz', () => {
  it('unterdrückt alle drei Trichter-Marken bei Bestandskunden, unabhängig von der Spalte', () => {
    const ctx = makeContext({ isKunde: true });
    expect(decideKanbanTransition('ersttermin_vereinbart', 'angebot_versendet', ctx).funnelMarkers).toEqual([]);
    expect(decideKanbanTransition('ersttermin_vereinbart', 'verloren', ctx).funnelMarkers).toEqual([]);
    expect(decideKanbanTransition('zweittermin', 'gewonnen', ctx).funnelMarkersIfWon).toEqual([]);
  });
});

describe('decideKanbanTransition — Jahres-Duplikatschutz', () => {
  it('lässt eine bereits geloggte Marke aus, der Rest bleibt unberührt', () => {
    const ctx = makeContext({ hasFunnelMarkerThisYear: (m) => m === 'termin_wahrgenommen' });
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'zweittermin', ctx);
    expect(plan.funnelMarkers).toEqual(['zweittermin_vereinbart']);
  });
});

describe('decideKanbanTransition — Energie-Budget', () => {
  it('lehnt eine Hauptaktion ab, wenn die Energie nicht reicht', () => {
    const ctx = makeContext({ energyRemaining: 2, actionEnergyCost: () => 5 });
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'angebot_versendet', ctx);
    expect(plan.allowed).toBe(false);
    expect(plan.rejectionReason).toContain('Energie');
  });

  it('lässt Übergänge ohne Hauptaktion von der Energie-Prüfung unberührt (z.B. "Verloren")', () => {
    const ctx = makeContext({ energyRemaining: 0, actionEnergyCost: () => 999 });
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'verloren', ctx);
    expect(plan.allowed).toBe(true);
  });

  it('lehnt eine kostenlose Aktion NIE ab, selbst bei negativem Restbudget (Fund einer unabhängigen Zweitmeinung: ">0"-Klausel wie im echten Code)', () => {
    const ctx = makeContext({ energyRemaining: -5, actionEnergyCost: () => 0 });
    const plan = decideKanbanTransition('ersttermin_vereinbart', 'nicht_erschienen', ctx);
    expect(plan.allowed).toBe(true);
  });

  it('prüft bei "Gewonnen" die Energie für "abschluss" unabhängig von der Herkunft', () => {
    const ctx = makeContext({
      energyRemaining: 2,
      actionEnergyCost: (a) => (a === 'abschluss' ? 100 : 0),
    });
    const plan = decideKanbanTransition('zweittermin', 'gewonnen', ctx);
    expect(plan.allowed).toBe(false);
    expect(plan.rejectionReason).toContain('Energie');
  });
});

describe('resolveWonOutcome', () => {
  it('setzt im Normalfall (Status-Update gelingt): Spalte gewonnen, abschluss, Kunde — aber KEINE Trichter-Marke', () => {
    // Fund einer unabhängigen Zweitmeinung: im echten Code wird
    // contacts.status VOR der Trichter-Prüfung auf 'kunde' gesetzt — ein
    // Erstabschluss unterdrückt dadurch praktisch immer seine eigene Marke.
    expect(resolveWonOutcome('ersttermin_vereinbart', true, ['termin_wahrgenommen'])).toEqual({
      finalStage: 'gewonnen',
      mainAction: 'abschluss',
      funnelMarkers: [],
      setStatusKunde: true,
    });
  });

  it('löst die versprochenen Marken nur im seltenen Randfall ein, dass der Status-Schreibvorgang selbst kollidiert', () => {
    expect(resolveWonOutcome('ersttermin_vereinbart', true, ['termin_wahrgenommen'], true)).toEqual({
      finalStage: 'gewonnen',
      mainAction: 'abschluss',
      funnelMarkers: ['termin_wahrgenommen'],
      setStatusKunde: false,
    });
  });

  it('macht bei Abbruch ohne Produkt die Spalte rückgängig (Revert-Pfad)', () => {
    expect(resolveWonOutcome('dauerbrenner', false, ['termin_wahrgenommen'])).toEqual({
      finalStage: 'dauerbrenner',
      mainAction: null,
      funnelMarkers: [],
      setStatusKunde: false,
    });
  });
});

describe('resolveLostOutcome', () => {
  it('setzt contacts.status nur bei tatsächlich eingetragenem Produkt', () => {
    expect(resolveLostOutcome(true)).toEqual({ setStatusVerloren: true });
    expect(resolveLostOutcome(false)).toEqual({ setStatusVerloren: false });
  });
});
