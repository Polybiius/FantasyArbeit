-- Leben-Satz von ‰ auf % umgestellt (2026-08-14, Nutzerwunsch: Komma-Eingabe
-- wie "2,5" statt "25" in Promille). Spalte war bei allen Profilen noch
-- leer (NULL), reine Umbenennung ohne Datenmigration nötig.
alter table public.profiles
  rename column lv_promille_satz to lv_prozent_satz;
