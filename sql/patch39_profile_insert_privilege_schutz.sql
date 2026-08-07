-- PATCH 39 — Rechte-Eskalation über profiles-INSERT schließen (Patch 38 deckte nur UPDATE ab)
--
-- Live bestätigt (2026-08-07, mit einem frischen Wegwerf-Testaccount,
-- kein bestehender Nutzer betroffen): "profiles_insert_self" prüft beim
-- allerersten Anlegen des eigenen Profils nur "id = auth.uid()" — ein
-- direkter POST an /rest/v1/profiles mit role:'admin' im Payload legt
-- sofort ein fertiges Admin-Profil an, komplett ohne die App oder den
-- Registrierungs-Bildschirm zu durchlaufen (der schickt selbst zwar immer
-- role:'member', aber das erzwingt nichts auf Datenbank-Seite). Patch 38
-- (BEFORE-UPDATE-Trigger) schützt nur nachträgliche Änderungen, nicht
-- diese allererste Zeile — getrennter Bug, getrennter Fix.
--
-- Da die App aktuell offene Selbstregistrierung erlaubt (kein Einladungs-
-- zwang), war das nicht nur ein Kollegen-Risiko, sondern von jedem
-- Internet-Besucher aus nutzbar, der die URL kennt.
--
-- Fix: BEFORE-INSERT-Trigger erzwingt role='member' für jede neue Zeile,
-- unabhängig vom mitgeschickten Wert — echte Admin-Rechte gibt's danach
-- nur noch per UPDATE durch einen bestehenden Admin (bereits durch Patch 38
-- geschützt). org_id wird zusätzlich auf die aktuell einzige Organisation
-- gezwungen, als zusätzliches Sicherheitsnetz — sobald echte Multi-Org-
-- Unterstützung gebaut wird (siehe "Technische Skalierungs-Schwellen" in
-- CLAUDE.md), muss diese Zeile neu gedacht werden. character_class bleibt
-- bewusst frei wählbar — das ist die legitime, einmalige Klassenwahl bei
-- der Charaktererstellung, kein Sicherheitsproblem.

create or replace function public.enforce_profile_insert_defaults()
returns trigger
language plpgsql
security definer
as $$
begin
  new.role := 'member';
  new.org_id := '00000000-0000-0000-0000-000000000001'::uuid;
  return new;
end;
$$;

drop trigger if exists trg_enforce_profile_insert_defaults on public.profiles;
create trigger trg_enforce_profile_insert_defaults
  before insert on public.profiles
  for each row execute function public.enforce_profile_insert_defaults();

insert into public.schema_patches (patch_number, title) values
  (39, 'Sicherheitsfix: profiles-INSERT erzwingt role=member (Patch 38 deckte nur UPDATE ab)')
on conflict (patch_number) do nothing;
