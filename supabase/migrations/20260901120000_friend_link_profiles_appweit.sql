-- PATCH: Freundes-Anzeige über Firmengrenzen hinweg
--
-- Folgefehler zu 20260830090000_friends_org_unabhaengig.sql: dort wurde
-- die Freundschafts-TABELLE und die SUCHE (search_profile_for_friend())
-- org-unabhängig gemacht, aber die ANZEIGE der bestehenden Freunde nicht.
--
-- index.html renderFriendGrid() und renderFriendRequests() holen die
-- Profildaten der Gegenseite weiterhin per direktem
--   sb.from('profiles').select(...).in('id', ids)
-- -- das unterliegt profiles_select_visible ('id = self OR
-- org_id = current_org_id()'). Folge: ein Freund aus einer anderen
-- Organisation ODER aus dem Pool (org_id NULL) erzeugt zwar eine echte
-- friends-Zeile, taucht aber in der Freundesliste / bei den offenen
-- Anfragen NICHT auf ("bist angeblich mein Freund, aber sehe dich
-- nirgends aufgelistet" -- echter Nutzer-Bugreport, Kollege hatte sich
-- gerade erst registriert und war noch im Pool).
--
-- Fix: gleiches Muster wie search_profile_for_friend() /
-- friend_skill_totals() -- eine schmale SECURITY-DEFINER-Lesefunktion
-- statt profiles_select_visible selbst aufzuweiten (würde sonst auch
-- real_name / company / Provisionssätze fremder Personen über einen
-- rohen REST-Aufruf offenlegen).
--
-- Gibt NUR die für die beiden Anzeige-Stellen nötigen Spalten zurück
-- (Anzeigename, Klasse, Level + die reinen Avatar-/Sigil-Felder) und
-- eng gefasst NUR für:
--   * bestätigte Freunde (accepted, beide Richtungen)  -> Freundesliste
--   * eingehende offene Anfragen (die Person hat MICH angefragt) -> die
--     Anfragen-Karte
-- Nicht enthalten: Personen, denen der Aufrufer selbst nur eine noch
-- offene Anfrage geschickt hat (Anzeigename/Klasse kennt er davon
-- ohnehin schon aus der Suche, Avatar/Level braucht die UI dort nicht).
-- Kein Pool-Browsing, kein Fremd-Profil ohne bestehende Verbindung.
--
-- Rückbau: Funktion droppen, Frontend auf den alten profiles-Select
-- zurücksetzen, friends_insert_own auf die alte WITH-CHECK-Fassung
-- (nur `owner_id = auth.uid()`) zurücksetzen.
--
-- ---------------------------------------------------------------------
-- ZUSATZ aus der unabhängigen Zweitmeinung (Pflichtregel, da diese
-- Migration jetzt doch Berechtigungslogik anfasst):
--
-- friends_insert_own hatte bisher NUR `with check (owner_id = auth.uid())`
-- -- der `status` war beim INSERT ungeprüft. Ein Nutzer konnte also per
-- rohem REST-Aufruf `insert friends {owner_id: ich, friend_id: <opfer>,
-- status: 'accepted'}` eine einseitig "bestätigte" Freundschaft erzeugen
-- (Opfer-UUID app-weit über search_profile_for_friend() per Anzeigename
-- beschaffbar) und darüber sowohl diese neue Funktion als auch das
-- bereits bestehende, WEITREICHENDERE friend_skill_totals() /
-- socially_visible() auslösen. Vorbestehende Lücke, von dieser Migration
-- nicht verursacht -- aber da wir hier ohnehin an der Freundes-Anzeige
-- bauen, direkt mitgeschlossen (Grundsatz "keine verwässerten
-- Kompromisse").
--
-- Fix: INSERT darf nur noch `status = 'pending'` anlegen. Das Annehmen
-- läuft ausschließlich über friends_update_recipient_accepts (UPDATE
-- durch den EMPFÄNGER, `friend_id = auth.uid()`), nie über den INSERT
-- des Absenders -- der legitime Ablauf ist unberührt (index.html fügt
-- ausnahmslos `status:'pending'` ein, Zeile ~5350).
-- ---------------------------------------------------------------------

begin;

alter policy "friends_insert_own" on public.friends
  with check (
    owner_id = (select auth.uid())
    and status = 'pending'
  );

create or replace function public.friend_link_profiles()
returns table(
  id uuid,
  display_name text,
  character_class text,
  level int,
  gender text,
  skin_tone text,
  hair_style text,
  equipped_weapon text,
  equipped_armor text,
  equipped_accessory text,
  active_title text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.display_name, p.character_class, p.level, p.gender,
         p.skin_tone, p.hair_style, p.equipped_weapon, p.equipped_armor,
         p.equipped_accessory, p.active_title
  from public.profiles p
  where exists (
    select 1 from public.friends f
    where (
      f.status = 'accepted'
      and (
        (f.owner_id = (select auth.uid()) and f.friend_id = p.id)
        or (f.friend_id = (select auth.uid()) and f.owner_id = p.id)
      )
    ) or (
      f.status = 'pending'
      and f.owner_id = p.id
      and f.friend_id = (select auth.uid())
    )
  );
$$;

grant execute on function public.friend_link_profiles() to authenticated;
revoke execute on function public.friend_link_profiles() from public, anon;

insert into public.schema_patches (patch_number, title) values
  (60, 'Freundesliste über Firmengrenzen sichtbar')
on conflict (patch_number) do nothing;

commit;
