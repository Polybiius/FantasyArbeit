-- Supabase-Advisor-Triage, Schritt 2: anonymen Zugriff auf 15 echte
-- Schreib-RPC-Funktionen sperren (Kategorie "Public Can Execute
-- SECURITY DEFINER Function", `anon_security_definer_function_executable`).
--
-- Jede der 15 Funktionen wurde einzeln gegen `auth.uid() IS NULL`
-- geprueft: alle scheitern bereits heute sauber mit einer Exception
-- oder betreffen 0 Zeilen (kein Datenrisiko). Dieser Revoke ist reine
-- Verteidigung in der Tiefe (gleiches Muster wie log_security_alert()),
-- keine Verhaltensaenderung fuer eingeloggte Nutzer -- die Funktionen
-- bleiben fuer `authenticated` unveraendert ausfuehrbar, die App ruft
-- sie ausschliesslich eingeloggt auf.
--
-- Bewusst NICHT angefasst: admin_emergency_access ist bereits admin-only
-- durch is_admin()-Pruefung intern geschuetzt, wird aber trotzdem mit
-- revoked, da auch hier "gar nicht erst anrufbar" staerker ist als
-- "ruft an, scheitert dann".
--
-- Diese Migration schliesst bewusst nur 15 der 33 Advisor-Funde dieser
-- Kategorie (`anon_security_definer_function_executable`) -- die
-- restlichen 18 bleiben ABSICHTLICH anon-ausfuehrbar, sind KEINE
-- Regression bei einem spaeteren Advisor-Nachlauf:
--   * 8 sind tatsaechlich `returns trigger`-Funktionen (Postgres kann
--     sie strukturell nicht per RPC aufrufen, unabhaengig von Rechten;
--     handle_member_offboarding, cleanup_termin_invitee_copies,
--     enforce_guild_selfjoin_limits, enforce_profile_insert_defaults,
--     prevent_duplicate_sale_submission, protect_location_owner_field,
--     protect_privileged_profile_fields,
--     sync_contacts_owner_on_location_reassign) -- bestaetigte
--     Fehlalarme.
--   * 10 sind reine Lese-/Berechtigungs-Hilfsfunktionen
--     (current_org_id, is_admin, socially_visible,
--     contacts_shared_for_org, guild_contact_permission,
--     guild_dungeon_permission, guild_founder_of_member,
--     guild_leadership_permission, friend_skill_totals,
--     guild_sales_metric_total) -- werden aus RLS-Policies heraus als
--     aufrufende Rolle ausgewertet, ein Revoke wuerde dort aus "liefert
--     0 Zeilen" ein hartes Rechte-Error bei jedem anonymen
--     Tabellenzugriff machen. Einzeln gegengeprueft: geben bei
--     `auth.uid() IS NULL` durchgehend false/0 Zeilen zurueck oder
--     (guild_sales_metric_total) eine generische Zugriffs-Exception --
--     kein Daten-/Informationsleck.
--
-- Wichtiger Fund aus dem Dry-Run: jede Funktion hat ZWEI unabhaengige
-- ACL-Eintraege, die anon Ausfuehrung erlauben -- einen expliziten
-- `anon=X` (aus den bestehenden ALTER DEFAULT PRIVILEGES-Regeln) UND
-- einen `=X` fuer PUBLIC (Postgres-Standard: neue Funktionen bekommen
-- automatisch EXECUTE fuer PUBLIC, unabhaengig von den DEFAULT-
-- PRIVILEGES-Regeln fuer einzelne Rollen). `revoke ... from anon`
-- allein reicht deshalb NICHT -- anon haette ueber den PUBLIC-Eintrag
-- weiterhin Zugriff. Beide Eintraege muessen einzeln entfernt werden;
-- `authenticated` hat einen eigenen dritten Eintrag und bleibt davon
-- unberuehrt.
--
-- Rueckbau: `grant execute on function <sig> to anon;` je Funktion --
-- stellt den anon-spezifischen Eintrag wieder her (siehe Dry-Run unten).
-- Der PUBLIC-Eintrag kaeme damit nicht zurueck, ist aber ohnehin nie
-- Teil der beabsichtigten Berechtigung gewesen (reiner Postgres-Default,
-- keine bewusste Konfiguration dieses Projekts).

revoke execute on function public.admin_emergency_access(uuid, text) from public, anon;
revoke execute on function public.attach_kanal_to_own_action(uuid, text) from public, anon;
revoke execute on function public.cancel_guild_invitation(uuid) from public, anon;
revoke execute on function public.consume_item_from_self(text) from public, anon;
revoke execute on function public.grant_guild_quest_completion(uuid, text, text, text) from public, anon;
revoke execute on function public.grant_item_to_self(text) from public, anon;
revoke execute on function public.grant_quest_bonus_to_self(text, text, text, text) from public, anon;
revoke execute on function public.invite_to_guild(uuid, uuid) from public, anon;
revoke execute on function public.invite_to_termin(uuid, uuid) from public, anon;
revoke execute on function public.log_action_for_self(text, text, uuid, uuid, jsonb, timestamptz) from public, anon;
revoke execute on function public.log_item_energy_refill_for_self(text) from public, anon;
revoke execute on function public.notify_termin_update(uuid) from public, anon;
revoke execute on function public.respond_to_guild_invitation(uuid, boolean) from public, anon;
revoke execute on function public.respond_to_termin_invitation(uuid, boolean) from public, anon;
revoke execute on function public.sync_own_level_cache() from public, anon;
