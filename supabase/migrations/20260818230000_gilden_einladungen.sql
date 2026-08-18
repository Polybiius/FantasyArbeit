-- PATCH: Echte Gilden-Einladung mit Annahme/Ablehnung
--
-- Nutzer-Bugreport 2026-08-18: der Gildengründer konnte über den
-- Mitglied-Picker (searchGuildCandidates() in index.html) jedes
-- Org-Mitglied DIREKT in guild_members einfügen (Policy
-- guild_members_insert_allowed, Founder-Branch) -- ohne dass die
-- eingeladene Person dem überhaupt zustimmen musste. Gleiches Muster wie
-- die Termin-Einladungen vom selben Tag (siehe termin_invitations): eine
-- echte Mitgliedschaft entsteht jetzt erst, wenn die eingeladene Person
-- aktiv annimmt.
--
-- Bewusst eine GETRENNTE Tabelle statt eines Status-Felds direkt an
-- guild_members -- guild_members wird an sehr vielen Stellen im Schema
-- (Kontakt-/Dungeon-Sichtbarkeit, Chronik-Sichtbarkeit, Notfallzugriff,
-- Nachfolgeregelung) als "ist wirklich Mitglied, hat Zugriff" gelesen.
-- Eine separate Einladungs-Tabelle lässt all das unangetastet -- eine
-- Zeile in guild_members entsteht weiterhin ausschließlich bei echter
-- Zusage, keine bestehende Stelle muss geprüft/angepasst werden.
--
-- Der bestehende Selbst-Beitritt über die "Gilde beitreten"-Liste
-- (joinGuild() in index.html, Selbstbeitritts-Zweig derselben Policy)
-- bleibt unverändert -- dort ist die beitretende Person selbst die
-- Handelnde, kein Fremdeinfügen. Betroffen ist ausschließlich der
-- Founder-Branch (ein Fremder trägt jemand ANDEREN ein).

create table public.guild_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  guild_id uuid not null references public.guilds(id) on delete cascade,
  invited_user_id uuid not null references public.profiles(id),
  invited_by uuid not null references public.profiles(id),
  status text not null default 'offen' check (status in ('offen','angenommen','abgelehnt')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (guild_id, invited_user_id)
);
create index guild_invitations_invited_user_id_idx on public.guild_invitations(invited_user_id);
create index guild_invitations_guild_id_idx on public.guild_invitations(guild_id);

alter table public.guild_invitations enable row level security;

-- Sichtbar für den Eingeladenen selbst, den Einladenden und Admins --
-- gleiches Leserechte-Muster wie bei termin_invitations.
create policy guild_invitations_select on public.guild_invitations
  for select using (
    invited_user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or public.is_admin()
  );

-- Bewusst keine insert/update/delete-Policies für normale Clients -- jeder
-- Schreibvorgang läuft über eine der drei Funktionen unten (gleiches
-- Härtungsmuster wie termin_invitations/action_log/user_inventory: kann
-- nie in einem halbfertigen Zustand enden).

-- 1) Einladen: nur der Gildengründer, nur an ein Org-Mitglied ohne
-- bestehende Gilde. Erneutes Einladen nach einer Ablehnung setzt den
-- bestehenden Datensatz einfach wieder auf "offen" statt eine Dublette
-- zu werfen (unique-Constraint + on conflict, wie bei invite_to_termin).
create or replace function public.invite_to_guild(p_guild_id uuid, p_invited_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_org_id uuid;
  v_invitation_id uuid;
begin
  select org_id into v_org_id from public.guilds
    where id = p_guild_id and founder_id = auth.uid();
  if v_org_id is null then
    raise exception 'Gilde nicht gefunden oder du bist nicht der Gründer.';
  end if;

  if p_invited_user_id = auth.uid() then
    raise exception 'Du kannst dich nicht selbst einladen.';
  end if;

  if exists (select 1 from public.guild_members where member_id = p_invited_user_id) then
    raise exception 'Diese Person ist bereits in einer Gilde.';
  end if;

  insert into public.guild_invitations (org_id, guild_id, invited_user_id, invited_by, status)
  values (v_org_id, p_guild_id, p_invited_user_id, auth.uid(), 'offen')
  on conflict (guild_id, invited_user_id)
  do update set status = 'offen', invited_by = auth.uid(), responded_at = null
  returning id into v_invitation_id;

  return v_invitation_id;
end;
$$;

-- 2) Annehmen/Ablehnen: nur der Eingeladene selbst, nur bei noch offener
-- Einladung. Erst bei Annahme entsteht die echte guild_members-Zeile, mit
-- denselben Minimalrechten wie bisher beim Selbstbeitritt (read/read/
-- false) -- der Gründer kann sie danach jederzeit über den bestehenden
-- "Rechte"-Button am Mitglied anpassen, kein Zwangs-Dialog beim Annehmen.
create or replace function public.respond_to_guild_invitation(p_invitation_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_inv record;
begin
  select * into v_inv from public.guild_invitations
    where id = p_invitation_id and invited_user_id = auth.uid() and status = 'offen';
  if v_inv is null then
    raise exception 'Einladung nicht gefunden oder bereits beantwortet.';
  end if;

  if not p_accept then
    update public.guild_invitations set status = 'abgelehnt', responded_at = now()
      where id = p_invitation_id;
    return;
  end if;

  if exists (select 1 from public.guild_members where member_id = auth.uid()) then
    raise exception 'Du bist bereits in einer Gilde.';
  end if;

  insert into public.guild_members (member_id, guild_id, org_id, contacts_access, dungeons_access, team_rights)
  values (auth.uid(), v_inv.guild_id, v_inv.org_id, 'read', 'read', false);

  update public.guild_invitations set status = 'angenommen', responded_at = now()
    where id = p_invitation_id;
end;
$$;

-- 3) Zurückziehen einer noch offenen Einladung durch den Einladenden --
-- nötig, damit der Picker nach einem Fehlklick nicht dauerhaft
-- "ausstehend" anzeigt.
create or replace function public.cancel_guild_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  delete from public.guild_invitations
    where id = p_invitation_id and invited_by = auth.uid() and status = 'offen';
end;
$$;

-- Founder darf nicht mehr direkt ein FREMDES Mitglied in guild_members
-- einfügen -- nur noch über respond_to_guild_invitation() oben (als
-- SECURITY DEFINER ohnehin an keine INSERT-Policy gebunden). Der
-- Selbstbeitritts-Zweig bleibt unverändert erlaubt.
drop policy "guild_members_insert_allowed" on public.guild_members;
create policy "guild_members_insert_self_join" on public.guild_members
  for insert
  with check (member_id = (select auth.uid()) and org_id = current_org_id());
