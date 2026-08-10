-- Chronik-Sichtbarkeit folgt jetzt automatisch der Kontakt-Freigabe
-- (Gilden-Lese-/Schreibrecht) -- keine eigene Einstellung, Nutzerentscheidung
-- 2026-08-10: "wenn man die Kontakte sehen kann, gehört die Chronik dazu."
--
-- Hintergrund: der Kontakt selbst (contacts) folgt schon seit Phase 1
-- (2026-08-08) guild_contact_permission(). Die Kontakt-Chronik im Frontend
-- ist aber keine eigene Tabelle, sondern eine im UI zusammengesetzte Sicht
-- auf VIER separate Tabellen -- keine davon kannte die Gilden-Freigabe:
-- - action_log/sales hatten schon eine "geteilter Kontakt"-Sonderregel,
--   aber nur auf Basis der ALTEN organisationsweiten
--   contacts_shared_for_org()-Einstellung (bleibt als Fallback erhalten,
--   genau wie bei contacts selbst -- wird nicht entfernt, nur ergänzt).
-- - contact_activities/termine hatten GAR KEINE Freigabe-Regel, nur
--   Eigentümer oder Admin.
--
-- guild_contact_permission(owner_id, false) mit need_write=false ist absichtlich
-- gewählt -- die Funktion liefert dann true für JEDES Gildenmitglied mit
-- Zugriff auf den Kontakt, unabhängig davon, ob es 'read' oder 'write' hat
-- (need_write wird nur bei true zur zusätzlichen Bedingung). Genau das war
-- gewünscht: Sichtbarkeit hängt an "kann den Kontakt sehen", nicht an
-- Schreibrecht.

ALTER POLICY "log_select_shared_contact_activity" ON "public"."action_log"
  USING (
    contact_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.id = action_log.contact_id
        AND c.org_id = public.current_org_id()
        AND (public.contacts_shared_for_org() OR public.guild_contact_permission(c.owner_id, false))
    )
  );

ALTER POLICY "sales_select_like_contact" ON "public"."sales"
  USING (
    EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.id = sales.contact_id
        AND (
          c.owner_id = auth.uid()
          OR public.is_admin()
          OR (c.org_id = public.current_org_id() AND public.contacts_shared_for_org())
          OR public.guild_contact_permission(c.owner_id, false)
        )
    )
  );

CREATE POLICY "contact_activities_select_shared_contact" ON "public"."contact_activities"
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.id = contact_activities.contact_id
        AND public.guild_contact_permission(c.owner_id, false)
    )
  );

CREATE POLICY "termine_select_shared_contact" ON "public"."termine"
  FOR SELECT USING (
    contact_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.id = termine.contact_id
        AND public.guild_contact_permission(c.owner_id, false)
    )
  );
