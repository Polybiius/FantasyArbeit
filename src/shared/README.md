# `src/shared/` — bereichsübergreifend genutzt

Unterordner werden angelegt, sobald der erste echte Inhalt hineinkommt
(meist mit Block 2/3). Gedachte Aufteilung (`docs/adr/0005`):

| Ordner | Inhalt | Grenze |
|---|---|---|
| `ui/` | reine, unbestylte Radix/shadcn-Bausteine (Button, Dialog, …) | **KEIN Geschäftswissen.** Weiß nichts von Kontakten, Kanban, XP. |
| `domain/` | Bausteine MIT Geschäftswissen, aber von mehreren `features/` genutzt | Leitbeispiel: die **eine** gemeinsame Kontakt-Karte (von `kanban/` UND `kontakte/`). Verhindert, dass die beiden Feature-Ordner künstlich aneinander gekoppelt werden. |
| `design-tokens/` | Cinzel-Schrift, die drei Klassenfarben, Radius-/Schatten-Werte | Quelle der Wahrheit für alles Farbige. Entsteht mit dem Styling-Spike (`docs/adr` 0006). |
| `hooks/` | `useLockedUpdate` (optimistisches Sperren), Konfliktmeldung, Doppelklick-Schutz, Energie-Budget | die React-Entsprechungen der Vanilla-Helfer (`withClickGuard`, `alertConflict`), kommen in Block 2. |
| `lib/` | Zugriff auf `window.__bridge` (Supabase-Client + Session), `error_log`-Anbindung | die einzige Stelle, die die Brücke zum Vanilla-Code kennt (`docs/adr/0002`). |
| `types/` | `supabase gen types`-Ausgabe + handgeschriebene Domänentypen | generierte Datei nie von Hand ändern. |
