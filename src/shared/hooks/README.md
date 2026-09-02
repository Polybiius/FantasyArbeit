# `src/shared/hooks/`

Wiederverwendbare React-Hooks, die bereichsübergreifend gebraucht werden.

| Hook | Zweck |
|---|---|
| `useCharacterClass()` | aktuelle Charakterklasse aus dem Vanilla-Profil (über die Brücke), aktualisiert bei Login/Logout. |
| `useGuardedAction(fn)` | Doppelklick-Schutz für schreibende Aktionen (Entsprechung zu `withClickGuard()`). Liefert `{ pending, run }`. |

Konfliktbehandlung bei gleichzeitiger Bearbeitung liegt in
`src/shared/lib/` (`notifyConflict`, `rpcLockedUpdate`, `lockedUpdate`) —
das sind reine Funktionen ohne React-Zustand.

## Noch offen

- `useProfile()` — allgemeiner Profil-Zugriff, falls mehr als die Klasse
  gebraucht wird.
- Energie-Budget-Anzeige.
- Toast-System (ersetzt das `window.alert` in `notifyConflict`) — kommt
  mit dem Styling-Spike (`docs/adr` 0006).
