-- ============================================================
-- Questbaum-Übersetzung, Phase 1, dritter Schritt: die vier
-- "Abschlüsse"-Sparten (Sachsparte/Lebensparte/Krankensparte/
-- Finanzierung) -- der zuletzt verbliebene große Block, siehe
-- project_roadmap_prioritaeten/project_questbaum_schema_design.
--
-- Zwei Blocker aus den Vorgänger-Migrationen sind geklärt:
-- 1. Metrik-Quelle: neue evaluateSalesLadderQuest()-Funktion in
--    index.html (metric.source:'sales') summiert kumuliert
--    saleBasisValue() aus mySalesCache, gefiltert auf eine feste
--    products.art (+ optional products.subcategory) -- kein neuer
--    Aggregat-Typ, immer eine reine Summe. Fester, im Code
--    ausgewerteter Metrik-Quellen-Typ, keine neue Escape-Hatch
--    (siehe Grenze in project_questbaum_schema_design).
-- 2. Kategorie-Zuordnung: seit dem Provisions-Rework (2026-08-14)
--    läuft jedes Produkt über eine feste "Art" (PRODUCT_ART_CONFIG
--    in index.html) -- Sachsparte zielt bewusst NICHT auf die ganze
--    Art "SH" (Sach/Hausrat), sondern zusätzlich auf
--    products.subcategory='Haftpflicht' (Nutzerentscheidung
--    2026-08-15: Haftpflicht ist im Ärztesegment "wirklich
--    wichtig", soll aber nicht als eigene Art/Berechnung
--    abgespalten werden -- die Provisions-/BWP-Mathematik bleibt
--    bei SH vereinheitlicht, die Fokus-Sparte lebt als freies
--    Unterkategorie-Tag am Produkt). Lebensparte/Krankensparte/
--    Finanzierung zielen direkt auf die ganze Art (LV/KV/D).
--
-- Darlehen (Art "D") ist bewusst NUR EIN Feld, nicht D+DP getrennt
-- wie in der Original-Excel (Nutzerentscheidung 2026-08-15: "wir
-- brauchen diese Besonderheit mit der apoBank nicht") -- Faktoren
-- sind die Basis-"D"-Werte (Darlehen APO), keine
-- Plattform-Variante.
--
-- Vier neue Ladder-Ketten, je ihre eigene Kategorie/Zunftbuch-Reiter
-- (Sachsparte/Lebensparte/Krankensparte/Finanzierung -- passt zur
-- Struktur in Questbaum.canvas, wo jede Sparte ein eigener
-- Top-Level-Ast unter "Abschlüsse" ist), Werte 1:1 aus
-- Questbaum.canvas übernommen. Dazu drei Ein-Sparten-Epics
-- (Sachexperte/Lebenexperte/Krankenexperte -- bewusst OHNE
-- Finanzierungs-Pendant, siehe reference_obsidian_vault_questbaum)
-- und die Vier-Sparten-Epic "Die Rundum-Versorgung" (eigene neue
-- Kategorie "Abschlüsse", da sie zu keiner einzelnen Sparte gehört).
--
-- Bewusst weiterhin blockiert (siehe project_questbaum_schema_design):
-- "Das Krankenhaus komplett absichern"/"Mehrfacher Festungsherr"
-- (brauchen zusätzlich Termine-Betrieb-Daten aus der Termine-Kanal-
-- Migration 20260813195101, die noch nicht gepusht ist).
--
-- || statt jsonb_set-Ersetzung, damit die bisherigen questTree-
-- Einträge erhalten bleiben, nicht überschrieben werden.
-- ============================================================

update public.rule_configs
set config = jsonb_set(config, '{questTree}', (config->'questTree') || '[
  {
    "id": "sach_haftpflicht",
    "type": "ladder",
    "category": "Sachsparte",
    "label": "Haftpflicht-Jahresbeitrag",
    "metric": { "source": "sales", "productArt": "SH", "productSubcategory": "Haftpflicht" },
    "stages": [
      { "id": "sach_1000", "threshold": 1000, "label": "1000 Euro Haftpflicht p.a." },
      { "id": "sach_5000", "threshold": 5000, "label": "5000 Euro Haftpflicht p.a." },
      { "id": "sach_10000", "threshold": 10000, "label": "10000 Euro Haftpflicht p.a." },
      { "id": "sach_15000", "threshold": 15000, "label": "15000 Euro Haftpflicht p.a." },
      { "id": "sach_20000", "threshold": 20000, "label": "20000 Euro Haftpflicht p.a." },
      { "id": "sach_30000", "threshold": 30000, "label": "30000 Euro Haftpflicht p.a." },
      { "id": "sach_50000", "threshold": 50000, "label": "50000 Euro Haftpflicht p.a.", "title": "Schutzschild-Meister" }
    ]
  },
  {
    "id": "sachexperte",
    "type": "epic",
    "category": "Sachsparte",
    "label": "Sachexperte",
    "requires": ["sach_50000"],
    "requiresMode": "all",
    "title": "Sachexperte"
  },
  {
    "id": "leben_bws",
    "type": "ladder",
    "category": "Lebensparte",
    "label": "Bewertungssumme (Leben)",
    "metric": { "source": "sales", "productArt": "LV" },
    "stages": [
      { "id": "leben_1", "threshold": 1000000, "label": "1 Mio Euro Leben-BWS" },
      { "id": "leben_1_5", "threshold": 1500000, "label": "1,5 Mio Euro Leben-BWS" },
      { "id": "leben_2", "threshold": 2000000, "label": "2 Mio Euro Leben-BWS" },
      { "id": "leben_2_5", "threshold": 2500000, "label": "2,5 Mio Euro Leben-BWS" },
      { "id": "leben_3", "threshold": 3000000, "label": "3 Mio Euro Leben-BWS" },
      { "id": "leben_4", "threshold": 4000000, "label": "4 Mio Euro Leben-BWS" },
      { "id": "leben_5", "threshold": 5000000, "label": "5 Mio Euro Leben-BWS", "title": "Vorsorge-Legende" }
    ]
  },
  {
    "id": "lebenexperte",
    "type": "epic",
    "category": "Lebensparte",
    "label": "Lebenexperte",
    "requires": ["leben_5"],
    "requiresMode": "all",
    "title": "Lebenexperte"
  },
  {
    "id": "kranken_beitrag",
    "type": "ladder",
    "category": "Krankensparte",
    "label": "Kranken-Beitrag",
    "metric": { "source": "sales", "productArt": "KV" },
    "stages": [
      { "id": "kranken_3000", "threshold": 3000, "label": "3000 Euro Kranken-Beitrag" },
      { "id": "kranken_5000", "threshold": 5000, "label": "5000 Euro Kranken-Beitrag" },
      { "id": "kranken_7500", "threshold": 7500, "label": "7500 Euro Kranken-Beitrag" },
      { "id": "kranken_10000", "threshold": 10000, "label": "10000 Euro Kranken-Beitrag" },
      { "id": "kranken_15000", "threshold": 15000, "label": "15000 Euro Kranken-Beitrag" },
      { "id": "kranken_20000", "threshold": 20000, "label": "20000 Euro Kranken-Beitrag" },
      { "id": "kranken_25000", "threshold": 25000, "label": "25000 Euro Kranken-Beitrag", "title": "Gesundheitswächter" }
    ]
  },
  {
    "id": "krankenexperte",
    "type": "epic",
    "category": "Krankensparte",
    "label": "Krankenexperte",
    "requires": ["kranken_25000"],
    "requiresMode": "all",
    "title": "Krankenexperte"
  },
  {
    "id": "fin_darlehen",
    "type": "ladder",
    "category": "Finanzierung",
    "label": "Darlehensvolumen",
    "metric": { "source": "sales", "productArt": "D" },
    "stages": [
      { "id": "fin_300k", "threshold": 300000, "label": "300000 Euro Darlehensvolumen" },
      { "id": "fin_500k", "threshold": 500000, "label": "500000 Euro Darlehensvolumen" },
      { "id": "fin_750k", "threshold": 750000, "label": "750000 Euro Darlehensvolumen" },
      { "id": "fin_1m", "threshold": 1000000, "label": "1 Mio Euro Darlehensvolumen" },
      { "id": "fin_1_25m", "threshold": 1250000, "label": "1,25 Mio Euro Darlehensvolumen" },
      { "id": "fin_1_5m", "threshold": 1500000, "label": "1,5 Mio Euro Darlehensvolumen" },
      { "id": "fin_2m", "threshold": 2000000, "label": "2 Mio Euro Darlehensvolumen", "title": "Baumeister der Zukunft" }
    ]
  },
  {
    "id": "rundum_versorgung",
    "type": "epic",
    "category": "Abschlüsse",
    "label": "Die Rundum-Versorgung",
    "requires": ["sach_50000", "leben_5", "kranken_25000", "fin_2m"],
    "requiresMode": "all",
    "title": "Der Allrounder"
  }
]'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';
