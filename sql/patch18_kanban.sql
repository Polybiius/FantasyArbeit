-- ============================================================
-- PATCH 18 — Kanban (Questpfad/Gildenbrett/Feldzug)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
--
-- Hintergrund: Das Kanban zeigt den Verkaufsprozess pro Kontakt als
-- Spalten, durch die man Karten zieht. "Angebot versendet" und
-- "Zweittermin" würden beide dieselbe Aktion (pitch) loggen — daran
-- allein ließe sich hinterher nicht mehr unterscheiden, in welcher
-- Spalte eine Karte liegt. Deshalb bekommt contacts ein explizites
-- Stufenfeld, das beim Ziehen direkt mitgesetzt wird. Das Aktions-Log
-- bleibt trotzdem die Wahrheitsquelle für XP/Quests/Statistik — das
-- neue Feld sorgt nur dafür, dass die Karte nach einem Neuladen exakt
-- in der richtigen Spalte liegt.
-- ============================================================

alter table public.contacts add column if not exists kanban_stage text not null default 'neuer_lead'
  check (kanban_stage in (
    'neuer_lead', 'ersttermin_vereinbart', 'nicht_erschienen',
    'angebot_versendet', 'zweittermin', 'gewonnen', 'verloren', 'dauerbrenner'
  ));

create index if not exists contacts_kanban_stage_idx on public.contacts(org_id, kanban_stage);

-- Neue Aktion für den Malus bei nicht wahrgenommenem Ersttermin
-- (Konversions-Malus, bisher nur konzeptionell im Regelwerk erwähnt,
-- jetzt zum ersten Mal tatsächlich als Aktion angelegt).
update public.rule_configs
set config = jsonb_set(
  config,
  '{actions,termin_nicht_wahrgenommen}',
  '{ "label": "Termin nicht wahrgenommen", "xp": -2, "energy": 0 }'::jsonb
)
where org_id = '00000000-0000-0000-0000-000000000001';
