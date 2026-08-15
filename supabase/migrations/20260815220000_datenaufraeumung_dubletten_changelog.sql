-- Datenaufräumung nach Sicherheits-/Datenaudit (2026-08-15), auf
-- ausdrücklichen Nutzerwunsch nach dem Questbaum-/Gilden-Ausbau.
--
-- 1) Drei Dubletten-Locations für dasselbe Krankenhaus gefunden
--    ("Christophorus-Kliniken (Hauptgebäude)" mit Bindestrich vs. zwei
--    Varianten ohne, IDs 49daccf8.../ec7c4b56.../b777ee0b...). Noch hing
--    weder eine Aktion noch ein Kontakt an den zwei überzähligen Zeilen,
--    aber die neue Questbaum-Ladder "kh_gaenge"/"kh_breite" gruppiert
--    genau nach location_id -- unbemerkt hätte das echte Krankenhausbesuche
--    unter drei verschiedenen IDs zersplittert und die Quest-Fortschritte
--    verwässert. Behalten wird die älteste Zeile (mit Bindestrich).
--
-- 2) Das Changelog-Popup (schema_patches, Patch 32) war seit Patch 40
--    (2026-08-09) nicht mehr nachgeführt worden -- fünf spätere Patches mit
--    echten Nutzer-Funktionen (Vertragsnummer, Datei-Upload, Chronik-
--    Sichtbarkeit, Sicherheitshärtung) haben sich nie eingetragen.
--    Rückwirkend nachgetragen, damit Kolleg:innen mit älterem
--    last_seen_patch_number diese Neuerungen noch angezeigt bekommen.
--    (Die reinen rule_configs-Datenpatches des Questbaum-Ausbaus/
--    Provisions-Reworks bleiben bewusst ohne eigenen Eintrag -- die waren
--    laufender Aufbau einer noch nicht fertigen Ansicht, kein einzelner
--    "Patch"-Moment für Nutzer.)
--
-- Hinweis: diese Migration wurde bereits per direktem `supabase db query
-- --linked` gegen die echte DB ausgeführt (Nutzer-Go eingeholt) und danach
-- per `supabase migration repair` als bereits angewendet markiert, statt
-- ein zweites Mal über `db push` zu laufen (DELETE wäre ein No-Op, INSERT
-- würde an den bereits vergebenen patch_number-Primärschlüsseln scheitern).
-- Die Datei dokumentiert den Schritt trotzdem, wie jeder andere Patch auch.

delete from public.locations
where id in ('ec7c4b56-8e42-4e03-8c12-b772181e21c4','b777ee0b-1f60-44f9-8393-846c309e750f');

insert into public.schema_patches (patch_number, title, applied_at) values
  (41, 'Vertragsnummer-Feld an Verkäufen', '2026-08-10 18:49:39+00'),
  (42, 'Datei-Upload bei Kontakten', '2026-08-10 18:59:23+00'),
  (44, 'Bugfix: Datei-Upload schlug an RLS-Namenskollision fehl', '2026-08-10 19:48:43+00'),
  (45, 'Chronik-Sichtbarkeit folgt automatisch der Kontakt-Freigabe', '2026-08-10 20:19:54+00'),
  (46, 'Fehlende Fremdschlüssel-Indizes + search_path-Härtung', '2026-08-11 20:23:49+00')
on conflict (patch_number) do nothing;
