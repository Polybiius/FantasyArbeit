-- ============================================================
-- Questbaum-Übersetzung, Phase 1, zweiter Schritt: Kundenausbau,
-- Empfehlungsmanagement, Meisterschaft (Erschein-/Abschluss-/Erreichquote)
--
-- Reine Regelwerk-Konfiguration (rule_configs.config.questTree), kein
-- Schema betroffen. Hängt an den drei kleinen, additiven Erweiterungen der
-- Auswertungsfunktionen in index.html (dieselbe Session):
--   - metric.groupBy darf jetzt auch "month"/"year" sein (virtueller
--     Gruppierungsschlüssel aus created_at statt einer echten Spalte) -
--     bildet "bester Monat/bestes Jahr bisher" ab, exakt wie kh_gaenge
--     "bestes Krankenhaus bisher" abbildet, nur mit Zeit statt Ort als
--     Gruppe.
--   - metric.numerator/denominator dürfen jetzt auch ein Array von
--     Aktions-Schlüsseln sein (Summe statt einer einzelnen Aktion) - nötig
--     für Quoten, bei denen es keine einzelne "es gab eine Gelegenheit"-
--     Aktion gibt, nur zwei sich ausschließende Ausgänge.
--   - epic.requiresMode darf jetzt auch eine Zahl sein ("mindestens N von
--     den genannten Voraussetzungen"), nicht nur 'all'/'any'.
-- Alle drei bleiben feste, im Code ausgewertete Optionen - keine neue
-- Escape-Hatch, siehe Grenze in project_questbaum_schema_design.
--
-- Bewusst NUR diese drei Äste (siehe CLAUDE.md/Erinnerung für den
-- vollständigen Stand). Bewusst NOCH NICHT übersetzt, echte Blocker:
--   - Sachsparte/Lebensparte/Krankensparte/Finanzierung: brauchen eine
--     komplett neue Metrik-Quelle (kumulierte Summe aus sales.
--     bewertungssumme/laufender_beitrag je Produktkategorie und Jahr,
--     nicht action_log-Zählung) - größere Erweiterung, noch nicht gebaut.
--   - Termine (Online/Büro/Im Betrieb): termine.kanal ist im action_log
--     nirgends mitgeloggt, keine Filterung nach Kanal möglich, bis das
--     nachgezogen wird.
--   - Telefonakquise-Serien/Termine-Serien-Ketten (20 Tage x N Nummern,
--     5/7 Termine über X Wochen): bräuchten einen fünften Quest-Typ
--     "Streak" (Kernlogik existiert bereits in computeDailyThresholdStreak/
--     computeWeeklyThresholdStreak für die "Konstanz"-Kachel, aber noch
--     nicht in die Questbaum-Engine übernommen).
--   - Gildenleben: bekannter, bereits dokumentierter Bedarf an einem
--     vierten/fünften Quest-Typ (Team-Aggregation über Gildenmitglieder).
--   - §34-Zertifikate: auf ausdrücklichen Nutzerwunsch zurückgestellt
--     ("vergiss das erst mal").
-- Drei Epics, die NUR von den hier neu übersetzten Ästen abhängen, sind
-- deshalb schon mit dabei ("Der Kundenpfleger", "Der Vertrauens-Makler",
-- "Meisterschafts-Schwerpunkt") - die übrigen vier Epics aus dem
-- Obsidian-Baum bleiben blockiert, bis ihre jeweiligen Voraussetzungs-Äste
-- übersetzt sind.
--
-- || statt jsonb_set-Ersetzung, damit der bestehende Krankenhausakquise-
-- Pilot (Migration 20260812194711) erhalten bleibt, nicht überschrieben wird.
-- ============================================================

update public.rule_configs
set config = jsonb_set(config, '{questTree}', (config->'questTree') || '[
  {
    "id": "ausbau_eigen",
    "type": "ladder",
    "category": "Kundenausbau",
    "label": "Eigenausbau",
    "metric": { "action": "abschluss", "aggregate": "maxPerGroup", "groupBy": "month" },
    "stages": [
      { "id": "ausbau_eigen_3", "threshold": 3, "label": "3 Kunden im Monat" },
      { "id": "ausbau_eigen_4", "threshold": 4, "label": "4 Kunden im Monat" },
      { "id": "ausbau_eigen_5", "threshold": 5, "label": "5 Kunden im Monat", "title": "Beziehungsbauer" }
    ]
  },
  {
    "id": "ausbau_bestand",
    "type": "ladder",
    "category": "Kundenausbau",
    "label": "Bestandskundenausbau",
    "metric": { "action": "kundenausbau", "aggregate": "maxPerGroup", "groupBy": "year" },
    "stages": [
      { "id": "ausbau_bestand_3", "threshold": 3, "label": "3 Bestandskunden im Jahr" },
      { "id": "ausbau_bestand_4", "threshold": 4, "label": "4 Bestandskunden im Jahr" },
      { "id": "ausbau_bestand_5", "threshold": 5, "label": "5 Bestandskunden im Jahr" },
      { "id": "ausbau_bestand_6", "threshold": 6, "label": "6 Bestandskunden im Jahr", "title": "Bestandspfleger" }
    ]
  },
  {
    "id": "kundenpfleger",
    "type": "epic",
    "category": "Kundenausbau",
    "label": "Der Kundenpfleger",
    "requires": ["ausbau_eigen_5", "ausbau_bestand_6"],
    "requiresMode": "any",
    "title": "Der Kundenpfleger"
  },
  {
    "id": "empfehlung_kette",
    "type": "ladder",
    "category": "Empfehlungsmanagement",
    "label": "Empfehlungsmanagement",
    "metric": { "action": "empfehlung", "aggregate": "maxPerGroup", "groupBy": "month" },
    "stages": [
      { "id": "empfehlung_1", "threshold": 1, "label": "1 Empfehlung im Monat" },
      { "id": "empfehlung_2", "threshold": 2, "label": "2 Empfehlungen im Monat" },
      { "id": "empfehlung_3", "threshold": 3, "label": "3 Empfehlungen im Monat" },
      { "id": "empfehlung_5", "threshold": 5, "label": "5 Empfehlungen im Monat", "title": "Vertrauensperson" }
    ]
  },
  {
    "id": "vertrauensmakler",
    "type": "epic",
    "category": "Empfehlungsmanagement",
    "label": "Der Vertrauens-Makler",
    "requires": ["empfehlung_5", "ausbau_bestand_6"],
    "requiresMode": "all",
    "title": "Der Vertraute"
  },
  {
    "id": "meister_erschein",
    "type": "ratio",
    "category": "Meisterschaft",
    "label": "Erscheinquote (Termine)",
    "metric": { "numerator": "termin_wahrgenommen", "denominator": ["termin_wahrgenommen", "termin_nicht_wahrgenommen"] },
    "window": 20,
    "stages": [
      { "id": "meister_erschein_65", "threshold": 65, "label": "65% Erscheinquote" },
      { "id": "meister_erschein_75", "threshold": 75, "label": "75% Erscheinquote" },
      { "id": "meister_erschein_85", "threshold": 85, "label": "85% Erscheinquote", "title": "Der Verlässliche" }
    ]
  },
  {
    "id": "meister_abschluss",
    "type": "ratio",
    "category": "Meisterschaft",
    "label": "Abschlussquote (Pitch → Abschluss)",
    "metric": { "numerator": "abschluss", "denominator": "pitch" },
    "window": 15,
    "stages": [
      { "id": "meister_abschluss_20", "threshold": 20, "label": "20% Abschlussquote" },
      { "id": "meister_abschluss_30", "threshold": 30, "label": "30% Abschlussquote" },
      { "id": "meister_abschluss_40", "threshold": 40, "label": "40% Abschlussquote", "title": "Der Closer" }
    ]
  },
  {
    "id": "meister_erreich",
    "type": "ratio",
    "category": "Meisterschaft",
    "label": "Erreichquote (Anrufe)",
    "metric": { "numerator": "anruf_erreicht", "denominator": ["anruf_erreicht", "anruf_nicht_erreicht"] },
    "window": 30,
    "stages": [
      { "id": "meister_erreich_40", "threshold": 40, "label": "40% Erreichquote" },
      { "id": "meister_erreich_55", "threshold": 55, "label": "55% Erreichquote" },
      { "id": "meister_erreich_70", "threshold": 70, "label": "70% Erreichquote", "title": "Der Draht zu den Menschen" }
    ]
  },
  {
    "id": "meisterschaft_schwerpunkt",
    "type": "epic",
    "category": "Meisterschaft",
    "label": "Meisterschafts-Schwerpunkt",
    "requires": ["meister_erschein_85", "meister_abschluss_40", "meister_erreich_70"],
    "requiresMode": 2,
    "title": "Meisterschafts-Schwerpunkt"
  }
]'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';
