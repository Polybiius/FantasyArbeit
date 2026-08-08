-- PATCH: Mitarbeiter-Offboarding + Gilden-Pool für Kontakte
--
-- Konzept (siehe Chat-Konversation 2026-08-08): loescht ein Admin einen
-- Account wirklich (auth.users), gibt es zwei Pfade:
--   - Mit Gilde: Kontakte/Dungeons bleiben erhalten, wandern in den
--     Gilden-Pool (owner_id -> NULL, guild_id gesetzt). Vertraege
--     (sales) bleiben in jedem Fall bestehen (Aufbewahrungspflicht).
--   - Gildenlos (= echter Einzelkaempfer/freier Handelsvertreter,
--     rechtliche Pruefung vor Launch noch offen): alles wird geloescht,
--     "seine Kunden, seine Verantwortung".
-- Gildenfuehrer und Mitglieder mit team_rights=true duerfen Pool-Kontakte
-- ihrer Gilde an andere Mitglieder verteilen.
--
-- Nebenbei behebt das den urspruenglichen Ausloeser dieser ganzen
-- Diskussion: locations.created_by/sales.created_by blockierten bisher
-- JEDE Account-Loeschung (auch von Testaccounts), sobald der Account
-- irgendwann einen Dungeon angelegt oder einen Verkauf eingetragen hatte.

-- === 1. created_by darf das Loeschen des Erstellers nicht mehr blockieren ===
-- (reine Herkunfts-Info, kein Grund, eine Loeschung zu verhindern)
alter table public.locations
  drop constraint locations_created_by_fkey,
  add constraint locations_created_by_fkey
    foreign key (created_by) references public.profiles(id) on delete set null;

alter table public.sales
  drop constraint sales_created_by_fkey,
  add constraint sales_created_by_fkey
    foreign key (created_by) references public.profiles(id) on delete set null;

-- === 2. contacts.owner_id muss fuer den Pool-Zustand nullable sein ===
-- (bisher NOT NULL + CASCADE -- das haette beim Loeschen eines Accounts
-- mit Gilde alle seine Kontakte samt Verlauf mitgerissen)
alter table public.contacts
  alter column owner_id drop not null,
  drop constraint contacts_owner_id_fkey,
  add constraint contacts_owner_id_fkey
    foreign key (owner_id) references public.profiles(id) on delete set null;

-- === 3. contacts.guild_id: dauerhafte Gilden-Zuordnung, analog zu locations.guild_id ===
alter table public.contacts
  add column guild_id uuid references public.guilds(id) on delete set null;

-- === 4. Helper: ist auth.uid() Gildenfuehrer ODER Teamleiter (team_rights) dieser Gilde? ===
create or replace function public.guild_leadership_permission(target_guild uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    exists (
      select 1 from public.guilds g
      where g.id = target_guild and g.founder_id = auth.uid()
    )
    or exists (
      select 1 from public.guild_members gm
      where gm.guild_id = target_guild
        and gm.member_id = auth.uid()
        and gm.team_rights = true
    );
$$;

-- === 5. RLS: Pool-Kontakte (owner_id NULL) sind fuer die ganze Gilde sichtbar ===
-- (guild_contact_permission() greift nur bei gesetztem owner_id -- ein
-- Pool-Kontakt haette sonst niemand, dessen Gilde man pruefen koennte)
create policy "contacts_select_guild_pool" on public.contacts
for select
using (
  owner_id is null
  and guild_id is not null
  and exists (
    select 1 from public.guild_members gm
    where gm.guild_id = contacts.guild_id and gm.member_id = auth.uid()
  )
);

-- === 6. RLS: Gildenfuehrer/Teamleiter duerfen Pool-Kontakte an Mitglieder verteilen ===
-- (normale Kontakt-Reassignierung zwischen zwei bereits zugewiesenen
-- Gildenmitgliedern laeuft weiterhin ueber die bestehende
-- contacts_update_owner_or_admin-Policy via guild_contact_permission();
-- diese Policy deckt nur den Sonderfall "aus dem Pool heraus" ab, wo
-- owner_id noch NULL ist und die bestehende Policy deshalb nicht greift)
create policy "contacts_update_guild_pool_assignment" on public.contacts
for update
using (
  owner_id is null
  and guild_id is not null
  and public.guild_leadership_permission(guild_id)
)
with check (
  guild_id is not null
  and public.guild_leadership_permission(guild_id)
  and (
    owner_id is null
    or exists (
      select 1 from public.guild_members gm
      where gm.guild_id = contacts.guild_id and gm.member_id = contacts.owner_id
    )
  )
);

-- === 7. Das eigentliche Offboarding: BEFORE DELETE Trigger auf auth.users ===
-- Greift bei JEDER Loeschung eines Accounts (Dashboard, Admin-API,
-- kuenftiger In-App-Button) -- nicht nur, wenn eine App-Funktion daran
-- denkt, vorher aufzuraeumen.
create or replace function public.handle_member_offboarding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guild_id uuid;
begin
  select guild_id into v_guild_id
    from public.guild_members
    where member_id = old.id;

  if v_guild_id is not null then
    -- Mit Gilde: Verlauf bleibt erhalten, wandert in den Gilden-Pool
    update public.contacts
      set owner_id = null, guild_id = v_guild_id
      where owner_id = old.id;
    update public.locations
      set owner_id = null, guild_id = coalesce(guild_id, v_guild_id)
      where owner_id = old.id;
  else
    -- Gildenlos: bewusste Komplett-Loeschung. Reisst per bestehendem
    -- CASCADE automatisch sales/contact_activities/journal_entry_mentions
    -- dieser Kontakte mit -- gewollt, siehe Konzept oben.
    delete from public.contacts where owner_id = old.id;
    delete from public.locations where owner_id = old.id;
  end if;

  return old;
end;
$$;

drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted
  before delete on auth.users
  for each row execute function public.handle_member_offboarding();
