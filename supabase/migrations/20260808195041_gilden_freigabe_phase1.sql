-- Gilden-basierte Sichtbarkeit, Phase 1 (2026-08-08).
--
-- Löst die bekannte, bisher bewusst tolerierte Lücke: jedes Org-Mitglied
-- sah bisher ALLE Dungeons (locations_select_org kannte keine
-- Eigentümer-Einschränkung), Kontakte liefen über einen einzigen
-- organisationsweiten "privat"/"geteilt"-Schalter. Ab jetzt: Grundzustand
-- ist "niemand sieht meine Dungeons/Kontakte", Sichtbarkeit entsteht
-- ausschließlich über Gilden-Mitgliedschaft mit explizit vergebenem
-- Rechte-Level (Least-Privilege / Deny-by-Default).
--
-- Kernidee (ausführlich mit dem Nutzer durchgesprochen, 2026-08-08):
-- - Kontakte und Dungeons sind zwei UNABHÄNGIGE Freigaben, keine hängt
--   von der anderen ab. Kontakte sind der eigentliche Kern (CRM), Dungeons
--   nur die spielerische Organisationsschicht obendrüber.
-- - Kontakt-Freigabe: pauschal für ALLE Kontakte eines Gilden-Mitglieds
--   (nicht pro Kontakt einzeln), Level 'read' (Standard) oder 'write'.
-- - Dungeon-Freigabe: ein Dungeon gehört zu höchstens einer Gilde
--   (locations.guild_id). Neue Dungeons eines Mitglieds mit
--   dungeons_access='write' landen automatisch im Pool seiner Gilde.
--   Bringt jemand beim Beitritt bereits bestehende, private Dungeons mit,
--   entscheidet einmalig der Gildengründer, ob sie in den Pool aufgenommen
--   werden (eigene Frontend-Funktion, kein DB-Zwang).
-- - team_rights ist als Spalte schon mit dabei (spätere Mitverwaltung),
--   wird in Phase 1 noch nicht ausgewertet.

-- === guild_members: Rechte-Spalten ===

ALTER TABLE "public"."guild_members"
  ADD COLUMN "contacts_access" "text" NOT NULL DEFAULT 'read',
  ADD COLUMN "dungeons_access" "text" NOT NULL DEFAULT 'read',
  ADD COLUMN "team_rights" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."guild_members"
  ADD CONSTRAINT "guild_members_contacts_access_check" CHECK ("contacts_access" IN ('read','write')),
  ADD CONSTRAINT "guild_members_dungeons_access_check" CHECK ("dungeons_access" IN ('read','write'));

-- === locations: Gilden-Zugehörigkeit ===

ALTER TABLE "public"."locations"
  ADD COLUMN "guild_id" "uuid" REFERENCES "public"."guilds"("id") ON DELETE SET NULL;

-- === Helferfunktionen ===

-- Darf auth.uid() die Kontakte von target_owner sehen (need_write=false)
-- bzw. bearbeiten (need_write=true), weil beide in derselben Gilde sind
-- und auth.uid() dort das passende Rechte-Level hat?
CREATE OR REPLACE FUNCTION "public"."guild_contact_permission"("target_owner" "uuid", "need_write" boolean)
RETURNS boolean
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.guild_members mine
    JOIN public.guild_members theirs
      ON theirs.guild_id = mine.guild_id
     AND theirs.member_id = target_owner
    WHERE mine.member_id = auth.uid()
      AND (NOT need_write OR mine.contacts_access = 'write')
  );
$$;

-- Darf auth.uid() einen Dungeon mit dieser guild_id sehen (need_write=false)
-- bzw. neue Dungeons in dieser Gilde anlegen (need_write=true)?
CREATE OR REPLACE FUNCTION "public"."guild_dungeon_permission"("loc_guild_id" "uuid", "need_write" boolean)
RETURNS boolean
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT loc_guild_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.guild_members mine
    WHERE mine.member_id = auth.uid()
      AND mine.guild_id = loc_guild_id
      AND (NOT need_write OR mine.dungeons_access = 'write')
  );
$$;

-- Ist auth.uid() Gründer der Gilde, in der target_owner Mitglied ist?
-- (für die einmalige Dungeon-Pool-Aufnahme beim Beitritt eines Mitglieds
-- mit bereits bestehenden, privaten Dungeons)
CREATE OR REPLACE FUNCTION "public"."guild_founder_of_member"("target_owner" "uuid")
RETURNS boolean
LANGUAGE "sql"
SECURITY DEFINER
SET "search_path" = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.guild_members gm
    JOIN public.guilds g ON g.id = gm.guild_id
    WHERE gm.member_id = target_owner
      AND g.founder_id = auth.uid()
  );
$$;

-- Der Gildengründer darf die Rechte-Spalten seiner Mitglieder ändern
-- (existierte bisher gar keine UPDATE-Policy für guild_members).
CREATE POLICY "guild_members_update_founder_sets_rights" ON "public"."guild_members"
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM "public"."guilds" g WHERE g."id" = "guild_members"."guild_id" AND g."founder_id" = "auth"."uid"())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM "public"."guilds" g WHERE g."id" = "guild_members"."guild_id" AND g."founder_id" = "auth"."uid"())
  );

-- === Kontakte: Gilden-Freigabe ergänzen ===

ALTER POLICY "contacts_select_own_or_shared_or_admin" ON "public"."contacts"
  USING (
    ("owner_id" = "auth"."uid"())
    OR "public"."is_admin"()
    OR (("org_id" = "public"."current_org_id"()) AND "public"."contacts_shared_for_org"())
    OR "public"."guild_contact_permission"("owner_id", false)
  );

ALTER POLICY "contacts_update_owner_or_admin" ON "public"."contacts"
  USING (
    ("owner_id" = "auth"."uid"())
    OR "public"."is_admin"()
    OR "public"."guild_contact_permission"("owner_id", true)
  )
  WITH CHECK (
    (("owner_id" = "auth"."uid"()) OR "public"."is_admin"() OR "public"."guild_contact_permission"("owner_id", true))
    AND ("org_id" = "public"."current_org_id"())
  );

-- === Dungeons: org-weite Sichtbarkeit ersetzen durch Eigentümer/Gilde/Admin ===

ALTER POLICY "locations_select_org" ON "public"."locations"
  USING (
    ("org_id" = "public"."current_org_id"())
    AND (
      ("owner_id" = "auth"."uid"())
      OR ("created_by" = "auth"."uid"())
      OR "public"."is_admin"()
      OR "public"."guild_dungeon_permission"("guild_id", false)
    )
  );

-- Neue Dungeons dürfen nur mit guild_id=NULL (privat) oder einer Gilde
-- angelegt werden, in der man selbst Schreibrecht auf Dungeons hat.
ALTER POLICY "locations_insert_org_members" ON "public"."locations"
  WITH CHECK (
    ("org_id" = "public"."current_org_id"())
    AND (
      "guild_id" IS NULL
      OR "public"."guild_dungeon_permission"("guild_id", true)
    )
  );

-- Der Gildengründer darf guild_id an Dungeons setzen, deren Eigentümer
-- (oder ursprünglicher Ersteller) Mitglied seiner Gilde ist -- die
-- einmalige Beitritts-Aufnahme in den Pool. Eigenständige, zusätzliche
-- Policy neben der bestehenden admin-exklusiven Umverteilungs-Policy
-- (locations_update_admin_only bleibt unverändert für owner_id-Reassignment).
CREATE POLICY "locations_update_guild_admission" ON "public"."locations"
  FOR UPDATE
  USING (
    "public"."guild_founder_of_member"("owner_id")
    OR "public"."guild_founder_of_member"("created_by")
  )
  WITH CHECK (
    "guild_id" IS NULL
    OR EXISTS (
      SELECT 1 FROM "public"."guilds" g
      WHERE g."id" = "locations"."guild_id" AND g."founder_id" = "auth"."uid"()
    )
  );
