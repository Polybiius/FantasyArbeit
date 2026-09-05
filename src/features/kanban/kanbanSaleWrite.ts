import { sb } from '@/shared/lib/bridge';
import { logSilentError } from '@/shared/lib/errorLog';

/** `laufender_beitrag` (Leben) × 12 Monate × 30 Jahre — 1:1 `LV_BWS_MONTHS` in `index.html`. */
export const LV_BWS_MONTHS = 360;

export function fmtEuro(n: number | null): string {
  return n == null ? '—' : n.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
}

export interface WonSaleProductInput {
  productId: string;
  vertragsnummer: string | null;
  laufenderBeitrag: number | null;
  vertragsbeginn: string;
}

/** 1:1-Portierung eines einzelnen `sales`-Inserts aus `recordWonSalesLoop()` — `menge` bewusst fest 1 (CLAUDE.md "BWS-Verrechnung"). */
export async function insertWonSaleProduct(
  contactId: string,
  orgId: string,
  createdBy: string,
  input: WonSaleProductInput,
): Promise<void> {
  const { error } = await sb()
    .from('sales')
    .insert({
      contact_id: contactId,
      org_id: orgId,
      product_id: input.productId,
      menge: 1,
      vertragsnummer: input.vertragsnummer,
      laufender_beitrag: input.laufenderBeitrag,
      vertragsbeginn: input.vertragsbeginn,
      status: 'gewonnen',
      created_by: createdBy,
    });
  if (error) throw error;
}

/** 1:1-Portierung des `sales`-Inserts aus `recordLostSale()` — kein Mengenfeld, keine Mehrfach-Schleife. */
export async function insertLostSale(contactId: string, orgId: string, createdBy: string, productId: string): Promise<void> {
  const { error } = await sb()
    .from('sales')
    .insert({ contact_id: contactId, org_id: orgId, product_id: productId, status: 'verloren', created_by: createdBy });
  if (error) throw error;
}

/**
 * 1:1-Portierung von `syncWiedervorlageTask()` — löscht eine evtl. schon
 * offene Wiedervorlage-Aufgabe des Kontakts und legt bei gesetztem Datum
 * sofort die neue an. Fehler werden bewusst NICHT geworfen (Vanilla-
 * Original: `logSilentError`, der bereits eingetragene Verkauf bleibt
 * davon unberührt — eine liegen gebliebene Aufgabe ist kein Grund, das
 * ganze Verkaufs-Popup als fehlgeschlagen zu behandeln).
 */
export async function syncWiedervorlageTask(
  orgId: string,
  ownerId: string,
  contactId: string,
  contactName: string,
  newDate: string | null,
): Promise<void> {
  const { error: delError } = await sb()
    .from('tasks')
    .delete()
    .eq('owner_id', ownerId)
    .eq('contact_id', contactId)
    .eq('source_type', 'wiedervorlage');
  if (delError) logSilentError('Alte Wiedervorlage-Aufgabe entfernen', delError);

  if (newDate) {
    const { error } = await sb()
      .from('tasks')
      .insert({ org_id: orgId, owner_id: ownerId, contact_id: contactId, title: `Wiedervorlage: ${contactName}`, due_date: newDate, source_type: 'wiedervorlage' });
    if (error) logSilentError('Wiedervorlage-Aufgabe anlegen', error);
  }
}
