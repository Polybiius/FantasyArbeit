-- PATCH: enforce_profile_insert_defaults() für das Pool-Feature nachgezogen
--
-- Beim Dry-Run der Fundament-Migrationen entdeckt (kein Teil der 4
-- ursprünglich geplanten Bauaufgaben, aber ein echter, seit dem
-- Pool-Feature-Launch (2026-08-29, Commit b4e6011) aktiv laufender
-- Bug): dieser BEFORE-INSERT-Trigger stammt aus Patch 39, lange vor
-- dem Pool-Feature, und überschreibt bei JEDER neuen Profil-Anlage
-- unbedingt org_id auf die alte Standard-Organisation
-- (00000000-0000-0000-0000-000000000001) + role auf 'member' --
-- unabhängig davon, was eingefügt wird. Ursprünglich korrekt (jede
-- Registrierung sollte damals in die einzige existierende
-- Organisation), aber nie an das Pool-Feature angepasst.
--
-- Folge: JEDE neue Registrierung landet seit dem 2026-08-29 tatsächlich
-- weiterhin in der alten Standard-Org statt im Pool (org_id NULL),
-- obwohl der Frontend-Code (index.html, appearanceDoneBtn-Insert-
-- Handler) explizit davon ausgeht, dass org_id unausgefüllt bleibt und
-- NULL wird -- das Pool-Feature war für neue Registrierungen seit
-- Launch faktisch wirkungslos. Nutzer bestätigt (2026-08-30): keine
-- echten Registrierungen betroffen, nur Testprofile -- keine
-- Datenkorrektur nötig.
--
-- Fix: org_id wird jetzt auf NULL erzwungen (Pool-Startzustand) statt
-- auf die alte Standard-Org. role bleibt unverändert unbedingt
-- 'member' erzwungen (Härtung gegen Selbst-Admin-Anlage bleibt
-- bestehen, kein Sicherheits-Rückschritt). Kein Trusted-Flag-
-- Mechanismus nötig: eine echte Organisationszugehörigkeit entsteht
-- laut Architektur ausschließlich über spätere, bereits gehärtete
-- UPDATEs (found_own_org()/respond_to_org_pool_invitation()/
-- respond_to_guild_invitation()), niemals beim initialen INSERT selbst
-- -- der Trigger darf org_id also bedenkenlos immer auf NULL zwingen,
-- ohne einen legitimen Fall zu blockieren.
--
-- Rückbau: org_id-Zeile zurück auf
-- '00000000-0000-0000-0000-000000000001'::uuid.

begin;

create or replace function public.enforce_profile_insert_defaults()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  new.role := 'member';
  new.org_id := null;
  return new;
end;
$$;

commit;
