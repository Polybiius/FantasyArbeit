-- ============================================================
-- Titel-/Recognition-System, Teil 2+3: einen freigeschalteten Titel aktiv
-- "tragen" + sichtbar machen. Teil 1 (Feier-Toast beim Erfüllen) ist
-- bereits live, siehe CLAUDE.md/questbaum-Erinnerung.
--
-- Rein kosmetisch, bewusst OHNE serverseitige Prüfung "wurde die Epic
-- wirklich erfüllt" (anders als bei XP/Item-Mengen letzte Woche) --
-- gleiches Vertrauensniveau wie bei anderen freien Textfeldern
-- (display_name, real_name): kein Spielvorteil, keine Datenoffenlegung,
-- nur eine angezeigte Zeichenkette. Der Wert ist eine Epic-`id` aus
-- `rule_configs.config.questTree`, kein Freitext -- das Frontend bietet
-- nur tatsächlich erfüllte Epics zur Auswahl an.
-- ============================================================

alter table public.profiles
  add column active_title text;

insert into public.schema_patches (patch_number, title) values
  (48, 'Titel-/Recognition-System: freigeschaltete Titel lassen sich jetzt aktiv tragen und werden im Header sowie auf Gilden-/Freundes-Kacheln angezeigt')
on conflict (patch_number) do nothing;
