-- Rein diagnostisch: prüfen, ob locations_update_admin_only mit der neuen
-- Policy interferiert. Wird gleich danach wiederhergestellt.
DROP POLICY IF EXISTS "locations_update_admin_only" ON "public"."locations";
