-- ============================================================
-- Idempotenz-Härtung: withClickGuard() schützt nur gegen einen
-- Doppelklick im selben Tab -- NICHT gegen einen Netzwerk-Retry
-- (Antwort geht verloren, Client denkt es sei fehlgeschlagen, Nutzer
-- versucht es erneut), einen zweiten offenen Tab, oder eine verzögerte
-- zweite Anfrage. Auslöser: Nutzer brachte eine generische
-- Engineering-Checkliste mit ("Eine bloße Deaktivierung des Buttons
-- ist keine zuverlässige Lösung. Der Server sollte z.B. mit
-- Idempotency Keys ... dafür sorgen, dass dieselbe Operation nur
-- einmal ausgeführt wird."), Cross-Check gegen den echten Code fand
-- drei konkrete Lücken -- diese Migration schließt zwei davon
-- serverseitig (die dritte, der nicht-atomare Mehrfach-Produkt-
-- Verkauf, bleibt bewusst UI-seitig wie bisher, siehe CLAUDE.md).
--
-- 1) grant_quest_bonus_to_self(): der bestehende Duplikat-Schutz war
--    "erst zählen, dann einfügen" (SELECT COUNT(*) ... IF > 0 THEN
--    RAISE) -- kein echter Constraint dahinter, also ein klassisches
--    Race-Window zwischen Prüfung und Insert. Umgestellt auf drei
--    partielle Unique-Indizes (einer je Duplikat-Schlüssel: Quest+
--    Zeitraum / Kette+Stufe / Questbaum+Stufe+Jahr) + INSERT ... ON
--    CONFLICT ... DO NOTHING -- Postgres entscheidet jetzt atomar,
--    zwei gleichzeitige Aufrufe können nicht mehr beide durchkommen.
-- 2) log_action_for_self(): hatte bisher GAR KEINEN Duplikatschutz --
--    die Funktion hinter fast jeder XP-Aktion. Ein exakt identischer
--    Aufruf (gleicher Nutzer/Aktions-Schlüssel/context/location/
--    contact/meta) innerhalb der letzten 5 Sekunden gibt jetzt die
--    bereits geloggte Zeile zurück statt ein zweites Mal zu inserten --
--    bewusst ein Zeitfenster statt eines harten Unique-Constraints
--    (dieselbe Aktion mehrfach am Tag zu loggen ist der Normalfall,
--    z.B. mehrere "Ansprache"-Einträge), 5 Sekunden sind lang genug für
--    einen realistischen Retry, kurz genug um eine echte, schnell
--    hintereinander eingegebene zweite Aktion praktisch nie
--    fälschlich zu blocken.
-- 3) sales: neuer BEFORE-INSERT-Trigger mit demselben Zeitfenster-
--    Prinzip -- ein exakt identischer Verkauf (gleicher Nutzer/
--    Kontakt/Produkt/Status/Beitrag/Vertragsbeginn) innerhalb von
--    5 Sekunden wird still übersprungen (RETURN NULL storniert den
--    Insert ohne Fehler) statt einen zweiten Vertrag anzulegen --
--    korrekte Idempotenz-Semantik: der Client sieht keinen Fehler
--    (der Datensatz existiert ja bereits genau einmal, wie gewollt).
-- ============================================================

-- 1) grant_quest_bonus_to_self(): atomarer Duplikatschutz
drop index if exists action_log_quest_bonus_dedup_idx;
drop index if exists action_log_chain_bonus_dedup_idx;
drop index if exists action_log_questtree_bonus_dedup_idx;

create unique index action_log_quest_bonus_dedup_idx
  on public.action_log (user_id, (meta->>'questId'), (meta->>'periodKey'))
  where action_key = 'quest_bonus';

create unique index action_log_chain_bonus_dedup_idx
  on public.action_log (user_id, (meta->>'chainId'), (meta->>'stageId'))
  where action_key = 'chain_bonus';

create unique index action_log_questtree_bonus_dedup_idx
  on public.action_log (user_id, (meta->>'questTreeId'), (meta->>'stageId'), (meta->>'year'))
  where action_key = 'questtree_bonus';

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
as $func$
declare
  v_org_id uuid;
  v_config jsonb;
  v_quest jsonb;
  v_stage jsonb;
  v_bonus integer;
  v_label text;
  v_meta jsonb;
  v_action_key text;
  v_row public.action_log;
begin
  select org_id into v_org_id from public.profiles where id = auth.uid();
  if v_org_id is null then
    raise exception 'Kein gueltiges Profil fuer diesen Aufruf.';
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
    v_label := 'Quest erfuellt: ' || coalesce(v_quest->>'name', p_quest_id);
    v_action_key := 'quest_bonus';
    v_meta := jsonb_build_object('questId', p_quest_id, 'periodKey', p_period_key);

    insert into public.action_log (user_id, org_id, action_key, label, xp, energy, meta)
    values (auth.uid(), v_org_id, v_action_key, v_label, v_bonus, 0, v_meta)
    on conflict (user_id, (meta->>'questId'), (meta->>'periodKey')) where action_key = 'quest_bonus'
    do nothing
    returning * into v_row;

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
    v_label := 'Kette erfuellt: ' || coalesce(v_quest->>'name', p_quest_id) || ' -- ' || coalesce(v_stage->>'name', p_stage_id);
    v_action_key := 'chain_bonus';
    v_meta := jsonb_build_object('chainId', p_quest_id, 'stageId', p_stage_id);

    insert into public.action_log (user_id, org_id, action_key, label, xp, energy, meta)
    values (auth.uid(), v_org_id, v_action_key, v_label, v_bonus, 0, v_meta)
    on conflict (user_id, (meta->>'chainId'), (meta->>'stageId')) where action_key = 'chain_bonus'
    do nothing
    returning * into v_row;

  elsif p_kind = 'questtree' then
    if p_period_key is null then
      raise exception 'periodKey (Jahr) fehlt.';
    end if;
    select elem into v_quest from jsonb_array_elements(coalesce(v_config->'questTree', '[]'::jsonb)) elem
      where elem->>'id' = p_quest_id;
    if v_quest is null then
      raise exception 'Unbekannte Questbaum-Kette: %', p_quest_id;
    end if;

    if v_quest->>'type' = 'epic' then
      if (v_quest->>'bonus') is null then
        raise exception 'Unbekanntes oder XP-loses Epic: %', p_quest_id;
      end if;
      v_bonus := (v_quest->>'bonus')::integer;
      v_label := 'Epic erfuellt: ' || coalesce(v_quest->>'title', v_quest->>'label', p_quest_id);
      p_stage_id := p_quest_id;
    else
      if p_stage_id is null then
        raise exception 'stageId fehlt.';
      end if;
      select elem into v_stage from jsonb_array_elements(coalesce(v_quest->'stages', '[]'::jsonb)) elem
        where elem->>'id' = p_stage_id;
      if v_stage is null or (v_stage->>'bonus') is null then
        raise exception 'Unbekannte oder XP-lose Questbaum-Stufe: %', p_stage_id;
      end if;
      v_bonus := (v_stage->>'bonus')::integer;
      v_label := 'Questbaum-Ziel erfuellt: ' || coalesce(v_stage->>'label', p_stage_id);
    end if;

    v_action_key := 'questtree_bonus';
    v_meta := jsonb_build_object('questTreeId', p_quest_id, 'stageId', p_stage_id, 'year', p_period_key);

    insert into public.action_log (user_id, org_id, action_key, label, xp, energy, meta)
    values (auth.uid(), v_org_id, v_action_key, v_label, v_bonus, 0, v_meta)
    on conflict (user_id, (meta->>'questTreeId'), (meta->>'stageId'), (meta->>'year')) where action_key = 'questtree_bonus'
    do nothing
    returning * into v_row;

  else
    raise exception 'Unbekannte Art: %', p_kind;
  end if;

  if v_row.id is null then
    raise exception 'Belohnung fuer % wurde bereits vergeben.', p_quest_id;
  end if;

  return v_row;
end;
$func$;

-- 2) log_action_for_self(): Zeitfenster-Duplikatschutz
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

  select * into v_row from public.action_log
    where user_id = auth.uid()
      and action_key = p_action_key
      and coalesce(context, '') = coalesce(p_context, '')
      and location_id is not distinct from p_location_id
      and contact_id is not distinct from p_contact_id
      and coalesce(meta, '{}'::jsonb) = coalesce(p_meta, '{}'::jsonb)
      and created_at > now() - interval '5 seconds'
    order by created_at desc
    limit 1;
  if v_row.id is not null then
    return v_row;
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

-- 3) sales: BEFORE-INSERT-Duplikatschutz
create or replace function public.prevent_duplicate_sale_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing_id uuid;
begin
  select id into v_existing_id
    from public.sales
    where created_by = new.created_by
      and contact_id is not distinct from new.contact_id
      and product_id = new.product_id
      and status = new.status
      and laufender_beitrag is not distinct from new.laufender_beitrag
      and vertragsbeginn is not distinct from new.vertragsbeginn
      and created_at > now() - interval '5 seconds'
    limit 1;
  if v_existing_id is not null then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_duplicate_sale_submission on public.sales;
create trigger trg_prevent_duplicate_sale_submission
  before insert on public.sales
  for each row execute function public.prevent_duplicate_sale_submission();

insert into public.schema_patches (patch_number, title) values
  (52, 'Idempotenz-Haertung: atomarer Quest-Bonus-Dedup, Zeitfenster-Duplikatschutz fuer action_log/sales')
on conflict (patch_number) do nothing;
