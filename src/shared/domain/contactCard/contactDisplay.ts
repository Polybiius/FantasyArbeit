/**
 * Reine Anzeige-Helfer für die Kontakt-Karte — bewusst framework-frei
 * (kein React), damit sie mit Vitest ohne DOM getestet werden können,
 * gleiches Prinzip wie `kanbanTransitions.ts` (docs/adr/0007).
 */

/**
 * `contacts.name` ist im echten Schema eine GENERIERTE Spalte
 * (`vorname || ' ' || nachname`, siehe CLAUDE.md "Kern-Tabellen") — sie
 * kommt bei jeder Lese-Abfrage bereits fertig zusammengesetzt mit.
 * Dieser Helfer ist nur der Rückfall für den seltenen Fall, dass eine
 * Abfrage `name` nicht mit ausgewählt hat.
 */
export function contactDisplayName(contact: { name: string | null; vorname: string; nachname: string }): string {
  return contact.name?.trim() || `${contact.vorname} ${contact.nachname}`.trim();
}
