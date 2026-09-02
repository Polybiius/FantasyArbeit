# `src/features/` — ein Ordner pro Geschäftsbereich

Ein Ordner wird angelegt, wenn sein Bereich tatsächlich migriert wird
(Reihenfolge: `docs/migration-status.md`). Jeder Ordner bekommt ein
eigenes `README.md` (kurz, im selben Commit gepflegt).

Vorgesehene Bereiche (spiegeln das Domänen-Vokabular aus `CLAUDE.md`):

| Ordner | entspricht in der App |
|---|---|
| `einstellungen/` | Einstellungen — Pilot-Kandidat (Block 3/4), bereits registry-getrieben |
| `kanban/` | Questpfad / Gildenbrett / Feldzug |
| `kontakte/` | Arkanes Register / Kriegsarchiv / Jägerchronik (Kundendatenbank) |
| `dungeons/` | Betriebe / Accounts |
| `verkauf-statistik/` | Kompendium / Kriegskasse / Trophäenkammer |
| `kalender/` | Abenteuerlog (Kalender / Tagebuch / Termine) |
| `charakter/` | Charakterseite (Level, Sigil, Ausrüstung) |
| `gilde/` | Orden / Legion / Bund |
| `tagebuch/` | die 5 Tagebuch-Fragen + Foto |
| `admin/` | Produkte, Fehlerprotokoll, Notfallzugriff, Organisation, Löschanfragen |

**`kanban/` und `kontakte/` werden gemeinsam migriert** (eine Einheit) —
dabei entsteht die gemeinsame Kontakt-Karte in `shared/domain/`. Der
B2C→B2B-Aktions-Umbau folgt als eigener Schritt direkt danach.
