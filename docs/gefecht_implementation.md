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

Der Ausbau nach `1b79203` ist in `gefecht_next_plan.md` nachgeführt. Kontakt und
Angriffsart werden flüchtig erfasst. AT/PA und Ausweichen prüfen tatsächliche DK;
Finte wird nach einer Abwehr nicht in den nächsten Angriff übernommen. Fernkampf
verwendet numerische Entfernungsprofile, bestätigte Situation und Ladezustand.
Ein gewürfelter Schuss hält seine offene Munitionsübernahme bei Schreibfehlern,
statt eine zweite Probe zu verlangen. Sonderangriffe bleiben manuell geprüft.

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
Katalog; die Probe benutzt die gemeinsame Engine. Zauber werden zu Beginn
einmal ausgewertet; ihre Wirkung tritt nach der bestätigten Dauer ein.
Liturgieprobenzeitpunkte werden anhand des konkreten Profils bestätigt. KaP/AsP-Kosten und Wirkungen
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

### Waffen-SF und Ziehen (Folgepakete 3a/3b)

Defensiver Kampfstil und talentgebundene Manöver werden über stabile IDs gelesen.
Waffenmeister reduziert den bestätigten Manöverzuschlag automatisch einmal.
Halbschwert benötigt die bestätigte Führung; Klingenwand/-sturm werden nicht als
einfache Einzelprobe abgewickelt. Bekannte Kataloglängen über zwei Schritt und
improvisierte Waffen sperren Umwandlungen; fehlende Profile bleiben manuell.
Das Ziehpopup fragt Trageposition, Griffbereitschaft und freie Hände.
Schnellziehen vom Gürtel/Arm/Brust bezahlt eine freie Marke; Rücken und Schild
erhalten die WdS-Dauer. Schilde vom Rücken sind eigene Nebenhandhandlungen.

### Zauber und Karma (Folgepakete 4a–4c)

Die frühere Endprobe für Zauber ist ersetzt: Ergebnis am Anfang einfrieren,
Dauer bezahlen, dann Kosten/Folgen übernehmen. Erfolg bindet volle Dauer;
Misserfolg halbe Dauer aufgerundet, mit Zauberkontrolle eine Aktion.
Störung verwendet Selbstbeherrschung mit Konzentrationsstärke; zusätzliche
Auswirkungen auf ZfP* bleiben ausdrücklich am Spieltisch geprüft.
Mirakel/Liturgien nutzen die Hausregel-Kulteigenschaften und separate Profile.
Liturgiezeitpunkt, konkrete Dauer und permanente Kosten sind manuell bestätigt.
Der Wirkabschluss verwendet den vorhandenen frischen Zustandsweg und bestehende
Armatrutz-/Attributo-Dialoge. Kosten und unterstützte Effekte sind ein Write;
Wiederholung einer übernahme erzeugt keinen zweiten Wurf. Separate Kostenübernahme
im Ressourcendialog merkt sich die Buchung bis zum Folgenabschluss.
Alle neuen Wirk-, Wiederholungs- und Mirakelbonusdaten bleiben flüchtig.

## Hauptwaffe und Nebenhand

Das Ausrüstungspopup bietet beide Handrollen, Waffen in beiden Händen und
Schilde/Parierwaffen in der Nebenhand. Leer führt über bestätigtes Wegstecken.
Ziehhandlungen speichern ihre Zielhand flüchtig und wechseln erst beim frischen
Abschluss. Doppelbelegung, Zweihandkonflikte und geänderte Ziele sperren sichtbar.

Abwehrdialoge zeigen das verwendete Kampfmittel: Schild vor zulässiger
Parierwaffe vor Hauptwaffe. Hauptwaffen- und Parierwaffenparade sind getrennt;
Nebenhandwaffen verwenden ihre eigene Vorschau einschließlich Falsche-Hand-Mali.
Schild-eBE ist enthalten, der AT-WM einer Parierwaffe wirkt nicht auf Haupt-AT.
Zusatzattacken/-paraden zeigen das konkrete Mittel und den berechneten Zielwert.
Die Probeengine erhält AT/PA statt einer allgemeinen Eigenschaftsprobe. Das
flüchtige Rundenmodell merkt Ausrüstungspaar, reguläres Abwehrmittel und Ansage.
Eine Zusatzmarke steht nur nach der passenden regulären Aktion mit derselben
Ausrüstung zur Verfügung; Schild-/Parierwaffenparaden benötigen jeweils vorher
dieselbe Abwehrart. Rundenwechsel löscht die Bindung, erhält laufende Handlungen.
SK-II-Zusatzparaden bezahlen keine reguläre Dauerhandlung. Zwei PW-Paraden
bleiben ohne Ansage und Umwandlung. Doppelangriff/geteilte Pools bleiben manuell.

WdS 71 (DSA MCP 7015–7017), Errata WdS S.3–4 (25631), geprüft 2026-10-02:
Schildführung sperrt einschlägige Manöver auch mit der Hauptwaffe; Finte/Ausfall
erhalten den belegten Zusatz, kleine Schilde die Finte-Ausnahme. Schildparaden
fragen je Angriff, ob der Schild-WM wirkt; bei Kettenwaffe/-stab oder Peitsche
entfällt nur der WM, nicht SF/Heldenanteile. Fernkampf-Munitionsabschluss verwendet
die gewählte Waffen-ID auch für eine normale Nebenhandwaffe.

Manuell bleiben improvisierte bzw. zugleich als Schild/Parierwaffe verwendete
Sonderprofile und Bruchtests. Tod von Links wird bei fehlendem Angriffsprofil des
bestehenden Parierwaffen-Eintrags erklärt gesperrt; es wird kein Hauptwaffen-AT
als Ersatz erfunden. Ein vollständiges eigenes Angriffsprofil erfordert eine
Waffe mit Talent und Waffenwerten im vorhandenen Waffeninventar.
