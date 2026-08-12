-- ============================================================
-- Questbaum-Übersetzung, Phase 1, Pilot: Krankenhausakquise
--
-- Reine Regelwerk-Konfiguration (rule_configs.config.questTree), kein
-- Schema betroffen - index.html bekommt dafür die Auswertungsfunktionen
-- evaluateLadderQuest()/evaluateHabitQuest()/evaluateRatioQuest()/
-- evaluateEpicQuest() (bereits committet, noch ohne UI-Anbindung).
--
-- Bewusst NUR Krankenhausakquise, bewusst OHNE Bonus-XP (reine Titel-/
-- Recognition-Schicht, siehe Nutzerentscheidung 2026-08-12 - vermeidet
-- eine Neukalibrierung der Level-Kurve für diesen Schritt). Die beiden
-- Epics "Festungsherr"/"Mehrfacher Festungsherr" aus dem Obsidian-Baum
-- fehlen hier bewusst, da sie Sachsparte/Termine-Betrieb-Daten brauchen,
-- die noch nicht übersetzt sind - kommen mit der jeweiligen Sparte.
-- ============================================================

update public.rule_configs
set config = jsonb_set(config, '{questTree}', '[
  {
    "id": "kh_gaenge",
    "type": "ladder",
    "category": "Krankenhausakquise",
    "label": "Gänge ins selbe Krankenhaus",
    "metric": { "action": "ansprache", "locationType": "krankenhaus", "aggregate": "maxPerGroup", "groupBy": "location_id" },
    "stages": [
      { "id": "kh_gaenge_1", "threshold": 1, "label": "Der erste Schritt" },
      { "id": "kh_gaenge_3", "threshold": 3, "label": "3 Gänge ins selbe Krankenhaus" },
      { "id": "kh_gaenge_6", "threshold": 6, "label": "6 Gänge ins selbe Krankenhaus", "title": "Der Stammgast" },
      { "id": "kh_gaenge_10", "threshold": 10, "label": "10+ im selben Krankenhaus", "title": "Krankenhaus-Legende" }
    ]
  },
  {
    "id": "kh_habit_1",
    "type": "habit",
    "category": "Krankenhausakquise",
    "label": "1 Krankenhausbesuch pro Woche",
    "metric": { "action": "ansprache", "locationType": "krankenhaus" },
    "period": "weekly",
    "threshold": 1
  },
  {
    "id": "kh_habit_2",
    "type": "habit",
    "category": "Krankenhausakquise",
    "label": "2 Krankenhausbesuche pro Woche",
    "metric": { "action": "ansprache", "locationType": "krankenhaus" },
    "period": "weekly",
    "threshold": 2
  },
  {
    "id": "kh_breite",
    "type": "ladder",
    "category": "Krankenhausakquise",
    "label": "Verschiedene Krankenhäuser",
    "metric": { "action": "ansprache", "locationType": "krankenhaus", "aggregate": "groupsAtLeast", "groupBy": "location_id" },
    "stages": [
      { "id": "kh_breite_3in3", "minPerGroup": 3, "minGroups": 3, "label": "3* in 3 verschiedenen Krankenhäusern" },
      { "id": "kh_breite_10in5", "minPerGroup": 10, "minGroups": 5, "label": "10* in 5 verschiedenen Krankenhäusern", "title": "Der Netzwerker" }
    ]
  },
  {
    "id": "kh_tueroeffner",
    "type": "ratio",
    "category": "Krankenhausakquise",
    "label": "Türöffner-Quote",
    "metric": { "numerator": "termin_vereinbart", "denominator": "ansprache", "locationType": "krankenhaus" },
    "window": 15,
    "stages": [
      { "id": "kh_tueroeffner_20", "threshold": 20, "label": "20% Türöffner-Quote" },
      { "id": "kh_tueroeffner_40", "threshold": 40, "label": "40% Türöffner-Quote" },
      { "id": "kh_tueroeffner_60", "threshold": 60, "label": "60% Türöffner-Quote", "title": "Der Türöffner" }
    ]
  },
  {
    "id": "kh_weg",
    "type": "epic",
    "category": "Krankenhausakquise",
    "label": "Der Krankenhaus-Weg",
    "requires": ["kh_gaenge_10", "kh_breite_10in5"],
    "requiresMode": "any",
    "title": "Der Krankenhaus-Weg"
  }
]'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';
