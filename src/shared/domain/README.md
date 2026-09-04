# `domain/` — Bausteine mit Geschäftswissen, bereichsübergreifend

Dritte Schublade zwischen `shared/ui/` (kein Geschäftswissen) und
`features/*/` (genau ein Bereich) — siehe `docs/adr/0005` und
`src/shared/README.md`.

## `contactCard/`

Die **eine** gemeinsame Kontakt-Karte, geplant für `features/kanban/`
UND `features/kontakte/` (Block-5-Ziel, siehe
`docs/migration-status.md`) — löst die im Vanilla-Code dokumentierte
Mehrfach-Duplikation (Kanban-Karte, Kontakttabelle, Kanban-
Kurzvorschau sind dort drei/vier unabhängige Rendering-Stellen).

Bisher nur die `'kanban'`-Variante gebaut (1:1 gegen die echte
Vanilla-Karte, `index.html` `.kanban-card`/`.kc-name`/`.kc-meta` —
Name als Link auf `#kontakt/<id>`, optional der Betriebsname darunter).
Weitere Varianten (`'table'` für die Kontakttabelle, `'preview'` für
die Kanban-Kurzvorschau) kommen erst, wenn der jeweilige Bereich
tatsächlich dran ist — kein Vorgriff auf Felder, die noch niemand
braucht (Rule of Three).
