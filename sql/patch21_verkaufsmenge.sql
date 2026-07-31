-- ============================================================
-- PATCH 21 — Menge pro Verkauf
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- Keine destruktive Operation: nur eine neue, nullable Spalte mit
-- Default 1 auf einer bestehenden Tabelle. Bestehende Zeilen in
-- `sales` bekommen automatisch Menge 1, nichts geht verloren.
-- ============================================================

-- Bisher war ein Verkauf nur "welches Produkt, gewonnen/verloren" —
-- jetzt kommt dazu, wie viel davon verkauft wurde (z.B. "Produkt X,
-- Menge 3"). Weiterhin ein Freitext-Produktname, kein Katalog (siehe
-- CLAUDE.md, Produktkatalog ist bewusst aufgeschoben).
alter table public.sales add column if not exists menge integer not null default 1;
