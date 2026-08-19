-- PATCH: Bugfix -- eine bereits angenommene Termin-Einladung ließ sich
-- nicht mehr absagen
--
-- Gefunden beim Ende-zu-Ende-Test der neuen Kanban-Spiegelkarte
-- (2026-08-19): respond_to_termin_invitation() erlaubte eine Antwort nur
-- noch, solange status='offen' war. Das blockiert nicht nur den neuen
-- "Termin absagen"-Knopf auf der Kanban-Spiegelkarte, sondern denselben,
-- schon länger bestehenden "Aus meinem Kalender entfernen"-Weg im
-- Kalender (termineEntryDeleteBtn bei einer delegierten Kopie) -- beide
-- rufen dieselbe Funktion mit p_accept=false auf einer bereits
-- angenommenen (status='angenommen') Einladung auf und liefen bisher
-- immer auf denselben Fehler ("Diese Einladung kann nicht mehr
-- beantwortet werden"). Vermutlich nie echt durchgetestet, da die
-- Absage-Funktionalität bisher nur für noch offene Einladungen verifiziert
-- wurde.
--
-- Fix: die Sperre wird nach Annehmen/Ablehnen aufgeteilt --
-- ANNEHMEN bleibt wie bisher nur aus status='offen' möglich (kein erneutes
-- Annehmen einer schon beantworteten Einladung). ABLEHNEN ist jetzt sowohl
-- aus 'offen' (klassisches Ablehnen vor der Antwort) als auch aus
-- 'angenommen' (nachträgliches Absagen) möglich -- aus 'abgelehnt' oder
-- 'storniert' weiterhin nicht (da bereits erledigt bzw. vom Organisator
-- bereits storniert).

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
  if p_accept and v_inv.status != 'offen' then
    raise exception 'Diese Einladung kann nicht mehr angenommen werden (Status: %).', v_inv.status;
  end if;
  if not p_accept and v_inv.status not in ('offen','angenommen') then
    raise exception 'Diese Einladung kann nicht mehr abgelehnt werden (Status: %).', v_inv.status;
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
