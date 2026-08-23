-- ============================================================
-- locations/sales/termine/termin_series: dieselbe strukturelle Härtung
-- wie bei contacts (20260824160000+20260824170000), auf die drei
-- übrigen Tabellen mit optimistischem Sperren übertragen. Direktes
-- UPDATE ist für normale Nutzer komplett gesperrt, einziger verbleibender
-- Weg sind die neuen SECURITY-DEFINER-Funktionen unten -- ein
-- vergessener Aufruf des Frontend-Helfers fällt jetzt als echter
-- RLS-Fehler auf statt lautlos ins alte Verhalten zurückzufallen.
--
-- Anders als bei contacts (eine einzige, breite Schreibfunktion) hier
-- MEHRERE schmale Funktionen -- weil sich die vier Tabellen strukturell
-- unterscheiden:
-- - locations: zwei völlig verschiedene Schreibvorgänge mit eigener
--   Berechtigungslogik (Gilden-Pool-Aufnahme durch den Gildenführer vs.
--   Account-Zuweisung, admin-exklusiv) -- eine gemeinsame Allowlist-
--   Funktion hätte diese beiden Fälle künstlich vermischt.
-- - sales: nur ein Schreibvorgang (Kündigen), Berechtigung hängt am
--   verknüpften Kontakt, nicht an sales selbst.
-- - termine/termin_series: wie contacts mehrere Felder, aber ohne die
--   Gilden-Komplexität von contacts -- einfaches owner_id=auth.uid()
--   OR is_admin(), analog zur bisherigen Policy.
-- ============================================================

-- ---------------------------------------------------------------
-- LOCATIONS
-- ---------------------------------------------------------------

-- Einzige Quelle der Wahrheit für "darf X diesen Dungeon anfassen" --
-- 1:1 aus der USING-Klausel von locations_update_visible übernommen.
create or replace function public.locations_writable(target public.locations)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    ((target.org_id = current_org_id()) and is_admin())
    or guild_founder_of_member(target.owner_id)
    or guild_founder_of_member(target.created_by);
$$;

-- Gilden-Pool-Aufnahme/-Entlassung (Checkbox in loadGuildRightsPoolList()).
-- p_guild_id = NULL entfernt den Dungeon wieder aus dem Pool -- dafür
-- reicht locations_writable() allein (WITH CHECK der alten Policy war bei
-- guild_id IS NULL ohnehin immer erfüllt). Bei einem Ziel-Wert muss der
-- Aufrufer zusätzlich Gründer GENAU dieser Gilde sein (oder Admin) --
-- entspricht der bisherigen WITH-CHECK-Bedingung.
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

  if not locations_writable(current_row) then
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
  return updated_row;
end;
$$;

grant execute on function public.admit_location_to_guild_pool_locked(uuid, uuid, timestamptz) to authenticated;

-- Account-Zuweisung (renderAccountPool(), nur für Admins im UI sichtbar).
-- Bewusst explizit admin-only geprüft statt sich allein auf den
-- bestehenden protect_location_owner_field()-Trigger (Migration
-- 20260822120000) zu verlassen -- der korrigiert bei Nicht-Admins nur
-- still zurück + protokolliert, bleibt hier als zusätzliche
-- Verteidigungsebene unverändert bestehen, gibt aber keinen klaren
-- Fehler an einen (ohnehin nie vorgesehenen) Nicht-Admin-Aufrufer zurück.
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
  if not is_admin() then
    raise exception 'Nur Admins dürfen Dungeon-Accounts zuweisen' using errcode = '42501';
  end if;

  select * into current_row from public.locations where id = p_id for update;
  if not found then
    raise exception 'Dungeon nicht gefunden' using errcode = '42501';
  end if;

  update public.locations set owner_id = p_owner_id
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;
  return updated_row;
end;
$$;

grant execute on function public.assign_location_owner_locked(uuid, uuid, timestamptz) to authenticated;

drop policy if exists "locations_update_visible" on public.locations;

-- ---------------------------------------------------------------
-- SALES
-- ---------------------------------------------------------------

-- 1:1 aus der USING-Klausel von sales_update_like_contact übernommen --
-- Berechtigung hängt am verknüpften Kontakt, nicht an sales selbst.
create or replace function public.sales_writable(target public.sales)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.contacts c
    where c.id = target.contact_id
      and (c.owner_id = (select auth.uid()) or is_admin())
  );
$$;

-- Einziger echter Schreibvorgang: einen Vertrag als gekündigt/ausgelaufen
-- markieren (vertragsende setzen).
create or replace function public.cancel_sale_locked(
  p_id uuid,
  p_vertragsende date,
  p_expected_updated_at timestamptz
)
returns public.sales
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.sales;
  updated_row public.sales;
begin
  select * into current_row from public.sales where id = p_id for update;
  if not found then
    raise exception 'Verkauf nicht gefunden oder keine Berechtigung' using errcode = '42501';
  end if;

  if not sales_writable(current_row) then
    raise exception 'Keine Schreibberechtigung für diesen Verkauf' using errcode = '42501';
  end if;

  update public.sales set vertragsende = p_vertragsende
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;
  return updated_row;
end;
$$;

grant execute on function public.cancel_sale_locked(uuid, date, timestamptz) to authenticated;

drop policy if exists "sales_update_like_contact" on public.sales;

-- ---------------------------------------------------------------
-- TERMINE
-- ---------------------------------------------------------------

create or replace function public.termine_writable(target public.termine)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select (target.owner_id = (select auth.uid())) or is_admin();
$$;

-- Deckt alle vier Termin-Schreibformen ab (Serie verknüpfen nach Anlage,
-- Serie-weite Zeitänderung pro Einzeltermin, Einzeltermin-Bearbeitung) --
-- gleiche Allowlist-Technik wie bei contacts, da hier (anders als bei
-- locations) alle Schreibstellen dieselbe Berechtigungslogik teilen.
create or replace function public.update_termin_locked(
  p_id uuid,
  p_patch jsonb,
  p_expected_updated_at timestamptz
)
returns public.termine
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.termine;
  updated_row public.termine;
  allowed_keys text[] := array['title','start_at','end_at','contact_id','location_id','kanal','series_id'];
  k text;
begin
  select * into current_row from public.termine where id = p_id for update;
  if not found then
    raise exception 'Termin nicht gefunden oder keine Berechtigung' using errcode = '42501';
  end if;

  if not termine_writable(current_row) then
    raise exception 'Keine Schreibberechtigung für diesen Termin' using errcode = '42501';
  end if;

  for k in select jsonb_object_keys(coalesce(p_patch, '{}'::jsonb)) loop
    if not (k = any(allowed_keys)) then
      raise exception 'Feld % darf über update_termin_locked() nicht geändert werden', k using errcode = '42501';
    end if;
  end loop;

  update public.termine set
    title       = case when p_patch ? 'title'       then p_patch->>'title'                 else title end,
    start_at    = case when p_patch ? 'start_at'    then (p_patch->>'start_at')::timestamptz else start_at end,
    end_at      = case when p_patch ? 'end_at'      then (p_patch->>'end_at')::timestamptz   else end_at end,
    contact_id  = case when p_patch ? 'contact_id'  then (p_patch->>'contact_id')::uuid      else contact_id end,
    location_id = case when p_patch ? 'location_id' then (p_patch->>'location_id')::uuid     else location_id end,
    kanal       = case when p_patch ? 'kanal'       then p_patch->>'kanal'                   else kanal end,
    series_id   = case when p_patch ? 'series_id'   then (p_patch->>'series_id')::uuid       else series_id end
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;
  return updated_row;
end;
$$;

grant execute on function public.update_termin_locked(uuid, jsonb, timestamptz) to authenticated;

drop policy if exists "termine_update_owner_or_admin" on public.termine;

-- ---------------------------------------------------------------
-- TERMIN_SERIES
-- ---------------------------------------------------------------

create or replace function public.termin_series_writable(target public.termin_series)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select (target.owner_id = (select auth.uid())) or is_admin();
$$;

-- "Ganze Serie ändern" -- nur Uhrzeiten/Kanal, nie Titel/Wochentage/
-- Frequenz (die App bietet dafür ohnehin keinen Bearbeiten-Weg an, siehe
-- CLAUDE.md "Serientermine").
create or replace function public.update_termin_series_locked(
  p_id uuid,
  p_patch jsonb,
  p_expected_updated_at timestamptz
)
returns public.termin_series
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.termin_series;
  updated_row public.termin_series;
  allowed_keys text[] := array['start_time','end_time','kanal'];
  k text;
begin
  select * into current_row from public.termin_series where id = p_id for update;
  if not found then
    raise exception 'Serie nicht gefunden oder keine Berechtigung' using errcode = '42501';
  end if;

  if not termin_series_writable(current_row) then
    raise exception 'Keine Schreibberechtigung für diese Serie' using errcode = '42501';
  end if;

  for k in select jsonb_object_keys(coalesce(p_patch, '{}'::jsonb)) loop
    if not (k = any(allowed_keys)) then
      raise exception 'Feld % darf über update_termin_series_locked() nicht geändert werden', k using errcode = '42501';
    end if;
  end loop;

  update public.termin_series set
    start_time = case when p_patch ? 'start_time' then (p_patch->>'start_time')::time else start_time end,
    end_time   = case when p_patch ? 'end_time'   then (p_patch->>'end_time')::time   else end_time end,
    kanal      = case when p_patch ? 'kanal'       then p_patch->>'kanal'              else kanal end
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;
  return updated_row;
end;
$$;

grant execute on function public.update_termin_series_locked(uuid, jsonb, timestamptz) to authenticated;

drop policy if exists "termin_series_update_owner_or_admin" on public.termin_series;

-- ---------------------------------------------------------------
-- Anon-Rechte sofort einschränken (nicht wie bei contacts erst als
-- Nachtrag) -- keine der neuen Funktionen soll anonym aufrufbar sein,
-- die *_writable()-Helfer werden nur intern verwendet.
-- ---------------------------------------------------------------
revoke execute on function public.locations_writable(public.locations) from public, anon, authenticated;
revoke execute on function public.admit_location_to_guild_pool_locked(uuid, uuid, timestamptz) from public, anon;
revoke execute on function public.assign_location_owner_locked(uuid, uuid, timestamptz) from public, anon;
revoke execute on function public.sales_writable(public.sales) from public, anon, authenticated;
revoke execute on function public.cancel_sale_locked(uuid, date, timestamptz) from public, anon;
revoke execute on function public.termine_writable(public.termine) from public, anon, authenticated;
revoke execute on function public.update_termin_locked(uuid, jsonb, timestamptz) from public, anon;
revoke execute on function public.termin_series_writable(public.termin_series) from public, anon, authenticated;
revoke execute on function public.update_termin_series_locked(uuid, jsonb, timestamptz) from public, anon;
