-- Aufräumen der Diagnose-Funktionen/-Policies aus der Fehlersuche, plus der
-- eigentliche Fix.
--
-- Ursache des Bugs: locations_update_guild_admission hatte korrektes
-- USING/WITH CHECK, aber Postgres verlangt bei UPDATE zusätzlich, dass die
-- Zeile auch über eine SELECT-Policy sichtbar ist (die UPDATE-eigene USING-
-- Klausel ersetzt die Sichtbarkeitsprüfung nicht, sie kommt obendrauf).
-- locations_select_org kannte aber nur bereits-aufgenommene Dungeons
-- (guild_id gesetzt) -- ein Gildenführer konnte die noch NICHT
-- aufgenommenen, privaten Dungeons eines Mitglieds also gar nicht sehen,
-- und damit erst recht nicht per UPDATE aufnehmen. Fix: dieselbe
-- guild_founder_of_member()-Bedingung, die die UPDATE-Policy schon nutzt,
-- zusätzlich in die SELECT-Policy aufnehmen.

-- === Diagnose-Reste entfernen ===
DROP POLICY IF EXISTS "debug_locations_update_always_true" ON "public"."locations";
DROP FUNCTION IF EXISTS "public"."debug_list_location_policies"();
DROP FUNCTION IF EXISTS "public"."debug_list_location_policies2"();
DROP FUNCTION IF EXISTS "public"."debug_eval_guild_admission_using"("uuid");
DROP FUNCTION IF EXISTS "public"."debug_eval_with_check"("uuid");
DROP FUNCTION IF EXISTS "public"."debug_raw_update"("uuid","uuid");
DROP FUNCTION IF EXISTS "public"."debug_column_grants"();
DROP FUNCTION IF EXISTS "public"."debug_context"("uuid");

-- === locations_update_admin_only wiederherstellen (wurde zum Testen entfernt) ===
CREATE POLICY "locations_update_admin_only" ON "public"."locations"
  FOR UPDATE
  USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));

-- === locations_update_guild_admission auf die echte, beabsichtigte Logik zurücksetzen ===
ALTER POLICY "locations_update_guild_admission" ON "public"."locations"
  USING (
    "public"."guild_founder_of_member"("owner_id")
    OR "public"."guild_founder_of_member"("created_by")
  )
  WITH CHECK (
    "guild_id" IS NULL
    OR EXISTS (
      SELECT 1 FROM "public"."guilds" g
      WHERE g."id" = "locations"."guild_id" AND g."founder_id" = "auth"."uid"()
    )
  );

-- === Der eigentliche Fix: SELECT-Sichtbarkeit für den Gildenführer auf
-- noch nicht aufgenommene, private Dungeons seiner Mitglieder ===
ALTER POLICY "locations_select_org" ON "public"."locations"
  USING (
    ("org_id" = "public"."current_org_id"())
    AND (
      ("owner_id" = "auth"."uid"())
      OR ("created_by" = "auth"."uid"())
      OR "public"."is_admin"()
      OR "public"."guild_dungeon_permission"("guild_id", false)
      OR "public"."guild_founder_of_member"("owner_id")
      OR "public"."guild_founder_of_member"("created_by")
    )
  );
