-- PATCH: Termin-Einladungen -- zwei kleine Robustheits-Unschärfen behoben
--
-- Beide am 2026-08-18 beim Sicherheits-Check des Tages dokumentiert (siehe
-- CLAUDE.md, "Bekannte, bewusst in Kauf genommene Lücken") -- kein
-- Datenleck, reine Konsistenz-/Sichtbarkeits-Härtung, jetzt abgearbeitet:
--
-- 1) termin_invitations_select prüfte die Organisator-Sicht bisher nur über
-- den Join termin_id -> termine.owner_id. Löscht der Organisator den
-- Original-Termin (termin_id wird dabei NULL, siehe Absage-Migration vom
-- 2026-08-18), verlor er technisch die Sicht auf seine eigene, jetzt
-- stornierte Einladungszeile. organizer_id (seit derselben Migration ein
-- festes Schattenfeld, bei jeder invite_to_termin()-Ausführung gesetzt)
-- schließt das strukturell -- unabhängig vom Zustand von termin_id.
--
-- 2) Ein Eingeladener konnte seine angenommene Kopie in termine bisher per
-- normalem Löschrecht (termine_delete_owner_or_admin) direkt entfernen,
-- statt über "Aus meinem Kalender entfernen" (= respond_to_termin_invitation)
-- zu gehen -- termin_invitations blieb dabei mit einem toten
-- invitee_termin_id und Status 'angenommen' zurück (reine
-- Dateninkonsistenz, keine Rechteausweitung). Gleiches Härtungsmuster wie
-- die Schreib-Härtung vom 2026-08-15: der direkte Weg wird für genau diese
-- Zeilen (organizer_id gesetzt = eine Einladungs-Kopie, kein eigener
-- Termin) gesperrt, respond_to_termin_invitation() bleibt als SECURITY
-- DEFINER-Funktion unverändert nutzbar (bypasst RLS ohnehin) -- keine
-- Verhaltensänderung für den bestehenden "Aus meinem Kalender
-- entfernen"-Button.

drop policy termin_invitations_select on public.termin_invitations;
create policy termin_invitations_select on public.termin_invitations
  for select using (
    invited_user_id = (select auth.uid())
    or organizer_id = (select auth.uid())
    or exists (select 1 from public.termine t where t.id = termin_id and t.owner_id = (select auth.uid()))
    or public.is_admin()
  );

drop policy termine_delete_owner_or_admin on public.termine;
create policy termine_delete_owner_or_admin on public.termine
  for delete using (
    (owner_id = (select auth.uid()) and organizer_id is null) or public.is_admin()
  );
