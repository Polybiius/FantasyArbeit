-- PATCH: Exact-Match-Suche im Pool für Org-Admins
--
-- Bewusst eine SECURITY DEFINER-Funktion statt einer reinen RLS-Policy
-- (z.B. "is_admin() and org_id is null") -- eine Policy würde nur
-- steuern, WER lesen darf, nicht WIE VIEL: ein roher REST-Aufruf ohne
-- Filter würde dann den kompletten Pool dumpen. Die Exact-Match-Regel
-- (ausdrücklicher Nutzerwunsch, einzige v1-Datenschutz-Schranke gegen
-- Pool-Browsing) muss deshalb SERVERSEITIG in der Funktion selbst
-- erzwungen werden -- reine Gleichheit (lower(x) = lower(trim(...))),
-- ausdrücklich KEIN ilike(): die bestehenden Geschwister-Suchen
-- (searchFriendByName(), searchGuildCandidates() in index.html) geben
-- den rohen Nutzer-Text unbereinigt in ilike() -- ein Suchbegriff wie
-- "%" matcht dort schon heute alles. Vorbestehende, kleine Lücke,
-- hier bewusst nicht mitgefixt (nicht Teil dieses Umbaus), aber die
-- neue Funktion übernimmt dieses Muster deshalb explizit NICHT.

begin;

create or replace function public.search_org_pool_candidates(p_name text)
returns table(id uuid, display_name text, real_name text, character_class text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_org_id uuid;
  v_name text := trim(coalesce(p_name, ''));
begin
  select org_id into v_org_id from public.profiles p where p.id = (select auth.uid());
  if v_org_id is null or not is_admin_of(v_org_id) then
    raise exception 'Nur Admins dürfen im Pool suchen.' using errcode = '42501';
  end if;
  if length(v_name) = 0 then
    raise exception 'Name erforderlich.';
  end if;

  return query
    select p.id, p.display_name, p.real_name, p.character_class
    from public.profiles p
    where p.org_id is null
      and (lower(p.real_name) = lower(v_name) or lower(p.display_name) = lower(v_name));
end;
$$;

grant execute on function public.search_org_pool_candidates(text) to authenticated;
revoke execute on function public.search_org_pool_candidates(text) from public, anon;

commit;
