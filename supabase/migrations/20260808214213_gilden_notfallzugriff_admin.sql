-- PATCH: Protokollierter Admin-Notfallzugriff (Phase 3 der Gilden-basierten
-- Sichtbarkeit)
--
-- Konzept (Chat-Konversation 2026-08-08, direkt nach Phase 2): Phase 1 hat
-- Admins bewusst von der Standard-Sichtbarkeit ausgeschlossen ("komplett
-- privat, auch fuer Admins unsichtbar im Alltag"). Phase 3 gibt dafuer
-- einen kontrollierten Ausnahmeweg: ein Admin kann sich im Notfall (Kollege
-- nicht erreichbar, dringender Kundenvorgang) die PRIVATEN Kontakte/
-- Dungeons eines Mitglieds ansehen -- read-only, kein Schreibzugriff,
-- keine Rechtevergabe. Bewusst "Break-Glass"-Muster (sofortiger Zugriff
-- gegen Pflicht-Begruendung, keine vorherige Freigabe durch eine dritte
-- Person) -- die Kontrolle liegt in der luckenlosen Protokollierung, nicht
-- in einer Blockade vorher. Bewusst NICHT angefasst: journal_entries
-- bleibt die einzige komplett private Tabelle ohne jede Admin-Ausnahme,
-- daran aendert dieser Patch nichts.

-- === 1. access_audit_log: unveraenderliches Protokoll jedes Notfallzugriffs ===
create table public.access_audit_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  admin_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now()
);

create index access_audit_log_org_id_idx on public.access_audit_log(org_id);
create index access_audit_log_target_user_id_idx on public.access_audit_log(target_user_id);

alter table public.access_audit_log enable row level security;

-- Nur Admins duerfen das Protokoll einsehen -- kein Insert/Update/Delete
-- fuer normale Client-Aufrufe, das Schreiben passiert ausschliesslich
-- innerhalb der Notfallzugriff-Funktion unten (SECURITY DEFINER). Genau
-- wie bei error_log: ein Protokoll wird nicht nachtraeglich veraendert.
create policy "access_audit_log_select_admin" on public.access_audit_log
for select
using (public.is_admin() and org_id = public.current_org_id());

-- === 2. Die eigentliche Notfallzugriff-Funktion ===
-- Loggt zuerst (Pflicht-Grund, sonst Abbruch), liefert danach die
-- privaten Kontakte/Dungeons des Zielmitglieds als ein JSON-Objekt.
-- Bewusst nur "eigene" Daten (owner_id = Zielperson) -- Pool-Daten der
-- Gilde sind fuer die Gilde ohnehin schon sichtbar, dafuer braucht es
-- keinen Notfallzugriff.
create or replace function public.admin_emergency_access(p_target_user uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_target_org_id uuid;
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Nur Admins duerfen Notfallzugriff auslösen.';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'Ein Grund ist Pflicht.';
  end if;

  v_org_id := public.current_org_id();

  select org_id into v_target_org_id from public.profiles where id = p_target_user;
  if v_target_org_id is null or v_target_org_id <> v_org_id then
    raise exception 'Zielperson nicht in der eigenen Organisation gefunden.';
  end if;

  insert into public.access_audit_log (org_id, admin_id, target_user_id, reason)
    values (v_org_id, auth.uid(), p_target_user, btrim(p_reason));

  select jsonb_build_object(
    'contacts', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.name)
      from public.contacts c
      where c.owner_id = p_target_user
    ), '[]'::jsonb),
    'locations', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.name)
      from public.locations l
      where l.owner_id = p_target_user
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;
