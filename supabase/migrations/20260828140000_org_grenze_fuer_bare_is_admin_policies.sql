-- PATCH: Organisations-Grenze für "nackte" is_admin()-Prüfungen
--
-- Voraussetzung für die eigentliche Mandantentrennungs-Arbeit (Pool +
-- Organisations-Einladung, siehe Erinnerung
-- project_naechster_struktureller_schritt). Bereits am 2026-08-27 bei
-- der Rechtemodell-Lücke gefunden (contacts_delete_owner_or_admin) und
-- dort bewusst als "gehört in einen eigenen, systematischen Audit"
-- vertagt: is_admin() prüft NUR die Rolle, nicht die Organisation. Das
-- war bisher folgenlos, weil es nur eine einzige Organisation gab (jeder
-- Admin war zwangsläufig der einzige Admin) — sobald eine ZWEITE, echte
-- Organisation mit eigenem Admin existiert, könnte deren Admin quer
-- durchs halbe Schema fremde Kontakte/Verkäufe/Termine/Aufgaben lesen
-- und teils sogar löschen.
--
-- Per echter Abfrage gegen pg_policies + pg_proc verifiziert (nicht nur
-- vermutet): 22 Policies (18 im Schema "public" + 3 im Schema "storage"
-- + eine weitere public-Policy, die beim ersten Durchgang übersehen
-- wurde, siehe unten) + 1 Funktion betroffen. Alle anderen
-- is_admin()-Vorkommen im Schema wurden geprüft und sind bereits korrekt
-- org-gebunden (u.a. alle vier "*_writable()"-Funktionen aus der
-- Konflikt-Schutz-Härtung, protect_privileged_profile_fields/
-- protect_location_owner_field (Trigger, nur nach vorherigem
-- RLS-Durchlass erreichbar), approve/reject_contact_deletion_request
-- (WHERE-Klausel org-gebunden, selbst wenn der Admin-Check selbst es
-- nicht ist)).
--
-- Zweite Runde nach unabhängiger Zweitmeinung (blind, eigene Dry-Run-
-- Verifikation gegen die echte DB, 2026-08-28): vier echte Funde, alle
-- hier eingearbeitet:
--   1) sales_select_like_contact hatte beim Umschreiben eine bestehende
--      Org-Grenze um contacts_shared_for_org() verloren -- wiederhergestellt.
--   2) is_admin_of() war für "anon" gesperrt (Konvention für
--      Schreibfunktionen, hier aber ein reines Lese-Policy-Helferlein) --
--      das hätte bei jedem Zugriff ohne gültige Session (App-Start vor
--      Session-Restore, abgelaufenes Token) einen harten Fehler statt
--      einer leeren Liste ausgelöst. is_admin_of() liefert für anon
--      ohnehin immer false (kein Profil vorhanden) -- nichts zu schützen,
--      jetzt wie alle Geschwister-Hilfsfunktionen (is_admin,
--      current_org_id, contacts_shared_for_org, guild_contact_permission)
--      auch für anon ausführbar.
--   3) public.contact_files_insert hatte GENAU dasselbe bare-is_admin()-
--      Muster wie contact_files_delete/_select (übersehen, weil beim
--      ersten manuellen Zusammenstellen der Liste nicht mitgezählt) --
--      jetzt mitgefixt.
--   4) drei storage.objects-Policies (contact_files_storage_select/
--      _delete/_insert) hatten dasselbe Muster im contacts-EXISTS-Zweig
--      -- übersehen, weil die ursprüngliche Bestandsaufnahme nur
--      schemaname='public' abgefragt hat, nicht 'storage'. Der jeweils
--      zweite Zweig dieser Policies (Warteschlangen-Zugriff) war bereits
--      korrekt org-gebunden und bleibt unverändert.
-- Keiner der vier Funde war live ausnutzbar (alle transitiv durch die
-- bereits gehärtete contacts_select_visible-Policy abgedeckt) -- trotzdem
-- mitgefixt, damit diese Migration nicht auf einer einzigen anderen
-- Policy als einziger Verteidigungslinie beruht.
--
-- Technik: neue, wiederverwendbare Hilfsfunktion is_admin_of(org_id) =
-- "ist Admin UND ist es von genau dieser Organisation" statt den
-- Ausdruck 18-mal zu wiederholen -- gleiche Konvention wie
-- current_org_id()/guild_contact_permission() im Projekt.
--
-- Rückbau: is_admin_of() droppen, jede ALTER POLICY unten mit der
-- jeweils vorherigen bare-is_admin()-Bedingung (siehe Kommentar über
-- jedem Block) ersetzen; guild_sales_metric_total auf die alte Fassung
-- zurücksetzen (siehe git-Historie dieser Datei).

begin;

-- ---------------------------------------------------------------------
-- Neue Hilfsfunktion
-- ---------------------------------------------------------------------

create or replace function public.is_admin_of(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin() and p_org_id = public.current_org_id();
$$;

-- Bewusst AUCH für anon ausführbar (Fund 2 der Zweitmeinung) -- ein reines
-- Lese-Helferlein, kein Schreibpfad, liefert für anon ohnehin immer false.
revoke execute on function public.is_admin_of(uuid) from public;
grant execute on function public.is_admin_of(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------
-- contact_activities
-- ---------------------------------------------------------------------

-- war: (user_id = auth.uid()) OR is_admin()
alter policy "contact_activities_delete_own_or_admin" on public.contact_activities
  using (
    (user_id = (select auth.uid())) or is_admin_of(org_id)
  );

-- war: (user_id = auth.uid()) OR is_admin() OR EXISTS(...)
alter policy "contact_activities_select_visible" on public.contact_activities
  using (
    (user_id = (select auth.uid()))
    or is_admin_of(org_id)
    or exists (
      select 1 from public.contacts c
      where c.id = contact_activities.contact_id
        and guild_contact_permission(c.owner_id, false)
    )
  );

-- war: USING bare, WITH CHECK bereits org-gebunden (Verteidigung in der
-- Tiefe -- die eigentliche Schreibgrenze stand schon, USING nachgezogen
-- für Konsistenz mit den anderen beiden Policies dieser Tabelle).
-- WITH CHECK bewusst NICHT auf is_admin_of() umgestellt: die ursprüngliche
-- Form ((user_id=self OR is_admin()) AND org_id=current_org_id()) verlangt
-- die Org-Grenze für BEIDE Zweige inkl. Selbst-Update -- eine naive
-- Umstellung auf "user_id=self OR is_admin_of(org_id)" würde das
-- versehentlich aufweichen (Selbst-Update bekäme keine Org-Prüfung mehr).
-- Bleibt exakt wie zuvor, nur USING nachgezogen (Fund 4 der Zweitmeinung
-- war rein kosmetisch, hier bewusst nicht angewendet).
alter policy "contact_activities_update_own_or_admin" on public.contact_activities
  using (
    (user_id = (select auth.uid())) or is_admin_of(org_id)
  )
  with check (
    ((user_id = (select auth.uid())) or is_admin())
    and (org_id = current_org_id())
  );

-- ---------------------------------------------------------------------
-- contact_files
-- ---------------------------------------------------------------------

-- war: EXISTS(contacts c WHERE ... OR is_admin() OR guild_contact_permission(...))
alter policy "contact_files_delete" on public.contact_files
  using (
    exists (
      select 1 from public.contacts c
      where c.id = contact_files.contact_id
        and (
          (c.owner_id = (select auth.uid()))
          or is_admin_of(c.org_id)
          or guild_contact_permission(c.owner_id, true)
        )
    )
  );

alter policy "contact_files_select" on public.contact_files
  using (
    exists (
      select 1 from public.contacts c
      where c.id = contact_files.contact_id
        and (
          (c.owner_id = (select auth.uid()))
          or is_admin_of(c.org_id)
          or guild_contact_permission(c.owner_id, false)
        )
    )
  );

-- war: (uploaded_by=self) AND (org_id=current_org_id()) AND EXISTS(contacts
-- c WHERE ... OR is_admin() OR ...) -- Fund 3 der Zweitmeinung: exakt
-- dasselbe bare-is_admin()-Muster wie die beiden Policies oben, beim
-- ersten Durchgang übersehen.
alter policy "contact_files_insert" on public.contact_files
  with check (
    (uploaded_by = (select auth.uid()))
    and (org_id = current_org_id())
    and exists (
      select 1 from public.contacts c
      where c.id = contact_files.contact_id
        and (
          (c.owner_id = (select auth.uid()))
          or is_admin_of(c.org_id)
          or guild_contact_permission(c.owner_id, true)
        )
    )
  );

-- ---------------------------------------------------------------------
-- contacts (das wichtigste einzelne Fundstück -- Kundendatenbank)
-- ---------------------------------------------------------------------

-- war: (... eigener Pool-Zweig ...) OR (owner_id=self OR is_admin() OR
-- (org_id=current_org_id() AND contacts_shared_for_org()) OR
-- guild_contact_permission(...))
alter policy "contacts_select_visible" on public.contacts
  using (
    ((owner_id is null) and (guild_id is not null) and exists (
      select 1 from public.guild_members gm
      where gm.guild_id = contacts.guild_id and gm.member_id = (select auth.uid())
    ))
    or (
      (owner_id = (select auth.uid()))
      or is_admin_of(org_id)
      or ((org_id = current_org_id()) and contacts_shared_for_org())
      or guild_contact_permission(owner_id, false)
    )
  );

-- ---------------------------------------------------------------------
-- guild_invitations / guild_quest_log
-- ---------------------------------------------------------------------

-- war: (invited_user_id=self) OR (invited_by=self) OR is_admin()
alter policy "guild_invitations_select" on public.guild_invitations
  using (
    (invited_user_id = (select auth.uid()))
    or (invited_by = (select auth.uid()))
    or is_admin_of(org_id)
  );

-- war: EXISTS(guild_members...) OR is_admin()
alter policy "guild_quest_log_select" on public.guild_quest_log
  using (
    exists (
      select 1 from public.guild_members gm
      where gm.guild_id = guild_quest_log.guild_id and gm.member_id = (select auth.uid())
    )
    or is_admin_of(org_id)
  );

-- ---------------------------------------------------------------------
-- sales
-- ---------------------------------------------------------------------

-- war: EXISTS(contacts c WHERE ... OR is_admin() OR ...)
alter policy "sales_delete_like_contact" on public.sales
  using (
    exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id
        and (
          ((c.owner_id is null) and (c.guild_id is not null) and guild_leadership_permission(c.guild_id))
          or (c.owner_id = (select auth.uid()))
          or is_admin_of(c.org_id)
          or guild_contact_permission(c.owner_id, true)
        )
    )
  );

-- war: äußere Bedingung (org_id=current_org_id() AND created_by=self AND
-- EXISTS(...)) bereits org-gebunden -- ABER die innere EXISTS-Prüfung
-- erlaubte via bare is_admin(), einen Verkauf an eine FREMDE Org-Kontakt-
-- ID zu hängen. Fix: is_admin()-Zweig innerhalb der EXISTS wird durch
-- is_admin_of(c.org_id) ersetzt -- prüft den referenzierten Kontakt,
-- nicht die eigene sales-Zeile (die war schon durch die äußere Klausel
-- abgedeckt).
alter policy "sales_insert_like_contact" on public.sales
  with check (
    (org_id = current_org_id())
    and (created_by = (select auth.uid()))
    and exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id
        and (
          ((c.owner_id is null) and (c.guild_id is not null) and guild_leadership_permission(c.guild_id))
          or (c.owner_id = (select auth.uid()))
          or is_admin_of(c.org_id)
          or guild_contact_permission(c.owner_id, true)
        )
    )
  );

-- war: EXISTS(contacts c WHERE ... OR is_admin() OR ((c.org_id=current_org_id())
-- AND contacts_shared_for_org()) OR ...) -- Fund 1 der Zweitmeinung: beim
-- ersten Entwurf hier versehentlich die bestehende Org-Grenze um
-- contacts_shared_for_org() mit verloren, jetzt wiederhergestellt.
alter policy "sales_select_like_contact" on public.sales
  using (
    exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id
        and (
          (c.owner_id = (select auth.uid()))
          or is_admin_of(c.org_id)
          or ((c.org_id = current_org_id()) and contacts_shared_for_org())
          or guild_contact_permission(c.owner_id, false)
        )
    )
  );

-- ---------------------------------------------------------------------
-- tasks
-- ---------------------------------------------------------------------

-- war: (owner_id=self) OR is_admin()
alter policy "tasks_delete_own_or_admin" on public.tasks
  using (
    (owner_id = (select auth.uid())) or is_admin_of(org_id)
  );

alter policy "tasks_select_own_or_admin" on public.tasks
  using (
    (owner_id = (select auth.uid())) or is_admin_of(org_id)
  );

-- ---------------------------------------------------------------------
-- termin_invitations / termin_series / termine
-- ---------------------------------------------------------------------

-- war: (invited_user_id=self) OR (organizer_id=self) OR EXISTS(...) OR is_admin()
alter policy "termin_invitations_select" on public.termin_invitations
  using (
    (invited_user_id = (select auth.uid()))
    or (organizer_id = (select auth.uid()))
    or exists (
      select 1 from public.termine t
      where t.id = termin_invitations.termin_id and t.owner_id = (select auth.uid())
    )
    or is_admin_of(org_id)
  );

-- war: (owner_id=self) OR is_admin()
alter policy "termin_series_delete_owner_or_admin" on public.termin_series
  using (
    (owner_id = (select auth.uid())) or is_admin_of(org_id)
  );

alter policy "termin_series_select_own_or_admin" on public.termin_series
  using (
    (owner_id = (select auth.uid())) or is_admin_of(org_id)
  );

-- war: ((owner_id=self) AND (organizer_id IS NULL)) OR is_admin()
alter policy "termine_delete_owner_or_admin" on public.termine
  using (
    ((owner_id = (select auth.uid())) and (organizer_id is null)) or is_admin_of(org_id)
  );

-- war: (owner_id=self) OR is_admin() OR ((contact_id IS NOT NULL) AND EXISTS(...))
alter policy "termine_select_visible" on public.termine
  using (
    (owner_id = (select auth.uid()))
    or is_admin_of(org_id)
    or (
      (contact_id is not null)
      and exists (
        select 1 from public.contacts c
        where c.id = termine.contact_id and guild_contact_permission(c.owner_id, false)
      )
    )
  );

-- ---------------------------------------------------------------------
-- storage.objects (Bucket "contact-files") -- Fund 3 der Zweitmeinung:
-- die ursprüngliche Bestandsaufnahme fragte nur schemaname='public' ab
-- und übersah dieses Schema komplett. Jeweils zweiter Zweig
-- (Aufräum-Warteschlange) war bereits korrekt org-gebunden und bleibt
-- unangetastet -- nur der contacts-EXISTS-Zweig wird gefixt.
-- ---------------------------------------------------------------------

-- war: EXISTS(contacts c WHERE ... OR is_admin() OR guild_contact_permission(...))
--      OR EXISTS(contact_file_deletion_queue q WHERE ... AND is_admin())
alter policy "contact_files_storage_select" on storage.objects
  using (
    (bucket_id = 'contact-files'::text)
    and (
      exists (
        select 1 from public.contacts c
        where (c.id)::text = (storage.foldername(objects.name))[1]
          and (
            (c.owner_id = (select auth.uid()))
            or is_admin_of(c.org_id)
            or public.guild_contact_permission(c.owner_id, false)
          )
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
    (bucket_id = 'contact-files'::text)
    and (
      exists (
        select 1 from public.contacts c
        where (c.id)::text = (storage.foldername(objects.name))[1]
          and (
            (c.owner_id = (select auth.uid()))
            or is_admin_of(c.org_id)
            or public.guild_contact_permission(c.owner_id, true)
          )
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
    (bucket_id = 'contact-files'::text)
    and exists (
      select 1 from public.contacts c
      where (c.id)::text = (storage.foldername(objects.name))[1]
        and (
          (c.owner_id = (select auth.uid()))
          or is_admin_of(c.org_id)
          or public.guild_contact_permission(c.owner_id, true)
        )
    )
  );

-- ---------------------------------------------------------------------
-- Funktion: guild_sales_metric_total() -- bare is_admin()-Fallback
-- erlaubte, die Verkaufssumme EINER FREMDEN Gilde (anderer Organisation)
-- abzufragen, solange man irgendwo Admin war.
-- ---------------------------------------------------------------------

create or replace function public.guild_sales_metric_total(
  p_guild_id uuid, p_field text, p_category text, p_year int
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric;
begin
  if not exists(select 1 from public.guild_members gm where gm.guild_id = p_guild_id and gm.member_id = auth.uid())
     and not coalesce(is_admin_of((select g.org_id from public.guilds g where g.id = p_guild_id)), false) then
    raise exception 'Kein Zugriff auf diese Gilde.';
  end if;
  if p_field not in ('bewertungssumme','laufender_beitrag') then
    raise exception 'Ungültiges Feld: %', p_field;
  end if;

  execute format(
    'select coalesce(sum(s.%I),0) from public.sales s
     join public.products pr on pr.id = s.product_id
     join public.guild_members gm on gm.member_id = s.created_by
     where gm.guild_id = $1
       and s.status = ''gewonnen''
       and extract(year from coalesce(s.vertragsbeginn, s.datum)) = $2
       and ($3 is null or pr.category = $3)',
    p_field
  ) into v_total using p_guild_id, p_year, p_category;

  return v_total;
end;
$$;

commit;
