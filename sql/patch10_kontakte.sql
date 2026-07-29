-- ============================================================
-- PATCH 10 — Kontakte (Arkanes Register / Kriegsarchiv / Jägerchronik)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  role text,
  location_id uuid references public.locations(id) on delete set null,
  status text not null default 'kalt' check (status in ('kalt','warm','kunde','verloren')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Verknüpfung zum Aktions-Log: jede Handlung kann optional einem
-- konkreten Kontakt zugeordnet werden (zusätzlich zum bestehenden Ort).
alter table public.action_log add column if not exists contact_id uuid references public.contacts(id) on delete set null;

alter table public.contacts enable row level security;

-- Hilfsfunktion: liest die Sichtbarkeits-Einstellung der Organisation
-- aus dem Regelwerk (rule_configs.config->>'contactsVisibility').
create or replace function public.contacts_shared_for_org()
returns boolean
language sql security definer stable
as $$
  select coalesce(
    (select config->>'contactsVisibility' from public.rule_configs where org_id = public.current_org_id()) = 'shared',
    false
  )
$$;

create policy "contacts_select_own_or_shared_or_admin" on public.contacts
  for select using (
    owner_id = auth.uid()
    or public.is_admin()
    or (org_id = public.current_org_id() and public.contacts_shared_for_org())
  );

create policy "contacts_insert_own" on public.contacts
  for insert with check (owner_id = auth.uid() and org_id = public.current_org_id());

create policy "contacts_update_owner_or_admin" on public.contacts
  for update using (owner_id = auth.uid() or public.is_admin());

create policy "contacts_delete_owner_or_admin" on public.contacts
  for delete using (owner_id = auth.uid() or public.is_admin());

-- Standard-Rollen ins Regelwerk eintragen (frei erweiterbar, wie bei Items/Aktionen)
update public.rule_configs
set config = config || '{
  "contactsVisibility": "private",
  "contactRoles": {
    "assistenzarzt": "Assistenzarzt",
    "oberarzt": "Ober-/Chefarzt",
    "sonstige": "Sonstige"
  }
}'::jsonb
where org_id = '00000000-0000-0000-0000-000000000001';
