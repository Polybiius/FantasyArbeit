-- ============================================================
-- PATCH 35 — Geburtstage im Kalender + produktweite Nachfass-Empfehlung
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- Teil 1: Ein/Aus-Schalter pro Person, ob Geburtstage der eigenen Kontakte
-- als nicht-blockierender Hinweis im Kalender erscheinen sollen (Wochen- und
-- Monatsansicht). Standard: an (true) — die Geburtstage selbst stecken schon
-- länger in contacts.geburtsdatum (Patch 15), hier kommt nur die
-- Kalender-Anzeige + der Schalter dazu, keine neue Geburtsdatum-Spalte.
alter table public.profiles add column if not exists calendar_show_birthdays boolean not null default true;

-- Teil 2: produktweite Nachfass-Empfehlung ("nach Vertragsbeginn wieder beim
-- Kunden melden"). Reine Empfehlung, kein Zwang — füllt im "Gewonnen"-Popup
-- nur das Wiedervorlage-Datum vor, überschreibbar. Zahl + Einheit getrennt
-- (nicht z.B. immer Tage), weil eine Berufshaftpflicht in Monaten gedacht
-- wird, eine Immobilienfinanzierung eher in Jahren (Prolongation).
alter table public.products add column if not exists recontact_amount integer;
alter table public.products add column if not exists recontact_unit text
  check (recontact_unit in ('tage','wochen','monate','jahre'));

insert into public.schema_patches (patch_number, title) values
  (35, 'Geburtstage im Kalender + produktweite Nachfass-Empfehlung')
on conflict (patch_number) do nothing;
