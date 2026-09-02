# ADR-0004 — TanStack Query für den Supabase-Datenverkehr

**Status:** akzeptiert (2026-09-02)
**Bezug:** ADR-0001 · Fund aus dem blinden Review ("kein austauschbares Kleingeld")

## Kontext

Der Vanilla-Code lädt Supabase-Daten mit handgeschriebenen `async`-
Funktionen und pflegt Aktualität von Hand. Zwei wiederkehrende
Bug-Muster (mehrfach in 5-Linsen-Reviews von Kanban und Dungeons real
gefunden):

- **vergessenes Refetch** nach einer Änderung (Stale-UI),
- **übertriebenes Voll-Neuladen** (`render()` baut das ganze Board neu
  nach jedem einzelnen Kartenzug).

Der Plan behandelte die Werkzeugwahl zunächst als "austauschbares
Kleingeld". Für TanStack Query stimmt das **nicht**: die Query-Key-
Struktur *ist* die Datenfluss-Architektur, und sie muss das
mehrschichtige Sichtbarkeitsmodell abbilden (privat / Gilden-geteilt /
Org-Pool / Admin-Notfallzugriff). Ein Wechsel nach Block 4 wäre ein
Neuschrieb.

## Entscheidung

**TanStack Query** ist die verbindliche Schicht für lesenden und
schreibenden Supabase-Verkehr im React-Teil.

- **Query-Key-Design ist ein eigener Arbeitsschritt**, kein
  Nebenprodukt. Keys tragen den Sichtbarkeits-Kontext, damit
  Cache-Einträge verschiedener Ebenen sich nicht überschreiben.
- **Mutation-Invalidierung wird eng gescoped** — nur die eine geänderte
  Entität invalidieren (die verschobene Kanban-Karte), nicht die ganze
  Liste. Sonst wird der bereits gefixte "Voll-Rebuild"-Bug im neuen
  Stack reproduziert.
- **Keine naiven `optimistic updates`.** Die serverseitige
  `updated_at`-Sperr-Logik (SECURITY-DEFINER-RPCs für contacts/
  locations/sales/termine) ist die Wahrheit; ein optimistisches
  Vorgreifen im Client würde ihr widersprechen. Mutations warten auf die
  echte Server-Antwort.
- **`onError` global** an die bestehende `error_log`-Konvention routen
  (siehe ADR-0002-naher Error-Boundary-Ansatz — separat zu
  spezifizieren).

## Konsequenzen

**Positiv:** die zwei Bug-Muster verschwinden strukturell; Caching/
Retry/Dedup gratis; Lade-/Fehlerzustände einheitlich.

**Negativ:** Query-Key-Konvention muss diszipliniert eingehalten werden
(ESLint kann das nur begrenzt erzwingen); Lernkurve für das
Sichtbarkeits-Mapping.

## Verworfene Alternativen

- **Weiter handgeschriebene Lade-Funktionen** — genau das Muster, das
  die Bugs erzeugt.
- **SWR** — kleiner, aber schwächeres Mutation-/Invalidierungs-Modell,
  das hier der Kern ist.
- **RTK Query / Redux** — zu viel Apparat für 10–15 Nutzer/Org; kein
  sonstiger Redux-Bedarf.
