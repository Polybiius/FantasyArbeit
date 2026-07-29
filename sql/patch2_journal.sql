-- ============================================================
-- PATCH 2 — Tagebuch / Abenteuerlog
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

create table public.journal_entries (
  user_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  entry_date date not null,
  q1 text, -- Welche Etappe habe ich heute gemeistert?
  q2 text, -- Welcher Herausforderung bin ich begegnet?
  q3 text, -- Welche Entdeckung habe ich gemacht?
  q4 text, -- Welche Spur nehme ich mit?
  q5 text, -- Wohin führt meine nächste Etappe?
  updated_at timestamptz not null default now(),
  primary key (user_id, entry_date)
);

alter table public.journal_entries enable row level security;

-- Bewusst STRENGER als bei allen anderen Tabellen: hier gibt es
-- keine Admin-Ausnahme. Nur der Nutzer selbst sieht seine eigenen
-- Tagebucheinträge — niemand sonst, auch kein Admin.
create policy "journal_select_own_only" on public.journal_entries
  for select using (user_id = auth.uid());

create policy "journal_insert_own_only" on public.journal_entries
  for insert with check (user_id = auth.uid());

create policy "journal_update_own_only" on public.journal_entries
  for update using (user_id = auth.uid());
