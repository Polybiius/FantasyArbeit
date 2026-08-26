-- Schließt die in CLAUDE.md ("Bekannte, bewusst in Kauf genommene
-- Lücken") dokumentierte Lücke: Dateien im Storage-Bucket
-- `contact-files` überlebten bisher die automatische Löschung
-- inaktiver Kontakte (auto_delete_inactive_contacts(), Patch 53) --
-- nur die contact_files-Datenbankzeile kaskadierte mit, das
-- eigentliche Objekt im Speicher blieb liegen. Grund: Supabase
-- blockiert eine direkte SQL-Löschung von storage.objects
-- (storage.protect_delete()-Trigger, "Use the Storage API instead"),
-- und pg_cron/reines SQL kann die Storage-API nicht ohne ein
-- zusätzliches Geheimnis in der Datenbank erreichen -- widerspräche
-- dem Architekturprinzip "kein versteckter Backend-Schlüssel".
--
-- Lösung, wie in CLAUDE.md skizziert: Warteschlange + Admin-Login-
-- Aufräumung, gleiches Muster wie der Geburtstags-/Manatrank-
-- Nachtrag -- kein neues Geheimnis nötig, die Storage-API wird
-- weiterhin nur über die normale, authentifizierte Browser-Sitzung
-- eines Admins aufgerufen.
--
-- Fassung nach unabhängiger Zweitmeinung korrigiert (blinder Review,
-- zwei echte, blockierende Funde behoben, siehe HISTORY.md für den
-- vollen Verlauf):
--
--   Fund 1 (behoben): die bestehenden Storage-Policies
--   (contact_files_storage_select/_delete, Patch 42/Fix) hängen an
--   "gehört ein passender contacts-Datensatz noch zum Pfad" -- nach
--   der Kontakt-Löschung existiert dieser Datensatz aber per
--   Definition nicht mehr, die Bereinigung hätte also RLS-bedingt
--   NICHTS gelöscht (Supabase Storage liefert bei einem per RLS leer
--   gefilterten remove()-Aufruf `200 OK` mit leerem Ergebnis, keinen
--   Fehler -- das Frontend hätte die Warteschlange trotzdem geleert,
--   ohne dass je etwas entfernt wurde). Fix: beide Policies bekommen
--   einen zweiten, warteschlangen-verankerten Zweig (Admin der
--   eigenen Organisation UND ein passender offener Eintrag in
--   contact_file_deletion_queue).
--
--   Fund 2 (behoben): contact_files.storage_path wurde beim Insert
--   nie gegen contact_id geprüft -- ein Gildenmitglied mit Lesezugriff
--   auf einen fremden Kontakt (kennt dadurch dessen storage_path)
--   hätte unter einem EIGENEN, beschreibbaren Kontakt eine
--   contact_files-Zeile mit dem FREMDEN storage_path anlegen und
--   sofort wieder löschen können -- die Warteschlange hätte dann beim
--   nächsten Admin-Login die noch aktiv referenzierte Fremd-Datei aus
--   dem Speicher gelöscht. Erst durch Fund 1s Fix überhaupt
--   ausnutzbar, aber unabhängig davon eine echte Lücke. Fix: CHECK-
--   Constraint, storage_path muss mit "<contact_id>/" beginnen --
--   exakt die Konvention, nach der der Pfad im Frontend ohnehin immer
--   gebildet wird (0 betroffene Bestandszeilen, per Abfrage gegen die
--   echte DB bestätigt).
--
--   Zusätzliche Härtung (kein Fund, aber naheliegend beim Beheben von
--   Fund 1): der Trigger queued jetzt NUR, wenn der Eltern-Kontakt
--   tatsächlich nicht mehr existiert -- verhindert, dass ein
--   Mitarbeiter-Offboarding (contact_files.uploaded_by ... on delete
--   cascade, Kontakt selbst bleibt am Leben, wandert nur in den
--   Gilden-Pool) künftig aktiv genutzte Dateien lebender Kontakte
--   löscht. Vorher wäre das Objekt ohnehin nur "orphaned", jetzt würde
--   es durch die neue Warteschlange sonst tatsächlich entfernt.
--
-- Ablauf:
--   1) Ein BEFORE DELETE-Trigger auf contact_files trägt den
--      storage_path jeder gelöschten Zeile in die neue Warteschlange
--      ein -- NUR wenn der zugehörige Kontakt nicht mehr existiert
--      (siehe "Zusätzliche Härtung" oben). Der Normalfall (manuelles
--      Löschen im Dateien-Reiter, Kontakt bleibt bestehen) entfernt
--      das Storage-Objekt ohnehin bereits selbst vorher im Frontend --
--      dort ist gar keine Warteschlangen-Eintragung mehr nötig.
--   2) Beim Login eines Admins liest das Frontend die Warteschlange,
--      ruft sb.storage.remove() mit allen ausstehenden Pfaden auf,
--      und leert danach nur die tatsächlich erfolgreich entfernten
--      Zeilen über eine eigene RPC-Funktion (kein direktes DELETE-
--      Recht für Clients, gleiches Härtungsmuster wie beim Rest des
--      Projekts).
--
-- RLS-Designprinzip beachtet (siehe CLAUDE.md "Sicherheitsprinzipien"):
-- kein Insert/Update/Delete für normale Clients auf der neuen Tabelle,
-- nur eine schmale SECURITY DEFINER-Funktion zum Leeren + ein SELECT
-- für Admins der eigenen Organisation.

begin;

create table public.contact_file_deletion_queue (
  id bigint generated always as identity primary key,
  org_id uuid not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create index contact_file_deletion_queue_storage_path_idx on public.contact_file_deletion_queue(storage_path);

alter table public.contact_file_deletion_queue enable row level security;

create policy contact_file_deletion_queue_select_admin on public.contact_file_deletion_queue
  for select using (org_id = current_org_id() and is_admin());

-- Kein Insert/Update/Delete für normale Clients -- Insert läuft über
-- den Trigger unten (SECURITY DEFINER, umgeht RLS bewusst, damit auch
-- ein nicht-privilegierter Nutzer beim manuellen Datei-Löschen
-- erfolgreich einträgt), Delete über clear_contact_file_cleanup_queue().

-- Fund 2: storage_path muss zum eigenen contact_id-Ordner gehören --
-- verhindert, dass eine contact_files-Zeile einen fremden Pfad
-- referenziert (0 betroffene Bestandszeilen).
alter table public.contact_files
  add constraint contact_files_storage_path_matches_contact
  check (storage_path like (contact_id::text || '/%'));

create or replace function public.queue_contact_file_for_storage_cleanup()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Nur eintragen, wenn der Kontakt selbst schon weg ist (echter
  -- Cascade-Waisenfall) -- existiert er noch (z.B. Mitarbeiter-
  -- Offboarding via uploaded_by-Cascade, oder ein manuelles Löschen
  -- im Dateien-Reiter, das den Speicher bereits selbst geräumt hat),
  -- bleibt das Objekt unangetastet.
  if not exists (select 1 from public.contacts where id = old.contact_id) then
    insert into public.contact_file_deletion_queue(org_id, storage_path)
    values (old.org_id, old.storage_path);
  end if;
  return old;
end;
$$;

drop trigger if exists contact_files_queue_storage_cleanup on public.contact_files;
create trigger contact_files_queue_storage_cleanup
  before delete on public.contact_files
  for each row execute function public.queue_contact_file_for_storage_cleanup();

-- returns trigger-Funktion: kann Postgres strukturell nicht per RPC
-- aufrufen lassen, unabhängig von vergebenen Rechten (gleiche
-- Begründung wie protect_privileged_profile_fields() & Co. in
-- CLAUDE.md) -- kein revoke execute nötig.

create or replace function public.clear_contact_file_cleanup_queue(p_ids bigint[])
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_admin() then
    raise exception 'Nur Admins dürfen die Datei-Aufräum-Warteschlange leeren' using errcode = '42501';
  end if;

  delete from public.contact_file_deletion_queue
  where id = any(p_ids) and org_id = current_org_id();
end;
$$;

grant execute on function public.clear_contact_file_cleanup_queue(bigint[]) to authenticated;
revoke execute on function public.clear_contact_file_cleanup_queue(bigint[]) from public, anon;

-- Fund 1: Storage-Policies erweitern -- ein Admin darf ein Objekt
-- auch dann sehen/löschen, wenn der ursprüngliche Kontakt bereits weg
-- ist, SOLANGE ein passender, org-eigener Warteschlangen-Eintrag
-- existiert. Kein Zugriff auf fremde Organisationen (q.org_id =
-- current_org_id()), kein Zugriff für Nicht-Admins.

alter policy "contact_files_storage_select" on storage.objects
  using (
    bucket_id = 'contact-files'
    and (
      exists (
        select 1 from public.contacts c
        where c.id::text = (storage.foldername(objects.name))[1]
          and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, false))
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
          and (c.owner_id = auth.uid() or public.is_admin() or public.guild_contact_permission(c.owner_id, true))
      )
      or exists (
        select 1 from public.contact_file_deletion_queue q
        where q.storage_path = objects.name
          and q.org_id = public.current_org_id()
          and public.is_admin()
      )
    )
  );

insert into public.schema_patches (patch_number, title) values
  (55, 'Storage-Aufraeum-Warteschlange fuer geloeschte Kontakt-Dateien')
on conflict (patch_number) do nothing;

commit;
