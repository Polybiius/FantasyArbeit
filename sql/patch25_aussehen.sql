-- ============================================================
-- PATCH 25 — Aussehen (Hautfarbe, Frisur)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- Keine destruktive Operation: nur zwei neue, nullable Spalten auf
-- einer bestehenden Tabelle. Bestehende Profile bleiben unverändert
-- (beide Felder bleiben dort leer/NULL, bis der neue Aussehen-Screen
-- einmal durchlaufen wurde).
-- ============================================================

-- Neuer Zwischenschritt bei der Charaktererstellung, nach der
-- Klassenwahl: Hautfarbe + Frisur. Beide Werte sind reine Schlüssel
-- in einen fest im Frontend hinterlegten Asset-Katalog (siehe
-- CREATOR-Kataloge in index.html) — die Frisur-Farbe (schwarz/braun/
-- blond/rot) ist dabei kein eigenes Feld, sondern steckt schon in der
-- gewählten Frisur selbst (jede Frisur hat eine feste Farbe).
alter table public.profiles add column if not exists skin_tone text;
alter table public.profiles add column if not exists hair_style text;
