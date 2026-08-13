-- ============================================================
-- Questbaum-Übersetzung, Phase 1, dritter Schritt: Termine nach Kanal
--
-- Reine Regelwerk-Konfiguration (rule_configs.config.questTree), kein
-- Schema betroffen. Hängt an einer neuen Fähigkeit der Engine (dieselbe
-- Session): action_log.meta.kanal wird jetzt beim Loggen von
-- termin_vereinbart mitgeschrieben, wenn der Kanal an der jeweiligen
-- Logging-Stelle bekannt ist (createLeadAndLogTerminVereinbart direkt,
-- moveKanbanCard per Nachtrag über attachKanalToLoggedAction, sobald
-- promptKanbanTermin den Kanal geliefert hat). Neue Metrik-Option
-- metric.kanal filtert bei ladder-Quests zusätzlich auf diesen Wert
-- (questMatchesKanal, analog zu questMatchesLocationType).
--
-- Bewusst NUR auf termin_vereinbart gebaut, nicht auf termin_wahrgenommen:
-- Letzteres hat im bestehenden Code keine verlässliche, eindeutige
-- Verknüpfung zu einem konkreten Termin-Datensatz (nur eine von vier
-- optionalen Aktionen im "Dauerbrenner"-Popup, ohne Termin-Bezug im
-- Scope) - eine Kanal-Zuordnung dafür wäre geraten, nicht abgeleitet.
-- "Termine nach Kanal" zählt deshalb vereinbarte, nicht zwingend
-- wahrgenommene Termine - näher an "wie viel Aktivität pro Kanal" als an
-- "wie viele erfolgreiche Treffen pro Kanal".
--
-- Wie bei Kundenausbau: "X Termine im Jahr" wird über groupBy:"year" als
-- "bestes Jahr bisher" abgebildet (siehe Erinnerung
-- reference_obsidian_vault_questbaum: "kumulierte Terminanzahl pro Jahr").
--
-- Zweittermine bleiben bewusst außen vor (loggen "pitch", nicht
-- termin_vereinbart, keine Kanal-Erfassung dafür verdrahtet) - ließe sich
-- bei Bedarf separat ergänzen.
--
-- Weiterhin blockiert, siehe vorherige Migrationen/Erinnerung:
-- Sachsparte/Lebensparte/Krankensparte/Finanzierung (sales-Summen-Metrik),
-- Telefonakquise-/Termine-Serien-Ketten (Streak-Typ), Gildenleben
-- (Team-Aggregation), §34-Zertifikate (zurückgestellt).
-- ============================================================

update public.rule_configs
set config = jsonb_set(config, '{questTree}', (config->'questTree') || '[
  {
    "id": "termine_online",
    "type": "ladder",
    "category": "Termine",
    "label": "Termine Online",
    "metric": { "action": "termin_vereinbart", "kanal": "online", "aggregate": "maxPerGroup", "groupBy": "year" },
    "stages": [
      { "id": "termine_online_10", "threshold": 10, "label": "10 Termine Online" },
      { "id": "termine_online_20", "threshold": 20, "label": "20 Termine Online" },
      { "id": "termine_online_35", "threshold": 35, "label": "35 Termine Online" },
      { "id": "termine_online_50", "threshold": 50, "label": "50 Termine Online", "title": "Digital-Profi" }
    ]
  },
  {
    "id": "termine_buero",
    "type": "ladder",
    "category": "Termine",
    "label": "Termine im Büro",
    "metric": { "action": "termin_vereinbart", "kanal": "buero", "aggregate": "maxPerGroup", "groupBy": "year" },
    "stages": [
      { "id": "termine_buero_8", "threshold": 8, "label": "8 Termine im Büro" },
      { "id": "termine_buero_18", "threshold": 18, "label": "18 Termine im Büro" },
      { "id": "termine_buero_30", "threshold": 30, "label": "30 Termine im Büro" },
      { "id": "termine_buero_45", "threshold": 45, "label": "45 Termine im Büro", "title": "Gastgeber" }
    ]
  },
  {
    "id": "termine_betrieb",
    "type": "ladder",
    "category": "Termine",
    "label": "Termine im Betrieb",
    "metric": { "action": "termin_vereinbart", "kanal": "betrieb", "aggregate": "maxPerGroup", "groupBy": "year" },
    "stages": [
      { "id": "termine_betrieb_5", "threshold": 5, "label": "5 Termine im Betrieb" },
      { "id": "termine_betrieb_12", "threshold": 12, "label": "12 Termine im Betrieb" },
      { "id": "termine_betrieb_20", "threshold": 20, "label": "20 Termine im Betrieb" },
      { "id": "termine_betrieb_30", "threshold": 30, "label": "30 Termine im Betrieb", "title": "Vor-Ort-Legende" }
    ]
  },
  {
    "id": "kanal_spezialist",
    "type": "epic",
    "category": "Termine",
    "label": "Der Kanal-Spezialist",
    "requires": ["termine_online_50", "termine_buero_45", "termine_betrieb_30"],
    "requiresMode": "any",
    "title": "Der Kanal-Spezialist"
  }
]'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';
