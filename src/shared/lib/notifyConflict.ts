/**
 * Entsprechung zu `alertConflict()` im Vanilla-Code: die Meldung, wenn
 * ein Datensatz zwischenzeitlich von jemand anderem geändert wurde
 * (optimistisches Sperren, siehe CLAUDE.md „Konflikt-Schutz bei
 * gleichzeitiger Bearbeitung").
 *
 * Bewusst identisch zu Vanilla (`window.alert`), damit sich alt und neu
 * während der Migration gleich anfühlen. Wird auf ein Toast-System
 * umgestellt, sobald es das gibt (Styling-Spike / docs/adr 0006).
 */
export function notifyConflict(subject: string): void {
  window.alert(
    `${subject} wurde inzwischen von jemand anderem geändert. ` +
      'Bitte lade die Seite neu, um die aktuelle Version zu sehen.',
  );
}
