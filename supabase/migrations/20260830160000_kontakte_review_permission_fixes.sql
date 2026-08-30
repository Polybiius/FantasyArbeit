-- PATCH: Gilden-Pool-Kontakte -- fehlende Berechtigungszweige + Auto-
-- Löschungs-/Aufgaben-Konsistenz
--
-- Funde aus der 5-Linsen-Tiefenprüfung "Kontakte" (Phase 2 des
-- CLAUDE.md-Fahrplans), von der Cross-File- UND der Korrektheits-Linse
-- unabhängig bestätigt, plus einer eigenen Zweitmeinungsrunde (Pflicht bei
-- Berechtigungslogik) auf den ersten Entwurf dieser Migration.
--
-- === Hintergrund ===
-- Ein Kontakt aus dem Mitarbeiter-Offboarding landet mit owner_id=NULL,
-- guild_id=<Gilde> im "Gilden-Pool" (20260808211342). guild_contact_
-- permission(owner_id, ...) kann für so einen Kontakt nie greifen -- sie
-- prüft die Gildenmitgliedschaft DES EIGENTÜMERS, den es per Definition
-- nicht gibt.
--
-- Zwei unterschiedliche Ersatz-Prüfungen, je nachdem ob es um LESEN oder
-- SCHREIBEN geht (Unterscheidung kam erst aus der Zweitmeinungsrunde, siehe
-- Fund 4 unten):
-- - LESEN: contacts_select_visible() (20260830091000) gewährt die
--   Sichtbarkeit des Pool-Kontakts selbst bereits JEDEM Gildenmitglied
--   (nicht nur der Führung) -- exakt das Modell, das ein normaler,
--   geteilter Kontakt auch hat (jedes Mitglied mit mindestens 'read'-Zugriff
--   sieht ihn). Neue Helferfunktion guild_pool_read_permission(guild_id)
--   spiegelt das für abhängige Tabellen (Verträge/Chronik/Termine/Log/
--   Dateien).
-- - SCHREIBEN: guild_leadership_permission(guild_id) (Gildenführer ODER
--   team_rights-Mitglied) -- ein Pool-Kontakt hat keinen Eigentümer, der
--   Schreibrecht delegieren könnte, deshalb entscheidet stattdessen die
--   Gildenführung als Kollektiv (Stewardship-Modell). contacts_writable()/
--   sales_writable()/sales_insert_like_contact/sales_delete_like_contact
--   (20260824190000, 20260827174618) nutzen das bereits korrekt.
--
-- === Funde, alle in dieser Migration behoben ===
--
-- 1) sales_select_like_contact -- Lese-Zweig fehlte (Erst-Fund).
-- 2) contact_activities_select_visible -- dieselbe Lücke für die Chronik
--    (Erst-Fund).
-- 3) request_contact_deletion() -- ein Gildenmitglied mit Führungsrecht
--    konnte für einen Gilden-Pool-Kontakt keine Löschanfrage stellen
--    (Schreib-Zweig, bleibt bewusst bei guild_leadership_permission --
--    eine Löschanfrage ist eine Schreibhandlung, kein reiner Lesezugriff).
-- 4) admin_reassign_contact() -- der nicht-Admin-Zweig (alleiniger
--    Gildenführer einer Ein-Gilde-Org) beschränkte sich auf reine
--    Org-Pool-Kontakte (guild_id IS NULL). Da is_sole_guild_founder_of_org()
--    nur bei GENAU EINER Gilde in der Org wahr wird, gehört jeder
--    Gilden-Pool-Kontakt der Org zwangsläufig zur eigenen (einzigen) Gilde
--    des Aufrufers -- "guild_id IS NULL" ist für diese Rolle deshalb
--    gefahrlos entfernbar (von der Zweitmeinungsrunde bestätigt: kein
--    neuer Autorisierungsspielraum für Multi-Gilden-Orgs, da der Zweig an
--    v_contact.org_id verankert bleibt).
-- 5) auto_delete_inactive_contacts() -- kein Eigentümer-Filter, ein
--    Pool-Kontakt würde nach Ablauf der Inaktivitätsfrist einfach gelöscht
--    -- Widerspruch zum dokumentierten Offboarding-Versprechen ("niemals
--    gelöscht"). Fix: Pool-Kontakte (owner_id IS NULL) von der Auto-
--    Löschung ausgenommen.
--    ACHTUNG, von der Zweitmeinungsrunde als bewusst unvollständig
--    markiert (Fund 3 dort): das macht einen NIE beanspruchten Pool-
--    Kontakt dauerhaft unlöschbar statt nur befristet verschont --
--    möglicherweise ein eigenes DSGVO-Aufbewahrungsthema (Art. 5 Abs. 1e
--    DSGVO, Speicherbegrenzung). Eine vollständige Lösung bräuchte eine
--    eigene Vorwarnung an die Gildenführung/den Org-Admin (Erweiterung von
--    contacts_pending_deletion_for_self() um einen entsprechenden Zweig)
--    -- das ist NICHT Teil dieser Migration, sondern bewusst als
--    Folgeaufgabe zurückgestellt (kein automatischer Mechanismus dafür
--    existiert bisher an anderer Stelle im Projekt, den man einfach
--    kopieren könnte). Diese Migration verhindert nur die schlimmere
--    Alternative (stilles, unwiderrufliches Löschen ohne jede
--    Vorwarnungsmöglichkeit).
-- 6) Wiedervorlage-Aufgaben-Karteileiche: ein BEFORE-DELETE-Trigger auf
--    contacts räumt offene tasks-Zeilen (source_type='wiedervorlage') jetzt
--    für JEDEN Löschweg auf (vorher nur beim manuellen Löschen und
--    approve_contact_deletion_request()) -- gleiches Muster wie
--    resolve_orphaned_deletion_requests() (20260827181923).
-- 7) [Zweitmeinungsrunde, Fund 1] sales_files/Dateien komplett vergessen:
--    contact_files_select/_insert/_delete + die drei storage.objects-
--    Geschwister-Policies kannten den Gilden-Pool-Fall nicht, obwohl das
--    Frontend (index.html, canEdit-Erweiterung um isGuildPoolLeader,
--    gleicher Bau-Zeitpunkt) der Gildenführung jetzt einen Upload-/
--    Löschen-Bereich anzeigt -- ohne diesen Fix ein garantiert
--    scheiternder Button (genau die Bug-Klasse, gegen die 20260827174618
--    seinerzeit geschrieben wurde). Lese-Policies bekommen
--    guild_pool_read_permission() (jedes Gildenmitglied), Schreib-Policies
--    guild_leadership_permission() (nur Führung).
-- 8) [Zweitmeinungsrunde, Fund 2] termine_select_visible/log_select_visible
--    (Kalendertermine + Vertriebs-Aktionen in der Chronik) hatten dieselbe
--    Lücke wie contact_activities -- ohne Fix wäre die Chronik eines
--    Gilden-Pool-Kontakts lückenhaft statt durchgängig (Verträge/Anrufe
--    sichtbar, Termine/Aktionen nicht) -- irreführender als komplett leer.
-- 9) [Zweitmeinungsrunde, Fund 4] die beiden unter 1)/2) zuerst gebauten
--    Lese-Policies nutzten fälschlich guild_leadership_permission (ein
--    Schreib-Prädikat) statt des neuen guild_pool_read_permission --
--    hier korrigiert, damit ein normales (nicht führendes) Gildenmitglied
--    dieselbe Verträge-/Chronik-Sicht auf einen Pool-Kontakt hat wie auf
--    jeden anderen für die Gilde freigegebenen Kontakt auch.
--
-- Rückbau: sales_select_like_contact/contact_activities_select_visible/
-- termine_select_visible/log_select_visible/contact_files_select/
-- contact_files_insert/contact_files_delete/contact_files_storage_select/
-- contact_files_storage_insert/contact_files_storage_delete auf den in
-- dieser Datei jeweils zitierten vorherigen Stand zurücksetzen (jede
-- Policy hier als vollständige create-Anweisung dokumentiert, keine reinen
-- Diffs). request_contact_deletion() auf 20260827181923:142 zurücksetzen,
-- admin_reassign_contact() auf 20260830092000:99, auto_delete_inactive_
-- contacts() auf 20260825201448:172. Trigger
-- contacts_cleanup_wiedervorlage_task + Funktion
-- cleanup_wiedervorlage_task_on_contact_delete() sowie die neue Funktion
-- guild_pool_read_permission() droppen.

begin;

-- ---------------------------------------------------------------------
-- Neue Helferfunktion: "ist irgendein Mitglied dieser Gilde" (Lese-Fall,
-- Gegenstück zu guild_leadership_permission() für den Schreib-Fall).
-- ---------------------------------------------------------------------
create or replace function public.guild_pool_read_permission(target_guild uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.guild_members gm
    where gm.guild_id = target_guild and gm.member_id = (select auth.uid())
  );
$$;
-- Bewusst auch für anon ausführbar, gleiche Begründung wie
-- is_sole_guild_founder_of_org(): reines Lese-Helferlein, liefert für anon
-- ohnehin immer false.
revoke execute on function public.guild_pool_read_permission(uuid) from public;
grant execute on function public.guild_pool_read_permission(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------
-- 1) sales_select_like_contact -- Gilden-Pool-Lesezweig ergänzen
-- ---------------------------------------------------------------------
drop policy if exists sales_select_like_contact on public.sales;
create policy sales_select_like_contact on public.sales
for select
using (
  exists (
    select 1 from public.contacts c
    where c.id = sales.contact_id
      and (
        c.owner_id = (select auth.uid())
        or is_admin_of(c.org_id)
        or (c.org_id = current_org_id() and contacts_shared_for_org())
        or guild_contact_permission(c.owner_id, false)
        or (c.owner_id is null and c.guild_id is not null and guild_pool_read_permission(c.guild_id))
      )
  )
);

-- ---------------------------------------------------------------------
-- 2) contact_activities_select_visible -- Gilden-Pool-Lesezweig ergänzen
-- ---------------------------------------------------------------------
drop policy if exists contact_activities_select_visible on public.contact_activities;
create policy contact_activities_select_visible on public.contact_activities
for select
using (
  user_id = (select auth.uid())
  or is_admin_of(org_id)
  or exists (
    select 1 from public.contacts c
    where c.id = contact_activities.contact_id
      and (
        guild_contact_permission(c.owner_id, false)
        or (c.owner_id is null and c.guild_id is not null and guild_pool_read_permission(c.guild_id))
      )
  )
);

-- ---------------------------------------------------------------------
-- 3) request_contact_deletion() -- Gilden-Pool-Schreibzweig ergänzen
-- ---------------------------------------------------------------------
create or replace function public.request_contact_deletion(p_contact_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_contact public.contacts;
  v_request_id uuid;
begin
  select * into v_contact from public.contacts
    where id = p_contact_id and org_id = current_org_id();
  if v_contact is null then
    raise exception 'Kontakt nicht gefunden.' using errcode = '42501';
  end if;

  if v_contact.owner_id = (select auth.uid()) or is_admin() then
    raise exception 'Als Eigentümer oder Admin kannst du direkt löschen, keine Anfrage nötig.' using errcode = '42501';
  end if;

  if not (
    guild_contact_permission(v_contact.owner_id, true)
    or (v_contact.owner_id is null and v_contact.guild_id is not null and guild_leadership_permission(v_contact.guild_id))
  ) then
    raise exception 'Keine Schreibberechtigung für diesen Kontakt.' using errcode = '42501';
  end if;

  insert into public.contact_deletion_requests (org_id, contact_id, contact_name_snapshot, requested_by, status)
  values (v_contact.org_id, p_contact_id, v_contact.name, (select auth.uid()), 'offen')
  on conflict (contact_id) where (status = 'offen')
  do nothing
  returning id into v_request_id;

  if v_request_id is null then
    select id into v_request_id from public.contact_deletion_requests
      where contact_id = p_contact_id and status = 'offen';
  end if;

  return v_request_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 4) admin_reassign_contact() -- sole-founder-Zweig auf Gilden-Pool erweitern
-- ---------------------------------------------------------------------
create or replace function public.admin_reassign_contact(
  p_contact_id uuid,
  p_new_owner_id uuid,
  p_new_guild_id uuid,
  p_expected_updated_at timestamptz
)
returns public.contacts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_contact public.contacts;
  v_updated public.contacts;
begin
  select * into v_contact from public.contacts where id = p_contact_id for update;
  if not found then
    raise exception 'Kontakt nicht gefunden' using errcode = '42501';
  end if;
  if not (
    is_admin_of(v_contact.org_id)
    or (is_sole_guild_founder_of_org(v_contact.org_id) and v_contact.owner_id is null)
  ) then
    raise exception 'Nur Admins oder der alleinige Gildenführer der eigenen Organisation dürfen Kontakte umverteilen (Gildenführer nur für herrenlose Pool-Kontakte)' using errcode = '42501';
  end if;
  if p_new_owner_id is not null and p_new_guild_id is not null then
    raise exception 'Ungültige Zielkombination: entweder Besitzer oder Gilden-Pool, nicht beides.';
  end if;
  if p_new_owner_id is not null and not exists (
    select 1 from public.profiles where id = p_new_owner_id and org_id = v_contact.org_id
  ) then
    raise exception 'Zielperson ist nicht Mitglied dieser Organisation.';
  end if;
  if p_new_guild_id is not null and not exists (
    select 1 from public.guilds where id = p_new_guild_id and org_id = v_contact.org_id
  ) then
    raise exception 'Zielgilde gehört nicht zu dieser Organisation.';
  end if;

  update public.contacts set owner_id = p_new_owner_id, guild_id = p_new_guild_id
  where id = p_contact_id and updated_at = p_expected_updated_at
  returning * into v_updated;

  if not found then
    return null;
  end if;

  insert into public.pool_zuweisung_log
    (org_id, entity_type, entity_id, entity_name_snapshot, new_owner_id, new_guild_id, assigned_by)
  values
    (v_updated.org_id, 'contact', v_updated.id, v_updated.name, v_updated.owner_id, v_updated.guild_id, (select auth.uid()));

  return v_updated;
end;
$$;

-- ---------------------------------------------------------------------
-- 5) auto_delete_inactive_contacts() -- Pool-Kontakte (owner_id NULL)
--    komplett von der Auto-Löschung ausnehmen (siehe Kopf-Kommentar,
--    bewusst als unvollständige Übergangslösung markiert)
-- ---------------------------------------------------------------------
create or replace function public.auto_delete_inactive_contacts()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  org record;
  months int;
  n_deleted int;
begin
  for org in
    select rc.org_id,
           (rc.config->'contactAutoDelete'->>'monthsInactive')::int as months_inactive
    from public.rule_configs rc
    where coalesce((rc.config->'contactAutoDelete'->>'enabled')::boolean, false) = true
  loop
    months := greatest(coalesce(org.months_inactive, 6), 1);

    with deleted as (
      delete from public.contacts c
      where c.org_id = org.org_id
        and c.owner_id is not null
        and not exists (
          select 1 from public.sales s
          where s.contact_id = c.id and s.status = 'gewonnen'
        )
        and greatest(
              c.created_at,
              c.updated_at,
              coalesce(c.naechster_kontakt::timestamptz, c.created_at),
              coalesce(
                (select max(ca.occurred_at) from public.contact_activities ca where ca.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(t.start_at) from public.termine t where t.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(al.created_at) from public.action_log al where al.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(cf.created_at) from public.contact_files cf where cf.contact_id = c.id),
                c.created_at
              )
            ) < now() - (months || ' months')::interval
      returning 1
    )
    select count(*) into n_deleted from deleted;

    insert into public.contact_auto_delete_log(org_id, deleted_count)
    values (org.org_id, n_deleted);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 6) Wiedervorlage-Aufgaben-Aufräumung für JEDEN Löschweg
-- ---------------------------------------------------------------------
create or replace function public.cleanup_wiedervorlage_task_on_contact_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.tasks where contact_id = old.id and source_type = 'wiedervorlage';
  return old;
end;
$$;

drop trigger if exists contacts_cleanup_wiedervorlage_task on public.contacts;
create trigger contacts_cleanup_wiedervorlage_task
  before delete on public.contacts
  for each row execute function public.cleanup_wiedervorlage_task_on_contact_delete();

-- ---------------------------------------------------------------------
-- 7) contact_files (Tabelle + Storage) -- Gilden-Pool-Zweige ergänzen
-- ---------------------------------------------------------------------
drop policy if exists contact_files_select on public.contact_files;
create policy contact_files_select on public.contact_files
for select
using (
  exists (
    select 1 from public.contacts c
    where c.id = contact_files.contact_id
      and (
        c.owner_id = (select auth.uid())
        or is_admin_of(c.org_id)
        or guild_contact_permission(c.owner_id, false)
        or (c.owner_id is null and c.guild_id is not null and guild_pool_read_permission(c.guild_id))
      )
  )
);

drop policy if exists contact_files_insert on public.contact_files;
create policy contact_files_insert on public.contact_files
for insert
with check (
  uploaded_by = (select auth.uid())
  and org_id = current_org_id()
  and exists (
    select 1 from public.contacts c
    where c.id = contact_files.contact_id
      and (
        c.owner_id = (select auth.uid())
        or is_admin_of(c.org_id)
        or guild_contact_permission(c.owner_id, true)
        or (c.owner_id is null and c.guild_id is not null and guild_leadership_permission(c.guild_id))
      )
  )
);

drop policy if exists contact_files_delete on public.contact_files;
create policy contact_files_delete on public.contact_files
for delete
using (
  exists (
    select 1 from public.contacts c
    where c.id = contact_files.contact_id
      and (
        c.owner_id = (select auth.uid())
        or is_admin_of(c.org_id)
        or guild_contact_permission(c.owner_id, true)
        or (c.owner_id is null and c.guild_id is not null and guild_leadership_permission(c.guild_id))
      )
  )
);

drop policy if exists contact_files_storage_select on storage.objects;
create policy contact_files_storage_select on storage.objects
for select
using (
  bucket_id = 'contact-files'
  and (
    exists (
      select 1 from public.contacts c
      where c.id::text = (storage.foldername(objects.name))[1]
        and (
          c.owner_id = (select auth.uid())
          or is_admin_of(c.org_id)
          or guild_contact_permission(c.owner_id, false)
          or (c.owner_id is null and c.guild_id is not null and guild_pool_read_permission(c.guild_id))
        )
    )
    or exists (
      select 1 from public.contact_file_deletion_queue q
      where q.storage_path = objects.name and q.org_id = current_org_id() and is_admin()
    )
  )
);

drop policy if exists contact_files_storage_insert on storage.objects;
create policy contact_files_storage_insert on storage.objects
for insert
with check (
  bucket_id = 'contact-files'
  and exists (
    select 1 from public.contacts c
    where c.id::text = (storage.foldername(objects.name))[1]
      and (
        c.owner_id = (select auth.uid())
        or is_admin_of(c.org_id)
        or guild_contact_permission(c.owner_id, true)
        or (c.owner_id is null and c.guild_id is not null and guild_leadership_permission(c.guild_id))
      )
  )
);

drop policy if exists contact_files_storage_delete on storage.objects;
create policy contact_files_storage_delete on storage.objects
for delete
using (
  bucket_id = 'contact-files'
  and (
    exists (
      select 1 from public.contacts c
      where c.id::text = (storage.foldername(objects.name))[1]
        and (
          c.owner_id = (select auth.uid())
          or is_admin_of(c.org_id)
          or guild_contact_permission(c.owner_id, true)
          or (c.owner_id is null and c.guild_id is not null and guild_leadership_permission(c.guild_id))
        )
    )
    or exists (
      select 1 from public.contact_file_deletion_queue q
      where q.storage_path = objects.name and q.org_id = current_org_id() and is_admin()
    )
  )
);

-- ---------------------------------------------------------------------
-- 8) termine_select_visible / log_select_visible -- Gilden-Pool-
--    Lesezweig ergänzen (schließt die Chronik-Lücke aus Fund 8 vollständig)
-- ---------------------------------------------------------------------
drop policy if exists termine_select_visible on public.termine;
create policy termine_select_visible on public.termine
for select
using (
  owner_id = (select auth.uid())
  or is_admin_of(org_id)
  or (
    contact_id is not null
    and exists (
      select 1 from public.contacts c
      where c.id = termine.contact_id
        and (
          guild_contact_permission(c.owner_id, false)
          or (c.owner_id is null and c.guild_id is not null and guild_pool_read_permission(c.guild_id))
        )
    )
  )
);

drop policy if exists log_select_visible on public.action_log;
create policy log_select_visible on public.action_log
for select
using (
  user_id = (select auth.uid())
  or (org_id = current_org_id() and is_admin())
  or (
    contact_id is not null
    and exists (
      select 1 from public.contacts c
      where c.id = action_log.contact_id
        and c.org_id = current_org_id()
        and (
          contacts_shared_for_org()
          or guild_contact_permission(c.owner_id, false)
          or (c.owner_id is null and c.guild_id is not null and guild_pool_read_permission(c.guild_id))
        )
    )
  )
);

commit;
