-- ============================================================
-- Nachtrag zum Konflikt-Schutz (2026-08-24): beide heute neu angelegten
-- Trigger-Funktionen (touch_contacts_updated_at, touch_updated_at) hatten
-- keinen fest verankerten search_path -- vom Supabase-Linter
-- (`supabase db advisors`, Kategorie SECURITY) als "Function Search Path
-- Mutable" gemeldet, beim Advisor-Nachlauf nach den beiden heutigen
-- Migrationen gefunden (der sonst übliche Advisor-Check nach Schema-
-- Änderungen war beim Bauen selbst übersprungen worden).
--
-- Ohne festen search_path könnte jemand mit CREATE-Recht in einem frühen
-- Schema der Suchreihenfolge ein gleichnamiges Objekt (z.B. eine eigene
-- now()-Funktion) unterschieben, das die Funktion dann ungewollt
-- verwenden würde ("search_path hijacking") -- bei diesen beiden trivialen
-- Funktionen (nur new.updated_at:=now()) ein theoretisches, kein akut
-- ausnutzbares Risiko, aber ein Standard-Postgres-Härtungsschritt, den
-- jede neue Funktion von Anfang an bekommen sollte.
-- ============================================================

alter function public.touch_contacts_updated_at() set search_path = public, pg_temp;
alter function public.touch_updated_at() set search_path = public, pg_temp;
