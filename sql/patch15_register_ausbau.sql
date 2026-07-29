-- ============================================================
-- PATCH 15 — Register-Ausbau: Wohnort, Kontaktdaten, Berufsstatus
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

alter table public.contacts add column if not exists geburtsdatum date;
alter table public.contacts add column if not exists telefon text;
alter table public.contacts add column if not exists email text;
alter table public.contacts add column if not exists wohnort_strasse text;
alter table public.contacts add column if not exists wohnort_ort text;

-- Vollständige Berufsstatus-Liste ersetzt die bisherige (kurze) Liste.
update public.rule_configs
set config = jsonb_set(
  config, '{contactRoles}',
  '{
    "assistenzarzt": "Assistenzarzt",
    "facharzt": "Facharzt",
    "oberarzt": "Oberarzt",
    "oberarzt_leitend": "Oberarzt mit leitender Funktion",
    "chefarzt": "Chefarzt",
    "niedergelassen": "Niedergelassen",
    "freiberuflich": "Freiberuflich"
  }'::jsonb
)
where org_id = '00000000-0000-0000-0000-000000000001';
