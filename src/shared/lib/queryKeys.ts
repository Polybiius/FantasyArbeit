/**
 * Zentrale Query-Key-Fabrik (docs/adr/0004).
 *
 * REGELN — gelten für jedes `useQuery` / `useMutation` im React-Teil:
 *
 * 1. **Kein Key wird inline gebildet.** Immer über `qk.*`. So stehen alle
 *    Keys an einer Stelle und Invalidierung ist nachvollziehbar.
 *
 * 2. **Hierarchisch:** `[bereich, entität, ...verfeinerung]`. Dadurch
 *    trifft `queryClient.invalidateQueries({ queryKey: qk.kontakte.all() })`
 *    alle Kontakt-Queries auf einmal, ein spezifischerer Key nur seine.
 *
 * 3. **Sichtbarkeit gehört IN den Key.** Das mehrschichtige Modell
 *    (privat / Gilden-geteilt / Org-Pool / Admin-Notfallzugriff, siehe
 *    CLAUDE.md) liefert je Sicht ANDERE Zeilen. Wird die Sicht nicht Teil
 *    des Keys, überschreiben sich die Caches gegenseitig und ein Nutzer
 *    sieht kurz fremde/falsche Daten. Deshalb: der letzte Key-Teil einer
 *    Liste ist ein Objekt mit allen Filter-/Sicht-Parametern
 *    (`{ scope, guildId, page, ... }`).
 *
 * 4. **`mutationKey` nach demselben Muster** — er landet in den
 *    `mutationCache.onError`-Meldungen (Fehlerprotokoll) und erlaubt
 *    gezieltes Invalidieren.
 *
 * 5. **Invalidierung eng scopen.** Nach einer Mutation nur den betroffenen
 *    Teilbaum invalidieren (z.B. `qk.kontakte.detail(id)`), nicht
 *    `qk.kontakte.all()` — sonst wird der im Vanilla längst gefixte
 *    "alles neu laden nach jeder Änderung"-Bug im neuen Stack reproduziert.
 */

/** Sicht-Parameter, die als letzter Key-Teil einer Liste mitgegeben werden. */
export interface ListScope {
  /** 'own' = nur eigene, 'guild' = Gilden-geteilt, 'orgPool' = herrenlos, 'emergency' = Notfallzugriff. */
  scope: 'own' | 'guild' | 'orgPool' | 'emergency';
  guildId?: string;
  page?: number;
}

export const qk = {
  // --- Pilot (Block 3) ---
  einstellungen: {
    all: () => ['einstellungen'] as const,
    /** eigenes Profil + Regelwerk-abgeleitete Registry-Werte */
    self: () => ['einstellungen', 'self'] as const,
  },

  // --- Beispiel für die Sicht-in-den-Key-Regel; wird in Block 5 real ---
  kontakte: {
    all: () => ['kontakte'] as const,
    list: (scope: ListScope) => ['kontakte', 'list', scope] as const,
    detail: (id: string) => ['kontakte', 'detail', id] as const,
  },

  // Weitere Bereiche (kanban, kalender, statistik, ...) ergänzen ihre
  // Einträge in ihrem jeweiligen Migrations-Block nach demselben Muster.
} as const;
