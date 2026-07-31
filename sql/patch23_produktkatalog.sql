-- ============================================================
-- PATCH 23 — Produktkatalog + Verkaufshistorie (Phase 1)
-- Einmal ausführen: SQL Editor -> New query -> einfügen -> Run
--
-- Ersetzt den bisherigen Freitext in sales.produkt (der laut Nutzer nur
-- ein Dummy/Platzhalter war) durch einen echten, admin-gepflegten
-- Produktkatalog. Phase 1 (dieser Patch): nur die Struktur — Kategorien,
-- Produkte, Vertragsdaten, laufender Beitrag. Die Bewertungssumme wird
-- ab jetzt erfasst, aber noch NICHT zu Provision/Bewertungspunkten
-- verrechnet (kommt als eigener, späterer Patch — Phase 2).
--
-- ACHTUNG, ENTHÄLT EINE DESTRUKTIVE OPERATION:
-- Schritt 2 löscht ALLE bisherigen Zeilen aus `sales`. Das war laut
-- Nutzer bewusst gewünscht ("nur Testverkäufe, mehr oder weniger
-- Dummy") und explizit abgesegnet — trotzdem hier klar markiert, wie
-- bei destruktiven Operationen in diesem Projekt üblich. Falls das
-- doch nicht mehr gewünscht ist: Schritt 2 einfach nicht ausführen,
-- dann bricht Schritt 3 (produkt_id not null) an bestehenden Zeilen ab.
-- ============================================================

-- ---------------------------------------------------------------
-- Schritt 1: Produktkatalog-Tabelle
-- ---------------------------------------------------------------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  key text not null,
  name text not null,
  category text not null,
  subcategory text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(org_id, key)
);

create index products_org_idx on public.products(org_id);

alter table public.products enable row level security;

-- Sichtbarkeit wie rule_configs: jeder in der Organisation darf lesen.
create policy "products_select_same_org" on public.products
  for select using (org_id = public.current_org_id());

-- Pflege nur Admins (laut Nutzer: später ggf. je Organisation, aber
-- weiterhin admin-exklusiv, nie alle Mitarbeitenden).
create policy "products_insert_admin_only" on public.products
  for insert with check (org_id = public.current_org_id() and public.is_admin());

create policy "products_update_admin_only" on public.products
  for update using (org_id = public.current_org_id() and public.is_admin());

-- Bewusst KEINE delete-Policy: Produkte werden über "active" deaktiviert,
-- nie gelöscht (gleiches Prinzip wie sonst im Projekt: Historisches bleibt
-- stehen, siehe error_log, journal_entry_mentions).

-- ---------------------------------------------------------------
-- Schritt 2: Bestehende Test-Verkäufe zurücksetzen (siehe Warnung oben)
-- ---------------------------------------------------------------
delete from public.sales;

-- ---------------------------------------------------------------
-- Schritt 3: sales umbauen — Freitext raus, Katalog + Vertragsdaten rein
-- ---------------------------------------------------------------
alter table public.sales drop column produkt;

alter table public.sales add column product_id uuid not null references public.products(id);
alter table public.sales add column bewertungssumme numeric;
alter table public.sales add column laufender_beitrag numeric;
alter table public.sales add column vertragsbeginn date;
alter table public.sales add column vertragsende date;

create index sales_product_idx on public.sales(product_id);

-- vertragsbeginn/bewertungssumme/laufender_beitrag bewusst NICHT not null:
-- bei "verloren" gibt es keinen echten Vertrag, das Formular fragt sie
-- dort gar nicht erst ab. Die Pflicht dafür ("beim Verkaufen bekannt und
-- muss eingetragen werden") wird im Frontend beim Gewinnen-Formular
-- durchgesetzt, nicht als harte DB-Regel.
