-- Schließt eine echte Lücke, die eine unabhängige Zweitmeinung
-- (/code-review high) am selben Tag am Frontend-Fix für die
-- canEdit-Rechtemodell-Lücke gefunden hat (siehe CLAUDE.md, Abschnitt
-- "Rechtemodell-Lücke: canEdit berücksichtigt Gilden-Schreibrecht"):
-- der Frontend-Fix zeigt einem Gildenmitglied mit
-- guild_members.contacts_access='write' jetzt auch "Löschen",
-- "Gekündigt/ausgelaufen" (cancel_sale_locked) und "+ Verkauf
-- eintragen" auf einem fremden, geteilten Kontakt an -- aber genau
-- diese drei Berechtigungs-Stellen kannten guild_contact_permission()
-- bisher NICHT (anders als contacts_writable(), das die Bearbeiten-
-- Aktion schon korrekt deckt, und sales_select_like_contact/
-- contact_files_*, die beim Lesen bzw. Datei-Upload schon korrekt sind).
--
-- Ohne diesen Fix hätte der Frontend-Fix allein drei aktive, aber
-- garantiert scheiternde Buttons erzeugt:
--   1. "Löschen" (contacts_delete_owner_or_admin): DELETE betrifft 0
--      Zeilen, PostgREST liefert dafür keinen Fehler zurück -- die App
--      hätte "gelöscht" angezeigt, obwohl der Kontakt weiter existiert
--      (stiller Fehlschlag, kein sichtbarer Fehler).
--   2. "Gekündigt/ausgelaufen" (sales_writable(), Basis von
--      cancel_sale_locked()): harter RLS-/RPC-Fehler.
--   3. "+ Verkauf eintragen" (sales_insert_like_contact): harter
--      RLS-Fehler beim Insert.
--
-- Fix: alle drei Stellen bekommen exakt denselben
-- guild_contact_permission(owner_id, true)-Zweig, den
-- contacts_writable()/sales_select_like_contact bereits nutzen -- keine
-- neue Berechtigungslogik, nur Konsistenz zwischen den Stellen, die
-- "Schreibrecht auf einen geteilten Kontakt" prüfen.
--
-- sales_delete_like_contact wird der Konsistenz halber im selben Zug
-- mitgezogen (Fund einer weiteren Zweitmeinungsrunde): kein "Verkauf
-- löschen"-Button existiert im Frontend, die Policy ist heute inert --
-- aber sie unangetastet zu lassen, während ihre drei Schwester-Policies
-- (sales_writable/sales_insert_like_contact/contacts_delete_owner_or_admin)
-- im selben Zug den Gilden-Zweig bekommen, wäre eine stille Falle für ein
-- künftiges "Verkauf löschen"-Feature (naheliegende Ergänzung neben den
-- bereits vorhandenen "Löschen"/"+ Verkauf eintragen"-Buttons) -- es
-- würde denselben Fehler reproduzieren, den diese Migration gerade
-- behebt, nur eine Ebene später.
--
-- Zusätzlicher, beim Gegenlesen selbst gefundener Fund (kein Teil des
-- ursprünglichen Zweitmeinungs-Berichts): contacts_delete_owner_or_admin
-- hatte -- anders als contacts_writable()/sales_writable()/
-- termine_writable() seit deren eigener Nachbesserung
-- (20260824190000_locked_write_org_boundary_fix.sql) -- NIE eine
-- org_id-Grenze in der is_admin()-Bedingung. is_admin() prüft nur die
-- Rolle des Aufrufers, nicht die Organisation der Zielzeile -- ein Admin
-- hätte damit (nur per erratener/bekannter Kontakt-UUID) auch einen
-- Kontakt einer FREMDEN Organisation löschen können. Beim aktuellen
-- Einzel-Org-Betrieb (nur DEFAULT_ORG_ID) folgenlos, aber exakt die
-- Lückenklasse, die vor dem ersten zweiten zahlenden Kunden geschlossen
-- sein muss (siehe CLAUDE.md, "Technische Skalierungs-Schwellen" /
-- Mandantentrennung) -- wird hier, da die Policy ohnehin für den
-- Gilden-Fix angefasst wird, im selben Zug mit erledigt. Ob dieselbe
-- Lücke (is_admin() ohne org_id-Vergleich) noch an anderen,
-- unangetasteten Policies im Schema existiert, ist NICHT Teil dieses
-- Fixes -- das gehört in einen eigenen, systematischen Audit als Teil
-- der eigentlichen Mandantentrennungs-Arbeit, nicht hier nebenbei.

begin;

alter policy "contacts_delete_owner_or_admin" on public.contacts
  using (((org_id = current_org_id()) and ((owner_id = (select auth.uid())) or is_admin() or guild_contact_permission(owner_id, true))));

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
        and (
          (c.owner_id is null and c.guild_id is not null and guild_leadership_permission(c.guild_id))
          or c.owner_id = (select auth.uid()) or is_admin() or guild_contact_permission(c.owner_id, true)
        )
    );
$$;

alter policy "sales_insert_like_contact" on public.sales
  with check (
    (org_id = current_org_id())
    and (created_by = (select auth.uid()))
    and (exists (
      select 1 from public.contacts c
      where c.id = sales.contact_id
        and (
          (c.owner_id is null and c.guild_id is not null and guild_leadership_permission(c.guild_id))
          or c.owner_id = (select auth.uid()) or is_admin() or guild_contact_permission(c.owner_id, true)
        )
    ))
  );

alter policy "sales_delete_like_contact" on public.sales
  using (exists (
    select 1 from public.contacts c
    where c.id = sales.contact_id
      and (
        (c.owner_id is null and c.guild_id is not null and guild_leadership_permission(c.guild_id))
        or c.owner_id = (select auth.uid()) or is_admin() or guild_contact_permission(c.owner_id, true)
      )
  ));

commit;
