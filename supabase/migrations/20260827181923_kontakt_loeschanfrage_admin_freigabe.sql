-- Nutzerwunsch, direkt im Anschluss an die Rechtemodell-Lücke von heute
-- (siehe CLAUDE.md, "Rechtemodell-Lücke: canEdit berücksichtigt Gilden-
-- Schreibrecht"): "Die Löschanfrage eines Gildenmitglieds soll nicht
-- direkt löschen, sondern erst beim Admin landen. Sonst könnte ein
-- verprellter Mitarbeiter einfach die Datenbank löschen." Betrifft
-- ausschließlich den Fall "Gildenmitglied löscht einen fremden, geteilten
-- Kontakt über Schreibrecht" -- der Eigentümer selbst und Admins löschen
-- weiterhin sofort, unverändert, das ist nicht der beschriebene Risikofall.
--
-- 1) contacts_delete_owner_or_admin verliert den heute erst hinzugefügten
--    guild_contact_permission-Zweig wieder (die org_id-Grenze von heute
--    bleibt bestehen, die war ein eigenständiger, unabhängiger Fix).
-- 2) Neue Tabelle contact_deletion_requests + drei SECURITY-DEFINER-
--    Funktionen (request/approve/reject), gleiches Härtungsmuster wie
--    guild_invitations/termin_invitations: keine direkte Insert/Update/
--    Delete-Policy für Clients, alles läuft über die Funktionen.
-- 3) contact_name_snapshot als Schattenfeld (gleicher Grund wie bei
--    termin_invitations' Titel-/Zeit-Schattenfeldern): contact_id wird
--    bei Löschung des Kontakts auf NULL gesetzt (on delete set null,
--    bewusst kein cascade -- sonst würde die eigene Genehmigung ihre
--    eigene Prüfspur mit wegreißen), der Name muss trotzdem lesbar
--    bleiben.
--
-- Drei Funde einer Zweitmeinungsrunde vor dem Push, alle behoben:
-- a) requested_by/reviewed_by hatten keine ON DELETE-Aktion (Standard
--    NO ACTION) -- hätte ein echtes Mitarbeiter-Offboarding blockiert
--    (handle_member_offboarding() räumt diese Tabelle nicht auf, die
--    auth.users-Löschung wäre an der Fremdschlüssel-Prüfung
--    gescheitert). Jetzt "on delete cascade" wie beim strukturell
--    gleichen access_audit_log (admin_id/target_user_id) --
--    Prüfspur-Zeilen eines später offboardeten Mitarbeiters
--    verschwinden mit, exakt dasselbe bereits akzeptierte Verhalten.
-- b) approve_contact_deletion_request() prüfte status='offen' nur in
--    der vorherigen SELECT, nicht mehr im UPDATE selbst -- zwei
--    gleichzeitige Genehmigungen hätten die Prüfspur (reviewed_by/
--    reviewed_at) verfälschen können. UPDATE hat jetzt dieselbe
--    status='offen'-Bedingung wie reject_contact_deletion_request()
--    plus denselben "not found"-Fehlerfall.
-- c) approve_contact_deletion_request() löschte den Kontakt ohne die
--    offene Wiedervorlage-Aufgabe vorher zu entfernen -- reproduziert
--    exakt den Karteileichen-Bug, der für den manuellen Löschweg schon
--    einmal gefunden und gefixt wurde (index.html,
--    syncWiedervorlageTask() VOR dem Löschen, nicht danach, weil
--    tasks.contact_id sonst schon auf NULL steht). Jetzt räumt die
--    Funktion dieselbe Zeile serverseitig genauso vorher weg.
--
-- Zweite Zweitmeinungsrunde auf den fertigen Diff, ein weiterer echter
-- Fund + eine bewusst NICHT übernommene Anregung:
-- d) War eine Anfrage noch offen, als der Eigentümer/ein Admin den
--    Kontakt direkt löschte (bypassed die Anfrage komplett), blieb die
--    Anfrage-Zeile fälschlich "offen" stehen (contact_id nur auf NULL
--    gesetzt) -- ein späteres "Genehmigen" wäre ein stiller Leerlauf
--    gewesen (beide DELETEs träfen 0 Zeilen wegen "= NULL", die Funktion
--    hätte trotzdem klaglos "Erfolg" gemeldet). Neuer BEFORE-DELETE-
--    Trigger auf contacts (resolve_orphaned_deletion_requests(), bewusst
--    BEFORE statt AFTER: läuft dadurch garantiert, bevor der eigene
--    on-delete-set-null-Fremdschlüssel contact_id schon nullt) markiert
--    jede noch offene Anfrage für den betroffenen Kontakt automatisch als
--    "genehmigt" (reviewed_by bleibt NULL -- unterscheidbar von einer
--    echten Admin-Aktion), sobald der Kontakt auf IRGENDEINEM Weg
--    verschwindet (Direktlöschung, diese Funktion selbst, künftig auch
--    auto_delete_inactive_contacts()). Die Anfrage taucht dadurch gar
--    nicht erst mehr in der offenen Liste auf.
-- e) NICHT übernommen: der Vorschlag, das Wiedervorlage-Aufräumen in
--    Punkt c) wie im Frontend auf owner_id der aufrufenden Person
--    einzuschränken. Bewusst anders: hier wird der KONTAKT vollständig
--    gelöscht (nicht nur eine Person bearbeitet ihn), jede an ihn
--    gebundene Wiedervorlage-Aufgabe wird dadurch für JEDEN Besitzer
--    bedeutungslos (der Kontakt existiert danach für niemanden mehr) --
--    eine Einschränkung auf nur die anfragende/genehmigende Person hätte
--    fremde Wiedervorlage-Aufgaben als Karteileichen zurückgelassen,
--    genau der Bug, den dieser Fix eigentlich vermeiden soll.

begin;

alter policy "contacts_delete_owner_or_admin" on public.contacts
  using (((org_id = current_org_id()) and ((owner_id = (select auth.uid())) or is_admin())));

create table public.contact_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  contact_id uuid references public.contacts(id) on delete set null,
  contact_name_snapshot text not null,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'offen' check (status in ('offen','genehmigt','abgelehnt')),
  created_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete cascade,
  reviewed_at timestamptz
);

-- Verhindert doppelte offene Anfragen für denselben Kontakt (mehrfaches
-- Klicken/mehrere Gildenmitglieder gleichzeitig) -- pro Kontakt maximal
-- eine offene Anfrage, nach Bearbeitung darf eine neue gestellt werden.
create unique index contact_deletion_requests_open_idx
  on public.contact_deletion_requests (contact_id) where (status = 'offen');
create index contact_deletion_requests_org_id_idx on public.contact_deletion_requests(org_id);

alter table public.contact_deletion_requests enable row level security;

-- Sichtbar für den Anfragenden selbst (kann seinen eigenen Status
-- nachsehen) und für Admins der eigenen Organisation -- bewusst mit
-- org_id-Grenze, nicht nur is_admin() (gleiche Lehre wie beim heutigen
-- contacts_delete_owner_or_admin-Fund).
create policy contact_deletion_requests_select on public.contact_deletion_requests
  for select using (
    (org_id = current_org_id())
    and (requested_by = (select auth.uid()) or is_admin())
  );

-- Bewusst keine insert/update/delete-Policies für normale Clients --
-- jeder Schreibvorgang läuft über eine der drei Funktionen unten.

-- Räumt eine noch offene Löschanfrage automatisch ab, sobald der
-- referenzierte Kontakt auf IRGENDEINEM Weg verschwindet -- nicht nur
-- über approve_contact_deletion_request() (siehe Fund d) oben). BEFORE
-- statt AFTER DELETE: muss vor dem eigenen on-delete-set-null-
-- Fremdschlüssel laufen, sonst ist contact_id hier schon NULL.
create or replace function public.resolve_orphaned_deletion_requests()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.contact_deletion_requests
    set status = 'genehmigt', reviewed_at = now()
    where contact_id = old.id and status = 'offen';
  return old;
end;
$$;

create trigger contacts_resolve_deletion_requests
  before delete on public.contacts
  for each row execute function public.resolve_orphaned_deletion_requests();

-- 1) Anfrage stellen: nur wer tatsächlich Gilden-Schreibrecht auf den
-- Kontakt hat, aber NICHT Eigentümer und NICHT Admin ist (die sollen
-- direkt löschen, keine Anfrage nötig -- verhindert auch sinnlose
-- Dubletten). on conflict auf den partiellen Unique-Index: eine zweite
-- Anfrage bei bereits offener Anfrage liefert einfach die bestehende
-- Anfrage-ID zurück statt einen Fehler zu werfen.
create or replace function public.request_contact_deletion(p_contact_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_contact public.contacts;
  v_request_id uuid;
begin
  select * into v_contact from public.contacts
    where id = p_contact_id and org_id = current_org_id();
  if v_contact is null then
    raise exception 'Kontakt nicht gefunden.' using errcode = '42501';
  end if;

  if v_contact.owner_id = (select auth.uid()) or is_admin() then
    raise exception 'Als Eigentümer oder Admin kannst du direkt löschen, keine Anfrage nötig.' using errcode = '42501';
  end if;

  if not guild_contact_permission(v_contact.owner_id, true) then
    raise exception 'Keine Schreibberechtigung für diesen Kontakt.' using errcode = '42501';
  end if;

  insert into public.contact_deletion_requests (org_id, contact_id, contact_name_snapshot, requested_by, status)
  values (v_contact.org_id, p_contact_id, v_contact.name, (select auth.uid()), 'offen')
  on conflict (contact_id) where (status = 'offen')
  do nothing
  returning id into v_request_id;

  if v_request_id is null then
    select id into v_request_id from public.contact_deletion_requests
      where contact_id = p_contact_id and status = 'offen';
  end if;

  return v_request_id;
end;
$$;

-- 2) Genehmigen: nur Admins der eigenen Organisation. Markiert die
-- Anfrage ZUERST als genehmigt (damit die Prüfspur den echten Zustand
-- zum Löschzeitpunkt zeigt), löscht danach den Kontakt wirklich --
-- contact_id auf der bereits aktualisierten Zeile wird durch den
-- on-delete-set-null-Fremdschlüssel automatisch NULL, contact_name_
-- snapshot bleibt als lesbare Spur erhalten.
create or replace function public.approve_contact_deletion_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_req public.contact_deletion_requests;
begin
  if not is_admin() then
    raise exception 'Nur Admins dürfen Löschanfragen genehmigen.' using errcode = '42501';
  end if;

  select * into v_req from public.contact_deletion_requests
    where id = p_request_id and org_id = current_org_id() and status = 'offen';
  if v_req is null then
    raise exception 'Löschanfrage nicht gefunden oder bereits bearbeitet.' using errcode = '42501';
  end if;

  update public.contact_deletion_requests
    set status = 'genehmigt', reviewed_by = (select auth.uid()), reviewed_at = now()
    where id = p_request_id and status = 'offen';
  if not found then
    raise exception 'Löschanfrage wurde inzwischen bereits von jemand anderem bearbeitet.' using errcode = '42501';
  end if;

  -- Gleiche Reihenfolge wie beim manuellen Löschweg (index.html,
  -- syncWiedervorlageTask() vor contacts.delete()): die offene
  -- Wiedervorlage-Aufgabe muss VOR dem Kontakt weg, sonst setzt der
  -- on-delete-set-null-Fremdschlüssel tasks.contact_id schon auf NULL,
  -- bevor sie darüber gefunden werden könnte -- Karteileiche.
  delete from public.tasks where contact_id = v_req.contact_id and source_type = 'wiedervorlage';

  delete from public.contacts where id = v_req.contact_id and org_id = current_org_id();
end;
$$;

-- 3) Ablehnen: nur Admins der eigenen Organisation, Kontakt bleibt
-- unangetastet bestehen.
create or replace function public.reject_contact_deletion_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_admin() then
    raise exception 'Nur Admins dürfen Löschanfragen ablehnen.' using errcode = '42501';
  end if;

  update public.contact_deletion_requests
    set status = 'abgelehnt', reviewed_by = (select auth.uid()), reviewed_at = now()
    where id = p_request_id and org_id = current_org_id() and status = 'offen';

  if not found then
    raise exception 'Löschanfrage nicht gefunden oder bereits bearbeitet.' using errcode = '42501';
  end if;
end;
$$;

grant execute on function public.request_contact_deletion(uuid) to authenticated;
revoke execute on function public.request_contact_deletion(uuid) from public, anon;
grant execute on function public.approve_contact_deletion_request(uuid) to authenticated;
revoke execute on function public.approve_contact_deletion_request(uuid) from public, anon;
grant execute on function public.reject_contact_deletion_request(uuid) to authenticated;
revoke execute on function public.reject_contact_deletion_request(uuid) from public, anon;

commit;
