# Architecture Decision Records (ADR)

Ein ADR pro großer, teurer, schwer umkehrbarer Entscheidung. Diese Dateien
sind **append-only**: ein ADR wird nie rückwirkend umgeschrieben, sondern
höchstens durch ein neues, verweisendes ADR ersetzt (`Status: abgelöst
durch ADR-XXXX`).

Zweck: eine neue Arbeitssitzung (Mensch oder KI, ohne Gedächtnis der
Ursprungssitzung) soll in einer Datei sehen, *warum* etwas so ist — nicht
nur *dass* es so ist. `CLAUDE.md` verweist hierher statt die Begründungen
zu duplizieren.

Format je Datei: **Status · Kontext · Entscheidung · Konsequenzen ·
Verworfene Alternativen**.

| ADR | Titel | Status |
|-----|-------|--------|
| [0001](0001-react-migration.md) | Umstieg von Vanilla-`index.html` auf React | akzeptiert (2026-09-02) |
| [0002](0002-bruecke-session.md) | Koexistenz-Brücke: `window.__bridge` (Weg A) | akzeptiert (2026-09-02) |
| [0003](0003-hash-routing-vertrag.md) | Hash-Routing als stabiler, dokumentierter Vertrag | akzeptiert (2026-09-02) |
| [0004](0004-tanstack-query.md) | TanStack Query für den Supabase-Datenverkehr | akzeptiert (2026-09-02) |
| [0005](0005-ordnerstruktur-doku.md) | Feature-basierte Ordnerstruktur + vier Doku-Schubladen | akzeptiert (2026-09-02) |
| [0006](0006-styling-tailwind.md) | Styling-Grundlage: Tailwind (ohne Preflight) + shadcn-Stil | akzeptiert (2026-09-03) |
| [0007](0007-kanban-zustandsmaschine.md) | Kanban-Übergangslogik als explizite Zustandsmaschine | akzeptiert (2026-09-04) |
| [0008](0008-dnd-kit.md) | Drag & Drop via `dnd-kit` statt zwei parallelen Bedienwegen | akzeptiert (2026-09-04) |
| [0009](0009-realtime-kontakte.md) | Supabase Realtime für die geteilte Kontakte-Seite | akzeptiert (2026-09-04), RLS-Verifikation vor Produktivschaltung |
| [0010](0010-kontakte-paginierung-suche.md) | Kontakte: Cursor-Paginierung, Volltextsuche, Virtualisierung | akzeptiert (2026-09-04) |
| [0011](0011-zod-laufzeitvalidierung.md) | Laufzeit-Validierung (Zod) an RPC-/Lese-Grenzen | akzeptiert (2026-09-04) |
