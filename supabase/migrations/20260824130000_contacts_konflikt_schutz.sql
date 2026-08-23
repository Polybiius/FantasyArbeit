-- ============================================================
-- Konflikt-Schutz bei gleichzeitiger Kontakt-Bearbeitung
-- (optimistisches Sperren), 2026-08-23.
--
-- Bisher: "wer zuletzt speichert, gewinnt" ohne Warnung -- speichern zwei
-- Kolleg:innen im selben Moment denselben geteilten Kontakt, überschreibt
-- die zweite Person die Änderung der ersten stillschweigend. Bekannte,
-- bewusst in Kauf genommene Lücke, siehe CLAUDE.md ("Bekannte, bewusst in
-- Kauf genommene Lücken").
--
-- Lösung: contacts.updated_at existiert bereits, wurde aber bisher nur an
-- EINER von acht Schreibstellen im Frontend überhaupt gepflegt (dem
-- normalen Bearbeiten-Formular) -- ein Trigger ist zuverlässiger als sich
-- darauf zu verlassen, dass jede künftige Schreibstelle im Code selbst
-- daran denkt (gleiches Prinzip wie bei der bestehenden serverseitigen
-- Schreib-Härtung, siehe CLAUDE.md). Der Trigger ignoriert dabei bewusst
-- jeden vom Client mitgeschickten updated_at-Wert und setzt IMMER now() --
-- sonst könnte ein direkter API-Aufruf (an der App vorbei) einen alten
-- Zeitstempel unterschieben und die Schutzprüfung so aushebeln.
--
-- Das Frontend ergänzt bei jedem Speichern zusätzlich `.eq('updated_at',
-- <beim Laden gesehener Wert>)` in der WHERE-Bedingung -- hat sich die
-- Zeile inzwischen geändert, matcht die Bedingung nicht mehr, das Update
-- betrifft 0 Zeilen statt die Änderung durchzuführen. Bewusst KEINE eigene
-- serverseitige Funktion dafür (anders als beim XP-System) -- hier geht es
-- um Datenqualität zwischen zwei ehrlichen Nutzern, nicht um Vertrauen
-- gegenüber böswilligen Aufrufen; wer schreiben darf, regelt weiterhin
-- unverändert die bestehende RLS-Policy. Kein SECURITY DEFINER nötig, der
-- Trigger braucht keine erhöhten Rechte.
-- ============================================================

create or replace function public.touch_contacts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_contacts_updated_at on public.contacts;
create trigger trg_touch_contacts_updated_at
  before update on public.contacts
  for each row
  execute function public.touch_contacts_updated_at();
