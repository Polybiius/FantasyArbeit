-- PATCH: Freunde-Feature app-weit statt org-gebunden
--
-- Phase-1-Bauaufgabe aus dem CLAUDE.md-Fahrplan (siehe Erinnerung
-- project_naechster_struktureller_schritt, Abschnitt 8/9). Nutzer-
-- Entscheidung, wörtlich: "freunde sind appweit gedacht. kann ja sein,
-- dass ich in einem anderen unternehmen einen freund habe. dann guck
-- ich mir seinen fortschritt und seine items an." Freundschaften sollen
-- außerdem jeden Org-Wechsel überstehen (bereits strukturell gegeben,
-- da friends nie durch Org-/Gilden-Wechsel automatisch angetastet
-- wird -- diese Migration entfernt nur die BEITRITTS-Schranke).
--
-- Geprüft vor dem Schreiben (nicht nur vermutet): weder die SELECT-
-- Policy (friends_select_related) noch die DELETE-Policy
-- (friends_delete_visible) noch socially_visible() nutzen friends.org_id
-- irgendwo -- nur die beiden WITH-CHECK-Klauseln auf INSERT/UPDATE tun
-- es. Deshalb genügt: Spalte (samt FK) entfernen, die beiden
-- betroffenen WITH-CHECK-Klauseln entschärfen. Der zugehörige Index
-- (friends_org_id_idx) fällt beim Spalten-Drop automatisch mit weg.
--
-- Rückbau: Spalte wieder anlegen (nullable, kein Backfill möglich --
-- historische Zuordnung ist weg), beide ALTER POLICY unten auf die
-- alte Fassung zurücksetzen (siehe git-Historie
-- 20260817210000_rls_performance_haertung.sql:163-171), zusätzlich
-- search_profile_for_friend() droppen (siehe unten).
--
-- Nachgeschärft nach unabhängiger Zweitmeinung (/code-review high) --
-- echter Fund: die Freundschafts-TABELLE ist jetzt org-unabhängig, aber
-- die SUCHE (index.html searchFriendByName()) lief weiterhin über ein
-- direktes `sb.from('profiles').select(...)`, das der bestehenden
-- profiles_select_visible-Policy unterliegt (`id=self OR
-- org_id=current_org_id()`) -- unverändert org-gebunden. Ohne Fix hätte
-- die Suche nach einer Person einer FREMDEN Org einfach "kein Treffer"
-- geliefert, obwohl die Freundschaft technisch längst möglich wäre.
-- Fix: gleiches Muster wie search_org_pool_candidates() -- eine schmale
-- SECURITY-DEFINER-Funktion statt die org-gebundene profiles-RLS-Policy
-- selbst aufzuweiten (würde sonst z.B. auch real_name/company/
-- Provisionssätze fremder Personen über einen rohen REST-Aufruf
-- offenlegen, weit über das für die Suche Nötige hinaus).

begin;

-- Reihenfolge wichtig: erst die beiden Policies umschreiben (sie
-- referenzieren org_id direkt), erst danach die Spalte droppen -- sonst
-- verweigert Postgres den Drop wegen bestehender Abhängigkeiten.
alter policy "friends_insert_own" on public.friends
  with check (owner_id = (select auth.uid()));

alter policy "friends_update_recipient_accepts" on public.friends
  using (friend_id = (select auth.uid()))
  with check (friend_id = (select auth.uid()));

alter table public.friends drop column org_id;

-- App-weite Freundes-Suche -- exact-match (ilike ohne Wildcards, gleiche
-- Konvention wie die bisherige Frontend-Suche), nur die drei für die
-- Anzeige nötigen Spalten, keine Org-Grenze mehr.
create or replace function public.search_profile_for_friend(p_name text)
returns table(id uuid, display_name text, character_class text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.display_name, p.character_class
  from public.profiles p
  where p.display_name ilike p_name;
$$;

grant execute on function public.search_profile_for_friend(text) to authenticated;
revoke execute on function public.search_profile_for_friend(text) from public, anon;

insert into public.schema_patches (patch_number, title) values
  (58, 'Freunde ohne Firmengrenze')
on conflict (patch_number) do nothing;

commit;
