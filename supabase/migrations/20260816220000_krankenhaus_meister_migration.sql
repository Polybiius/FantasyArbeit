-- ============================================================
-- Bonus-XP für den Questbaum + Migration der alten Kette
-- "Krankenhaus-Meister" (config.questChains, bisher das letzte
-- verbliebene Relikt des Vor-Questbaum-Systems). Danach wird das alte
-- System endgültig abgeschaltet.
--
-- Bisher gab der Questbaum bewusst nur Titel, keine XP (Phase-1-
-- Entscheidung, um die Level-Kurve nicht neu kalibrieren zu müssen).
-- Diese Migration führt XP für Questbaum-Stufen ein, aber NUR für die
-- beiden hier neu angelegten Krankenhaus-Meister-Stufen -- keine
-- rückwirkende XP-Vergabe für sonstige, längst bestehende Stufen.
-- ============================================================

-- 1) grant_quest_bonus_to_self(): dritte Art "questtree" ergänzt,
-- gleiches Duplikat-Schutz-Prinzip wie "recurring"/"chain" (kann nicht
-- zweimal für dieselbe Stufe vergeben werden). XP kommt aus dem
-- stage.bonus-Feld im Regelwerk, nie vom Client.
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

  elsif p_kind = 'questtree' then
    if p_stage_id is null then
      raise exception 'stageId fehlt.';
    end if;
    select elem into v_quest from jsonb_array_elements(coalesce(v_config->'questTree', '[]'::jsonb)) elem
      where elem->>'id' = p_quest_id;
    if v_quest is null then
      raise exception 'Unbekannte Questbaum-Kette: %', p_quest_id;
    end if;
    select elem into v_stage from jsonb_array_elements(coalesce(v_quest->'stages', '[]'::jsonb)) elem
      where elem->>'id' = p_stage_id;
    if v_stage is null or (v_stage->>'bonus') is null then
      raise exception 'Unbekannte oder XP-lose Questbaum-Stufe: %', p_stage_id;
    end if;
    v_bonus := (v_stage->>'bonus')::integer;
    v_label := 'Questbaum-Ziel erfüllt: ' || coalesce(v_stage->>'label', p_stage_id);
    v_action_key := 'questtree_bonus';
    v_meta := jsonb_build_object('questTreeId', p_quest_id, 'stageId', p_stage_id);

    select count(*) into v_already from public.action_log
      where user_id = auth.uid() and action_key = 'questtree_bonus'
        and meta->>'questTreeId' = p_quest_id and meta->>'stageId' = p_stage_id;
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

-- 2) Zwei neue Questbaum-Stufen (ersetzen inhaltlich die alte Kette,
-- gleiche 50/100 XP wie bisher, siehe Absprache -- keine neue XP-Quelle,
-- nur eine strukturell zuverlässigere Zählweise: nach dem echten
-- verknüpften Betrieb [location_id], nicht nach frei getipptem Text wie
-- im alten System). Gleiches Format wie die bestehenden Ketten
-- kh_gaenge/kh_breite, nur auf Aktion "abschluss" statt "ansprache".
update public.rule_configs
set config = jsonb_set(
  jsonb_set(config, '{questChains}', '[]'::jsonb),
  '{questTree}',
  (config->'questTree') || jsonb_build_array(
    jsonb_build_object(
      'id', 'kh_abschluss_tiefe',
      'type', 'ladder',
      'label', 'Abschlüsse im selben Krankenhaus',
      'metric', jsonb_build_object('action','abschluss','groupBy','location_id','aggregate','maxPerGroup','locationType','krankenhaus'),
      'stages', jsonb_build_array(
        jsonb_build_object('id','kh_abschluss_tiefe_3','label','3 Abschlüsse im selben Krankenhaus','threshold',3,'bonus',50)
      ),
      'category', 'Krankenhausakquise'
    ),
    jsonb_build_object(
      'id', 'kh_abschluss_breite',
      'type', 'ladder',
      'label', 'Abschlüsse in verschiedenen Krankenhäusern',
      'metric', jsonb_build_object('action','abschluss','groupBy','location_id','aggregate','groupsAtLeast','locationType','krankenhaus'),
      'stages', jsonb_build_array(
        jsonb_build_object('id','kh_abschluss_breite_3','label','Abschlüsse in 3 verschiedenen Krankenhäusern','minGroups',3,'minPerGroup',1,'bonus',100)
      ),
      'category', 'Krankenhausakquise'
    )
  )
);

-- 3) Die zwei alten Log-Einträge aus dem bisherigen System löschen
-- (Nutzer-Go, ausdrücklich: "kein Stress, XP-Verhältnisse sind
-- wichtiger als das Bewahren alter Werte") -- exakt auf die alte Kette
-- eingegrenzt (action_key + chainId), betrifft sonst nichts.
delete from public.action_log
where action_key = 'chain_bonus' and meta->>'chainId' = 'krankenhaus_meister';

insert into public.schema_patches (patch_number, title) values
  (49, 'Questbaum kann jetzt XP vergeben; alte Kette "Krankenhaus-Meister" migriert und altes Kettensystem abgeschaltet')
on conflict (patch_number) do nothing;
