-- Schließt eine seit 2026-08-08 bestehende, bisher nicht dokumentierte
-- RLS-Lücke bei locations.owner_id -- gefunden vom Cross-File-Review-Agenten
-- in Häppchen 8 des systematischen Bugfix-Durchgangs (index.html, Abschnitt
-- "Dungeons (Karte)").
--
-- Hintergrund: locations_update_visible (RLS-Performance-Härtung,
-- 20260817210000) fasst die frühere locations_update_admin_only +
-- locations_update_guild_admission zusammen. Deren WITH CHECK prüft für
-- Nicht-Admins nur, ob guild_id auf eine Gilde zeigt, deren Gründer der
-- Ausführende ist -- owner_id selbst wird von KEINER WITH-CHECK-Klausel
-- geschützt (Postgres-RLS kann OLD.owner_id in WITH CHECK ohnehin nicht mit
-- vergleichen -- WITH CHECK sieht nur die NEUE Zeile). Diese Lücke bestand
-- bereits in der ursprünglichen locations_update_guild_admission-Policy vom
-- 2026-08-08 (siehe 20260808201900_phase1_fix_und_debug_aufraeumen.sql) --
-- die Performance-Härtung hat sie nur unverändert mit übernommen, nicht neu
-- eingeführt.
--
-- Auswirkung: ein Gildenführer (kein Org-Admin) kann per direktem
-- PATCH /rest/v1/locations owner_id eines Dungeons, den ein eigenes
-- Gildenmitglied besitzt, auf einen beliebigen Wert setzen (inkl. sich
-- selbst) -- obwohl CLAUDE.md/der Code-Kommentar in
-- 20260808195041_gilden_freigabe_phase1.sql ausdrücklich festhalten, dass
-- "Umverteilen bleibt Admin-exklusiv" (das Frontend zeigt renderAccountPool()
-- entsprechend auch nur Admins).
--
-- Fix, gleiches Muster wie protect_privileged_profile_fields() (Patch 38/47)
-- und enforce_guild_selfjoin_limits() (Patch 47): korrigieren statt
-- ablehnen, damit der Log-Eintrag nicht im selben Transaktions-Rollback
-- verloren geht. Kein Verhaltensunterschied für legitime Aufrufe -- das
-- Frontend ändert owner_id ausschließlich über renderAccountPool()
-- (admin-only sichtbar) und schickt es nie in einem Update, das ein
-- Nicht-Admin auslöst.
create or replace function public.protect_location_owner_field()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin() and new.owner_id is distinct from old.owner_id then
    perform public.log_security_alert(auth.uid(), 'location_owner_tamper',
      format('Versuchte owner_id-Änderung an Dungeon %s: %s -> %s', old.id, old.owner_id, new.owner_id));
    new.owner_id := old.owner_id;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_protect_location_owner on public.locations;
create trigger trg_protect_location_owner
  before update on public.locations
  for each row execute function public.protect_location_owner_field();
