-- ============================================================
-- Zwei weitere Funde derselben Lückenklasse, diesmal per systematischem
-- Durchgang ALLER INSERT/UPDATE-Policies gefunden (nicht mehr durch
-- Zufall) — Nutzerfrage "gibt es noch andere Grundregeln, die wir
-- übersehen haben".
-- ============================================================

-- 1) guild_members: Selbst-Beitritt konnte sich beliebige Rechte geben
-- (contacts_access/dungeons_access/team_rights waren beim Insert
-- komplett ungeprüft) -- live bestätigt: ein Mitglied könnte sich beim
-- "Beitreten" sofort Schreibzugriff auf alle geteilten Kontakte/Dungeons
-- UND die Nachfolge-Berechtigung selbst geben, ganz ohne Gründer-Zutun.
-- Die ernsteste der bisher gefundenen Lücken, weil sie echten Zugriff
-- auf Kolleg:innen-Daten verschafft, nicht nur Kosmetik. Fix: beim
-- Selbst-Beitritt sind nur die echten Minimalrechte erlaubt (Lesen,
-- kein Team-Recht) -- außer man ist der Gründer der eigenen Gilde
-- (legitimer Fall aus guildCreateBtn, setzt sich selbst volle Rechte).
drop policy if exists "guild_members_insert_self_join" on public.guild_members;
create policy "guild_members_insert_self_join" on public.guild_members for insert
with check (
  (member_id = auth.uid())
  and (org_id = current_org_id())
  and (
    (contacts_access = 'read' and dungeons_access = 'read' and team_rights = false)
    or exists (select 1 from public.guilds g where g.id = guild_members.guild_id and g.founder_id = auth.uid())
  )
);


-- 2) profiles.total_xp/level: reiner Anzeige-Cache (die echte Wahrheit
-- bleibt immer action_log), aber ungeschützt direkt überschreibbar --
-- live bestätigt: quantity-artiger Cheat, Level 100 ohne einen Punkt XP.
-- Sichtbar für Freunde/Gilde (Avatar-Kacheln), reines Vorspiegeln, kein
-- Zugriff auf fremde Daten -- trotzdem behoben, gleiche Grundregel wie
-- überall sonst heute.
--
-- Löst das genauso wie action_log: der Wert wird nicht mehr vom Client
-- übernommen, sondern serverseitig aus der echten Summe (action_log.xp)
-- + der echten Level-Kurve (rule_configs.config.levelBase/
-- levelExponent, identische Formel wie xpForLevel()/levelInfo() im
-- Frontend) neu berechnet. protect_privileged_profile_fields() (Patch
-- 38/39) bekommt dafür eine dritte Prüfung -- total_xp/level dürfen nur
-- noch über diese eine Funktion geändert werden, erkennbar an einem
-- Sitzungs-Flag, das nur sync_own_level_cache() selbst setzt.
create or replace function public.protect_privileged_profile_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    if new.role is distinct from old.role then
      raise exception 'Nur Admins dürfen die Rolle ändern.';
    end if;
    if new.character_class is distinct from old.character_class then
      raise exception 'Die Charakterklasse kann nicht direkt geändert werden.';
    end if;
    if new.org_id is distinct from old.org_id then
      raise exception 'org_id kann nicht direkt geändert werden.';
    end if;
    if (new.total_xp is distinct from old.total_xp or new.level is distinct from old.level)
       and coalesce(current_setting('app.trusted_level_sync', true), 'false') <> 'true' then
      raise exception 'total_xp/level werden nur über sync_own_level_cache() aktualisiert.';
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.sync_own_level_cache()
returns table(total_xp integer, level integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_base numeric;
  v_exp numeric;
  v_total integer;
  v_level integer := 1;
  v_remaining integer;
  v_need integer;
  v_iterations integer := 0;
begin
  select org_id into v_org_id from public.profiles where id = auth.uid();
  if v_org_id is null then
    raise exception 'Kein gültiges Profil für diesen Aufruf.';
  end if;

  select coalesce(sum(xp), 0) into v_total from public.action_log where user_id = auth.uid();

  select coalesce((config->>'levelBase')::numeric, 4.7), coalesce((config->>'levelExponent')::numeric, 1.5)
    into v_base, v_exp
    from public.rule_configs where org_id = v_org_id;

  v_remaining := v_total;
  v_need := round(v_base * power(v_level, v_exp));
  while v_remaining >= v_need and v_iterations < 500 loop
    v_remaining := v_remaining - v_need;
    v_level := v_level + 1;
    v_need := round(v_base * power(v_level, v_exp));
    v_iterations := v_iterations + 1;
  end loop;

  perform set_config('app.trusted_level_sync', 'true', true);
  update public.profiles set total_xp = v_total, level = v_level where id = auth.uid();

  return query select v_total, v_level;
end;
$$;

grant execute on function public.sync_own_level_cache() to authenticated;
