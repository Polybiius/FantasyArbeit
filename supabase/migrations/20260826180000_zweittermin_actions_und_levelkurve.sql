-- Akquise-Trichter (Verkaufsstatistik-Seite), erster Baustein: neue
-- Aktions-Schlüssel fürs Kanban, damit der Zweittermin sich sauber vom
-- Ersttermin unterscheiden lässt -- Vorgeschichte/Design-Gespräch siehe
-- CLAUDE.md, Abschnitt "Kanban" (Zweittermin/Angebot versendet teilten
-- sich bisher dieselbe Aktion `pitch`).
--
-- Drei neue, rein additive Aktionen (kein bestehender Schlüssel wird
-- geändert/entfernt):
--   - zweittermin_vereinbart (0 XP) -- reine Zähl-Markierung, damit sich
--     "wie oft wurde ein Zweittermin erreicht" aus dem Log ablesen lässt.
--     0 XP bewusst, weil die eigentliche Belohnung für denselben
--     Kanban-Schritt weiterhin über die unveränderte `pitch`-Aktion
--     läuft (15 XP) -- sonst würde derselbe Übergang doppelt kassieren.
--   - zweittermin_wahrgenommen (12 XP) -- Pendant zu termin_wahrgenommen
--     (8 XP), etwas höher bewertet, da ein wahrgenommener Zweittermin
--     eine schwerer erreichte Stufe ist.
--   - zweittermin_nicht_wahrgenommen (-2 XP) -- Pendant zu
--     termin_nicht_wahrgenommen, gleicher Malus.
--
-- Level-Kurve-Neukalibrierung: bisher wurde `termin_wahrgenommen` nur
-- von Hand geloggt (kam praktisch nie vor), ab jetzt automatisch bei
-- jedem Kanban-Übergang vom Ersttermin weiter (siehe Frontend-Änderung
-- an moveKanbanCard()) -- macht daraus eine häufige, regelmäßige
-- XP-Quelle statt einer seltenen Ausnahme. Nutzer-Entscheidung: die
-- automatische XP bleibt bestehen, die Kurve wird stattdessen angepasst,
-- damit "Level 100 nach 10 Jahren" weiter ungefähr stimmt.
--
-- Rechnung (Methodik wie bei Patch 50, siehe HISTORY.md): bisheriges
-- levelBase=5.80/Exponent=1.5 ergibt ein wöchentliches Budget von
-- ~440,6 XP über 10 Jahre. Geschätzte neue automatische XP/Woche, auf
-- Basis der bereits bestehenden Konstanz-Schwelle "5-7 Termine
-- wahrgenommen/Woche" (Mittelwert 6): 6 × 8 XP (termin_wahrgenommen)
-- + ~2,04 × 12 XP (zweittermin_wahrgenommen, geschätzt aus ~40% Erst-
-- zu-Zweittermin-Quote × ~85% Erscheinquote) ≈ 72,5 XP/Woche zusätzlich
-- (+16,5%). Neues levelBase = 5.80 × 1.165 ≈ 6.75 -- hält die
-- Gesamt-XP-Summe bis Level 100 (~229.000) stabil trotz der neuen
-- automatischen Quelle.

begin;

update public.rule_configs
set config = config
  || jsonb_build_object(
    'levelBase', 6.75
  )
  || jsonb_build_object(
    'actions',
    config->'actions' || jsonb_build_object(
      'zweittermin_vereinbart', jsonb_build_object(
        'label', 'Zweittermin vereinbart', 'xp', 0, 'energy', 0, 'skill', 'akquise'
      ),
      'zweittermin_wahrgenommen', jsonb_build_object(
        'label', 'Zweittermin wahrgenommen', 'xp', 12, 'energy', 0, 'skill', 'beziehung'
      ),
      'zweittermin_nicht_wahrgenommen', jsonb_build_object(
        'label', 'Zweittermin nicht wahrgenommen', 'xp', -2, 'energy', 0
      )
    )
  )
where not (config->'actions' ? 'zweittermin_vereinbart');

commit;
