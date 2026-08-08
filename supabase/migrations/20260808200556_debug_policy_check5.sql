-- Diagnostisch: führt ein direktes UPDATE (SECURITY INVOKER, also mit
-- den Rechten/RLS des Aufrufers, kein PostgREST dazwischen) zum selben
-- Ergebnis wie über die REST-API?
CREATE OR REPLACE FUNCTION "public"."debug_raw_update"("loc_id" "uuid", "new_guild" "uuid")
RETURNS integer
LANGUAGE "plpgsql"
SECURITY INVOKER
SET "search_path" = ''
AS $$
DECLARE
  affected integer;
BEGIN
  UPDATE public.locations SET guild_id = new_guild WHERE id = loc_id;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;
