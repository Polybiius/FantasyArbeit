-- Für die Orden/Freunde-Seite: bewegter Avatar + anklickbares Sigil eines
-- Freundes oder Gildenmitglieds. Level/Klasse waren schon immer sozial
-- sichtbar (siehe CLAUDE.md), das Sigil (Skill-Aufschlüsselung) ist eine
-- naheliegende Erweiterung derselben, längst etablierten "RPG-Fortschritt
-- ist unter Freunden/Gilde sichtbar"-Philosophie -- betrifft nur XP/Skills,
-- keine CRM-Geschäftsdaten (Kontakte/Dungeons bleiben unangetastet).
--
-- Bewusst KEINE breite SELECT-Policy auf action_log direkt (das würde auch
-- `context`/`meta`/`location_id`/`contact_id` offenlegen, potenziell
-- geschäftsbezogene Notizen) -- stattdessen eine schmale RPC-Funktion, die
-- nur die aggregierten Skill-Summen zurückgibt, genau das, was fürs Sigil
-- gebraucht wird.

CREATE OR REPLACE FUNCTION "public"."socially_visible"("target_user" "uuid")
RETURNS boolean
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT target_user = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.friends f
      WHERE f.status = 'accepted'
        AND ((f.owner_id = auth.uid() AND f.friend_id = target_user)
          OR (f.friend_id = auth.uid() AND f.owner_id = target_user))
    )
    OR EXISTS (
      SELECT 1 FROM public.guild_members mine
      JOIN public.guild_members theirs ON theirs.guild_id = mine.guild_id
      WHERE mine.member_id = auth.uid() AND theirs.member_id = target_user
    );
$$;

CREATE OR REPLACE FUNCTION "public"."friend_skill_totals"("target_user" "uuid")
RETURNS TABLE("skill_key" "text", "xp_sum" bigint)
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT t.skill_key, SUM(t.xp_contribution)::bigint
  FROM (
    SELECT a.skill AS skill_key, a.xp AS xp_contribution
    FROM public.action_log a
    WHERE a.user_id = target_user AND a.skill IS NOT NULL
      AND public.socially_visible(target_user)
    UNION ALL
    SELECT a.skill2 AS skill_key, ROUND(a.xp * 0.4)::bigint AS xp_contribution
    FROM public.action_log a
    WHERE a.user_id = target_user AND a.skill2 IS NOT NULL
      AND public.socially_visible(target_user)
  ) t
  GROUP BY t.skill_key;
$$;
