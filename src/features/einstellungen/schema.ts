import { z } from 'zod';

/**
 * Deckt bisher nur die Gruppe "Profil" ab (real_name/company) --
 * Grenzen 1:1 aus SETTINGS_REGISTRY in index.html übernommen (maxlength
 * 60 / 80). Provision/Kalender folgen mit eigenen Schemas, sobald diese
 * Gruppen migriert werden (siehe README.md dieses Ordners).
 */
export const profilFormSchema = z.object({
  real_name: z.string().trim().max(60, 'Höchstens 60 Zeichen.'),
  company: z.string().trim().max(80, 'Höchstens 80 Zeichen.'),
});

export type ProfilFormValues = z.infer<typeof profilFormSchema>;
