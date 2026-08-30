-- PATCH: auto_delete_inactive_contacts() -- Eigentümer-Ausnahme wieder
-- zurückgenommen, Nutzer-Korrektur direkt nach dem Kontakte-Review
--
-- 20260830160000 hatte Gilden-/Org-Pool-Kontakte (owner_id IS NULL)
-- komplett von der automatischen Inaktivitäts-Löschung ausgenommen --
-- Begründung damals: die 30-Tage-Sonderquest-Vorwarnung ist eigentümer-
-- gebunden und kann für einen Pool-Kontakt nie erscheinen, ein stilles
-- Löschen ohne jede Vorwarnungsmöglichkeit widerspräche dem "niemals
-- gelöscht"-Versprechen beim Mitarbeiter-Offboarding.
--
-- Nutzer-Klarstellung (2026-08-30, direkt im Anschluss an das Review):
-- "Herrenlose Kontakte in einer Gilde im Pool dürfen nach einem halben
-- Jahr gelöscht werden, wenn es keine Verträge gibt. Gibt es Verträge,
-- sind das einfach Kunden ohne Betreuung, aber sind ja immer noch Kunden
-- der Firma." -- ein herrenloser Pool-Kontakt OHNE Vertrag ist also ein
-- schlicht liegengebliebener Lead, den niemand in der Frist beansprucht
-- hat, und darf genauso automatisch gelöscht werden wie jeder andere
-- Kontakt ohne Vertrag auch. Der eigentlich schützenswerte Fall (ein
-- Kontakt MIT Vertrag) ist bereits unabhängig vom Eigentümer-Zustand
-- durch die bestehende "not exists (sales where status='gewonnen')"-
-- Bedingung abgedeckt -- die Eigentümer-Ausnahme aus 20260830160000 war
-- also zu weitgehend (schützte auch vertragslose Pool-Kontakte, die gar
-- keinen Schutz brauchen) und wird hier vollständig zurückgenommen.
--
-- Funktionskörper entspricht damit wieder exakt dem Stand aus
-- 20260825201448 (der ursprünglichen Auto-Löschungs-Migration) -- keine
-- inhaltliche Neuerung, reine Rücknahme der einen Zeile.
--
-- Rückbau: "and c.owner_id is not null" wieder ergänzen (Stand
-- 20260830160000).

begin;

create or replace function public.auto_delete_inactive_contacts()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  org record;
  months int;
  n_deleted int;
begin
  for org in
    select rc.org_id,
           (rc.config->'contactAutoDelete'->>'monthsInactive')::int as months_inactive
    from public.rule_configs rc
    where coalesce((rc.config->'contactAutoDelete'->>'enabled')::boolean, false) = true
  loop
    months := greatest(coalesce(org.months_inactive, 6), 1);

    with deleted as (
      delete from public.contacts c
      where c.org_id = org.org_id
        and not exists (
          select 1 from public.sales s
          where s.contact_id = c.id and s.status = 'gewonnen'
        )
        and greatest(
              c.created_at,
              c.updated_at,
              coalesce(c.naechster_kontakt::timestamptz, c.created_at),
              coalesce(
                (select max(ca.occurred_at) from public.contact_activities ca where ca.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(t.start_at) from public.termine t where t.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(al.created_at) from public.action_log al where al.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(cf.created_at) from public.contact_files cf where cf.contact_id = c.id),
                c.created_at
              )
            ) < now() - (months || ' months')::interval
      returning 1
    )
    select count(*) into n_deleted from deleted;

    insert into public.contact_auto_delete_log(org_id, deleted_count)
    values (org.org_id, n_deleted);
  end loop;
end;
$$;

commit;
