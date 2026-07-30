-- ============================================================
-- PATCH 19 — Kanban ist opt-in, nicht automatisch
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
--
-- Fehler in Patch 18: kanban_stage wurde "not null default 'neuer_lead'"
-- angelegt — dadurch ist JEDER bereits bestehende Kontakt beim Anlegen
-- der Spalte automatisch als "Neuer Lead" im Kanban aufgetaucht, nur
-- weil er in der Datenbank existiert. Das ist falsch: in der Datenbank
-- zu stehen bedeutet nicht automatisch, Teil der Verkaufs-Pipeline zu
-- sein. Ein Kontakt landet im Kanban nur über einen der bewusst dafür
-- gebauten Wege ("+ Neuer Lead" im Board, "Termin vereinbart" am
-- Dungeon, oder manuell im Kontaktformular ausgewählt) — nicht einfach
-- dadurch, dass er existiert.
--
-- NULL bedeutet ab jetzt: "kein Kanban-Kontakt, taucht im Board gar
-- nicht auf" statt "Neuer Lead".
-- ============================================================

alter table public.contacts alter column kanban_stage drop not null;
alter table public.contacts alter column kanban_stage drop default;

-- Alle bestehenden Kontakte zurücksetzen — sie wurden durch den
-- fehlerhaften Default aus Patch 18 unfreiwillig zu "Neuer Lead".
update public.contacts set kanban_stage = null;
