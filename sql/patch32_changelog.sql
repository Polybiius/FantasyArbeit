-- ============================================================
-- PATCH 32 — Changelog-Popup für angewendete SQL-Patches
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Jeder künftige Patch trägt sich am Ende selbst hier ein (siehe letzte
-- Zeile dieser Datei als Beispiel) - damit weiß die laufende App live,
-- welche Patches auf DIESER Datenbank wirklich schon angewendet wurden
-- (nicht nur, welche SQL-Dateien im Repo existieren). Beim nächsten Login
-- sieht jedes Team-Mitglied ein Popup mit allem, was seit dem letzten
-- eigenen Login neu dazugekommen ist - auch mehrere verpasste Patches auf
-- einmal, falls jemand länger nicht eingeloggt war. Der angezeigte Titel
-- kommt automatisch aus der Kopfzeile jeder Patch-Datei (siehe oben,
-- "PATCH N — ..."), kein zusätzlicher Handschreib-Schritt für den Admin.
create table if not exists public.schema_patches (
  patch_number integer primary key,
  title text not null,
  applied_at timestamptz not null default now()
);

alter table public.schema_patches enable row level security;

-- Lesen darf jede eingeloggte Person - die Tabelle beschreibt den Zustand
-- der gesamten Datenbank, nicht einer einzelnen Organisation, deshalb kein
-- org_id-Bezug wie sonst üblich. Schreiben passiert ausschließlich über den
-- SQL-Editor (mit vollen Rechten, umgeht RLS) - keine Insert/Update/Delete-
-- Policy für normale Nutzer nötig.
create policy schema_patches_select_all on public.schema_patches
  for select using (auth.uid() is not null);

-- "Zuletzt gesehener Patch" pro Person.
alter table public.profiles add column if not exists last_seen_patch_number integer;

-- Neue Profile starten automatisch "auf dem aktuellen Stand" - niemand soll
-- bei der allerersten Anmeldung mit der kompletten bisherigen Patch-Historie
-- begrüßt werden, das Popup ist nur für echte Neuerungen AB JETZT gedacht.
create or replace function public.set_initial_seen_patch()
returns trigger language plpgsql as $$
begin
  if new.last_seen_patch_number is null then
    new.last_seen_patch_number := coalesce((select max(patch_number) from public.schema_patches), 0);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_initial_seen_patch on public.profiles;
create trigger trg_set_initial_seen_patch
  before insert on public.profiles
  for each row execute function public.set_initial_seen_patch();

-- Dieser Patch selbst trägt sich ein (Beispiel für alle künftigen Patches:
-- diese Zeile einfach mit neuem patch_number/title kopieren und ans Ende
-- der jeweiligen Datei hängen).
insert into public.schema_patches (patch_number, title) values
  (32, 'Changelog-Popup für angewendete SQL-Patches')
on conflict (patch_number) do nothing;

-- Bestehende Profile ebenfalls auf "gesehen bis hierhin" setzen - sonst
-- würde dieser Patch selbst rückwirkend als Popup bei allen aufploppen, was
-- für eine reine Infrastruktur-Änderung nicht sinnvoll ist.
update public.profiles set last_seen_patch_number = 32 where last_seen_patch_number is null;
