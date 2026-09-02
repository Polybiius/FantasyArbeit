import type { Session, SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/shared/types/supabase';

export type AppSupabaseClient = SupabaseClient<Database>;
export type Profile = Database['public']['Tables']['profiles']['Row'];

export type AuthChangeHandler = (event: string, session: Session | null) => void;

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
