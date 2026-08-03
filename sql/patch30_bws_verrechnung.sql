-- ============================================================
-- PATCH 30 — BWS-Verrechnung: Faktoren am Produkt, individuelle Sätze am Profil
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Formel aus der vom Nutzer gelieferten Excel abgeleitet (siehe CLAUDE.md
-- "BWS-Verrechnung"). Bewusst KEINE Rückrechnung/Migration bestehender
-- Produkte hier - die Faktoren sind admin-getippte Zahlen, nicht aus dem
-- Produktnamen zuverlässig ableitbar. Bestehende Produkte bekommen
-- NULL-Faktoren und werden im "Produkte"-Reiter nachgetragen.

-- 1) Bewertungspunkte-/Provisions-Faktor je Produkt. provision_mode
--    steuert, ob provision_faktor direkt gilt ('fest') oder stattdessen
--    die individuelle Rate des verkaufenden Mitarbeiters herangezogen
--    wird ('individuell_lv'/'individuell_kv') - nur bei Leben/Kranken
--    laut Excel der Fall, alle anderen Sparten nutzen 'fest'.
alter table public.products add column if not exists bwp_faktor numeric;
alter table public.products add column if not exists provision_faktor numeric;
alter table public.products add column if not exists provision_mode text not null default 'fest'
  check (provision_mode in ('fest','individuell_lv','individuell_kv'));

-- 2) Individuelle Provisionssätze pro Mitarbeiter - nur für Leben (‰-Satz)
--    und Kranken (Satz je monatlichem Beitrag) relevant, alle anderen
--    Sparten nutzen products.provision_faktor. Admin-gepflegt (siehe
--    Produkte-Reiter), nicht selbst editierbar - analog zur bestehenden
--    Account-Pool-Zuweisung, ebenfalls ein sensibler, admin-exklusiver Wert.
alter table public.profiles add column if not exists lv_promille_satz numeric;
alter table public.profiles add column if not exists kv_mb_satz numeric;

-- 3) Org-weite Referenzsätze für die Differenzprovision (Standard-Satz
--    minus individueller Satz, nur Leben/Kranken) - Defaults entsprechen
--    der Excel-Vorlage (40‰ Leben, 8 Kranken).
update public.rule_configs set config = jsonb_set(config, '{diffProvLvPromille}', '40'::jsonb);
update public.rule_configs set config = jsonb_set(config, '{diffProvKvMb}', '8'::jsonb);
