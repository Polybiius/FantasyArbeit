-- PATCH: Absage-Benachrichtigung + Statusanzeige für Termin-Einladungen
--
-- Nutzerkorrektur zur ersten Fassung vom selben Tag: Löschen eines
-- Termins mit angenommener Einladung soll den Eingeladenen NICHT mehr
-- still lassen, sondern eine echte "abgesagt"-Benachrichtigung
-- hinterlassen. Außerdem soll der Organisator (in der Kanban-Vorschau UND
-- im Kalender-Termin selbst) sehen können, ob/wie seine Einladung
-- beantwortet wurde.
--
-- Kernänderung: termin_invitations bekommt eigene Titel/Zeit/Kanal-
-- Schattenfelder (title/start_at/end_at/kanal), gepflegt bei invite_to_termin()
-- und notify_termin_update(). Grund: sobald der Organisator seinen Termin
-- löscht, verliert termin_id seinen Bezugspunkt (FK jetzt ON DELETE SET
-- NULL statt CASCADE) -- ohne eigene Schattenfelder gäbe es dann nichts
-- mehr anzuzeigen ("Wer hat wann welchen Termin abgesagt?"). Die
-- Invitation-Zeile selbst bleibt bestehen (status='storniert') statt wie
-- bisher automatisch mitgelöscht zu werden.

alter table public.termin_invitations
  add column title text,
  add column start_at timestamptz,
  add column end_at timestamptz,
  add column kanal text;

update public.termin_invitations ti
  set title = t.title, start_at = t.start_at, end_at = t.end_at, kanal = t.kanal
  from public.termine t where t.id = ti.termin_id;

alter table public.termin_invitations alter column termin_id drop not null;
alter table public.termin_invitations drop constraint termin_invitations_termin_id_fkey;
alter table public.termin_invitations
  add constraint termin_invitations_termin_id_fkey
  foreign key (termin_id) references public.termine(id) on delete set null;

alter table public.termin_invitations drop constraint termin_invitations_status_check;
alter table public.termin_invitations
  add constraint termin_invitations_status_check
  check (status in ('offen','angenommen','abgelehnt','storniert'));

-- Der Eingeladene darf eine bereits zur Kenntnis genommene Absage selbst
-- wieder ausblenden -- rein aufräumend, keine Kreuz-Nutzer-Wirkung, daher
-- (anders als sonst in diesem Projekt) eine normale RLS-Policy statt einer
-- eigenen Funktion ausreichend.
create policy termin_invitations_delete_own_cancelled on public.termin_invitations
  for delete using (invited_user_id = (select auth.uid()) and status = 'storniert');

create or replace function public.invite_to_termin(p_termin_id uuid, p_invited_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_src record;
  v_invitation_id uuid;
begin
  select * into v_src from public.termine t where t.id = p_termin_id and t.owner_id = auth.uid();
  if v_src is null then
    raise exception 'Termin nicht gefunden oder du bist nicht der Organisator.';
  end if;

  if p_invited_user_id = auth.uid() then
    raise exception 'Du kannst dich nicht selbst einladen.';
  end if;

  if not public.socially_visible(p_invited_user_id) then
    raise exception 'Diese Person ist nicht in deiner Gilde/Freundesliste.';
  end if;

  insert into public.termin_invitations (org_id, termin_id, invited_user_id, status, title, start_at, end_at, kanal)
  values (v_src.org_id, p_termin_id, p_invited_user_id, 'offen', v_src.title, v_src.start_at, v_src.end_at, v_src.kanal)
  on conflict (termin_id, invited_user_id)
  do update set status = 'offen', invitee_termin_id = null, responded_at = null,
    title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal
  returning id into v_invitation_id;

  return v_invitation_id;
end;
$$;

create or replace function public.respond_to_termin_invitation(p_invitation_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_inv record;
  v_new_termin_id uuid;
begin
  select * into v_inv from public.termin_invitations
    where id = p_invitation_id and invited_user_id = auth.uid();
  if v_inv is null then
    raise exception 'Einladung nicht gefunden.';
  end if;
  if v_inv.status != 'offen' then
    raise exception 'Diese Einladung kann nicht mehr beantwortet werden (Status: %).', v_inv.status;
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
    update public.termine
      set title = v_inv.title, start_at = v_inv.start_at, end_at = v_inv.end_at, kanal = v_inv.kanal
      where id = v_inv.invitee_termin_id;
    v_new_termin_id := v_inv.invitee_termin_id;
  else
    insert into public.termine (org_id, owner_id, title, start_at, end_at, kanal, organizer_id)
    values (v_inv.org_id, auth.uid(), v_inv.title, v_inv.start_at, v_inv.end_at, v_inv.kanal,
      (select owner_id from public.termine where id = v_inv.termin_id))
    returning id into v_new_termin_id;
  end if;

  update public.termin_invitations
    set status = 'angenommen', invitee_termin_id = v_new_termin_id, responded_at = now()
    where id = p_invitation_id;
end;
$$;

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
      set status = 'offen', responded_at = null, title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal
      where id = v_inv.id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- Löscht der Organisator den Original-Termin, bekommt jede noch offene
-- oder angenommene Einladung jetzt status='storniert' statt einfach zu
-- verschwinden -- der Eingeladene sieht das als "abgesagt"-Hinweis. Die
-- Zeile selbst bleibt bestehen (termin_id wird durch die FK automatisch
-- NULL, sobald der referenzierte Termin gleich darauf wirklich gelöscht
-- wird), bis der Eingeladene sie selbst ausblendet.
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
      where termin_id = old.id and invitee_termin_id is not null and status in ('offen','angenommen')
    );
  update public.termin_invitations
    set status = 'storniert', invitee_termin_id = null
    where termin_id = old.id and status in ('offen','angenommen');
  return old;
end;
$$;