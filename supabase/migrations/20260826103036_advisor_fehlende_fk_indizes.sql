-- Supabase-Advisor-Triage, Schritt 1: fehlende Indizes auf Fremdschlüsseln.
-- Betrifft Tabellen, die nach der urspruenglichen FK-Index-Haertung
-- (Patch 17/17b) entstanden sind - reine Performance-Vorsorge fuer
-- kuenftiges Datenwachstum, keine Verhaltensaenderung, kein Berechtigungsbezug.
-- Quelle: `supabase db advisors --linked --type all --level info`, 2026-08-26.

create index if not exists guild_invitations_invited_by_idx
  on public.guild_invitations (invited_by);

create index if not exists guild_invitations_org_id_idx
  on public.guild_invitations (org_id);

create index if not exists guild_quest_log_org_id_idx
  on public.guild_quest_log (org_id);

create index if not exists security_alerts_user_id_idx
  on public.security_alerts (user_id);

create index if not exists tasks_contact_id_idx
  on public.tasks (contact_id);

create index if not exists tasks_org_id_idx
  on public.tasks (org_id);

create index if not exists termin_invitations_contact_id_idx
  on public.termin_invitations (contact_id);

create index if not exists termin_invitations_invitee_termin_id_idx
  on public.termin_invitations (invitee_termin_id);

create index if not exists termin_invitations_org_id_idx
  on public.termin_invitations (org_id);

create index if not exists termin_invitations_organizer_id_idx
  on public.termin_invitations (organizer_id);

create index if not exists termine_organizer_id_idx
  on public.termine (organizer_id);
