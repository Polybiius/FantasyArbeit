/**
 * Zahlen-Felder aus SETTINGS_REGISTRY (Gruppe Provision) kannten in
 * Vanilla zwei Anzeige-/Parse-Stile (`settingsEntryValue()`/
 * `settingsInputChanged()` in index.html):
 *   - 'number'  -- natives <input type="number">, Wert/DOM-String nutzt
 *     IMMER "." als Dezimaltrennzeichen (HTML-Spezifikation, unabhängig
 *     vom OS-Gebietsschema).
 *   - 'decimal' (nur lv_prozent_satz) -- <input type="text"
 *     inputmode="decimal">, zeigt/erwartet deutsches Komma, weil native
 *     Zahlenfelder in den meisten Browsern gar kein Komma als Eingabe
 *     zulassen.
 * Diese zwei Helfer-Paare spiegeln genau dieses Verhalten für React.
 */
export function parsePlainNumber(raw: string): number | null {
  const trimmed = raw.trim();
  if (trimmed === '') return null;
  // parseFloat (nicht Number()) -- spiegelt Vanillas settingsSaveBarSave
  // (index.html), das ebenfalls parseFloat nutzt und dadurch Nachsilben
  // toleriert ("123abc" -> 123). Unabhängiger Review 2026-09-03: Number()
  // hätte hier strenger abgelehnt als das noch aktive Vanilla-Gegenstück.
  return parseFloat(trimmed);
}

export function displayPlainNumber(v: number | null | undefined): string {
  if (v === null || v === undefined) return '';
  return String(v);
}

export function parseGermanDecimal(raw: string): number | null {
  const trimmed = raw.trim();
  if (trimmed === '') return null;
  return parseFloat(trimmed.replace(',', '.'));
}

export function displayGermanDecimal(v: number | null | undefined): string {
  if (v === null || v === undefined) return '';
  return String(v).replace('.', ',');
}

/** Für RHF `register(name, { validate })` -- leer ist immer gültig (optionales Feld). */
export const numberValidate = (v: string): true | string =>
  v.trim() === '' || !Number.isNaN(parsePlainNumber(v)) || 'Ungültige Zahl.';
export const decimalValidate = (v: string): true | string =>
  v.trim() === '' || !Number.isNaN(parseGermanDecimal(v)) || 'Ungültige Zahl.';
