-- ============================================================
-- PATCH 34 — Wochenenden in der Kalender-Wochenansicht ausblendbar
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Ergänzt Patch 33 (Termin-Kalender): ein Tag ohne hinterlegte Arbeitszeit
-- gilt jetzt als komplett arbeitsfrei (ganztägig abgedunkelt in der
-- Wochenansicht) statt wie zuvor fälschlich ungegraut. Zusätzlich lässt
-- sich einstellen, ob Samstag/Sonntag in der Wochenansicht überhaupt als
-- Spalten erscheinen sollen oder ganz ausgeblendet werden (Outlooks
-- "Arbeitswoche"-Ansicht) — Standard bleibt "anzeigen" (false), damit sich
-- an der bestehenden Optik nichts ändert, bis jemand die Einstellung aktiv
-- umschaltet.
alter table public.profiles add column if not exists calendar_hide_weekends boolean not null default false;

insert into public.schema_patches (patch_number, title) values
  (34, 'Wochenenden in der Kalender-Wochenansicht ausblendbar')
on conflict (patch_number) do nothing;
