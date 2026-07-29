-- ============================================================
-- PATCH 14 — Betrieb direkt aus der Kundendatenbank anlegen
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- 1) Strukturierte Adressfelder ergänzen (zusätzlich zum bestehenden
--    "address"-Freitext, der fürs Geocoding gebraucht wird).
alter table public.locations add column if not exists plz text;
alter table public.locations add column if not exists strasse text;
alter table public.locations add column if not exists stadt text;

-- 2) Anlegen eines neuen Betriebs darf künftig JEDES Team-Mitglied,
--    nicht mehr nur der Admin — man legt ihn schließlich meist genau
--    in dem Moment an, in dem man live vor Ort einen neuen Kontakt
--    erfasst. Umverteilen (Pool-Verwaltung) bleibt weiterhin Admin-Sache,
--    diese Regel bleibt unverändert bestehen.
drop policy if exists "locations_insert_admin_only" on public.locations;
create policy "locations_insert_org_members" on public.locations
  for insert with check (org_id = public.current_org_id());

-- 3) Zweiten Ortstyp "Niederlassung" ergänzen, zusätzlich zu Krankenhaus.
update public.rule_configs
set config = jsonb_set(
  config, '{locationTypes,niederlassung}',
  '{"label": "Niederlassung", "icon": "🏢"}'::jsonb
)
where org_id = '00000000-0000-0000-0000-000000000001';
