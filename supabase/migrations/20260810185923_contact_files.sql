-- Datei-Upload bei Kontakten (2026-08-10), erste Runde einer bewusst
-- offen gelassenen Idee. Mit dem Nutzer geklärt:
-- - Rechte folgen exakt dem bestehenden Gilden-Freigabepaar für Kontakte
--   (contacts_access 'read' = nur ansehen/herunterladen, 'write' =
--   zusätzlich hochladen/löschen) -- kein drittes Rechte-Level nötig,
--   guild_contact_permission() aus Phase 1 wird 1:1 wiederverwendet.
-- - Sichtbarkeit folgt 1:1 der Kontakt-Sichtbarkeit, kein eigenes Modell.
-- - Grenzen (Nutzerwunsch "best practice"): 10 MB pro Datei (deckt auch
--   mehrseitige eingescannte Vertrags-PDFs ab, ohne den Storage
--   unnötig zu belasten), erlaubte Typen PDF + gängige Bildformate
--   (JPEG/PNG/WEBP -- kein HEIC wegen inkonsistenter Browser-Vorschau).
--   Mehrfach-Upload erlaubt, kein künstliches Zähl-Limit pro Kontakt.

-- === 1) Privaten Speicherort (Bucket) anlegen, Grenzen direkt am Bucket ===

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'contact-files', 'contact-files', false,
  10485760, -- 10 MB
  array['application/pdf','image/jpeg','image/png','image/webp']
)
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- === 2) Storage-Zugriffsregeln: Objektpfad ist "<contact_id>/<uuid>_<dateiname>",
--    Berechtigung wird über guild_contact_permission() auf den Kontakt geprüft ===

create policy "contact_files_storage_select" on storage.objects
  for select using (
    bucket_id = 'contact-files'
    and exists (
      select 1 from public.contacts c
      where c.id::text = (storage.foldername(name))[1]
        and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, false))
    )
  );

create policy "contact_files_storage_insert" on storage.objects
  for insert with check (
    bucket_id = 'contact-files'
    and exists (
      select 1 from public.contacts c
      where c.id::text = (storage.foldername(name))[1]
        and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, true))
    )
  );

create policy "contact_files_storage_delete" on storage.objects
  for delete using (
    bucket_id = 'contact-files'
    and exists (
      select 1 from public.contacts c
      where c.id::text = (storage.foldername(name))[1]
        and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, true))
    )
  );

-- === 3) Tabelle, die festhält, welche Datei zu welchem Kontakt gehört ===

create table public.contact_files (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  contact_id uuid not null references public.contacts(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  filename text not null,
  mime_type text not null,
  size_bytes bigint not null,
  created_at timestamptz not null default now()
);

create index contact_files_contact_id_idx on public.contact_files(contact_id);

alter table public.contact_files enable row level security;

create policy "contact_files_select" on public.contact_files
  for select using (
    exists (
      select 1 from public.contacts c
      where c.id = contact_files.contact_id
        and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, false))
    )
  );

create policy "contact_files_insert" on public.contact_files
  for insert with check (
    uploaded_by = auth.uid()
    and org_id = public.current_org_id()
    and exists (
      select 1 from public.contacts c
      where c.id = contact_files.contact_id
        and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, true))
    )
  );

-- Kein Update -- eine Datei wird gelöscht+neu hochgeladen, nicht editiert.

create policy "contact_files_delete" on public.contact_files
  for delete using (
    exists (
      select 1 from public.contacts c
      where c.id = contact_files.contact_id
        and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, true))
    )
  );
