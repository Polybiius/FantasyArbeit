-- Migration: RLS-Performance-Haertung (auth_rls_initplan + multiple_permissive_policies)
-- Reine Effizienz-Migration, KEINE Verhaltensaenderung. Zwei Muster:
-- 1) auth.uid() wird zu (select auth.uid()) gewrappt, damit Postgres es einmal pro
--    Query statt einmal pro Zeile auswertet (InitPlan-Caching, Supabase-Standardfix).
-- 2) Tabellen mit mehreren permissiven Policies fuer dieselbe Aktion werden zu je einer
--    Policy zusammengefasst. Postgres verknuepft mehrere permissive Policies ohnehin per
--    OR (USING-Klauseln separat, WITH CHECK-Klauseln separat) -- eine einzelne Policy mit
--    denselben, per OR verknuepften Bedingungen ist exakt aequivalent, nur schneller zu
--    pruefen (ein statt mehrere Policy-Checks pro Zeile).
--
-- Vor dem Einspielen in einer begin/rollback-Transaktion gegen die echte DB getestet:
-- 35 Sichtbarkeits-Snapshots (7 echte Nutzer x 5 der am staerksten betroffenen
-- Tabellen) vorher/nachher exakt identisch, plus 7 gezielte Schreibproben (Kontakt-
-- Gildenpool-Zuweisung, Gildenfuehrer-Update, alle Verweigerungsfaelle) -- alle
-- bestanden.

-- ============================================================
-- TEIL A: zentrale Hilfsfunktionen -- wrapt auth.uid() an der Quelle,
-- wirkt sich auf ALLE Policies aus, die current_org_id()/is_admin()/etc. aufrufen.
-- ============================================================

CREATE OR REPLACE FUNCTION public.current_org_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select org_id from public.profiles where id = (select auth.uid())
$function$;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select role from public.profiles where id = (select auth.uid())) = 'admin', false)
$function$;

CREATE OR REPLACE FUNCTION public.guild_contact_permission(target_owner uuid, need_write boolean)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.guild_members mine
    JOIN public.guild_members theirs
      ON theirs.guild_id = mine.guild_id
     AND theirs.member_id = target_owner
    WHERE mine.member_id = (select auth.uid())
      AND (NOT need_write OR mine.contacts_access = 'write')
  );
$function$;

CREATE OR REPLACE FUNCTION public.guild_dungeon_permission(loc_guild_id uuid, need_write boolean)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT loc_guild_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.guild_members mine
    WHERE mine.member_id = (select auth.uid())
      AND mine.guild_id = loc_guild_id
      AND (NOT need_write OR mine.dungeons_access = 'write')
  );
$function$;

CREATE OR REPLACE FUNCTION public.guild_founder_of_member(target_owner uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.guild_members gm
    JOIN public.guilds g ON g.id = gm.guild_id
    WHERE gm.member_id = target_owner
      AND g.founder_id = (select auth.uid())
  );
$function$;

CREATE OR REPLACE FUNCTION public.guild_leadership_permission(target_guild uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    exists (
      select 1 from public.guilds g
      where g.id = target_guild and g.founder_id = (select auth.uid())
    )
    or exists (
      select 1 from public.guild_members gm
      where gm.guild_id = target_guild
        and gm.member_id = (select auth.uid())
        and gm.team_rights = true
    );
$function$;

CREATE OR REPLACE FUNCTION public.socially_visible(target_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT target_user = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.friends f
      WHERE f.status = 'accepted'
        AND ((f.owner_id = (select auth.uid()) AND f.friend_id = target_user)
          OR (f.friend_id = (select auth.uid()) AND f.owner_id = target_user))
    )
    OR EXISTS (
      SELECT 1 FROM public.guild_members mine
      JOIN public.guild_members theirs ON theirs.guild_id = mine.guild_id
      WHERE mine.member_id = (select auth.uid()) AND theirs.member_id = target_user
    );
$function$;

-- ============================================================
-- TEIL B: einzelne Policies mit direktem auth.uid()-Aufruf, die NICHT Teil
-- einer Zusammenlegung in Teil C sind -- per ALTER POLICY neu gewrappt,
-- Name/Rolle/Befehl bleiben unveraendert.
-- ============================================================

ALTER POLICY "contact_activities_delete_own_or_admin" ON public.contact_activities
  USING (((user_id = (select auth.uid())) OR is_admin()));

ALTER POLICY "contact_activities_insert_own" ON public.contact_activities
  WITH CHECK (((user_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "contact_activities_update_own_or_admin" ON public.contact_activities
  USING (((user_id = (select auth.uid())) OR is_admin()))
  WITH CHECK ((((user_id = (select auth.uid())) OR is_admin()) AND (org_id = current_org_id())));

ALTER POLICY "contact_files_delete" ON public.contact_files
  USING ((EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = contact_files.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin() OR guild_contact_permission(c.owner_id, true))))));

ALTER POLICY "contact_files_insert" ON public.contact_files
  WITH CHECK (((uploaded_by = (select auth.uid())) AND (org_id = current_org_id()) AND (EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = contact_files.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin() OR guild_contact_permission(c.owner_id, true)))))));

ALTER POLICY "contact_files_select" ON public.contact_files
  USING ((EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = contact_files.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin() OR guild_contact_permission(c.owner_id, false))))));

ALTER POLICY "contacts_delete_owner_or_admin" ON public.contacts
  USING (((owner_id = (select auth.uid())) OR is_admin()));

ALTER POLICY "contacts_insert_own" ON public.contacts
  WITH CHECK (((owner_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "friends_insert_own" ON public.friends
  WITH CHECK (((owner_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "friends_select_related" ON public.friends
  USING (((owner_id = (select auth.uid())) OR (friend_id = (select auth.uid()))));

ALTER POLICY "friends_update_recipient_accepts" ON public.friends
  USING ((friend_id = (select auth.uid())))
  WITH CHECK (((friend_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "guild_members_delete_self_or_founder" ON public.guild_members
  USING (((member_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM guilds g
  WHERE ((g.id = guild_members.guild_id) AND (g.founder_id = (select auth.uid())))))));

ALTER POLICY "guild_members_update_founder_sets_rights" ON public.guild_members
  USING ((EXISTS ( SELECT 1
   FROM guilds g
  WHERE ((g.id = guild_members.guild_id) AND (g.founder_id = (select auth.uid()))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM guilds g
  WHERE ((g.id = guild_members.guild_id) AND (g.founder_id = (select auth.uid()))))));

ALTER POLICY "guilds_insert_self_founder" ON public.guilds
  WITH CHECK (((org_id = current_org_id()) AND (founder_id = (select auth.uid()))));

ALTER POLICY "journal_insert_own_only" ON public.journal_entries
  WITH CHECK (((user_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "journal_select_own_only" ON public.journal_entries
  USING ((user_id = (select auth.uid())));

ALTER POLICY "journal_update_own_only" ON public.journal_entries
  USING ((user_id = (select auth.uid())))
  WITH CHECK (((user_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "journal_mentions_delete_own_only" ON public.journal_entry_mentions
  USING ((user_id = (select auth.uid())));

ALTER POLICY "journal_mentions_insert_own_only" ON public.journal_entry_mentions
  WITH CHECK (((user_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "journal_mentions_select_own_only" ON public.journal_entry_mentions
  USING ((user_id = (select auth.uid())));

ALTER POLICY "journal_photos_insert_own" ON public.journal_photos
  WITH CHECK (((user_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "journal_photos_select_own" ON public.journal_photos
  USING ((user_id = (select auth.uid())));

ALTER POLICY "journal_photos_update_own" ON public.journal_photos
  USING ((user_id = (select auth.uid())))
  WITH CHECK (((user_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "locations_insert_org_members" ON public.locations
  WITH CHECK (((org_id = current_org_id()) AND (created_by = (select auth.uid())) AND ((owner_id = (select auth.uid())) OR (owner_id IS NULL)) AND ((guild_id IS NULL) OR guild_dungeon_permission(guild_id, true))));

ALTER POLICY "locations_select_org" ON public.locations
  USING (((org_id = current_org_id()) AND ((owner_id = (select auth.uid())) OR (created_by = (select auth.uid())) OR is_admin() OR guild_dungeon_permission(guild_id, false) OR guild_founder_of_member(owner_id) OR guild_founder_of_member(created_by))));

ALTER POLICY "profiles_insert_self" ON public.profiles
  WITH CHECK ((id = (select auth.uid())));

ALTER POLICY "sales_delete_like_contact" ON public.sales
  USING ((EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = sales.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin())))));

ALTER POLICY "sales_insert_like_contact" ON public.sales
  WITH CHECK (((org_id = current_org_id()) AND (created_by = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = sales.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin()))))));

ALTER POLICY "sales_select_like_contact" ON public.sales
  USING ((EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = sales.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin() OR ((c.org_id = current_org_id()) AND contacts_shared_for_org()) OR guild_contact_permission(c.owner_id, false))))));

ALTER POLICY "sales_update_like_contact" ON public.sales
  USING ((EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = sales.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin())))))
  WITH CHECK (((EXISTS ( SELECT 1
   FROM contacts c
  WHERE ((c.id = sales.contact_id) AND ((c.owner_id = (select auth.uid())) OR is_admin())))) AND (org_id = current_org_id())));

ALTER POLICY "schema_patches_select_all" ON public.schema_patches
  USING (((select auth.uid()) IS NOT NULL));

ALTER POLICY "termin_series_delete_owner_or_admin" ON public.termin_series
  USING (((owner_id = (select auth.uid())) OR is_admin()));

ALTER POLICY "termin_series_insert_own" ON public.termin_series
  WITH CHECK (((owner_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "termin_series_select_own_or_admin" ON public.termin_series
  USING (((owner_id = (select auth.uid())) OR is_admin()));

ALTER POLICY "termin_series_update_owner_or_admin" ON public.termin_series
  USING (((owner_id = (select auth.uid())) OR is_admin()))
  WITH CHECK ((((owner_id = (select auth.uid())) OR is_admin()) AND (org_id = current_org_id())));

ALTER POLICY "termine_delete_owner_or_admin" ON public.termine
  USING (((owner_id = (select auth.uid())) OR is_admin()));

ALTER POLICY "termine_insert_own" ON public.termine
  WITH CHECK (((owner_id = (select auth.uid())) AND (org_id = current_org_id())));

ALTER POLICY "termine_update_owner_or_admin" ON public.termine
  USING (((owner_id = (select auth.uid())) OR is_admin()))
  WITH CHECK ((((owner_id = (select auth.uid())) OR is_admin()) AND (org_id = current_org_id())));

ALTER POLICY "inventory_select_own" ON public.user_inventory
  USING ((user_id = (select auth.uid())));

-- ============================================================
-- TEIL C: Tabellen mit mehreren permissiven Policies je Aktion --
-- zu je einer zusammengelegt (Bedingungen bleiben per OR verknuepft,
-- exakt wie Postgres es bei mehreren permissiven Policies ohnehin schon tut).
-- ============================================================

-- action_log SELECT: log_select_admin_sees_all_in_org + log_select_own +
-- log_select_shared_contact_activity -> log_select_visible
DROP POLICY "log_select_admin_sees_all_in_org" ON public.action_log;
DROP POLICY "log_select_own" ON public.action_log;
DROP POLICY "log_select_shared_contact_activity" ON public.action_log;
CREATE POLICY "log_select_visible" ON public.action_log
  FOR SELECT
  USING (
    (user_id = (select auth.uid()))
    OR ((org_id = current_org_id()) AND is_admin())
    OR ((contact_id IS NOT NULL) AND (EXISTS ( SELECT 1
       FROM contacts c
      WHERE ((c.id = action_log.contact_id) AND (c.org_id = current_org_id()) AND (contacts_shared_for_org() OR guild_contact_permission(c.owner_id, false))))))
  );

-- contact_activities SELECT: contact_activities_select_own_or_admin +
-- contact_activities_select_shared_contact -> contact_activities_select_visible
DROP POLICY "contact_activities_select_own_or_admin" ON public.contact_activities;
DROP POLICY "contact_activities_select_shared_contact" ON public.contact_activities;
CREATE POLICY "contact_activities_select_visible" ON public.contact_activities
  FOR SELECT
  USING (
    ((user_id = (select auth.uid())) OR is_admin())
    OR (EXISTS ( SELECT 1
       FROM contacts c
      WHERE ((c.id = contact_activities.contact_id) AND guild_contact_permission(c.owner_id, false))))
  );

-- contacts SELECT: contacts_select_guild_pool + contacts_select_own_or_shared_or_admin
-- -> contacts_select_visible
DROP POLICY "contacts_select_guild_pool" ON public.contacts;
DROP POLICY "contacts_select_own_or_shared_or_admin" ON public.contacts;
CREATE POLICY "contacts_select_visible" ON public.contacts
  FOR SELECT
  USING (
    ((owner_id IS NULL) AND (guild_id IS NOT NULL) AND (EXISTS ( SELECT 1
       FROM guild_members gm
      WHERE ((gm.guild_id = contacts.guild_id) AND (gm.member_id = (select auth.uid()))))))
    OR ((owner_id = (select auth.uid())) OR is_admin() OR ((org_id = current_org_id()) AND contacts_shared_for_org()) OR guild_contact_permission(owner_id, false))
  );

-- contacts UPDATE: contacts_update_guild_pool_assignment + contacts_update_owner_or_admin
-- -> contacts_update_visible
DROP POLICY "contacts_update_guild_pool_assignment" ON public.contacts;
DROP POLICY "contacts_update_owner_or_admin" ON public.contacts;
CREATE POLICY "contacts_update_visible" ON public.contacts
  FOR UPDATE
  USING (
    ((owner_id IS NULL) AND (guild_id IS NOT NULL) AND guild_leadership_permission(guild_id))
    OR ((owner_id = (select auth.uid())) OR is_admin() OR guild_contact_permission(owner_id, true))
  )
  WITH CHECK (
    ((guild_id IS NOT NULL) AND guild_leadership_permission(guild_id) AND ((owner_id IS NULL) OR (EXISTS ( SELECT 1
       FROM guild_members gm
      WHERE ((gm.guild_id = contacts.guild_id) AND (gm.member_id = contacts.owner_id))))))
    OR (((owner_id = (select auth.uid())) OR is_admin() OR guild_contact_permission(owner_id, true)) AND (org_id = current_org_id()))
  );

-- friends DELETE: friends_delete_own + friends_delete_recipient_declines
-- -> friends_delete_visible
DROP POLICY "friends_delete_own" ON public.friends;
DROP POLICY "friends_delete_recipient_declines" ON public.friends;
CREATE POLICY "friends_delete_visible" ON public.friends
  FOR DELETE
  USING (
    (owner_id = (select auth.uid()))
    OR (friend_id = (select auth.uid()))
  );

-- guild_members INSERT: guild_members_insert_founder_adds + guild_members_insert_self_join
-- -> guild_members_insert_allowed
DROP POLICY "guild_members_insert_founder_adds" ON public.guild_members;
DROP POLICY "guild_members_insert_self_join" ON public.guild_members;
CREATE POLICY "guild_members_insert_allowed" ON public.guild_members
  FOR INSERT
  WITH CHECK (
    ((org_id = current_org_id()) AND (EXISTS ( SELECT 1
       FROM guilds g
      WHERE ((g.id = guild_members.guild_id) AND (g.founder_id = (select auth.uid()))))))
    OR ((member_id = (select auth.uid())) AND (org_id = current_org_id()))
  );

-- locations UPDATE: locations_update_admin_only + locations_update_guild_admission
-- -> locations_update_visible
-- (locations_update_admin_only hatte keine eigene WITH CHECK -> Postgres nutzt dafuer
-- automatisch dieselbe Bedingung wie USING; deshalb hier explizit dupliziert.)
DROP POLICY "locations_update_admin_only" ON public.locations;
DROP POLICY "locations_update_guild_admission" ON public.locations;
CREATE POLICY "locations_update_visible" ON public.locations
  FOR UPDATE
  USING (
    ((org_id = current_org_id()) AND is_admin())
    OR (guild_founder_of_member(owner_id) OR guild_founder_of_member(created_by))
  )
  WITH CHECK (
    ((org_id = current_org_id()) AND is_admin())
    OR ((guild_id IS NULL) OR (EXISTS ( SELECT 1
       FROM guilds g
      WHERE ((g.id = locations.guild_id) AND (g.founder_id = (select auth.uid()))))))
  );

-- profiles SELECT: profiles_select_own + profiles_select_same_org -> profiles_select_visible
DROP POLICY "profiles_select_own" ON public.profiles;
DROP POLICY "profiles_select_same_org" ON public.profiles;
CREATE POLICY "profiles_select_visible" ON public.profiles
  FOR SELECT
  USING (
    (id = (select auth.uid()))
    OR (org_id = current_org_id())
  );

-- profiles UPDATE: profiles_update_admin + profiles_update_own -> profiles_update_visible
-- (beide Original-Policies hatten keine eigene WITH CHECK, Postgres spiegelt USING --
-- die neue Policy laesst WITH CHECK deshalb bewusst ebenfalls weg, gleiche Wirkung.
-- protect_privileged_profile_fields()-Trigger, Patch 38/39, bleibt unabhaengig davon
-- weiterhin die Spalten-Haertung fuer role/character_class/org_id/total_xp/level.)
DROP POLICY "profiles_update_admin" ON public.profiles;
DROP POLICY "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_visible" ON public.profiles
  FOR UPDATE
  USING (
    ((org_id = current_org_id()) AND is_admin())
    OR (id = (select auth.uid()))
  );

-- termine SELECT: termine_select_own_or_admin + termine_select_shared_contact
-- -> termine_select_visible
DROP POLICY "termine_select_own_or_admin" ON public.termine;
DROP POLICY "termine_select_shared_contact" ON public.termine;
CREATE POLICY "termine_select_visible" ON public.termine
  FOR SELECT
  USING (
    ((owner_id = (select auth.uid())) OR is_admin())
    OR ((contact_id IS NOT NULL) AND (EXISTS ( SELECT 1
       FROM contacts c
      WHERE ((c.id = termine.contact_id) AND guild_contact_permission(c.owner_id, false)))))
  );
