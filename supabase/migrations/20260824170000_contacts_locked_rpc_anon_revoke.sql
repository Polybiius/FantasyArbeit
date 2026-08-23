-- ============================================================
-- Nachtrag zu 20260824160000: `supabase db advisors` direkt im Anschluss
-- ausgeführt (gehört seit dem 24.08. zur Routine bei jeder Schema-
-- Änderung, siehe CLAUDE.md/touch_trigger_search_path_fix) -- zwei echte,
-- durch die neue Migration verursachte Funde.
--
-- Beide neuen Funktionen bekamen automatisch EXECUTE für anon/authenticated
-- (Standard-Rechtevergabe für neue public-Schema-Funktionen, siehe CLAUDE.md
-- Abschnitt "Sicherheitswarnungen"). Praktisch ungefährlich (anon hat kein
-- gültiges auth.uid(), contacts_writable() würde für anon immer false
-- liefern, update_contact_locked() immer mit "keine Berechtigung"
-- abbrechen) -- trotzdem unnötige Angriffsfläche, die dasselbe Härtungs-
-- Prinzip verletzt wie beim Rest des Projekts: Funktionen, die niemand
-- anonym aufrufen soll, bekommen explizit KEIN EXECUTE.
--
-- contacts_writable() braucht darüber hinaus auch für eingeloggte Nutzer
-- kein direktes EXECUTE -- sie wird ausschließlich intern von
-- update_contact_locked() aufgerufen (als dessen Eigentümer-Rolle, davon
-- unberührt vom Entzug hier), kein Frontend-Code ruft sie direkt auf.
-- ============================================================

revoke execute on function public.contacts_writable(public.contacts) from public, anon, authenticated;
revoke execute on function public.update_contact_locked(uuid, jsonb, timestamptz) from public, anon;
