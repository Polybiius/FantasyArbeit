/**
 * Kanban-Übergangslogik als explizite, reine Zustandsmaschine (docs/adr/0007).
 *
 * Kein React, kein Netzwerk, kein DOM — bewusst framework-frei, damit sie
 * mit Vitest in Millisekunden erschöpfend testbar ist (siehe
 * kanbanTransitions.test.ts, alle 8×8 Spalten-Kombinationen). Das Verhalten
 * ist 1:1 aus `moveKanbanCard()`/`moveContactToGewonnenAndRecordSale()` in
 * der Vanilla-`index.html` übernommen und gegen den bestehenden Playwright-
 * "Kanban-Übergangs-Vertrag" (`tests/regression_suite.mjs`) abgeglichen —
 * beide Suiten müssen bei jeder künftigen Regelwerk-Änderung übereinstimmen.
 *
 * WICHTIGE ASYMMETRIE zwischen "Gewonnen" und "Verloren", bewusst so aus
 * dem echten Code übernommen (keine Vereinfachung/Bereinigung an dieser
 * Stelle — Block 5 friert das Verhalten bit-identisch ein):
 * - "Gewonnen": die Spalte wird nur bei einem WIRKLICH eingetragenen
 *   Produkt final gesetzt; wird das Verkaufs-Popup ohne Produkt
 *   geschlossen, springt die Karte auf die Herkunftsspalte zurück
 *   ("Revert-Pfad" — siehe Bugfix-Kommentar im echten Code). Dieser
 *   Zweig wird direkt in `kanbanMutations.ts` behandelt, VOR dem Aufruf
 *   von `resolveWonFunnelMarkers()` unten (Fund einer unabhängigen
 *   Zweitmeinung, 2026-09-05).
 * - "Verloren": die Spalte wird SOFORT und UNBEDINGT gesetzt (kein
 *   Revert) — nur ob `contacts.status` auf 'verloren' gesetzt wird, hängt
 *   vom Popup-Ausgang ab (`resolveLostOutcome`). Ebenso werden abgeleitete
 *   Trichter-Marken für "Verloren" SOFORT geloggt, unabhängig vom
 *   Popup-Ausgang.
 * - "Gewonnen": bei WIRKLICH eingetragenem Produkt wird `contacts.status`
 *   im echten Code VOR der Trichter-Prüfung auf 'kunde' gesetzt — ein
 *   Erstabschluss unterdrückt dadurch praktisch immer seine eigene Marke
 *   (`resolveWonFunnelMarkers`, Parameter `statusUpdateConflicted` deckt den
 *   seltenen Gegenfall ab, in dem genau dieser Status-Schreibvorgang
 *   fehlschlägt/kollidiert).
 */

export const KANBAN_STAGES = [
  'neuer_lead',
  'ersttermin_vereinbart',
  'angebot_versendet',
  'zweittermin',
  'nicht_erschienen',
  'gewonnen',
  'verloren',
  'dauerbrenner',
] as const;

export type KanbanStage = (typeof KANBAN_STAGES)[number];

/** Aktionen aus `rule_configs.config.actions`, die ein Kartenzug direkt auslösen kann. */
export type KanbanMainAction =
  | 'termin_nicht_wahrgenommen'
  | 'zweittermin_nicht_wahrgenommen'
  | 'kundenausbau'
  | 'termin_vereinbart'
  | 'pitch'
  | 'abschluss';

/** Abgeleitete Akquise-Trichter-Marken (0 XP, reine Zähl-Markierungen). */
export type KanbanFunnelMarker =
  | 'termin_wahrgenommen'
  | 'zweittermin_wahrgenommen'
  | 'zweittermin_vereinbart';

/** Optionale Zusatzaktionen aus `offerExtraAction()` (Bedarfsanalyse-Nachfrage bei Angebot/Zweittermin, vier Optionen bei Dauerbrenner) — freiwillig, nie Voraussetzung für den Kartenzug selbst. */
export type KanbanExtraAction = 'bedarfsanalyse' | 'pitch' | 'termin_wahrgenommen' | 'empfehlung';

/** Popups, die nach einem Zug erscheinen können — alle bis auf die beiden Verkaufs-Popups überspringbar. */
export type KanbanPopup =
  | 'bedarfsanalyse-optional'
  | 'termin-ersttermin'
  | 'termin-zweittermin'
  | 'dauerbrenner-optional';

export type KanbanSpecialFlow = 'none' | 'gewonnen' | 'verloren';

export interface KanbanTransitionContext {
  /** `contact.status === 'kunde'` — unterdrückt bei "true" ALLE drei Trichter-Marken (Bestandskunden-Betreuung zählt nicht als Erfolgsmessung). */
  isKunde: boolean;
  /** Wurde diese Marke für den Kontakt in diesem Geschäftsjahr schon geloggt? (Duplikat-Schutz) */
  hasFunnelMarkerThisYear: (marker: KanbanFunnelMarker) => boolean;
  /** Heute schon verbrauchtes Energie-Budget, siehe `config.energyMax - energyUsedToday()` im echten Code. */
  energyRemaining: number;
  /** Energie-Kosten einer Hauptaktion aus dem Regelwerk (`config.actions[key].energy`). */
  actionEnergyCost: (action: KanbanMainAction) => number;
}

export interface KanbanTransitionPlan {
  allowed: boolean;
  /** Nutzer-sichtbare Ablehnungs-Meldung (Alert-Text im Vanilla-Original), `null` wenn erlaubt. */
  rejectionReason: string | null;
  mainAction: KanbanMainAction | null;
  /** Sofort geloggte Marken — bei "Verloren" unabhängig vom Popup-Ausgang, bei allen anderen Zielspalten außer "Gewonnen" die einzige Quelle. */
  funnelMarkers: KanbanFunnelMarker[];
  /** NUR bei `specialFlow === 'gewonnen'` befüllt — Kandidaten, kein Versprechen: `resolveWonFunnelMarkers()` löst sie NUR im seltenen Konfliktfall ein (siehe dortige Dokumentation), im Normalfall eines Erstabschlusses bleiben sie stumm. */
  funnelMarkersIfWon: KanbanFunnelMarker[];
  popups: KanbanPopup[];
  specialFlow: KanbanSpecialFlow;
}

const ENERGY_REJECTION = 'Nicht genug Energie heute für diese Aktion.';
const NICHT_ERSCHIENEN_REJECTION =
  '"Nicht erschienen" ist nur vom Ersttermin oder Zweittermin aus erreichbar.';

function rejected(reason: string): KanbanTransitionPlan {
  return {
    allowed: false,
    rejectionReason: reason,
    mainAction: null,
    funnelMarkers: [],
    funnelMarkersIfWon: [],
    popups: [],
    specialFlow: 'none',
  };
}

/**
 * Entscheidet, was ein Kartenzug von `fromStage` nach `toStage` auslöst.
 * Deckt NICHT den Popup-Ausgang bei "Gewonnen"/"Verloren" ab — dafür
 * `resolveWonFunnelMarkers()`/`resolveLostOutcome()` NACH Bekanntwerden des
 * tatsächlichen Ausgangs aufrufen.
 */
export function decideKanbanTransition(
  fromStage: KanbanStage,
  toStage: KanbanStage,
  ctx: KanbanTransitionContext,
): KanbanTransitionPlan {
  if (
    toStage === 'nicht_erschienen' &&
    fromStage !== 'ersttermin_vereinbart' &&
    fromStage !== 'zweittermin'
  ) {
    return rejected(NICHT_ERSCHIENEN_REJECTION);
  }

  const fromTerminal = fromStage === 'gewonnen' || fromStage === 'verloren';
  const toActive =
    toStage === 'ersttermin_vereinbart' || toStage === 'angebot_versendet' || toStage === 'zweittermin';

  let mainAction: KanbanMainAction | null = null;
  if (toStage === 'nicht_erschienen') {
    mainAction = fromStage === 'zweittermin' ? 'zweittermin_nicht_wahrgenommen' : 'termin_nicht_wahrgenommen';
  } else if (fromTerminal && toActive) {
    // Reihenfolge wichtig: dieser Zweig greift VOR "toStage==='ersttermin_vereinbart'"
    // unten — ein zurückgewonnener Bestandskunde loggt "kundenausbau", nicht
    // "termin_vereinbart", obwohl das Ziel dasselbe ist.
    mainAction = 'kundenausbau';
  } else if (toStage === 'ersttermin_vereinbart') {
    mainAction = 'termin_vereinbart';
  } else if (toStage === 'angebot_versendet' || toStage === 'zweittermin') {
    mainAction = 'pitch';
  }
  // neuer_lead, dauerbrenner: keine Hauptaktion. "gewonnen"/"verloren" als
  // Ziel bekommen hier absichtlich KEINE Hauptaktion zugewiesen — "abschluss"
  // hängt bei "gewonnen" vom Popup-Ausgang ab (siehe resolveWonFunnelMarkers),
  // "verloren" hat gar keine eigene Hauptaktion ("Verloren ist verloren").

  // ">0"-Klausel bewusst wie im echten Code (Fund einer unabhängigen
  // Zweitmeinung, 2026-09-04): eine echt kostenlose Aktion darf NIE am
  // Budget scheitern, selbst wenn `energyRemaining` durch clientseitiges
  // Drift über mehrere Tabs/Geräte hinweg auf 0 oder knapp darunter steht
  // (siehe `logKanbanAction()`-Kommentar im echten Code, Fund vom
  // 2026-08-26). Ohne die Klausel würde ein 0-Energie-Übergang wie
  // "termin_nicht_wahrgenommen" fälschlich abgelehnt.
  if (mainAction && ctx.actionEnergyCost(mainAction) > 0 && ctx.actionEnergyCost(mainAction) > ctx.energyRemaining) {
    return rejected(ENERGY_REJECTION);
  }
  // "Gewonnen" hat einen EIGENEN, von obigem unabhängigen Energie-Check auf
  // "abschluss" (im echten Code: ganz am Anfang von
  // moveContactToGewonnenAndRecordSale(), vor jeder Datenbank-Änderung).
  if (
    toStage === 'gewonnen' &&
    ctx.actionEnergyCost('abschluss') > 0 &&
    ctx.actionEnergyCost('abschluss') > ctx.energyRemaining
  ) {
    return rejected(ENERGY_REJECTION);
  }

  const derivedFunnelMarkers: KanbanFunnelMarker[] = [];
  if (!ctx.isKunde) {
    const termWahrgenommenTargets: readonly KanbanStage[] = [
      'angebot_versendet',
      'zweittermin',
      'gewonnen',
      'verloren',
    ];
    if (
      fromStage === 'ersttermin_vereinbart' &&
      termWahrgenommenTargets.includes(toStage) &&
      !ctx.hasFunnelMarkerThisYear('termin_wahrgenommen')
    ) {
      derivedFunnelMarkers.push('termin_wahrgenommen');
    }
    if (
      fromStage === 'zweittermin' &&
      (toStage === 'gewonnen' || toStage === 'verloren') &&
      !ctx.hasFunnelMarkerThisYear('zweittermin_wahrgenommen')
    ) {
      derivedFunnelMarkers.push('zweittermin_wahrgenommen');
    }
    if (
      toStage === 'zweittermin' &&
      !fromTerminal &&
      !ctx.hasFunnelMarkerThisYear('zweittermin_vereinbart')
    ) {
      derivedFunnelMarkers.push('zweittermin_vereinbart');
    }
  }

  const popups: KanbanPopup[] = [];
  if (toStage === 'angebot_versendet') popups.push('bedarfsanalyse-optional');
  if (toStage === 'zweittermin') popups.push('bedarfsanalyse-optional', 'termin-zweittermin');
  if (toStage === 'ersttermin_vereinbart') popups.push('termin-ersttermin');
  if (toStage === 'dauerbrenner') popups.push('dauerbrenner-optional');

  if (toStage === 'gewonnen') {
    return {
      allowed: true,
      rejectionReason: null,
      mainAction: null,
      funnelMarkers: [],
      funnelMarkersIfWon: derivedFunnelMarkers,
      popups,
      specialFlow: 'gewonnen',
    };
  }
  if (toStage === 'verloren') {
    return {
      allowed: true,
      rejectionReason: null,
      mainAction: null,
      funnelMarkers: derivedFunnelMarkers,
      funnelMarkersIfWon: [],
      popups,
      specialFlow: 'verloren',
    };
  }
  return {
    allowed: true,
    rejectionReason: null,
    mainAction,
    funnelMarkers: derivedFunnelMarkers,
    funnelMarkersIfWon: [],
    popups,
    specialFlow: 'none',
  };
}

/**
 * Liefert die Trichter-Marken, die nach einem WIRKLICH abgeschlossenen
 * Verkauf ("Gewonnen") zu loggen sind. `funnelMarkersIfWon` kommt
 * unverändert aus `decideKanbanTransition()`.
 *
 * **Kein `saleRecorded`-Parameter mehr** (Fund einer unabhängigen
 * Zweitmeinung, 2026-09-05): die Vorfassung `resolveWonOutcome()` hatte
 * dafür einen eigenen Revert-Zweig, der beim tatsächlichen Aufrufer
 * (`kanbanMutations.ts`) nie erreicht wurde — der Revert-Pfad bei
 * fehlendem Produkt wird dort bereits VOR diesem Aufruf selbst behandelt
 * (eigener `lockedUpdate()`-Aufruf mit der Herkunftsspalte).
 *
 * `statusUpdateConflicted` (Fund einer unabhängigen Zweitmeinung,
 * 2026-09-04): im echten Code (`recordWinOrLoss()`) wird `contacts.status`
 * auf 'kunde' gesetzt, BEVOR die Trichter-Marken-Prüfung läuft — ein
 * Erstabschluss (Herkunft Ersttermin/Zweittermin, vorher noch nicht
 * Kunde) sieht sich zum Prüfzeitpunkt deshalb selbst schon als Kunde und
 * unterdrückt seine eigene Marke. Die Marke feuert nur in dem seltenen
 * Randfall, dass GENAU dieser Status-Schreibvorgang fehlschlägt oder mit
 * einer gleichzeitigen Änderung kollidiert (Sperr-Konflikt) — dann bleibt
 * `contact.status` auf dem alten Wert stehen, und die ursprünglich in
 * `funnelMarkersIfWon` versprochenen Marken lösen tatsächlich aus.
 */
export function resolveWonFunnelMarkers(
  statusUpdateConflicted: boolean,
  funnelMarkersIfWon: readonly KanbanFunnelMarker[],
): KanbanFunnelMarker[] {
  return statusUpdateConflicted ? [...funnelMarkersIfWon] : [];
}

export interface KanbanLostOutcome {
  setStatusVerloren: boolean;
}

/**
 * Löst den "Verloren"-Sonderfall nach bekanntem Popup-Ausgang auf. Die
 * Spalte selbst steht zu diesem Zeitpunkt bereits fest (kein Revert, siehe
 * Modul-Kommentar oben) — nur `contacts.status` hängt vom Ausgang ab.
 */
export function resolveLostOutcome(saleRecorded: boolean): KanbanLostOutcome {
  return { setStatusVerloren: saleRecorded };
}
