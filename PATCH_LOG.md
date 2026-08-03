# Patch-Verlauf (chronologisch, alle bereits erstellt)

Alle Dateien liegen als Vorlage vor. Diese Liste dokumentiert, was jeder Patch
bewirkt — nicht ob er auf einer bestimmten Datenbank schon gelaufen ist. Vor
dem ersten Arbeiten mit Claude Code: mit dem Nutzer verifizieren, ob wirklich
alle bis einschließlich Patch 15 im Supabase-Projekt eingespielt sind.

| # | Datei | Kernstück |
|---|---|---|
| 1 | `schema.sql` | Grundschema: `organizations`, `profiles`, `rule_configs`, `action_log`, RLS-Basisfunktionen `current_org_id()`/`is_admin()` |
| 1b | `patch.sql` | (früher Patch, Ergänzung zum Grundschema — profiles-Insert-Policy, `meta`-Spalte im Log) |
| 2 | `patch2_journal.sql` | Tagebuch: `journal_entries`, 5 feste Fragen, strikt privat (keine Admin-Ausnahme) |
| 3 | `patch3_inventar.sql` | `user_inventory`, erster Item-Katalog (Manatrank) im Regelwerk |
| 4 | `patch4_fotos.sql` | Foto-Funktion im Tagebuch: privater Storage-Bucket, `journal_photos` (inkl. Platzhalter für spätere KI-Umwandlung) |
| 5 | `patch5_ausruestung.sql` | `profiles.equipped_weapon/armor/accessory` — Grundlage für späteres Ausrüstungssystem |
| 6 | `patch6_gilde.sql` | `guilds`, `guild_members`, `profiles.total_xp/level`-Cache (damit Level sichtbar ist ohne fremdes privates Log zu lesen) |
| 7 | `patch7_freunde.sql` | `friends` — einfache, unidirektionale Liste (später durch Patch 8 zum Anfrage-System erweitert) |
| 8 | `patch8_freundschaftsanfragen.sql` | `friends.status` ('pending'/'accepted'), RLS für Annehmen/Ablehnen |
| 9 | `patch9_dungeons.sql` | `locations` ("Dungeons"), `action_log.location_id`, `locationTypes` im Regelwerk |
| 10 | `patch10_kontakte.sql` | **Kundendatenbank-Fundament**: `contacts`, `action_log.contact_id`, `contactsVisibility`-Einstellung, `contactRoles` |
| 11 | `patch11_account_pool.sql` | `locations.owner_id` (Pool-Mechanismus), Trigger: Kontakte wandern bei Neuzuweisung automatisch mit |
| 12 | `patch12_ansprache_tagebuch.sql` | Ansprache vereinheitlicht (5 XP für alle statt gestaffelt), `journal_entries.tagged_contact_id`, Level-Kurve neu kalibriert (`levelBase` 5 → 4.7) |
| 13 | `patch13_kundendatenbank_ausbau.sql` | Vorname/Nachname getrennt (name wird generierte Spalte), `bedarf_ist`/`bedarf_wunsch`, `naechster_kontakt`, echte `sales`-Tabelle (Verkaufshistorie) |
| 14 | `patch14_betrieb_anlegen.sql` | `locations.plz/strasse/stadt`, Anlegen von Locations für alle Team-Mitglieder freigegeben (nicht mehr nur Admin), Ortstyp "Niederlassung" |
| 15 | `patch15_register_ausbau.sql` | `contacts.geburtsdatum/telefon/email/wohnort_*`, vollständige 7-teilige Berufsstatus-Liste |
| 16 | `patch16_tagebuch_mentions.sql` | Tagebuch-Kundenmarkierung von einzelnem `tagged_contact_id`-Feld auf `journal_entry_mentions`-Tabelle umgestellt (mehrere @mentions pro Tag statt separater Such-Box); **droppt** `journal_entries.tagged_contact_id` nach Datenübernahme |
| 17 | `patch17_error_log.sql` | `error_log`-Tabelle für zentrale Fehlerprotokollierung (jeder fehlgeschlagene DB-Aufruf landet hier), Lesen nur für Admins, Index auf `(org_id, created_at)` |
| 17b | `patch17b_indizes.sql` | Fehlende Indizes auf Fremdschlüssel-Spalten (`contacts`, `locations`, `sales`, `journal_entry_mentions`, `profiles`) — vorher gab es außer auf `action_log` keine |
| 18 | `patch18_kanban.sql` | `contacts.kanban_stage` (Kanban-Spalte pro Kontakt, 8 feste Werte), neue Aktion `termin_nicht_wahrgenommen` (−2 XP, Konversions-Malus) im Regelwerk |
| 19 | `patch19_kanban_opt_in.sql` | **Korrektur zu Patch 18**: `kanban_stage` war fälschlich `not null default 'neuer_lead'` — dadurch tauchte JEDER bestehende Kontakt automatisch als Lead im Kanban auf, nur weil er in der Datenbank existierte. Jetzt nullable ohne Default, alle bestehenden Kontakte auf `null` zurückgesetzt (= kein Kanban-Kontakt) |
| 20 | `patch20_manareserve_20.sql` | `energyMax` (Manareserve/Tagesenergie) von 15 auf 20 angehoben — reine Regelwerk-Konfiguration, kein Code betroffen |
| 21 | `patch21_verkaufsmenge.sql` | `sales.menge` (Integer, Default 1) — Verkäufe können jetzt eine Stückzahl pro Produkt tragen, nicht nur den Produktnamen |
| 22 | `patch22_manatrank_katalog.sql` | Manatrank-Item-Katalogeintrag idempotent (neu) gesetzt, `items` als Objekt abgesichert. Bewusst **ohne** `where org_id = ...`-Filter (Lehre aus dem Patch-20-Vorfall: hartkodierte ID kann still ins Leere laufen, ohne Fehlermeldung) |
| 23 | `patch23_produktkatalog.sql` | Neue Tabelle `products` (Kategorie/Unterkategorie, admin-gepflegt, nur deaktivierbar statt löschbar). `sales.produkt` (Freitext) ersetzt durch `product_id` + neue Felder `bewertungssumme`, `laufender_beitrag`, `vertragsbeginn`, `vertragsende`. **Löscht vorher alle bestehenden `sales`-Zeilen** (waren laut Nutzer nur Testverkäufe) |
| 24 | `patch24_profil_onboarding.sql` | `profiles.real_name`/`gender`/`company` (alle nullable) — neuer Zwischenschritt bei der Charaktererstellung vor der Klassenwahl, siehe CLAUDE.md |
| 25 | `patch25_aussehen.sql` | `profiles.skin_tone`/`hair_style` (beide nullable) — neuer Aussehen-Screen nach der Klassenwahl (Hautfarbe, Frisur), siehe CLAUDE.md |
| 26 | `patch26_klassenitems.sql` | Klassenitems (Zauberstab, blaues Cape, Holzschwert, Guard Helmet, kleiner Rucksack) neu im `items`-Katalog, jetzt als echte, ausziehbare Ausrüstung statt fest im Code verdrahtet. Bestehende Profile bekommen ihr Klassenitem einmalig nachträglich ins Inventar + angezogen, neue Charaktere ab jetzt automatisch bei der Erschaffung (`grantClassStarterEquipment()` in index.html) |
| 27 | `patch27_item_icons.sql` | `icon_img` bei den 5 Klassenitems ergänzt (echte, freigestellte Bild-Ausschnitte aus den Sprite-Sheets statt generischer Emojis, die bei wachsendem Katalog nicht mehr unterscheidbar wären) — Bilder liegen unter `img/characters/creator/item_*.png` |

## Wichtiger Hinweis zu Patch 13

Dieser Patch **löscht** die alte `name`-Spalte bei Kontakten (ersetzt durch
generierte Spalte aus `vorname`+`nachname`). Falls zum Zeitpunkt der
Ausführung bereits echte Kontakt-Daten existierten, gingen die ursprünglichen
Namen dabei verloren (mussten neu eingetragen werden). Rein informativ, falls
das rückblickend Verwirrung stiftet.

## Wichtiger Hinweis zu Patch 16

Dieser Patch **löscht** `journal_entries.tagged_contact_id`, nachdem er ihren
Inhalt zuvor in die neue Tabelle `journal_entry_mentions` kopiert hat (Schritt
2 vor Schritt 3 im Patch, keine Datenverluste bei normaler Ausführung als
Ganzes). Wenn der Patch aus irgendeinem Grund nur teilweise läuft, vor dem
erneuten Ausführen prüfen, ob die Kopie bereits stattgefunden hat.

## Wenn ein neuer Patch nötig wird

Muster beibehalten: neue Datei `patchN_kurzname.sql`, Kommentarkopf mit
Nummer/Titel/Ausführungshinweis, `alter table ... add column if not exists`
wo möglich (idempotent), destruktive Operationen (`drop column`, `delete`)
immer explizit im Kommentar markieren und dem Nutzer gegenüber vor Ausführung
benennen.
