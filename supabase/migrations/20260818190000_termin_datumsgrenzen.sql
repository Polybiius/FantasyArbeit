-- PATCH: Plausibilitätsgrenzen für Termin-Datumsfelder
--
-- Auslöser: ein Nutzer-gemeldeter "verschwundener" Ersttermin stellte sich
-- als kaputtes Jahr heraus (0202 statt 2026, vermutlich durch mid-typing-
-- Zustand des nativen <input type="date">, ausgelöst über einen separat
-- behobenen Kanban-Listener-Stacking-Bug) -- ohne jede Plausibilitätsgrenze
-- akzeptiert termine/termin_series jedes beliebige Jahr klaglos, der Termin
-- verschwand dadurch einfach unsichtbar aus jeder Kalenderansicht.
--
-- Gleiches Muster wie die sales-Plausibilitätsgrenzen vom 2026-08-15
-- (sales_bewertungssumme_range/sales_menge_range): großzügige feste
-- Jahresgrenzen, die reale Nutzung nie stören, nur offensichtlichen Unsinn
-- (Tippfehler, kaputte Clients) blocken. Bewusst KEINE relative now()-Grenze
-- -- feste Literale sind einfacher nachvollziehbar und brauchen erst in
-- ~14 Jahren eine einmalige Anpassung (kein CI/CD, kein automatischer
-- Ablauf-Alarm nötig für diesen Zeithorizont).

alter table public.termine
  add constraint termine_start_at_range check (start_at >= '2020-01-01' and start_at < '2041-01-01'),
  add constraint termine_end_at_range check (end_at >= '2020-01-01' and end_at < '2041-01-01');

alter table public.termin_series
  add constraint termin_series_start_date_range check (start_date >= '2020-01-01' and start_date < '2041-01-01'),
  add constraint termin_series_until_date_range check (until_date is null or (until_date >= '2020-01-01' and until_date < '2041-01-01')),
  add constraint termin_series_generated_until_range check (generated_until >= '2020-01-01' and generated_until < '2041-01-01');
