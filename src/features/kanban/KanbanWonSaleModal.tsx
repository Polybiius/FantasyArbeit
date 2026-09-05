import { useState } from 'react';

import { getBridge } from '@/shared/lib/bridge';
import { logSilentError } from '@/shared/lib/errorLog';
import { toError } from '@/shared/lib/toError';
import { useBusyGuard } from '@/shared/hooks/useBusyGuard';
import { formInputClass as inputClass, formLabelClass as labelClass, formSelectClass as selectClass } from '@/shared/ui/formStyles';
import { Modal } from '@/shared/ui/Modal';

import { contactDisplayName } from '@/shared/domain/contactCard/contactDisplay';
import type { KanbanContact } from './kanbanApi';
import { computeRecontactDate, useActiveProductsQuery, useProductCategorySelection } from './kanbanProducts';
import { LV_BWS_MONTHS, fmtEuro, insertWonSaleProduct } from './kanbanSaleWrite';

/** Ergebnis eines abgeschlossenen "Gewonnen"-Popups — `kanbanMutations.ts` schreibt Wiedervorlage/`naechster_kontakt` selbst (Fund 1, `kanban/README.md`: braucht dafür den frischen `updated_at`-Stand, den das Popup nicht kennt). */
export interface WonSaleResult {
  /** `true` = mindestens ein Produkt wurde eingetragen (analog zum Rückgabewert von `recordWonSalesLoop()`). */
  saleRecorded: boolean;
  /** Gewähltes Wiedervorlage-Datum, `null` wenn leer gelassen. Wird UNABHÄNGIG von `saleRecorded` geschrieben (auch im Revert-Fall), siehe CLAUDE.md "Kalender-Aufgaben". */
  wiedervorlage: string | null;
}

export interface KanbanWonSaleModalProps {
  contact: KanbanContact;
  onResolve: (result: WonSaleResult) => void;
}

/**
 * 1:1-Portierung von `recordWonSalesLoop()` (`index.html`) — ein
 * Abschluss kann mehrere Produkte umfassen: "+ Produkt hinzufügen"
 * trägt jedes einzeln sofort in `sales` ein (kein Stückzahl-Feld mehr,
 * siehe CLAUDE.md "BWS-Verrechnung: Provision & Bewertungspunkte").
 * "Fertig" UND "✕" laufen auf denselben `finish()`-Pfad wie im Original:
 * ein ausgefülltes, aber nicht per Klick bestätigtes Produkt wird beim
 * Schließen automatisch mit übernommen (Bugfix 2026-08-14 im echten
 * Code — sonst ginge ein Einzel-Produkt-Verkauf beim direkten
 * "Fertig"-Klick verloren).
 *
 * **Bewusste Abweichung von Vanilla:** ein Klick auf die abgedunkelte
 * Fläche hinter dem Modal löst hier ebenfalls `finish()` aus. Im echten
 * Code schließt derselbe Klick das `.loc-modal` nur optisch
 * (`modal.style.display='none'`, siehe globaler Klick-Handler in
 * `index.html`), OHNE die wartende Promise aufzulösen — der
 * `moveKanbanCard()`-Aufruf bliebe dort für immer hängen. Für die
 * TanStack-Mutation hier wäre das schlimmer (das ganze Board bliebe
 * `aria-busy`/gesperrt), deshalb bewusst korrigiert statt 1:1 übernommen.
 */
export function KanbanWonSaleModal({ contact, onResolve }: KanbanWonSaleModalProps) {
  const profile = getBridge().getProfile();
  const orgId = profile?.org_id ?? undefined;
  const { data: products } = useActiveProductsQuery(orgId);
  const { categories, category, setCategory, productsForCategory, productId, setProductId, selectedProduct } =
    useProductCategorySelection(products);

  const [vertragsnummer, setVertragsnummer] = useState('');
  const [beitrag, setBeitrag] = useState('');
  const [vertragsbeginn, setVertragsbeginn] = useState('');
  const [status, setStatus] = useState('');
  const [added, setAdded] = useState<string[]>([]);
  const { busy, run } = useBusyGuard();

  // Wiedervorlage: gleiches Override-Prinzip wie Kategorie/Produkt oben --
  // "solange der Nutzer das Feld nicht selbst angefasst hat" (CLAUDE.md
  // "Produktweite Nachfass-Empfehlung") wird `wiedervorlageOverride` NICHT
  // gesetzt (bleibt `null`), der angezeigte Wert ist dann die live aus
  // Produkt+Vertragsbeginn abgeleitete Empfehlung. Sobald der Nutzer tippt,
  // ist der Override (auch als Leerstring) dauerhaft gesetzt und gewinnt.
  const [wiedervorlageOverride, setWiedervorlageOverride] = useState<string | null>(null);
  const suggestedWiedervorlage = computeRecontactDate(selectedProduct, vertragsbeginn);
  const wiedervorlage = wiedervorlageOverride ?? suggestedWiedervorlage ?? '';

  const bwsPreview =
    selectedProduct?.provision_mode === 'individuell_lv' && beitrag
      ? `Bewertungssumme (automatisch, Beitrag × 360): ${fmtEuro(parseFloat(beitrag) * LV_BWS_MONTHS)}`
      : null;

  async function addProduct(): Promise<boolean> {
    if (!selectedProduct) {
      setStatus('Bitte Produkt auswählen.');
      return false;
    }
    if (!vertragsbeginn) {
      setStatus('Bitte Vertragsbeginn eintragen.');
      return false;
    }
    if (!profile?.org_id) {
      setStatus('Keine Organisation.');
      return false;
    }
    try {
      await insertWonSaleProduct(contact.id, profile.org_id, profile.id, {
        productId: selectedProduct.id,
        vertragsnummer: vertragsnummer.trim() || null,
        laufenderBeitrag: beitrag ? parseFloat(beitrag) : null,
        vertragsbeginn,
      });
    } catch (err) {
      logSilentError('Verkauf eintragen', err);
      setStatus(toError(err).message);
      return false;
    }
    setAdded((prev) => [...prev, selectedProduct.name]);
    setVertragsnummer('');
    setBeitrag('');
    setVertragsbeginn('');
    setStatus('');
    return true;
  }

  async function finish() {
    const result = await run(async (): Promise<WonSaleResult | null> => {
      let addedCount = added.length;
      // Ein ausgefülltes, aber nicht bestätigtes Produkt beim Schließen
      // automatisch mit übernehmen (siehe Kommentar oben).
      if (vertragsbeginn) {
        const ok = await addProduct();
        if (!ok) return null; // Status-Text zeigt den Fehler, Modal bleibt offen.
        addedCount += 1;
      }
      return { saleRecorded: addedCount > 0, wiedervorlage: wiedervorlage || null };
    });
    if (result) onResolve(result);
  }

  return (
    <Modal
      title={<>Verkauf eintragen für {contactDisplayName(contact)}</>}
      onClose={() => void finish()}
      testId="sale-entry-modal"
      closeTestId="sale-entry-close"
    >
      <div className="tw:flex tw:flex-col tw:gap-2">
        <select
          data-testid="sale-entry-category"
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
          data-testid="sale-entry-product"
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
        <input
          type="text"
          placeholder="Vertragsnummer (optional)"
          maxLength={60}
          className={inputClass}
          value={vertragsnummer}
          onChange={(e) => setVertragsnummer(e.target.value)}
        />
        <input
          type="number"
          placeholder="Laufender Beitrag (€)"
          step="0.01"
          min="0"
          className={inputClass}
          value={beitrag}
          onChange={(e) => setBeitrag(e.target.value)}
        />
        <label className={labelClass}>Vertragsbeginn</label>
        <input
          type="date"
          data-testid="sale-entry-vertragsbeginn"
          className={inputClass}
          value={vertragsbeginn}
          onChange={(e) => setVertragsbeginn(e.target.value)}
        />
        {bwsPreview && <div className="tw:text-xs tw:text-muted">{bwsPreview}</div>}
        <button
          type="button"
          className="tw:rounded-sm tw:border tw:border-border tw:bg-panel-2 tw:px-2 tw:py-1.5 tw:text-sm tw:text-text tw:hover:border-arcane"
          disabled={busy}
          onClick={() => void run(() => addProduct())}
        >
          + Produkt hinzufügen
        </button>
        {status && <div className="tw:text-xs tw:text-danger">{status}</div>}
        {added.length > 0 && <div className="tw:text-xs tw:text-success">{added.map((name) => `✓ ${name}`).join(' · ')}</div>}
        <label className={labelClass}>Wiedervorlage (optional) – wann meldest du dich wieder?</label>
        <input
          type="date"
          className={inputClass}
          value={wiedervorlage}
          onChange={(e) => setWiedervorlageOverride(e.target.value)}
        />
      </div>
      <button
        type="button"
        data-testid="sale-entry-done"
        className="tw:mt-3 tw:w-full tw:rounded-sm tw:border tw:border-arcane tw:bg-arcane/10 tw:px-2 tw:py-1.5 tw:text-sm tw:font-semibold tw:text-text"
        disabled={busy}
        onClick={() => void finish()}
      >
        Fertig
      </button>
    </Modal>
  );
}
