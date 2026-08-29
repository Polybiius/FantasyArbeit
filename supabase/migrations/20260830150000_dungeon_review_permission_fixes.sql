-- PATCH: assign_location_owner_locked() -- Trusted-Flag-Bypass + Org-Grenze
--
-- Fund aus der 5-Linsen-Tiefenprüfung "Dungeons" (Phase 2 des
-- CLAUDE.md-Fahrplans), unabhängig von der Korrektheits- UND der
-- Cross-File-Linse bestätigt.
--
-- 1) Kritischer Fund: 20260830091000_org_pool_verteilung_gildenfuehrer.sql
-- (spaeter erneut per CREATE OR REPLACE in 20260830092000_pool_zuweisung_
-- log.sql definiert) hat assign_location_owner_locked() um einen Zweig
-- erweitert, der einem NICHT-Admin (dem alleinigen Gildenfuehrer einer
-- Ein-Gilde-Org) erlaubt, owner_id eines herrenlosen Dungeons zu setzen.
--
-- Der bestehende Trigger protect_location_owner_field() (zuletzt geaendert
-- in 20260829094000_leave_own_org.sql) blockt/korrigiert JEDE owner_id-
-- Aenderung zurueck, ausser der Aufrufer ist is_admin() ODER das
-- Sitzungs-Flag app.trusted_location_owner_change ist gesetzt.
-- 20260829094000 dokumentiert dazu woertlich: "assign_location_owner_
-- locked() (Admin-only) ist von diesem Fix nicht betroffen -- dort ist
-- is_admin() zum Ausfuehrungszeitpunkt ohnehin schon garantiert wahr" --
-- eine Annahme, die genau einen Tag spaeter durch den neuen
-- Gildenfuehrer-Zweig falsch wurde, ohne dass die Funktion nachgezogen
-- wurde.
--
-- Konkrete Auswirkung: ein alleiniger Gildenfuehrer ruft die Funktion fuer
-- einen echten Pool-Dungeon auf, die Autorisierungspruefung besteht, das
-- UPDATE laeuft -- der Trigger sieht "kein Admin, kein Trusted-Flag" und
-- setzt owner_id still auf den alten Wert (NULL) zurueck, PLUS protokolliert
-- einen location_owner_tamper-Sicherheitsalarm gegen die eigentlich
-- berechtigte Person. Da updated_at trotzdem neu gesetzt wird, liefert die
-- RPC weder error noch conflict zurueck -- das Frontend meldet Erfolg,
-- obwohl nie etwas zugewiesen wurde. Damit ist die Halfte des in CLAUDE.md
-- als "live" dokumentierten Org-Pool-Verteilungs-Features fuer Dungeons
-- faktisch wirkungslos. admin_reassign_contact() (Kontakte) hat kein
-- Aequivalent zu diesem Trigger und ist nicht betroffen.
--
-- Fix: assign_location_owner_locked() setzt das Trusted-Flag jetzt selbst,
-- direkt vor dem UPDATE -- gleiche Technik wie in leave_own_org()/
-- handle_member_offboarding(). Die Autorisierungspruefung selbst (wer darf
-- ueberhaupt aufrufen) bleibt unveraendert, der Flag-Bypass wirkt erst
-- NACH dieser Pruefung.
--
-- 2) Kleinerer Fund (Cross-File-Linse): anders als admin_reassign_contact()
-- validiert assign_location_owner_locked() an keiner Fassung, ob p_owner_id
-- ueberhaupt Mitglied der betroffenen Organisation ist. Ueber die
-- bestehende UI unkritisch (Dropdown listet nur Org-Mitglieder), aber bei
-- direktem RPC-Aufruf koennte owner_id auf eine organisationsfremde
-- Profil-ID gesetzt werden -- Datenkonsistenz-Luecke, kein Privilegien-
-- Escape. Fix: gleiche exists(...)-Pruefung wie bei admin_reassign_contact()
-- ergaenzt.
--
-- Rueckbau: assign_location_owner_locked() auf den Funktionskoerper aus
-- 20260830092000_pool_zuweisung_log.sql zuruecksetzen (perform set_config
-- + die neue exists-Pruefung wieder entfernen).

begin;

create or replace function public.assign_location_owner_locked(
  p_id uuid,
  p_owner_id uuid,
  p_expected_updated_at timestamptz
)
returns public.locations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.locations;
  updated_row public.locations;
begin
  select * into current_row from public.locations where id = p_id for update;
  if not found then
    raise exception 'Dungeon nicht gefunden' using errcode = '42501';
  end if;

  if not (
    is_admin_of(current_row.org_id)
    or (is_sole_guild_founder_of_org(current_row.org_id) and current_row.owner_id is null)
  ) then
    raise exception 'Nur Admins oder der alleinige Gildenführer der eigenen Organisation dürfen Dungeon-Accounts zuweisen (Gildenführer nur für herrenlose Pool-Dungeons)' using errcode = '42501';
  end if;

  if p_owner_id is not null and not exists (
    select 1 from public.profiles where id = p_owner_id and org_id = current_row.org_id
  ) then
    raise exception 'Zielperson ist nicht Mitglied dieser Organisation.';
  end if;

  -- Bypass fuer protect_location_owner_field() -- diese Funktion ist seit
  -- 20260830091000/092000 auch fuer Nicht-Admins (alleiniger Gildenfuehrer)
  -- aufrufbar, die Autorisierungspruefung oben hat zu diesem Zeitpunkt
  -- bereits stattgefunden.
  perform set_config('app.trusted_location_owner_change', 'true', true);

  update public.locations set owner_id = p_owner_id
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;

  insert into public.pool_zuweisung_log
    (org_id, entity_type, entity_id, entity_name_snapshot, new_owner_id, new_guild_id, assigned_by)
  values
    (updated_row.org_id, 'location', updated_row.id, updated_row.name, updated_row.owner_id, updated_row.guild_id, (select auth.uid()));

  return updated_row;
end;
$$;

commit;
