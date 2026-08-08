-- PATCH: Notfall-Nachfolgekette fuer Gildenfuehrer (Phase 2 der
-- Gilden-basierten Sichtbarkeit)
--
-- Konzept (Chat-Konversation 2026-08-08, direkt im Anschluss an das
-- Mitarbeiter-Offboarding): wird der Account eines Gildenfuehrers
-- geloescht, braucht die Gilde automatisch einen neuen Fuehrer, sonst
-- kann niemand mehr Rechte vergeben oder den Pool verwalten.
--
-- Kriterium erstmal bewusst simpel gehalten (echte Regeln folgen, sobald
-- ein konkretes Unternehmen die App nutzt): das Mitglied mit
-- team_rights=true, das am laengsten dabei ist (fruehestes joined_at).
-- Gibt es niemanden mit team_rights, faellt es auf das insgesamt
-- laengste Mitglied zurueck -- die Gilde soll nie ohne Not fuehrerlos
-- werden, solange noch irgendwer drin ist.
--
-- WICHTIG, ausdrueckliche Nutzer-Vorgabe: eine Gilde wird beim Ausfall
-- ihres Fuehrers NIEMALS geloescht oder unsichtbar gemacht, auch nicht
-- im Extremfall (Fuehrer war das letzte verbliebene Mitglied) -- das
-- sind Unternehmensdaten, potenziell tausende Kundenkontakte. Deshalb
-- wird founder_id zusaetzlich zur Trigger-Logik als echtes
-- Sicherheitsnetz von NOT NULL/CASCADE auf nullable/SET NULL umgestellt:
-- selbst wenn die Nachfolge-Suche niemanden findet, bleibt die Gilde
-- (und alle ihre Pool-Kontakte/-Dungeons) bestehen, nur eben
-- voruebergehend ohne Fuehrer (fuehrerlos = Sonderfall fuer Phase 3
-- Admin-Notfallzugriff, hier bewusst noch nicht geloest).

-- === 1. founder_id darf nicht mehr automatisch die ganze Gilde mitreissen ===
alter table public.guilds
  alter column founder_id drop not null,
  drop constraint guilds_founder_id_fkey,
  add constraint guilds_founder_id_fkey
    foreign key (founder_id) references public.profiles(id) on delete set null;

-- === 2. handle_member_offboarding() um die Nachfolge-Suche erweitern ===
-- Laeuft VOR der bestehenden Pool-/Loeschlogik, im selben BEFORE-DELETE-
-- Trigger auf auth.users -- muss vor dem eigentlichen Loeschen passieren,
-- damit founder_id schon umgehaengt ist, wenn die CASCADE-Kette greift.
create or replace function public.handle_member_offboarding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guild_id uuid;
  v_founded_guild uuid;
  v_successor uuid;
begin
  -- --- Notfall-Nachfolgekette: war old.id Gildenfuehrer? ---
  select id into v_founded_guild
    from public.guilds
    where founder_id = old.id;

  if v_founded_guild is not null then
    select member_id into v_successor
      from public.guild_members
      where guild_id = v_founded_guild
        and member_id <> old.id
        and team_rights = true
      order by joined_at asc
      limit 1;

    if v_successor is null then
      -- kein Teamleiter vorhanden: laengstes Mitglied insgesamt uebernimmt
      select member_id into v_successor
        from public.guild_members
        where guild_id = v_founded_guild
          and member_id <> old.id
        order by joined_at asc
        limit 1;
    end if;

    if v_successor is not null then
      update public.guilds
        set founder_id = v_successor
        where id = v_founded_guild;
      -- neuer Fuehrer erbt volle Rechte, wie ein Gildengruender
      update public.guild_members
        set contacts_access = 'write', dungeons_access = 'write', team_rights = true
        where guild_id = v_founded_guild and member_id = v_successor;
    end if;
    -- Bleibt v_successor NULL (alle anderen Mitglieder schon laenger weg,
    -- nur noch Pool-Daten uebrig): founder_id faellt per FK oben auf NULL,
    -- die Gilde samt Pool-Kontakten/-Dungeons bleibt trotzdem bestehen.
  end if;

  -- --- Bestehendes Offboarding: eigene Kontakte/Dungeons des Accounts ---
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
    -- dieser Kontakte mit -- gewollt, siehe Konzept im vorherigen Patch.
    delete from public.contacts where owner_id = old.id;
    delete from public.locations where owner_id = old.id;
  end if;

  return old;
end;
$$;
