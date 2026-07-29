-- ============================================================
-- PATCH 16 — Tagebuch: mehrere @mentions pro Tag statt einer
--            einzelnen Kunde-markieren-Box
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
--
-- Hintergrund: Patch 12 hatte journal_entries.tagged_contact_id
-- eingeführt (genau EIN Kontakt pro Tag, über ein separates
-- Suchfeld unter dem Tagebuch verknüpft). Das war so nicht
-- gedacht — gewünscht ist stattdessen, dass man beim Schreiben
-- direkt im Text mit @Name markieren kann, und zwar mehrere
-- verschiedene Kontakte pro Tag (z.B. je einer in Frage 1 und
-- Frage 3). Bleibt weiterhin rein persönlich, keine
-- CRM-Statistik — nur ein Vermerk auf der Kundenkartei, dass es
-- am jeweiligen Datum einen Tagebucheintrag gibt.
-- ============================================================

-- 1) Neue Tabelle: beliebig viele Kontakt-Markierungen pro
--    Tagebuchtag. Referenziert journal_entries über deren
--    zusammengesetzten Primärschlüssel (user_id, entry_date) —
--    journal_entries hat keine eigene id-Spalte.
create table public.journal_entry_mentions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  entry_date date not null,
  contact_id uuid not null references public.contacts(id) on delete cascade,
  created_at timestamptz not null default now(),
  foreign key (user_id, entry_date) references public.journal_entries(user_id, entry_date) on delete cascade,
  unique (user_id, entry_date, contact_id)
);

alter table public.journal_entry_mentions enable row level security;

-- Bewusst genauso streng wie journal_entries selbst: keine
-- Admin-Ausnahme, nur der Nutzer selbst sieht/verwaltet seine
-- eigenen Markierungen.
create policy "journal_mentions_select_own_only" on public.journal_entry_mentions
  for select using (user_id = auth.uid());

create policy "journal_mentions_insert_own_only" on public.journal_entry_mentions
  for insert with check (user_id = auth.uid());

create policy "journal_mentions_delete_own_only" on public.journal_entry_mentions
  for delete using (user_id = auth.uid());

-- 2) Bestehende Einzel-Markierungen (tagged_contact_id) in die
--    neue Tabelle übernehmen, damit keine Daten verloren gehen.
insert into public.journal_entry_mentions (user_id, org_id, entry_date, contact_id)
select user_id, org_id, entry_date, tagged_contact_id
from public.journal_entries
where tagged_contact_id is not null
on conflict (user_id, entry_date, contact_id) do nothing;

-- 3) ACHTUNG — destruktiv: entfernt die alte Spalte, nachdem ihr
--    Inhalt oben migriert wurde. Nur ausführen, wenn Schritt 2
--    bereits gelaufen ist (in diesem Patch der Fall, da er als
--    Ganzes ausgeführt wird). Nach diesem Patch schreibt der
--    Code nicht mehr in tagged_contact_id.
alter table public.journal_entries drop column tagged_contact_id;
