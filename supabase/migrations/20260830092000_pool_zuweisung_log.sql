-- PATCH: Protokoll für Org-Pool-Zuweisungen + "neu zugewiesen"-Badge
--
-- Phase-1-Bauaufgabe (project_naechster_struktureller_schritt,
-- Abschnitt 8/9). Nutzer-Entscheidung: "wer der besitzer ist und wann
-- übertragen worden ist gerne dokumentieren" + "anzeigen, dass kontakte
-- zugewiesen sind find ich gut."
--
-- Bewusst EINFACH gehalten (v1, nach Nutzer-Rückmeldung "hab noch nicht
-- verstanden, was wir da haben" nachträglich abgespeckt): keine
-- Chronik-Integration am Kontakt, keine Kontakt-Sichtbarkeits-Logik
-- nachgebaut -- nur Org-Admin/alleiniger Gildenführer dürfen das
-- Protokoll lesen (reicht für die Pool-Seite selbst). Spätere
-- Erweiterung (Chronik-Eintrag, feinere Sichtbarkeit) jederzeit
-- nachrüstbar, kein Schema-Bruch.
--
-- Die drei Zuweisungs-Funktionen aus der vorherigen Migration
-- (20260830091000) werden hier ein zweites Mal per CREATE OR REPLACE
-- definiert -- diesmal inklusive des Logging-Inserts. Autorisierungs-
-- Logik bleibt identisch zur vorherigen Migration, nur um den Insert
-- ergänzt (CREATE OR REPLACE braucht den vollständigen Funktionskörper,
-- kein Diff möglich).
--
-- Rückbau: Logging-Inserts aus den drei Funktionen entfernen (auf den
-- Stand von 20260830091000 zurücksetzen), pool_zuweisung_log +
-- profiles.last_seen_pool_assignment droppen.
--
-- Nachgeschärft nach unabhängiger Zweitmeinung (/code-review high):
-- dieselbe Pool-Zustand-Einschränkung (owner_id/guild_id NULL) wie in
-- 20260830091000 auch hier in den drei erneut definierten Funktionen
-- nachgezogen (sonst würde dieser CREATE OR REPLACE die dortige
-- Härtung wieder überschreiben) -- plus zwei fehlende FK-Indizes
-- (assigned_by, new_guild_id) ergänzt, Projekt-Konvention seit Patch 17.

begin;

create table public.pool_zuweisung_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  entity_type text not null check (entity_type in ('contact','location')),
  entity_id uuid not null,
  entity_name_snapshot text not null,
  new_owner_id uuid references public.profiles(id) on delete set null,
  new_guild_id uuid references public.guilds(id) on delete set null,
  assigned_by uuid not null references public.profiles(id) on delete cascade,
  assigned_at timestamptz not null default now()
);
create index pool_zuweisung_log_org_id_idx on public.pool_zuweisung_log(org_id);
create index pool_zuweisung_log_new_owner_id_idx on public.pool_zuweisung_log(new_owner_id);
create index pool_zuweisung_log_assigned_by_idx on public.pool_zuweisung_log(assigned_by);
create index pool_zuweisung_log_new_guild_id_idx on public.pool_zuweisung_log(new_guild_id);

alter table public.pool_zuweisung_log enable row level security;

-- Kein Insert/Update/Delete für Clients -- ausschließlich per Insert
-- innerhalb der drei SECURITY-DEFINER-Zuweisungsfunktionen (laufen mit
-- erhöhten Rechten, RLS betrifft sie nicht). Gleiches Muster wie
-- access_audit_log/error_log: ein Protokoll wird nicht nachträglich
-- verändert.
--
-- Zusätzlich zu Org-Admin/Sole-Founder (Pool-Seite selbst) darf jede
-- Person ihre EIGENEN Zuweisungen sehen (new_owner_id = eigene ID) --
-- ohne diesen Zweig könnte der Badge-Hinweis "dir wurde etwas
-- zugewiesen" für ein normales, nicht-admin Teammitglied nie geladen
-- werden, obwohl genau das der Hauptzweck des Protokolls ist.
create policy "pool_zuweisung_log_select" on public.pool_zuweisung_log
  for select using (
    new_owner_id = (select auth.uid())
    or is_admin_of(org_id)
    or is_sole_guild_founder_of_org(org_id)
  );

alter table public.profiles add column if not exists last_seen_pool_assignment timestamptz;

-- ---------------------------------------------------------------------
-- admin_reassign_contact(): + Logging
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
    or (is_sole_guild_founder_of_org(v_contact.org_id) and v_contact.owner_id is null and v_contact.guild_id is null)
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
-- assign_location_owner_locked(): + Logging
-- ---------------------------------------------------------------------

create or replace function public.assign_location_owner_locked(
  p_id uuid,
  p_owner_id uuid,
  p_expected_updated_at timestamptz
)
returns public.locations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.locations;
  updated_row public.locations;
begin
  select * into current_row from public.locations where id = p_id for update;
  if not found then
    raise exception 'Dungeon nicht gefunden' using errcode = '42501';
  end if;

  if not (
    is_admin_of(current_row.org_id)
    or (is_sole_guild_founder_of_org(current_row.org_id) and current_row.owner_id is null)
  ) then
    raise exception 'Nur Admins oder der alleinige Gildenführer der eigenen Organisation dürfen Dungeon-Accounts zuweisen (Gildenführer nur für herrenlose Pool-Dungeons)' using errcode = '42501';
  end if;

  update public.locations set owner_id = p_owner_id
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;

  insert into public.pool_zuweisung_log
    (org_id, entity_type, entity_id, entity_name_snapshot, new_owner_id, new_guild_id, assigned_by)
  values
    (updated_row.org_id, 'location', updated_row.id, updated_row.name, updated_row.owner_id, updated_row.guild_id, (select auth.uid()));

  return updated_row;
end;
$$;

-- ---------------------------------------------------------------------
-- admit_location_to_guild_pool_locked(): + Logging
-- ---------------------------------------------------------------------

create or replace function public.admit_location_to_guild_pool_locked(
  p_id uuid,
  p_guild_id uuid,
  p_expected_updated_at timestamptz
)
returns public.locations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.locations;
  updated_row public.locations;
begin
  select * into current_row from public.locations where id = p_id for update;
  if not found then
    raise exception 'Dungeon nicht gefunden oder keine Berechtigung' using errcode = '42501';
  end if;

  if not (
    locations_writable(current_row)
    or (current_row.owner_id is null and is_sole_guild_founder_of_org(current_row.org_id))
  ) then
    raise exception 'Keine Schreibberechtigung für diesen Dungeon' using errcode = '42501';
  end if;

  if p_guild_id is not null and not (
    is_admin() or exists (
      select 1 from public.guilds g where g.id = p_guild_id and g.founder_id = (select auth.uid())
    )
  ) then
    raise exception 'Nur der Gildengründer darf einen Dungeon in seine Gilde aufnehmen' using errcode = '42501';
  end if;

  update public.locations set guild_id = p_guild_id
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;

  insert into public.pool_zuweisung_log
    (org_id, entity_type, entity_id, entity_name_snapshot, new_owner_id, new_guild_id, assigned_by)
  values
    (updated_row.org_id, 'location', updated_row.id, updated_row.name, updated_row.owner_id, updated_row.guild_id, (select auth.uid()));

  return updated_row;
end;
$$;

insert into public.schema_patches (patch_number, title) values
  (59, 'Kunden-/Dungeon-Pool: Verteilung durch Gildenführer')
on conflict (patch_number) do nothing;

commit;
