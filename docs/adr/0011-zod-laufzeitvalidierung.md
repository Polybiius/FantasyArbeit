# ADR-0011 — Laufzeit-Validierung (Zod) an RPC-/Lese-Grenzen

**Status:** akzeptiert (2026-09-04)
**Bezug:** ADR-0001 · ADR-0004 (TanStack Query) · `supabase gen types`-
Disziplin (Fahrplan)

## Kontext

`supabase gen types typescript --linked` liefert TypeScript-Typen —
die schützen nur zur **Kompilierzeit**. Bei diesem Projekt ändert sich
das Datenbankschema sehr häufig (100+ Migrationen bereits, siehe
CLAUDE.md). Driftet eine Migration von dem ab, was das Frontend
erwartet (umbenanntes RPC-Feld, geänderter Rückgabetyp), fällt das
bisher erst als stiller `undefined` irgendwo tiefer im Rendering auf —
nicht als sofortiger, sprechender Fehler an der eigentlichen Grenze.
React Hook Form + Zod ist im Fahrplan bereits für Formulareingaben
gesetzt (ADR-0001-Umfeld) — dieselbe Technik fehlt bisher auf der
**Lese-/RPC-Antwort-Seite**.

## Entscheidung

Zod-Schemas für die Datenformen, die die Supabase-Grenze überqueren
(Rückgaben der sechs `*_locked`-Funktionen, `log_action_for_self`,
`grant_quest_bonus_to_self`, zentrale Lese-Modelle wie Kontakt-/
Verkaufszeilen) werden **von Hand parallel zu den generierten
TypeScript-Typen gepflegt** (kein automatisches Zod-aus-Postgres-
Tooling — dafür zu unausgereift für diesen Maßstab) und bei jeder
TanStack-Query-Abfrage/-Mutation an der Antwortgrenze ausgewertet.

## Konsequenzen

**Positiv:** Schema-Drift wird zum sofortigen, konkret benennbaren
Laufzeitfehler ("Feld X fehlt/hat falschen Typ") an der Stelle, wo er
entsteht — nicht zu stillen Falschdaten drei Komponenten weiter unten.
Ergänzt `supabase gen types` sauber, ohne es zu ersetzen.

**Negativ:** Schemas müssen bei jeder schemaändernden Migration bewusst
mitgepflegt werden (zusätzlicher, disziplinierter Schritt neben der
ohnehin schon geplanten Typgenerierung) — kein Automatismus, der das
von selbst erkennt.

## Verworfene Alternativen

- **Nur TypeScript-Typen, keine Laufzeitprüfung** — Status quo des
  Plans; schützt nicht vor Drift zwischen echter DB und generierten
  Typen zwischen zwei `gen:types`-Läufen.
- **Volles automatisches Zod-aus-Postgres-Codegen** — Werkzeuglandschaft
  dafür noch nicht robust genug, Setup-Aufwand steht in keinem
  Verhältnis zum Nutzen bei diesem Team/Maßstab.
