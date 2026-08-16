-- ============================================================
-- Sicherheitswarnungen (Alarm-Logging), Schritt 1 der BaaS-
-- Aufgabenliste Punkt 9 ("Logging mit echter Reaktion statt nur
-- Speicherung"). Auslöser: offene Selbstregistrierung + öffentlich
-- erreichbare App bedeuten, dass ein Angriff nicht zwingend über
-- unsere eigene Oberfläche laufen muss -- bisher landete ein
-- abgewehrter Manipulationsversuch nur dann im Fehlerprotokoll, wenn
-- der BROWSER ihn freiwillig meldete. Wer unsere Oberfläche komplett
-- umgeht (direkter API-Aufruf), blieb bisher unsichtbar.
--
-- Kernidee: die beiden ernsthaftesten, bereits am 2026-08-15 gehärteten
-- Lücken (profiles-Rechte-Felder, guild_members-Selbstbeitritt) werden
-- von "hart ablehnen" auf "still auf einen sicheren Wert zurücksetzen
-- UND protokollieren" umgestellt -- dasselbe Muster, das
-- enforce_profile_insert_defaults() (Patch 39) schon lange nutzt. Der
-- Vorteil: die Korrektur läuft in DERSELBEN, erfolgreichen Transaktion
-- wie der Rest der Anfrage, der Log-Eintrag geht also nie durch einen
-- Rollback verloren -- ein reines "raise exception" könnte das nicht
-- zuverlässig, ohne eine separate (autonome) Datenbank-Verbindung
-- aufzubauen (z.B. über die dblink-Erweiterung). Das würde bedeuten,
-- ein Verbindungs-Geheimnis irgendwo abzulegen -- widerspricht genau
-- dem Architekturprinzip, das dieses Projekt bisher auszeichnet (siehe
-- CLAUDE.md: "diese Architektur hat strukturell gar keinen Ort für ein
-- verstecktes Backend-Geheimnis"). Deshalb bewusst nicht eingebaut.
--
-- Bewusst NICHT Teil dieses Schritts (ehrliche Grenze, keine stille
-- Lücke): die reinen Ablehnungs-Fälle ohne sinnvollen "korrigierten"
-- Wert (unbekannter action_key/item_key, doppelt eingelöste Quest,
-- sales-Grenzwerte, locations-Owner-Fälschung) bleiben weiterhin
-- durch die bestehenden Prüfungen vollständig blockiert -- der
-- Schreibversuch kann so oder so nie erfolgreich sein, es fehlt hier
-- nur die Alarmierung selbst (reine Aufklärung "wer probiert
-- rum", kein Datenrisiko). Eine vollständige Abdeckung bräuchte
-- dieselbe Autonome-Transaktion-Frage wie oben -- als bewusste
-- Wiedervorlage vermerkt, kein aktueller Auslöser.
-- ============================================================

-- === Tabelle ===

create table public.security_alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  detail text,
  created_at timestamptz not null default now()
);

create index security_alerts_org_idx on public.security_alerts using btree (org_id, created_at desc);

alter table public.security_alerts enable row level security;

-- Nur Admins der eigenen Organisation dürfen lesen -- kein Insert/
-- Update/Delete für normale Rollen, Schreiben läuft ausschließlich
-- über log_security_alert() unten.
create policy "security_alerts_select_admin" on public.security_alerts
  for select using (org_id = current_org_id() and is_admin());

-- === Schreib-Helfer, NICHT direkt aufrufbar ===
--
-- Wichtig: returns void (keine Trigger-Funktion) -- Postgres würde das
-- NICHT automatisch vor direktem RPC-Aufruf schützen (anders als die
-- "returns trigger"-Funktionen im Projekt, die strukturell gar nicht
-- per RPC aufrufbar sind). Neue Funktionen im Schema public bekommen
-- laut den bestehenden ALTER DEFAULT PRIVILEGES-Regeln automatisch
-- EXECUTE für anon/authenticated -- deshalb hier explizit entzogen,
-- sonst könnte jeder eigene, erfundene Alarme einschleusen (Rauschen/
-- Verschleierung echter Vorfälle).
create or replace function public.log_security_alert(p_user_id uuid, p_event_type text, p_detail text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
begin
  select org_id into v_org_id from public.profiles where id = p_user_id;
  if v_org_id is null then
    return;
  end if;
  insert into public.security_alerts (org_id, user_id, event_type, detail)
  values (v_org_id, p_user_id, p_event_type, p_detail);
end;
$$;

revoke execute on function public.log_security_alert(uuid, text, text) from public, anon, authenticated;

-- === profiles-Rechte-Felder: von "ablehnen" auf "korrigieren + melden" ===
--
-- Kein Verhaltensunterschied für legitime Aufrufe: kein Weg in der App
-- schickt diese vier Felder je in einem normalen .update() (total_xp/
-- level laufen über sync_own_level_cache(), role/character_class/org_id
-- werden von normalen Mitgliedern nie mitgeschickt) -- Admins sind von
-- der ganzen Prüfung ohnehin ausgenommen (if not is_admin()).
create or replace function public.protect_privileged_profile_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    if new.role is distinct from old.role then
      perform public.log_security_alert(auth.uid(), 'profile_role_tamper',
        format('Versuchte Rollenänderung: %s -> %s', old.role, new.role));
      new.role := old.role;
    end if;
    if new.character_class is distinct from old.character_class then
      perform public.log_security_alert(auth.uid(), 'profile_class_tamper',
        format('Versuchte Klassenänderung: %s -> %s', old.character_class, new.character_class));
      new.character_class := old.character_class;
    end if;
    if new.org_id is distinct from old.org_id then
      perform public.log_security_alert(auth.uid(), 'profile_org_tamper',
        format('Versuchte org_id-Änderung: %s -> %s', old.org_id, new.org_id));
      new.org_id := old.org_id;
    end if;
    if (new.total_xp is distinct from old.total_xp or new.level is distinct from old.level)
       and coalesce(current_setting('app.trusted_level_sync', true), 'false') <> 'true' then
      perform public.log_security_alert(auth.uid(), 'profile_level_tamper',
        format('Versuchter Level-Cache-Schreibzugriff: xp %s->%s, level %s->%s', old.total_xp, new.total_xp, old.level, new.level));
      new.total_xp := old.total_xp;
      new.level := old.level;
    end if;
  end if;
  return new;
end;
$function$;

-- === guild_members-Selbstbeitritt: dasselbe Muster ===
--
-- Die bisherige WITH CHECK-Policy (2026-08-15) lehnte einen
-- Selbstbeitritt mit erhöhten Rechten hart ab -- sicher, aber nicht
-- protokollierbar (ein abgelehnter INSERT hinterlässt serverseitig
-- keine Spur, die wir festhalten könnten). Jetzt: die Policy prüft nur
-- noch Identität/Organisation, ein neuer BEFORE-INSERT-Trigger setzt
-- erhöhte Rechte still auf die sicheren Minimalwerte zurück UND
-- protokolliert das -- außer der Beitretende ist selbst der
-- Gildengründer (legitimer Fall aus guildCreateBtn) ODER der Aufruf
-- kommt vom Gildengründer, der ein ANDERES Mitglied einlädt
-- (guild_members_insert_founder_adds -- eigene, unveränderte Policy,
-- dort sind erhöhte Rechte gewollt und bleiben erlaubt).
drop policy if exists "guild_members_insert_self_join" on public.guild_members;
create policy "guild_members_insert_self_join" on public.guild_members for insert
with check (
  (member_id = auth.uid())
  and (org_id = current_org_id())
);

create or replace function public.enforce_guild_selfjoin_limits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_is_founder boolean;
begin
  -- Betrifft nur echten Selbstbeitritt (member_id = auth.uid()); wenn
  -- der Gildengründer jemand ANDEREN einlädt, ist new.member_id != auth.uid()
  -- und diese Prüfung greift absichtlich nicht.
  if new.member_id = auth.uid() then
    select exists(select 1 from public.guilds g where g.id = new.guild_id and g.founder_id = auth.uid())
      into v_caller_is_founder;

    if not v_caller_is_founder
       and (new.contacts_access <> 'read' or new.dungeons_access <> 'read' or new.team_rights <> false) then
      perform public.log_security_alert(new.member_id, 'guild_selfjoin_privilege_escalation',
        format('Selbst-Beitritt mit erhöhten Rechten versucht: contacts=%s dungeons=%s team_rights=%s (Gilde %s)',
          new.contacts_access, new.dungeons_access, new.team_rights, new.guild_id));
      new.contacts_access := 'read';
      new.dungeons_access := 'read';
      new.team_rights := false;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_guild_selfjoin_limits on public.guild_members;
create trigger trg_enforce_guild_selfjoin_limits
  before insert on public.guild_members
  for each row execute function public.enforce_guild_selfjoin_limits();

-- === Sichtbarkeit im Frontend: "seit wann gesehen" ===
--
-- Gleiches Prinzip wie profiles.last_seen_patch_number (Changelog-
-- Popup), aber ein Zeitstempel statt einer Nummer, da Alarme keine
-- fortlaufende Zählung haben. default now() sorgt automatisch dafür,
-- dass neue Profile (die es noch gar nicht gibt) nie mit einer alten
-- Historie überflutet werden -- exakt dieselbe Überlegung, die beim
-- Changelog-Popup einen eigenen Trigger brauchte, hier durch den
-- Spalten-Default trivial gelöst.
alter table public.profiles
  add column last_seen_security_alert timestamptz not null default now();

insert into public.schema_patches (patch_number, title) values
  (47, 'Sicherheitswarnungen: Rechte-Manipulationsversuche werden erkannt, protokolliert und Admins beim Login angezeigt')
on conflict (patch_number) do nothing;
