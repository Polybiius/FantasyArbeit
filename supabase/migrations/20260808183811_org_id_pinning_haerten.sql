-- Sicherheits-Härtung, Fund vom 2026-08-08.
--
-- org_id wurde bei INSERT teils, bei UPDATE bei fast keiner
-- "gehört mir persönlich"-Tabelle (contacts, contact_activities, sales,
-- termine, termin_series, friends, journal_entries,
-- journal_entry_mentions, journal_photos, user_inventory) explizit
-- geprüft -- nur die Eigentümerschaft (owner_id/user_id) war abgesichert.
-- Ohne eigene WITH CHECK-Klausel gilt bei UPDATE automatisch dieselbe
-- USING-Bedingung auch für die neue Zeile, aber die referenziert nirgends
-- org_id -- ein Nutzer konnte also technisch per direktem API-Aufruf einen
-- eigenen Datensatz auf eine beliebige org_id umbiegen. Heute (nur eine
-- Organisation, DEFAULT_ORG_ID) folgenlos, aber ein Zeitzünder fuer den
-- Tag, an dem eine zweite echte Kundenorganisation auf derselben
-- Datenbank existiert (siehe CLAUDE.md, "Multi-Org-Loskopplung") --
-- dann koennte so ein Datensatz in der Sicht einer fremden Organisation
-- auftauchen. Fix: WITH CHECK ergänzt org_id = current_org_id(), analog
-- zum bereits bestehenden Muster bei locations/products/rule_configs.
--
-- Bewusst NICHT Teil dieser Migration: eine Katalog-Prüfung für
-- user_inventory.item_key (blockt erfundene Item-Schlüssel) war zunächst
-- mit dabei, wurde aber auf Nutzerwunsch rausgenommen -- das Item-/
-- Mengen-System wird ohnehin noch umgebaut (Manatrank war bisher nur ein
-- Bauphase-Hilfsmittel für Energie-Nachschub), eine Katalog-Prüfung jetzt
-- würde beim Umbau vermutlich gleich wieder angepasst werden müssen.
-- Bei Bedarf nach dem Umbau erneut aufgreifen.

-- === 1) org_id in WITH CHECK ergänzen ===

ALTER POLICY "contacts_update_owner_or_admin" ON "public"."contacts"
  WITH CHECK ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "contact_activities_update_own_or_admin" ON "public"."contact_activities"
  WITH CHECK ((("user_id" = "auth"."uid"()) OR "public"."is_admin"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "sales_update_like_contact" ON "public"."sales"
  WITH CHECK (
    (EXISTS ( SELECT 1 FROM "public"."contacts" "c"
      WHERE (("c"."id" = "sales"."contact_id") AND (("c"."owner_id" = "auth"."uid"()) OR "public"."is_admin"()))))
    AND ("org_id" = "public"."current_org_id"())
  );

ALTER POLICY "termine_update_owner_or_admin" ON "public"."termine"
  WITH CHECK ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "termin_series_update_owner_or_admin" ON "public"."termin_series"
  WITH CHECK ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "friends_insert_own" ON "public"."friends"
  WITH CHECK (("owner_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "friends_update_recipient_accepts" ON "public"."friends"
  WITH CHECK (("friend_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "journal_insert_own_only" ON "public"."journal_entries"
  WITH CHECK (("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "journal_update_own_only" ON "public"."journal_entries"
  WITH CHECK (("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "journal_mentions_insert_own_only" ON "public"."journal_entry_mentions"
  WITH CHECK (("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "journal_photos_insert_own" ON "public"."journal_photos"
  WITH CHECK (("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "journal_photos_update_own" ON "public"."journal_photos"
  WITH CHECK (("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "inventory_insert_own" ON "public"."user_inventory"
  WITH CHECK (("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));

ALTER POLICY "inventory_update_own" ON "public"."user_inventory"
  WITH CHECK (("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"()));
