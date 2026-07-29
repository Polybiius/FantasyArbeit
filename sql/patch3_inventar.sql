-- ============================================================
-- PATCH 3 — Inventar
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

create table public.user_inventory (
  user_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  item_key text not null,
  quantity integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, item_key)
);

alter table public.user_inventory enable row level security;

create policy "inventory_select_own" on public.user_inventory
  for select using (user_id = auth.uid());

create policy "inventory_insert_own" on public.user_inventory
  for insert with check (user_id = auth.uid());

create policy "inventory_update_own" on public.user_inventory
  for update using (user_id = auth.uid());

-- Manatrank als erster Gegenstand im Regelwerk ergänzen.
-- (Das komplette Regelwerk liegt als JSON in rule_configs.config —
--  dieser Befehl fügt nur den neuen "items"-Schlüssel hinzu, ohne
--  den Rest der Konfiguration anzufassen.)
update public.rule_configs
set config = config || '{
  "items": {
    "mana_trank": {
      "label": "Manatrank",
      "category": "consumables",
      "icon": "🧪",
      "effect": "full_energy_refill",
      "description": "Füllt die Manareserve für heute vollständig auf."
    }
  }
}'::jsonb
where org_id = '00000000-0000-0000-0000-000000000001';
