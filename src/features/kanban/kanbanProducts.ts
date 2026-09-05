import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';

import { sb } from '@/shared/lib/bridge';
import { qk } from '@/shared/lib/queryKeys';

/**
 * Laufzeit-Vertrag für GENAU die Produktkatalog-Felder, die die
 * Verkaufs-Popups „Gewonnen“/„Verloren“ brauchen (docs/adr/0011) — 1:1
 * zu Vanillas `populateCategorySelect()`/`populateProductSelect()`/
 * `computeRecontactDate()` (`index.html`).
 */
const productSchema = z.object({
  id: z.string(),
  name: z.string(),
  category: z.string(),
  subcategory: z.string().nullable(),
  provision_mode: z.string(),
  recontact_amount: z.number().nullable(),
  recontact_unit: z.string().nullable(),
});

export type KanbanProduct = z.infer<typeof productSchema>;

async function fetchActiveProducts(orgId: string): Promise<KanbanProduct[]> {
  const { data, error } = await sb()
    .from('products')
    .select('id,name,category,subcategory,provision_mode,recontact_amount,recontact_unit')
    .eq('org_id', orgId)
    .eq('active', true);
  if (error) throw error;
  return data.map((row) => productSchema.parse(row));
}

/** Aktiver Produktkatalog der eigenen Organisation — ändert sich selten, langes `staleTime` wie bei `fetchOrgActionCosts()`. */
export function useActiveProductsQuery(orgId: string | undefined) {
  return useQuery({
    queryKey: qk.kanban.products(orgId ?? ''),
    queryFn: () => fetchActiveProducts(orgId!),
    enabled: orgId != null,
    staleTime: 5 * 60_000,
  });
}

/** 1:1-Portierung von `productGroupKey()` — "Kategorie" oder "Kategorie — Unterkategorie". */
export function productGroupKey(p: Pick<KanbanProduct, 'category' | 'subcategory'>): string {
  return p.category + (p.subcategory ? ' — ' + p.subcategory : '');
}

export function groupedProductCategories(products: readonly KanbanProduct[]): string[] {
  return [...new Set(products.map(productGroupKey))].sort();
}

export function productsInGroup(products: readonly KanbanProduct[], group: string): KanbanProduct[] {
  return products.filter((p) => productGroupKey(p) === group);
}

export interface ProductCategorySelection {
  categories: string[];
  category: string;
  setCategory: (category: string) => void;
  productsForCategory: KanbanProduct[];
  productId: string;
  setProductId: (id: string) => void;
  selectedProduct: KanbanProduct | undefined;
}

/**
 * Gemeinsame Kategorie/Produkt-Auswahllogik für beide Verkaufs-Popups
 * (`KanbanWonSaleModal`/`KanbanLostSaleModal`) — vorher in beiden
 * Komponenten wortgleich dupliziert (Fund einer unabhängigen
 * Zweitmeinung), hier einmal zentral.
 *
 * Bewusst OHNE `useEffect`+`setState`, um aus dem Katalog abgeleitete
 * Standardauswahlen zu pflegen (React-Lint `react-hooks/set-state-in-effect`
 * rät genau davon ab) — stattdessen hält der State nur eine optionale
 * Nutzer-Auswahl ("Override"), der eigentliche Anzeigewert wird bei
 * jedem Render aus Katalog+Override abgeleitet. Lädt der Katalog nach,
 * wandert der abgeleitete Wert automatisch mit, ohne dass ein Effekt
 * nötig wäre.
 */
export function useProductCategorySelection(products: readonly KanbanProduct[] | undefined): ProductCategorySelection {
  const categories = useMemo(() => groupedProductCategories(products ?? []), [products]);
  const [categoryOverride, setCategoryOverride] = useState<string | null>(null);
  const category = categoryOverride !== null && categories.includes(categoryOverride) ? categoryOverride : (categories[0] ?? '');

  const productsForCategory = useMemo(() => productsInGroup(products ?? [], category), [products, category]);
  const [productIdOverride, setProductIdOverride] = useState<string | null>(null);
  const productId =
    productIdOverride !== null && productsForCategory.some((p) => p.id === productIdOverride)
      ? productIdOverride
      : (productsForCategory[0]?.id ?? '');
  const selectedProduct = productsForCategory.find((p) => p.id === productId);

  return {
    categories,
    category,
    setCategory: setCategoryOverride,
    productsForCategory,
    productId,
    setProductId: setProductIdOverride,
    selectedProduct,
  };
}

function dateKeyLocal(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * 1:1-Portierung von `computeRecontactDate()` — bewusst mit lokalen
 * `Date`-Gettern (CLAUDE.md "Zeitzonen-Inkonsistenz", Fall "Typ B"): `d`
 * entsteht rein aus Kalender-Arithmetik ab einem auf 12 Uhr verankerten
 * Datum, kein echter Zeitstempel, für den `todayKey()`/`localPartsInTZ()`
 * nötig wären.
 */
export function computeRecontactDate(product: KanbanProduct | undefined, vertragsbeginnStr: string): string | null {
  if (!product || !product.recontact_amount || !product.recontact_unit || !vertragsbeginnStr) return null;
  const d = new Date(vertragsbeginnStr + 'T12:00:00');
  const n = product.recontact_amount;
  if (product.recontact_unit === 'tage') d.setDate(d.getDate() + n);
  else if (product.recontact_unit === 'wochen') d.setDate(d.getDate() + n * 7);
  else if (product.recontact_unit === 'monate') d.setMonth(d.getMonth() + n);
  else if (product.recontact_unit === 'jahre') d.setFullYear(d.getFullYear() + n);
  else return null;
  return dateKeyLocal(d);
}
