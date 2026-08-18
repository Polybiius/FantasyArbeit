-- PATCH: Organisator-Name als Schattenfeld auf termin_invitations
--
-- Direkter Nachtrag zur vorigen Migration: title/start_at/end_at/kanal
-- wurden schon als Schattenfelder gespeichert, damit eine Absage-Meldung
-- nach dem Löschen des Original-Termins noch etwas anzuzeigen hat --
-- WER abgesagt hat, fehlte aber noch, da das bisher nur über den Join
-- termin_id -> termine.owner_id lief, und termin_id nach einer Absage
-- NULL wird.

alter table public.termin_invitations add column organizer_id uuid references public.profiles(id);

update public.termin_invitations ti
  set organizer_id = t.owner_id
  from public.termine t where t.id = ti.termin_id;

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

  insert into public.termin_invitations (org_id, termin_id, invited_user_id, status, title, start_at, end_at, kanal, organizer_id)
  values (v_src.org_id, p_termin_id, p_invited_user_id, 'offen', v_src.title, v_src.start_at, v_src.end_at, v_src.kanal, auth.uid())
  on conflict (termin_id, invited_user_id)
  do update set status = 'offen', invitee_termin_id = null, responded_at = null,
    title = v_src.title, start_at = v_src.start_at, end_at = v_src.end_at, kanal = v_src.kanal, organizer_id = auth.uid()
  returning id into v_invitation_id;

  return v_invitation_id;
end;
$$;
