CREATE OR REPLACE FUNCTION "public"."debug_context"("loc_id" "uuid")
RETURNS TABLE("cur_role" "text", "cur_uid" "uuid", "row_exists_for_me" boolean, "rowsecurity_active" boolean)
LANGUAGE "plpgsql"
SECURITY INVOKER
SET "search_path" = ''
AS $$
BEGIN
  RETURN QUERY SELECT
    current_setting('role', true),
    auth.uid(),
    EXISTS(SELECT 1 FROM public.locations WHERE id = loc_id),
    (SELECT c.relrowsecurity FROM pg_catalog.pg_class c WHERE c.oid = 'public.locations'::regclass);
END;
$$;
