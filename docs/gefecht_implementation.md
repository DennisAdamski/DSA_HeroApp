# Erste Flutter-Version des Gefechts

Verbindliche Grundlage: `mockups/gefecht-plan.md` und der freigegebene
Umsetzungsplan vom 1. Oktober 2026. Die bisherige Kampfverwaltung bleibt erhalten.

## Teilpakete

1. Flüchtiger Zustand je Held und gemeinsame Freigaben unter `rules/derived`.
2. Einmalige Gefechtsproben über die gemeinsame Engine und das Protokoll.
3. Einstieg im Spielen-Bereich, responsive Gefechtsansicht, Aktionsdialoge.
4. Eigenes Ausrüstungspopup, verzögerte Waffenwechsel, bestehende Fachdialoge.
5. Regel-, Ablauf-, Speicher- und Layoutprüfungen sowie Abschlussreview.

## Grenzen der Automatisierung

Keine globale Phasenuhr und keine Speicherung laufender Gefechte. Ansagezeitpunkt,
Gegnervoraussetzungen, Zusatzaktionen, Ziehkontext und nicht abbildbare Manöver,
Magie- und Karmaregeln müssen ausdrücklich geprüft werden. Bekannte Sperren
bleiben dabei verbindlich. Dauerhafte Änderungen verwenden die bestehenden
Schreibwege auf dem frisch geladenen Helden.

Aufmerksamkeit übernimmt den vorhandenen festen INI-Wurf (einschließlich
Klingentänzer) und überspringt den Dialog. Das ist die gewünschte App-Regel;
WdS gewährt das Maximum erst beim Orientieren.

## Fortschritt

Die Umsetzung und ihre Prüfungen werden je Teilpaket hier nachgeführt.

- Zustand/Freigaben und einmaliger Probe-Modus implementiert. Erste Tests
  decken Umwandlung, INI-Fixierung, Ausweichsperren, SK-II-Paraden, Abbruch,
  Doppelbuchung und die bisherigen Probeaufrufer ab.
