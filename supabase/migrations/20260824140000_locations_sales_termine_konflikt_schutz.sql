-- ============================================================
-- Konflikt-Schutz bei gleichzeitiger Bearbeitung, Fortsetzung: locations/
-- sales/termine/termin_series, 2026-08-24. Erste Runde (contacts) war
-- 20260824130000_contacts_konflikt_schutz.sql -- gleiches Muster,
-- priorisiert nach echtem Mehrfach-Schreiber-Risiko (siehe CLAUDE.md):
--
-- - locations (Dungeons): gilden-geteilter Pool, Gildenführer/Admin
--   können denselben Dungeon anfassen (Gilden-Pool-Aufnahme,
--   Account-Zuweisung).
-- - sales: Eigentümer ODER Admin kann denselben Verkauf als
--   gekündigt/ausgelaufen markieren.
-- - termine/termin_series: Admin darf laut RLS-Policy auch fremde
--   Termine/Serien bearbeiten (termine_update_owner_or_admin/
--   termin_series_update_owner_or_admin) -- seltener, aber echter Fall.
--
-- Keine dieser vier Tabellen hatte bisher ein updated_at-Feld -- anders
-- als bei contacts (das Feld existierte dort schon, nur ungepflegt) muss
-- es hier zuerst angelegt werden. Gleiches Trigger-Prinzip wie bei
-- contacts: ignoriert IMMER jeden vom Client mitgeschickten Wert, setzt
-- ausschließlich echtes now() -- sonst könnte ein direkter API-Aufruf die
-- Schutzprüfung durch einen alten, mitgeschickten Zeitstempel aushebeln.
-- Kein SECURITY DEFINER nötig, reine Datenqualitäts-Absicherung zwischen
-- zwei ehrlichen Nutzern, keine Zugriffskontrolle -- wer schreiben darf,
-- regelt weiterhin unverändert die bestehende RLS-Policy je Tabelle.
--
-- Bewusst NICHT angefasst: der automatische generated_until-Fortschritts-
-- marker in topUpSeries() (termin_series) -- das ist reine interne
-- Hintergrund-Buchhaltung eines Systemvorgangs, keine Nutzer-Bearbeitung,
-- für die dieser Schutz gedacht ist.
-- ============================================================

alter table public.locations add column if not exists updated_at timestamptz not null default now();
alter table public.sales add column if not exists updated_at timestamptz not null default now();
alter table public.termine add column if not exists updated_at timestamptz not null default now();
alter table public.termin_series add column if not exists updated_at timestamptz not null default now();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_locations_updated_at on public.locations;
create trigger trg_touch_locations_updated_at
  before update on public.locations
  for each row
  execute function public.touch_updated_at();

drop trigger if exists trg_touch_sales_updated_at on public.sales;
create trigger trg_touch_sales_updated_at
  before update on public.sales
  for each row
  execute function public.touch_updated_at();

drop trigger if exists trg_touch_termine_updated_at on public.termine;
create trigger trg_touch_termine_updated_at
  before update on public.termine
  for each row
  execute function public.touch_updated_at();

drop trigger if exists trg_touch_termin_series_updated_at on public.termin_series;
create trigger trg_touch_termin_series_updated_at
  before update on public.termin_series
  for each row
  execute function public.touch_updated_at();
