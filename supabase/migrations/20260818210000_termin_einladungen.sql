-- PATCH: Termin-Einladungen für Gildenmitglieder (Fundament für Gildenquest)
--
-- Nutzerwunsch, Outlook als ausdrückliches Vorbild: ein Termin lässt sich
-- an ein Gildenmitglied "einladen". Erscheint erst als offene Einladung
-- (noch nicht im Kalender), bei Annahme entsteht eine eigene Kalenderzeile
-- beim Eingeladenen (als "primär Termin von X" markiert). Verschiebt der
-- Organisator den Termin danach, kann er ein Update an alle mit
-- angenommener Einladung senden -- deren Kopie wird mitverschoben UND ihr
-- Status springt zurück auf "offen" (muss die neue Zeit erneut bestätigen
-- oder ablehnen), exakt wie Outlooks "Update senden?"-Mechanik.
--
-- Bewusste Vereinfachungen dieser ersten Fassung (siehe Chat-Absprache
-- 2026-08-18): Serientermine + Einladung nicht kombiniert, die Kopie beim
-- Eingeladenen trägt keinen contact_id/location_id-Bezug (nur Titel/Zeit/
-- Kanal -- vermeidet, in die Kontakt-Sichtbarkeitsrechte reingehen zu
-- müssen), Löschen des Original-Termins räumt die Kopie still ab, ohne
-- eigene "abgesagt"-Benachrichtigung.
--
-- Cross-User-Schreibvorgänge laufen ausschließlich über die drei neuen
-- SECURITY DEFINER-Funktionen unten (gleiches Muster wie die
-- Schreib-Härtung vom 2026-08-15: kein direktes INSERT/UPDATE auf
-- termin_invitations für Clients, damit Einladung/Annahme/Update immer
-- atomar und konsistent bleiben statt in Halbzuständen enden zu können).

alter table public.termine
  add column organizer_id uuid references public.profiles(id);
comment on column public.termine.organizer_id is
  'Nur bei einer per Einladung angenommenen Kopie gesetzt: verweist auf den ursprünglichen Organisator. NULL = eigener Termin.';

create table public.termin_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  termin_id uuid not null references public.termine(id) on delete cascade,
  invited_user_id uuid not null references public.profiles(id),
  status text not null default 'offen' check (status in ('offen','angenommen','abgelehnt')),
  invitee_termin_id uuid references public.termine(id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (termin_id, invited_user_id)
);
create index termin_invitations_termin_id_idx on public.termin_invitations(termin_id);
create index termin_invitations_invited_user_id_idx on public.termin_invitations(invited_user_id);

alter table public.termin_invitations enable row level security;

-- Sichtbar für den Eingeladenen selbst, den Organisator (Eigentümer des
-- referenzierten Termins) und Admins -- gleiches Leserechte-Muster wie bei
-- termine selbst.
create policy termin_invitations_select on public.termin_invitations
  for select using (
    invited_user_id = (select auth.uid())
    or exists (select 1 from public.termine t where t.id = termin_id and t.owner_id = (select auth.uid()))
    or public.is_admin()
  );

-- Bewusst KEINE insert/update/delete-Policies für normale Clients -- jeder
-- Schreibvorgang läuft über eine der drei Funktionen unten, damit
-- Einladung/Annahme/Update-Weitergabe nie in einem halbfertigen Zustand
-- enden können (z.B. Status auf "angenommen", aber keine Kalenderzeile).

-- 1) Einladen: nur der Organisator (Eigentümer des Termins), nur an ein
-- Gildenmitglied/eine Freundschaft (dieselbe Grenze wie friend_skill_totals,
-- socially_visible() bereits seit Phase 1 der Gilden-Sichtbarkeit etabliert
-- und geprüft). Erneutes Einladen nach einer Ablehnung setzt einfach den
-- bestehenden Status wieder auf "offen" zurück statt eine Dublette zu werfen.
create or replace function public.invite_to_termin(p_termin_id uuid, p_invited_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_org_id uuid;
  v_invitation_id uuid;
begin
  select t.org_id into v_org_id from public.termine t
    where t.id = p_termin_id and t.owner_id = auth.uid();
  if v_org_id is null then
    raise exception 'Termin nicht gefunden oder du bist nicht der Organisator.';
  end if;

  if p_invited_user_id = auth.uid() then
    raise exception 'Du kannst dich nicht selbst einladen.';
  end if;

  if not public.socially_visible(p_invited_user_id) then
    raise exception 'Diese Person ist nicht in deiner Gilde/Freundesliste.';
  end if;

  insert into public.termin_invitations (org_id, termin_id, invited_user_id, status)
  values (v_org_id, p_termin_id, p_invited_user_id, 'offen')
  on conflict (termin_id, invited_user_id)
  do update set status = 'offen', invitee_termin_id = null, responded_at = null
  returning id into v_invitation_id;

  return v_invitation_id;
end;
$$;

-- 2) Annehmen/Ablehnen: nur der Eingeladene selbst. Bei Annahme entsteht
-- (oder wird aktualisiert, falls schon einmal angenommen und gerade neu zu
-- bestätigen) eine eigene Kalenderzeile mit organizer_id-Markierung. Bei
-- Ablehnung verschwindet eine ggf. bereits bestehende Kopie wieder.
create or replace function public.respond_to_termin_invitation(p_invitation_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_inv record;
  v_src record;
  v_new_termin_id uuid;
begin
  select * into v_inv from public.termin_invitations
    where id = p_invitation_id and invited_user_id = auth.uid();
  if v_inv is null then
    raise exception 'Einladung nicht gefunden.';
  end if;

  select * into v_src from public.termine where id = v_inv.termin_id;
  if v_src is null then
    raise exception 'Der zugehörige Termin existiert nicht mehr.';
  end if;

  if not p_accept then
    if v_inv.invitee_termin_id is not null then
      delete from public.termine where id = v_inv.invitee_termin_id;
    end if;
    update public.termin_invitations
      set status = 'abgelehnt', invitee_termin_id = null, responded_at = now()
      where id = p_invitation_id;
    return;
  end if;

  if v_inv.invitee_termin_id is not null then
    -- Reaktion auf ein Update (Termin wurde verschoben) -- bestehende Kopie
    -- einfach auf den aktuellen Stand des Original-Termins nachziehen.
    update public.termine
      set title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal
      where id = v_inv.invitee_termin_id;
    v_new_termin_id := v_inv.invitee_termin_id;
  else
    insert into public.termine (org_id, owner_id, title, start_at, end_at, kanal, organizer_id)
    values (v_inv.org_id, auth.uid(), v_src.title, v_src.start_at, v_src.end_at, v_src.kanal, v_src.owner_id)
    returning id into v_new_termin_id;
  end if;

  update public.termin_invitations
    set status = 'angenommen', invitee_termin_id = v_new_termin_id, responded_at = now()
    where id = p_invitation_id;
end;
$$;

-- 3) Update-Weitergabe: nur der Organisator, nur für bereits angenommene
-- Einladungen. Zieht deren Kopien auf den (schon zuvor ganz normal per
-- eigenem UPDATE geänderten) aktuellen Stand des Original-Termins nach und
-- setzt den Status zurück auf "offen" -- der Eingeladene muss die neue Zeit
-- erneut bestätigen, exakt wie bei Outlooks Termin-Update.
create or replace function public.notify_termin_update(p_termin_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_src record;
  v_count integer := 0;
  v_inv record;
begin
  select * into v_src from public.termine where id = p_termin_id and owner_id = auth.uid();
  if v_src is null then
    raise exception 'Termin nicht gefunden oder du bist nicht der Organisator.';
  end if;

  for v_inv in
    select * from public.termin_invitations
    where termin_id = p_termin_id and status = 'angenommen' and invitee_termin_id is not null
  loop
    update public.termine
      set title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal
      where id = v_inv.invitee_termin_id;
    update public.termin_invitations
      set status = 'offen', responded_at = null
      where id = v_inv.id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- Löscht der Organisator den Original-Termin komplett, verschwindet die
-- Kopie beim Eingeladenen mit (bewusst still, siehe Kommentar oben) --
-- ohne diesen Trigger bliebe die Kopie als verwaiste, nie mehr
-- aktualisierbare Karteileiche im fremden Kalender stehen.
create or replace function public.cleanup_termin_invitee_copies()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  delete from public.termine
    where id in (
      select invitee_termin_id from public.termin_invitations
      where termin_id = old.id and invitee_termin_id is not null
    );
  return old;
end;
$$;

create trigger termine_cleanup_invitee_copies
  before delete on public.termine
  for each row execute function public.cleanup_termin_invitee_copies();
