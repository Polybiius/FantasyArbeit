-- ============================================================
-- PATCH 4 — Foto-Funktion im Abenteuerlog
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- 1) Privaten Speicherort (Bucket) für Fotos anlegen
insert into storage.buckets (id, name, public)
values ('journal-photos', 'journal-photos', false)
on conflict (id) do nothing;

-- 2) Zugriffsregeln: jeder Nutzer darf NUR in seinem eigenen,
--    nach seiner User-ID benannten Unterordner lesen/schreiben.
create policy "photo_select_own_folder" on storage.objects
  for select using (bucket_id = 'journal-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "photo_insert_own_folder" on storage.objects
  for insert with check (bucket_id = 'journal-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "photo_update_own_folder" on storage.objects
  for update using (bucket_id = 'journal-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- 3) Tabelle, die festhält, welches Foto zu welchem Tag gehört.
--    "transformed_path" bleibt bewusst jetzt schon vorbereitet, aber leer —
--    das ist der Platz, wo später das Ergebnis der KI-Umwandlung
--    (z.B. "Hexer im Rat der Weißen") landet, ohne dass wir die
--    Struktur später nochmal ändern müssen.
create table public.journal_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  entry_date date not null,
  storage_path text not null,
  transformed_path text, -- für später: KI-umgewandeltes Bild
  transform_status text not null default 'none', -- 'none' | 'pending' | 'done' (für später)
  created_at timestamptz not null default now(),
  unique(user_id, entry_date)
);

alter table public.journal_photos enable row level security;

create policy "journal_photos_select_own" on public.journal_photos
  for select using (user_id = auth.uid());

create policy "journal_photos_insert_own" on public.journal_photos
  for insert with check (user_id = auth.uid());

create policy "journal_photos_update_own" on public.journal_photos
  for update using (user_id = auth.uid());
