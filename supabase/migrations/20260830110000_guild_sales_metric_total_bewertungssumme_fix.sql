-- PATCH: guild_sales_metric_total() summierte eine seit der BWS-
-- Verrechnung-Umstellung (2026-08-14) tote Spalte
--
-- Fund: Verkauf/Statistik-Korrektheits-Review (Phase 2, 2026-08-30).
-- Seit der Umstellung schreibt das Frontend für neue Verkäufe nur noch
-- `sales.laufender_beitrag` -- `sales.bewertungssumme` bleibt für Leben
-- (provision_mode='individuell_lv') seitdem strukturell NULL, die
-- Bewertungssumme wird stattdessen clientseitig aus dem Beitrag
-- abgeleitet (saleBasisValue() in index.html: Beitrag x 360 für Leben,
-- sonst der Beitrag selbst). guild_sales_metric_total() (Gildenleben-
-- Team-Ziele, siehe CLAUDE.md) summierte bei p_field='bewertungssumme'
-- aber weiterhin diese tote Spalte -- das Beispiel-Team-Ziel
-- "team_leben_bws_2026" (Schwelle 500.000, Kategorie Lebensversicherung)
-- blieb dadurch für JEDEN seit 2026-08-14 eingetragenen Lebens-
-- Abschluss bei 0 stehen, unabhängig vom tatsächlichen Verkaufsvolumen
-- der Gilde -- ein stiller Widerspruch zur persönlichen Kompendium-
-- Kachel "Bewertungssumme Leben", die denselben Verkauf korrekt zeigt.
--
-- Fix: bei p_field='bewertungssumme' wird jetzt dieselbe Ableitung wie
-- saleBasisValue() im Frontend nachgebildet (Beitrag x 360 nur für
-- provision_mode='individuell_lv', sonst der Beitrag unverändert) statt
-- die nie beschriebene Spalte zu summieren. Die frühere dynamische SQL
-- (format() mit %I auf den Spaltennamen) wird dafür nicht mehr
-- gebraucht -- es gibt exakt zwei erlaubte p_field-Werte, beide laufen
-- jetzt über denselben Basiswert (`laufender_beitrag`), nur mit
-- unterschiedlicher Ableitung. Rechte-/Sichtbarkeitsprüfung (Gilden-
-- Mitgliedschaft ODER is_admin_of() derselben Org) bleibt unverändert
-- aus der vorherigen Fassung (20260828140000).
--
-- Rückbau: die vorherige Fassung (dynamische SQL über format(), reines
-- sum(s.bewertungssumme) bzw. sum(s.laufender_beitrag)) steht in
-- 20260828140000_org_grenze_fuer_bare_is_admin_policies.sql, Zeilen
-- 417-449, sowie in der git-Historie dieser Datei.

begin;

create or replace function public.guild_sales_metric_total(
  p_guild_id uuid, p_field text, p_category text, p_year int
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric;
begin
  if not exists(select 1 from public.guild_members gm where gm.guild_id = p_guild_id and gm.member_id = auth.uid())
     and not coalesce(is_admin_of((select g.org_id from public.guilds g where g.id = p_guild_id)), false) then
    raise exception 'Kein Zugriff auf diese Gilde.';
  end if;
  if p_field not in ('bewertungssumme','laufender_beitrag') then
    raise exception 'Ungültiges Feld: %', p_field;
  end if;

  -- 'bewertungssumme' ist konzeptionell dieselbe Ableitung wie
  -- saleBasisValue() im Frontend (Beitrag x 360 für Leben, sonst
  -- unverändert) -- sales.bewertungssumme selbst wird seit 2026-08-14
  -- nicht mehr beschrieben, siehe Migrationskopf oben.
  -- 'laufender_beitrag' bleibt bewusst der rohe Beitrag ohne
  -- Leben-Hochrechnung (Team-Ziel "alle Sparten zusammen").
  select coalesce(sum(
    case
      when p_field = 'bewertungssumme' and pr.provision_mode = 'individuell_lv'
        then coalesce(s.laufender_beitrag,0) * 360
      else coalesce(s.laufender_beitrag,0)
    end
  ),0)
  into v_total
  from public.sales s
  join public.products pr on pr.id = s.product_id
  join public.guild_members gm on gm.member_id = s.created_by
  where gm.guild_id = p_guild_id
    and s.status = 'gewonnen'
    and extract(year from coalesce(s.vertragsbeginn, s.datum)) = p_year
    and (p_category is null or pr.category = p_category);

  return v_total;
end;
$$;

-- Kein neues revoke hier -- CREATE OR REPLACE FUNCTION ändert bestehende
-- Berechtigungen nicht, die Rechte-Lage dieser Funktion ist unverändert
-- gegenüber der vorherigen Fassung (20260828140000) und war nicht Teil
-- dieses Funds.

commit;
