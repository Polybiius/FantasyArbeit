CREATE OR REPLACE FUNCTION "public"."debug_eval_with_check"("target_guild" "uuid")
RETURNS boolean
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT (target_guild IS NULL) OR EXISTS (
    SELECT 1 FROM public.guilds g
    WHERE g.id = target_guild AND g.founder_id = auth.uid()
  );
$$;
