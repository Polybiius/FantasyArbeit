-- ============================================================
-- Aufgaben-System (Outlook-Stil): echte, abhakbare Aufgaben
-- ============================================================
-- Ersetzt NICHT die bestehenden Kalender-Hinweise (tasksForDate() in
-- index.html, Monats-Punkte/Wochen-Chips) -- die bleiben als reine,
-- nicht-interaktive Vorschau unverändert bestehen. Diese Tabelle ist die
-- neue, tatsächlich interaktive Aufgaben-Liste im neuen Tag-Reiter des
-- Kalenders.
--
-- Bewusst OHNE "erledigt"-Zustand: eine Aufgabe existiert nur, solange sie
-- offen ist -- Abhaken löscht die Zeile direkt (Nutzerentscheidung
-- 2026-08-20: eine Historie erledigter Aufgaben hat keinen praktischen
-- Wert -- wurde ein Anruf/Termin wirklich wahrgenommen, steht das ohnehin
-- schon in der Kontakt-Chronik/den Terminen).
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  title text not null,
  due_date date,
  source_type text not null default 'manual' check (source_type in ('manual','geburtstag','wiedervorlage')),
  created_at timestamptz not null default now()
);

-- Verhindert doppelte automatische Aufgaben (Geburtstag/Wiedervorlage) für
-- denselben Kontakt+Tag -- Sync läuft an mehreren Stellen (Kontakt
-- speichern, Login, Tageswechsel-Wächter), die sich zeitlich überschneiden
-- könnten.
create unique index tasks_unique_auto on public.tasks(owner_id, contact_id, source_type, due_date)
  where source_type in ('geburtstag','wiedervorlage');

alter table public.tasks enable row level security;

-- Rechte wie bei termine (Patch 33): rein persönlich, Admin darf lesen
-- (nicht so abgeschottet wie journal_entries), Schreiben bleibt beim
-- Eigentümer. Direkt mit dem seit der RLS-Performance-Härtung
-- (2026-08-17) aktuellen Muster geschrieben -- (select auth.uid()), eine
-- einzelne SELECT-Policy -- statt es später nachoptimieren zu müssen.
-- Bewusst KEINE update-Policy: Aufgaben werden in Version 1 nicht
-- nachträglich bearbeitet, nur angelegt oder gelöscht (Rule of Three --
-- Bearbeiten kommt erst, wenn wirklich gebraucht).
create policy "tasks_select_own_or_admin" on public.tasks
  for select using (owner_id = (select auth.uid()) or public.is_admin());

create policy "tasks_insert_own" on public.tasks
  for insert with check (owner_id = (select auth.uid()) and org_id = public.current_org_id());

create policy "tasks_delete_own_or_admin" on public.tasks
  for delete using (owner_id = (select auth.uid()) or public.is_admin());

-- Merkt sich pro Nutzer, für welchen Kalendertag die automatischen
-- Geburtstags-Aufgaben zuletzt erzeugt wurden. Verhindert, dass eine am
-- selben Tag bereits abgehakte (= gelöschte) Geburtstags-Aufgabe durch
-- eine erneute Sync-Prüfung (z.B. der Tageswechsel-Wächter in index.html,
-- der auch bei durchgehend geöffnetem Laptop den Tageswechsel erkennt)
-- wieder aufersteht. Normales, unbewachtes Profilfeld -- kein
-- Trigger-Schutz nötig, anders als role/character_class/total_xp/level.
alter table public.profiles add column if not exists tasks_synced_date date;

insert into public.schema_patches (patch_number, title) values
  (51, 'Aufgaben-System (Outlook-Stil, abhakbar)')
on conflict (patch_number) do nothing;
