-- PATCH: Fundament für Gildenleben-Team-Ziele ("Gilden-Gebäude")
--
-- Erster Baustein einer längeren, mit dem Nutzer ausführlich besprochenen
-- Konzeptreihe (2026-08-19): die Gilde bekommt eigene, verkaufsbasierte
-- Jahres-Team-Ziele (mehrere gleichzeitig, je Sparte), deren Erfüllung
-- Bauteile eines gemeinsamen Gilden-Gebäudes freischaltet -- kein XP, kein
-- Titel, sondern ein rein visuelles, gilden-eigenes Fortschritts-Symbol
-- (Optik folgt als eigener, späterer Schritt).
--
-- Nur die Datenbank-Seite dieses ersten Schritts: das Protokoll +
-- die beiden Funktionen. Regelwerk-Beispieldaten, Auswertungslogik im
-- Frontend und der Seiten-Umbau folgen als eigene, nächste Schritte.

-- ---------------------------------------------------------------------
-- 1) guild_quest_log -- reines Anhänge-Protokoll, gleiches Prinzip wie
-- action_log: nichts wird gespeichert außer "das ist passiert". Der
-- Bau-Fortschritt eines Gilden-Gebäudes wird nirgends als Zahl
-- gespeichert, sondern beim Anzeigen live gezählt (Anzahl Zeilen für
-- diese Gilde). Bewusst NIE geleert/resettet -- anders als der jährliche
-- Zähl-Zeitraum für die Team-Ziel-Erfüllung selbst (period_key), bleibt
-- eine einmal erfüllte Stufe für immer im Protokoll stehen (Nutzer-
-- Klarstellung: "was sich nie resettet ist ... im Falle der Gilde die
-- Entwicklung und der Bau des Gebäudes"). Dieselbe Stufe eines Team-Ziels
-- ist über mehrere Jahre hinweg mehrfach erreichbar (Jahresziel-Prinzip
-- wie beim individuellen Questbaum seit Patch 50) -- der Unique-Key
-- schließt deshalb period_key mit ein, nicht nur guild_id/quest_id/stage_id.
create table public.guild_quest_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  guild_id uuid not null references public.guilds(id) on delete cascade,
  quest_id text not null,
  stage_id text not null,
  period_key text not null,
  achieved_at timestamptz not null default now(),
  unique (guild_id, quest_id, stage_id, period_key)
);
create index guild_quest_log_guild_id_idx on public.guild_quest_log(guild_id);

alter table public.guild_quest_log enable row level security;

-- Sichtbar für alle Mitglieder der jeweiligen Gilde + Admins -- gleiches
-- Sichtbarkeits-Muster wie guild_members selbst.
create policy guild_quest_log_select on public.guild_quest_log
  for select using (
    exists(select 1 from public.guild_members gm where gm.guild_id = guild_quest_log.guild_id and gm.member_id = (select auth.uid()))
    or public.is_admin()
  );

-- Bewusst KEINE insert/update/delete-Policy für normale Clients -- jeder
-- Eintrag läuft ausschließlich über grant_guild_quest_completion() unten,
-- gleiches Härtungsmuster wie action_log/user_inventory/termin_invitations.

-- ---------------------------------------------------------------------
-- 2) guild_sales_metric_total() -- Aggregat-Funktion, liefert NUR eine
-- Summe zurück (keine Einzelverkäufe), gleiches Schutzprinzip wie das
-- bestehende friend_skill_totals(). Nötig, weil normale sales-RLS nicht
-- jedem Gildenmitglied automatisch alle Verkäufe der anderen zeigt (nur
-- wenn zufällig über einen geteilten Kontakt) -- ein Team-Ziel braucht
-- aber die Summe über ALLE Mitglieder, unabhängig von Kontakt-Freigaben.
-- p_field ist bewusst über eine feste Erlaubnisliste geprüft (kein freier
-- SQL-Injection-Vektor über dynamische Spaltennamen). p_category filtert
-- optional auf eine Produktkategorie (z.B. 'Krankenversicherung'), NULL
-- = alle Kategorien zusammen. Zeitraum wie auf der persönlichen
-- Statistik-Seite: vertragsbeginn, Fallback datum.
create or replace function public.guild_sales_metric_total(
  p_guild_id uuid, p_field text, p_category text, p_year int
)
returns numeric
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_total numeric;
begin
  if not exists(select 1 from public.guild_members gm where gm.guild_id = p_guild_id and gm.member_id = auth.uid())
     and not public.is_admin() then
    raise exception 'Kein Zugriff auf diese Gilde.';
  end if;
  if p_field not in ('bewertungssumme','laufender_beitrag') then
    raise exception 'Ungültiges Feld: %', p_field;
  end if;

  execute format(
    'select coalesce(sum(s.%I),0) from public.sales s
     join public.products pr on pr.id = s.product_id
     join public.guild_members gm on gm.member_id = s.created_by
     where gm.guild_id = $1
       and s.status = ''gewonnen''
       and extract(year from coalesce(s.vertragsbeginn, s.datum)) = $2
       and ($3 is null or pr.category = $3)',
    p_field
  ) into v_total using p_guild_id, p_year, p_category;

  return v_total;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) grant_guild_quest_completion() -- trägt eine erfüllte Stufe ins
-- Protokoll ein. Aufrufbar von jedem Mitglied der betroffenen Gilde (die
-- Prüfung "ist der Schwellenwert wirklich erreicht" passiert im Frontend
-- über guild_sales_metric_total(), genau wie bei den bestehenden
-- persönlichen Quest-Prüfungen -- diese Funktion selbst verhindert nur
-- doppeltes Eintragen derselben Stufe/desselben Jahres, prüft aber (wie
-- bei grant_quest_bonus_to_self()) nicht erneut den Schwellenwert selbst).
-- Gibt true zurück, wenn wirklich neu eingetragen wurde, false bei einem
-- bereits vorhandenen Duplikat.
create or replace function public.grant_guild_quest_completion(
  p_guild_id uuid, p_quest_id text, p_stage_id text, p_period_key text
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_org_id uuid;
  v_row_count integer;
begin
  if not exists(select 1 from public.guild_members gm where gm.guild_id = p_guild_id and gm.member_id = auth.uid()) then
    raise exception 'Kein Mitglied dieser Gilde.';
  end if;

  select org_id into v_org_id from public.guilds where id = p_guild_id;
  if v_org_id is null then
    raise exception 'Gilde nicht gefunden.';
  end if;

  insert into public.guild_quest_log (org_id, guild_id, quest_id, stage_id, period_key)
  values (v_org_id, p_guild_id, p_quest_id, p_stage_id, p_period_key)
  on conflict (guild_id, quest_id, stage_id, period_key) do nothing;

  get diagnostics v_row_count = row_count;
  return v_row_count > 0;
end;
$$;
