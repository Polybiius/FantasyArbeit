-- PATCH: Plausibilitätsgrenze für contacts.geburtsdatum
--
-- Auslöser: direkter Nutzer-Fund im Arkanen Register -- als Geburtsdatum
-- ließ sich klaglos ein Datum in der Zukunft (z.B. 02.09.2026) eintragen,
-- ohne jede Grenze. Gleiches Muster wie die termine-Datumsgrenzen vom
-- selben Tag und die sales-Plausibilitätsgrenzen vom 2026-08-15: eine
-- großzügige Grenze, die reale Nutzung nie stört, nur offensichtlichen
-- Unsinn blockt. current_date ist hier bewusst zulässig (anders als bei
-- den termine-Grenzen, die auf festen Literalen bleiben) -- ein einmal
-- korrekt eingetragenes Geburtsdatum bleibt für immer korrekt, es gibt
-- keinen Effekt durch spätere Neubewertung, da CHECK-Constraints nur bei
-- INSERT/UPDATE ausgewertet werden, nicht fortlaufend.

alter table public.contacts
  add constraint contacts_geburtsdatum_range
  check (geburtsdatum is null or (geburtsdatum >= '1900-01-01' and geburtsdatum <= current_date));
