-- PATCH: Einwilligungs-Häkchen an Kontakten + automatische Löschung
-- inaktiver Kontakte ohne je gewonnenen Vertrag (DSGVO-Vorbereitung,
-- siehe businessvorbereitung/ im Repo).
--
-- Teil 1: contacts.consent_obtained -- einfaches Ja/Nein-Häkchen, kein
-- Datum, keine Zweckangabe (Nutzerentscheidung, gleiche Praxis wie beim
-- AXA-Vertrieb: "wird abgehakt und gut ist").
--
-- Teil 2: automatische Löschung. Fassung nach unabhängiger Zweitmeinung
-- korrigiert (zwei echte Logikfehler der ersten Fassung behoben, siehe
-- HISTORY.md/CLAUDE.md für den vollen Verlauf):
--
--   Fund 1 (behoben): der "Inaktivitäts"-Anker war zuvor nur
--   Anlagedatum/Vertragsende -- ignorierte echte Vertriebsaktivität.
--   Jetzt: der Anker ist das Späteste aus Anlagedatum, letzter
--   Bearbeitung (updated_at), Wiedervorlage-Datum, letztem Anruf/E-Mail
--   (contact_activities), letztem Termin (termine) und letzter
--   geloggter Aktion am Kontakt (action_log). Ein aktiv bearbeiteter
--   Lead wird dadurch nie versehentlich gelöscht, egal wie alt er ist.
--
--   Fund 2 (behoben): Standard ist jetzt enabled=false -- die
--   Organisation muss das bewusst scharf schalten, kein
--   automatischer Erstlauf ohne Not-Aus.
--
--   Fund 3 (behoben): Kontakte mit IRGENDEINEM jemals gewonnenen
--   Vertrag (auch längst gekündigt) sind von der Auto-Löschung
--   komplett ausgenommen -- Kaskade auf sales würde sonst rückwirkend
--   Kompendium-/Schatzraum-Zahlen vergangener Jahre verändern. Echte
--   Ex-Kunden brauchen einen eigenen, noch zu bauenden Mechanismus
--   (Art. 18 DSGVO "Einschränkung der Verarbeitung"/Sperrvermerk statt
--   Löschung, wegen §257 HGB-Aufbewahrungspflicht bei echten
--   Vertragsabschlüssen) -- bewusst nicht Teil dieses Patches.
--
--   Fund 4 (behoben): contact_auto_delete_log protokolliert jeden Lauf
--   (nur Anzahl, keine personenbezogenen Daten), admin-lesbar.
--
-- Zweite Zweitmeinungs-Runde (nach den obigen Korrekturen) fand drei
-- weitere Funde: Aktivitäts-Anker fehlte contact_files.created_at
-- (behoben, ein kürzlicher Datei-Upload zählt jetzt auch als
-- Aktivität), monthsInactive hatte keine Untergrenze gegen einen
-- Konfigurations-Tippfehler wie 0 (behoben, greatest(...,1)), sowie
-- ein bewusst NICHT behobener Fund: die Datei selbst im
-- Storage-Bucket `contact-files` überlebt die Löschung der
-- `contact_files`-Zeile (nur die DB-Zeile kaskadiert, nicht das
-- Objekt im Speicher -- live bestätigt: Supabase blockiert eine
-- direkte SQL-Löschung von storage.objects ausdrücklich per
-- storage.protect_delete()-Trigger, nur die Storage-API kann das
-- wirklich löschen, die von reinem SQL/pg_cron aus nicht ohne
-- zusätzliches Geheimnis in der Datenbank erreichbar ist). Nutzer-
-- Entscheidung 2026-08-25: heute ohne Datei-Aufräumung live gehen,
-- betrifft nur Kontakte, die nie Kunde wurden (Ex-Kunden sind ja
-- bereits komplett ausgenommen) -- siehe CLAUDE.md, "Bekannte,
-- bewusst in Kauf genommene Lücken" für die dauerhafte Dokumentation
-- und einen möglichen Nachfolge-Mechanismus (Warteschlange +
-- Admin-Login-Aufräumung, gleiches Muster wie Geburtstags-/
-- Manatrank-Nachtrag -- kein neues Geheimnis in der Datenbank nötig).
--
-- Ausgelöst über pg_cron (täglicher Lauf), nicht über einen
-- Login-getriebenen Nachtrag wie bei Manatrank/Geburtstagen --
-- bewusste Nutzerentscheidung, da die Löschung auch dann zuverlässig
-- passieren soll, wenn niemand aus der Organisation gerade eingeloggt
-- ist.
--
-- Fremdschlüssel-Verhalten beim Löschen (per Schema-Check bestätigt):
-- sales/contact_activities/contact_files/journal_entry_mentions
-- kaskadieren mit (gehören zum Kontakt, sollen mit verschwinden --
-- betrifft wegen Fund 3 jetzt nur noch Kontakte ohne jemals gewonnenen
-- Vertrag, ihre sales-Zeilen sind dann höchstens 'verloren'),
-- action_log/tasks/termine/termin_series/termin_invitations setzen den
-- Kontaktbezug nur auf NULL (bleiben als eigene Datensätze der/des
-- Mitarbeiter:in bestehen).

begin;

-- Teil 1: Einwilligungs-Feld ------------------------------------------------

alter table public.contacts
  add column if not exists consent_obtained boolean not null default false;

-- update_contact_locked() erlaubt bisher nur eine feste Feld-Allowlist
-- (siehe CLAUDE.md, "Serverseitige Schreib-Härtung" / "contacts:
-- strukturell gehärtet") -- consent_obtained muss dort ergänzt werden,
-- sonst schlägt ein Bearbeiten-Speichern mit gesetztem Häkchen fehl.
create or replace function public.update_contact_locked(
  p_id uuid,
  p_patch jsonb,
  p_expected_updated_at timestamptz
)
returns contacts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_row public.contacts;
  updated_row public.contacts;
  allowed_keys text[] := array[
    'vorname','nachname','role','location_id','status','kanban_stage',
    'geburtsdatum','telefon','email','wohnort_strasse','wohnort_ort',
    'bedarf_ist','bedarf_wunsch','naechster_kontakt','notes',
    'consent_obtained'
  ];
  k text;
begin
  select * into current_row from public.contacts where id = p_id for update;
  if not found then
    raise exception 'Kontakt nicht gefunden oder keine Berechtigung' using errcode = '42501';
  end if;

  if not contacts_writable(current_row) then
    raise exception 'Keine Schreibberechtigung für diesen Kontakt' using errcode = '42501';
  end if;

  for k in select jsonb_object_keys(coalesce(p_patch, '{}'::jsonb)) loop
    if not (k = any(allowed_keys)) then
      raise exception 'Feld % darf über update_contact_locked() nicht geändert werden', k using errcode = '42501';
    end if;
  end loop;

  update public.contacts set
    vorname           = case when p_patch ? 'vorname'           then p_patch->>'vorname'           else vorname end,
    nachname          = case when p_patch ? 'nachname'          then p_patch->>'nachname'          else nachname end,
    role              = case when p_patch ? 'role'              then p_patch->>'role'              else role end,
    location_id       = case when p_patch ? 'location_id'       then (p_patch->>'location_id')::uuid else location_id end,
    status            = case when p_patch ? 'status'            then p_patch->>'status'            else status end,
    kanban_stage      = case when p_patch ? 'kanban_stage'      then p_patch->>'kanban_stage'      else kanban_stage end,
    geburtsdatum      = case when p_patch ? 'geburtsdatum'      then (p_patch->>'geburtsdatum')::date else geburtsdatum end,
    telefon           = case when p_patch ? 'telefon'           then p_patch->>'telefon'           else telefon end,
    email             = case when p_patch ? 'email'             then p_patch->>'email'             else email end,
    wohnort_strasse   = case when p_patch ? 'wohnort_strasse'   then p_patch->>'wohnort_strasse'   else wohnort_strasse end,
    wohnort_ort       = case when p_patch ? 'wohnort_ort'       then p_patch->>'wohnort_ort'       else wohnort_ort end,
    bedarf_ist        = case when p_patch ? 'bedarf_ist'        then p_patch->>'bedarf_ist'        else bedarf_ist end,
    bedarf_wunsch     = case when p_patch ? 'bedarf_wunsch'     then p_patch->>'bedarf_wunsch'     else bedarf_wunsch end,
    naechster_kontakt = case when p_patch ? 'naechster_kontakt' then (p_patch->>'naechster_kontakt')::date else naechster_kontakt end,
    notes             = case when p_patch ? 'notes'             then p_patch->>'notes'             else notes end,
    consent_obtained  = case when p_patch ? 'consent_obtained'  then (p_patch->>'consent_obtained')::boolean else consent_obtained end
  where id = p_id and updated_at = p_expected_updated_at
  returning * into updated_row;

  if not found then
    return null; -- Konflikt: Zeile hat sich seit dem Laden geändert
  end if;

  return updated_row;
end;
$$;

-- Teil 2: automatische Löschung ----------------------------------------

-- Konfiguration pro Organisation (Templating-Prinzip). Bewusst
-- enabled=false als Standard (Fund 2) -- muss aktiv scharf geschaltet
-- werden, kein automatischer Erstlauf ohne Not-Aus.
update public.rule_configs
set config = config || jsonb_build_object(
  'contactAutoDelete', jsonb_build_object('enabled', false, 'monthsInactive', 6)
)
where not (config ? 'contactAutoDelete');

create table if not exists public.contact_auto_delete_log (
  id bigint generated always as identity primary key,
  org_id uuid not null,
  deleted_count int not null,
  run_at timestamptz not null default now()
);

alter table public.contact_auto_delete_log enable row level security;

drop policy if exists contact_auto_delete_log_select_admin on public.contact_auto_delete_log;
create policy contact_auto_delete_log_select_admin on public.contact_auto_delete_log
  for select using (org_id = current_org_id() and is_admin());

create or replace function public.auto_delete_inactive_contacts()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  org record;
  months int;
  n_deleted int;
begin
  for org in
    select rc.org_id,
           (rc.config->'contactAutoDelete'->>'monthsInactive')::int as months_inactive
    from public.rule_configs rc
    where coalesce((rc.config->'contactAutoDelete'->>'enabled')::boolean, false) = true
  loop
    -- Fund C (zweite Zweitmeinung): Untergrenze gegen einen
    -- Tippfehler/0 in der Konfiguration, der sonst sofort den
    -- kompletten Nicht-Kunden-Bestand löschen würde.
    months := greatest(coalesce(org.months_inactive, 6), 1);

    with deleted as (
      delete from public.contacts c
      where c.org_id = org.org_id
        -- Fund 3: jemals gewonnener Vertrag (auch gekündigt) schließt
        -- die Auto-Löschung komplett aus -- eigener Mechanismus nötig
        -- (Sperrvermerk statt Löschung, HGB-Aufbewahrungspflicht).
        and not exists (
          select 1 from public.sales s
          where s.contact_id = c.id and s.status = 'gewonnen'
        )
        -- Fund 1: Anker ist das Späteste aus Anlage, letzter
        -- Bearbeitung, Wiedervorlage und echter Vertriebsaktivität --
        -- nicht nur das Anlagedatum. Fund B (zweite Zweitmeinung):
        -- ein kürzlich hochgeladenes Dokument zählt ebenfalls als
        -- Aktivität (contact_files.created_at, Upload rührt
        -- contacts.updated_at selbst nicht an).
        and greatest(
              c.created_at,
              c.updated_at,
              coalesce(c.naechster_kontakt::timestamptz, c.created_at),
              coalesce(
                (select max(ca.occurred_at) from public.contact_activities ca where ca.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(t.start_at) from public.termine t where t.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(al.created_at) from public.action_log al where al.contact_id = c.id),
                c.created_at
              ),
              coalesce(
                (select max(cf.created_at) from public.contact_files cf where cf.contact_id = c.id),
                c.created_at
              )
            ) < now() - (months || ' months')::interval
      returning 1
    )
    select count(*) into n_deleted from deleted;

    insert into public.contact_auto_delete_log(org_id, deleted_count)
    values (org.org_id, n_deleted);
  end loop;
end;
$$;

-- Nur für den pg_cron-Job gedacht, kein Weg über die normale API --
-- gleiches Härtungsmuster wie log_security_alert() (CLAUDE.md,
-- "Sicherheitswarnungen"): neue Funktionen im Schema public bekommen
-- über ALTER DEFAULT PRIVILEGES automatisch EXECUTE für anon/
-- authenticated, das hier explizit zurücknehmen.
revoke execute on function public.auto_delete_inactive_contacts() from public, anon, authenticated;

create extension if not exists pg_cron;

select cron.schedule(
  'auto-delete-inactive-contacts-daily',
  '17 3 * * *', -- täglich um 03:17 UTC, bewusst kein glatter Stundenwert
  $$select public.auto_delete_inactive_contacts();$$
);

insert into public.schema_patches (patch_number, title) values
  (53, 'Einwilligungs-Haekchen + automatische Loeschung inaktiver Kontakte (DSGVO)')
on conflict (patch_number) do nothing;

commit;
