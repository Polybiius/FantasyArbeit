-- PATCH: Gildenleben, Schritt 2 -- Beispiel-Team-Ziele + Bau-Rezept im
-- Regelwerk
--
-- Reine Daten-Ergänzung (kein Schema, keine Rechte-Änderung), zwei neue
-- Top-Level-Schlüssel in rule_configs.config, additiv per jsonb-Merge
-- (bestehender Inhalt bleibt unangetastet):
--
-- guildTeamQuests: die Team-Ziele selbst, gleiches Datenprinzip wie der
-- restliche Questbaum -- vorerst von Hand befüllt (siehe CLAUDE.md/
-- Konzept-Erinnerung: Self-Service-Oberfläche kommt erst mit der großen
-- Automatisierung). Bewusst FLACH (kein stages-Array wie beim
-- individuellen Ladder-Typ) -- jedes Team-Ziel ist genau eine Schwelle,
-- stage_id = quest_id (gleiche Konvention wie bei den bestehenden Epics,
-- die ihre eigene id doppelt als Erkennungsmerkmal nutzen). Beispielwerte
-- diesmal NICHT aus echten Planungszielen abgeleitet -- es gibt aktuell
-- noch keine einzige eingetragene individuelle Planung (`profiles.
-- planung_*` komplett leer, geprüft vor dem Schreiben dieser Migration) --
-- deshalb rein illustrative Rundwerte, klar als solche markiert, kein
-- echtes Geschäftsziel.
--
-- guildBuilding: das "Bau-Rezept" -- wie viele insgesamt erfüllte
-- Team-Ziel-Stufen (über ALLE Team-Ziele und Jahre hinweg,= Anzahl Zeilen
-- in guild_quest_log für diese Gilde) welche Baustufe ergeben. Reine
-- Platzhalter-Bezeichnungen/Icons, keine echte Grafik -- die kommt als
-- eigener, viel späterer Schritt.

update public.rule_configs
set config = config
  || jsonb_build_object(
    'guildTeamQuests', jsonb_build_array(
      jsonb_build_object(
        'id', 'team_leben_bws_2026',
        'label', 'Team-Ziel: Lebensversicherung (Bewertungssumme)',
        'metric', jsonb_build_object('field', 'bewertungssumme', 'category', 'Lebensversicherung'),
        'threshold', 500000,
        'note', 'Beispielwert zum Testen der Mechanik, kein echtes Geschäftsziel'
      ),
      jsonb_build_object(
        'id', 'team_beitrag_gesamt_2026',
        'label', 'Team-Ziel: Laufender Beitrag (alle Sparten)',
        'metric', jsonb_build_object('field', 'laufender_beitrag', 'category', null),
        'threshold', 5000,
        'note', 'Beispielwert zum Testen der Mechanik, kein echtes Geschäftsziel'
      )
    )
  )
  || jsonb_build_object(
    'guildBuilding', jsonb_build_object(
      'name', 'Gildenfeste',
      'tiers', jsonb_build_array(
        jsonb_build_object('partsRequired', 1, 'label', 'Kleine Hütte', 'icon', '🛖'),
        jsonb_build_object('partsRequired', 3, 'label', 'Gehöft', 'icon', '🏚️'),
        jsonb_build_object('partsRequired', 6, 'label', 'Turm', 'icon', '🗼'),
        jsonb_build_object('partsRequired', 10, 'label', 'Festung', 'icon', '🏰')
      )
    )
  );
