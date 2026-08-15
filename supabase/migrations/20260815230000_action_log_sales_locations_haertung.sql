-- ============================================================
-- Fortsetzung der user_inventory-Härtung vom selben Abend: drei
-- weitere Stellen mit demselben Grundmuster gefunden (Nutzerfrage
-- "haben wir noch dringliche Themen davon") und geschlossen.
-- ============================================================

-- 1) action_log — DAS Kernstück (XP/Level werden nie gespeichert,
-- sondern immer frisch aus dieser Tabelle aufsummiert). Bisher prüfte
-- log_insert_own nur "gehört dir die Zeile", nicht ob xp/energy/skill
-- plausibel sind -- exakt dieselbe Lücke wie bei user_inventory, nur
-- am wichtigeren Datensatz. Alle 9 Insert-Stellen in index.html fallen
-- in drei Gruppen, dafür drei neue Funktionen:
--
-- a) log_action_for_self(): der Normalfall (logAction/logTallyAction/
--    logActionForContact/logKanbanAction/Chronik-Aktivität/Dungeon-
--    Aktion) -- xp/energy/skill/skill2/label kommen jetzt IMMER aus
--    dem echten Regelwerk (rule_configs.config.actions), nie vom
--    Client. context/location_id/contact_id/meta bleiben Durchreiche
--    (reine Beschreibungsfelder ohne Punktewert, kein Integritätsrisiko).
-- b) grant_quest_bonus_to_self(): tägliche/wöchentliche Quests +
--    Quest-Ketten -- Bonus-XP kommt aus rule_configs.config.
--    recurringQuests/questChains, nicht vom Client. Zusätzlich, weil
--    hier (anders als bei a) keine echte Handlung dahinter geprüft
--    wird: ein Duplikat-Check pro Zeitraum/Stufe (kann nicht zweimal
--    für dieselbe Quest am selben Tag vergeben werden).
-- c) log_item_energy_refill_for_self(): der Manatrank-Effekt --
--    energy ist hier kein fester Katalog-Wert, sondern hängt von der
--    heute schon verbrauchten Energie ab. Wird jetzt serverseitig aus
--    der echten Tagessumme berechnet, nicht vom Client übernommen.
--
-- Bewusst NICHT mit angefasst (gleiche Abwägung wie bei user_inventory,
-- ausführlich mit dem Nutzer besprochen): ob eine Quest/Handlung wirklich
-- verdient ist, wird weiterhin nicht serverseitig nachgeprüft -- das
-- bräuchte die komplette Quest-Auswertung zusätzlich in der Datenbank,
-- ein eigenes großes Projekt (siehe project_business_fahrplan, Phase 5).
-- Diese drei Funktionen schließen "erfundener xp-Wert"/"erfundener
-- Aktions-Schlüssel", nicht "wurde wirklich gehandelt".

create or replace function public.log_action_for_self(
  p_action_key text,
  p_context text default null,
  p_location_id uuid default null,
  p_contact_id uuid default null,
  p_meta jsonb default null,
  p_occurred_at timestamptz default now()
)
returns public.action_log
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_action jsonb;
  v_row public.action_log;
begin
  select org_id into v_org_id from public.profiles where id = auth.uid();
  if v_org_id is null then
    raise exception 'Kein gültiges Profil für diesen Aufruf.';
  end if;

  select config->'actions'->p_action_key into v_action from public.rule_configs where org_id = v_org_id;
  if v_action is null then
    raise exception 'Unbekannter Aktions-Schlüssel: %', p_action_key;
  end if;

  insert into public.action_log (user_id, org_id, action_key, label, xp, energy, skill, skill2, context, location_id, contact_id, meta, created_at)
  values (
    auth.uid(), v_org_id, p_action_key,
    coalesce(v_action->>'label', p_action_key),
    coalesce((v_action->>'xp')::integer, 0),
    coalesce((v_action->>'energy')::integer, 0),
    v_action->>'skill',
    v_action->>'skill2',
    p_context, p_location_id, p_contact_id, p_meta, coalesce(p_occurred_at, now())
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.grant_quest_bonus_to_self(
  p_kind text,
  p_quest_id text,
  p_period_key text default null,
  p_stage_id text default null
)
returns public.action_log
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_config jsonb;
  v_quest jsonb;
  v_stage jsonb;
  v_bonus integer;
  v_label text;
  v_meta jsonb;
  v_action_key text;
  v_already integer;
  v_row public.action_log;
begin
  select org_id into v_org_id from public.profiles where id = auth.uid();
  if v_org_id is null then
    raise exception 'Kein gültiges Profil für diesen Aufruf.';
  end if;

  select config into v_config from public.rule_configs where org_id = v_org_id;

  if p_kind = 'recurring' then
    if p_period_key is null then
      raise exception 'periodKey fehlt.';
    end if;
    select elem into v_quest from jsonb_array_elements(coalesce(v_config->'recurringQuests', '[]'::jsonb)) elem
      where elem->>'id' = p_quest_id;
    if v_quest is null then
      raise exception 'Unbekannte Quest: %', p_quest_id;
    end if;
    v_bonus := coalesce((v_quest->>'bonus')::integer, 0);
    v_label := 'Quest erfüllt: ' || coalesce(v_quest->>'name', p_quest_id);
    v_action_key := 'quest_bonus';
    v_meta := jsonb_build_object('questId', p_quest_id, 'periodKey', p_period_key);

    select count(*) into v_already from public.action_log
      where user_id = auth.uid() and action_key = 'quest_bonus'
        and meta->>'questId' = p_quest_id and meta->>'periodKey' = p_period_key;
    if v_already > 0 then
      raise exception 'Belohnung für % (%) wurde bereits vergeben.', p_quest_id, p_period_key;
    end if;

  elsif p_kind = 'chain' then
    if p_stage_id is null then
      raise exception 'stageId fehlt.';
    end if;
    select elem into v_quest from jsonb_array_elements(coalesce(v_config->'questChains', '[]'::jsonb)) elem
      where elem->>'id' = p_quest_id;
    if v_quest is null then
      raise exception 'Unbekannte Kette: %', p_quest_id;
    end if;
    select elem into v_stage from jsonb_array_elements(coalesce(v_quest->'stages', '[]'::jsonb)) elem
      where elem->>'id' = p_stage_id;
    if v_stage is null then
      raise exception 'Unbekannte Kettenstufe: %', p_stage_id;
    end if;
    v_bonus := coalesce((v_stage->>'bonus')::integer, 0);
    v_label := 'Kette erfüllt: ' || coalesce(v_quest->>'name', p_quest_id) || ' — ' || coalesce(v_stage->>'name', p_stage_id);
    v_action_key := 'chain_bonus';
    v_meta := jsonb_build_object('chainId', p_quest_id, 'stageId', p_stage_id);

    select count(*) into v_already from public.action_log
      where user_id = auth.uid() and action_key = 'chain_bonus'
        and meta->>'chainId' = p_quest_id and meta->>'stageId' = p_stage_id;
    if v_already > 0 then
      raise exception 'Belohnung für % (%) wurde bereits vergeben.', p_quest_id, p_stage_id;
    end if;
  else
    raise exception 'Unbekannte Art: %', p_kind;
  end if;

  insert into public.action_log (user_id, org_id, action_key, label, xp, energy, meta)
  values (auth.uid(), v_org_id, v_action_key, v_label, v_bonus, 0, v_meta)
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.log_item_energy_refill_for_self(p_item_key text)
returns public.action_log
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_item jsonb;
  v_today date;
  v_used integer;
  v_row public.action_log;
begin
  select org_id into v_org_id from public.profiles where id = auth.uid();
  if v_org_id is null then
    raise exception 'Kein gültiges Profil für diesen Aufruf.';
  end if;

  select config->'items'->p_item_key into v_item from public.rule_configs where org_id = v_org_id;
  if v_item is null or (v_item->>'effect') is distinct from 'full_energy_refill' then
    raise exception 'Item hat keinen Energie-Auffüll-Effekt: %', p_item_key;
  end if;

  v_today := (now() at time zone 'Europe/Berlin')::date;

  select coalesce(sum(energy), 0) into v_used
    from public.action_log
    where user_id = auth.uid()
      and (created_at at time zone 'Europe/Berlin')::date = v_today;

  if v_used <= 0 then
    raise exception 'Energie ist bereits voll, Trank wäre wirkungslos.';
  end if;

  insert into public.action_log (user_id, org_id, action_key, label, xp, energy, meta)
  values (auth.uid(), v_org_id, 'item_use', 'Benutzt: ' || coalesce(v_item->>'label', p_item_key), 0, -v_used, jsonb_build_object('itemKey', p_item_key))
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.log_action_for_self(text, text, uuid, uuid, jsonb, timestamptz) to authenticated;
grant execute on function public.grant_quest_bonus_to_self(text, text, text, text) to authenticated;
grant execute on function public.log_item_energy_refill_for_self(text) to authenticated;

-- Direktes Schreiben ist ab jetzt nicht mehr möglich -- nur noch die
-- drei Funktionen oben (SECURITY DEFINER) dürfen in action_log
-- schreiben. Lesen (log_select_*) bleibt unverändert.
drop policy if exists "log_insert_own" on public.action_log;


-- 2) sales — Bewertungssumme/laufender Beitrag/Menge sind echte,
-- frei einzugebende Vertragsdaten (anders als bei action_log/
-- user_inventory gibt es hier keinen Katalogwert, gegen den man
-- prüfen könnte -- ein realer Vertragsbetrag ist nun mal variabel).
-- Deshalb hier KEIN vollständiger Verschluss wie oben, sondern
-- Plausibilitäts-Grenzen (CHECK-Constraints, gelten für INSERT UND
-- UPDATE gleichermaßen) gegen offensichtlichen Unsinn wie
-- "quantity:9999"-artige Werte. Zusätzlich: created_by muss beim
-- Anlegen die eigene ID sein (bisher ungeprüft, hätte Verkäufe unter
-- fremdem Namen erlaubt) -- App setzt das an beiden Insert-Stellen
-- ohnehin immer schon selbst so, keine Verhaltensänderung.
alter table public.sales
  add constraint sales_bewertungssumme_range check (bewertungssumme is null or (bewertungssumme >= 0 and bewertungssumme <= 100000000)),
  add constraint sales_laufender_beitrag_range check (laufender_beitrag is null or (laufender_beitrag >= 0 and laufender_beitrag <= 1000000)),
  add constraint sales_menge_range check (menge >= 1 and menge <= 1000);

drop policy if exists "sales_insert_like_contact" on public.sales;
create policy "sales_insert_like_contact" on public.sales for insert
with check (
  (org_id = current_org_id())
  and (created_by = auth.uid())
  and (exists (select 1 from public.contacts c where c.id = sales.contact_id and (c.owner_id = auth.uid() or is_admin())))
);


-- 3) locations — owner_id/created_by waren beim Anlegen komplett
-- ungeprüft (die App selbst setzt beide immer korrekt auf sich
-- selbst bzw. owner_id NULL für den Gilden-Pool -- die Lücke war nur
-- über einen direkten API-Aufruf ausnutzbar, kein echter Gewinn dabei,
-- aber dieselbe Art Lücke wie oben, deshalb mitgeschlossen).
drop policy if exists "locations_insert_org_members" on public.locations;
create policy "locations_insert_org_members" on public.locations for insert
with check (
  (org_id = current_org_id())
  and (created_by = auth.uid())
  and (owner_id = auth.uid() or owner_id is null)
  and ((guild_id is null) or guild_dungeon_permission(guild_id, true))
);
