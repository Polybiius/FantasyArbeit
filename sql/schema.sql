-- ============================================================
-- VERTRIEBS-QUEST — Datenbankschema für Supabase
-- ============================================================
-- Anleitung: Im Supabase-Dashboard -> SQL Editor -> "New query"
-- Diesen kompletten Inhalt einfügen -> "Run" klicken.
-- Das legt alle Tabellen, Sicherheitsregeln (RLS) und das
-- Start-Regelwerk aus unserem Prototyp an.
-- ============================================================

-- ------------------------------------------------------------
-- 1. ORGANISATIONEN
-- Jedes Vertriebsteam = eine Organisation. So skaliert das
-- System später auf mehrere Teams, ohne die Struktur zu ändern.
-- ------------------------------------------------------------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'Europe/Berlin', -- Vorkehrung: pro Org einstellbar
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. PROFILE
-- Ein Profil pro Login-Nutzer, verknüpft mit Supabase Auth.
-- role = 'admin' (du) oder 'member' (Vertriebler).
-- character_class ist schon jetzt ein Feld, auch wenn aktuell
-- nur "hexer" existiert -> spätere Klassen brauchen keine
-- Strukturänderung, nur neue Werte in dieser Spalte.
-- ------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  display_name text not null default 'Namenloser Held',
  role text not null default 'member' check (role in ('admin','member')),
  character_class text not null default 'hexer',
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. REGELWERK (rule_configs)
-- Ein JSON-Datensatz pro Organisation: alle Aktionen, XP-Werte,
-- Skills, Level-Kurve, Quests und Quest-Ketten. Der Admin ändert
-- hier Parameter, ohne dass Code angefasst werden muss.
-- ------------------------------------------------------------
create table public.rule_configs (
  org_id uuid primary key references public.organizations(id) on delete cascade,
  config jsonb not null,
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 4. AKTIONS-LOG (action_log)
-- Jede geloggte Handlung eines Nutzers. XP, Level, Skills und
-- Quest-Fortschritt werden daraus IMMER live berechnet -
-- genau wie im HTML-Prototyp. Nichts davon wird redundant
-- gespeichert.
-- ------------------------------------------------------------
create table public.action_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  action_key text not null,
  label text not null,
  xp integer not null,
  energy integer not null default 0,
  skill text,
  skill2 text,
  context text,
  created_at timestamptz not null default now()
);

create index action_log_user_idx on public.action_log(user_id, created_at);
create index action_log_org_idx on public.action_log(org_id, created_at);

-- ============================================================
-- SICHERHEIT (Row Level Security)
-- Ohne das könnte jeder eingeloggte Nutzer alle Daten aller
-- Organisationen sehen/ändern. Das hier sorgt dafür, dass:
--  - jeder nur seine eigene Organisation sieht
--  - nur Admins das Regelwerk ändern dürfen
--  - jeder nur seine eigenen Log-Einträge schreibt
-- ============================================================

-- Hilfsfunktionen (security definer = dürfen die Profiltabelle
-- lesen, ohne dass es zu einer RLS-Endlosschleife kommt)
create or replace function public.current_org_id()
returns uuid
language sql security definer stable
as $$
  select org_id from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql security definer stable
as $$
  select coalesce((select role from public.profiles where id = auth.uid()) = 'admin', false)
$$;

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.rule_configs enable row level security;
alter table public.action_log enable row level security;

-- Organisationen
create policy "org_select_own" on public.organizations
  for select using (id = public.current_org_id());

create policy "org_update_admin_only" on public.organizations
  for update using (id = public.current_org_id() and public.is_admin());

-- Profile
create policy "profiles_select_own" on public.profiles
  for select using (id = auth.uid());

create policy "profiles_select_same_org" on public.profiles
  for select using (org_id = public.current_org_id());

create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid());

create policy "profiles_update_admin" on public.profiles
  for update using (org_id = public.current_org_id() and public.is_admin());

-- Regelwerk
create policy "rules_select_same_org" on public.rule_configs
  for select using (org_id = public.current_org_id());

create policy "rules_insert_admin_only" on public.rule_configs
  for insert with check (org_id = public.current_org_id() and public.is_admin());

create policy "rules_update_admin_only" on public.rule_configs
  for update using (org_id = public.current_org_id() and public.is_admin());

-- Aktions-Log
create policy "log_select_own" on public.action_log
  for select using (user_id = auth.uid());

create policy "log_select_admin_sees_all_in_org" on public.action_log
  for select using (org_id = public.current_org_id() and public.is_admin());

create policy "log_insert_own" on public.action_log
  for insert with check (user_id = auth.uid() and org_id = public.current_org_id());

-- ============================================================
-- START-REGELWERK
-- Legt deine Organisation an und befüllt sie mit dem kompletten
-- Regelwerk aus unserem HTML-Prototyp (Aktionen, Skills,
-- Level-Kurve, Quests, Quest-Ketten).
-- ============================================================
insert into public.organizations (id, name, timezone)
values ('00000000-0000-0000-0000-000000000001', 'Mein Vertriebsteam', 'Europe/Berlin');

insert into public.rule_configs (org_id, config)
values (
  '00000000-0000-0000-0000-000000000001',
  '{
    "energyMax": 15,
    "levelBase": 5,
    "levelExponent": 1.5,
    "skills": {
      "gespraech": "Gesprächsführung",
      "akquise": "Akquise & Ausdauer",
      "fachwissen": "Fachwissen",
      "beziehung": "Beziehungspflege",
      "abschluss": "Abschlusskraft"
    },
    "actions": {
      "ansprache_assistenz":   { "label": "Ansprache Assistenzarzt",        "xp": 2,  "energy": 1, "skill": "akquise" },
      "ansprache_oberarzt":    { "label": "Ansprache Ober-/Chefarzt",        "xp": 5,  "energy": 2, "skill": "gespraech", "skill2": "akquise" },
      "gruppentermin":         { "label": "Gruppentermin",                  "xp": 10, "energy": 3, "skill": "akquise", "skill2": "beziehung" },
      "telefon_5":             { "label": "5 Nummern gewählt",              "xp": 2,  "energy": 1, "skill": "akquise" },
      "kalttelefonie":         { "label": "Kalttelefonie geführt",          "xp": 4,  "energy": 1, "skill": "gespraech", "skill2": "akquise" },
      "bestandskunde":         { "label": "Bestandskunde kontaktiert",      "xp": 1,  "energy": 1, "skill": "beziehung" },
      "termin_vereinbart":     { "label": "Termin vereinbart",              "xp": 5,  "energy": 1, "skill": "akquise" },
      "termin_wahrgenommen":   { "label": "Termin wahrgenommen",           "xp": 8,  "energy": 0, "skill": "beziehung" },
      "bedarfsanalyse":        { "label": "Bedarfsanalyse geführt",        "xp": 10, "energy": 2, "skill": "gespraech" },
      "kundenausbau":          { "label": "Kundenausbau",                   "xp": 10, "energy": 2, "skill": "akquise", "skill2": "beziehung" },
      "pitch":                 { "label": "Angebot/Pitch abgegeben",       "xp": 15, "energy": 3, "skill": "fachwissen", "skill2": "abschluss" },
      "empfehlung":            { "label": "Empfehlung erhalten",           "xp": 20, "energy": 2, "skill": "beziehung" },
      "fachinfo":              { "label": "Fachliche Info recherchiert",   "xp": 5,  "energy": 1, "skill": "fachwissen" },
      "abschluss":             { "label": "Abschluss",                      "xp": 40, "energy": 4, "skill": "abschluss", "context": "Klinik/Krankenhaus" },
      "boss":                  { "label": "Boss-Encounter: Große Präsentation", "xp": 60, "energy": 5, "skill": "fachwissen", "skill2": "gespraech" }
    },
    "recurringQuests": [
      { "id": "daily1", "period": "daily", "name": "Täglich: 3 Ansprachen + 1 Termin vereinbart", "bonus": 10,
        "conditions": [
          { "actions": ["ansprache_assistenz","ansprache_oberarzt"], "count": 3 },
          { "actions": ["termin_vereinbart"], "count": 1 }
        ] },
      { "id": "weekly1", "period": "weekly", "name": "Wöchentlich: 1 neue Fachinfo recherchiert", "bonus": 25,
        "conditions": [
          { "actions": ["fachinfo"], "count": 1 }
        ] }
    ],
    "questChains": [
      { "id": "krankenhaus_meister", "name": "Krankenhaus-Meister",
        "stages": [
          { "id": "stufe1", "name": "3 Abschlüsse im selben Krankenhaus", "bonus": 50, "rule": "same_context_count>=3" },
          { "id": "stufe2", "name": "Abschlüsse aus 3 verschiedenen Krankenhäusern", "bonus": 100, "rule": "distinct_contexts>=3" }
        ] }
    ]
  }'::jsonb
);

-- ============================================================
-- LETZTER MANUELLER SCHRITT (nicht Teil dieses Skripts):
-- Nachdem du dich einmal in der zukünftigen App registriert
-- hast, muss dein Profil noch mit der Organisation und der
-- Admin-Rolle verknüpft werden. Das machen wir gemeinsam mit
-- einem kurzen Folge-Befehl, sobald der Login steht.
-- ============================================================
