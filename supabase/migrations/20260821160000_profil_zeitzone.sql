-- Zeitraster-Vereinheitlichung, Fortsetzung (2026-08-21): eigene Zeitzone
-- pro Nutzer, nach dem Salesforce-/Outlook-Muster -- geht in tz() (index.html)
-- vor der Organisations-Zeitzone (organizations.timezone), Fallback bleibt
-- 'Europe/Berlin'. Nullable, kein Constraint noetig: leer = "Standard der
-- Organisation verwenden", genau wie profiles.arbeitszeiten kein Pflichtfeld
-- ist. Keine Berechtigungs-/Sicherheitsrelevanz (anders als role/
-- character_class/org_id) -- normale profiles_update_own-Policy deckt das
-- bereits ab, kein Trigger-Schutz noetig.

alter table public.profiles
  add column timezone text;
