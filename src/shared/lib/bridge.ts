import type { Session, SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/shared/types/supabase';

export type AppSupabaseClient = SupabaseClient<Database>;
export type Profile = Database['public']['Tables']['profiles']['Row'];
/** Rückgabeform von `log_action_for_self`/`grant_quest_bonus_to_self` — siehe `notifyActionLogged`. */
export type ActionLogRow = Database['public']['Functions']['log_action_for_self']['Returns'];

export type AuthChangeHandler = (event: string, session: Session | null) => void;

/**
 * Snapshot der Level-/XP-/Energie-Anzeige (ADR-0002-Nachtrag 3, Block 4).
 * Kommt fertig berechnet aus Vanillas `render()` -- React baut die
 * Level-Kurve/Energie-Formel NICHT selbst nach (Doppelpflege-Risiko),
 * sondern zeigt nur das bereits berechnete Ergebnis an.
 */
export interface CharacterStats {
  readonly level: number;
  readonly xpIntoLevel: number;
  readonly xpNeededForLevel: number;
  readonly totalXp: number;
  readonly energyUsed: number;
  readonly energyMax: number;
  readonly energyRemaining: number;
}

/**
 * Navigations-Zustand, der echte (teils asynchrone) Vanilla-Logik
 * braucht -- alle ANDEREN Sichtbarkeitsregeln (Admin-Rolle, Pool-Zustand)
 * liest der React-Sidebar direkt aus `getProfile()`, das sind einfache
 * Feldabfragen ohne eigenen Rechenweg.
 */
export interface NavState {
  /** Die von `showPage()` NACH allen Weiterleitungsregeln aufgelöste
   * Seite (ungültiger Hash, fehlende Admin-/Gildengründer-Rechte, Pool-
   * Zustand) -- z.B. `'charakter'`, niemals ein abgelehnter Wert. */
  readonly activePage: string;
  /** Ob die eingeloggte Person mindestens eine Gilde gegründet hat
   * (`guilds.founder_id`) -- steuert die Team-Reporting-Sichtbarkeit,
   * kommt aus einer eigenen DB-Abfrage, steht nicht in `profile`. */
  readonly isGuildFounder: boolean;
}

/**
 * Die Koexistenz-Brücke, die die produktive `index.html` unter
 * `window.__bridge` bereitstellt (docs/adr/0002). Der React-Teil liest
 * ausschließlich hierüber -- er erzeugt keinen eigenen Supabase-Client.
 * Von hier aus wird nur gelesen; alle Schreibpfade bleiben im Vanilla-Code.
 */
export interface AppBridge {
  /** Der EINE Supabase-Client, geteilt mit dem Vanilla-Code. */
  readonly sb: AppSupabaseClient;
  /**
   * Aktuelle Auth-Session. NUR LESEN — das Objekt gehört dem Vanilla-Code
   * (ADR-0002). `Readonly` verhindert versehentliches Schreiben von der
   * React-Seite; `window.__bridge` selbst ist zusätzlich `Object.freeze`d.
   */
  getSession(): Readonly<Session> | null;
  /** Profilzeile der eingeloggten Person. NUR LESEN, siehe `getSession`. */
  getProfile(): Readonly<Profile> | null;
  /**
   * Auf Login / Logout / Token-Refresh reagieren.
   * Gibt eine Abmelde-Funktion zurück.
   */
  onAuthChange(fn: AuthChangeHandler): () => void;
  /**
   * Einzige Ausnahme von "nur lesen" (ADR-0002-Nachtrag, Block 3): nach
   * einer erfolgreichen React-Mutation auf `profiles` wird das im
   * Vanilla-Code lebende `profile`-Objekt nachgezogen, damit beide
   * Hälften denselben Stand zeigen, ohne dass React direkt hineinschreibt
   * -- der Vanilla-Code bleibt der einzige Ort, der das Objekt wirklich
   * mutiert, React liefert nur den bereits vom Server bestätigten Patch.
   * Löst KEINE Re-Renders in React aus (das übernimmt TanStack Query).
   * Zwei Felder (`calendar_hide_weekends`/`calendar_show_birthdays`)
   * haben in Vanilla einen zusätzlichen Seiteneffekt (Kalender-Aufgaben
   * neu rendern, bei Geburtstagen zusätzlich einen Resync) -- den führt
   * die Vanilla-Implementierung dieser Funktion selbst aus, React weiß
   * davon nichts (siehe index.html-Kommentar an der Bridge-Definition).
   */
  notifyProfilePatch(patch: Partial<Profile>): void;
  /**
   * Einzige weitere Ausnahme von "nur lesen" (Block 4, Scharfschalten):
   * navigiert zur Tagebuch-Seite OHNE den Hash blind auf die bare Seite
   * zurückzusetzen -- bewahrt den von `updateCalendarHash()` gepflegten
   * Ansicht+Tag-Unterhash (`#tagebuch/woche/<datum>` usw.), genau wie es
   * der frühere Vanilla-Sidebar-Klick-Handler für "Abenteuerlog" tat.
   * Alle anderen Seiten navigieren über normale `<a href="#seite">`.
   */
  navigateToTagebuch(): void;
  /**
   * Dritte Ausnahme von "nur lesen" (Block 5, Kanban-Schreibpfad).
   * React ruft für eine Kanban-Aktion dieselben `SECURITY DEFINER`-RPCs
   * auf wie Vanilla selbst (`log_action_for_self`/
   * `grant_quest_bonus_to_self`) — die zurückgelieferten Zeilen werden
   * NICHT von React interpretiert (keine zweite XP-/Quest-Berechnung,
   * Doppelpflege-Risiko), sondern hier eingereicht. Vanilla reiht sie in
   * seinen eigenen `log`-Puffer ein, prüft Quests und rendert neu —
   * exakt dieselben drei Schritte, die `logAction()`/
   * `flushKanbanActionPost()` nach ihren eigenen RPC-Aufrufen sowieso
   * ausführen. Löst danach `onStatsChange` aus wie jeder normale
   * Vanilla-Render-Lauf. Reihenfolge egal, `null`-Einträge werden
   * ignoriert (Aufrufer kann z.B. eine bewusst ausgelassene, optionale
   * Aktion einfach mit `null` an derselben Stelle mitgeben).
   */
  notifyActionLogged(rows: ReadonlyArray<ActionLogRow | null>): Promise<void>;
  /**
   * Aktueller Level-/XP-/Energie-Snapshot, oder `null` vor dem ersten
   * `render()`-Lauf (z.B. während des Logins). Zusammen mit
   * `onStatsChange` bewusst im `useSyncExternalStore`-Vertrag gehalten
   * (subscribe ohne Nutzlast + separater Snapshot-Getter) -- siehe
   * `useCharacterStats()`.
   */
  getCharacterStats(): Readonly<CharacterStats> | null;
  /**
   * Wird nach JEDEM Vanilla-`render()`-Lauf aufgerufen (deckt damit alle
   * ~9 Aufrufstellen automatisch ab). Der Callback bekommt keine
   * Nutzlast -- neu lesen über `getCharacterStats()`. Gibt eine
   * Abmelde-Funktion zurück.
   */
  onStatsChange(fn: () => void): () => void;
  /** Immer verfügbar (sinnvoller Default schon vor dem ersten Login,
   * passend zur statischen HTML). Siehe `NavState`. */
  getNavState(): Readonly<NavState>;
  /** Feuert nach jedem `showPage()`-Aufruf und nach jedem Neuladen des
   * Gildengründer-Status. Kein Payload, siehe `onStatsChange`. */
  onNavChange(fn: () => void): () => void;
}

declare global {
  interface Window {
    readonly __bridge?: AppBridge;
  }
}

/**
 * Zugriff auf `window.__bridge`. Wirft mit klarer Meldung, wenn sie fehlt
 * -- dann läuft der React-Code außerhalb der produktiven `index.html`
 * (z.B. der Vite-Einstieg `app.html` ohne den Vanilla-Bundle).
 */
export function getBridge(): AppBridge {
  const b = window.__bridge;
  if (!b) {
    throw new Error(
      'window.__bridge nicht verfügbar. Der React-Code muss innerhalb der ' +
        'produktiven index.html laufen (siehe docs/adr/0002).',
    );
  }
  return b;
}

/** Kurzform für den geteilten Supabase-Client. */
export function sb(): AppSupabaseClient {
  return getBridge().sb;
}
