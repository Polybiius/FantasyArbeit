-- PATCH: Org-Grenze für Gilden-Einladung + app-weite Freundes-Suche
--
-- Zwei Funde aus einem gezielten Code-Review (Freunde / Pool /
-- Gildeneinladungen, 2026-09-01) -- beide dieselbe Klasse wie der
-- Org-Grenze-Audit vom 2026-08-28
-- (20260828140000_org_grenze_fuer_bare_is_admin_policies.sql): eine
-- fehlende Organisationsgrenze in Berechtigungslogik. Heute folgenlos
-- (nur eine Organisation existiert), aber ein echtes Cross-Org-Leck,
-- sobald über found_own_org() eine zweite Org entsteht.
--
-- ---------------------------------------------------------------------
-- FUND 1 -- Der Weg in guild_members hat KEINE Org-Grenze. Drei Türen,
-- alle bisher ungeprüft:
--
--   a) invite_to_guild() / respond_to_guild_invitation()
--      (20260818230000_gilden_einladungen.sql) prüfen NICHT, dass die
--      eingeladene bzw. annehmende Person zur Organisation der Gilde
--      gehört. Ein Gründer kann per direktem RPC-Aufruf ein gildenloses
--      Mitglied einer FREMDEN Org ODER einen Pool-Nutzer (org_id NULL)
--      einladen.
--
--   b) guild_members_insert_self_join (RLS-Policy aus
--      20260816140000_security_alerts.sql / 20260818230000):
--        with check (member_id = auth.uid() and org_id = current_org_id())
--      -- "org_id" ist hier die vom CLIENT gelieferte Spalte, NICHT
--      guilds.org_id. Nichts (kein FK, kein CHECK, kein Trigger) bindet
--      guild_members.guild_id an guild_members.org_id. joinGuild() in
--      index.html ist ein roher insert -> die Zeilenform ist frei
--      fälschbar. Ein Nutzer aus Org A kann
--        insert guild_members {member_id: ich, guild_id: <Gilde aus Org B>,
--                              org_id: <Org A>}
--      absetzen -- die Policy passt (member_id=ich, org_id=current_org_id()),
--      die Zeile entsteht. (Von der blinden Zweitmeinung zu dieser
--      Migration gefunden -- die Einladungs-Härtung allein schließt die
--      Lücke NICHT, nur diese Tür.)
--
-- Folge in beiden Fällen: guild_contact_permission() /
-- guild_dungeon_permission() / socially_visible() / die
-- Chronik-Sichtbarkeit sind reine guild_members-Joins OHNE Org-Recheck --
-- Kontakte, Dungeons, Chronik, Dateien und Skill-/Verkaufs-Summen werden
-- über die Firmengrenze hinweg sichtbar (in beide Richtungen).
--
-- Fix, dreiteilig:
--   * NEU: Trigger enforce_guild_members_org_consistency() auf
--     guild_members -- die strukturelle Invariante
--     "guild_members.org_id = guilds.org_id" gilt ab jetzt für JEDEN
--     Insert/Update, egal über welche Tür (Policy-Self-Join, beide
--     SECURITY-DEFINER-Einladungsfunktionen, found_own_org,
--     admin_create_guild, künftige Pfade). Das ist der eigentliche
--     Verschluss von Tür (b) und die Absicherung gegen jede künftige
--     verirrte/gefälschte Membership-Zeile.
--   * invite_to_guild(): Ziel muss Mitglied der Guild-Org sein
--     (schließt Fremd-Org UND Pool-Nutzer aus -- gute UX + Defense-in-
--     Depth, gleiches Muster wie admin_create_guild()).
--   * respond_to_guild_invitation(): die eigene org_id muss zur
--     Einladung passen -- fängt zusätzlich eine bereits bestehende /
--     veraltete Cross-Org-Einladung ab.
-- Der Trigger allein deckt "guild_members.org_id passt zur Gilde" ab;
-- "die Person gehört zu dieser Org" bleibt Sache der Self-Join-Policy
-- (org_id = current_org_id()) bzw. der beiden Funktions-Prüfungen --
-- zusammen ergibt sich transitiv: Mitglied gehört zur Org der Gilde.
--
-- FOLGE-HINWEIS für später: guild_members.org_id ist ab jetzt vollständig
-- aus guilds.org_id abgeleitet. Ein künftiges "Gilde in eine andere Org
-- verschieben"-Feature muss beide Spalten in EINER Anweisung ändern,
-- sonst blockiert der Trigger. (guilds selbst hat aktuell nur eine
-- SELECT-Policy, kein Client-Schreibweg -- der abgeleitete Wert kann
-- also nicht unbemerkt driften.)
--
-- ---------------------------------------------------------------------
-- FUND 2 -- search_profile_for_friend()
-- (20260830090000_friends_org_unabhaengig.sql) macht
--   where p.display_name ilike p_name
-- -- ohne %/_ zu neutralisieren und ohne limit. Direkt aufrufbar:
--   sb.rpc('search_profile_for_friend', { p_name: '%' })
-- liefert id + display_name + character_class JEDES Profils in JEDER
-- Organisation. Patch 58 hat diese Suche von einem org-gebundenen
-- profiles-Select auf eine app-weite SECURITY-DEFINER-Funktion
-- umgestellt, aber ilike beibehalten -- die vorher org-begrenzte
-- "%-Lücke" (in 20260829093000_org_pool_suche.sql als bewusst vertagt
-- notiert, damals aber org-begrenzt) wurde damit cross-tenant.
--
-- Fix: exact-match wie das Geschwister search_org_pool_candidates()
-- (20260829093000): lower(display_name) = lower(trim(p_name)).
--
-- ---------------------------------------------------------------------
-- Rückbau:
--   * Trigger + Funktion: drop trigger trg_guild_members_org_consistency
--     on public.guild_members;  drop function
--     public.enforce_guild_members_org_consistency();
--   * invite_to_guild / respond_to_guild_invitation: die jeweils neue
--     "gehört zur Organisation"-Prüfung wieder entfernen (Fassung von
--     20260818230000_gilden_einladungen.sql wiederherstellen).
--   * search_profile_for_friend: Body auf
--     "where p.display_name ilike p_name" zurücksetzen
--     (Fassung von 20260830090000_friends_org_unabhaengig.sql).
--   Keine Datenänderung, kein Backfill nötig -- reine Funktions-/
--   Trigger-Logik. Bestandsdaten sind bereits konsistent (per Abfrage
--   bestätigt: alle guild_members.org_id == guilds.org_id), die Migration
--   prüft das zu Beginn zusätzlich per assertion und bricht sonst ab.
-- ---------------------------------------------------------------------

begin;

-- === FUND 1: strukturelle Invariante guild_members.org_id = guilds.org_id ===

-- Sicherheitsnetz: gäbe es doch eine inkonsistente Bestandszeile, würde
-- der Trigger unten jeden künftigen Update darauf blockieren -- lieber
-- hier laut abbrechen als das erst im Betrieb zu merken.
do $$
declare v_bad int;
begin
  select count(*) into v_bad
  from public.guild_members gm
  join public.guilds g on g.id = gm.guild_id
  where gm.org_id is distinct from g.org_id;
  if v_bad > 0 then
    raise exception 'Abbruch: % guild_members-Zeile(n) mit org_id != guilds.org_id -- erst bereinigen.', v_bad;
  end if;
end $$;

create or replace function public.enforce_guild_members_org_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guild_org uuid;
begin
  select org_id into v_guild_org from public.guilds where id = new.guild_id;
  if v_guild_org is null then
    raise exception 'Gilde % existiert nicht.', new.guild_id using errcode = '23503';
  end if;
  if new.org_id is distinct from v_guild_org then
    raise exception 'guild_members.org_id (%) muss zur Organisation der Gilde (%) passen.',
      new.org_id, v_guild_org using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guild_members_org_consistency on public.guild_members;
create trigger trg_guild_members_org_consistency
  before insert or update of guild_id, org_id on public.guild_members
  for each row execute function public.enforce_guild_members_org_consistency();

-- === FUND 1a: invite_to_guild() -- Ziel muss zur Org der Gilde gehören ===
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

  -- NEU: die eingeladene Person muss Mitglied genau dieser Organisation
  -- sein -- schließt Mitglieder fremder Orgs UND Pool-Nutzer (org_id
  -- NULL) aus. Gleiches Muster wie admin_create_guild().
  if not exists (
    select 1 from public.profiles
    where id = p_invited_user_id and org_id = v_org_id
  ) then
    raise exception 'Die eingeladene Person gehört nicht zu dieser Organisation.';
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

-- === FUND 1b: respond_to_guild_invitation() -- eigene Org muss passen ===
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

  -- NEU (Defense-in-Depth): die eigene org_id muss zur Einladung passen.
  -- invite_to_guild() lässt eine Cross-Org-Einladung ab dieser Migration
  -- gar nicht mehr entstehen -- diese Prüfung fängt zusätzlich bereits
  -- bestehende / veraltete Einladungen ab (z.B. falls sich die org_id
  -- des Eingeladenen nach dem Einladen geändert hat).
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and org_id = v_inv.org_id
  ) then
    raise exception 'Diese Einladung gehört zu einer anderen Organisation als deiner.';
  end if;

  insert into public.guild_members (member_id, guild_id, org_id, contacts_access, dungeons_access, team_rights)
  values (auth.uid(), v_inv.guild_id, v_inv.org_id, 'read', 'read', false);

  update public.guild_invitations set status = 'angenommen', responded_at = now()
    where id = p_invitation_id;
end;
$$;

-- === FUND 2: search_profile_for_friend() -- exact-match statt ilike ===
-- ilike p_name -> lower(display_name) = lower(trim(p_name)): ein
-- Suchbegriff "%" (oder "_") matcht sonst ALLES app-weit (id +
-- display_name + character_class jedes Profils jeder Org). Zusätzlich
-- die zwei fehlenden Schutzmaßnahmen, die das Geschwister
-- search_org_pool_candidates() hat: Leerstring-Guard (sonst matcht
-- p_name='' alle leeren/whitespace-only display_names) und ein limit.
create or replace function public.search_profile_for_friend(p_name text)
returns table(id uuid, display_name text, character_class text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.display_name, p.character_class
  from public.profiles p
  where length(trim(coalesce(p_name, ''))) > 0
    and lower(p.display_name) = lower(trim(p_name))
  limit 25;
$$;

-- Grants unverändert (create or replace behält sie) -- zur Sicherheit
-- erneut gesetzt, gleiches Muster wie search_org_pool_candidates().
grant execute on function public.search_profile_for_friend(text) to authenticated;
revoke execute on function public.search_profile_for_friend(text) from public, anon;

insert into public.schema_patches (patch_number, title) values
  (61, 'Org-Grenze für Gildenbeitritt, -Einladung und Freundes-Suche')
on conflict (patch_number) do nothing;

commit;
