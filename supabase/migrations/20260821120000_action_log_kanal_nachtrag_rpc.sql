-- ============================================================
-- Bugfix, gefunden beim Häppchen-2-Bugfix-Durchgang (2026-08-21,
-- Cross-File-Konsistenz-Agent): attachKanalToLoggedAction() in
-- index.html versucht seit Patch 40 den Kanal (online/buero/betrieb)
-- nachträglich in eine bereits geloggte termin_vereinbart-Aktion
-- einzutragen -- für den Fall, dass der Kanal erst NACH dem
-- ursprünglichen Log-Aufruf bekannt wird (Ziehen einer BESTEHENDEN
-- Kanban-Karte auf "Ersttermin vereinbart"; beim Dungeon-Button/neuen
-- Lead ist der Kanal dagegen schon beim ursprünglichen Aufruf bekannt
-- und wird korrekt sofort mitgeschrieben).
--
-- Für dieses nachträgliche Schreiben gab es aber NIE eine UPDATE-Policy
-- auf action_log (nur log_insert_own bis zur RLS-Härtung am
-- 2026-08-15, seitdem gar keine Schreib-Policy mehr) -- der
-- .update()-Aufruf ist seit jeher lautlos an RLS gescheitert
-- (abgefangen von logSilentError, "kein Abbruch nötig" laut Kommentar
-- an der Stelle). Auswirkung: ein per Drag&Drop auf eine bestehende
-- Karte gebuchter Termin behält meta.kanal für immer leer und zählt
-- deshalb nie zu den Kanal-Questbaum-Ketten (z.B. "termine_online"),
-- obwohl der Nutzer den Kanal im Popup tatsächlich ausgewählt hat --
-- eine stille Untererfassung, rein abhängig vom benutzten UI-Pfad.
--
-- Fix nach demselben Härtungsmuster wie log_action_for_self() &
-- grant_quest_bonus_to_self() (siehe
-- 20260815230000_action_log_sales_locations_haertung.sql): keine
-- direkte UPDATE-Policy (die würde xp/energy/skill wieder
-- Client-seitig manipulierbar machen), sondern eine schmale
-- SECURITY-DEFINER-Funktion, die AUSSCHLIESSLICH meta.kanal auf eine
-- eigene Zeile mergt (bestehende meta-Felder bleiben per jsonb-Merge
-- erhalten statt überschrieben zu werden) und den Kanal-Wert gegen
-- eine feste Erlaubnisliste prüft.
-- ============================================================

create or replace function public.attach_kanal_to_own_action(p_log_id uuid, p_kanal text)
returns public.action_log
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.action_log;
begin
  if p_kanal not in ('online', 'buero', 'betrieb') then
    raise exception 'Unbekannter Kanal: %', p_kanal;
  end if;

  update public.action_log
    set meta = coalesce(meta, '{}'::jsonb) || jsonb_build_object('kanal', p_kanal)
    where id = p_log_id and user_id = auth.uid()
    returning * into v_row;

  if v_row is null then
    raise exception 'Aktion nicht gefunden oder gehört nicht dir.';
  end if;

  return v_row;
end;
$$;

grant execute on function public.attach_kanal_to_own_action(uuid, text) to authenticated;
