import './EinstellungenPage.css';
import { useOwnProfileQuery } from './api';
import { ChronikSection } from './sections/ChronikSection';
import { KalenderSection } from './sections/KalenderSection';
import { ProfilSection } from './sections/ProfilSection';
import { ProvisionSection } from './sections/ProvisionSection';

/**
 * Block-3-Pilot (docs/migration-status.md) -- alle vier SETTINGS_GROUPS
 * aus der Vanilla-Registry sind hier abgedeckt. Danger Zone bleibt
 * bewusst dauerhaft Vanilla (index.html, `leaveOrgBtn`/`deleteAccountBtn`
 * -- eigene Listener außerhalb der jetzt vollständig toten
 * `renderEinstellungenPage()`). Details/Abgrenzung: README.md.
 */
export function EinstellungenPage() {
  const { isLoading, isError } = useOwnProfileQuery();

  if (isLoading) return <p>Lädt …</p>;
  if (isError) return <p>Profil konnte nicht geladen werden.</p>;

  return (
    <div className="ein-wrap">
      <ProfilSection />
      <ChronikSection />
      <ProvisionSection />
      <KalenderSection />
    </div>
  );
}
