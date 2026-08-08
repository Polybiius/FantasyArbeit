CREATE OR REPLACE FUNCTION "public"."debug_column_grants"()
RETURNS TABLE("grantee" "text", "column_name" "text", "privilege_type" "text")
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT g.grantee::text, g.column_name::text, g.privilege_type::text
  FROM information_schema.column_privileges g
  WHERE g.table_schema='public' AND g.table_name='locations'
    AND g.privilege_type='UPDATE'
  ORDER BY g.grantee, g.column_name;
$$;
