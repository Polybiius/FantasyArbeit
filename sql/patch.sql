-- ============================================================
-- PATCH — einmal ausführen, BEVOR die App zum ersten Mal genutzt wird
-- (SQL Editor -> New query -> einfügen -> Run)
-- ============================================================

-- 1) Fehlende Regel: ein neu registrierter Nutzer darf sein EIGENES
--    Profil anlegen (beim allerersten Login). Ohne diese Regel
--    würde die App aus Sicherheitsgründen sonst nichts einfügen dürfen.
create policy "profiles_insert_self" on public.profiles
  for insert with check (id = auth.uid());

-- 2) Zusätzliches Feld im Log, um Quest-/Ketten-Boni sauber zuordnen
--    zu können (z.B. "welche Quest, welcher Zeitraum" bzw.
--    "welche Kette, welche Stufe") ohne für jeden Zweck eine eigene Spalte
--    anzulegen. jsonb = flexibler Container für strukturierte Zusatzdaten.
alter table public.action_log add column if not exists meta jsonb;
