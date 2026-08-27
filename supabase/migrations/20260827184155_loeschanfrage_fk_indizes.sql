-- Reiner Struktur-Fix (keine Berechtigungsänderung, kein Zweitmeinungs-
-- Gate nötig): Advisor-Nachlauf direkt nach der Löschanfrage-Migration
-- fand zwei fehlende FK-Indizes, gleiche Kategorie wie beim
-- Supabase-Advisor-Triage-Durchgang (11 FK-Indizes gebaut).

create index if not exists contact_deletion_requests_requested_by_idx
  on public.contact_deletion_requests(requested_by);
create index if not exists contact_deletion_requests_reviewed_by_idx
  on public.contact_deletion_requests(reviewed_by);
