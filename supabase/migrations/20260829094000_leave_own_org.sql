-- PATCH: Organisation verlassen (Austritt zurück in den Pool)
--
-- Neue, eigenständige Operation -- Account/Charakter bleibt bestehen,
-- nur org_id/role werden zurückgesetzt. Ausdrücklicher Nutzerwunsch:
-- Level/XP/bereits gewonnene Items bleiben beim Austritt (und bei einem
-- späteren erneuten Beitritt/Gründen) unverändert erhalten -- diese
-- Migration rührt total_xp/level/user_inventory/action_log deshalb
-- bewusst NICHT an:
--   - action_log/user_inventory sind bereits vollständig portabel
--     (inventory_select_own/log_select_own filtern nur auf
--     user_id = auth.uid(), keine org_id-Einschränkung) -- keine
--     Anpassung nötig.
--   - sync_own_level_cache() lehnt Aufrufe mit org_id IS NULL ohnehin
--     ab (bestehendes Verhalten, siehe Funktion selbst) -- im
--     Pool-Zustand wird sie schlicht nicht aufgerufen, der zuletzt
--     synchronisierte total_xp/level-Stand bleibt automatisch stehen.
--
-- Die bestehende Nachfolge-Logik für einen ausscheidenden
-- Gildenführer (handle_member_offboarding(), Patch
-- 20260808213214_gilden_notfall_nachfolge) wird als eigene Funktion
-- herausgezogen (reassign_guild_founder_on_departure) -- identisches
-- Verhalten, jetzt aber aus ZWEI Kontexten aufrufbar: dem bestehenden
-- BEFORE-DELETE-Trigger auf auth.users UND dieser neuen Funktion, die
-- in einem völlig anderen Kontext läuft (kein Zeilen-Löschen, der
-- Account bleibt bestehen).
--
-- Nutzer-Entscheidung nachgereicht (Rückfrage nach dem ersten Dry-Run/
-- der Zweitmeinungsrunde): die BESTEHENDE Account-Löschung stellt ihr
-- "gildenlos -> hart löschen"-Verhalten JETZT ebenfalls auf "Org-Pool"
-- um -- Begründung des Nutzers wörtlich: "die bleiben bei der Firma,
-- weil die Verträge laufen ja über die Firma." Betrifft ausschließlich
-- Kontakte/Dungeons eines Org-Mitglieds OHNE eigene Gilde (ein reiner
-- Pool-Nutzer ohne Org kann per Konstruktion gar keine Kontakte
-- besitzen, contacts.org_id ist NOT NULL) -- Freundschaften
-- (`friends`) sind davon komplett unberührt, waren es auch vorher schon
-- (weder dieser Trigger noch leave_own_org() rühren die Tabelle an --
-- eine Freundschaft endet nie automatisch durch Firmen-/Gildenwechsel,
-- nur durch bewusstes manuelles Entfernen).
--
-- Beim Dry-Run-Test dieser Migration selbst gefunden (unabhängig von
-- allem oben, ein eigenständiger, vorbestehender Bug seit 2026-08-22):
-- protect_location_owner_field() (Migration
-- 20260822120000_locations_owner_tamper_schutz.sql) korrigiert JEDE
-- owner_id-Änderung an einem Dungeon still zurück, wenn is_admin() zum
-- Ausführungszeitpunkt falsch ist -- betrifft nicht nur normale Client-
-- Updates, sondern GENAUSO die owner_id-Umverteilung, die
-- handle_member_offboarding() (bestehend, seit 2026-08-08) und das neue
-- leave_own_org() selbst auslösen: ein austretendes/gelöschtes
-- Nicht-Admin-Mitglied ist selbst kein Admin, der Trigger revertierte
-- die eigene owner_id=NULL-Zuweisung deshalb bisher unbemerkt wieder --
-- mit Folgefehler (FK-Verletzung beim Cascade auf profiles), sobald das
-- betroffene Konto anschließend tatsächlich gelöscht wird. Fix: gleiche
-- Sitzungs-Flag-Technik wie an den anderen Stellen dieser Migration
-- (app.trusted_location_owner_change), gesetzt von genau den beiden
-- vertrauenswürdigen Funktionen, die diese Umverteilung durchführen.
-- assign_location_owner_locked() (Admin-only) ist von diesem Fix nicht
-- betroffen -- dort ist is_admin() zum Ausführungszeitpunkt ohnehin
-- schon garantiert wahr, der Trigger greift dort nie ein.

begin;

-- === Fix: protect_location_owner_field() erlaubt jetzt zusätzlich einen
-- vertrauenswürdigen Sitzungs-Flag-Bypass (siehe Kommentar oben) ===
create or replace function public.protect_location_owner_field()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin()
     and coalesce(current_setting('app.trusted_location_owner_change', true), 'false') <> 'true'
     and new.owner_id is distinct from old.owner_id then
    perform public.log_security_alert(auth.uid(), 'location_owner_tamper',
      format('Versuchte owner_id-Änderung an Dungeon %s: %s -> %s', old.id, old.owner_id, new.owner_id));
    new.owner_id := old.owner_id;
  end if;
  return new;
end;
$function$;

-- === Nachfolge-Logik, wortgleich aus handle_member_offboarding()
-- herausgezogen (siehe 20260808213214_gilden_notfall_nachfolge.sql) ===
create or replace function public.reassign_guild_founder_on_departure(p_leaving_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_founded_guild uuid;
  v_successor uuid;
begin
  select id into v_founded_guild from public.guilds where founder_id = p_leaving_id;
  if v_founded_guild is null then
    return;
  end if;

  select member_id into v_successor from public.guild_members
    where guild_id = v_founded_guild and member_id <> p_leaving_id and team_rights = true
    order by joined_at asc limit 1;

  if v_successor is null then
    -- kein Teamleiter vorhanden: laengstes Mitglied insgesamt uebernimmt
    select member_id into v_successor from public.guild_members
      where guild_id = v_founded_guild and member_id <> p_leaving_id
      order by joined_at asc limit 1;
  end if;

  if v_successor is not null then
    update public.guilds set founder_id = v_successor where id = v_founded_guild;
    update public.guild_members set contacts_access = 'write', dungeons_access = 'write', team_rights = true
      where guild_id = v_founded_guild and member_id = v_successor;
  else
    -- Kein Nachfolger gefunden: founder_id MUSS hier explizit auf NULL
    -- gesetzt werden. Im ursprünglichen Trigger-Kontext (Account-
    -- Löschung) übernahm das bisher unbemerkt die guilds_founder_id_fkey
    -- ON DELETE SET NULL-Klausel automatisch, weil die profiles-Zeile
    -- gleich darauf per CASCADE mitgelöscht wurde. Im neuen
    -- leave_own_org()-Kontext bleibt die profiles-Zeile aber bestehen
    -- (Account überlebt den Org-Austritt) -- ohne diese explizite
    -- Zeile bliebe founder_id fälschlich auf der ausscheidenden Person
    -- stehen. Für den Trigger-Kontext ist das schlicht ein no-op-
    -- Duplikat der ohnehin gleich folgenden FK-Kaskade, ändert dort
    -- also nichts.
    update public.guilds set founder_id = null where id = v_founded_guild;
  end if;
  -- Die Gilde samt Pool-Kontakten/-Dungeons bleibt in beiden Fällen
  -- (mit oder ohne Nachfolger) bestehen, wird nie gelöscht.
end;
$$;

-- Rein interne Hilfsfunktion, nie über RPC direkt aufrufbar -- nimmt
-- eine beliebige p_leaving_id ohne eigene auth.uid()-Prüfung entgegen
-- (das ist beabsichtigt: der TRIGGER-Kontext übergibt old.id einer
-- GERADE GELÖSCHTEN fremden Person, kein "eigener" Aufruf). Ohne dieses
-- Revoke wäre sie -- wie jede neue Funktion im Schema public -- über
-- ALTER DEFAULT PRIVILEGES automatisch für anon/authenticated per RPC
-- ausführbar, und jeder eingeloggte Nutzer könnte damit gezielt den
-- Gildenführer irgendeiner fremden Gilde austauschen (per
-- Zweitmeinungsrunde gefunden, vor dem Push behoben) -- gleiches Muster
-- wie auto_delete_inactive_contacts() (nur für pg_cron/interne Aufrufer
-- gedacht).
revoke execute on function public.reassign_guild_founder_on_departure(uuid) from public, anon, authenticated;

-- === handle_member_offboarding() ruft jetzt die ausgelagerte Funktion
-- auf, statt die Logik zu duplizieren -- Verhalten identisch zu vorher ===
create or replace function public.handle_member_offboarding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guild_id uuid;
begin
  perform public.reassign_guild_founder_on_departure(old.id);
  -- Bypass fuer protect_location_owner_field() (siehe Kommentar ganz
  -- oben in dieser Datei) -- ohne diesen Flag wuerde der Trigger die
  -- gleich folgenden owner_id=NULL-Zuweisungen still zuruecksetzen.
  perform set_config('app.trusted_location_owner_change', 'true', true);

  select guild_id into v_guild_id
    from public.guild_members
    where member_id = old.id;

  if v_guild_id is not null then
    -- Mit Gilde: Verlauf bleibt erhalten, wandert in den Gilden-Pool
    update public.contacts
      set owner_id = null, guild_id = v_guild_id
      where owner_id = old.id;
    update public.locations
      set owner_id = null, guild_id = coalesce(guild_id, v_guild_id)
      where owner_id = old.id;
  else
    -- Gildenlos: NICHT mehr hart geloescht (Verhaltensaenderung, siehe
    -- Kommentar oben -- Nutzer-Entscheidung "die bleiben bei der Firma,
    -- weil die Vertraege ja ueber die Firma laufen"). Wandert
    -- stattdessen in den Org-Pool (owner_id=null, guild_id=null),
    -- exakt wie beim neuen leave_own_org() fuer denselben Fall.
    update public.contacts set owner_id = null, guild_id = null where owner_id = old.id;
    update public.locations set owner_id = null, guild_id = null where owner_id = old.id;
  end if;

  return old;
end;
$$;

-- === leave_own_org(): Austritt, Account bleibt bestehen ===
create or replace function public.leave_own_org()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org_id uuid;
  v_guild_id uuid;
begin
  select org_id into v_org_id from public.profiles where id = v_uid;
  if v_org_id is null then
    raise exception 'Du bist keiner Organisation zugeordnet.';
  end if;

  perform public.reassign_guild_founder_on_departure(v_uid);
  -- Bypass fuer protect_location_owner_field() (siehe Kommentar ganz
  -- oben in dieser Datei) -- ein austretendes Nicht-Admin-Mitglied ist
  -- selbst kein Admin, ohne diesen Flag wuerde der Trigger die eigene
  -- owner_id=NULL-Zuweisung gleich wieder zuruecksetzen.
  perform set_config('app.trusted_location_owner_change', 'true', true);

  select guild_id into v_guild_id from public.guild_members where member_id = v_uid;

  if v_guild_id is not null then
    update public.contacts set owner_id = null, guild_id = v_guild_id where owner_id = v_uid;
    update public.locations set owner_id = null, guild_id = coalesce(guild_id, v_guild_id) where owner_id = v_uid;
    delete from public.guild_members where member_id = v_uid;
  else
    -- Gildenlos: Account bleibt bestehen, also KEIN hartes Loeschen --
    -- die Kontakte/Dungeons wandern stattdessen in den neuen Org-Pool
    -- (owner_id=null, guild_id=null). Dieser Pfad ist komplett neu, es
    -- gibt kein bestehendes Verhalten, das hier erhalten werden muesste.
    update public.contacts set owner_id = null, guild_id = null where owner_id = v_uid;
    update public.locations set owner_id = null, guild_id = null where owner_id = v_uid;
  end if;

  perform set_config('app.trusted_org_membership_change', 'true', true);
  update public.profiles set org_id = null, role = 'member' where id = v_uid;
  -- role wird auch fuer einen austretenden Admin auf 'member'
  -- zurueckgesetzt -- "Admin" ist ausserhalb einer Org bedeutungslos,
  -- sonst entstuende ein "Pool-Admin"-Zustand.
end;
$$;

grant execute on function public.leave_own_org() to authenticated;
revoke execute on function public.leave_own_org() from public, anon;

commit;
