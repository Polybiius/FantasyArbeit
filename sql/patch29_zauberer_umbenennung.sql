-- ============================================================
-- PATCH 29 — Klasse "Hexer" komplett in "Zauberer" umbenannt
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Es gibt keine "Hexerin" (nur "Hexe", negativ konnotiert) - deshalb auf
-- Zauberer/Zauberin umbenannt. Nicht nur der Anzeige-Text in index.html,
-- sondern auch der interne Schlüssel selbst (character_class, Item-Keys),
-- damit das System durchgängig ist statt nur oberflächlich anders
-- beschriftet. Bewusst OHNE where org_id = ... bei den rule_configs-Updates
-- (Lehre aus Patch 20, seit Patch 22 unconditional, siehe dort).

-- 1) Bestehende Profile umstellen.
update public.profiles set character_class = 'zauberer' where character_class = 'hexer';

-- 2) Neue Profile bekommen künftig den neuen Standardwert (character_class
--    wird beim Erschaffen zwar ohnehin explizit gesetzt, siehe charCreateBtn
--    in index.html - der Spalten-Default sollte trotzdem mitziehen).
alter table public.profiles alter column character_class set default 'zauberer';

-- 3) Item-Katalog: hexer_stab/hexer_cape -> zauberer_stab/zauberer_cape,
--    inkl. neuer Bildpfade (Dateien wurden von Claude Code umbenannt, siehe
--    img/characters/creator/item_zauberer_*.png). "sheet" bleibt
--    unverändert (outfit_weapon_stick_{g}.png/outfit_cape_blue.png sind
--    nach dem benannt, was sie zeigen, nicht nach der Klasse).
update public.rule_configs
set config = jsonb_set(
  config,
  '{items}',
  ((config->'items') - 'hexer_stab' - 'hexer_cape')
    || jsonb_build_object(
      'zauberer_stab', (config->'items'->'hexer_stab') || jsonb_build_object('icon_img','img/characters/creator/item_zauberer_stab_{g}.png'),
      'zauberer_cape', (config->'items'->'hexer_cape') || jsonb_build_object('icon_img','img/characters/creator/item_zauberer_cape.png')
    )
)
where config->'items' ? 'hexer_stab' or config->'items' ? 'hexer_cape';

-- 4) Bestehendes Inventar auf die neuen Item-Keys ummappen.
update public.user_inventory set item_key = 'zauberer_stab' where item_key = 'hexer_stab';
update public.user_inventory set item_key = 'zauberer_cape' where item_key = 'hexer_cape';

-- 5) Bereits angezogene Klassenitems ebenfalls ummappen, sonst würde die
--    Ausrüstung nach diesem Patch nicht mehr auf den Katalog passen und
--    die Sprite-Ebene stumm verschwinden.
update public.profiles set equipped_weapon = 'zauberer_stab' where equipped_weapon = 'hexer_stab';
update public.profiles set equipped_accessory = 'zauberer_cape' where equipped_accessory = 'hexer_cape';
