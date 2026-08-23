-- ============================================================
-- Contacts: struktureller statt disziplin-basierter Konflikt-Schutz
--
-- Bisher (seit 20260824130000): der Sperr-Check ("wurde die Zeile
-- inzwischen geändert?") existiert nur, WEIL jede der 8 Kontakt-
-- Schreibstellen im Frontend brav updateContactWithLockCheck() statt
-- eines rohen sb.from('contacts').update() aufruft. Nichts in der
-- Datenbank erzwingt das -- eine künftige 17./9. Schreibstelle könnte
-- den Helfer versehentlich vergessen, ohne dass irgendetwas das meldet
-- (siehe Erinnerung project_optimistic_locking_enforcement_gap).
--
-- Lösung, exakt nach dem bereits etablierten Muster von action_log/
-- user_inventory ("Serverseitige Schreib-Härtung", siehe CLAUDE.md):
-- direktes UPDATE auf contacts wird für normale Nutzer komplett
-- gesperrt (RLS-UPDATE-Policy entfernt, kein Ersatz dafür), der einzige
-- verbleibende Weg ist die neue Funktion update_contact_locked(). Ein
-- vergessener Aufruf des alten Helfers würde jetzt nicht mehr still
-- funktionieren, sondern mit einem echten RLS-Fehler auffallen.
--
-- Kein Duplikations-Risiko zur alten Policy-Logik: es gibt danach nur
-- noch EINE Stelle, die "wer darf diese Zeile schreiben" entscheidet
-- (contacts_writable(), 1:1 aus der bisherigen USING-Klausel der
-- entfernten Policy übernommen), nicht mehr zwei parallele.
--
-- Bewusst schmaler geschnitten als eine vollständig generische
-- "patch irgendeine Spalte"-Funktion: update_contact_locked() erlaubt
-- nur genau die Spalten, die die 8 echten Schreibstellen im Frontend
-- tatsächlich anfassen (siehe allowed_keys unten). owner_id/guild_id/
-- org_id sind bewusst NICHT dabei -- die ändern sich ausschließlich
-- über die bestehenden SECURITY-DEFINER-Trigger
-- (sync_contacts_owner_on_location_reassign/handle_member_offboarding),
-- nie über eine der 8 Frontend-Schreibstellen. Dadurch ist automatisch
-- sichergestellt, dass die WITH-CHECK-Bedingung der alten Policy (u.a.
-- org_id bleibt gleich, Gilden-Pool-Zuordnung bleibt konsistent) immer
-- erfüllt bleibt, ohne sie zusätzlich nachbauen zu müssen -- diese
-- Felder werden von dieser Funktion schlicht nie verändert.
-- ============================================================

-- --- 1. Einzige Quelle der Wahrheit für "darf X diese Kontakt-Zeile
--        schreiben" -- 1:1 aus der USING-Klausel von
--        contacts_update_visible (20260817210000) übernommen. ---
create or replace function public.contacts_writable(target public.contacts)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    ((target.owner_id is null) and (target.guild_id is not null) and guild_leadership_permission(target.guild_id))
    or ((target.owner_id = (select auth.uid())) or is_admin() or guild_contact_permission(target.owner_id, true));
$$;

-- --- 2. Die einzige verbleibende Schreibfunktion für contacts. ---
create or replace function public.update_contact_locked(
  p_id uuid,
  p_patch jsonb,
  p_expected_updated_at timestamptz
)
returns public.contacts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.contacts;
  updated_row public.contacts;
  allowed_keys text[] := array[
    'vorname','nachname','role','location_id','status','kanban_stage',
    'geburtsdatum','telefon','email','wohnort_strasse','wohnort_ort',
    'bedarf_ist','bedarf_wunsch','naechster_kontakt','notes'
  ];
  k text;
begin
  select * into current_row from public.contacts where id = p_id for update;
  if not found then
    raise exception 'Kontakt nicht gefunden oder keine Berechtigung' using errcode = '42501';
  end if;

  if not contacts_writable(current_row) then
    raise exception 'Keine Schreibberechtigung für diesen Kontakt' using errcode = '42501';
  end if;

  for k in select jsonb_object_keys(coalesce(p_patch, '{}'::jsonb)) loop
    if not (k = any(allowed_keys)) then
      raise exception 'Feld % darf über update_contact_locked() nicht geändert werden', k using errcode = '42501';
    end if;
  end loop;

  update public.contacts set
    vorname           = case when p_patch ? 'vorname'           then p_patch->>'vorname'           else vorname end,
    nachname          = case when p_patch ? 'nachname'          then p_patch->>'nachname'          else nachname end,
    role              = case when p_patch ? 'role'              then p_patch->>'role'              else role end,
    location_id       = case when p_patch ? 'location_id'       then (p_patch->>'location_id')::uuid else location_id end,
    status            = case when p_patch ? 'status'            then p_patch->>'status'            else status end,
    kanban_stage      = case when p_patch ? 'kanban_stage'      then p_patch->>'kanban_stage'      else kanban_stage end,
    geburtsdatum      = case when p_patch ? 'geburtsdatum'      then (p_patch->>'geburtsdatum')::date else geburtsdatum end,
    telefon           = case when p_patch ? 'telefon'           then p_patch->>'telefon'           else telefon end,
    email             = case when p_patch ? 'email'             then p_patch->>'email'             else email end,
    wohnort_strasse   = case when p_patch ? 'wohnort_strasse'   then p_patch->>'wohnort_strasse'   else wohnort_strasse end,
    wohnort_ort       = case when p_patch ? 'wohnort_ort'       then p_patch->>'wohnort_ort'       else wohnort_ort end,
    bedarf_ist        = case when p_patch ? 'bedarf_ist'        then p_patch->>'bedarf_ist'        else bedarf_ist end,
    bedarf_wunsch     = case when p_patch ? 'bedarf_wunsch'     then p_patch->>'bedarf_wunsch'     else bedarf_wunsch end,
    naechster_kontakt = case when p_patch ? 'naechster_kontakt' then (p_patch->>'naechster_kontakt')::date else naechster_kontakt end,
    notes             = case when p_patch ? 'notes'             then p_patch->>'notes'             else notes end
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null; -- Konflikt: Zeile hat sich seit dem Laden geändert
  end if;

  return updated_row;
end;
$$;

grant execute on function public.update_contact_locked(uuid, jsonb, timestamptz) to authenticated;

-- --- 3. Direktes UPDATE für normale Nutzer sperren -- kein Ersatz für
--        die entfernte Policy, exakt das Muster von action_log/
--        user_inventory ("log_insert_own"/"inventory_update_own"
--        entfernt, siehe CLAUDE.md). ---
drop policy if exists "contacts_update_visible" on public.contacts;
