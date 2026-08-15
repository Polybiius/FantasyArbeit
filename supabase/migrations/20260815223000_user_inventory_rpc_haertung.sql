-- ============================================================
-- user_inventory-RLS-Lücke schließen (im Sicherheits-Durchgang
-- 2026-08-07 gefunden, seitdem als "niedrige Priorität" offen
-- gelassen -- Nutzerwunsch 2026-08-15: jetzt wirklich schließen).
--
-- Bisheriges Problem: inventory_insert_own/inventory_update_own
-- prüften nur user_id = auth.uid(), nicht WAS geschrieben wird. Jeder
-- Nutzer konnte per direktem REST-Aufruf (eigener Zugang, kein
-- Datenleck) einen erfundenen item_key eintragen oder quantity auf
-- einen beliebigen Wert setzen (live getestet: quantity:9999 landete
-- echt in der DB).
--
-- Nutzerentscheidung (2026-08-15, ausführlich besprochen): kein
-- Kompromiss mit einer Mengen-Obergrenze pro Schreibvorgang (das würde
-- wiederholte kleine Aufrufe nicht verhindern), aber auch NICHT das
-- große Projekt (komplette Quest-Auswertung zusätzlich serverseitig
-- nachbauen, damit die Funktion selbst weiß, ob eine Belohnung wirklich
-- verdient ist) -- das ist bewusst zurückgestellt, siehe
-- project_business_fahrplan (Erinnerung, außerhalb des Repos) und
-- CLAUDE.md-Nachtrag unten. Stattdessen: direktes Schreiben auf die
-- Tabelle komplett sperren, nur noch zwei eng gefasste Funktionen
-- dürfen die Menge anfassen -- jede einzelne davon bewegt die Menge
-- IMMER um exakt 1 (nie mehr, nie weniger), genau wie es die App heute
-- auch schon tut (grantItem()-Aufrufe sind aktuell ausnahmslos qty:1,
-- useItem() zieht immer exakt 1 ab). Erfundene item_key sind zusätzlich
-- unmöglich, weil beide Funktionen gegen den echten Katalog
-- (rule_configs.config.items) prüfen.
--
-- Restrisiko, bewusst in Kauf genommen (siehe Absprache): dieselbe
-- kleine Funktion sehr oft hintereinander aufzurufen bliebe technisch
-- möglich -- das würde aber viele einzelne, im Verlauf sichtbare
-- Aufrufe brauchen, kein einmaliger Klick. Vollständig ausschließen
-- ginge nur mit einer serverseitigen Nachprüfung "wurde die Quest
-- wirklich erfüllt", das ist das oben genannte, zurückgestellte
-- Projekt.
-- ============================================================

create or replace function public.grant_item_to_self(p_item_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_catalog jsonb;
begin
  select org_id into v_org_id from public.profiles where id = auth.uid();
  if v_org_id is null then
    raise exception 'Kein gültiges Profil für diesen Aufruf.';
  end if;

  select config->'items' into v_catalog from public.rule_configs where org_id = v_org_id;
  if v_catalog is null or not (v_catalog ? p_item_key) then
    raise exception 'Unbekannter Item-Schlüssel: %', p_item_key;
  end if;

  insert into public.user_inventory (user_id, org_id, item_key, quantity, updated_at)
  values (auth.uid(), v_org_id, p_item_key, 1, now())
  on conflict (user_id, item_key)
  do update set quantity = user_inventory.quantity + 1, updated_at = now();
end;
$$;

create or replace function public.consume_item_from_self(p_item_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows integer;
begin
  update public.user_inventory
  set quantity = quantity - 1, updated_at = now()
  where user_id = auth.uid() and item_key = p_item_key and quantity > 0;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'Kein Bestand von % vorhanden.', p_item_key;
  end if;
end;
$$;

grant execute on function public.grant_item_to_self(text) to authenticated;
grant execute on function public.consume_item_from_self(text) to authenticated;

-- Direktes Schreiben auf die Tabelle ist ab jetzt nicht mehr möglich --
-- nur noch die beiden Funktionen oben (SECURITY DEFINER, laufen mit
-- höheren Rechten und umgehen RLS gezielt für genau diesen einen
-- kontrollierten Zweck). Lesen (inventory_select_own) bleibt unverändert.
drop policy if exists "inventory_insert_own" on public.user_inventory;
drop policy if exists "inventory_update_own" on public.user_inventory;
