-- ============================================================
-- PATCH 27 — Echte Item-Bilder statt generischer Emojis im Inventar
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Ergänzt "icon_img" bei den 5 Klassenitems aus Patch 26 - kleine,
-- freigestellte Ausschnitte aus den echten Sprite-Sheets
-- (img/characters/creator/item_*.png, erzeugt aus
-- img/characters/sheets/outfit_*.png). Emojis waren bei mehreren Items zu
-- ähnlich/generisch, um sie bei wachsendem Katalog auseinanderzuhalten.
-- "icon" (Emoji) bleibt als Fallback im Katalog stehen, falls das Bild aus
-- irgendeinem Grund nicht lädt. "{g}" wird im Frontend genau wie bei
-- "sheet" durch "m"/"w" ersetzt.
--
-- Bewusst ohne where org_id = ... (Lehre aus Patch 20, siehe Patch 22/26).
-- Keine destruktive Operation, jsonb_set auf einzelne Item-Schlüssel.

update public.rule_configs
set config = jsonb_set(config, '{items,hexer_stab,icon_img}', '"img/characters/creator/item_hexer_stab_{g}.png"');

update public.rule_configs
set config = jsonb_set(config, '{items,hexer_cape,icon_img}', '"img/characters/creator/item_hexer_cape.png"');

update public.rule_configs
set config = jsonb_set(config, '{items,krieger_schwert,icon_img}', '"img/characters/creator/item_krieger_schwert_{g}.png"');

update public.rule_configs
set config = jsonb_set(config, '{items,krieger_helm,icon_img}', '"img/characters/creator/item_krieger_helm.png"');

update public.rule_configs
set config = jsonb_set(config, '{items,schuetze_rucksack,icon_img}', '"img/characters/creator/item_schuetze_rucksack.png"');
