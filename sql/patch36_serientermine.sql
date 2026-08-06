-- ============================================================
-- PATCH 36 — Serientermine (wiederkehrende Termine, Outlook-Stil)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Die Wiederholungsregel selbst ("jede Woche Mo+Mi 9-10 Uhr, bis Ende 2027
-- oder unbegrenzt") lebt getrennt von den echten Kalendereinträgen in
-- termine. Statt die Wiederholung rein virtuell zu berechnen, werden echte
-- termine-Zeilen vorausschauend "gebacken" (materialisiert) — genau wie
-- beim täglichen Manatrank-Nachtrag rollierend immer ein Stück weiter in
-- die Zukunft, nicht auf einen Schlag unendlich (siehe generated_until).
-- Vorteil dieses Ansatzes: ein einzelner Tag der Serie lässt sich ganz
-- normal verschieben/löschen wie jeder andere Termin, ohne eigene
-- "Ausnahme"-Buchhaltung — generated_until wandert nur vorwärts, ein einmal
-- erzeugter (und ggf. verschobener) Tag wird nie ein zweites Mal erzeugt.
create table public.termin_series (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  location_id uuid references public.locations(id) on delete set null,
  title text not null,
  start_time time not null,
  end_time time not null,
  freq text not null check (freq in ('taeglich','woechentlich','monatlich')),
  interval_n integer not null default 1 check (interval_n > 0),
  weekdays smallint[], -- nur bei 'woechentlich' genutzt: 0=Montag .. 6=Sonntag
  start_date date not null,
  until_date date, -- NULL = unbegrenzt
  generated_until date not null,
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);

alter table public.termin_series enable row level security;

create policy "termin_series_select_own_or_admin" on public.termin_series
  for select using (owner_id = auth.uid() or public.is_admin());

create policy "termin_series_insert_own" on public.termin_series
  for insert with check (owner_id = auth.uid() and org_id = public.current_org_id());

create policy "termin_series_update_owner_or_admin" on public.termin_series
  for update using (owner_id = auth.uid() or public.is_admin());

create policy "termin_series_delete_owner_or_admin" on public.termin_series
  for delete using (owner_id = auth.uid() or public.is_admin());

-- Jeder tatsächliche Kalendertag einer Serie ist eine ganz normale Zeile in
-- termine (kein Sonderfall beim Anzeigen/Ziehen), nur mit Rückverweis auf
-- die Serie für "ganze Serie löschen/verschieben". "on delete cascade":
-- die ganze Serie löschen entfernt automatisch alle ihre Termine mit.
alter table public.termine add column if not exists series_id uuid references public.termin_series(id) on delete cascade;

insert into public.schema_patches (patch_number, title) values
  (36, 'Serientermine (wiederkehrende Termine, Outlook-Stil)')
on conflict (patch_number) do nothing;
