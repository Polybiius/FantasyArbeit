-- Fehlende Indizes auf Fremdschlüssel-Spalten (33 Stück) + Absicherung des
-- search_path bei 7 SECURITY-DEFINER-nahen Funktionen.
--
-- Gefunden per `supabase db advisors --linked` (offizieller Supabase-
-- Sicherheits-/Performance-Check), nicht durch Vermutung. Rein additiv,
-- nichts Destruktives: neue Indizes und ein zusätzliches SET auf
-- bestehenden Funktionen, keine Logik-/Datenänderung.
--
-- Postgres indiziert Fremdschlüssel nicht automatisch (bekanntes Muster
-- aus diesem Projekt, siehe Patch 17/17b) -- diese 33 sind seither bei
-- neueren Tabellen (Kalender, Gilden, Dateien, Chronik) durchgerutscht.

create index if not exists access_audit_log_admin_id_idx on public.access_audit_log(admin_id);
create index if not exists action_log_contact_id_idx on public.action_log(contact_id);
create index if not exists action_log_location_id_idx on public.action_log(location_id);
create index if not exists contact_activities_action_log_id_idx on public.contact_activities(action_log_id);
create index if not exists contact_activities_user_id_idx on public.contact_activities(user_id);
create index if not exists contact_files_org_id_idx on public.contact_files(org_id);
create index if not exists contact_files_uploaded_by_idx on public.contact_files(uploaded_by);
create index if not exists contacts_guild_id_idx on public.contacts(guild_id);
create index if not exists error_log_user_id_idx on public.error_log(user_id);
create index if not exists friends_friend_id_idx on public.friends(friend_id);
create index if not exists friends_org_id_idx on public.friends(org_id);
create index if not exists guild_members_guild_id_idx on public.guild_members(guild_id);
create index if not exists guild_members_org_id_idx on public.guild_members(org_id);
create index if not exists guilds_founder_id_idx on public.guilds(founder_id);
create index if not exists guilds_org_id_idx on public.guilds(org_id);
create index if not exists journal_entries_org_id_idx on public.journal_entries(org_id);
create index if not exists journal_entry_mentions_contact_id_idx on public.journal_entry_mentions(contact_id);
create index if not exists journal_entry_mentions_org_id_idx on public.journal_entry_mentions(org_id);
create index if not exists journal_photos_org_id_idx on public.journal_photos(org_id);
create index if not exists locations_created_by_idx on public.locations(created_by);
create index if not exists locations_guild_id_idx on public.locations(guild_id);
create index if not exists locations_owner_id_idx on public.locations(owner_id);
create index if not exists sales_created_by_idx on public.sales(created_by);
create index if not exists termin_series_contact_id_idx on public.termin_series(contact_id);
create index if not exists termin_series_location_id_idx on public.termin_series(location_id);
create index if not exists termin_series_org_id_idx on public.termin_series(org_id);
create index if not exists termin_series_owner_id_idx on public.termin_series(owner_id);
create index if not exists termine_contact_id_idx on public.termine(contact_id);
create index if not exists termine_location_id_idx on public.termine(location_id);
create index if not exists termine_org_id_idx on public.termine(org_id);
create index if not exists termine_owner_id_idx on public.termine(owner_id);
create index if not exists termine_series_id_idx on public.termine(series_id);
create index if not exists user_inventory_org_id_idx on public.user_inventory(org_id);

-- search_path-Härtung: ohne festen search_path könnte eine Funktion mit
-- erhöhten Rechten (SECURITY DEFINER) theoretisch durch ein Schema
-- gleichen Namens im Suchpfad ausgetrickst werden (search_path hijacking).
-- Alle sieben sind Null-Argument-Funktionen, ALTER FUNCTION braucht daher
-- keine Signatur-Angabe außer dem Namen.
alter function public.contacts_shared_for_org() set search_path = public;
alter function public.sync_contacts_owner_on_location_reassign() set search_path = public;
alter function public.current_org_id() set search_path = public;
alter function public.is_admin() set search_path = public;
alter function public.set_initial_seen_patch() set search_path = public;
alter function public.protect_privileged_profile_fields() set search_path = public;
alter function public.enforce_profile_insert_defaults() set search_path = public;
