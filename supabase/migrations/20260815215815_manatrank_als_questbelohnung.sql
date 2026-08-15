-- ============================================================
-- Täglicher Gratis-Manatrank abgebaut, ersetzt durch eine echte
-- Quest-Belohnung: der Manatrank kommt jetzt, wenn die tägliche
-- Quest ("daily1", 3 Ansprachen + 1 Termin vereinbart) erfüllt wird,
-- statt automatisch jeden Kalendertag beim Einloggen.
--
-- grantDailyManatrank() (index.html) war laut CLAUDE.md von Anfang an
-- nur ein Bauphase-Hilfsmittel, kein finales Design -- Nutzerwunsch
-- jetzt: echte Verdienst-Kopplung an eine Quest statt geschenkter
-- Tages-Gutschrift. Die Funktion + ihr Aufruf in enterApp() sind
-- bereits aus index.html entfernt (dieselbe Session).
--
-- checkAndAwardRecurringQuests() unterstützt itemReward:{key,qty}
-- bereits seit dem Krankenhausakquise-Pilot (bisher nur ungenutzt) --
-- reine Datenänderung hier, kein Engine-Code nötig. Gleichzeitig neuer
-- Belohnungs-Toast (unten links XP, unten rechts Item) in derselben
-- Session gebaut, feuert automatisch für jede erfüllte recurringQuest
-- mit itemReward.
--
-- || + CASE-Ersetzung statt kompletter Array-Ersetzung, damit die
-- bestehende weekly1-Quest unangetastet bleibt.
-- ============================================================

update public.rule_configs
set config = jsonb_set(
  config,
  '{recurringQuests}',
  (
    select jsonb_agg(
      case
        when elem->>'id' = 'daily1' then jsonb_set(elem, '{itemReward}', '{"key":"mana_trank","qty":1}'::jsonb)
        else elem
      end
    )
    from jsonb_array_elements(config->'recurringQuests') elem
  )
)
where org_id = '00000000-0000-0000-0000-000000000001';
