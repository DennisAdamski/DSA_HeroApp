# Gefecht: nächste Ausbaustufe ab `1b79203`

## Verbindlicher Auftrag

Erlaubte Aktionen zuverlässiger erkennen, fehlenden Kontext gezielt erfragen
und bestätigte Handlungen einschließlich Dauer, Probe, Kosten und Folgen
abwickeln. Aufmerksamkeit-Start (einschließlich Klingentänzer), kompakte
Rundenleiste, direkte Umwandlung, Ausrüstungspopup, einmalige Proben und
geschützte Handlungen bleiben erhalten. Keine neue Gefechtspersistenz.

## Pakete und Abnahme

- [x] 1a Orientieren: IN + floor(max(0, Kriegskunst-TaW)/2), zwei Aktionen;
  Aufmerksamkeit eine ohne Probe. Liegend/bei Einschränkung sperren.
  Kampfverluste zurückgewinnen, Wund-/Zauberverluste und ungeklärte Korrekturen
  erhalten. INI-Ergebnis automatisch übernehmen; maximale 12 bei Klingentänzer
  bleibt ausdrücklich App-Konvention. Tests: TaW 0/1/2/5, Erfolg/Misserfolg,
  Abbruch, Doppelcallback, Restdauer, frischer Held, fixierter INI-Bonus.
- [x] 1b Position + Orientieren: eine reguläre Aktion nach freiem Ausweichen;
  Position beendet Desorientierung auch bei gescheiterter IN-Probe. Zusatzparade
  kann die Handlung nicht bezahlen. Tests: beide Ergebnisse, Budget, Abbruch.
- [x] 2a Flüchtiger benannter Gegnerkontakt; tatsächliche DK, gegnerische
  Angriffsdaten, Finte und besondere Verbote nur bei Abhängigkeit abfragen.
  Standardwerte sind keine Bestätigung. Kontaktwechsel löscht Angriffsdaten.
  AT-/PA-DK-Mali, einfache/doppelte Ausweichmali, explizite Distanzänderungen
  ohne Schaden. Tests: alle DK, Mehrfach-DK, Finte einmal, Hausregelausnahmen,
  Kontaktwechsel, unbekannter Kontext und gesperrte Voraussetzungen.
- [x] 2b Fernkampf: Entfernung/Entfernungsband, Größe, Bewegung, Sicht/Deckung,
  Getümmel, Ladezustand/Munition; Getümmel-SF und Kontrollbereichshinweis.
  Tests: Bandgrenzen, fehlendes Profil, leere Waffe, frische Munitionsbuchung.
- [x] 3a Waffen-SF: Defensiver Kampfstil, Umwandlungsverbote/-ausnahmen,
  Waffenmeister, Zusatzaktionen und bestätigte Halbschwertführung. Klingenwand
  und Klingensturm weiterhin manuell, keine vorgetäuschte Einzelprobe.
  Tests: SF aktiv/inaktiv, Ansagezeitpunkt, Halbschwert-DK, Zusatzbudgets.
- [x] 3b Ziehen: Scheide/Griffbereitschaft/Handbelegung statt pauschaler Dauer.
  Schnellziehen bezahlt freie Marke; Schild vom Rücken eigene Handlung.
  Ungewöhnliche Wechsel manuell; Rüstung bleibt Statuskorrektur.
  Tests: Kostenmatrix, freie Marken, Resthandlung, Slot-ID, Schreibfehler.
- [x] 4a Zauberprobe zu Beginn einfrieren, Wirkung erst nach Dauer. Scheitern
  nach halber Dauer (angebrochene Aktionen aufrunden, App-Konvention), mit
  Zauberkontrolle eine Aktion. Störungen über Selbstbeherrschung führen.
  Tests: Dauer 1/2/5, beide Ergebnisse, SF, Störung, Navigation, Abbruch.
- [x] 4b Kosten/Folgen: bestehende Ressourcen-/Effektdialoge vorbelegen;
  frischer gemeinsamer Zustandsvorgang für unterstützte Folgen. Wiederaufnahme
  nach Fehler ohne erneuten Wurf/Verbrauch; unzureichende Energie nicht klemmen.
  Tests: halbe Kosten aufrunden, Paralleländerung, Schreibfehler, Doppelbuchung.
- [x] 4c Mirakel/Liturgien getrennt führen, gottspezifische Probe, Gradkosten,
  Wiederholung derselben Handlung binnen bestätigter SR (+3 je Fehlschlag).
  Tests: Gottheiten, Grade I–VI, Erfolg/Scheitern, SR-Grenze, einmaliger Bonus.
- [x] Mockup: Orientierung, bedingte Kontextfragen, Ziehkontext, eingefrorene
  Probe/Restdauer, Störung/Abbruch, Abschluss und erneute Übernahme.

## Schnittstellen

`Gefechtskontext` hält unbekannte Werte explizit und trennt Kontakt- von
Angriffsdaten. `Gefechtspruefung` liefert Budget, Modifikatoranteile, fehlende
Eingaben und manuelle Prüfgründe. Typisierte Handlungen halten Probe, Restdauer
und Abschlussstatus. Regelmodule bleiben rein; UI/Provider rechnen nicht.
Bekannte Widersprüche sperren, fehlende Angaben verlangen Prüfung; Hinweise
auf automatisch behandelte Folgen allein verhindern kein „bereit“.

## DSA-MCP-Quellen (geprüft am 2. Oktober 2026)

| Thema | Quelle / MCP-Chunk |
| --- | --- |
| Orientieren | WdS S. 56, 6973 |
| Ziehen | WdS S. 55, 6972 |
| Position + Orientieren, hohe INI | Erweiterung und Überarbeitung S. 2–3, 25817–25818 |
| DK und Distanzänderungen | WdS S. 80, 7040–7041; Hausregel 25818 |
| Ausweichen | WdS S. 67–68, 7006–7007 |
| Defensiver Kampfstil | WdS S. 74, 7025 |
| Zusatzaktionen/Halbschwert/Verbote | Errata WdS, 25631–25632 |
| Zauber: Zeitpunkt, Scheitern, Störungen, Kosten | WdZ S. 13–17, 4972–4976, 4981–4982 |
| Mirakel/Liturgie: Grad, Kosten, Dauer | Liber Liturgium S. 9–14, 25843–25845 |
| Karmale Modifikatoren | Liber Liturgium S. 17–19, 25847 |
| Gottspezifische Probe | Erweiterung und Überarbeitung S. 25–26, 25835 |
| Ansage/Phasen | WdS S. 82, 7046; Errata 25632 |

Seiten entsprechen dem MCP-Index. Aufmerksamkeit-Maximum beim Start ist eine
gewünschte App-Abweichung; WdS gewährt das Maximum erst beim Orientieren.
Offen/manuell bleiben AW-Mirakelbonus, Bonusrundung, Liturgieprobenzeitpunkt,
karmale Unterbrechung, permanente Kosten, unbestätigte Repräsentationsausnahmen,
Patzer und fremde Zielwirkungen. Kein vollständiger neuer Liturgiekatalog.

## Prüfungen und Folgepaket

Pro Paket: zuerst Regression, dann Umsetzung, `flutter analyze`, relevante
Tests, Dokumentationsprüfung und gezielter Commit. Layout 390/820/1200/1440 in
Hell/Dunkel; frische Schreibwege mit Zwischenänderungen, unbekannten Feldern,
stabilen IDs und Fehlern. Doppel-Tap-Nachweis ohne verdeckte zweite Schaltfläche.

Globale Initiativphasen sind ein eigenes Folgepaket mit gemeinsamer flüchtiger
Teilnehmerliste, Gleichständen, sofortigen INI-Änderungen, Verzögerung und INI−8.
Bis dahin Phasenzeitpunkte manuell bestätigen; lokal entscheidbare negative
INI-Budgetgrenzen schon jetzt prüfen. Keine Persistenz und eigene Bedienabnahme.

## Fortschrittsnachweis

Ausgangsstand: Analyse ohne Befund, 71 gezielte Tests bestanden.

1a/1b: Regeln und Orientierungsdialog mit später einmaliger Probe integriert;
32 Regel-/State-/Layoutprüfungen und Analyse bestanden, Commit `456c332`.
2a/2b: DK-Matrix, freies Ausweichen, Finte, Kontaktwechsel, Schusskontext und
frische Munitionsübernahme integriert. Größe/Bewegung/Sicht/Deckung bleiben ein
bestätigter Situationszuschlag; kein zweiter vollständiger Fernkampfrechner.
Ruling: frei benannte Entfernungsbänder werden nicht als Zahlen interpretiert.

### Wirkpfad: Abgrenzung der Automatisierung

Zauber erhalten eine Startprobe und bestätigte Aktionsdauer. Niedrige LE/AU
und eine bestätigte Zahl aufrechterhaltener Zauber werden berechnet;
Repräsentation, MR, spontane Modifikationen und sonstige Komponenten werden
gezielt bestätigt. Die Anzahl aufrechterhaltener Zauber wird nicht aus den
Effektchips geraten. Mirakel und Liturgie verwenden getrennte Profile;
unbekannte Kulte benötigen eine gültige bestätigte Eigenschaftskette.
Die genaue Liturgie und Mirakelzielkennung identifizieren Wiederholungen;
die SR-Grenze bleibt ausdrücklich bestätigt. Bei variablen nicht durch fünf
teilbaren Liturgiekosten wird eine Fehlversuchskostenangabe verlangt.
Mirakelboni bleiben wegen der offenen Rundung bestätigt, wirken aber auf
genau eine passende Gefechtsprobe. Lange Rituale, permanente Kosten und
Unterbrechungsfolgen ohne vollständiges Profil bleiben manuell.

Unterstützte eigene Effekte (Armatrutz, Attributo, Axxeleratus) können mit
den Kosten frisch zusammen übernommen werden; die bestehenden Eingabedialoge
werden verwendet. Der Ressourcendialog hat einen optionalen Abschlussmodus.
Kosten können vor übrigen Folgen übernommen werden; ein Fehler erhält Probe
und offene Handlung. Ausweichen beendet laufendes Wirken nicht stillschweigend.

### Abschlussreview und Korrekturen

Das unabhängige Abschlussreview fand keine Critical-, aber fünf Important-Befunde.
Alle wurden durch zuvor fehlschlagende Regressionen nachgewiesen und korrigiert:

1. Position + Orientieren darf die eigene Desorientierung überwinden; vollständiger
   Dialogablauf mit Erfolg/Misserfolg, genau einer Marke und fixiertem INI-Bonus.
2. Abwehrmanöver verwenden in Liste, Auftrag, Dialog und Pflichtprüfung dieselbe
   fachliche Aktionsart. Unbekannte Finte/Angriffsart/Paradeverbote bleiben Pflichtangaben.
3. Einmalige Mirakelboni erreichen auch Orientierungs-, Start-, End- und Störungsproben;
   Abbruch vor einem Ergebnis verbraucht den Bonus nicht.
4. Karmale Endprobenhandlungen können über ausdrücklich bestätigte Unterbrechungskosten
   ohne erfundenen Wurf abgeschlossen werden. Abbruch allein zählt nicht als misslungene
   Liturgieprobe; tatsächlich misslungene eingefrorene Proben bleiben Fehlversuche.
5. Manöver berücksichtigen die frische Katalogwaffe einschließlich Umwandlungssperren.

Die Minor-Befunde (veralteter Endprobenhinweis, beschädigte Umlaute und falsche
Angriffsabsichten bei Abwehr) sind ebenfalls korrigiert; keine Reviewbefunde zurückgestellt.
Zusätzlich erhält der Armatrutz-Abschluss unbekannte frische Effekt-/Dauerdaten.
Gefechtsregressionen: 82 Tests bestanden; Analyse und LOC-Budget ohne Befund.
Gesamtsuite: 3.153 Tests bestanden, drei bestehende Tests übersprungen.
Die zuletzt ergänzte INI-Vorschau und Armatrutz-Regel bestehen zusätzlich in
zehn gezielten Prüfungen; Mockup-JavaScript besteht `node --check`.
Pakete 2–4: Commits `4bd2185`, `7de1146`, `dd54046`; Bedienprototyp `1c22b6a`.

## Ergänzung: Hauptwaffe und Nebenhand (ab `d0fcb36`)

Freigegebener Umfang: Hauptwaffe plus zweite Waffe, Schild oder Parierwaffe;
kein allgemeines Modell für zwei Schilde, keine neue Persistenz. Drei Pakete:

1. Handbelegung: kompakte Anzeige, Haupt-/Nebenhandauswahl, Leer, Zielhand der
   Ziehhandlung; Doppelbelegung und Zweihandkonflikte vor Normalisierung sperren.
2. Abwehrmittel: getrennte Hauptwaffen-/Parierwaffen-/Schild-/Nebenhandprofile,
   konkrete Auswahl und benannte Modifikatoren; gemeinsame frische Prüfung.
3. Nebenhandaktionen: automatisch berechnete Zusatzattacken/-paraden mit
   gemeinsamem Budget und vorgeschriebener vorheriger regulärer Aktion.

Schnittstellenprüfung: Paket 1 produziert bestätigte `zielHand` und bestehende
`OffhandAssignment`; Paket 2 konsumiert diese unverändert. Paket 2 liefert
typisierte Kampfmittel samt stabiler ID; Paket 3 verwendet dieselbe Auswahl
für Budget und Ergebnisbuchung. Kein zweiter Namens-/Index-Schreibweg.

Paket 1: Regel-, frische Schreib- und Layoutregressionen (15 Tests) bestanden.
Bekannte Zieländerungen verlangen erneute Bestätigung; reine unbekannte
Zusatzfelder werden erhalten. Wegstecken benötigt bestätigte Dauer und wirkt
erst beim Abschluss. Keine automatische Entfernung kollidierender Ausrüstung.
