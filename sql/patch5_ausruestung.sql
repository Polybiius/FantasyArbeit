-- ============================================================
-- PATCH 5 — Ausrüstungs-Slots (Anlegen/Ablegen)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

alter table public.profiles add column if not exists equipped_weapon text;
alter table public.profiles add column if not exists equipped_armor text;
alter table public.profiles add column if not exists equipped_accessory text;

-- Hinweis: Diese Felder verweisen auf einen item_key aus dem
-- "items"-Katalog im Regelwerk (rule_configs.config). Sobald ein
-- Item dort ein "image"-Feld bekommt (URL zu einem freigestellten
-- PNG, z.B. später KI- oder illustratorgeneriert), zeigt die
-- Charakterseite es automatisch als Ebene über der Basisfigur an —
-- ohne dass am Code noch etwas geändert werden muss.
