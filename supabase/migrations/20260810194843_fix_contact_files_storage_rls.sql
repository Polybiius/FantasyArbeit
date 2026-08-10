-- Bugfix: Datei-Upload bei Kontakten schlug für JEDE Datei mit "new row
-- violates row-level security policy" fehl (Bugreport 2026-08-10, direkt
-- nach Live-Test entdeckt).
--
-- Ursache: Namenskollision in den drei Storage-Policies aus Patch 42.
-- storage.objects hat eine Spalte "name" (der Objekt-/Dateipfad), aber
-- die dort korrelierte Tabelle public.contacts hat EBENFALLS eine Spalte
-- "name" (die generierte Spalte aus Vor-/Nachname). Der unqualifizierte
-- Ausdruck "storage.foldername(name)" innerhalb der EXISTS-Subquery
-- wurde von Postgres auf das näherliegende contacts.name aufgelöst, NICHT
-- auf storage.objects.name -- die Prüfung verglich also faktisch den
-- Kundennamen (z.B. "Jrui Laev", enthält kein "/") statt des Pfads gegen
-- die Kontakt-ID, was für jede noch so berechtigte Datei false ergab.
-- Fix: "objects.name" statt "name" -- der bloße Tabellenname dient als
-- implizite Korrelationsvariable der eigenen Zeile innerhalb einer
-- RLS-Policy und ist dadurch eindeutig, unabhängig davon, was die
-- Subquery sonst noch im FROM stehen hat.
--
-- Per direkter SQL-Diagnose bestätigt: mit einem Literal-String statt der
-- echten Spalte lieferte dieselbe Logik korrekt "true" -- der Fehler lag
-- eindeutig an der Spaltenauflösung, nicht an der eigentlichen
-- Berechtigungslogik (guild_contact_permission() etc. war nie das
-- Problem).

ALTER POLICY "contact_files_storage_select" ON "storage"."objects"
  USING (
    bucket_id = 'contact-files'
    AND EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.id::text = (storage.foldername(objects.name))[1]
        AND (c.owner_id = auth.uid() OR public.is_admin() OR public.guild_contact_permission(c.owner_id, false))
    )
  );

ALTER POLICY "contact_files_storage_insert" ON "storage"."objects"
  WITH CHECK (
    bucket_id = 'contact-files'
    AND EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.id::text = (storage.foldername(objects.name))[1]
        AND (c.owner_id = auth.uid() OR public.is_admin() OR public.guild_contact_permission(c.owner_id, true))
    )
  );

ALTER POLICY "contact_files_storage_delete" ON "storage"."objects"
  USING (
    bucket_id = 'contact-files'
    AND EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.id::text = (storage.foldername(objects.name))[1]
        AND (c.owner_id = auth.uid() OR public.is_admin() OR public.guild_contact_permission(c.owner_id, true))
    )
  );
