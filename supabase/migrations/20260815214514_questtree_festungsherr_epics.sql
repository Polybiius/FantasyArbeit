-- ============================================================
-- Questbaum-Übersetzung, Phase 1, vierter Schritt: die zwei letzten
-- noch fehlenden Epics aus Questbaum.canvas -- "Das Krankenhaus
-- komplett absichern" 🏅 "Festungsherr" und "Mehrfacher Festungsherr"
-- 🏅 "Der Gebietsherrscher". Beide waren bewusst aus dem
-- Krankenhausakquise-Pilot (20260812194711) ausgeklammert, weil sie
-- Sachsparte-/Termine-Betrieb-Daten brauchten, die erst mit den beiden
-- Migrationen vom 2026-08-13 (Termine-Kanal) und 2026-08-15
-- (Abschlüsse-Sparten) übersetzt wurden -- beide sind seit heute live,
-- damit ist dieser Nachtrag jetzt vollständig baubar.
--
-- "Das Krankenhaus komplett absichern": laut Questbaum.canvas drei
-- Vorbedingungen aus drei verschiedenen Ästen (requiresMode:"all"):
-- kh_gaenge_10 (10+ im selben Krankenhaus), sach_50000 (50000 Euro
-- Haftpflicht p.a.), termine_betrieb_30 (30 Termine im Betrieb).
--
-- "Mehrfacher Festungsherr": Canvas-Text ("'Festungsherr'-Status in
-- ZWEI verschiedenen Krankenhäusern erreicht") lässt sich mit dem
-- bestehenden Schema nicht direkt als "Epic hängt von einem anderen
-- Epic ab" ausdrücken -- questTreeEvaluateChain()/stageDoneMap werten
-- bewusst nur ladder/ratio/streak aus, Epics selbst tragen nie einen
-- eigenen Eintrag in stageDoneMap (siehe project_questbaum_schema_design).
-- Stattdessen wird die "in zwei Krankenhäusern"-Bedingung direkt über
-- die bereits vorhandene Breiten-Leiter (kh_breite, groupsAtLeast)
-- ausgedrückt: eine neue Zwischenstufe kh_breite_10in2 (10+ Ansprachen
-- in mindestens 2 verschiedenen Krankenhäusern, zwischen den
-- bestehenden Stufen 3in3 und 10in5 einsortiert -- 3×3=9,10×2=20,
-- 10×5=50 Personen-Besuche, damit eine plausibel aufsteigende Leiter).
-- Die Epic selbst verlangt dann kh_breite_10in2 + dieselben zwei
-- org-weiten Kriterien wie beim ersten Festungsherr (sach_50000,
-- termine_betrieb_30) -- inhaltlich exakt dieselbe Bedingung wie
-- "Festungsherr-Status in zwei Krankenhäusern", nur ohne die (aktuell
-- nicht unterstützte) Epic-von-Epic-Verkettung zu brauchen.
-- ============================================================

update public.rule_configs
set config = jsonb_set(
  config,
  '{questTree}',
  (
    select jsonb_agg(
      case
        when elem->>'id' = 'kh_breite' then
          jsonb_set(elem, '{stages}', '[
            { "id": "kh_breite_3in3", "minPerGroup": 3, "minGroups": 3, "label": "3* in 3 verschiedenen Krankenhäusern" },
            { "id": "kh_breite_10in2", "minPerGroup": 10, "minGroups": 2, "label": "10* in 2 verschiedenen Krankenhäusern" },
            { "id": "kh_breite_10in5", "minPerGroup": 10, "minGroups": 5, "label": "10* in 5 verschiedenen Krankenhäusern", "title": "Der Netzwerker" }
          ]'::jsonb)
        else elem
      end
    )
    from jsonb_array_elements(config->'questTree') elem
  ) || '[
    {
      "id": "kh_festungsherr",
      "type": "epic",
      "category": "Krankenhausakquise",
      "label": "Das Krankenhaus komplett absichern",
      "requires": ["kh_gaenge_10", "sach_50000", "termine_betrieb_30"],
      "requiresMode": "all",
      "title": "Festungsherr"
    },
    {
      "id": "kh_gebietsherrscher",
      "type": "epic",
      "category": "Krankenhausakquise",
      "label": "Mehrfacher Festungsherr",
      "requires": ["kh_breite_10in2", "sach_50000", "termine_betrieb_30"],
      "requiresMode": "all",
      "title": "Der Gebietsherrscher"
    }
  ]'::jsonb
)
where org_id = '00000000-0000-0000-0000-000000000001';
