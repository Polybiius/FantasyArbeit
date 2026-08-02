-- ============================================================
-- PATCH 24 — Profil-Onboarding (echter Name, Geschlecht, Unternehmen)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- Keine destruktive Operation: nur drei neue, nullable Spalten auf
-- einer bestehenden Tabelle. Bestehende Profile bleiben unverändert
-- (alle drei Felder bleiben dort leer/NULL, weil wir für längst
-- registrierte Konten keinen echten Namen/Geschlecht/Unternehmen
-- kennen — betrifft aktuell den Nutzer selbst und die zwei
-- Test-Kollegen).
-- ============================================================

-- Neuer Zwischenschritt bei der Charaktererstellung, vor der
-- Klassenwahl: echter Name, Geschlecht (steuert die Klassen-
-- bezeichnung: Hexer/Hexerin, Krieger/Kriegerin, Schütze/Schützin),
-- optionales Unternehmen (reines Freitext-Anzeigefeld, KEINE
-- Verknüpfung zum Mandanten-System `organizations` — bleibt bewusst
-- getrennt, siehe CLAUDE.md).
alter table public.profiles add column if not exists real_name text;
alter table public.profiles add column if not exists gender text check (gender in ('m','w'));
alter table public.profiles add column if not exists company text;
