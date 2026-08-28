-- PATCH: Pool-Grundlage -- profiles.org_id wird nullable
--
-- Erster Baustein des Pool-Features (Selbst-Gründung von Organisationen/
-- Gilden, Austritt zurück in den Pool). Ausführlich mit dem Nutzer
-- durchgesprochen, siehe Claudes Erinnerung
-- project_naechster_struktureller_schritt, Abschnitte 5+6, und der
-- zugehörige Implementierungsplan.
--
-- Diese Migration allein macht noch nichts sichtbar nutzbar -- sie
-- öffnet nur die beiden strukturellen Sperren, die jede spätere
-- Pool-Funktion (found_own_org, leave_own_org,
-- respond_to_org_pool_invitation) sonst sofort blockieren würden:
--
--   1) profiles.org_id war bisher NOT NULL -- ein Pool-Zustand
--      (org_id = NULL) war damit technisch unmöglich.
--   2) profiles_insert_self prüfte nur "id = auth.uid()", keine
--      Einschränkung auf org_id/role. Solange jede Registrierung
--      hart auf DEFAULT_ORG_ID/role='member' verdrahtet war, war das
--      folgenlos -- mit einem Pool-Zustand könnte ein Client sonst
--      versuchen, sich direkt eine beliebige org_id oder role='admin'
--      zu erschleichen. Jetzt erzwungen: eine Registrierung darf NUR
--      mit org_id IS NULL und role='member' ankommen, jede weitere
--      Privilegien-Änderung (Org beitreten/gründen, Admin werden)
--      läuft ab jetzt ausschließlich über SECURITY DEFINER-Funktionen.
--   3) protect_privileged_profile_fields() (Patch 38/39, seit
--      2026-08-15) blockt für Nicht-Admins JEDE Änderung an role/
--      org_id -- ausnahmslos, auch aus einer SECURITY DEFINER-Funktion
--      heraus, da ein Trigger unabhängig von der ausführenden Rolle
--      feuert. Ohne Anpassung würden found_own_org()/leave_own_org()/
--      respond_to_org_pool_invitation() (alle künftig aus Sicht dieses
--      Triggers "Nicht-Admin ändert org_id/role") alle mit
--      "raise exception" fehlschlagen. Fix: dieselbe Sitzungs-Flag-
--      Technik, die total_xp/level schon nutzt (app.trusted_level_sync),
--      wird auf role/org_id erweitert (app.trusted_org_membership_change)
--      -- das Flag ist nur innerhalb einer SECURITY DEFINER-Funktion
--      setzbar (set_config ist über PostgREST/Client nicht erreichbar),
--      exakt dieselbe Vertrauensannahme wie beim bestehenden Flag.

begin;

-- === 1. Pool-Zustand technisch ermöglichen ===
alter table public.profiles alter column org_id drop not null;

-- === 2. Registrierungs-Insert verschärfen ===
drop policy "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self" on public.profiles
  for insert
  with check (
    id = (select auth.uid())
    and org_id is null
    and role = 'member'
  );

-- === 3. Trigger um die beiden neuen, vertrauenswürdigen Ausnahmen erweitern ===
create or replace function public.protect_privileged_profile_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  -- role/org_id: bewusst UNABHÄNGIG von is_admin() geprüft, unabhängig
  -- vom Rest der Funktion -- Verschärfung gegenüber der ursprünglichen
  -- Fassung (Patch 38/39), die beide Felder unter denselben
  -- "if not is_admin()"-Schirm wie character_class/total_xp/level
  -- stellte ("Admin-Bypass bleibt bestehen"). Das war bei genau EINER
  -- existierenden Organisation folgenlos (org_id konnte ohnehin nur auf
  -- diese eine Org zeigen). Mit Selbst-Gründung mehrerer Organisationen
  -- (found_own_org()) wird derselbe Bypass zu einem echten
  -- Cross-Org-Eskalationsweg: is_admin() liest innerhalb dieses
  -- BEFORE-UPDATE-Triggers den zum Zeitpunkt des Feuerns noch nicht
  -- angewendeten (= alten) Rollenwert -- ein aktuell admin-Nutzer könnte
  -- sonst per einfachem Client-Update seine eigene org_id auf eine
  -- FREMDE Organisation setzen und wäre dort sofort is_admin_of()
  -- (per Zweitmeinungsrunde gefunden, vor dem Push behoben). Kein
  -- bestehendes Feature verlässt sich auf einen Admin-Bypass für diese
  -- beiden Felder (geprüft: kein Client-Code setzt role/org_id direkt)
  -- -- beide sind ab jetzt ausschließlich über die vertrauenswürdigen
  -- Sitzungs-Flag-Funktionen (found_own_org()/leave_own_org()/
  -- admin_create_guild()/respond_to_org_pool_invitation()) änderbar.
  if new.role is distinct from old.role
     and coalesce(current_setting('app.trusted_org_membership_change', true), 'false') <> 'true' then
    raise exception 'Rolle kann nur über eine Organisations-Mitgliedschaftsfunktion geändert werden.';
  end if;
  if new.org_id is distinct from old.org_id
     and coalesce(current_setting('app.trusted_org_membership_change', true), 'false') <> 'true' then
    raise exception 'org_id kann nicht direkt geändert werden.';
  end if;

  -- character_class/total_xp/level: unverändert weiterhin mit
  -- Admin-Bypass (Selbsttest-Klassenschalter bzw. akzeptiertes
  -- Eigen-XP-Vertrauen innerhalb der EIGENEN Organisation, siehe
  -- Patch 38/39) -- keine Cross-Org-Eskalation möglich, deshalb hier
  -- bewusst unangetastet gelassen.
  if not public.is_admin() then
    if new.character_class is distinct from old.character_class then
      raise exception 'Die Charakterklasse kann nicht direkt geändert werden.';
    end if;
    if (new.total_xp is distinct from old.total_xp or new.level is distinct from old.level)
       and coalesce(current_setting('app.trusted_level_sync', true), 'false') <> 'true' then
      raise exception 'total_xp/level werden nur über sync_own_level_cache() aktualisiert.';
    end if;
  end if;
  return new;
end;
$function$;

commit;
