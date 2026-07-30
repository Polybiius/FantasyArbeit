-- ============================================================
-- PATCH 20 — Manareserve (energyMax) von 15 auf 20 angehoben
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
--
-- Reine Regelwerk-Konfiguration, kein Code betroffen — index.html liest
-- config.energyMax bereits überall dynamisch. Level-Kurve NICHT neu
-- kalibriert (das war bisher nur bei XP-Wert-Änderungen nötig, nicht bei
-- reiner Tagesenergie) — bei Bedarf später nachjustierbar.
-- ============================================================

update public.rule_configs
set config = jsonb_set(config, '{energyMax}', '20'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';
