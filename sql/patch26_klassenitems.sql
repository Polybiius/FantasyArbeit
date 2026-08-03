-- ============================================================
-- PATCH 26 — Klassenitems als echte, ausziehbare Ausrüstung
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Wichtig: NICHT config || '{"items": {...}}' wie in Patch 3/22 - das würde
-- den kompletten "items"-Schlüssel ersetzen und den bestehenden mana_trank
-- darin löschen (shallow merge). jsonb_set mit Pfad '{items}' merged
-- stattdessen NUR innerhalb von "items" und lässt mana_trank unangetastet.
-- "sheet" ist derselbe Dateiname wie bei Haut/Haaren unter
-- img/characters/sheets/ - "{g}" wird im Frontend durch "m"/"w" ersetzt.
--
-- Bewusst OHNE where org_id = ... (Lehre aus Patch 20: eine hartkodierte ID
-- kann still ins Leere laufen, ohne Fehlermeldung - seit Patch 22 deshalb
-- unconditional, unproblematisch solange es nur eine Organisation gibt).
update public.rule_configs
set config = jsonb_set(
  config,
  '{items}',
  coalesce(config->'items', '{}'::jsonb) || '{
    "hexer_stab": {"label":"Zauberstab","category":"waffen","icon":"🪄","sheet":"outfit_weapon_stick_{g}.png"},
    "hexer_cape": {"label":"Blaues Cape","category":"accessories","icon":"🧣","sheet":"outfit_cape_blue.png"},
    "krieger_schwert": {"label":"Holzschwert","category":"waffen","icon":"🗡️","sheet":"outfit_weapon_sword_{g}.png"},
    "krieger_helm": {"label":"Guard Helmet","category":"ruestung","icon":"⛑️","sheet":"outfit_hat_guardhelmet.png"},
    "schuetze_rucksack": {"label":"Kleiner Rucksack","category":"accessories","icon":"🎒","sheet":"outfit_backpack_small.png"}
  }'::jsonb
);

-- Bestehende Profile (bereits vor diesem Patch mit einer Klasse angelegt)
-- bekommen ihr Klassenitem einmalig nachträglich ins Inventar - neue
-- Charaktere bekommen das ab jetzt automatisch über grantClassStarterEquipment()
-- in index.html bei der Erschaffung. on conflict do nothing macht diesen
-- Block gefahrlos mehrfach ausführbar.
insert into public.user_inventory (user_id, org_id, item_key, quantity)
select id, org_id, 'hexer_stab', 1 from public.profiles where character_class = 'hexer'
on conflict (user_id, item_key) do nothing;

insert into public.user_inventory (user_id, org_id, item_key, quantity)
select id, org_id, 'hexer_cape', 1 from public.profiles where character_class = 'hexer'
on conflict (user_id, item_key) do nothing;

insert into public.user_inventory (user_id, org_id, item_key, quantity)
select id, org_id, 'krieger_schwert', 1 from public.profiles where character_class = 'krieger'
on conflict (user_id, item_key) do nothing;

insert into public.user_inventory (user_id, org_id, item_key, quantity)
select id, org_id, 'krieger_helm', 1 from public.profiles where character_class = 'krieger'
on conflict (user_id, item_key) do nothing;

insert into public.user_inventory (user_id, org_id, item_key, quantity)
select id, org_id, 'schuetze_rucksack', 1 from public.profiles where character_class = 'schuetze'
on conflict (user_id, item_key) do nothing;

-- ...und gleich anziehen, damit sich am heutigen Aussehen nichts ändert.
-- Die where-Bedingung (alle drei Slots noch leer) macht auch diesen Block
-- gefahrlos mehrfach ausführbar - wer inzwischen manuell etwas an-/ausgezogen
-- hat, wird hier nicht überschrieben.
update public.profiles set
  equipped_weapon = case character_class
    when 'hexer' then 'hexer_stab'
    when 'krieger' then 'krieger_schwert'
    else equipped_weapon end,
  equipped_armor = case character_class
    when 'krieger' then 'krieger_helm'
    else equipped_armor end,
  equipped_accessory = case character_class
    when 'hexer' then 'hexer_cape'
    when 'schuetze' then 'schuetze_rucksack'
    else equipped_accessory end
where equipped_weapon is null and equipped_armor is null and equipped_accessory is null
  and character_class in ('hexer','krieger','schuetze');
