-- Provisions-Rework, erster Schritt (2026-08-14): drei neue persönliche
-- Felder an profiles, Teil der "Rechnungsgrundlage"-Gruppe in den
-- Einstellungen.
--
-- pma_suh_satz/pma_kv_satz: die Excel (Datenblatt!B14/B15, "Prov pma SUH"/
-- "Prov pma KV") führt diese als persönliche Eingabefelder, exakt im
-- selben Eingabefelder-Block wie Leben-‰/Kranken-MB -- im Programm
-- steckten sie bisher fest verbacken im Produkt-Faktor (0,23×0,05 bzw.
-- 0,75×0,282). Ab jetzt trägt das Produkt nur noch den festen Teilfaktor
-- (0,23/0,75, weiterhin in products.provision_faktor bei den neuen Modi
-- 'individuell_pma_suh'/'individuell_pma_kv'), multipliziert mit dem
-- persönlichen Satz aus diesen beiden neuen Feldern -- gleiches Muster wie
-- individuell_lv/individuell_kv, nur mit zusätzlichem Produkt-Faktor.
--
-- taetig_seit_jahr: in der Excel (Datenblatt!A3 "Tätig seit Jahr:") rein
-- informativ, fließt in keine einzige Formel ein -- bewusst genauso hier:
-- reines Speicherfeld ohne Auswirkung auf die Berechnung.
--
-- Keine Migration bestehender Zeilen nötig, alle drei Felder bleiben NULL,
-- bis jemand sie in den Einstellungen ausfüllt.

alter table public.profiles
  add column pma_suh_satz numeric,
  add column pma_kv_satz numeric,
  add column taetig_seit_jahr integer;
