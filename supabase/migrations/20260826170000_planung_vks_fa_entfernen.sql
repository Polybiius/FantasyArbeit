-- Entfernt zwei nie fertig zu Ende gedachte Planungsfelder
-- (profiles.planung_vks/planung_fa, "Planung Verkaufsgespräche"/
-- "Planung Fachkontakte (FA)") -- waren schon länger als
-- Eingabefelder in den Einstellungen sichtbar, aber ohne definierte
-- Zählquelle im Aktions-Log geblieben (siehe CLAUDE.md, "BWS-
-- Verrechnung", jetzt entfernt). Nutzer-Entscheidung 2026-08-26 beim
-- Versuch, das nachzuholen: die Idee "hat sich hereingeschlichen",
-- keine echte Anforderung dahinter -- komplett streichen statt
-- nachträglich eine Definition zu erfinden.
--
-- Gefahrlos: 0 von 8 Profilen hatten je einen Wert in einer der beiden
-- Spalten (per Abfrage gegen die echte DB bestätigt), keine
-- Fremdschlüssel/Policies/Funktionen referenzieren sie außerhalb ihrer
-- ursprünglichen Anlage.

begin;

alter table public.profiles
  drop column if exists planung_vks,
  drop column if exists planung_fa;

commit;
