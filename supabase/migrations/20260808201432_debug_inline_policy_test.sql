DROP POLICY IF EXISTS "locations_update_guild_admission" ON "public"."locations";

CREATE POLICY "locations_update_guild_admission" ON "public"."locations"
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.guild_members gm
      JOIN public.guilds g ON g.id = gm.guild_id
      WHERE gm.member_id = locations.owner_id AND g.founder_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.guild_members gm
      JOIN public.guilds g ON g.id = gm.guild_id
      WHERE gm.member_id = locations.created_by AND g.founder_id = auth.uid()
    )
  )
  WITH CHECK (
    guild_id IS NULL
    OR EXISTS (
      SELECT 1 FROM public.guilds g
      WHERE g.id = guild_id AND g.founder_id = auth.uid()
    )
  );
