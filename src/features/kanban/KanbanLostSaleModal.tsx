import { useState } from 'react';

import { getBridge } from '@/shared/lib/bridge';
import { logSilentError } from '@/shared/lib/errorLog';
import { toError } from '@/shared/lib/toError';
import { useBusyGuard } from '@/shared/hooks/useBusyGuard';
import { formSelectClass as selectClass } from '@/shared/ui/formStyles';
import { Modal } from '@/shared/ui/Modal';

import { contactDisplayName } from '@/shared/domain/contactCard/contactDisplay';
import type { KanbanContact } from './kanbanApi';
import { useActiveProductsQuery, useProductCategorySelection } from './kanbanProducts';
import { insertLostSale } from './kanbanSaleWrite';

export interface KanbanLostSaleModalProps {
  contact: KanbanContact;
  /** `true` = ein Produkt wurde eingetragen (analog zum Rückgabewert von `recordLostSale()`). */
  onResolve: (saleRecorded: boolean) => void;
}

/**
 * 1:1-Portierung von `recordLostSale()` (`index.html`) — bewusst
 * schlanker als das Gewonnen-Popup: nur Kategorie+Produkt, kein
 * Mengenfeld, keine Mehrfach-Schleife ("wie viel verkauft" ergibt bei
 * einem verlorenen Deal keinen Sinn, siehe CLAUDE.md "Produktkatalog &
 * Verkaufshistorie"). "✕" bricht direkt ab (kein Auto-Übernehmen wie
 * beim Gewonnen-Popup — hier gibt es kein "angefangenes" Feld, das
 * verloren gehen könnte).
 */
export function KanbanLostSaleModal({ contact, onResolve }: KanbanLostSaleModalProps) {
  const profile = getBridge().getProfile();
  const orgId = profile?.org_id ?? undefined;
  const { data: products } = useActiveProductsQuery(orgId);
  const { categories, category, setCategory, productsForCategory, productId, setProductId } =
    useProductCategorySelection(products);

  const [status, setStatus] = useState('');
  const { busy, run } = useBusyGuard();

  // Guard gegen einen Klick auf "✕"/Hintergrund WÄHREND `confirm()` noch
  // läuft (Fund einer unabhängigen Zweitmeinung): ohne diesen Schutz
  // würde das Schließen die wartende Promise sofort mit `false` auflösen
  // (Kartenspalte bleibt "verloren", `contacts.status` wird NICHT
  // nachgezogen), während die noch laufende Einfügung den `sales`-Eintrag
  // trotzdem anlegt -- ein echter, durch einen ungeduldigen Klick
  // erreichbarer Dateninkonsistenz-Fall.
  function close() {
    if (busy) return;
    onResolve(false);
  }

  async function confirm() {
    if (!productId) {
      setStatus('Bitte Produkt auswählen.');
      return;
    }
    if (!profile?.org_id) {
      setStatus('Keine Organisation.');
      return;
    }
    await run(async () => {
      try {
        await insertLostSale(contact.id, profile.org_id!, profile.id, productId);
        onResolve(true);
      } catch (err) {
        logSilentError('Verkauf eintragen', err);
        setStatus(toError(err).message);
      }
    });
  }

  return (
    <Modal
      title={<>Welches Produkt war im Gespräch für {contactDisplayName(contact)}?</>}
      onClose={close}
      testId="sale-lost-modal"
    >
      <div className="tw:flex tw:flex-col tw:gap-2">
        <select
          data-testid="sale-lost-category"
          className={selectClass}
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        >
          {categories.length === 0 && <option value="">Keine Produkte im Katalog</option>}
          {categories.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
        <select
          data-testid="sale-lost-product"
          className={selectClass}
          value={productId}
          onChange={(e) => setProductId(e.target.value)}
        >
          {productsForCategory.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
        {status && <div className="tw:text-xs tw:text-danger">{status}</div>}
      </div>
      <button
        type="button"
        data-testid="sale-lost-confirm"
        className="tw:mt-3 tw:w-full tw:rounded-sm tw:border tw:border-arcane tw:bg-arcane/10 tw:px-2 tw:py-1.5 tw:text-sm tw:font-semibold tw:text-text"
        disabled={busy}
        onClick={() => void confirm()}
      >
        Als verloren eintragen
      </button>
    </Modal>
  );
}
