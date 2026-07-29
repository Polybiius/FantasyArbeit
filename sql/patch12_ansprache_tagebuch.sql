-- ============================================================
-- PATCH 12 — Ansprache vereinheitlicht, Tagebuch-Kundenmarkierung
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- 1) Ansprache vereinheitlichen: eine einzige Aktion statt getrennt
--    nach Assistenz-/Oberarzt. Die Rolle steckt jetzt sauber am
--    Kontakt (contacts.role), nicht mehr in der XP-Logik.
--    Bereits geloggte alte Einträge bleiben unverändert erhalten —
--    ihre XP-Werte sind zum Zeitpunkt der Buchung eingefroren.
update public.rule_configs
set config = (config - 'actions') || jsonb_build_object(
  'actions',
  (config->'actions')
    - 'ansprache_assistenz' - 'ansprache_oberarzt'
    || jsonb_build_object('ansprache', jsonb_build_object(
         'label', 'Ansprache',
         'xp', 5,
         'energy', 1,
         'skill', 'akquise'
       ))
)
where org_id = '00000000-0000-0000-0000-000000000001';

-- Tägliche Quest-Bedingung auf den neuen, einheitlichen Aktions-Key umstellen.
update public.rule_configs
set config = jsonb_set(
  config,
  '{recurringQuests,0,conditions,0,actions}',
  '["ansprache"]'::jsonb
)
where org_id = '00000000-0000-0000-0000-000000000001';

-- 2) Tagebuch: optionale Verknüpfung eines Eintrags mit einem Kontakt.
--    Bewusst rein persönlich (bestehende journal_entries-Regeln
--    gelten unverändert — nur der Nutzer selbst sieht das), keine
--    CRM-Statistik, sondern Stoff für die spätere Jahres-Geschichte.
alter table public.journal_entries add column if not exists tagged_contact_id uuid references public.contacts(id) on delete set null;

-- 3) Level-Kurve neu kalibriert: Ansprache jetzt einheitlich 5 XP
--    (statt gewichtet ~2,9 XP) plus Konversions-Bonus/Malus bringen
--    mehr XP ins System. levelBase von 5 auf 4,7 abgesenkt, damit
--    Level 100 weiterhin realistisch nach ~10 Jahren erreichbar bleibt.
--    Basis: geschätzte 80% Erscheinquote — vorläufig, mit echten
--    Daten aus dem Kanban später nachjustierbar.
update public.rule_configs
set config = jsonb_set(config, '{levelBase}', '4.7'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';
