/**
 * 1:1 aus `allTimezones()` in index.html übernommen -- volle IANA-Liste
 * vom Browser, falls verfügbar, sonst eine handverlesene, praxisnahe
 * Auswahl gängiger Geschäfts-Zeitzonen als Rückfall.
 */
export function allTimezones(): string[] {
  if (typeof Intl.supportedValuesOf === 'function') {
    try {
      return Intl.supportedValuesOf('timeZone');
    } catch {
      // Rückfall unten
    }
  }
  return [
    'Europe/Berlin', 'Europe/London', 'Europe/Paris', 'Europe/Madrid', 'Europe/Rome',
    'Europe/Zurich', 'Europe/Vienna', 'Europe/Warsaw', 'Europe/Lisbon', 'Europe/Moscow',
    'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles',
    'America/Sao_Paulo', 'Asia/Dubai', 'Asia/Kolkata', 'Asia/Shanghai', 'Asia/Tokyo',
    'Asia/Singapore', 'Australia/Sydney', 'Pacific/Auckland', 'UTC',
  ];
}
