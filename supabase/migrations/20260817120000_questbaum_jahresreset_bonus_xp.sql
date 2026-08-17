-- ============================================================
-- Jahres-Reset fuer den Questbaum + Bonus-XP fuer den gesamten Baum
-- (bisher hatten nur die zwei Krankenhaus-Meister-Stufen echte
-- Bonus-XP, siehe 20260816220000). Auf ausdruecklichen Nutzerwunsch:
-- "unsere Quests sind Jahresquests, nach jedem Geschaeftsjahr wird
-- einmal resettet" -- Geschaeftsjahr = Kalenderjahr (wie die
-- bestehenden Jahr/Monat-Reiter im Kompendium). Damit ist eine Stufe
-- keine einmalige Lebensleistung mehr, sondern ein jaehrlich
-- wiederholbares Ziel -- siehe project_questbaum_schema_design fuer
-- die vollstaendige Kalibrierungs-Herleitung (Artifact mit dem Nutzer
-- durchgesprochen und abgesegnet, 2026-08-17).
--
-- Drei Teile:
-- 1) grant_quest_bonus_to_self(): questtree-Zweig um Epics erweitert
--    (eigenes flaches bonus-Feld statt eines stages-Arrays -- Epics
--    haben requires/requiresMode, kein stages-Array) UND der
--    Duplikat-Schutz nutzt jetzt zusaetzlich das Jahr (ueber den
--    ohnehin vorhandenen p_period_key-Parameter, gleiches Muster wie
--    beim "recurring"-Zweig) -- dieselbe Stufe/dasselbe Epic kann
--    dadurch pro Jahr einmal, aber ueber mehrere Jahre hinweg mehrfach
--    ausgezahlt werden.
-- 2) rule_configs.config.questTree: bonus-Feld an allen 76 bestehenden
--    Ladder-/Quoten-/Serien-Stufen + bonus-Feld an allen 11 Epics
--    ergaenzt (Werte siehe Artifact-Freigabe, proportional zur
--    Schwierigkeit gestaffelt). Gewohnheits-Stufen (kh_habit_1/2)
--    bleiben bewusst ohne Bonus (kein stages-Array, siehe Nutzer-
--    Absprache Punkt 1). levelBase steigt von 4,70 auf 5,80
--    (levelExponent bleibt 1,5) -- Neukalibrierung, weil jaehrlich
--    wiederholbare Boni das Gesamt-XP-Budget ueber 10 Jahre spuerbar
--    erhoehen (185.656 -> 228.876 XP bis Level 100, +23,3%).
-- 3) Frontend (index.html, bereits committed): evaluateLadderQuest/
--    evaluateSalesLadderQuest/evaluateRatioQuest/evaluateStreakQuest
--    werten jetzt nur noch Ereignisse/Verkaeufe des laufenden
--    Kalenderjahres aus (logInCurrentYear()/currentBusinessYear()),
--    checkAndAwardEpics() zahlt jetzt echte Bonus-XP aus (statt nur
--    zu feiern) und ist dafuer async geworden.
--
-- Bewusst noch NICHT Teil dieser Migration: der "Trophaenraum" (Ort,
-- an dem vergangene Jahre ihre erreichten Stufen/Epics behalten,
-- obwohl die laufende Ansicht zum 1. Januar wieder bei 0 startet) --
-- eigener, separater Design-Schritt nach dieser Freigabe, siehe
-- project_questbaum_schema_design. Der neue action_log.meta.year
-- macht ihn spaeter ohne neue Tabelle direkt aus action_log ableitbar.
-- ============================================================

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
  v_already integer;
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

    select count(*) into v_already from public.action_log
      where user_id = auth.uid() and action_key = 'quest_bonus'
        and meta->>'questId' = p_quest_id and meta->>'periodKey' = p_period_key;
    if v_already > 0 then
      raise exception 'Belohnung fuer % (%) wurde bereits vergeben.', p_quest_id, p_period_key;
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
    v_label := 'Kette erfuellt: ' || coalesce(v_quest->>'name', p_quest_id) || ' -- ' || coalesce(v_stage->>'name', p_stage_id);
    v_action_key := 'chain_bonus';
    v_meta := jsonb_build_object('chainId', p_quest_id, 'stageId', p_stage_id);

    select count(*) into v_already from public.action_log
      where user_id = auth.uid() and action_key = 'chain_bonus'
        and meta->>'chainId' = p_quest_id and meta->>'stageId' = p_stage_id;
    if v_already > 0 then
      raise exception 'Belohnung fuer % (%) wurde bereits vergeben.', p_quest_id, p_stage_id;
    end if;

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

    select count(*) into v_already from public.action_log
      where user_id = auth.uid() and action_key = 'questtree_bonus'
        and meta->>'questTreeId' = p_quest_id and meta->>'stageId' = p_stage_id
        and meta->>'year' = p_period_key;
    if v_already > 0 then
      raise exception 'Belohnung fuer % (%, %) wurde bereits vergeben.', p_quest_id, p_stage_id, p_period_key;
    end if;

  else
    raise exception 'Unbekannte Art: %', p_kind;
  end if;

  insert into public.action_log (user_id, org_id, action_key, label, xp, energy, meta)
  values (auth.uid(), v_org_id, v_action_key, v_label, v_bonus, 0, v_meta)
  returning * into v_row;

  return v_row;
end;
$func$;

-- rule_configs.config.questTree: bonus-Feld an allen Stufen+Epics,
-- levelBase neu kalibriert (4,70 -> 5,80).
update public.rule_configs
set config = jsonb_set(
  jsonb_set(config, '{questTree}', $qtree$[{"category":"Krankenhausakquise","id":"kh_gaenge","label":"Gänge ins selbe Krankenhaus","metric":{"action":"ansprache","aggregate":"maxPerGroup","groupBy":"location_id","locationType":"krankenhaus"},"stages":[{"id":"kh_gaenge_1","label":"Der erste Schritt","threshold":1,"bonus":30},{"id":"kh_gaenge_3","label":"3 Gänge ins selbe Krankenhaus","threshold":3,"bonus":50},{"id":"kh_gaenge_6","label":"6 Gänge ins selbe Krankenhaus","threshold":6,"title":"Der Stammgast","bonus":90},{"id":"kh_gaenge_10","label":"10+ im selben Krankenhaus","threshold":10,"title":"Krankenhaus-Legende","bonus":160}],"type":"ladder"},{"category":"Krankenhausakquise","id":"kh_habit_1","label":"1 Krankenhausbesuch pro Woche","metric":{"action":"ansprache","locationType":"krankenhaus"},"period":"weekly","threshold":1,"type":"habit"},{"category":"Krankenhausakquise","id":"kh_habit_2","label":"2 Krankenhausbesuche pro Woche","metric":{"action":"ansprache","locationType":"krankenhaus"},"period":"weekly","threshold":2,"type":"habit"},{"category":"Krankenhausakquise","id":"kh_breite","label":"Verschiedene Krankenhäuser","metric":{"action":"ansprache","aggregate":"groupsAtLeast","groupBy":"location_id","locationType":"krankenhaus"},"stages":[{"id":"kh_breite_3in3","label":"3* in 3 verschiedenen Krankenhäusern","minGroups":3,"minPerGroup":3,"bonus":50},{"id":"kh_breite_10in2","label":"10* in 2 verschiedenen Krankenhäusern","minGroups":2,"minPerGroup":10,"bonus":100},{"id":"kh_breite_10in5","label":"10* in 5 verschiedenen Krankenhäusern","minGroups":5,"minPerGroup":10,"title":"Der Netzwerker","bonus":180}],"type":"ladder"},{"category":"Krankenhausakquise","id":"kh_tueroeffner","label":"Türöffner-Quote","metric":{"denominator":"ansprache","locationType":"krankenhaus","numerator":"termin_vereinbart"},"stages":[{"id":"kh_tueroeffner_20","label":"20% Türöffner-Quote","threshold":20,"bonus":20},{"id":"kh_tueroeffner_40","label":"40% Türöffner-Quote","threshold":40,"bonus":40},{"id":"kh_tueroeffner_60","label":"60% Türöffner-Quote","threshold":60,"title":"Der Türöffner","bonus":70}],"type":"ratio","window":15},{"category":"Krankenhausakquise","id":"kh_weg","label":"Der Krankenhaus-Weg","requires":["kh_gaenge_10","kh_breite_10in5"],"requiresMode":"any","title":"Der Krankenhaus-Weg","type":"epic","bonus":150},{"category":"Kundenausbau","id":"ausbau_eigen","label":"Eigenausbau","metric":{"action":"abschluss","aggregate":"maxPerGroup","groupBy":"month"},"stages":[{"id":"ausbau_eigen_3","label":"3 Kunden im Monat","threshold":3,"bonus":40},{"id":"ausbau_eigen_4","label":"4 Kunden im Monat","threshold":4,"bonus":90},{"id":"ausbau_eigen_5","label":"5 Kunden im Monat","threshold":5,"title":"Beziehungsbauer","bonus":160}],"type":"ladder"},{"category":"Kundenausbau","id":"ausbau_bestand","label":"Bestandskundenausbau","metric":{"action":"kundenausbau","aggregate":"maxPerGroup","groupBy":"year"},"stages":[{"id":"ausbau_bestand_3","label":"3 Bestandskunden im Jahr","threshold":3,"bonus":30},{"id":"ausbau_bestand_4","label":"4 Bestandskunden im Jahr","threshold":4,"bonus":60},{"id":"ausbau_bestand_5","label":"5 Bestandskunden im Jahr","threshold":5,"bonus":110},{"id":"ausbau_bestand_6","label":"6 Bestandskunden im Jahr","threshold":6,"title":"Bestandspfleger","bonus":180}],"type":"ladder"},{"category":"Kundenausbau","id":"kundenpfleger","label":"Der Kundenpfleger","requires":["ausbau_eigen_5","ausbau_bestand_6"],"requiresMode":"any","title":"Der Kundenpfleger","type":"epic","bonus":150},{"category":"Empfehlungsmanagement","id":"empfehlung_kette","label":"Empfehlungsmanagement","metric":{"action":"empfehlung","aggregate":"maxPerGroup","groupBy":"month"},"stages":[{"id":"empfehlung_1","label":"1 Empfehlung im Monat","threshold":1,"bonus":25},{"id":"empfehlung_2","label":"2 Empfehlungen im Monat","threshold":2,"bonus":50},{"id":"empfehlung_3","label":"3 Empfehlungen im Monat","threshold":3,"bonus":90},{"id":"empfehlung_5","label":"5 Empfehlungen im Monat","threshold":5,"title":"Vertrauensperson","bonus":150}],"type":"ladder"},{"category":"Empfehlungsmanagement","id":"vertrauensmakler","label":"Der Vertrauens-Makler","requires":["empfehlung_5","ausbau_bestand_6"],"requiresMode":"all","title":"Der Vertraute","type":"epic","bonus":250},{"category":"Meisterschaft","id":"meister_erschein","label":"Erscheinquote (Termine)","metric":{"denominator":["termin_wahrgenommen","termin_nicht_wahrgenommen"],"numerator":"termin_wahrgenommen"},"stages":[{"id":"meister_erschein_65","label":"65% Erscheinquote","threshold":65,"bonus":20},{"id":"meister_erschein_75","label":"75% Erscheinquote","threshold":75,"bonus":40},{"id":"meister_erschein_85","label":"85% Erscheinquote","threshold":85,"title":"Der Verlässliche","bonus":70}],"type":"ratio","window":20},{"category":"Meisterschaft","id":"meister_abschluss","label":"Abschlussquote (Pitch → Abschluss)","metric":{"denominator":"pitch","numerator":"abschluss"},"stages":[{"id":"meister_abschluss_20","label":"20% Abschlussquote","threshold":20,"bonus":20},{"id":"meister_abschluss_30","label":"30% Abschlussquote","threshold":30,"bonus":40},{"id":"meister_abschluss_40","label":"40% Abschlussquote","threshold":40,"title":"Der Closer","bonus":70}],"type":"ratio","window":15},{"category":"Meisterschaft","id":"meister_erreich","label":"Erreichquote (Anrufe)","metric":{"denominator":["anruf_erreicht","anruf_nicht_erreicht"],"numerator":"anruf_erreicht"},"stages":[{"id":"meister_erreich_40","label":"40% Erreichquote","threshold":40,"bonus":20},{"id":"meister_erreich_55","label":"55% Erreichquote","threshold":55,"bonus":40},{"id":"meister_erreich_70","label":"70% Erreichquote","threshold":70,"title":"Der Draht zu den Menschen","bonus":70}],"type":"ratio","window":30},{"category":"Meisterschaft","id":"meisterschaft_schwerpunkt","label":"Meisterschafts-Schwerpunkt","requires":["meister_erschein_85","meister_abschluss_40","meister_erreich_70"],"requiresMode":2,"title":"Meisterschafts-Schwerpunkt","type":"epic","bonus":250},{"category":"Termine","id":"termine_online","label":"Termine Online","metric":{"action":"termin_vereinbart","aggregate":"maxPerGroup","groupBy":"year","kanal":"online"},"stages":[{"id":"termine_online_10","label":"10 Termine Online","threshold":10,"bonus":20},{"id":"termine_online_20","label":"20 Termine Online","threshold":20,"bonus":40},{"id":"termine_online_35","label":"35 Termine Online","threshold":35,"bonus":80},{"id":"termine_online_50","label":"50 Termine Online","threshold":50,"title":"Digital-Profi","bonus":150}],"type":"ladder"},{"category":"Termine","id":"termine_buero","label":"Termine im Büro","metric":{"action":"termin_vereinbart","aggregate":"maxPerGroup","groupBy":"year","kanal":"buero"},"stages":[{"id":"termine_buero_8","label":"8 Termine im Büro","threshold":8,"bonus":20},{"id":"termine_buero_18","label":"18 Termine im Büro","threshold":18,"bonus":40},{"id":"termine_buero_30","label":"30 Termine im Büro","threshold":30,"bonus":80},{"id":"termine_buero_45","label":"45 Termine im Büro","threshold":45,"title":"Gastgeber","bonus":150}],"type":"ladder"},{"category":"Termine","id":"termine_betrieb","label":"Termine im Betrieb","metric":{"action":"termin_vereinbart","aggregate":"maxPerGroup","groupBy":"year","kanal":"betrieb"},"stages":[{"id":"termine_betrieb_5","label":"5 Termine im Betrieb","threshold":5,"bonus":20},{"id":"termine_betrieb_12","label":"12 Termine im Betrieb","threshold":12,"bonus":40},{"id":"termine_betrieb_20","label":"20 Termine im Betrieb","threshold":20,"bonus":80},{"id":"termine_betrieb_30","label":"30 Termine im Betrieb","threshold":30,"title":"Vor-Ort-Legende","bonus":150}],"type":"ladder"},{"category":"Termine","id":"kanal_spezialist","label":"Der Kanal-Spezialist","requires":["termine_online_50","termine_buero_45","termine_betrieb_30"],"requiresMode":"any","title":"Der Kanal-Spezialist","type":"epic","bonus":150},{"category":"Konstanz","id":"telefon_serie","label":"Telefonakquise-Serie","metric":{"action":"telefon_5","perEntryQty":5,"period":"daily"},"stages":[{"id":"telefon_serie_10","label":"20 Tage in Folge ≥10 Nummern gewählt","perPeriodThreshold":10,"streakTarget":20,"bonus":80},{"id":"telefon_serie_20","label":"20 Tage in Folge ≥20 Nummern gewählt","perPeriodThreshold":20,"streakTarget":20,"title":"Telefon-Champion","bonus":200}],"type":"streak"},{"category":"Konstanz","id":"termine_serie","label":"Termine-Serie","metric":{"action":"termin_wahrgenommen","period":"weekly"},"stages":[{"id":"termine_serie_5_4","label":"4 Wochen in Folge ≥5 Termine wahrgenommen","perPeriodThreshold":5,"streakTarget":4,"bonus":60},{"id":"termine_serie_5_8","label":"8 Wochen in Folge ≥5 Termine wahrgenommen","perPeriodThreshold":5,"streakTarget":8,"bonus":120},{"id":"termine_serie_7_4","label":"4 Wochen in Folge ≥7 Termine wahrgenommen","perPeriodThreshold":7,"streakTarget":4,"bonus":150},{"id":"termine_serie_7_8","label":"8 Wochen in Folge ≥7 Termine wahrgenommen","perPeriodThreshold":7,"streakTarget":8,"bonus":250}],"type":"streak"},{"category":"Sachsparte","id":"sach_haftpflicht","label":"Haftpflicht-Jahresbeitrag","metric":{"productArt":"SH","productSubcategory":"Haftpflicht","source":"sales"},"stages":[{"id":"sach_1000","label":"1000 Euro Haftpflicht p.a.","threshold":1000,"bonus":30},{"id":"sach_5000","label":"5000 Euro Haftpflicht p.a.","threshold":5000,"bonus":60},{"id":"sach_10000","label":"10000 Euro Haftpflicht p.a.","threshold":10000,"bonus":100},{"id":"sach_15000","label":"15000 Euro Haftpflicht p.a.","threshold":15000,"bonus":150},{"id":"sach_20000","label":"20000 Euro Haftpflicht p.a.","threshold":20000,"bonus":220},{"id":"sach_30000","label":"30000 Euro Haftpflicht p.a.","threshold":30000,"bonus":320},{"id":"sach_50000","label":"50000 Euro Haftpflicht p.a.","threshold":50000,"title":"Schutzschild-Meister","bonus":450}],"type":"ladder"},{"category":"Sachsparte","id":"sachexperte","label":"Sachexperte","requires":["sach_50000"],"requiresMode":"all","title":"Sachexperte","type":"epic","bonus":100},{"category":"Lebensparte","id":"leben_bws","label":"Bewertungssumme (Leben)","metric":{"productArt":"LV","source":"sales"},"stages":[{"id":"leben_1","label":"1 Mio Euro Leben-BWS","threshold":1000000,"bonus":30},{"id":"leben_1_5","label":"1,5 Mio Euro Leben-BWS","threshold":1500000,"bonus":60},{"id":"leben_2","label":"2 Mio Euro Leben-BWS","threshold":2000000,"bonus":100},{"id":"leben_2_5","label":"2,5 Mio Euro Leben-BWS","threshold":2500000,"bonus":150},{"id":"leben_3","label":"3 Mio Euro Leben-BWS","threshold":3000000,"bonus":220},{"id":"leben_4","label":"4 Mio Euro Leben-BWS","threshold":4000000,"bonus":320},{"id":"leben_5","label":"5 Mio Euro Leben-BWS","threshold":5000000,"title":"Vorsorge-Legende","bonus":450}],"type":"ladder"},{"category":"Lebensparte","id":"lebenexperte","label":"Lebenexperte","requires":["leben_5"],"requiresMode":"all","title":"Lebenexperte","type":"epic","bonus":100},{"category":"Krankensparte","id":"kranken_beitrag","label":"Kranken-Beitrag","metric":{"productArt":"KV","source":"sales"},"stages":[{"id":"kranken_3000","label":"3000 Euro Kranken-Beitrag","threshold":3000,"bonus":30},{"id":"kranken_5000","label":"5000 Euro Kranken-Beitrag","threshold":5000,"bonus":60},{"id":"kranken_7500","label":"7500 Euro Kranken-Beitrag","threshold":7500,"bonus":100},{"id":"kranken_10000","label":"10000 Euro Kranken-Beitrag","threshold":10000,"bonus":150},{"id":"kranken_15000","label":"15000 Euro Kranken-Beitrag","threshold":15000,"bonus":220},{"id":"kranken_20000","label":"20000 Euro Kranken-Beitrag","threshold":20000,"bonus":320},{"id":"kranken_25000","label":"25000 Euro Kranken-Beitrag","threshold":25000,"title":"Gesundheitswächter","bonus":450}],"type":"ladder"},{"category":"Krankensparte","id":"krankenexperte","label":"Krankenexperte","requires":["kranken_25000"],"requiresMode":"all","title":"Krankenexperte","type":"epic","bonus":100},{"category":"Finanzierung","id":"fin_darlehen","label":"Darlehensvolumen","metric":{"productArt":"D","source":"sales"},"stages":[{"id":"fin_300k","label":"300000 Euro Darlehensvolumen","threshold":300000,"bonus":30},{"id":"fin_500k","label":"500000 Euro Darlehensvolumen","threshold":500000,"bonus":60},{"id":"fin_750k","label":"750000 Euro Darlehensvolumen","threshold":750000,"bonus":100},{"id":"fin_1m","label":"1 Mio Euro Darlehensvolumen","threshold":1000000,"bonus":150},{"id":"fin_1_25m","label":"1,25 Mio Euro Darlehensvolumen","threshold":1250000,"bonus":220},{"id":"fin_1_5m","label":"1,5 Mio Euro Darlehensvolumen","threshold":1500000,"bonus":320},{"id":"fin_2m","label":"2 Mio Euro Darlehensvolumen","threshold":2000000,"title":"Baumeister der Zukunft","bonus":450}],"type":"ladder"},{"category":"Abschlüsse","id":"rundum_versorgung","label":"Die Rundum-Versorgung","requires":["sach_50000","leben_5","kranken_25000","fin_2m"],"requiresMode":"all","title":"Der Allrounder","type":"epic","bonus":800},{"category":"Krankenhausakquise","id":"kh_festungsherr","label":"Das Krankenhaus komplett absichern","requires":["kh_gaenge_10","sach_50000","termine_betrieb_30"],"requiresMode":"all","title":"Festungsherr","type":"epic","bonus":500},{"category":"Krankenhausakquise","id":"kh_gebietsherrscher","label":"Mehrfacher Festungsherr","requires":["kh_breite_10in2","sach_50000","termine_betrieb_30"],"requiresMode":"all","title":"Der Gebietsherrscher","type":"epic","bonus":700},{"category":"Krankenhausakquise","id":"kh_abschluss_tiefe","label":"Abschlüsse im selben Krankenhaus","metric":{"action":"abschluss","aggregate":"maxPerGroup","groupBy":"location_id","locationType":"krankenhaus"},"stages":[{"bonus":50,"id":"kh_abschluss_tiefe_3","label":"3 Abschlüsse im selben Krankenhaus","threshold":3}],"type":"ladder"},{"category":"Krankenhausakquise","id":"kh_abschluss_breite","label":"Abschlüsse in verschiedenen Krankenhäusern","metric":{"action":"abschluss","aggregate":"groupsAtLeast","groupBy":"location_id","locationType":"krankenhaus"},"stages":[{"bonus":100,"id":"kh_abschluss_breite_3","label":"Abschlüsse in 3 verschiedenen Krankenhäusern","minGroups":3,"minPerGroup":1}],"type":"ladder"}]$qtree$::jsonb),
  '{levelBase}',
  '5.80'::jsonb
)
where org_id = '00000000-0000-0000-0000-000000000001';

insert into public.schema_patches (patch_number, title) values
  (50, 'Questbaum: Jahres-Reset + Bonus-XP fuer den gesamten Baum, Level-Kurve neu kalibriert')
on conflict (patch_number) do nothing;
