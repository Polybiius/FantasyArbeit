-- PATCH: Dritter Kontakt-Zustand "Org-Pool" -- admin-only Umverteilung
--
-- Eine Org kann mehrere Gilden haben; alle Kunden gehören der Org, die
-- Org entscheidet, welcher Gildenführer welche Kunden sieht
-- (Regionalprinzip o.ä.). Ausdrücklich mit dem Nutzer abgestimmt: für
-- v1 reicht das DATENMODELL (owner_id IS NULL AND guild_id IS NULL =
-- "gehört der Org, noch keiner Gilde zugeteilt") -- die eigentliche
-- Verteilungs-Oberfläche (Regionen/Filter) ist ein späterer, separater
-- Schritt. Siehe project_naechster_struktureller_schritt, Abschnitt 6.
--
-- Sichtbarkeit für den Org-Pool-Zustand braucht KEINE neue SELECT-Policy:
-- sowohl contacts_select_visible als auch locations_select_org gewähren
-- is_admin_of(org_id)/is_admin() bereits UNBEDINGT (nicht auf owner_id/
-- guild_id eingeschränkt) -- ein Org-Admin sieht schon heute JEDEN
-- Kontakt/Dungeon seiner eigenen Org, unabhängig vom owner_id/guild_id-
-- Zustand. Geprüft, keine Annahme.
--
-- Für LOCATIONS existieren bereits zwei granulare, admin-taugliche
-- Locked-Write-RPCs (20260824180000_locations_sales_termine_locked_write_rpc.sql):
-- assign_location_owner_locked(id, owner_id, expected) (admin-only,
-- owner_id auch auf NULL setzbar) und admit_location_to_guild_pool_locked
-- (id, guild_id, expected) (guild_id auch auf NULL setzbar) -- zusammen
-- decken sie "Dungeon in den Org-Pool verschieben" (beide auf NULL) und
-- "Dungeon einer Gilde zuteilen" bereits ab. Keine neue Funktion nötig.
--
-- Für CONTACTS gibt es dagegen KEINEN bestehenden Weg: update_contact_
-- locked() schließt owner_id/guild_id/org_id bewusst aus seiner
-- Allowlist aus (siehe dortiger Kommentar), und die frühere
-- contacts_update_guild_pool_assignment-Policy wurde durch dieselbe
-- 2026-08-24-Härtung (Umstieg auf ausschließlich Locked-Write-RPCs)
-- funktionslos, ohne einen Ersatz zu bekommen -- vorbestehende, hier
-- nicht separat gemeldete Lücke. Diese Migration schließt sie mit
-- genau der Funktion, die für den neuen Org-Pool-Zustand ohnehin
-- gebraucht wird.

begin;

create or replace function public.admin_reassign_contact(
  p_contact_id uuid,
  p_new_owner_id uuid,
  p_new_guild_id uuid,
  p_expected_updated_at timestamptz
)
returns public.contacts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_contact public.contacts;
  v_updated public.contacts;
begin
  select * into v_contact from public.contacts where id = p_contact_id for update;
  if not found then
    raise exception 'Kontakt nicht gefunden' using errcode = '42501';
  end if;
  if not is_admin_of(v_contact.org_id) then
    raise exception 'Nur Admins der eigenen Organisation dürfen Kontakte umverteilen' using errcode = '42501';
  end if;
  if p_new_owner_id is not null and p_new_guild_id is not null then
    raise exception 'Ungültige Zielkombination: entweder Besitzer oder Gilden-Pool, nicht beides.';
  end if;
  if p_new_owner_id is not null and not exists (
    select 1 from public.profiles where id = p_new_owner_id and org_id = v_contact.org_id
  ) then
    raise exception 'Zielperson ist nicht Mitglied dieser Organisation.';
  end if;
  if p_new_guild_id is not null and not exists (
    select 1 from public.guilds where id = p_new_guild_id and org_id = v_contact.org_id
  ) then
    raise exception 'Zielgilde gehört nicht zu dieser Organisation.';
  end if;

  update public.contacts set owner_id = p_new_owner_id, guild_id = p_new_guild_id
  where id = p_contact_id and updated_at = p_expected_updated_at
  returning * into v_updated;

  if not found then
    return null; -- optimistischer Sperrkonflikt, gleiche Konvention wie update_contact_locked()
  end if;
  return v_updated;
end;
$$;

grant execute on function public.admin_reassign_contact(uuid, uuid, uuid, timestamptz) to authenticated;
revoke execute on function public.admin_reassign_contact(uuid, uuid, uuid, timestamptz) from public, anon;

insert into public.schema_patches (patch_number, title) values
  (57, 'Pool: eigene Organisation gruenden, Firma wechseln')
on conflict (patch_number) do nothing;

commit;
