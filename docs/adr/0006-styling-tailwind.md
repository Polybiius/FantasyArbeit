# ADR-0006 — Styling-Grundlage: Tailwind (ohne Preflight) + shadcn-Stil

**Status:** akzeptiert (2026-09-03)
**Bezug:** ADR-0001 · ADR-0005 (Radix/shadcn im "Code gehört euch"-Modus) · S8 aus dem Fahrplan

## Kontext

Der Plan sah einen Praxis-Test vor Festlegung vor (S8): dieselbe
Statistik-Kachel einmal mit Tailwind-Utilities, einmal mit eigenem CSS
(CSS-Modul) auf dem bestehenden Design-Token-System bauen und
vergleichen. Beide Varianten wurden gebaut und gegen alle drei
Klassenfarben (Zauberer/Krieger/Schütze) verifiziert — **pixelidentisch**,
weil das bestehende Theme-System bereits vollständig über CSS-Variablen
läuft, die beide Varianten gleich lesen.

Ein Ein-Komponenten-Test kann Tailwinds eigentlichen Vorteil aber nicht
zeigen — der liegt nicht im Einzelergebnis, sondern in der Wirkung über
viele Komponenten und (bei uns: viele unabhängige KI-Sitzungen ohne
gemeinsames Gedächtnis) hinweg:

1. **shadcn/ui setzt Tailwind voraus.** ADR-0005 (Design-Ebene) legt
   bereits fest, dass die Optik über Radix/shadcn im "Code gehört
   euch"-Modus entstehen soll, um das dokumentierte "sieht nicht wie
   08/15-App aus"-Ziel zu erreichen. Jede shadcn-Komponente kommt fertig
   in Tailwind-Klassen — ohne Tailwind müsste jede künftig übernommene
   Komponente (Dialog, Dropdown, Kalender-Picker) von Hand zurück in
   eigenes CSS übersetzt werden, dauerhaft, bei jeder einzelnen.
2. **Trainingsdaten-Dichte**, dasselbe Argument wie React vs. Vue
   (ADR-0001), nur schärfer: Tailwind ist der de-facto-Standard in
   praktisch jedem aktuellen React-Projekt/-Beispiel/-Tutorial. Reines
   Custom-CSS ist die Nische.
3. **Design-System-Drift-Schutz.** Das reale Risiko dieses Projekts ist
   nicht "ein Entwickler-Team vergisst eine Konvention", sondern "eine
   neue KI-Sitzung ohne Kontext der vorherigen erfindet leicht
   abweichende Werte" — genau das Muster, das im Projekt bereits mehrfach
   strukturelle statt Prosa-Lösungen nötig gemacht hat (`html`-Tag statt
   "bitte immer escHtml() benutzen", `withClickGuard` statt "bitte immer
   deaktivieren"). Tailwinds Config ist eine harte Grenze: nur Werte aus
   dem Theme sind ohne Weiteres erreichbar, ein Ausreißer
   (`bg-[#123456]`) fällt im Diff sofort auf.

## Entscheidung

**Tailwind v4** (`4.3.3`, exakt gepinnt) als Utility-Schicht für den
React-Teil, **kombiniert mit shadcn-Stil-Komponenten** (unbestylte
Radix-Primitive + Tailwind-Klassen, ins eigene Projekt kopiert, nicht als
fertiges Theme-Paket).

**Zwei technische Einschränkungen, beide beim Praxis-Test entdeckt, nicht
vorher absehbar:**

1. **Preflight-Reset wird NICHT eingebunden.** Preflight setzt über
   ungescopte Selektoren (`*, button, input, h1..h6, ...`) einen globalen
   Reset. Da `assets/app.css` in der produktiven `index.html` in
   DERSELBEN Kaskade wie die komplette, gewachsene Vanilla-CSS lädt
   (React und Vanilla-Seiten sind DOM-Geschwister, kein iframe/Shadow-DOM),
   würde Preflight jeden Vanilla-Button/-Input/-Überschrift in Kanban,
   Kontakte, Kalender usw. mit-zurücksetzen — nicht nur die React-Teile.
2. **Jede Utility-Klasse bekommt zwingend das Präfix `tw:`**
   (`prefix(tw)`), UND das automatische Scannen nach Kandidaten-Klassen
   ist auf `src/**/*.{ts,tsx}` eingegrenzt (`@source`, `source(none)` auf
   dem Utilities-Import). Grund, empirisch verifiziert: Tailwinds
   Standard-Erkennung durchsucht sonst das GESAMTE Repo (respektiert nur
   `.gitignore`) nach Text, der wie eine Utility-Klasse aussieht — ein
   Beispielwert aus diesem ADR-Text (`bg-[#123456]`) landete beim ersten
   Testlauf als echte, ausgelieferte Klasse im Bundle, ebenso `flex`/
   `grid`/`block`/`static`/`inline` aus `style={{display:'flex'}}`-artigen
   Inline-Style-Strings in eigenem React-Code (Tailwinds Scanner ist reine
   Text-Erkennung, kein CSS-/JS-bewusstes Parsen). `index.html` hat
   bereits eine eigene `.grid{display:grid;grid-template-columns:1.1fr
   1fr}`-Regel — Tailwinds gleichnamiges `.grid{display:grid}` hätte bei
   gleicher Spezifität je nach Ladereihenfolge in dieselbe Regel
   geschrieben. **Präzisierung nach unabhängiger Zweitmeinung
   (2026-09-03):** Da beide Regeln nur `display:grid` gemeinsam haben
   (Tailwinds `.grid` setzt sonst nichts), wäre `grid-template-columns`
   dabei NICHT verloren gegangen — die ursprüngliche Formulierung
   ("unsichtbarer Layout-Bug") war dramatischer als die tatsächliche
   Gefahr. Die Vorsichtsmaßnahme bleibt trotzdem richtig: die Zweitmeinung
   hat alle 442 in `index.html` vorkommenden Klassennamen einzeln gegen
   Tailwind kompiliert — `.grid` ist die **einzige** Kollision im
   gesamten Bestand, aber zukünftige Vanilla-Änderungen könnten jederzeit
   eine zweite erzeugen. Das Präfix macht eine Namenskollision mit
   bestehendem UND künftigem Vanilla-CSS strukturell unmöglich, statt
   sich auf "kein Vanilla-Name kollidiert zufällig" zu verlassen.

Einbindung (`src/styles/tailwind.css`):

```css
@import 'tailwindcss/theme.css' prefix(tw);
@import 'tailwindcss/utilities.css' source(none) prefix(tw);
@import './tokens.css';

@source '../**/*.{ts,tsx}';

@theme {
  /* Tailwinds eigene Standardpalette (color-red-500 usw.) UND
     Standard-Radien/-Schatten schließen -- sonst bleibt sie trotz
     eigenem Mapping zusätzlich erreichbar. */
  --color-*: initial;
  --radius-*: initial;
  --shadow-*: initial;

  --color-panel-2: var(--panel-2);
  /* … Rest der bestehenden Tokens, siehe src/styles/tailwind.css */
}
```

**Nachtrag nach unabhängiger Zweitmeinung (2026-09-03):** die erste
Fassung dieses `@theme`-Blocks bildete nur 13 der 22 Basis-Tokens ab —
`--danger`/`--success`/`--amber`/`--shadow-rest`/`--shadow-raised`/
`--radius-pill` fehlten, während Tailwinds komplette eingebaute
Standardpalette (`tw:bg-red-500`, `tw:shadow-xl`, `tw:rounded-3xl`, ...)
weiterhin klaglos funktionierte. Das war das genaue Gegenteil des unter
"Design-System-Drift-Schutz" oben beschriebenen Ziels — eine künftige
Sitzung hätte zur bequemen Tailwind-Standardfarbe statt zum eigenen
Token gegriffen, unauffällig im Diff. Fix: die fehlenden sechs Tokens
ergänzt UND `--color-*`/`--radius-*`/`--shadow-*` vor der eigenen Liste
auf `initial` gesetzt, damit ausschließlich die neun eigenen Farben, fünf
Radien und zwei Schatten erreichbar sind. Verifiziert: alle neun eigenen
Werte generieren korrektes CSS, `tw:bg-red-500`/`tw:rounded-3xl`/
`tw:shadow-xl` erzeugen danach nichts mehr.

Eine Utility-Klasse im JSX sieht dadurch so aus: `className="tw:flex
tw:bg-panel-2 tw:rounded-lg"`. Verifiziert: `--tw-color-panel-2:
var(--panel-2)` wird korrekt erzeugt, der Klassenfarbwechsel
(`applyClassTheme()`) wirkt dadurch unverändert auch auf Tailwind-Klassen.

**CSS-Variablen bleiben die Quelle der Wahrheit** (unverändert zu ADR-0002):
`applyClassTheme()` in der Vanilla-`index.html` schreibt weiterhin die
9 Theme-Variablen zur Laufzeit auf `document.documentElement`. Tailwinds
`@theme`-Block ist nur eine zweite, für Utility-Klassen nutzbare
Schreibweise derselben Werte (`--color-arcane: var(--arcane)` usw.) —
kein Duplikat, keine zweite Farbquelle. Ein Klassenfarbwechsel wirkt
dadurch automatisch auch auf jede Tailwind-Klasse, ohne Re-Render.

**Radix-Primitive** kommen unabhängig davon zum Einsatz, sobald echte
interaktive Bausteine (Dialog, Dropdown, Combobox) gebraucht werden —
das ist eine Frage des Verhaltens, nicht des Stylings, und von dieser
Entscheidung unberührt.

## Konsequenzen

**Positiv:** shadcn-Komponenten lassen sich ohne Übersetzungsschritt
übernehmen; Utility-Klassen sind im JSX selbst sichtbar (Code-Review
sieht das Ergebnis direkt im Diff, kein Sprung in eine zweite Datei);
tote Utility-Klassen verschwinden automatisch (Tailwind scannt nur
tatsächlich genutzte Klassen); harte Werte-Grenze schützt gegen Drift
über viele getrennte KI-Sitzungen hinweg.

**Negativ:** zusätzliche Build-Abhängigkeit mit realer Versions-Historie
(v3→v4 war ein Breaking Change, im Fahrplan bereits als Risiko markiert)
— durch exaktes Pinnen (`4.3.3`, `package.json`) eingehegt. `@theme`-
Mapping muss bei jeder neuen Basis-Token-Ergänzung in `tokens.css`
manuell nachgezogen werden (zwei Dateien statt einer) — akzeptabel, da
Tokens selten neu hinzukommen (aktuell 9 Theme-Variablen, historisch
stabil). Jede Tailwind-Klasse braucht das `tw:`-Präfix — minimal mehr
Tipparbeit, dafür strukturell kollisionsfrei mit der bestehenden
Vanilla-CSS, siehe oben.

**Verbindliche Regel für neuen React-Code ab jetzt:** Tailwind-Utilities
IMMER mit `tw:`-Präfix schreiben (`tw:flex`, nicht `flex`) — das Präfix
ist keine Stilfrage, sondern der einzige Schutz gegen Namenskollisionen
mit der noch aktiven Vanilla-CSS.

**Kleine Ehrlichkeits-Präzisierung, aus der Zweitmeinung:** sobald
irgendeine echte Utility-Klasse benutzt wird, schreibt Tailwind zusätzlich
einen kleinen `@layer properties`-Block, der auf dem Universal-Selektor
(`*, :before, :after, ::backdrop`) sitzt — er registriert dort aber
ausschließlich eigene `--tw-*`-Hilfsvariablen (für Transform/Filter-
Verkettung), keine sichtbaren Stile. Verifiziert: `index.html` benutzt
keine einzige `--tw-*`-Variable, der Block ist inert. "Strukturell
unmöglich" (oben) gilt für alle sichtbaren Stile; dieser eine interne
Block ist die einzige, harmlose Ausnahme von "nichts Ungescoptes".

**`clsx`/`class-variance-authority`/`tailwind-merge`** wurden im selben
Zug als exakt gepinnte Abhängigkeiten installiert (`package.json`),
werden aber in diesem Schritt noch nirgends verwendet — sie sind die in
der shadcn-Doku übliche Werkzeug-Kombination für Komponenten-Varianten
und kommen erst mit den ersten echten shadcn-Bausteinen in Block 4 zum
Einsatz, keine vergessene Altlast.

**Bewusst NICHT Preflight** — siehe oben, dauerhafte Einschränkung, nicht
nur für den Umbau: solange React-Seiten und Vanilla-Seiten im selben
Dokument koexistieren (bis "Fertig"-Definition, `docs/migration-status.md`),
bleibt Preflight tabu. Nach vollständigem Abschluss der Migration (kein
Vanilla-CSS mehr im Dokument) könnte Preflight erneut bewertet werden —
kein aktueller Bedarf, da das bestehende `tokens.css`/Vanilla-CSS bereits
einen eigenen, funktionierenden Basis-Reset mitbringt.

## Verworfene Alternativen

- **Eigenes CSS (CSS-Module) auf den bestehenden Tokens** — funktioniert
  nachweislich (Spike verifiziert, pixelidentisch zu Tailwind bei diesem
  Test), aber inkompatibel mit dem bereits beschlossenen shadcn-Modell
  (ADR-0005) ohne dauerhaften Übersetzungsaufwand pro Komponente. Bleibt
  die richtige Wahl für sehr spezielle Fälle (`<canvas>`-Sprite-Rendering,
  komplexe SVG-Zeichnungen), die ohnehin nie Utility-Klassen nutzen würden.
- **Tailwind MIT Preflight** — verworfen wegen des dokumentierten
  Kaskaden-Konflikts mit der noch aktiven Vanilla-CSS.
- **Fertiges Komponenten-Theme (Material UI, Ant Design, Chakra)** —
  bereits in der ursprünglichen Planung verworfen (ADR-0005/Design-Ebene):
  bringt die sofort wiedererkennbare "Standard-App"-Optik mit, die der
  Nutzer explizit ablehnt.
