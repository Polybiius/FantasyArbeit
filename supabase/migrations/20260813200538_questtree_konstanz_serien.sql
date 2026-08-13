-- ============================================================
-- Questbaum-Übersetzung, Phase 1, vierter Schritt: Telefonakquise-/
-- Termine-Serien ("Konstanz statt Rohvolumen")
--
-- Reine Regelwerk-Konfiguration (rule_configs.config.questTree), kein
-- Schema betroffen. Hängt am neuen fünften Quest-Typ "streak" in
-- index.html (dieselbe Session, evaluateStreakQuest()) - reiner Wrapper
-- um computeDailyThresholdStreak()/computeWeeklyThresholdStreak(), die
-- für die bestehende "Konstanz"-Kachel auf der Statistik-Seite schon
-- existieren (kein Doppelbau der Kernlogik, nur ein zweiter Verbraucher).
-- Jede Stufe trägt ihr eigenes perPeriodThreshold+streakTarget-Paar
-- (nicht nur ein wachsendes Ziel bei fixem Schwellenwert) - deckt sowohl
-- den Telefon-Fall (fixe Serienlänge 20 Tage, wachsender Tages-
-- Schwellenwert 10→20) als auch den Termine-Fall (beide Achsen wachsen
-- zugleich: 5/4 Wochen → 5/8 → 7/4 → 7/8) mit demselben Schema ab.
--
-- Werte 1:1 aus dem Obsidian-Questbaum (Questbaum.canvas) übernommen,
-- nicht neu erfunden. Kategorie "Konstanz" (neuer Zunftbuch-Reiter,
-- gleicher Sprachgebrauch wie die bestehende Konstanz-Kachel/CLAUDE.md
-- "Konstanz statt Rohvolumen").
--
-- Bewusst NICHT Teil dieses Schritts: die Epic "Der zertifizierte
-- Vollprofi" (hängt im Obsidian-Baum an der Telefon-Champion-Stufe UND an
-- §34-Zertifikaten, Letztere bleiben auf Nutzerwunsch zurückgestellt -
-- bleibt einer von weiterhin vier blockierten Obsidian-Epics, siehe
-- CLAUDE.md/Erinnerung project_questbaum_schema_design).
--
-- Weiterhin blockiert, siehe vorherige Migrationen/Erinnerung:
-- Sachsparte/Lebensparte/Krankensparte/Finanzierung (sales-Summen-Metrik,
-- products/sales in der echten DB weiterhin leer, Stand 2026-08-13),
-- Gildenleben (Team-Aggregation), §34-Zertifikate (zurückgestellt).
--
-- || statt jsonb_set-Ersetzung, damit die bestehenden Ketten (Migrationen
-- 20260812194711/20260813193529/20260813195101) erhalten bleiben, nicht
-- überschrieben werden.
-- ============================================================

update public.rule_configs
set config = jsonb_set(config, '{questTree}', (config->'questTree') || '[
  {
    "id": "telefon_serie",
    "type": "streak",
    "category": "Konstanz",
    "label": "Telefonakquise-Serie",
    "metric": { "action": "telefon_5", "perEntryQty": 5, "period": "daily" },
    "stages": [
      { "id": "telefon_serie_10", "perPeriodThreshold": 10, "streakTarget": 20, "label": "20 Tage in Folge ≥10 Nummern gewählt" },
      { "id": "telefon_serie_20", "perPeriodThreshold": 20, "streakTarget": 20, "label": "20 Tage in Folge ≥20 Nummern gewählt", "title": "Telefon-Champion" }
    ]
  },
  {
    "id": "termine_serie",
    "type": "streak",
    "category": "Konstanz",
    "label": "Termine-Serie",
    "metric": { "action": "termin_wahrgenommen", "period": "weekly" },
    "stages": [
      { "id": "termine_serie_5_4", "perPeriodThreshold": 5, "streakTarget": 4, "label": "4 Wochen in Folge ≥5 Termine wahrgenommen" },
      { "id": "termine_serie_5_8", "perPeriodThreshold": 5, "streakTarget": 8, "label": "8 Wochen in Folge ≥5 Termine wahrgenommen" },
      { "id": "termine_serie_7_4", "perPeriodThreshold": 7, "streakTarget": 4, "label": "4 Wochen in Folge ≥7 Termine wahrgenommen" },
      { "id": "termine_serie_7_8", "perPeriodThreshold": 7, "streakTarget": 8, "label": "8 Wochen in Folge ≥7 Termine wahrgenommen" }
    ]
  }
]'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';
