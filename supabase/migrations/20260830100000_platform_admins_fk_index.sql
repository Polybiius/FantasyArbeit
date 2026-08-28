-- PATCH: fehlender FK-Index auf platform_admins.added_by
--
-- Vom Supabase-Advisor direkt nach dem Push der Fundament-Migrationen
-- gefunden (unindexed_foreign_keys). Reiner Struktur-Fix ohne
-- Berechtigungsbezug -- keine Zweitmeinungs-Pflicht (siehe CLAUDE.md).
--
-- Rückbau: Index droppen.

begin;

create index platform_admins_added_by_idx on public.platform_admins(added_by);

commit;
