# ADR-0009 — Supabase Realtime für die geteilte Kontakte-Seite

**Status:** akzeptiert (2026-09-04), **Realtime-RLS-Verifikation ist
Bedingung vor Produktivschaltung**
**Bezug:** ADR-0001 · ADR-0004 (TanStack Query) · Block-5-Vorbereitung ·
Mandantenmodell Pool → Organisation → mehrere Gilden

## Kontext

Kontakte sind gilden-/org-geteilt (Phase-1-Sichtbarkeitsmodell,
`guild_contact_permission()`). Bearbeitet ein Kollege einen gemeinsamen
Kontakt, sieht das Gegenüber die Änderung aktuell erst nach manuellem
Neuladen. Supabase bringt Realtime (`postgres_changes`-Abos) bereits
mit, ungenutzt — die Infrastruktur kostet nichts extra.

**Kanban ist davon ausdrücklich ausgenommen:** Kanban ist laut CLAUDE.md
strikt die persönliche Vertriebspipe, kein Gilden-Blick — dort gibt es
keinen Kollaborations-Bedarf, den Realtime lösen würde.

**Der entscheidende Vorbehalt:** das Mandantenmodell hat mehrere Ebenen
(Pool → Organisation → mehrere Gilden je Organisation, plus Org-Pool/
Admin-Notfallzugriff). Ein Realtime-Kanal, der dieselben RLS-Regeln
nicht nachweislich durchsetzt wie normale PostgREST-Abfragen, wäre ein
Cross-Tenant-Datenleck — exakt die Fehlerklasse, die der bestehende
Org-Grenze-Audit (CLAUDE.md, 2026-08-28/2026-09-01) für die REST-Seite
bereits zweimal geschlossen hat.

## Entscheidung

Supabase Realtime (`postgres_changes` auf `contacts`) wird für die
React-Kontakte-Seite eingeführt — **erst nach einem expliziten
Verifikationsschritt**, der mit derselben Disziplin wie der
Org-Grenze-Audit durchgeführt wird: ein Dry-Run mit zwei echten
Testprofilen aus unterschiedlichen Organisationen, der bestätigt, dass
ein Realtime-Event für Organisation A niemals bei einem Client sitzt,
der zu Organisation B gehört. Erst danach geht die Funktion live.

Realtime-Events patchen den bestehenden TanStack-Query-Cache gezielt
(dieselbe Regel wie bei Mutations, ADR-0004: kein Voll-Neuladen), nicht
als zweiter, paralleler State neben der Query-Cache.

## Konsequenzen

**Positiv:** echter Kollaborations-Mehrwert bei praktisch keinen
Zusatzkosten (Infrastruktur ist schon vorhanden) — der Unterschied
zwischen "spürt sich nach migrierter Alt-App an" und "spürt sich nach
einem echten, lebendigen Produkt an".

**Negativ:** zusätzlicher bewegter Teil (WebSocket-Verbindungslebenszyklus,
Reconnect-Verhalten); der Verifikationsschritt ist ein Pflicht-Gate, kein
"kann man später nachholen" — bis er nicht grün ist, bleibt Realtime
aus, die Seite funktioniert dann einfach wie gehabt (reines Refetch).

## Verworfene Alternativen

- **Intervall-Polling statt Realtime** — einfacher, kein RLS-auf-Kanal-
  Risiko, aber spürbar schlechtere Nutzererfahrung und unnötige Last bei
  mehreren gleichzeitig offenen Tabs.
- **Kein Realtime** — sicherste Wahl, verschenkt aber einen echten,
  günstigen Gewinn, den der bestehende Stack bereits mitbringt.
- **Realtime auch für Kanban** — verworfen, da Kanban laut Produktprinzip
  nicht gilden-geteilt ist; es gäbe nichts zu synchronisieren.
