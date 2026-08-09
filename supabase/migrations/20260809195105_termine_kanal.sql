-- Termine: Kanal-Feld (Online / Büro / Im Betrieb)
--
-- Bisher hatte ein Termin nur Titel + Zeit + optionalen Kontakt/Betrieb —
-- kein Feld, das festhält, ob er online, im eigenen Büro oder beim
-- Kunden/Betrieb (Krankenhaus/Praxis) stattfand. Wird beim Eintragen eines
-- Termins direkt mit erfasst (kein Pflichtfeld, alte Zeilen bleiben NULL).
-- Werte sind plain text ('online'|'buero'|'betrieb'), kein CHECK-Constraint —
-- gleiches Muster wie contacts.status/kanban_stage, Validierung passiert im
-- Frontend.
--
-- termin_series bekommt dasselbe Feld, damit eine Wiederholungsregel ihren
-- Kanal an jeden materialisierten Termin weitergibt (topUpSeries()).

alter table public.termine add column kanal text;
alter table public.termin_series add column kanal text;

insert into public.schema_patches (patch_number, title) values
  (40, 'Termine: Kanal-Feld (Online/Büro/Im Betrieb)');
