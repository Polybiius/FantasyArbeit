-- ============================================================
-- PATCH 37 — CRM-Chronik: Anruf-/Email-Aktivitäten + XP-Sichtbarkeits-Schalter
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- 1) Neue Tabelle für echte CRM-Aktivitäten (Anrufe, später Emails) —
--    bewusst GETRENNT von action_log (das bleibt reine XP-Buchhaltung,
--    unangetastet). Die Felder sind schon so angelegt, wie sie eine
--    spätere echte Email-Integration bräuchte (betreff/inhalt/
--    occurred_at), auch wenn sie vorerst von Hand befüllt werden.
--    action_log_id verknüpft optional die zugehörige XP-Buchung (ein
--    geloggter Anruf/eine Email löst wie jede andere Vertriebsaktion XP
--    aus) — die Chronik kann darüber die XP-Zahl ein-/ausblenden, ohne
--    zwei getrennte Zeilen für dasselbe Ereignis anzuzeigen.
create table public.contact_activities (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid not null references public.contacts(id) on delete cascade,
  type text not null check (type in ('anruf','email')),
  outcome text,
  betreff text,
  inhalt text,
  occurred_at timestamptz not null default now(),
  action_log_id uuid references public.action_log(id) on delete set null,
  created_at timestamptz not null default now()
);

create index contact_activities_contact_idx on public.contact_activities(contact_id, occurred_at);
create index contact_activities_org_idx on public.contact_activities(org_id);

alter table public.contact_activities enable row level security;

-- Gleiches Sichtbarkeitsmuster wie bei termine: rein persönlich, aber mit
-- Admin-Leserechte-Ausnahme (wie bei den meisten Tabellen im Projekt).
-- Team-Sichtbarkeit unter Kolleg:innen ist bewusst NICHT Teil dieses
-- Patches — das hängt an einer größeren, noch offenen Überarbeitung.
create policy "contact_activities_select_own_or_admin" on public.contact_activities
  for select using (user_id = auth.uid() or public.is_admin());

create policy "contact_activities_insert_own" on public.contact_activities
  for insert with check (user_id = auth.uid() and org_id = public.current_org_id());

create policy "contact_activities_update_own_or_admin" on public.contact_activities
  for update using (user_id = auth.uid() or public.is_admin());

create policy "contact_activities_delete_own_or_admin" on public.contact_activities
  for delete using (user_id = auth.uid() or public.is_admin());

-- 2) Persönlicher Schalter (Einstellungen-Seite): XP (das spielerische
--    Element) in der Kontakt-Chronik standardmäßig ausgeblendet lassen,
--    optional einblendbar. Die "echten" CRM-Fakten (Anrufe, Emails,
--    Termine, Verkäufe, Abschluss/Pitch/etc.) zeigt die Chronik immer,
--    unabhängig von diesem Schalter.
alter table public.profiles add column if not exists chronik_show_xp boolean not null default false;

-- 3) Neue XP-Aktionen für Anruf/Email — modest bemessen (vergleichbar mit
--    "Kalttelefonie geführt"/"Ansprache"), da gelegentliches, manuelles
--    Zusatz-Loggen, keine neue Pflicht-Handlung und kein Quest hängt
--    daran. Deshalb bewusst KEINE Neukalibrierung der Level-Kurve nötig.
update public.rule_configs
set config = jsonb_set(config, '{actions,anruf_erreicht}',
  '{"label":"Anruf – erreicht","xp":4,"energy":1,"skill":"gespraech"}'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';

update public.rule_configs
set config = jsonb_set(config, '{actions,anruf_nicht_erreicht}',
  '{"label":"Anruf – nicht erreicht","xp":1,"energy":1,"skill":"akquise"}'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';

update public.rule_configs
set config = jsonb_set(config, '{actions,email_geschrieben}',
  '{"label":"Email geschrieben","xp":3,"energy":1,"skill":"gespraech"}'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';

update public.rule_configs
set config = jsonb_set(config, '{actions,email_empfangen}',
  '{"label":"Email empfangen","xp":1,"energy":0}'::jsonb)
where org_id = '00000000-0000-0000-0000-000000000001';

insert into public.schema_patches (patch_number, title) values
  (37, 'CRM-Chronik: Anruf-/Email-Aktivitäten + XP-Sichtbarkeits-Schalter')
on conflict (patch_number) do nothing;
