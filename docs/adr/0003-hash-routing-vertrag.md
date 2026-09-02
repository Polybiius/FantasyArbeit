# ADR-0003 — Hash-Routing als stabiler, dokumentierter Vertrag

**Status:** akzeptiert (2026-09-02)
**Bezug:** ADR-0001 · bestehendes Prinzip "Echte Seiten statt Modals für Datensätze"

## Kontext

Die App nutzt seit Langem Hash-Routing (`#kontakt/<uuid>`,
`#tagebuch/<monat|woche|tag>/<YYYY-MM-DD>`, plus einfache Seitennamen).
Das ist **kein Zufall**:

- **GitHub Pages** kann kein Server-seitiges Rewrite — pfad-basiertes
  Routing (`/kontakt/123`) liefert bei direktem Aufruf/Reload einen 404.
  Hash-Routing (`/#/kontakt/123`) umgeht das komplett.
- Die Deep-Links sind bewusst **bookmark-fähige CRM-Datensatz-URLs**
  (Rechtsklick → neuer Tab muss funktionieren, siehe Erinnerung
  `feedback_real_pages_over_modals_for_records`).
- `updateCalendarHash()` schreibt den Kalender-Zustand per
  `history.replaceState()` (kein neuer History-Eintrag pro Klick).

Risiko: eine künftige Sitzung könnte beim "Aufräumen" auf `BrowserRouter`
umstellen wollen und damit sowohl die 404-Vermeidung als auch bestehende
Lesezeichen brechen. Zusätzlich wäre der Vite-`base`-Pfad bei
`BrowserRouter` in einem GitHub-Pages-Unterordner ein garantierter
Stolperstein (bei `HashRouter` unkritisch).

## Entscheidung

Hash-Routing bleibt, und wird als **expliziter Vertrag** festgehalten:

- React nutzt `HashRouter` von React Router.
- Die bestehenden Hash-Formate (`#<seite>`, `#kontakt/<uuid>`,
  `#tagebuch/<mode>/<date>`) bleiben **wort-kompatibel** — ein alter
  Lesezeichen-Link muss nach der Migration exakt dieselbe Seite öffnen.
- Ein Umstieg auf `BrowserRouter` / pfad-basiertes Routing ist nur über
  ein neues ADR zulässig, das GitHub-Pages-404 und Lesezeichen-Bruch
  ausdrücklich adressiert.
- Die Regressions-Suite prüft Deep-Link-Reload-Persistenz (bereits
  vorhanden) — diese Checks bleiben verbindlich.

## Konsequenzen

**Positiv:** Kontinuität; keine 404-Klasse; bestehende Lesezeichen und
geteilte Links überleben; `base`-Pfad-Stolperstein entfällt.

**Negativ:** URLs mit `#` sehen für manche "weniger sauber" aus — bewusst
in Kauf genommen. Analytics/Server-Logs sehen den Hash-Teil nicht
(irrelevant, kein serverseitiges Tracking im Projekt).

## Verworfene Alternativen

- **`BrowserRouter` + 404-Fallback-Trick** (404.html, das auf index
  weiterleitet) — fragil, doppelte Auslieferung, Flackern beim
  Erstaufruf.
- **Eigene Landing-/Marketing-Seite mit sauberen Pfaden** — bleibt ein
  separates, kleines Projekt (Business-Fahrplan Phase 4), keine Vorgabe
  fürs CRM.
