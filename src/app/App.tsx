import { Route, Routes } from 'react-router-dom';

import { EinstellungenPage } from '@/features/einstellungen/EinstellungenPage';

/**
 * Strangler-Fig-Wurzel (ADR-0001/0003): jede Route hier entspricht genau
 * einem `#page-<name>`-Div im Vanilla-`index.html`, das eigene Sichtbarkeit
 * bereits per `display:none`/`block` regelt. React muss dafür nichts
 * Eigenes beitragen -- ein nicht-migrierter Pfad rendert schlicht nichts
 * (Vanilla übernimmt die betreffende Seite komplett).
 *
 * `path="einstellungen"` matcht `#einstellungen` (kein führender Slash im
 * Vanilla-Hash-Format nötig -- empirisch gegen HashRouter verifiziert,
 * siehe Fundament-Review 2026-09-02).
 */
export function App() {
  return (
    <Routes>
      <Route path="einstellungen" element={<EinstellungenPage />} />
      <Route path="*" element={null} />
    </Routes>
  );
}
