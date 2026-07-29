-- ============================================================
-- PATCH 11 — Account-Besitz & Pool (Grundgerüst Kundendatenbank)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

-- 1) Accounts (Dungeons/locations) bekommen einen Besitzer.
--    leer = "im Pool des Teamleiters", nicht momentan bearbeitet.
alter table public.locations add column if not exists owner_id uuid references public.profiles(id) on delete set null;

-- 2) Wenn ein Account neu zugewiesen wird, wandern automatisch ALLE
--    Kontakte darin mit — nie einzeln, immer als Ganzes (wie besprochen).
create or replace function public.sync_contacts_owner_on_location_reassign()
returns trigger
language plpgsql security definer
as $$
begin
  if new.owner_id is distinct from old.owner_id then
    update public.contacts set owner_id = new.owner_id where location_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_contacts_owner on public.locations;
create trigger trg_sync_contacts_owner
  after update of owner_id on public.locations
  for each row execute function public.sync_contacts_owner_on_location_reassign();

-- 3) Team-Sichtbarkeit bei geteilten Kontakten: wenn contactsVisibility
--    auf "shared" steht, dürfen alle Team-Mitglieder die Log-Einträge
--    sehen, die zu genau diesem Kontakt gehören (Historie bei
--    Mitarbeiterwechsel nachvollziehbar) — nicht das gesamte private
--    Log der Kollegen, nur was an diesem einen Kontakt hängt.
create policy "log_select_shared_contact_activity" on public.action_log
  for select using (
    contact_id is not null
    and exists (
      select 1 from public.contacts c
      where c.id = action_log.contact_id
        and c.org_id = public.current_org_id()
        and public.contacts_shared_for_org()
    )
  );
