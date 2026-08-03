-- ============================================================
-- PATCH 28 — Bogen als Fernkampfwaffe für den Schützen
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Der Schütze hatte bisher kein Waffen-Item (kein Bogen/Zauberstab im
-- gekauften GandalfHardcore-Paket enthalten, siehe CLAUDE.md-Wiedervorlage).
-- Statt weiter zu warten: handgezeichnetes Pixel-Sprite, positioniert entlang
-- derselben Laufzyklus-Spur wie Schwert/Stab (img/characters/sheets/
-- outfit_weapon_bow_{m,w}.png, siehe Design/export_full_sheets.py).
--
-- Bewusst ohne where org_id = ... (Lehre aus Patch 20, siehe Patch 22/26/27).
update public.rule_configs
set config = jsonb_set(
  config,
  '{items,schuetze_bogen}',
  '{"label":"Bogen","category":"waffen","icon":"🏹","sheet":"outfit_weapon_bow_{g}.png","icon_img":"img/characters/creator/item_schuetze_bogen.png"}'::jsonb
);

-- Bestehende Schützen bekommen den Bogen einmalig nachträglich ins Inventar
-- + angezogen, genau wie in Patch 26 für die anderen Klassenitems. Guard
-- nur auf equipped_weapon (nicht alle drei Slots wie in Patch 26), weil
-- equipped_accessory beim Schützen durch Patch 26 schon belegt ist.
insert into public.user_inventory (user_id, org_id, item_key, quantity)
select id, org_id, 'schuetze_bogen', 1 from public.profiles where character_class = 'schuetze'
on conflict (user_id, item_key) do nothing;

update public.profiles
set equipped_weapon = 'schuetze_bogen'
where character_class = 'schuetze' and equipped_weapon is null;
