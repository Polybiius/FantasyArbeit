-- Vertragsnummer-Feld an sales, angekündigt am 2026-07-31 fürs
-- zukünftige B2B-CRM-Geschäft (andere Vertriebsorganisationen brauchen
-- das vermutlich), jetzt am 2026-08-10 umgesetzt. Nullable Freitextspalte
-- pro Verkaufszeile (nicht pro Abschluss) -- ein Abschluss kann mehrere
-- Produkte/Zeilen erzeugen (siehe recordWonSalesLoop() in index.html),
-- jede Police hat üblicherweise ihre eigene Vertragsnummer.
-- Keine Migration bestehender Zeilen nötig, bleibt einfach NULL.

alter table public.sales
  add column vertragsnummer text;
