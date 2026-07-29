-- ============================================================
-- PATCH 8 — Freundschaftsanfragen (Annehmen/Ablehnen statt Sofort-Add)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
-- ============================================================

alter table public.friends add column if not exists status text not null default 'pending' check (status in ('pending','accepted'));

-- Bisherige Auswahl-Regel ersetzen: man muss jetzt auch Anfragen sehen
-- können, die an einen selbst gerichtet sind (nicht nur die eigenen).
drop policy if exists "friends_select_own" on public.friends;

create policy "friends_select_related" on public.friends
  for select using (owner_id = auth.uid() or friend_id = auth.uid());

-- Der Empfänger einer Anfrage darf sie annehmen (status ändern)...
create policy "friends_update_recipient_accepts" on public.friends
  for update using (friend_id = auth.uid());

-- ...oder ablehnen (Zeile löschen).
create policy "friends_delete_recipient_declines" on public.friends
  for delete using (friend_id = auth.uid());
