-- Produktanlage-Vereinfachung (2026-08-14): "Art" (LV/KV/SH/KFZ/RS/
-- pmaSUH/pmaKV, die anderen Excel-Arten D/DP/KAP/KontoAPO/KontoStud
-- bewusst noch weggelassen) wird ein festes Feld am Produkt -- Kategorie,
-- Provisions-Modus und beide Faktoren leiten sich beim Anlegen automatisch
-- daraus ab (siehe PRODUCT_ART_CONFIG in index.html), kein manuelles
-- Einstellen mehr nötig. Kein DB-Constraint auf die erlaubten Werte,
-- gleiches Muster wie contacts.status/termine.kanal -- Prüfung im Frontend.
alter table public.products
  add column art text;
