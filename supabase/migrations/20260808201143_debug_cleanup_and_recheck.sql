-- Diagnose-Policy wieder entfernen, echte Policies bleiben unangetastet.
DROP POLICY IF EXISTS "debug_locations_update_always_true" ON "public"."locations";
