-- ============================================================
-- PATCH 31 — Persönliche Planungsziele je Mitarbeiter
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Ergänzt Patch 30 (BWS-Verrechnung): die "Planung ..."-Eingabefelder aus
-- der vom Nutzer gelieferten Excel (Datenblatt!B9-B13) sind persönliche
-- Jahresziele je Mitarbeiter, keine organisationsweite Einstellung -
-- deshalb an profiles, nicht an rule_configs. Werden künftig auf der
-- neuen "Einstellungen"-Seite von jedem selbst eingetragen (siehe
-- CLAUDE.md), nicht vom Admin verwaltet.
alter table public.profiles add column if not exists planung_lv_bws numeric;
alter table public.profiles add column if not exists planung_kv_mb numeric;
alter table public.profiles add column if not exists planung_bwp numeric;
alter table public.profiles add column if not exists planung_vks numeric;
alter table public.profiles add column if not exists planung_fa numeric;
