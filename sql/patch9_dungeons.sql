-- ============================================================
-- PATCH 9 — Dungeons (Orte auf der Karte)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- 1) Orte. "type" ist generisch (z.B. "krankenhaus"), damit sich das
--    Konzept 1:1 auf andere Branchen übertragen lässt — Aussehen
--    (Icon/Label) kommt aus dem Regelwerk, nicht aus dem Code.
create table public.locations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  type text not null,
  lat double precision not null,
  lng double precision not null,
  address text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.locations enable row level security;

create policy "locations_select_org" on public.locations
  for select using (org_id = public.current_org_id());

create policy "locations_insert_admin_only" on public.locations
  for insert with check (org_id = public.current_org_id() and public.is_admin());

create policy "locations_update_admin_only" on public.locations
  for update using (org_id = public.current_org_id() and public.is_admin());

create policy "locations_delete_admin_only" on public.locations
  for delete using (org_id = public.current_org_id() and public.is_admin());

-- 2) Aktions-Log bekommt einen optionalen Verweis auf einen Ort.
--    Das macht Quest-Ketten robuster: statt Freitext-Vergleich
--    ("Klinikum" vs. "klinikum" vs. Tippfehler) zählen wir jetzt
--    eindeutige IDs.
alter table public.action_log add column if not exists location_id uuid references public.locations(id) on delete set null;

-- 3) Beispiel-Ortstyp ins Regelwerk eintragen (Krankenhaus).
--    Neue Typen später einfach im Admin-Bereich der App im
--    "items"-artigen Muster ergänzen — kein SQL mehr nötig.
update public.rule_configs
set config = config || '{
  "locationTypes": {
    "krankenhaus": { "label": "Krankenhaus", "icon": "🏥" }
  }
}'::jsonb
where org_id = '00000000-0000-0000-0000-000000000001';
