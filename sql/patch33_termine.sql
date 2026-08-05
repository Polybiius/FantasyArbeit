-- ============================================================
-- PATCH 33 — Echter Termin-Kalender (Wochenansicht, Outlook-Stil)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Rein persönlicher Kalender (wie das Tagebuch), aber NICHT so
-- abgeschottet wie journal_entries — Admins bekommen wie bei den meisten
-- anderen Tabellen (Kontakte, Locations, ...) eine Leserechte-Ausnahme,
-- weil sich das Projekt Richtung Team-Reporting skalieren soll. Optionale
-- Verweise auf Kontakt/Betrieb, Freitext-Titel deckt Termine ohne
-- Verknüpfung ab (z.B. "Büroarbeit"). Keine Überschneidungs-Prüfung —
-- Doppelbuchungen sind einfach unabhängige Zeilen, die Wochenansicht
-- zeigt sie nebeneinander (reine Anzeige-Logik im Frontend).
create table public.termine (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  location_id uuid references public.locations(id) on delete set null,
  title text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (end_at > start_at)
);

alter table public.termine enable row level security;

create policy "termine_select_own_or_admin" on public.termine
  for select using (owner_id = auth.uid() or public.is_admin());

create policy "termine_insert_own" on public.termine
  for insert with check (owner_id = auth.uid() and org_id = public.current_org_id());

create policy "termine_update_owner_or_admin" on public.termine
  for update using (owner_id = auth.uid() or public.is_admin());

create policy "termine_delete_owner_or_admin" on public.termine
  for delete using (owner_id = auth.uid() or public.is_admin());

-- Persönliche Arbeitszeiten (neue Einstellungen-Unterseite "Kalender"):
-- pro Wochentag ein eigenes Start/Ende, damit z.B. ein kürzerer Freitag
-- möglich ist — die Bedienung in der App setzt trotzdem bequem mehrere
-- Tage auf einmal. NULL (Standard) = keine Arbeitszeiten hinterlegt, die
-- Wochenansicht zeigt dann ungefärbt wie ein normales 24h-Raster.
-- Struktur: {"mon":{"start":"09:00","end":"18:00"}, "tue":{...}, ..., "sun":null}
alter table public.profiles add column if not exists arbeitszeiten jsonb;

insert into public.schema_patches (patch_number, title) values
  (33, 'Echter Termin-Kalender (Wochenansicht, Outlook-Stil)')
on conflict (patch_number) do nothing;
