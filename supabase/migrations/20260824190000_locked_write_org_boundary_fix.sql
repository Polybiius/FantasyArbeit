-- ============================================================
-- Fund einer unabhängigen Gegenprüfung (frischer Agent ohne Kontext der
-- Bau-Session, neue verbindliche Regel seit heute, siehe CLAUDE.md
-- Abschnitt "Supabase-CLI-Migrationstoolchain"): contacts_writable()/
-- sales_writable()/termine_writable()/termin_series_writable()
-- (Migrationen 20260824160000+20260824180000) übernahmen jeweils nur die
-- USING-Klausel der entfernten RLS-Policy -- die Org-Grenze für den
-- Admin-Zweig saß bei diesen vier Tabellen aber in der WITH-CHECK-Klausel
-- (z.B. termine_update_owner_or_admin: USING ohne org_id-Bezug, WITH
-- CHECK zusätzlich "AND org_id = current_org_id()"). Da die neuen
-- SECURITY-DEFINER-Funktionen die Zielzeile ohne RLS per id laden (nicht
-- auf die eigene Org eingeschränkt), konnte ein Admin dadurch bislang
-- theoretisch eine Zeile JEDER Organisation anfassen, sofern er ihre
-- UUID kennt -- ein echter Bruch der Mandantentrennung, der beim
-- aktuellen Einzel-Org-Betrieb (nur DEFAULT_ORG_ID) praktisch folgenlos
-- blieb, aber vor dem ersten zweiten zahlenden Kunden geschlossen sein
-- muss.
--
-- locations_writable() war davon NICHT betroffen -- dort stand der
-- Org-Check schon in der ursprünglichen USING-Klausel selbst
-- (locations_update_visible: "(org_id = current_org_id()) AND is_admin()
-- OR guild_founder_of_member(...)") und wurde entsprechend korrekt mit
-- übernommen.
--
-- Fix: jede der vier Funktionen bekommt zusätzlich "target.org_id =
-- current_org_id()" als Vorbedingung -- 1:1 dieselbe Grenze, die die
-- alte WITH-CHECK-Klausel für die neue Zeile durchsetzte, jetzt für die
-- ALTE (zu lesende) Zeile durchgesetzt. Da keine der vier Funktionen
-- org_id patchen kann (nicht in der jeweiligen Allowlist / kein
-- Parameter dafür), ist die neue Zeile ohnehin identisch in org_id --
-- die Vorbedingung auf der alten Zeile deckt damit exakt denselben Fall
-- ab wie vorher die WITH-CHECK-Prüfung auf der neuen.
-- ============================================================

create or replace function public.contacts_writable(target public.contacts)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    (target.org_id = current_org_id())
    and (
      ((target.owner_id is null) and (target.guild_id is not null) and guild_leadership_permission(target.guild_id))
      or ((target.owner_id = (select auth.uid())) or is_admin() or guild_contact_permission(target.owner_id, true))
    );
$$;

create or replace function public.sales_writable(target public.sales)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    (target.org_id = current_org_id())
    and exists (
      select 1 from public.contacts c
      where c.id = target.contact_id
        and (c.owner_id = (select auth.uid()) or is_admin())
    );
$$;

create or replace function public.termine_writable(target public.termine)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    (target.org_id = current_org_id())
    and ((target.owner_id = (select auth.uid())) or is_admin());
$$;

create or replace function public.termin_series_writable(target public.termin_series)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    (target.org_id = current_org_id())
    and ((target.owner_id = (select auth.uid())) or is_admin());
$$;
