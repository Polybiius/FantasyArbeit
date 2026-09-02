# ADR-0005 — Feature-basierte Ordnerstruktur + vier Doku-Schubladen

**Status:** akzeptiert (2026-09-02)
**Bezug:** ADR-0001 · Langfristigkeits-Abschnitt des Fahrplans

## Kontext

Die bestimmende Randbedingung ist nicht Teamgröße, sondern: **eine KI
arbeitet über viele getrennte Sitzungen ohne gemeinsames Gedächtnis**,
und der Stakeholder kann den Code nicht gegenlesen. Eine layer-basierte
Struktur (`components/`, `hooks/`, `pages/` als Top-Level) zwingt jede
Sitzung, drei bis vier Ordner zu öffnen, um einen Bereich zu verstehen.

`CLAUDE.md` (3.632 Zeilen) dokumentiert die App heute auf Funktions-/
Zeilen-Ebene — funktioniert nur, weil alles in einer Datei liegt. Nach
der Migration driftet eine solche zentrale Riesendatei zwangsläufig.

## Entscheidung

### Ordnerstruktur — feature-basiert

```
src/
  app/                 # Routing (Hash), Seitenrahmen/Vollbreite-Layout, globale Provider
  shared/
    ui/                # reine, unbestylte Radix/shadcn-Primitive — KEIN Geschäftswissen
    domain/            # Bausteine MIT Geschäftswissen, bereichsübergreifend genutzt
                       #   Leitbeispiel: die EINE gemeinsame Kontakt-Karte (kanban/ + kontakte/)
    design-tokens/     # Cinzel-Schrift, Klassenfarben, Radius-/Schatten-Werte
    hooks/             # useLockedUpdate, Konfliktmeldung, Doppelklick-Schutz, Energie-Budget
    lib/               # window.__bridge-Zugriff, error_log-Anbindung
    types/             # supabase-gen-types + handgeschriebene Domänentypen
  features/            # EIN Ordner pro Geschäftsbereich, spiegelt das CLAUDE.md-Vokabular
    kanban/ kontakte/ dungeons/ verkauf-statistik/ kalender/
    charakter/ gilde/ tagebuch/ einstellungen/ admin/
    (jeweils mit eigenem README.md)
public/                # Assets, die NICHT durch Vites Bundling laufen dürfen
                       #   Charakter-Sprite-Sheets (Laufzeit-String-Pfade!), fonts/*.woff2
docs/
  adr/                 # diese ADRs
  migration-status.md  # Bereich | Status (Vanilla/Migriert/In Arbeit) | Datum
```

**`shared/domain/` ist eine bewusste dritte Schublade** zwischen reinen
UI-Primitiven (kein Geschäftswissen) und bereichseigenen Komponenten —
sie verhindert, dass `features/kanban/` und `features/kontakte/`
künstlich aneinander gekoppelt werden, nur weil sie sich die
Kontakt-Karte teilen.

**`public/` statt `src/assets/` für Sprites + Fonts** ist zwingend:
`SHEETS_IMG_BASE` + `{g}`-Platzhalter werden zur Laufzeit als String
gebaut — Vites statische Asset-Analyse sieht das nicht und würde jeden
Hautton / jede Frisur zu einem 404 machen. Fonts bleiben lokal
(`.woff2`), niemals Google-Fonts-CDN (DSGVO — Standard-Setup-Vorlagen
von shadcn/Tailwind binden oft automatisch Google-Fonts-Links ein, das
ist aktiv zu entfernen).

### Doku — vier getrennte Schubladen

1. **`CLAUDE.md`** (Repo-Root) — **wechselt die Rolle**: reine Warum-/
   Konventions-/Verweis-Ebene (Geschäftsregeln, die im Code nicht
   sichtbar sind; projektweite Zwänge wie Locked-Update-RPCs,
   Escaping-Pflicht; Wegweiser). **Keine** Funktions-/Zeilen-Ebene mehr.
2. **`src/features/<bereich>/README.md`** — kurz, lebt neben dem Code,
   im selben Commit gepflegt.
3. **`docs/adr/NNNN-titel.md`** — append-only, ein Dokument pro großer
   Entscheidung.
4. **`docs/migration-status.md`** — sichtbare Tabelle, welcher Bereich
   noch Vanilla / migriert / in Arbeit ist. Verhindert, dass eine neue
   Sitzung in der falschen von zwei parallelen Implementierungen
   arbeitet.

`HISTORY.md` bleibt unverändert die reine Chronik.

## Konsequenzen

**Positiv:** eine Sitzung öffnet einen `features/`-Ordner und sieht alles
Relevante; Doku driftet weniger (kleine Dateien neben dem Code);
Entscheidungs-Historie ist nachlesbar.

**Negativ:** `CLAUDE.md` umzuschreiben ist eigener Aufwand (erst sinnvoll,
wenn genug migriert ist); die `shared/`-vs-`features/`-Grenze braucht
Disziplin, sonst wandert Geschäftswissen nach `shared/ui/`.

**Wichtig:** diese Struktur ist ein *sinnvoller Startpunkt*, kein
unantastbares Gesetz — bei tatsächlicher Umsetzung anpassbar, wenn sich
etwas als unpraktisch erweist.

## Verworfene Alternativen

- **Layer-basiert** (`components/`/`hooks/`/`pages/`) — zwingt zum
  Ordner-Springen, passt schlecht zu einer Sitzung ohne Gedächtnis.
- **Alles in `CLAUDE.md` weiterwachsen lassen** — driftet garantiert,
  sobald der Code auf viele Dateien verteilt ist.
- **`src/assets/` für Sprites** — 404 auf jeden Laufzeit-String-Pfad.
