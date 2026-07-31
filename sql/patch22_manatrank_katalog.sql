-- ============================================================
-- PATCH 22 — Manatrank-Katalogeintrag absichern
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================
-- Der Manatrank sollte laut Patch 3 bereits im Regelwerk stehen
-- (rule_configs.config.items.mana_trank). Da sich Patch 20 letztens als
-- nie wirklich ausgeführt herausstellte, hier sicherheitshalber idempotent
-- neu gesetzt statt blind vorausgesetzt — schadet nicht, falls er doch
-- schon da ist (überschreibt ihn nur mit denselben Werten).
--
-- Keine destruktive Operation.

-- Schritt 1: "items" als Objekt sicherstellen, falls aus irgendeinem Grund
-- noch nicht vorhanden (jsonb_set kann sonst kein verschachteltes Feld
-- darunter anlegen).
update public.rule_configs
set config = jsonb_set(config, '{items}', coalesce(config->'items', '{}'::jsonb))
where config->'items' is null;

-- Schritt 2: Manatrank-Definition setzen. effect "full_energy_refill" wird
-- von useItem() in index.html bereits ausgewertet (füllt die Manareserve
-- des Tages komplett auf).
update public.rule_configs
set config = jsonb_set(
  config,
  '{items,mana_trank}',
  '{
    "label": "Manatrank",
    "category": "consumables",
    "icon": "🧪",
    "effect": "full_energy_refill",
    "description": "Füllt die Manareserve für heute vollständig auf."
  }'::jsonb,
  true
);
