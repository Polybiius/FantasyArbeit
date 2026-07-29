-- ============================================================
-- PATCH 6 — Gilde / Orden / Legion / Bund
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- 1) Level-Cache am Profil. Warum nötig: XP-Logs sind privat pro
--    Nutzer (RLS erlaubt nur eigene Einsicht). Damit man trotzdem
--    das LEVEL von Gildenmitgliedern sehen kann, ohne an deren
--    private Logs zu müssen, hält jeder Nutzer selbst diese zwei
--    Werte aktuell — sie werden clientseitig nach jeder Berechnung
--    aktualisiert.
alter table public.profiles add column if not exists total_xp integer not null default 0;
alter table public.profiles add column if not exists level integer not null default 1;

-- 2) Gilden. Jede Organisation kann mehrere Gilden haben.
create table public.guilds (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  founder_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- 3) Mitgliedschaft. Ein Nutzer ist immer in höchstens EINER Gilde
--    (member_id ist Primärschlüssel) — passt zum Prinzip:
--    man tritt bei oder gründet, man "addet" nicht als Einzelperson.
create table public.guild_members (
  member_id uuid primary key references public.profiles(id) on delete cascade,
  guild_id uuid not null references public.guilds(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  joined_at timestamptz not null default now()
);

alter table public.guilds enable row level security;
alter table public.guild_members enable row level security;

-- Gilden: alle in der Organisation dürfen sehen, welche Gilden es gibt
-- (sonst könnte niemand einer beitreten). Gründen darf jeder für sich selbst.
create policy "guilds_select_org" on public.guilds
  for select using (org_id = public.current_org_id());

create policy "guilds_insert_self_founder" on public.guilds
  for insert with check (org_id = public.current_org_id() and founder_id = auth.uid());

-- Mitgliedschaften: alle in der Organisation sehen die Mitgliederlisten
-- (für die Kacheln). Beitreten darf man nur sich selbst. Mitglieder
-- hinzufügen darf nur, wer die jeweilige Gilde gegründet hat.
create policy "guild_members_select_org" on public.guild_members
  for select using (org_id = public.current_org_id());

create policy "guild_members_insert_self_join" on public.guild_members
  for insert with check (member_id = auth.uid() and org_id = public.current_org_id());

create policy "guild_members_insert_founder_adds" on public.guild_members
  for insert with check (
    org_id = public.current_org_id()
    and exists (select 1 from public.guilds g where g.id = guild_id and g.founder_id = auth.uid())
  );

create policy "guild_members_delete_self_or_founder" on public.guild_members
  for delete using (
    member_id = auth.uid()
    or exists (select 1 from public.guilds g where g.id = guild_id and g.founder_id = auth.uid())
  );
