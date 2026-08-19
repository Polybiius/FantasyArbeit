-- PATCH: Kontakt-Verknüpfung bei Termin-Einladungen (Fundament für die
-- Kanban-Spiegelkarte)
--
-- Nutzerwunsch: ist ein eingeladener Termin mit einem Kunden verknüpft,
-- soll der Eingeladene nach Annahme nicht nur einen Kalendereintrag,
-- sondern auch eine schreibgeschützte Kanban-Karte für genau diesen
-- Kunden sehen (in der Spalte, in der der Kontakt tatsächlich gerade
-- steht -- live abgeleitet, keine eigene Kopie des Status). Von dort kann
-- er absagen (= dieselbe respond_to_termin_invitation()-Funktion wie im
-- Kalender). Kanban selbst bleibt sonst strikt persönlich (siehe
-- CLAUDE.md, "Kanban ist strikt die eigene Vertriebspipe") -- das hier
-- ist eine bewusste, gezielte Ausnahme nur für angenommene Einladungen,
-- keine generelle Öffnung.
--
-- contact_id wird dafür wie title/start_at/end_at/kanal/organizer_id als
-- Schattenfeld auf termin_invitations mitgeführt (gleiches Muster wie die
-- Absage-Migration vom 2026-08-18) -- unabhängig vom späteren Löschen des
-- Original-Termins bleibt die Verknüpfung so erhalten. Kein Zwang zur
-- Sichtbarkeit: hat der Eingeladene keinen Lesezugriff auf den Kontakt
-- (z.B. eingeladen als Freund ohne gemeinsame Gilde), liefert die
-- bestehende contacts-RLS für ihn schlicht nichts zurück -- die
-- Kanban-Karte bleibt dann einfach aus, kein Sonderfall im Code nötig.

alter table public.termin_invitations add column contact_id uuid references public.contacts(id) on delete set null;

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

  insert into public.termin_invitations (org_id, termin_id, invited_user_id, status, title, start_at, end_at, kanal, organizer_id, contact_id)
  values (v_src.org_id, p_termin_id, p_invited_user_id, 'offen', v_src.title, v_src.start_at, v_src.end_at, v_src.kanal, auth.uid(), v_src.contact_id)
  on conflict (termin_id, invited_user_id)
  do update set status = 'offen', invitee_termin_id = null, responded_at = null,
    title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal, organizer_id = auth.uid(), contact_id = v_src.contact_id
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
      set title = v_inv.title, start_at = v_inv.start_at, end_at = v_inv.end_at, kanal = v_inv.kanal, contact_id = v_inv.contact_id
      where id = v_inv.invitee_termin_id;
    v_new_termin_id := v_inv.invitee_termin_id;
  else
    insert into public.termine (org_id, owner_id, title, start_at, end_at, kanal, organizer_id, contact_id)
    values (v_inv.org_id, auth.uid(), v_inv.title, v_inv.start_at, v_inv.end_at, v_inv.kanal,
      (select owner_id from public.termine where id = v_inv.termin_id), v_inv.contact_id)
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
      set title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal, contact_id = v_src.contact_id
      where id = v_inv.invitee_termin_id;
    update public.termin_invitations
      set status = 'offen', responded_at = null, title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal, contact_id = v_src.contact_id
      where id = v_inv.id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;
