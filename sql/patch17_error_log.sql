-- ============================================================
-- PATCH 17 — Fehlerprotokoll (error_log)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
--
-- Hintergrund: bisher wurde nur ein Teil der fehlgeschlagenen
-- Datenbank-Aufrufe im Frontend überhaupt bemerkt (nur dort, wo
-- der Code das error-Feld der Antwort auch geprüft hat). Ab jetzt
-- wird jeder Fehlschlag zusätzlich hier abgelegt, damit ein Admin
-- im Nachhinein sehen kann, was schiefgelaufen ist, ohne dass ein
-- Nutzer sich erst melden muss. Rein additiv, kein Nutzer merkt im
-- Normalbetrieb etwas davon (nur Schreiben bei Fehlern, kein Lesen
-- durch normale Mitglieder).
-- ============================================================

create table public.error_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  context text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index error_log_org_idx on public.error_log(org_id, created_at desc);

alter table public.error_log enable row level security;

-- Jedes Mitglied darf für die eigene Organisation einen Fehler
-- eintragen (das Protokollieren selbst darf nicht an RLS scheitern).
create policy "error_log_insert_own_org" on public.error_log
  for insert with check (org_id = public.current_org_id());

-- Lesen nur für Admins der eigenen Organisation — bewusst kein
-- Update/Delete für irgendwen: ein Protokoll wird nicht nachträglich
-- verändert.
create policy "error_log_select_admin_only" on public.error_log
  for select using (org_id = public.current_org_id() and public.is_admin());
