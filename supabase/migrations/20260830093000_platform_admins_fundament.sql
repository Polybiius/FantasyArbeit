-- PATCH: Plattformadmin-Fundament (schlank, kein Stufen-Feld)
--
-- Phase-1-Bauaufgabe (project_naechster_struktureller_schritt,
-- Abschnitt 8/9). Nutzer-Entscheidung: eine Rolle (du + künftige
-- Mitarbeiter), zwei getrennte Fähigkeiten -- Regelwerk-Bearbeitung
-- fremder Organisationen (Routine, "wenn die an uns mit einer Anfrage
-- herantreten müssen wir ja deren Wünsche erfüllen") und Notfallzugriff
-- auf fremde Kundendaten (Break-Glass wie beim gildeninternen
-- Notfallzugriff, siehe 20260808214213_gilden_notfallzugriff_admin.sql,
-- aber organisationsübergreifend statt nur innerhalb einer Org).
--
-- Bewusst KEIN Stufen-/Level-Feld (ursprünglich für ein künftiges
-- 1st/2nd/3rd-Level-Support-Modell angedacht, in der Planungs-Kritik
-- verworfen -- widerspricht dem im Projekt etablierten Rule-of-Three-
-- Prinzip, solange kein echter Bedarf für mehrere Stufen besteht). Eine
-- flache Allowlist reicht, spätere Erweiterung um ein Stufen-Feld ist
-- eine reine additive Spalten-Migration, kein Umbau.
--
-- Kein Self-Service zum Eintragen -- der erste Eintrag (der Nutzer
-- selbst) wird NACH dem Push einmalig manuell per SQL gesetzt, bewusst
-- NICHT Teil dieser versionierten Migration (nutzerspezifische Daten
-- gehören nicht in eine wiederholbare Schema-Migration).
--
-- v1 bekommt nur EINE Oberfläche (Regelwerk-Editor-Erweiterung im
-- Frontend) -- der Notfallzugriff (platform_admin_emergency_access)
-- existiert vollständig im Backend, aber ohne eigene Seite, bis ein
-- echter Anwendungsfall ansteht (Nutzer-Rückmeldung, Plan minimiert).
--
-- Rückbau: platform_admin_update_rule_config/platform_admin_
-- emergency_access/platform_admin_list_orgs/is_platform_admin droppen,
-- platform_admin_actions + platform_admins droppen.
--
-- Bewusst KEIN schema_patches-Eintrag (Zweitmeinung fragte danach):
-- gleiches Präzedenzmuster wie der ebenfalls admin/support-exklusive
-- Notfallzugriff (20260808214213_gilden_notfallzugriff_admin.sql, hat
-- ebenfalls keinen Eintrag) -- ein Feature, das nur für dich als
-- Plattformadmin sichtbar/nutzbar ist, muss nicht jedem Teammitglied
-- als Changelog-Popup angekündigt werden.

begin;

-- ---------------------------------------------------------------------
-- platform_admins: flache Allowlist
-- ---------------------------------------------------------------------

create table public.platform_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  added_at timestamptz not null default now(),
  added_by uuid references public.profiles(id) on delete set null
);

alter table public.platform_admins enable row level security;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.platform_admins where user_id = (select auth.uid())
  );
$$;

-- Bewusst auch für anon ausführbar, gleiche Begründung wie is_admin_of():
-- reines Lese-Helferlein, liefert für anon ohnehin immer false.
revoke execute on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated, anon;

-- Nur Plattformadmins sehen die eigene Liste -- rein informativ, kein
-- Client-Write möglich (keine Insert/Update/Delete-Policy).
create policy "platform_admins_select" on public.platform_admins
  for select using (is_platform_admin());

-- ---------------------------------------------------------------------
-- platform_admin_actions: gemeinsames Protokoll für beide Fähigkeiten
-- ---------------------------------------------------------------------

create table public.platform_admin_actions (
  id uuid primary key default gen_random_uuid(),
  action_type text not null check (action_type in ('rule_config_edit','emergency_data_access')),
  org_id uuid not null references public.organizations(id) on delete cascade,
  target_user_id uuid references public.profiles(id) on delete set null,
  reason text,
  admin_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index platform_admin_actions_org_id_idx on public.platform_admin_actions(org_id);
create index platform_admin_actions_admin_id_idx on public.platform_admin_actions(admin_id);
create index platform_admin_actions_target_user_id_idx on public.platform_admin_actions(target_user_id);

alter table public.platform_admin_actions enable row level security;

-- Kein Insert/Update/Delete für Clients -- ausschließlich per Insert
-- innerhalb der beiden SECURITY-DEFINER-Funktionen unten. Gleiches
-- Muster wie access_audit_log/error_log: ein Protokoll wird nicht
-- nachträglich verändert.
create policy "platform_admin_actions_select" on public.platform_admin_actions
  for select using (is_platform_admin());

-- ---------------------------------------------------------------------
-- platform_admin_list_orgs(): Org-Auswahl für den Regelwerk-Editor
-- ---------------------------------------------------------------------

create or replace function public.platform_admin_list_orgs()
returns table(id uuid, name text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_platform_admin() then
    raise exception 'Nur Plattformadmins dürfen Organisationen auflisten.' using errcode = '42501';
  end if;
  return query select o.id, o.name from public.organizations o order by o.name;
end;
$$;

grant execute on function public.platform_admin_list_orgs() to authenticated;
revoke execute on function public.platform_admin_list_orgs() from public, anon;

-- Damit der Regelwerk-Editor eine fremde Org überhaupt erst ANZEIGEN
-- kann (nicht nur speichern), braucht rule_configs eine passende
-- SELECT-Erweiterung -- ohne die würde platform_admin_update_rule_config()
-- zwar schreiben können, aber der Editor hätte nichts zum Vorbefüllen.
-- war: USING (org_id = current_org_id())
alter policy "rules_select_same_org" on public.rule_configs
  using (org_id = current_org_id() or is_platform_admin());

-- ---------------------------------------------------------------------
-- platform_admin_update_rule_config(): Regelwerk fremder Org bearbeiten
-- ---------------------------------------------------------------------

create or replace function public.platform_admin_update_rule_config(p_org_id uuid, p_config jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_platform_admin() then
    raise exception 'Nur Plattformadmins dürfen fremde Regelwerke bearbeiten.' using errcode = '42501';
  end if;
  if p_config is null then
    raise exception 'Regelwerk darf nicht leer sein.';
  end if;

  update public.rule_configs set config = p_config, updated_at = now() where org_id = p_org_id;
  if not found then
    raise exception 'Organisation nicht gefunden.';
  end if;

  insert into public.platform_admin_actions (action_type, org_id, admin_id)
  values ('rule_config_edit', p_org_id, (select auth.uid()));
end;
$$;

grant execute on function public.platform_admin_update_rule_config(uuid, jsonb) to authenticated;
revoke execute on function public.platform_admin_update_rule_config(uuid, jsonb) from public, anon;

-- ---------------------------------------------------------------------
-- platform_admin_emergency_access(): Break-Glass, organisationsübergreifend
--
-- Vorlage: admin_emergency_access() (20260808214213). Wichtiger
-- Unterschied (Fund der Plan-Prüfung): die Vorlage loggt die Org des
-- AUFRUFERS (current_org_id()) -- hier muss stattdessen die Org der
-- ZIELPERSON geloggt werden, da ein Plattformadmin keiner bestimmten
-- Org zugeordnet sein muss und current_org_id() für ihn auch null sein
-- könnte. Kein UI in v1, Backend vollständig nutzbar per SQL/RPC.
-- ---------------------------------------------------------------------

create or replace function public.platform_admin_emergency_access(p_target_user uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_target_org_id uuid;
  v_result jsonb;
begin
  if not is_platform_admin() then
    raise exception 'Nur Plattformadmins dürfen organisationsübergreifenden Notfallzugriff auslösen.' using errcode = '42501';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'Ein Grund ist Pflicht.';
  end if;

  select org_id into v_target_org_id from public.profiles where id = p_target_user;
  if v_target_org_id is null then
    raise exception 'Zielperson nicht gefunden oder ohne Organisation.';
  end if;

  insert into public.platform_admin_actions (action_type, org_id, target_user_id, reason, admin_id)
    values ('emergency_data_access', v_target_org_id, p_target_user, btrim(p_reason), (select auth.uid()));

  select jsonb_build_object(
    'contacts', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.name)
      from public.contacts c
      where c.owner_id = p_target_user
    ), '[]'::jsonb),
    'locations', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.name)
      from public.locations l
      where l.owner_id = p_target_user
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

grant execute on function public.platform_admin_emergency_access(uuid, text) to authenticated;
revoke execute on function public.platform_admin_emergency_access(uuid, text) from public, anon;

commit;
