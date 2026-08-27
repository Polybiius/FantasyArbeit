-- RLS-Performance-Härtung für ALLE sechs Policies auf storage.objects.
--
-- Auslöser: Migration 20260826160000_contact_files_storage_cleanup_queue.sql
-- hat contact_files_storage_select/_delete komplett neu geschrieben, dabei
-- aber weiterhin rohes `auth.uid()` verwendet statt `(select auth.uid())` --
-- verpasste Gelegenheit gegen die in CLAUDE.md dokumentierte Konvention
-- "RLS-Performance-Härtung" ("bei jeder neuen Policy/Hilfsfunktion beide Muster
-- von Anfang an anwenden"). Eine blinde Zweitmeinung wies darauf hin, dass
-- storage.objects insgesamt sechs Policies hat, alle mit rohem auth.uid() --
-- deshalb hier gleich flächendeckend gewrappt (contact-files UND journal-photos).
--
-- Wirkung: rohes auth.uid() wird von Postgres einmal PRO ZEILE ausgewertet,
-- die (select auth.uid())-Form nur einmal pro Abfrage (InitPlan). KEINE
-- Sicherheits-/Verhaltensänderung -- `(select auth.uid())` liefert exakt
-- denselben Wert. Wer welche Storage-Objekte sehen/anlegen/ändern/löschen darf,
-- bleibt Byte für Byte identisch (mechanisch nachgewiesen: alte Definition mit
-- s/auth.uid()/(select auth.uid())/g == neue Definition). Die übrigen Prädikate
-- (is_admin(), current_org_id(), guild_contact_permission()) wrappen auth.uid()
-- bereits intern.
--
-- Vorherige (rohe) Definitionen zum Rückbau:
--   contact_files_storage_select/_delete -> 20260826160000_...cleanup_queue.sql (Z. 156-196)
--   contact_files_storage_insert         -> 20260810194843_fix_contact_files_storage_rls.sql
--   photo_*_own_folder                   -> 20260808145403_remote_schema.sql / sql/patch4_fotos.sql
-- Rückbau = jene Blöcke erneut anwenden (nur `(select auth.uid())` -> `auth.uid()`).

begin;

-- ---- contact-files ----

alter policy "contact_files_storage_select" on storage.objects
  using (
    bucket_id = 'contact-files'
    and (
      exists (
        select 1 from public.contacts c
        where c.id::text = (storage.foldername(objects.name))[1]
          and (c.owner_id = (select auth.uid()) or public.is_admin() or public.guild_contact_permission(c.owner_id, false))
      )
      or exists (
        select 1 from public.contact_file_deletion_queue q
        where q.storage_path = objects.name
          and q.org_id = public.current_org_id()
          and public.is_admin()
      )
    )
  );

alter policy "contact_files_storage_delete" on storage.objects
  using (
    bucket_id = 'contact-files'
    and (
      exists (
        select 1 from public.contacts c
        where c.id::text = (storage.foldername(objects.name))[1]
          and (c.owner_id = (select auth.uid()) or public.is_admin() or public.guild_contact_permission(c.owner_id, true))
      )
      or exists (
        select 1 from public.contact_file_deletion_queue q
        where q.storage_path = objects.name
          and q.org_id = public.current_org_id()
          and public.is_admin()
      )
    )
  );

alter policy "contact_files_storage_insert" on storage.objects
  with check (
    bucket_id = 'contact-files'
    and exists (
      select 1 from public.contacts c
      where c.id::text = (storage.foldername(objects.name))[1]
        and (c.owner_id = (select auth.uid()) or public.is_admin() or public.guild_contact_permission(c.owner_id, true))
    )
  );

-- ---- journal-photos ----

alter policy "photo_select_own_folder" on storage.objects
  using (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = ((select auth.uid()))::text
  );

alter policy "photo_update_own_folder" on storage.objects
  using (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = ((select auth.uid()))::text
  );

alter policy "photo_insert_own_folder" on storage.objects
  with check (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = ((select auth.uid()))::text
  );

insert into public.schema_patches (patch_number, title) values
  (56, 'RLS-Performance: auth.uid()-Wrap in allen Storage-Policies')
on conflict (patch_number) do nothing;

commit;
