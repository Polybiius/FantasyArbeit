# `src/shared/hooks/`

Wiederverwendbare React-Hooks, die bereichsübergreifend gebraucht werden.

| Hook | Zweck |
|---|---|
| `useCharacterClass()` | aktuelle Charakterklasse aus dem Vanilla-Profil (über die Brücke), aktualisiert bei Login/Logout. |

## Noch offen (folgende Block-2-Stücke)

- `useClickGuard()` — Doppelklick-/Doppel-Absende-Schutz (Entsprechung
  zu `withClickGuard()` im Vanilla-Code).
- Konfliktmeldung bei gleichzeitiger Bearbeitung (Entsprechung zu
  `alertConflict()`), zusammen mit dem Locked-Update-Wrapper.
- `useProfile()` — allgemeiner Profil-Zugriff, falls mehr als nur die
  Klasse gebraucht wird.
- Energie-Budget-Anzeige.
