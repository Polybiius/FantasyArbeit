-- ============================================================
-- PATCH 13 — Kundendatenbank-Fundament (Herzstück, ausgebaut)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================
-- ACHTUNG: Dieser Patch löscht den Inhalt der bisherigen Spalte
-- "name" bei Kontakten (wird durch vorname+nachname ersetzt).
-- Falls bereits echte Testkontakte mit Namen angelegt wurden,
-- vorher notieren — sie müssen danach einmal neu eingetragen werden.
-- ============================================================

-- 1) Vorname/Nachname getrennt. "name" bleibt als Spalte erhalten,
--    wird aber automatisch aus beiden zusammengesetzt (generated
--    column) — dadurch funktioniert der komplette bestehende Code
--    (Aktions-Log-Kontext, Tagebuch-Suche, Kacheln) unverändert weiter,
--    ohne dass wir jede Stelle im Code anfassen müssen.
alter table public.contacts add column if not exists vorname text not null default '';
alter table public.contacts add column if not exists nachname text not null default '';
alter table public.contacts drop column if exists name;
alter table public.contacts add column name text generated always as (trim(vorname || ' ' || nachname)) stored;

-- 2) Bedarfsanalyse als zwei getrennte Felder (Ist-Zustand / Wunsch),
--    plus Wiedervorlage-Datum für "nächster Kontakt".
alter table public.contacts add column if not exists bedarf_ist text;
alter table public.contacts add column if not exists bedarf_wunsch text;
alter table public.contacts add column if not exists naechster_kontakt date;

-- 3) Echte Verkaufshistorie statt einem einzelnen Produkt-Feld.
--    Produkt bleibt vorerst Freitext — der richtige Produkt-Katalog
--    kommt in einem späteren Patch, ohne dass diese Tabelle sich
--    dafür noch einmal ändern muss.
create table public.sales (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references public.contacts(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  produkt text not null,
  datum date not null default current_date,
  status text not null default 'gewonnen' check (status in ('gewonnen','verloren')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.sales enable row level security;

-- Sichtbarkeit spiegelt exakt die des zugehörigen Kontakts:
-- Besitzer, Admin, oder Team bei geteilten Kontakten.
create policy "sales_select_like_contact" on public.sales
  for select using (
    exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id
        and (c.owner_id = auth.uid() or public.is_admin() or (c.org_id = public.current_org_id() and public.contacts_shared_for_org()))
    )
  );

create policy "sales_insert_like_contact" on public.sales
  for insert with check (
    org_id = public.current_org_id()
    and exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id and (c.owner_id = auth.uid() or public.is_admin())
    )
  );

create policy "sales_update_like_contact" on public.sales
  for update using (
    exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id and (c.owner_id = auth.uid() or public.is_admin())
    )
  );

create policy "sales_delete_like_contact" on public.sales
  for delete using (
    exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id and (c.owner_id = auth.uid() or public.is_admin())
    )
  );
