-- ============================================================
-- PATCH 7 — Freunde (unabhängig von Gilden)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

create table public.friends (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, friend_id)
);

alter table public.friends enable row level security;

-- Jeder verwaltet nur seine eigene Freundesliste.
create policy "friends_select_own" on public.friends
  for select using (owner_id = auth.uid());

create policy "friends_insert_own" on public.friends
  for insert with check (owner_id = auth.uid());

create policy "friends_delete_own" on public.friends
  for delete using (owner_id = auth.uid());
