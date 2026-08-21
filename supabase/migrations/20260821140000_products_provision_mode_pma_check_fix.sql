-- Häppchen-6a-Review (2026-08-21): products_provision_mode_check erlaubte nur
-- 'fest'/'individuell_lv'/'individuell_kv', obwohl PRODUCT_ART_CONFIG im
-- Frontend (index.html) seit dem BWS-Verrechnungs-Rework vom 2026-08-14 für
-- die Arten pmaSUH/pmaKV bereits 'individuell_pma_suh'/'individuell_pma_kv'
-- setzt. Ein Admin, der ein Produkt dieser beiden Arten anlegt, bekam dadurch
-- strukturell immer eine CHECK-Constraint-Verletzung -- diese zwei Produktarten
-- waren nie tatsächlich anlegbar, obwohl die restliche Verrechnungslogik
-- (saleProvision() in index.html) bereits vollständig darauf vorbereitet ist.

alter table public.products
  drop constraint products_provision_mode_check;

alter table public.products
  add constraint products_provision_mode_check
  check (provision_mode = any (array[
    'fest', 'individuell_lv', 'individuell_kv',
    'individuell_pma_suh', 'individuell_pma_kv'
  ]));
