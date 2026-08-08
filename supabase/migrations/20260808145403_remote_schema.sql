


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."contacts_shared_for_org"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  select coalesce(
    (select config->>'contactsVisibility' from public.rule_configs where org_id = public.current_org_id()) = 'shared',
    false
  )
$$;


ALTER FUNCTION "public"."contacts_shared_for_org"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_org_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  select org_id from public.profiles where id = auth.uid()
$$;


ALTER FUNCTION "public"."current_org_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_profile_insert_defaults"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  new.role := 'member';
  new.org_id := '00000000-0000-0000-0000-000000000001'::uuid;
  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_profile_insert_defaults"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  select coalesce((select role from public.profiles where id = auth.uid()) = 'admin', false)
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."protect_privileged_profile_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  if not public.is_admin() then
    if new.role is distinct from old.role then
      raise exception 'Nur Admins dürfen die Rolle ändern.';
    end if;
    if new.character_class is distinct from old.character_class then
      raise exception 'Die Charakterklasse kann nicht direkt geändert werden.';
    end if;
    if new.org_id is distinct from old.org_id then
      raise exception 'org_id kann nicht direkt geändert werden.';
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."protect_privileged_profile_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_initial_seen_patch"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.last_seen_patch_number is null then
    new.last_seen_patch_number := coalesce((select max(patch_number) from public.schema_patches), 0);
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."set_initial_seen_patch"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_contacts_owner_on_location_reassign"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  if new.owner_id is distinct from old.owner_id then
    update public.contacts set owner_id = new.owner_id where location_id = new.id;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."sync_contacts_owner_on_location_reassign"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."action_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "action_key" "text" NOT NULL,
    "label" "text" NOT NULL,
    "xp" integer NOT NULL,
    "energy" integer DEFAULT 0 NOT NULL,
    "skill" "text",
    "skill2" "text",
    "context" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "meta" "jsonb",
    "location_id" "uuid",
    "contact_id" "uuid"
);


ALTER TABLE "public"."action_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."contact_activities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "contact_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "outcome" "text",
    "betreff" "text",
    "inhalt" "text",
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "action_log_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "contact_activities_type_check" CHECK (("type" = ANY (ARRAY['anruf'::"text", 'email'::"text"])))
);


ALTER TABLE "public"."contact_activities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."contacts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "role" "text",
    "location_id" "uuid",
    "status" "text" DEFAULT 'kalt'::"text" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vorname" "text" DEFAULT ''::"text" NOT NULL,
    "nachname" "text" DEFAULT ''::"text" NOT NULL,
    "name" "text" GENERATED ALWAYS AS (TRIM(BOTH FROM (("vorname" || ' '::"text") || "nachname"))) STORED,
    "bedarf_ist" "text",
    "bedarf_wunsch" "text",
    "naechster_kontakt" "date",
    "geburtsdatum" "date",
    "telefon" "text",
    "email" "text",
    "wohnort_strasse" "text",
    "wohnort_ort" "text",
    "kanban_stage" "text",
    CONSTRAINT "contacts_kanban_stage_check" CHECK (("kanban_stage" = ANY (ARRAY['neuer_lead'::"text", 'ersttermin_vereinbart'::"text", 'nicht_erschienen'::"text", 'angebot_versendet'::"text", 'zweittermin'::"text", 'gewonnen'::"text", 'verloren'::"text", 'dauerbrenner'::"text"]))),
    CONSTRAINT "contacts_status_check" CHECK (("status" = ANY (ARRAY['kalt'::"text", 'warm'::"text", 'kunde'::"text", 'verloren'::"text"])))
);


ALTER TABLE "public"."contacts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."error_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "context" "text" NOT NULL,
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."error_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."friends" (
    "owner_id" "uuid" NOT NULL,
    "friend_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    CONSTRAINT "friends_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text"])))
);


ALTER TABLE "public"."friends" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guild_members" (
    "member_id" "uuid" NOT NULL,
    "guild_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."guild_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guilds" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "founder_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."guilds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."journal_entries" (
    "user_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "entry_date" "date" NOT NULL,
    "q1" "text",
    "q2" "text",
    "q3" "text",
    "q4" "text",
    "q5" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."journal_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."journal_entry_mentions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "entry_date" "date" NOT NULL,
    "contact_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."journal_entry_mentions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."journal_photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "entry_date" "date" NOT NULL,
    "storage_path" "text" NOT NULL,
    "transformed_path" "text",
    "transform_status" "text" DEFAULT 'none'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."journal_photos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "lat" double precision NOT NULL,
    "lng" double precision NOT NULL,
    "address" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "owner_id" "uuid",
    "plz" "text",
    "strasse" "text",
    "stadt" "text"
);


ALTER TABLE "public"."locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "timezone" "text" DEFAULT 'Europe/Berlin'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "key" "text" NOT NULL,
    "name" "text" NOT NULL,
    "category" "text" NOT NULL,
    "subcategory" "text",
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "bwp_faktor" numeric,
    "provision_faktor" numeric,
    "provision_mode" "text" DEFAULT 'fest'::"text" NOT NULL,
    "recontact_amount" integer,
    "recontact_unit" "text",
    CONSTRAINT "products_provision_mode_check" CHECK (("provision_mode" = ANY (ARRAY['fest'::"text", 'individuell_lv'::"text", 'individuell_kv'::"text"]))),
    CONSTRAINT "products_recontact_unit_check" CHECK (("recontact_unit" = ANY (ARRAY['tage'::"text", 'wochen'::"text", 'monate'::"text", 'jahre'::"text"])))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "display_name" "text" DEFAULT 'Namenloser Held'::"text" NOT NULL,
    "role" "text" DEFAULT 'member'::"text" NOT NULL,
    "character_class" "text" DEFAULT 'zauberer'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "equipped_weapon" "text",
    "equipped_armor" "text",
    "equipped_accessory" "text",
    "total_xp" integer DEFAULT 0 NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "real_name" "text",
    "gender" "text",
    "company" "text",
    "skin_tone" "text",
    "hair_style" "text",
    "lv_promille_satz" numeric,
    "kv_mb_satz" numeric,
    "planung_lv_bws" numeric,
    "planung_kv_mb" numeric,
    "planung_bwp" numeric,
    "planung_vks" numeric,
    "planung_fa" numeric,
    "last_seen_patch_number" integer,
    "arbeitszeiten" "jsonb",
    "calendar_hide_weekends" boolean DEFAULT false NOT NULL,
    "calendar_show_birthdays" boolean DEFAULT true NOT NULL,
    "chronik_show_xp" boolean DEFAULT false NOT NULL,
    CONSTRAINT "profiles_gender_check" CHECK (("gender" = ANY (ARRAY['m'::"text", 'w'::"text"]))),
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'member'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rule_configs" (
    "org_id" "uuid" NOT NULL,
    "config" "jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."rule_configs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "contact_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "datum" "date" DEFAULT CURRENT_DATE NOT NULL,
    "status" "text" DEFAULT 'gewonnen'::"text" NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "menge" integer DEFAULT 1 NOT NULL,
    "product_id" "uuid" NOT NULL,
    "bewertungssumme" numeric,
    "laufender_beitrag" numeric,
    "vertragsbeginn" "date",
    "vertragsende" "date",
    CONSTRAINT "sales_status_check" CHECK (("status" = ANY (ARRAY['gewonnen'::"text", 'verloren'::"text"])))
);


ALTER TABLE "public"."sales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."schema_patches" (
    "patch_number" integer NOT NULL,
    "title" "text" NOT NULL,
    "applied_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."schema_patches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."termin_series" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "contact_id" "uuid",
    "location_id" "uuid",
    "title" "text" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "freq" "text" NOT NULL,
    "interval_n" integer DEFAULT 1 NOT NULL,
    "weekdays" smallint[],
    "start_date" "date" NOT NULL,
    "until_date" "date",
    "generated_until" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "termin_series_check" CHECK (("end_time" > "start_time")),
    CONSTRAINT "termin_series_freq_check" CHECK (("freq" = ANY (ARRAY['taeglich'::"text", 'woechentlich'::"text", 'monatlich'::"text"]))),
    CONSTRAINT "termin_series_interval_n_check" CHECK (("interval_n" > 0))
);


ALTER TABLE "public"."termin_series" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."termine" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "contact_id" "uuid",
    "location_id" "uuid",
    "title" "text" NOT NULL,
    "start_at" timestamp with time zone NOT NULL,
    "end_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "series_id" "uuid",
    CONSTRAINT "termine_check" CHECK (("end_at" > "start_at"))
);


ALTER TABLE "public"."termine" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_inventory" (
    "user_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "item_key" "text" NOT NULL,
    "quantity" integer DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_inventory" OWNER TO "postgres";


ALTER TABLE ONLY "public"."action_log"
    ADD CONSTRAINT "action_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."contact_activities"
    ADD CONSTRAINT "contact_activities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."contacts"
    ADD CONSTRAINT "contacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."error_log"
    ADD CONSTRAINT "error_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_pkey" PRIMARY KEY ("owner_id", "friend_id");



ALTER TABLE ONLY "public"."guild_members"
    ADD CONSTRAINT "guild_members_pkey" PRIMARY KEY ("member_id");



ALTER TABLE ONLY "public"."guilds"
    ADD CONSTRAINT "guilds_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."journal_entries"
    ADD CONSTRAINT "journal_entries_pkey" PRIMARY KEY ("user_id", "entry_date");



ALTER TABLE ONLY "public"."journal_entry_mentions"
    ADD CONSTRAINT "journal_entry_mentions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."journal_entry_mentions"
    ADD CONSTRAINT "journal_entry_mentions_user_id_entry_date_contact_id_key" UNIQUE ("user_id", "entry_date", "contact_id");



ALTER TABLE ONLY "public"."journal_photos"
    ADD CONSTRAINT "journal_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."journal_photos"
    ADD CONSTRAINT "journal_photos_user_id_entry_date_key" UNIQUE ("user_id", "entry_date");



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_org_id_key_key" UNIQUE ("org_id", "key");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rule_configs"
    ADD CONSTRAINT "rule_configs_pkey" PRIMARY KEY ("org_id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."schema_patches"
    ADD CONSTRAINT "schema_patches_pkey" PRIMARY KEY ("patch_number");



ALTER TABLE ONLY "public"."termin_series"
    ADD CONSTRAINT "termin_series_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."termine"
    ADD CONSTRAINT "termine_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_pkey" PRIMARY KEY ("user_id", "item_key");



CREATE INDEX "action_log_org_idx" ON "public"."action_log" USING "btree" ("org_id", "created_at");



CREATE INDEX "action_log_user_idx" ON "public"."action_log" USING "btree" ("user_id", "created_at");



CREATE INDEX "contact_activities_contact_idx" ON "public"."contact_activities" USING "btree" ("contact_id", "occurred_at");



CREATE INDEX "contact_activities_org_idx" ON "public"."contact_activities" USING "btree" ("org_id");



CREATE INDEX "contacts_kanban_stage_idx" ON "public"."contacts" USING "btree" ("org_id", "kanban_stage");



CREATE INDEX "contacts_location_idx" ON "public"."contacts" USING "btree" ("location_id");



CREATE INDEX "contacts_org_idx" ON "public"."contacts" USING "btree" ("org_id");



CREATE INDEX "contacts_owner_idx" ON "public"."contacts" USING "btree" ("owner_id");



CREATE INDEX "error_log_org_idx" ON "public"."error_log" USING "btree" ("org_id", "created_at" DESC);



CREATE INDEX "locations_org_idx" ON "public"."locations" USING "btree" ("org_id");



CREATE INDEX "products_org_idx" ON "public"."products" USING "btree" ("org_id");



CREATE INDEX "profiles_org_idx" ON "public"."profiles" USING "btree" ("org_id");



CREATE INDEX "sales_contact_idx" ON "public"."sales" USING "btree" ("contact_id");



CREATE INDEX "sales_org_idx" ON "public"."sales" USING "btree" ("org_id");



CREATE INDEX "sales_product_idx" ON "public"."sales" USING "btree" ("product_id");



CREATE OR REPLACE TRIGGER "trg_enforce_profile_insert_defaults" BEFORE INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_profile_insert_defaults"();



CREATE OR REPLACE TRIGGER "trg_protect_privileged_profile_fields" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."protect_privileged_profile_fields"();



CREATE OR REPLACE TRIGGER "trg_set_initial_seen_patch" BEFORE INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_initial_seen_patch"();



CREATE OR REPLACE TRIGGER "trg_sync_contacts_owner" AFTER UPDATE OF "owner_id" ON "public"."locations" FOR EACH ROW EXECUTE FUNCTION "public"."sync_contacts_owner_on_location_reassign"();



ALTER TABLE ONLY "public"."action_log"
    ADD CONSTRAINT "action_log_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."action_log"
    ADD CONSTRAINT "action_log_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."action_log"
    ADD CONSTRAINT "action_log_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."action_log"
    ADD CONSTRAINT "action_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contact_activities"
    ADD CONSTRAINT "contact_activities_action_log_id_fkey" FOREIGN KEY ("action_log_id") REFERENCES "public"."action_log"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."contact_activities"
    ADD CONSTRAINT "contact_activities_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contact_activities"
    ADD CONSTRAINT "contact_activities_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contact_activities"
    ADD CONSTRAINT "contact_activities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contacts"
    ADD CONSTRAINT "contacts_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."contacts"
    ADD CONSTRAINT "contacts_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contacts"
    ADD CONSTRAINT "contacts_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."error_log"
    ADD CONSTRAINT "error_log_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."error_log"
    ADD CONSTRAINT "error_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_friend_id_fkey" FOREIGN KEY ("friend_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guild_members"
    ADD CONSTRAINT "guild_members_guild_id_fkey" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guild_members"
    ADD CONSTRAINT "guild_members_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guild_members"
    ADD CONSTRAINT "guild_members_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guilds"
    ADD CONSTRAINT "guilds_founder_id_fkey" FOREIGN KEY ("founder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guilds"
    ADD CONSTRAINT "guilds_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_entries"
    ADD CONSTRAINT "journal_entries_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_entries"
    ADD CONSTRAINT "journal_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_entry_mentions"
    ADD CONSTRAINT "journal_entry_mentions_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_entry_mentions"
    ADD CONSTRAINT "journal_entry_mentions_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_entry_mentions"
    ADD CONSTRAINT "journal_entry_mentions_user_id_entry_date_fkey" FOREIGN KEY ("user_id", "entry_date") REFERENCES "public"."journal_entries"("user_id", "entry_date") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_entry_mentions"
    ADD CONSTRAINT "journal_entry_mentions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_photos"
    ADD CONSTRAINT "journal_photos_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."journal_photos"
    ADD CONSTRAINT "journal_photos_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rule_configs"
    ADD CONSTRAINT "rule_configs_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."termin_series"
    ADD CONSTRAINT "termin_series_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."termin_series"
    ADD CONSTRAINT "termin_series_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."termin_series"
    ADD CONSTRAINT "termin_series_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."termin_series"
    ADD CONSTRAINT "termin_series_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."termine"
    ADD CONSTRAINT "termine_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."termine"
    ADD CONSTRAINT "termine_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."termine"
    ADD CONSTRAINT "termine_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."termine"
    ADD CONSTRAINT "termine_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."termine"
    ADD CONSTRAINT "termine_series_id_fkey" FOREIGN KEY ("series_id") REFERENCES "public"."termin_series"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE "public"."action_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."contact_activities" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "contact_activities_delete_own_or_admin" ON "public"."contact_activities" FOR DELETE USING ((("user_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "contact_activities_insert_own" ON "public"."contact_activities" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "contact_activities_select_own_or_admin" ON "public"."contact_activities" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "contact_activities_update_own_or_admin" ON "public"."contact_activities" FOR UPDATE USING ((("user_id" = "auth"."uid"()) OR "public"."is_admin"()));



ALTER TABLE "public"."contacts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "contacts_delete_owner_or_admin" ON "public"."contacts" FOR DELETE USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "contacts_insert_own" ON "public"."contacts" FOR INSERT WITH CHECK ((("owner_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "contacts_select_own_or_shared_or_admin" ON "public"."contacts" FOR SELECT USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"() OR (("org_id" = "public"."current_org_id"()) AND "public"."contacts_shared_for_org"())));



CREATE POLICY "contacts_update_owner_or_admin" ON "public"."contacts" FOR UPDATE USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



ALTER TABLE "public"."error_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "error_log_insert_own_org" ON "public"."error_log" FOR INSERT WITH CHECK (("org_id" = "public"."current_org_id"()));



CREATE POLICY "error_log_select_admin_only" ON "public"."error_log" FOR SELECT USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



ALTER TABLE "public"."friends" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "friends_delete_own" ON "public"."friends" FOR DELETE USING (("owner_id" = "auth"."uid"()));



CREATE POLICY "friends_delete_recipient_declines" ON "public"."friends" FOR DELETE USING (("friend_id" = "auth"."uid"()));



CREATE POLICY "friends_insert_own" ON "public"."friends" FOR INSERT WITH CHECK (("owner_id" = "auth"."uid"()));



CREATE POLICY "friends_select_related" ON "public"."friends" FOR SELECT USING ((("owner_id" = "auth"."uid"()) OR ("friend_id" = "auth"."uid"())));



CREATE POLICY "friends_update_recipient_accepts" ON "public"."friends" FOR UPDATE USING (("friend_id" = "auth"."uid"()));



ALTER TABLE "public"."guild_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guild_members_delete_self_or_founder" ON "public"."guild_members" FOR DELETE USING ((("member_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."guilds" "g"
  WHERE (("g"."id" = "guild_members"."guild_id") AND ("g"."founder_id" = "auth"."uid"()))))));



CREATE POLICY "guild_members_insert_founder_adds" ON "public"."guild_members" FOR INSERT WITH CHECK ((("org_id" = "public"."current_org_id"()) AND (EXISTS ( SELECT 1
   FROM "public"."guilds" "g"
  WHERE (("g"."id" = "guild_members"."guild_id") AND ("g"."founder_id" = "auth"."uid"()))))));



CREATE POLICY "guild_members_insert_self_join" ON "public"."guild_members" FOR INSERT WITH CHECK ((("member_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "guild_members_select_org" ON "public"."guild_members" FOR SELECT USING (("org_id" = "public"."current_org_id"()));



ALTER TABLE "public"."guilds" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guilds_insert_self_founder" ON "public"."guilds" FOR INSERT WITH CHECK ((("org_id" = "public"."current_org_id"()) AND ("founder_id" = "auth"."uid"())));



CREATE POLICY "guilds_select_org" ON "public"."guilds" FOR SELECT USING (("org_id" = "public"."current_org_id"()));



CREATE POLICY "inventory_insert_own" ON "public"."user_inventory" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "inventory_select_own" ON "public"."user_inventory" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "inventory_update_own" ON "public"."user_inventory" FOR UPDATE USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."journal_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."journal_entry_mentions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "journal_insert_own_only" ON "public"."journal_entries" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "journal_mentions_delete_own_only" ON "public"."journal_entry_mentions" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "journal_mentions_insert_own_only" ON "public"."journal_entry_mentions" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "journal_mentions_select_own_only" ON "public"."journal_entry_mentions" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."journal_photos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "journal_photos_insert_own" ON "public"."journal_photos" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "journal_photos_select_own" ON "public"."journal_photos" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "journal_photos_update_own" ON "public"."journal_photos" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "journal_select_own_only" ON "public"."journal_entries" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "journal_update_own_only" ON "public"."journal_entries" FOR UPDATE USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."locations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "locations_delete_admin_only" ON "public"."locations" FOR DELETE USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



CREATE POLICY "locations_insert_org_members" ON "public"."locations" FOR INSERT WITH CHECK (("org_id" = "public"."current_org_id"()));



CREATE POLICY "locations_select_org" ON "public"."locations" FOR SELECT USING (("org_id" = "public"."current_org_id"()));



CREATE POLICY "locations_update_admin_only" ON "public"."locations" FOR UPDATE USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



CREATE POLICY "log_insert_own" ON "public"."action_log" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "log_select_admin_sees_all_in_org" ON "public"."action_log" FOR SELECT USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



CREATE POLICY "log_select_own" ON "public"."action_log" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "log_select_shared_contact_activity" ON "public"."action_log" FOR SELECT USING ((("contact_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."contacts" "c"
  WHERE (("c"."id" = "action_log"."contact_id") AND ("c"."org_id" = "public"."current_org_id"()) AND "public"."contacts_shared_for_org"())))));



CREATE POLICY "org_select_own" ON "public"."organizations" FOR SELECT USING (("id" = "public"."current_org_id"()));



CREATE POLICY "org_update_admin_only" ON "public"."organizations" FOR UPDATE USING ((("id" = "public"."current_org_id"()) AND "public"."is_admin"()));



ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_insert_admin_only" ON "public"."products" FOR INSERT WITH CHECK ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



CREATE POLICY "products_select_same_org" ON "public"."products" FOR SELECT USING (("org_id" = "public"."current_org_id"()));



CREATE POLICY "products_update_admin_only" ON "public"."products" FOR UPDATE USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_insert_self" ON "public"."profiles" FOR INSERT WITH CHECK (("id" = "auth"."uid"()));



CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT USING (("id" = "auth"."uid"()));



CREATE POLICY "profiles_select_same_org" ON "public"."profiles" FOR SELECT USING (("org_id" = "public"."current_org_id"()));



CREATE POLICY "profiles_update_admin" ON "public"."profiles" FOR UPDATE USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."rule_configs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "rules_insert_admin_only" ON "public"."rule_configs" FOR INSERT WITH CHECK ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



CREATE POLICY "rules_select_same_org" ON "public"."rule_configs" FOR SELECT USING (("org_id" = "public"."current_org_id"()));



CREATE POLICY "rules_update_admin_only" ON "public"."rule_configs" FOR UPDATE USING ((("org_id" = "public"."current_org_id"()) AND "public"."is_admin"()));



ALTER TABLE "public"."sales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sales_delete_like_contact" ON "public"."sales" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."contacts" "c"
  WHERE (("c"."id" = "sales"."contact_id") AND (("c"."owner_id" = "auth"."uid"()) OR "public"."is_admin"())))));



CREATE POLICY "sales_insert_like_contact" ON "public"."sales" FOR INSERT WITH CHECK ((("org_id" = "public"."current_org_id"()) AND (EXISTS ( SELECT 1
   FROM "public"."contacts" "c"
  WHERE (("c"."id" = "sales"."contact_id") AND (("c"."owner_id" = "auth"."uid"()) OR "public"."is_admin"()))))));



CREATE POLICY "sales_select_like_contact" ON "public"."sales" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."contacts" "c"
  WHERE (("c"."id" = "sales"."contact_id") AND (("c"."owner_id" = "auth"."uid"()) OR "public"."is_admin"() OR (("c"."org_id" = "public"."current_org_id"()) AND "public"."contacts_shared_for_org"()))))));



CREATE POLICY "sales_update_like_contact" ON "public"."sales" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."contacts" "c"
  WHERE (("c"."id" = "sales"."contact_id") AND (("c"."owner_id" = "auth"."uid"()) OR "public"."is_admin"())))));



ALTER TABLE "public"."schema_patches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "schema_patches_select_all" ON "public"."schema_patches" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."termin_series" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "termin_series_delete_owner_or_admin" ON "public"."termin_series" FOR DELETE USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "termin_series_insert_own" ON "public"."termin_series" FOR INSERT WITH CHECK ((("owner_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "termin_series_select_own_or_admin" ON "public"."termin_series" FOR SELECT USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "termin_series_update_owner_or_admin" ON "public"."termin_series" FOR UPDATE USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



ALTER TABLE "public"."termine" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "termine_delete_owner_or_admin" ON "public"."termine" FOR DELETE USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "termine_insert_own" ON "public"."termine" FOR INSERT WITH CHECK ((("owner_id" = "auth"."uid"()) AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "termine_select_own_or_admin" ON "public"."termine" FOR SELECT USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "termine_update_owner_or_admin" ON "public"."termine" FOR UPDATE USING ((("owner_id" = "auth"."uid"()) OR "public"."is_admin"()));



ALTER TABLE "public"."user_inventory" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."contacts_shared_for_org"() TO "anon";
GRANT ALL ON FUNCTION "public"."contacts_shared_for_org"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."contacts_shared_for_org"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_org_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_org_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_org_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_profile_insert_defaults"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_profile_insert_defaults"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_profile_insert_defaults"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."protect_privileged_profile_fields"() TO "anon";
GRANT ALL ON FUNCTION "public"."protect_privileged_profile_fields"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."protect_privileged_profile_fields"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_initial_seen_patch"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_initial_seen_patch"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_initial_seen_patch"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_contacts_owner_on_location_reassign"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_contacts_owner_on_location_reassign"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_contacts_owner_on_location_reassign"() TO "service_role";


















GRANT ALL ON TABLE "public"."action_log" TO "anon";
GRANT ALL ON TABLE "public"."action_log" TO "authenticated";
GRANT ALL ON TABLE "public"."action_log" TO "service_role";



GRANT ALL ON TABLE "public"."contact_activities" TO "anon";
GRANT ALL ON TABLE "public"."contact_activities" TO "authenticated";
GRANT ALL ON TABLE "public"."contact_activities" TO "service_role";



GRANT ALL ON TABLE "public"."contacts" TO "anon";
GRANT ALL ON TABLE "public"."contacts" TO "authenticated";
GRANT ALL ON TABLE "public"."contacts" TO "service_role";



GRANT ALL ON TABLE "public"."error_log" TO "anon";
GRANT ALL ON TABLE "public"."error_log" TO "authenticated";
GRANT ALL ON TABLE "public"."error_log" TO "service_role";



GRANT ALL ON TABLE "public"."friends" TO "anon";
GRANT ALL ON TABLE "public"."friends" TO "authenticated";
GRANT ALL ON TABLE "public"."friends" TO "service_role";



GRANT ALL ON TABLE "public"."guild_members" TO "anon";
GRANT ALL ON TABLE "public"."guild_members" TO "authenticated";
GRANT ALL ON TABLE "public"."guild_members" TO "service_role";



GRANT ALL ON TABLE "public"."guilds" TO "anon";
GRANT ALL ON TABLE "public"."guilds" TO "authenticated";
GRANT ALL ON TABLE "public"."guilds" TO "service_role";



GRANT ALL ON TABLE "public"."journal_entries" TO "anon";
GRANT ALL ON TABLE "public"."journal_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."journal_entries" TO "service_role";



GRANT ALL ON TABLE "public"."journal_entry_mentions" TO "anon";
GRANT ALL ON TABLE "public"."journal_entry_mentions" TO "authenticated";
GRANT ALL ON TABLE "public"."journal_entry_mentions" TO "service_role";



GRANT ALL ON TABLE "public"."journal_photos" TO "anon";
GRANT ALL ON TABLE "public"."journal_photos" TO "authenticated";
GRANT ALL ON TABLE "public"."journal_photos" TO "service_role";



GRANT ALL ON TABLE "public"."locations" TO "anon";
GRANT ALL ON TABLE "public"."locations" TO "authenticated";
GRANT ALL ON TABLE "public"."locations" TO "service_role";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."rule_configs" TO "anon";
GRANT ALL ON TABLE "public"."rule_configs" TO "authenticated";
GRANT ALL ON TABLE "public"."rule_configs" TO "service_role";



GRANT ALL ON TABLE "public"."sales" TO "anon";
GRANT ALL ON TABLE "public"."sales" TO "authenticated";
GRANT ALL ON TABLE "public"."sales" TO "service_role";



GRANT ALL ON TABLE "public"."schema_patches" TO "anon";
GRANT ALL ON TABLE "public"."schema_patches" TO "authenticated";
GRANT ALL ON TABLE "public"."schema_patches" TO "service_role";



GRANT ALL ON TABLE "public"."termin_series" TO "anon";
GRANT ALL ON TABLE "public"."termin_series" TO "authenticated";
GRANT ALL ON TABLE "public"."termin_series" TO "service_role";



GRANT ALL ON TABLE "public"."termine" TO "anon";
GRANT ALL ON TABLE "public"."termine" TO "authenticated";
GRANT ALL ON TABLE "public"."termine" TO "service_role";



GRANT ALL ON TABLE "public"."user_inventory" TO "anon";
GRANT ALL ON TABLE "public"."user_inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."user_inventory" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";


  create policy "photo_insert_own_folder"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'journal-photos'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "photo_select_own_folder"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'journal-photos'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "photo_update_own_folder"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'journal-photos'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



