# Datenschutzerklärung — ENTWURF

**Status: Entwurf, noch nicht veröffentlicht.** Vor dem ersten echten
Kundeneinsatz (Pilotkunde, Phase 2) durch einen Rechtsanwalt oder
Datenschutzbeauftragten gegenprüfen lassen — insbesondere die Abschnitte
zur Rechtsgrundlage der Kontaktdatenverarbeitung (Abschnitt 5) und zum
Drittlandtransfer (Abschnitt 7), das sind Einzelfallbewertungen, die eine
KI-Einschätzung nicht ersetzen kann.

Letzte Überarbeitung: 2026-08-25.

---

## 1. Verantwortlicher

Verantwortlich für die Datenverarbeitung im Sinne der
Datenschutz-Grundverordnung (DSGVO) ist:

Muharrem Sakin
Ruhrtalstraße 78
45239 Essen
E-Mail: sakin.muharrem@web.de

*(Sobald ein Gewerbe/eine Firma für dieses Produkt angemeldet ist, muss
dieser Abschnitt entsprechend ergänzt werden — Firmenname,
Handelsregister-/Steuernummer falls vorhanden.)*

## 2. Worum es in diesem Dokument geht

Dieses Dokument beschreibt, welche personenbezogenen Daten bei der
Nutzung von **Vertriebs-Quest** verarbeitet werden, zu welchem Zweck, auf
welcher Rechtsgrundlage und an wen sie ggf. weitergegeben werden. Es
betrifft zwei unterschiedliche Gruppen betroffener Personen:

- **Nutzer:innen des Systems** (Vertriebsmitarbeiter:innen der jeweiligen
  Kundenorganisation, die sich einloggen und damit arbeiten).
- **Im System erfasste Kontakte** (Personen, die von den Nutzer:innen als
  Geschäftskontakte/Interessent:innen/Kund:innen im CRM angelegt werden —
  diese Personen sind selbst keine Nutzer:innen des Systems).

## 3. Verarbeitete Datenkategorien — Nutzer:innen

- Kontodaten: E-Mail-Adresse, Passwort (verschlüsselt gespeichert)
- Profildaten: echter Name, angezeigter Charaktername, Geschlecht
  (nur zur Anzeige der Klassenbezeichnung), Firma, Zeitzone
- Leistungs-/Vertriebsdaten: geloggte Vertriebsaktivitäten, Verkaufszahlen,
  daraus abgeleitete Kennzahlen (Level, Skills — Teil der
  Motivationsmechanik der Anwendung)
- Persönliche Tagebucheinträge und Fotos (**streng privat** — nicht
  einmal von Administrator:innen der Kundenorganisation einsehbar)
- Technische Protokolldaten (Fehlerprotokoll, Sicherheitswarnungen) bei
  fehlgeschlagenen oder auffälligen Systemzugriffen

## 4. Verarbeitete Datenkategorien — im System erfasste Kontakte

- Name, Geburtsdatum, Telefonnummer, E-Mail-Adresse, Wohn-/Berufsadresse
- Beruflicher Status und Zugehörigkeit zu einem Betrieb
- Verlauf der Geschäftsbeziehung (Termine, Anrufe, Verkäufe, Notizen)
- Ggf. hochgeladene Dokumente (z. B. Vertragsunterlagen)

## 5. Rechtsgrundlagen

- **Nutzer:innen-Konten:** Vertragserfüllung bzw. vorvertragliche
  Maßnahmen (Art. 6 Abs. 1 lit. b DSGVO) im Verhältnis zur jeweiligen
  Kundenorganisation, die das System einsetzt.
- **Kontaktdaten im CRM:** berechtigtes Interesse der Kundenorganisation
  an der Pflege ihrer Geschäftskontakte (Art. 6 Abs. 1 lit. f DSGVO) —
  branchenübliche Vertriebsdokumentation. *Hinweis für die rechtliche
  Prüfung: da diese Daten in der Regel nicht direkt bei der betroffenen
  Person selbst erhoben werden, ist zusätzlich die Informationspflicht
  nach Art. 14 DSGVO zu prüfen (ggf. einschlägige Ausnahmetatbestände bei
  unverhältnismäßigem Aufwand).*
- **Sicherheits-/Fehlerprotokolle:** berechtigtes Interesse an der
  Sicherheit und Funktionsfähigkeit des Systems (Art. 6 Abs. 1 lit. f
  DSGVO).

## 6. Empfänger / eingesetzte Dienstleister (Auftragsverarbeiter)

| Dienst | Zweck | Sitz |
|---|---|---|
| Supabase Inc. | Datenbank, Login, Dateispeicher (Hosting-Region: EU/Irland) | USA (Auftragsverarbeitungsvertrag erforderlich) |
| GitHub Pages | Ausliefern der Programmoberfläche (keine personenbezogenen Daten fließen über diesen Dienst) | USA |
| OpenStreetMap Nominatim | Umwandlung eingegebener Adressen in Kartenkoordinaten | EU (gemeinnütziger Betreiber) |
| CartoDB (basemaps.cartocdn.com) | Darstellung der Kartenansicht | EU/USA |
| jsDelivr / unpkg (CDN) | Auslieferung technischer Programmbibliotheken | EU/global verteilt |

Es werden **keine** Daten zu Werbe- oder Analysezwecken an Dritte
weitergegeben. Es sind **keine** Analyse-/Tracking-Dienste (z. B. Google
Analytics) im Einsatz.

## 7. Übermittlung in Drittländer

Die Datenbank läuft technisch in einem Rechenzentrum innerhalb der EU
(Irland). Der Betreiber dieses Rechenzentrums, Supabase Inc., ist jedoch
ein US-amerikanisches Unternehmen — ein theoretischer Zugriff durch
US-Behörden (z. B. gestützt auf den US CLOUD Act) kann nicht vollständig
ausgeschlossen werden, auch wenn die Daten selbst in der EU gespeichert
bleiben. *Für die endgültige Fassung: prüfen, ob Supabase Standard
Contractual Clauses (SCCs) anbietet und diese in den
Auftragsverarbeitungsvertrag mit aufnehmen.*

## 8. Speicherdauer / Löschkonzept

- Kontakte ohne aktiv laufenden Vertrag werden nach einem definierten,
  konfigurierbaren Zeitraum automatisch gelöscht (Details siehe
  VVT-Dokument im selben Ordner).
- Tagebucheinträge, Sicherheitsprotokolle und Fehlerprotokolle
  unterliegen eigenen, im VVT dokumentierten Aufbewahrungslogiken.
- Nutzer:innen-Konten bleiben bestehen, solange die Kundenorganisation
  das System nutzt; ein vollständiger Lösch-Mechanismus für einzelne
  Nutzer:innen-Konten ist zum Zeitpunkt dieses Entwurfs noch in
  Vorbereitung.

## 9. Rechte der betroffenen Personen

Jede betroffene Person hat das Recht auf:

- Auskunft über die zu ihrer Person gespeicherten Daten (Art. 15 DSGVO)
- Berichtigung unrichtiger Daten (Art. 16 DSGVO)
- Löschung ihrer Daten, soweit keine gesetzliche Aufbewahrungspflicht
  entgegensteht (Art. 17 DSGVO)
- Einschränkung der Verarbeitung (Art. 18 DSGVO)
- Datenübertragbarkeit (Art. 20 DSGVO)
- Widerspruch gegen eine auf berechtigtem Interesse gestützte
  Verarbeitung (Art. 21 DSGVO)
- Beschwerde bei einer Datenschutz-Aufsichtsbehörde, z. B. der
  Landesbeauftragten für Datenschutz und Informationsfreiheit
  Nordrhein-Westfalen

Anfragen dazu bitte an die oben genannte E-Mail-Adresse.

## 10. Cookies / lokale Speicherung

Das System verwendet technisch notwendige Anmeldedaten (Sitzungsdaten),
um eingeloggte Nutzer:innen zu erkennen. Es werden keine Cookies zu
Analyse- oder Marketingzwecken eingesetzt.

## 11. Änderungen dieser Erklärung

Diese Datenschutzerklärung wird bei inhaltlichen Änderungen der
Datenverarbeitung aktualisiert. Das Datum der letzten Überarbeitung steht
oben im Dokument.
