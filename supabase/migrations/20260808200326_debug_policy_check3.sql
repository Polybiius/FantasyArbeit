CREATE OR REPLACE FUNCTION "public"."debug_list_location_policies2"()
RETURNS TABLE("policyname" "text", "permissive" "text", "cmd" "text", "roles" "text")
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT p.policyname::text, p.permissive::text, p.cmd::text, p.roles::text
  FROM pg_catalog.pg_policies p
  WHERE p.schemaname = 'public' AND p.tablename = 'locations';
$$;
