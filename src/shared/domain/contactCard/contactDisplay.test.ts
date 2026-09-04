import { describe, expect, it } from 'vitest';

import { contactDisplayName } from './contactDisplay';

describe('contactDisplayName', () => {
  it('nutzt die generierte name-Spalte, wenn vorhanden', () => {
    expect(contactDisplayName({ name: 'Erika Mustermann', vorname: 'Erika', nachname: 'Mustermann' })).toBe(
      'Erika Mustermann',
    );
  });

  it('fällt auf vorname+nachname zurück, wenn name fehlt', () => {
    expect(contactDisplayName({ name: null, vorname: 'Max', nachname: 'Muster' })).toBe('Max Muster');
  });

  it('fällt auf vorname+nachname zurück, wenn name nur Leerraum ist', () => {
    expect(contactDisplayName({ name: '   ', vorname: 'Max', nachname: 'Muster' })).toBe('Max Muster');
  });
});
