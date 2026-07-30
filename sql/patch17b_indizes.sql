-- ============================================================
-- PATCH 17b — Fehlende Indizes auf Fremdschlüssel-Spalten
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
--
-- Hintergrund: Postgres indiziert Fremdschlüssel NICHT automatisch
-- (nur den Primärschlüssel einer Tabelle). Bisher gab es außer auf
-- action_log (schema.sql) keine Indizes — jede über RLS gefilterte
-- Abfrage (praktisch jede Abfrage, gefiltert nach org_id) durchsucht
-- also die komplette Tabelle. Bei einer Organisation mit wenigen
-- Kontakten unmerklich, bei vielen Organisationen/vielen Kontakten
-- zunehmend spürbar. Rein additiv, keine Verhaltensänderung.
-- ============================================================

create index if not exists contacts_org_idx on public.contacts(org_id);
create index if not exists contacts_owner_idx on public.contacts(owner_id);
create index if not exists contacts_location_idx on public.contacts(location_id);

create index if not exists locations_org_idx on public.locations(org_id);

create index if not exists sales_contact_idx on public.sales(contact_id);
create index if not exists sales_org_idx on public.sales(org_id);

create index if not exists profiles_org_idx on public.profiles(org_id);
