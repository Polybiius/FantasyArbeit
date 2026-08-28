-- PATCH: Org-Pool-Verteilung auch durch den alleinigen Gildenführer
--
-- Phase-1-Bauaufgabe (project_naechster_struktureller_schritt,
-- Abschnitt 8/9). Nutzer-Entscheidung zur Autorisierung: "Wenn wir eine
-- Organisation mit mehreren Gilden/Teamleitern haben, dann die
-- Organisation [entscheidet]. Wenn wir jemanden haben, der eine Gilde
-- hat, dann der Gildenführer" -- ergänzt bestätigt: "auch dann sind ja
-- prinzipiell alle Kunden unter der Organisation gebündelt" (eine Org
-- mit genau einer Gilde -> deren Gründer hat de-facto Organisations-
-- Autorität für die Kunden-/Dungeon-Verteilung).
--
-- Neue Hilfsfunktion is_sole_guild_founder_of_org(): true nur, wenn die
-- Org GENAU EINE Gilde hat UND der Aufrufer deren founder_id ist --
-- bewusst kein Zugriff für Gildenführer in Mehrfach-Gilden-Orgs (das
-- bleibt Org-Admin-exklusiv, siehe Nutzer-Zitat oben). Fällt der
-- alleinige Gildenführer ohne Nachfolger weg
-- (reassign_guild_founder_on_departure() setzt dann founder_id=NULL),
-- liefert diese Funktion für niemanden mehr true -- Verteilung braucht
-- in diesem Randfall einen Org-Admin, akzeptables Fallback-Verhalten.
--
-- Drei bestehende Funktionen bekommen den zusätzlichen Autorisierungs-
-- Zweig -- bewusst NICHT die geteilte locations_writable() erweitert
-- (würde jeden anderen Location-Schreibweg mitbetreffen, unnötig breiter
-- Blast-Radius), sondern jede Funktion einzeln, chirurgisch:
-- - admin_reassign_contact(): war is_admin_of() allein.
-- - assign_location_owner_locked(): war bare is_admin() (siehe
--   20260824180000, Zeile ~100-116) -- KEIN is_admin_of()! Zusätzlicher,
--   beim Bau dieser Migration selbst gefundener Fund (nicht Teil des
--   ursprünglichen Org-Grenze-Audits vom 2026-08-28, der laut eigenem
--   Kommentar nur "22 Policies + 1 Funktion" umfasste, SECURITY-DEFINER-
--   Funktionskörper wie diesen hier nicht mit einschloss): ein Admin
--   EINER BELIEBIGEN Org hätte bisher JEDEN Dungeon JEDER Org neu
--   zuweisen können, solange er irgendwo Admin war. Im aktuellen
--   Ein-Org-Betrieb folgenlos, aber exakt die Lückenklasse des
--   2026-08-28-Audits -- im selben Zug mitgefixt, da die Funktion
--   ohnehin angefasst wird.
-- - admit_location_to_guild_pool_locked(): war bereits korrekt
--   org-gebunden über locations_writable().
--
-- Rückbau: is_sole_guild_founder_of_org() droppen, alle drei Funktionen
-- auf die jeweils vorherige Fassung zurücksetzen (siehe git-Historie
-- 20260829095000_contacts_org_pool_rpc.sql und
-- 20260824180000_locations_sales_termine_locked_write_rpc.sql).
--
-- Nachgeschärft nach unabhängiger Zweitmeinung (/code-review high) --
-- zwei echte, kritische Funde, beide hier behoben:
-- 1) contacts_select_visible hätte dem Gildenführer unbedingt JEDEN
--    Kontakt der Org sichtbar gemacht (auch private, nicht geteilte
--    Kontakte von Kolleg:innen außerhalb der Gilde) -- der neue Zweig
--    ist jetzt auf den echten Pool-Zustand eingeschränkt (owner_id UND
--    guild_id beide NULL).
-- 2) admin_reassign_contact()/assign_location_owner_locked()/
--    admit_location_to_guild_pool_locked() prüften nur, WER aufruft,
--    nicht, ob das ZIEL tatsächlich ein herrenloser Pool-Kontakt/
--    -Dungeon ist -- ein Gildenführer hätte damit auch einen aktiv
--    privat gehaltenen Kontakt/Dungeon eines Kollegen an sich reißen
--    können. Der Gildenführer-Zweig ist jetzt zusätzlich auf den
--    Pool-Zustand des Ziels beschränkt; der bestehende Admin-Zweig
--    bleibt unverändert (Admins durften schon vorher frei umverteilen,
--    kein Rückschritt).

begin;

create or replace function public.is_sole_guild_founder_of_org(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1 from public.guilds g
      where g.org_id = p_org_id and g.founder_id = (select auth.uid())
    )
    and (select count(*) from public.guilds g2 where g2.org_id = p_org_id) = 1;
$$;

-- Bewusst auch für anon ausführbar, gleiche Begründung wie is_admin_of():
-- reines Lese-Helferlein, liefert für anon ohnehin immer false.
revoke execute on function public.is_sole_guild_founder_of_org(uuid) from public;
grant execute on function public.is_sole_guild_founder_of_org(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------
-- contacts_select_visible: Sichtbarkeits-Lücke für Org-Pool-Kontakte
--
-- locations_select_org ist bereits schlicht "org_id = current_org_id()"
-- -- jedes Org-Mitglied sieht alle Dungeons der eigenen Org unbedingt,
-- auch Pool-Dungeons, keine Anpassung nötig. contacts_select_visible ist
-- dagegen enger: ein Org-Pool-Kontakt (owner_id IS NULL AND guild_id IS
-- NULL) wäre für einen NICHT-Admin-Gildenführer unsichtbar geblieben --
-- die bestehende Policy gewährt is_admin_of(org_id) unbedingt, hat aber
-- keinen äquivalenten Zweig für is_sole_guild_founder_of_org(). Ohne
-- diesen Fix könnte ein Gildenführer die neue Autorisierung zwar
-- AUSFÜHREN, aber die zuzuweisenden Kontakte gar nicht erst SEHEN/LISTEN.
-- ---------------------------------------------------------------------

alter policy "contacts_select_visible" on public.contacts
  using (
    ((owner_id is null) and (guild_id is not null) and exists (
      select 1 from public.guild_members gm
      where gm.guild_id = contacts.guild_id and gm.member_id = (select auth.uid())
    ))
    -- Neu, bewusst eng: NUR echte Org-Pool-Kontakte (beide Felder NULL)
    -- für den alleinigen Gildenführer -- nicht "jeder Kontakt der Org".
    or ((owner_id is null) and (guild_id is null) and is_sole_guild_founder_of_org(org_id))
    or (
      (owner_id = (select auth.uid()))
      or is_admin_of(org_id)
      or ((org_id = current_org_id()) and contacts_shared_for_org())
      or guild_contact_permission(owner_id, false)
    )
  );

-- ---------------------------------------------------------------------
-- admin_reassign_contact(): Autorisierung erweitert
-- ---------------------------------------------------------------------

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
  -- Admin: unverändert volle Umverteilungsmacht (auch aktiv gehaltene
  -- Kontakte, wie schon vor dieser Migration). Gildenführer: NEU, aber
  -- bewusst nur für echte Pool-Kontakte (beide Felder NULL) -- kein
  -- Zugriff auf aktiv privat gehaltene Kontakte von Kolleg:innen.
  if not (
    is_admin_of(v_contact.org_id)
    or (is_sole_guild_founder_of_org(v_contact.org_id) and v_contact.owner_id is null and v_contact.guild_id is null)
  ) then
    raise exception 'Nur Admins oder der alleinige Gildenführer der eigenen Organisation dürfen Kontakte umverteilen (Gildenführer nur für herrenlose Pool-Kontakte)' using errcode = '42501';
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

-- ---------------------------------------------------------------------
-- assign_location_owner_locked(): bare is_admin() -> is_admin_of() +
-- neuer Gildenführer-Zweig
-- ---------------------------------------------------------------------

create or replace function public.assign_location_owner_locked(
  p_id uuid,
  p_owner_id uuid,
  p_expected_updated_at timestamptz
)
returns public.locations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.locations;
  updated_row public.locations;
begin
  select * into current_row from public.locations where id = p_id for update;
  if not found then
    raise exception 'Dungeon nicht gefunden' using errcode = '42501';
  end if;

  -- Admin: unverändert volle Umverteilungsmacht. Gildenführer: NEU,
  -- aber nur für herrenlose Pool-Dungeons (owner_id NULL).
  if not (
    is_admin_of(current_row.org_id)
    or (is_sole_guild_founder_of_org(current_row.org_id) and current_row.owner_id is null)
  ) then
    raise exception 'Nur Admins oder der alleinige Gildenführer der eigenen Organisation dürfen Dungeon-Accounts zuweisen (Gildenführer nur für herrenlose Pool-Dungeons)' using errcode = '42501';
  end if;

  update public.locations set owner_id = p_owner_id
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;
  return updated_row;
end;
$$;

-- ---------------------------------------------------------------------
-- admit_location_to_guild_pool_locked(): zusätzlicher Gildenführer-Zweig
-- ---------------------------------------------------------------------

create or replace function public.admit_location_to_guild_pool_locked(
  p_id uuid,
  p_guild_id uuid,
  p_expected_updated_at timestamptz
)
returns public.locations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.locations;
  updated_row public.locations;
begin
  select * into current_row from public.locations where id = p_id for update;
  if not found then
    raise exception 'Dungeon nicht gefunden oder keine Berechtigung' using errcode = '42501';
  end if;

  -- locations_writable() deckt Admins/bestehende Gildenführer-Fälle ab.
  -- Neuer Zweig: alleiniger Gildenführer, aber nur für herrenlose
  -- Pool-Dungeons (owner_id NULL) -- kein Zugriff auf aktiv privat
  -- gehaltene Dungeons von Kolleg:innen.
  if not (
    locations_writable(current_row)
    or (current_row.owner_id is null and is_sole_guild_founder_of_org(current_row.org_id))
  ) then
    raise exception 'Keine Schreibberechtigung für diesen Dungeon' using errcode = '42501';
  end if;

  if p_guild_id is not null and not (
    is_admin() or exists (
      select 1 from public.guilds g where g.id = p_guild_id and g.founder_id = (select auth.uid())
    )
  ) then
    raise exception 'Nur der Gildengründer darf einen Dungeon in seine Gilde aufnehmen' using errcode = '42501';
  end if;

  update public.locations set guild_id = p_guild_id
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null;
  end if;
  return updated_row;
end;
$$;

commit;
