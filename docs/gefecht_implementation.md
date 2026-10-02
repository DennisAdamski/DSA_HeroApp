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
- Einstieg und responsive Ansicht implementiert. Die Rundenleiste läuft über
  die ganze Breite; Haltung, Gegner und DK stehen neben der direkten Ansage.
  Manöver sind suchbar und ihre Liste bleibt in der Höhe begrenzt. Auf dem
  Handy stehen Angriff, Manöver und Verteidigung vor Durchhalten.
- Ausrüstung und Fachdialoge verbunden: verzögerter Waffenwechsel, frische
  Slot-Auswahl, Rüstungskorrektur mit Konfliktprüfung, Schaden, Ressourcen,
  Wunden, Effekte und das bestehende Protokoll.

## Bedienung und bewusste manuelle Abläufe

„Gefecht läuft“ öffnet die erhaltene Sitzung ohne neuen INI-Wurf. Reguläre,
freie und Zusatzmarken bleiben getrennt. Die hohen INI-Boni werden bei der
ersten verbrauchten Marke fixiert. Zusätzliche Waffenaktionen benötigen eine
tatsächlich ausgeführte passende reguläre Aktion und eine verfügbare
Ausrüstungsoption. Schildkampf II erlaubt die zweite gewöhnliche Schildparade
nur nach einer ersten Schildparade; längere Handlungen verwenden dieses Budget
nicht. Umwandlung wird verbindlich bestätigt, Korrekturen sind separat.

Manöver zeigen Katalogtext, Voraussetzungen und Zielwert. Eindeutig bezifferte
Katalogzuschläge werden vorbelegt, variable Zuschläge und nicht automatisierte
Kosten/Folgen werden bestätigt. Bekannte Lern-, Talent-, Waffen- und
Gegnersperren (einschließlich Hammerschlag) bleiben verbindlich. Die vollständige
Manöverwirkung am Gegner wird nicht simuliert. Abwehrmanöver verbrauchen PA;
Gegenhalten verwendet dabei AT ohne hohen INI-Paradebonus (WdS 69–70, DSA-MCP).
Aktuelle Kopf-INI-Verluste kommen zusätzlich zu den bereits berechneten Wundmali
zur Anwendung. Waffenmeister-Erleichterungen werden ausdrücklich im Dialog zur
Prüfung genannt; zusätzliche freigegebene Manöver erweitern die Waffenfreigabe.

Orientieren wird regelgeführt: zwei Aktionen und IN-Probe mit Kriegskunstbonus,
mit Aufmerksamkeit eine Aktion ohne Probe. Das Ergebnis übernimmt INI-Maximum
und rückgewinnbare Kampfverluste automatisch. Position + Orientieren nach freiem
Ausweichen bezahlt gemäß Hausregel eine Aktion. Ungeklärte Korrekturen müssen
zuerst zugeordnet werden; Wund-/Zaubermali bleiben erhalten. Freies
Ausweichen verliert vier INI, bei Erfolg wird Position erforderlich; gezieltes
Ausweichen berücksichtigt DK und verliert bei Misslingen zwei INI. Rückweichen
und weitere Gegnerfolgen bleiben manuell.

Zauber und Liturgiekenntnis stammen aus gelernten Heldendaten und dem aktuellen
Katalog; die Probe benutzt die gemeinsame Engine. Längere Zauber können erst am
Ende ihrer bestätigten Dauer ausgewertet werden. KaP/AsP-Kosten und Wirkungen
werden über die vorhandenen Ressource-/Effektdialoge geführt. Fehlende Katalog-
oder Probeninformationen erhalten einen manuellen Zielwert, keine angenommene Formel.

## Verifikation

Regel-, State-, Probe- und Widgettests prüfen Umwandlung, hohe INI, Haltung,
Ausweichvarianten, Zusatzaktionen, Schildparaden, bekannte Manöversperren,
Aufmerksamkeit/Klingentänzer, Abbruch, doppelte Ergebnisbuchung und Navigation.
Die Ausrüstungstests verwenden den echten Bestandsadapter und einen zweiten
Schreibweg: verschobene Slots, neue fremde Daten und unbekannte Felder bleiben
erhalten. Bei Speicherfehlern bleiben Abschluss und Aktionsmarke offen.

Das Raster prüft 390/820/1200/1440 Pixel in Hell/Dunkel mit echten Karto-Schriften,
hoher INI und offenen Aktions-/Ausrüstungspopups. Aufnahmen lassen sich reproduzieren:

```powershell
flutter test test/ui2/spielen/gefecht_visual_test.dart --dart-define=GEFECHT_SCREENSHOT_DIR=<Verzeichnis>
```

Stand der Abnahmeprüfung: `flutter analyze` ohne Befund, 332 relevante Tests
bestanden, zusätzlich acht Rastertests mit 24 gerenderten Zuständen. Bestehende
Kampfverwaltung und bisherige Probendialoge sind in der Regression enthalten.

Die Abschlusskorrektur trennt die zusätzliche SK-II-Schildparade von regulären
Reaktionen: Sie kann weder Position noch gezieltes Ausweichen bezahlen. Zauber
werden bei vollständig bezahlter Dauer sofort genau einmal ausgewertet; Abbruch
vor der Auswertung verbraucht auch bei zwei Aktionen keine Marke. Beide Fälle
sind durch zuerst fehlschlagende Regressionstests abgesichert.

Abschlussreview vom 2. Oktober 2026: drei relevante Befunde behoben. Zusätzlich
zu Budget und Zauberabschluss schützt eine gemeinsame Sperre bestehende
Resthandlungen vor neuen kurzen/längeren Zaubern und manuellen Aufträgen. Nur
der ausdrückliche Fortsetzen-Pfad darf die bestehende Handlung weiterführen.
Regel-/Ablaufregressionen einschließlich verzögerter Zauberproben und Abbrüchen
bestehen; `flutter analyze` meldet keine Probleme. Die dokumentierten manuellen
Grenzen bleiben Bestandteil dieser ersten Version.
