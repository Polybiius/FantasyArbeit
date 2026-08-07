-- PATCH 38 — Rechte-Eskalation über profiles.role/character_class/org_id schließen
--
-- Hintergrund: "profiles_update_own" erlaubt jedem Nutzer, seine eigene
-- profiles-Zeile zu aktualisieren, geprüft nur über "id = auth.uid()".
-- Da Postgres bei fehlender WITH-CHECK-Klausel die USING-Klausel dafür
-- wiederverwendet, wird lediglich verhindert, dass jemand die eigene id
-- ändert — NICHT, welche anderen Spalten er dabei mitschickt. Live per
-- Playwright + direktem PostgREST-Aufruf verifiziert (2026-08-07): ein
-- normaler Nutzer kann per PATCH auf /rest/v1/profiles seine eigene
-- role auf 'admin' setzen und wird damit sofort is_admin() — das öffnet
-- error_log, Produktpflege, Regelwerk-Bearbeitung usw. Ebenso frei
-- änderbar wären character_class (soll laut Konzept "einmalig, dauerhaft"
-- sein) und org_id.
--
-- Fix: ein BEFORE-UPDATE-Trigger blockiert Änderungen an role/
-- character_class/org_id, außer der ausführende Nutzer ist bereits Admin
-- (deckt weiterhin den bestehenden Admin-Debug-Weg "🎭 Neu erschaffen" und
-- echte Rollenvergabe durch einen Admin ab — dort läuft ohnehin schon
-- is_admin() über die vorhandene "profiles_update_admin"-Policy).
-- Nicht destruktiv, keine Daten betroffen, rein additiv.

create or replace function public.protect_privileged_profile_fields()
returns trigger
language plpgsql
security definer
as $$
begin
  if not public.is_admin() then
    if new.role is distinct from old.role then
      raise exception 'Nur Admins dürfen die Rolle ändern.';
    end if;
    if new.character_class is distinct from old.character_class then
      raise exception 'Die Charakterklasse kann nicht direkt geändert werden.';
    end if;
    if new.org_id is distinct from old.org_id then
      raise exception 'org_id kann nicht direkt geändert werden.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_privileged_profile_fields on public.profiles;
create trigger trg_protect_privileged_profile_fields
  before update on public.profiles
  for each row execute function public.protect_privileged_profile_fields();

insert into public.schema_patches (patch_number, title) values
  (38, 'Sicherheitsfix: role/character_class/org_id vor Selbst-Änderung geschützt')
on conflict (patch_number) do nothing;
