# Verzeichnis von Verarbeitungstätigkeiten (VVT) — ENTWURF

Pflichtdokument nach Art. 30 DSGVO. Kein Text für Kunden/Öffentlichkeit —
dient der eigenen Dokumentationspflicht und als Nachweis bei einer
Prüfung durch eine Aufsichtsbehörde. Muss bei jeder wesentlichen
Änderung an der Datenverarbeitung (neue Tabelle mit personenbezogenen
Daten, neuer Auftragsverarbeiter, geänderte Speicherdauer) aktualisiert
werden — am besten direkt zusammen mit CLAUDE.md fortschreiben, da dort
ohnehin jede neue Tabelle dokumentiert wird.

Letzte Überarbeitung: 2026-08-25.

---

## Verantwortlicher

Muharrem Sakin, Ruhrtalstraße 78, 45239 Essen, sakin.muharrem@web.de
(siehe `datenschutzerklaerung_entwurf.md` im selben Ordner)

## Verarbeitungstätigkeit 1: Nutzer:innen-Verwaltung

| | |
|---|---|
| **Zweck** | Login, Zuordnung zur Kundenorganisation, Anzeige von Profil/Charakter |
| **Betroffene** | Mitarbeiter:innen der Kundenorganisation |
| **Datenkategorien** | E-Mail, Passwort (gehasht), echter Name, Charaktername, Geschlecht, Firma, Zeitzone |
| **Rechtsgrundlage** | Vertragserfüllung (Art. 6 Abs. 1 lit. b) |
| **Tabelle(n)** | `profiles` |
| **Empfänger** | Supabase (Auftragsverarbeiter) |
| **Speicherdauer** | solange Account besteht; Löschmechanismus für einzelne Accounts noch nicht gebaut (siehe Datenschutzerklärung Abschnitt 8) |
| **TOMs** | Passwort-Hashing durch Supabase Auth, RLS pro Organisation, sensible Felder (Rolle, Klasse, Org-Zugehörigkeit) serverseitig gegen Selbstmanipulation gehärtet (siehe CLAUDE.md, "Serverseitige Schreib-Härtung") |

## Verarbeitungstätigkeit 2: Kontakt-/Kundendatenverwaltung (CRM-Kern)

| | |
|---|---|
| **Zweck** | Vertriebsdokumentation, Nachverfolgung von Geschäftskontakten |
| **Betroffene** | Von Nutzer:innen erfasste Geschäftskontakte (nicht selbst Nutzer:innen des Systems) |
| **Datenkategorien** | Vor-/Nachname, Geburtsdatum, Telefon, E-Mail, Wohn-/Berufsadresse, Berufsstatus, Notizen, Bedarfsanalyse |
| **Rechtsgrundlage** | berechtigtes Interesse (Art. 6 Abs. 1 lit. f) — *rechtlich noch zu bestätigen, siehe Datenschutzerklärung Abschnitt 5* |
| **Tabelle(n)** | `contacts` |
| **Empfänger** | Supabase (Auftragsverarbeiter); innerhalb der Organisation ggf. an Gildenmitglieder mit Freigabe (siehe CLAUDE.md, "Gilden-basierte Sichtbarkeit") |
| **Speicherdauer** | **Automatische Löschung nach 6 Monaten ohne aktiv laufenden Vertrag** (konfigurierbar pro Organisation über `rule_configs`, Details siehe Abschnitt "Offene technische Umsetzung" unten) |
| **TOMs** | RLS pro Organisation + Gildenfreigabe, serverseitig gehärtete Schreibrechte (`update_contact_locked()`) |

## Verarbeitungstätigkeit 3: Vertriebsdokumentation (Termine, Anrufe, Verkäufe)

| | |
|---|---|
| **Zweck** | Nachvollziehbarkeit der Kundenhistorie, Provisions-/Erfolgsberechnung |
| **Betroffene** | dieselben Kontakte wie oben |
| **Datenkategorien** | Termin-/Anruf-/E-Mail-Verlauf, Verkaufsabschlüsse, Vertragsdaten, Vertragsnummern |
| **Rechtsgrundlage** | berechtigtes Interesse (Art. 6 Abs. 1 lit. f), bei echten Vertragsabschlüssen zusätzlich Vertragserfüllung im Verhältnis Kunde↔Kundenorganisation |
| **Tabelle(n)** | `termine`, `contact_activities`, `sales` |
| **Empfänger** | Supabase (Auftragsverarbeiter) |
| **Speicherdauer** | folgt dem zugehörigen Kontakt (siehe oben); bei tatsächlich abgeschlossenen Verträgen ggf. eigene handelsrechtliche Aufbewahrungspflichten zu prüfen (§257 HGB, 6 Jahre bei Handelsbriefen — nur relevant, wenn ein Vertrag wirklich zustande kam) |
| **TOMs** | wie Verarbeitungstätigkeit 2 |

## Verarbeitungstätigkeit 4: Persönliches Tagebuch

| | |
|---|---|
| **Zweck** | Reflexions-/Motivationswerkzeug für Nutzer:innen |
| **Betroffene** | Nutzer:innen selbst |
| **Datenkategorien** | Freitext-Tagebucheinträge, Fotos |
| **Rechtsgrundlage** | berechtigtes Interesse / Einwilligung durch freiwillige Nutzung |
| **Tabelle(n)** | `journal_entries`, `journal_photos` |
| **Empfänger** | Supabase (Auftragsverarbeiter) — **keine** Weitergabe, auch nicht an Admins der eigenen Organisation |
| **Speicherdauer** | unbegrenzt, solange Account besteht (bewusste Produktentscheidung — Tagebuch ist strikt privat) |
| **TOMs** | einzige Tabelle im Schema ohne Admin-Ausnahme in der RLS-Policy |

## Verarbeitungstätigkeit 5: Leistungs-/Gamification-Daten

| | |
|---|---|
| **Zweck** | Motivationsmechanik (XP, Level, Skills) — abgeleitet aus tatsächlicher Vertriebsaktivität |
| **Betroffene** | Nutzer:innen |
| **Datenkategorien** | protokollierte Vertriebsaktionen, daraus berechnete Kennzahlen |
| **Rechtsgrundlage** | berechtigtes Interesse (Motivations-/Personalentwicklungszweck) |
| **Tabelle(n)** | `action_log` |
| **Hinweis** | ⚠️ Systeme, die Leistung/Verhalten von Arbeitnehmer:innen sichtbar messen, können bei Kundenorganisationen mit Betriebsrat der Mitbestimmung nach §87 Abs. 1 Nr. 6 BetrVG unterliegen (technische Überwachungseinrichtung) — das ist kein DSGVO-, sondern ein Arbeitsrecht-Thema, aber relevant genug, um bei einem echten Pilotkunden mit Betriebsrat aktiv anzusprechen, nicht erst wenn danach gefragt wird. |
| **Speicherdauer** | unbegrenzt (Grundlage für Level-Berechnung über die gesamte Account-Laufzeit) |

## Verarbeitungstätigkeit 6: Datei-Uploads am Kontakt

| | |
|---|---|
| **Zweck** | Ablage von Vertragsunterlagen/Dokumenten am jeweiligen Kontakt |
| **Betroffene** | im System erfasste Kontakte |
| **Datenkategorien** | hochgeladene Dateien (PDF/Bilder), ggf. mit personenbezogenem Inhalt |
| **Rechtsgrundlage** | wie Verarbeitungstätigkeit 2/3 |
| **Tabelle(n)/Speicher** | `contact_files`, Storage-Bucket `contact-files` |
| **Speicherdauer** | folgt dem zugehörigen Kontakt |
| **TOMs** | max. 10 MB/Datei, geprüfte Dateitypen, signierte, zeitlich begrenzte Download-URLs, Freigabe folgt der Kontakt-Freigabe |

## Verarbeitungstätigkeit 7: Standort-/Geodaten

| | |
|---|---|
| **Zweck** | Darstellung von Betrieben ("Dungeons") auf der Karte |
| **Betroffene** | keine natürlichen Personen direkt (Betriebsadressen), ggf. indirekt über die IP-Adresse der abfragenden Nutzer:innen |
| **Datenkategorien** | eingegebene Adresse, IP-Adresse bei der Geocoding-/Kartenanfrage |
| **Empfänger** | OpenStreetMap Nominatim (Geocoding), CartoDB (Kartenkacheln) — beides externe Dienste ohne eigenen AVV bisher |
| **Speicherdauer** | Adressdaten folgen dem Betrieb; die externen Dienste selbst protokollieren serverseitig nach eigenen, nicht von uns kontrollierten Regeln |

## Verarbeitungstätigkeit 8: Sicherheits- und Fehlerprotokolle

| | |
|---|---|
| **Zweck** | Erkennung von Manipulationsversuchen, Fehlerdiagnose |
| **Betroffene** | Nutzer:innen (bei auffälligem/fehlgeschlagenem Zugriff) |
| **Datenkategorien** | Nutzer-ID, Kontext der Aktion, Fehlermeldung, Zeitpunkt |
| **Rechtsgrundlage** | berechtigtes Interesse an Systemsicherheit (Art. 6 Abs. 1 lit. f) |
| **Tabelle(n)** | `error_log`, `security_alerts`, `access_audit_log` |
| **Empfänger** | nur Admins der eigenen Organisation |
| **Speicherdauer** | unbegrenzt, bewusst unveränderlich (Protokoll-Charakter) |

## Liste der Auftragsverarbeiter / externen Dienste

Siehe Datenschutzerklärung, Abschnitt 6 — hier nicht dupliziert, damit
nicht zwei Stellen gepflegt werden müssen, die auseinanderlaufen können.

**Offener Punkt:** für Supabase fehlt noch der angeforderte AVV (siehe
CLAUDE.md, Phase 1). Für Nominatim/CartoDB gibt es keinen klassischen
AVV-Prozess (öffentliche, kostenlose Dienste) — hier reicht in der Regel
die Nennung als Empfänger in der Datenschutzerklärung plus Prüfung der
jeweiligen Nutzungsbedingungen, kein Ersatz für eine Rechtsberatung.

## Offene technische Umsetzung (Stand 2026-08-25)

Automatische Löschung von Kontakten ohne aktiv laufenden Vertrag: fachlich
festgelegt (siehe CLAUDE.md-Eintrag, sobald gebaut), technisch noch nicht
umgesetzt. Diese Zeile hier stehen lassen, bis der Punkt aus CLAUDE.md
als erledigt markiert ist — dann auch die Speicherdauer-Zeile in
Verarbeitungstätigkeit 2 oben von "geplant" auf den tatsächlichen
Mechanismus aktualisieren.
