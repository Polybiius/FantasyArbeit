-- PATCH: Org-Soft-Delete-Fundament (nur Sicherheitsgurt, kein Feature)
--
-- Phase-1-Bauaufgabe (project_naechster_struktureller_schritt,
-- Abschnitt 8/9). Bewusst NUR die dokumentierte Stolperfalle
-- entschärfen -- kein Auflösungs-Feature, keine UI, keine neue RPC in
-- diesem Schritt (das echte Szenario ist Insolvenz/Pleite einer
-- Kundenfirma, kein Alltagsfall, verdient ein eigenes, späteres
-- Gespräch inkl. "Mitglieder erst in den Pool zurückführen"-Logik).
--
-- organizations.dissolved_at: neue, aktuell wirkungslose Spalte -- reiner
-- Platzhalter für das künftige Auflösungs-Feature, damit dessen spätere
-- Migration keine neue Spalte mehr braucht.
--
-- profiles_org_id_fkey: ON DELETE CASCADE -> ON DELETE RESTRICT. Vorher
-- hätte ein rohes "DELETE FROM organizations" JEDEN Mitglieder-Account
-- dieser Org hart mitgelöscht (nicht nur in den Pool zurückgeschickt).
-- Geprüft (Plan-Agent-Review vor dieser Migration): aktuell löscht KEIN
-- Code-Pfad im Projekt (weder index.html noch eine bestehende Migration)
-- je eine organizations-Zeile -- diese Änderung ist folgenlos für
-- bestehende Abläufe (Account-Löschung läuft über eine komplett andere
-- FK, profiles_id_fkey -> auth.users, unberührt von dieser Migration),
-- schließt nur die Stolperfalle für die Zukunft.
--
-- Rückbau: dissolved_at-Spalte droppen, FK zurück auf ON DELETE CASCADE.

begin;

alter table public.organizations add column if not exists dissolved_at timestamptz;

alter table public.profiles drop constraint profiles_org_id_fkey;
alter table public.profiles add constraint profiles_org_id_fkey
  foreign key (org_id) references public.organizations(id) on delete restrict;

commit;
