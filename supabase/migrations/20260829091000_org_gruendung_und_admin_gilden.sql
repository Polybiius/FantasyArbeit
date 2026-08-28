-- PATCH: Selbst-Gründung einer Organisation (Pool -> eigene Org+Gilde)
-- + Admin-gesteuerte Zweitgilde innerhalb einer bestehenden Org
--
-- Zwei getrennte, mit dem Nutzer explizit unterschiedlich entschiedene
-- Fälle (siehe project_naechster_struktureller_schritt, Abschnitt 6):
--
--   1) Ein Pool-Nutzer (org_id IS NULL) gründet frei seine erste Gilde --
--      das erzeugt automatisch eine neue, leichte Organisation mit
--      kopiertem Standard-Regelwerk (Platzhalter, keine automatisierte
--      Individualisierung -- das bleibt ein eigenes, späteres Vorhaben).
--      Der Gründer wird Gildenführer UND de-facto Organisationsadmin.
--
--   2) Innerhalb einer BEREITS bestehenden Org darf ein normales
--      Mitglied NICHT mehr selbst eine weitere Gilde gründen --
--      ausdrückliche Nutzer-Vorgabe ("die Organisation muss schon als
--      übergeordneter Admin zustimmen. Ein Mitarbeiter kann nicht
--      einfach eigene Strukturen bauen. Eigentlich baut die
--      Organisation die Gilden und setzt dort ihre Teamleiter ein").
--      Bewusster Verhaltenswechsel gegenüber dem heutigen
--      "guildCreateBtn" (index.html) -- fiel bisher nie auf, weil es
--      nur eine einzige Organisation gibt und JEDES Org-Mitglied per
--      guilds_insert_self_founder direkt gründen durfte.
--
-- Die alte guilds_insert_self_founder-Policy (erlaubte jedem
-- Org-Mitglied einen direkten Client-Insert) wird deshalb komplett
-- entfernt -- ab jetzt läuft JEDE Gilden-Gründung ausschließlich über
-- eine der beiden Funktionen unten (SECURITY DEFINER, umgeht RLS wie
-- jede andere *_locked()/*_to_self()-Funktion in diesem Projekt auch).

begin;

drop policy "guilds_insert_self_founder" on public.guilds;

-- === found_own_org(): einziger Weg vom Pool zu Org+Admin+Gründungsgilde ===
create or replace function public.found_own_org(p_org_name text, p_guild_name text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := (select auth.uid());
  v_current_org_id uuid;
  v_org_id uuid;
  v_guild_id uuid;
  v_template_config jsonb;
  v_org_name text := trim(coalesce(p_org_name, ''));
  v_guild_name text := trim(coalesce(p_guild_name, ''));
begin
  -- "for update" sperrt die eigene profiles-Zeile für die Dauer dieses
  -- Aufrufs -- ein zweiter, gleichzeitiger Aufruf (Netzwerk-Retry oder
  -- zweiter offener Tab) blockiert hier, bis der erste committet hat,
  -- und sieht danach garantiert das gesetzte org_id -> lehnt korrekt ab,
  -- statt (wie bei einem reinen "if exists"-Vorab-Check ohne Sperre
  -- möglich) parallel eine zweite, verwaiste Organisation samt Gilde
  -- anzulegen (per Zweitmeinungsrunde gefunden, vor dem Push behoben).
  select org_id into v_current_org_id from public.profiles where id = v_uid for update;
  if v_current_org_id is not null then
    raise exception 'Du gehörst bereits einer Organisation an.' using errcode = '42501';
  end if;
  if length(v_org_name) = 0 or length(v_org_name) > 150 then
    raise exception 'Name der Organisation erforderlich (max. 150 Zeichen).';
  end if;
  if length(v_guild_name) = 0 or length(v_guild_name) > 150 then
    raise exception 'Name der ersten Gilde erforderlich (max. 150 Zeichen).';
  end if;

  insert into public.organizations (name) values (v_org_name) returning id into v_org_id;

  -- Kopiertes Standard-Regelwerk als Startpunkt (bewusst nur eine Kopie,
  -- keine Automatisierung -- siehe Kommentar oben). Quelle bleibt frei
  -- austauschbar, rule_configs.config ist ohnehin freies JSONB.
  select config into v_template_config
    from public.rule_configs
    where org_id = '00000000-0000-0000-0000-000000000001'::uuid;
  if v_template_config is null then
    raise exception 'Keine Vorlagen-Konfiguration gefunden.';
  end if;
  -- contactAutoDelete MUSS für eine neue Org auf enabled=false stehen
  -- (dokumentierter Standard, siehe CLAUDE.md "DSGVO-Vorbereitung") --
  -- unabhängig davon, was die Quell-Org gerade eingestellt hat (beim
  -- echten Vorbild-Org aktuell enabled=true). Ohne diese Überschreibung
  -- würde eine frisch gegründete Org sonst stillschweigend die scharf
  -- geschaltete Auto-Löschung der Vorlage erben (per Zweitmeinungsrunde
  -- gefunden, vor dem Push behoben).
  v_template_config := jsonb_set(v_template_config, '{contactAutoDelete,enabled}', 'false'::jsonb, true);
  insert into public.rule_configs (org_id, config) values (v_org_id, v_template_config);

  -- Produktkatalog mitkopieren, sonst ist "+ Verkauf eintragen" am
  -- ersten Tag leer (rule_configs allein reicht nicht für eine sofort
  -- funktionsfähige neue Org -- products ist ein eigenes, org_id-
  -- gebundenes Katalog, das die ursprünglich besprochenen Anforderungen
  -- nicht erwähnt hatten, aber strukturell mitgedacht werden muss).
  insert into public.products (org_id, key, name, category, subcategory, active,
                                bwp_faktor, provision_faktor, provision_mode,
                                recontact_amount, recontact_unit)
  select v_org_id, key, name, category, subcategory, active,
         bwp_faktor, provision_faktor, provision_mode,
         recontact_amount, recontact_unit
  from public.products
  where org_id = '00000000-0000-0000-0000-000000000001'::uuid;

  insert into public.guilds (org_id, name, founder_id)
    values (v_org_id, v_guild_name, v_uid) returning id into v_guild_id;

  perform set_config('app.trusted_org_membership_change', 'true', true);
  update public.profiles set org_id = v_org_id, role = 'admin' where id = v_uid;

  insert into public.guild_members (member_id, guild_id, org_id, contacts_access, dungeons_access, team_rights)
    values (v_uid, v_guild_id, v_org_id, 'write', 'write', true);

  return v_org_id;
end;
$$;

-- === admin_create_guild(): Admin gründet eine WEITERE Gilde innerhalb
-- der eigenen Org und designiert deren Gildenführer/Teamleiter ===
create or replace function public.admin_create_guild(p_name text, p_founder_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_org_id uuid;
  v_guild_id uuid;
  v_name text := trim(coalesce(p_name, ''));
begin
  select org_id into v_org_id from public.profiles where id = (select auth.uid());
  if v_org_id is null or not is_admin_of(v_org_id) then
    raise exception 'Nur Admins der eigenen Organisation dürfen weitere Gilden anlegen.' using errcode = '42501';
  end if;
  if length(v_name) = 0 or length(v_name) > 150 then
    raise exception 'Name erforderlich (max. 150 Zeichen).';
  end if;
  if p_founder_user_id is null or not exists (
    select 1 from public.profiles where id = p_founder_user_id and org_id = v_org_id
  ) then
    raise exception 'Der designierte Gildenführer muss Mitglied dieser Organisation sein.';
  end if;
  if exists (select 1 from public.guild_members where member_id = p_founder_user_id) then
    raise exception 'Diese Person ist bereits Mitglied einer Gilde.';
  end if;

  insert into public.guilds (org_id, name, founder_id)
    values (v_org_id, v_name, p_founder_user_id) returning id into v_guild_id;
  insert into public.guild_members (member_id, guild_id, org_id, contacts_access, dungeons_access, team_rights)
    values (p_founder_user_id, v_guild_id, v_org_id, 'write', 'write', true);

  -- Gleiche Übernahme wie beim bisherigen client-seitigen Selbst-Gründen
  -- (index.html, alter guildCreateBtn-Handler): bereits private, noch
  -- gildenlose Dungeons des designierten Gründers wandern automatisch in
  -- den Pool der neuen Gilde -- "es ist die eigene Welt des Gründers",
  -- keine gesonderte Prüfung nötig (anders als beim späteren Beitritt
  -- eines fremden Mitglieds).
  update public.locations
    set guild_id = v_guild_id
    where (owner_id = p_founder_user_id or created_by = p_founder_user_id)
      and guild_id is null;

  return v_guild_id;
end;
$$;

grant execute on function public.found_own_org(text, text) to authenticated;
revoke execute on function public.found_own_org(text, text) from public, anon;
grant execute on function public.admin_create_guild(text, uuid) to authenticated;
revoke execute on function public.admin_create_guild(text, uuid) from public, anon;

commit;
