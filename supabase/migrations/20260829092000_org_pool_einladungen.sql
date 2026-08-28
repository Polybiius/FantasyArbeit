-- PATCH: Org-Einladung (Pool -> Organisation), Admin-exklusiv
--
-- Getrennt von der bestehenden Gilden-Einladung (guild_invitations,
-- Patch 2026-08-18) -- unterschiedliche Suchmenge (Pool-weit statt
-- org-intern) UND unterschiedliches Berechtigungsmodell (nur
-- Org-Admin statt Gildenführer). Sobald jemand über diesen Weg in der
-- Org ist, läuft eine Zuordnung zu einer konkreten Gilde unverändert
-- über die bestehende guild_invitations/searchGuildCandidates()-Kette
-- -- die kennt bereits org-interne, noch gildenlose Mitglieder, braucht
-- dafür keine Anpassung.
--
-- Gleiches Grundmuster wie guild_invitations: eigene Tabelle statt
-- eines Status-Felds direkt an profiles, kein Insert/Update/Delete für
-- Clients, ausschließlich über die drei Funktionen unten.

begin;

create table public.org_pool_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  invited_user_id uuid not null references public.profiles(id),
  invited_by uuid not null references public.profiles(id),
  status text not null default 'offen' check (status in ('offen','angenommen','abgelehnt')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  -- Dedupliziert nur pro (Org, Eingeladener) -- verhindert bewusst NICHT,
  -- dass dieselbe Person gleichzeitig offene Einladungen von mehreren
  -- verschiedenen Organisationen hat (ausdrücklich keine Exklusiv-Sperre
  -- in v1, kommt erst auf konkreten Kundenwunsch).
  unique (org_id, invited_user_id)
);
create index org_pool_invitations_invited_user_id_idx on public.org_pool_invitations(invited_user_id);
create index org_pool_invitations_org_id_idx on public.org_pool_invitations(org_id);

alter table public.org_pool_invitations enable row level security;

create policy org_pool_invitations_select on public.org_pool_invitations
  for select using (
    invited_user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or is_admin_of(org_id)
  );

create or replace function public.invite_to_org_pool(p_invited_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_org_id uuid;
  v_id uuid;
begin
  select org_id into v_org_id from public.profiles where id = (select auth.uid());
  if v_org_id is null or not is_admin_of(v_org_id) then
    raise exception 'Nur Admins dürfen aus dem Pool einladen.' using errcode = '42501';
  end if;
  if p_invited_user_id is null or not exists (
    select 1 from public.profiles where id = p_invited_user_id and org_id is null
  ) then
    raise exception 'Diese Person ist nicht im Pool verfügbar.';
  end if;

  insert into public.org_pool_invitations (org_id, invited_user_id, invited_by, status)
  values (v_org_id, p_invited_user_id, (select auth.uid()), 'offen')
  on conflict (org_id, invited_user_id)
  do update set status = 'offen', invited_by = excluded.invited_by, responded_at = null
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.respond_to_org_pool_invitation(p_invitation_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inv record;
begin
  select * into v_inv from public.org_pool_invitations
    where id = p_invitation_id and invited_user_id = (select auth.uid()) and status = 'offen';
  if v_inv is null then
    raise exception 'Einladung nicht gefunden oder bereits beantwortet.';
  end if;

  if not p_accept then
    update public.org_pool_invitations set status = 'abgelehnt', responded_at = now()
      where id = p_invitation_id;
    return;
  end if;

  if exists (select 1 from public.profiles where id = (select auth.uid()) and org_id is not null) then
    raise exception 'Du gehörst bereits einer Organisation an.';
  end if;

  perform set_config('app.trusted_org_membership_change', 'true', true);
  update public.profiles set org_id = v_inv.org_id where id = (select auth.uid());

  update public.org_pool_invitations set status = 'angenommen', responded_at = now()
    where id = p_invitation_id;

  -- Wer beitritt, kann nur einer Org angehören -- jede andere noch
  -- offene Einladung dieser Person wird damit gegenstandslos und
  -- automatisch abgelehnt, statt sie als "offen" hängen zu lassen.
  update public.org_pool_invitations set status = 'abgelehnt', responded_at = now()
    where invited_user_id = (select auth.uid()) and status = 'offen' and id <> p_invitation_id;
end;
$$;

create or replace function public.cancel_org_pool_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_org_id uuid;
begin
  select org_id into v_org_id from public.org_pool_invitations
    where id = p_invitation_id and status = 'offen';
  if v_org_id is null then
    return; -- nicht gefunden/schon beantwortet -- kein Fehler, gleiche Idempotenz wie andere *_cancel-Funktionen
  end if;
  -- Bewusst nicht nur der ursprüngliche Einladende, sondern JEDER Admin
  -- der einladenden Org -- eine ausgesprochene Einladung ist Sache der
  -- Organisation, nicht persönliches Eigentum der einzelnen einladenden
  -- Person (anders als bei cancel_guild_invitation(), wo die Gilde
  -- einem einzelnen Gründer gehört). Ohne diese Erweiterung hätte ein
  -- zweiter Admin auf "Zurückziehen" geklickt und stillschweigend nichts
  -- wäre passiert (per Zweitmeinungsrunde gefunden, vor dem Push behoben).
  if not is_admin_of(v_org_id) then
    raise exception 'Nur Admins der einladenden Organisation dürfen die Einladung zurückziehen.' using errcode = '42501';
  end if;
  delete from public.org_pool_invitations where id = p_invitation_id and status = 'offen';
end;
$$;

grant execute on function public.invite_to_org_pool(uuid) to authenticated;
revoke execute on function public.invite_to_org_pool(uuid) from public, anon;
grant execute on function public.respond_to_org_pool_invitation(uuid, boolean) to authenticated;
revoke execute on function public.respond_to_org_pool_invitation(uuid, boolean) from public, anon;
grant execute on function public.cancel_org_pool_invitation(uuid) to authenticated;
revoke execute on function public.cancel_org_pool_invitation(uuid) from public, anon;

commit;
