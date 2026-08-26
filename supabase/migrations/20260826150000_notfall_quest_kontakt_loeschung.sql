-- PATCH: Notfall-Quest vor automatischer Kontakt-Loeschung (Sonderquest)
--
-- Idee vom Nutzer am 2026-08-25 im Anschluss an die automatische Loeschung
-- inaktiver Kontakte vorgeschlagen (siehe CLAUDE.md, "Bewusst
-- aufgeschobene Ideen"), am 2026-08-26 konkretisiert: eine Sonderquest-
-- Kachel in den taeglichen Quests, 1 Monat bevor ein Kontakt ohne jemals
-- gewonnenen Vertrag automatisch geloescht wird ("Vorname Nachname
-- kontaktieren", Loeschdatum als Unterzeile, dezent farblich hervorgehoben).
--
-- Reine Lese-Funktion, kein neuer Schreibpfad -- fest auf den eingeloggten
-- Nutzer verdrahtet (auth.uid() intern, kein Parameter von aussen),
-- liefert nur die EIGENEN Kontakte der aufrufenden Person, nie fremde.
-- Spiegelt exakt denselben Aktivitaets-Anker wie
-- auto_delete_inactive_contacts() (Migration
-- 20260825201448_contact_consent_und_auto_delete.sql) -- bei kuenftigen
-- Aenderungen an diesem Anker BEIDE Funktionen anfassen, sonst laufen
-- Warnung und tatsaechliche Loeschung auseinander.
--
-- Nutzerentscheidungen 2026-08-26: kein Extra-XP-Bonus fuers Retten (die
-- normale Aktions-XP, mit der der Kontakt beruehrt wird, reicht),
-- ALLE betroffenen Kontakte werden gleichzeitig als eigene Kachel gezeigt.
--
-- Performance: alle noetigen FK-Indizes existieren bereits
-- (contacts.owner_id, contact_activities(contact_id,occurred_at),
-- termine.contact_id, action_log.contact_id, contact_files.contact_id)
-- -- der own_contacts-Filter (owner_id=auth.uid()) grenzt VOR dem
-- Lateral-Join auf die typischerweise kleine eigene Kontaktmenge ein.
--
-- Erweiterbarkeit (siehe CLAUDE.md, "Sonderquest-Hinweise"): der Nutzer
-- plant, kuenftig weitere, noch nicht konkretisierte automatisierte
-- Hinweise an dasselbe Kachel-System anzuhaengen -- bewusst KEINE
-- generische Tabelle/Funktion dafuer vorgebaut, siehe Schwellenwert dort
-- (Rule of Three: erst ab dem dritten Hinweistyp verallgemeinern).

begin;

create or replace function public.contacts_pending_deletion_for_self()
returns table(contact_id uuid, vorname text, nachname text, deletion_date date)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_enabled boolean;
  v_months int;
begin
  select coalesce((rc.config->'contactAutoDelete'->>'enabled')::boolean, false),
         greatest(coalesce((rc.config->'contactAutoDelete'->>'monthsInactive')::int, 6), 1)
    into v_enabled, v_months
  from public.rule_configs rc
  where rc.org_id = current_org_id();

  if not coalesce(v_enabled, false) then
    return;
  end if;

  return query
  with own_contacts as (
    select c.id, c.vorname, c.nachname, c.created_at, c.updated_at, c.naechster_kontakt
    from public.contacts c
    where c.owner_id = auth.uid()
      and c.org_id = current_org_id()
      and not exists (
        select 1 from public.sales s
        where s.contact_id = c.id and s.status = 'gewonnen'
      )
  )
  select
    oc.id,
    oc.vorname,
    oc.nachname,
    (anchor.last_activity + (v_months || ' months')::interval)::date as deletion_date
  from own_contacts oc
  cross join lateral (
    select greatest(
      oc.created_at,
      oc.updated_at,
      coalesce(oc.naechster_kontakt::timestamptz, oc.created_at),
      coalesce((select max(ca.occurred_at) from public.contact_activities ca where ca.contact_id = oc.id), oc.created_at),
      coalesce((select max(t.start_at) from public.termine t where t.contact_id = oc.id), oc.created_at),
      coalesce((select max(al.created_at) from public.action_log al where al.contact_id = oc.id), oc.created_at),
      coalesce((select max(cf.created_at) from public.contact_files cf where cf.contact_id = oc.id), oc.created_at)
    ) as last_activity
  ) anchor
  -- >= statt > current_date (Zweitmeinungs-Fund): der Cron-Lauf löscht
  -- erst um 03:17 UTC -- am Tag der eigentlichen Löschung selbst muss die
  -- Warnung noch sichtbar sein, das ist der letzte mögliche Rettungstag.
  where (anchor.last_activity + (v_months || ' months')::interval)::date >= current_date
    and (anchor.last_activity + (v_months || ' months')::interval)::date <= current_date + 30;
end;
$$;

-- Neue Funktionen im Schema public bekommen automatisch EXECUTE fuer
-- public/anon ueber die bestehenden ALTER DEFAULT PRIVILEGES-Regeln
-- (siehe CLAUDE.md, "Stolperstein beim revoke execute") -- explizit
-- zurücknehmen, obwohl die Funktion selbst harmlos waere (anon hat kein
-- gueltiges auth.uid(), current_org_id() wuerde ohnehin leer/NULL liefern).
revoke execute on function public.contacts_pending_deletion_for_self() from public, anon;

insert into public.schema_patches (patch_number, title) values
  (54, 'Notfall-Quest: Sonderquest-Kachel vor automatischer Kontakt-Loeschung')
on conflict (patch_number) do nothing;

commit;
