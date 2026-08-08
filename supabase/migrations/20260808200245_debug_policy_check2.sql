-- Temporäre Diagnose-Funktion, wird in der nächsten Migration wieder entfernt.
CREATE OR REPLACE FUNCTION "public"."debug_eval_guild_admission_using"("loc_id" "uuid")
RETURNS TABLE("row_owner" "uuid", "row_created_by" "uuid", "caller" "uuid", "founder_check_owner" boolean, "founder_check_created_by" boolean, "combined" boolean)
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT l.owner_id, l.created_by, auth.uid(),
         public.guild_founder_of_member(l.owner_id),
         public.guild_founder_of_member(l.created_by),
         (public.guild_founder_of_member(l.owner_id) OR public.guild_founder_of_member(l.created_by))
  FROM public.locations l
  WHERE l.id = loc_id;
$$;
