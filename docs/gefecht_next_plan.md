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

Paket 1: Commit `284bb58`. Paket 2: getrennte Kampfmittelprofile und Dialogauswahl;
81 neue/bestehende Kampf-, Armwund-, Quellen- und Layoutprüfungen bestanden.
WdS 71 (MCP 7015–7016) bestätigt Parierwaffen-WM/SF auf Hauptwaffen-PA und
unveränderte Hauptwaffen-AT; Schild-PA berücksichtigt eBE. Der alte Test, der
den Parierwaffen-AT-WM der Hauptwaffe zuschlug, wurde entsprechend korrigiert.
Die optionale Schildverbesserung bei Hauptwaffen-PA 15/18/21 wird nicht neu
aktiviert; individuelle bestätigte Abweichungen bleiben explizite Zuschläge.

Paket 2: Commit `849acfb`. Paket 3 verbindet die konkrete Zusatzaktion mit
vorheriger regulärer Aktion, Ausrüstungspaar und einmaliger AT-/PA-Probe.
SK-II-Paraden erhalten dieselbe Zusatzmarke wie andere Quellen; keine zweite
reguläre Parade, keine Zahlung einer Dauerhandlung. PW-II verlangt gewöhnliche
Paraden ohne Ansage/Umwandlung. Bindungen werden beim Rundenwechsel gelöscht.
Frische Auswahl bestimmt auch Fernkampfkontext und Munitions-ID.

Ergänzende MCP-Prüfung 2026-10-02: WdS 71, 7017 (Schild-Manöververbote,
Finte-/Ausfallzuschläge, kleine Schilde, Aufhebung des Schild-WM); Errata WdS
S.3–4, 25631 (Hauptwaffenbindung, Reihenfolge und gewöhnliche PW-Paraden).
Optionale/improvisierte Doppelrollen und Bruchtests bleiben manuell.
Tod von Links benötigt ein eigenes AT-Profil; vorhandene reine
Parierwaffen-Einträge enthalten weder Waffentalent noch vollständige Angriffswerte.
Die vorhandene Sperre bleibt mit Erklärung sichtbar. Kein neues persistiertes
Hand-/Waffenmodell und keine unbelegte Übernahme der Hauptwaffenattacke.

Zusatzaktionsdialoge enthalten keine manuelle Zielwert-/Dauereingabe.
Regressionen prüfen konkrete Zielwerte, Finte/INI genau einmal, SF, Waffenwechsel,
PW-/Schildbindung, Rundenreset, nicht kumulative Marken, Doppelcallback und
Layoutmatrix 390/820/1200/1440, Hell/Dunkel mit Tastatur.

Paket 3: Commit `47f53d0`; 128 Gefechtsregressionen und Analyse bestanden.
Das unabhängige Abschlussreview meldete zwei Important-Befunde, keine Critical:
Zusatzparaden löschten Angriffsdaten nicht und gesperrte PW-Zusatzattacken
erzeugten eine ungültige Dropdown-Auswahl. Beide wurden zuerst als rote
Regression nachgewiesen und korrigiert; die Zusatzmarke bleibt dabei unverändert.
Die Gesamtsuite deckte außerdem zwei alte Bestandswerte ohne Schild-eBE auf.
Der Krieger-Schild folgt nun nach WdS 71 der Rechnung 6 + WM 3 − Armwunde 2
− eBE-PA-Anteil 1 = 6, beim Linkshänder ohne Schildarmwunde 8.

## Ausbau vom 3. Oktober 2026: Paket 1

Gemeinsame strukturierte Freigabe, kombinierbare Manöverfilter, bedingte
Schildsichtbarkeit, konkrete Pflichtangaben statt allgemeinem Haken, freie Werte
ab 0 mit einmaligen festen Zuschlägen und ausgeschriebene Distanznamen sind
implementiert. Die Paketregressionen und Layoutmatrix umfassen 86 bestandene
Tests. Diese Teilabnahme umfasst noch keine getrennten Finte-/Wuchtschlag-/
Fernkampfansagen, neuen Ergebnisboni, spontane Umwandlung oder Ladehandlungen.

### Paket 2: Ansagen und spontane Umwandlung (3. Oktober 2026)

Getrennte Ansagen und Erfolgsprofile sind implementiert. Finte/Wuchtschlag ohne
SF behalten die gerundete halbe Wirkung; normale Attacke und Sturmangriff
erlauben beide Anteile. Feste Zuschläge, Schild und Waffenmeister wirken einmal.
Schadensboni gehören zu einzeln erhaltenen erfolgreichen Angriffen mit eingefrorenem Profil;
der allgemeine Schadenswurf bleibt unabhängig. Spontanes Umwandeln erhält
verbrauchte Budgets, Quellenverbote und INI-Grenzen. Klingentänzer wird aktiv
mit eigener BE-Grenze geführt; Kampfgespür bleibt Quelle der späten Umwandlung.

Paket 3 konsumiert `Gefechtszielstand` und `gefechtsFernkampfansage`: bezahlte
zusätzliche Ansagezeit ist an Kampfmittel, Geschoss, vollständigen Profilkey,
Zielkontakt und Ansage gebunden. Der gebuchte Schuss verbraucht den Stand;
Rundenwechsel erhält ihn. Der bezahlende Bedienpfad ist in Paket 3 implementiert;
fehlende Zahlungen sperren weiterhin den unmittelbaren Schuss. Allgemeines
optionales Zielen zur Senkung anderer Zuschläge bleibt manuell abgegrenzt.

Quellen erneut im DSA-MCP gelesen: Finte 6994, Wuchtschlag 7003/7004,
Fernkampfansage 7089, Umwandlung 7046/7047, Klingentänzer 7030,
Hammerschlag 6996, Gezielter Stich 6995, Todesstoß 7002, Klingensturm 6997.
Komplexe Hammerschlag-/Todesstoßfolgen bleiben konkret am Tisch bestätigt,
anstatt aus Textschlagwörtern automatisch freigegeben zu werden.

Reviewkorrektur I1: Erfolgsfolgen sind zentral nach unterstütztem Waffenschaden,
keinem Schaden und manueller Abwicklung eingeteilt. Entwaffnen/Umreißen bieten
keinen Schadensrequest; ungeklärte Varianten erhalten keine gewöhnlichen
Waffen-TP. Regel- und Widgetregressionen prüfen diese Grenze sowie den einzelnen
Abschluss bei weiteren offenen Treffern. Hammerschlag behält gebundene Ansagen
und den ausdrücklich manuellen Multiplikator der gesamten TP.

### Paket 3: Laden und bezahltes Zusatz-Zielen (3. Oktober 2026)

Eigene flüchtige Lade-/Zielhandlungen verwenden echte reguläre Marken über Runden.
Ladung gilt pro physischer Waffen-ID für Haupt- und Nebenhand, nicht global pro
Gegnerkontakt. Unbekannter Anfang wird konkret erfragt; bekannte Entladung bleibt
verbindlich. Fortschritt ist an Geschoss/Profil gebunden und wird weder durch
Waffenwechsel noch Abbruch übertragen oder erstattet. Aktuelle Ladezeit aus
derselben Combat-Vorschau kann sich ändern; bereits bezahlte Aktionen bleiben
erhalten. Bei Rest0 kostet der Ladeabschluss keine neue Aktion.

Die Armbrust-Schnellladenrechnung erhält nun gerundete drei Viertel statt ein
Viertel der Basis. Rechner, Anzeige, Tests und technische Übersicht sind angepasst.
Schnellladen einschließlich der durch Axxeleratus verliehenen Wirkung gilt in
beiden Händen nur bis effektiver Rüstungs-BE 4 nach Rüstungsgewöhnung; BE 5
deaktiviert auch den Kombinationsbonus einer besessenen SF mit Axxeleratus.
Zusatz-Zielen hält den vollständigen ursprünglichen Schussauftrag. Vor dem Schuss
werden Profil, Zielkontakt, Zahlung und eigenes Budget erneut geprüft. Dabei
bleiben aktuelle DK und Sitzungskontext auch nach Probeabbruch erhalten. Fertig
bezahltes Zielen erlaubt spontane Kampfgespür-Umwandlung ohne Markenrückzahlung.
Abgebrochene Probe erhält Zielauftrag; gewürfelte Schüsse erhalten offene
Munitionsübernahme ohne Abbruch. Retry würfelt nicht erneut und konsumiert das
eingefrorene Geschoss einmal; Endkampf bestätigt keine zwischenzeitliche offene
Übernahme weg.

Lade-/FK-Ansagedialog, laufende Zielhandlung und drei offene Treffer samt langem
Hammerschlag-Hinweis werden bei390/820/1200/1440Pixeln, Hell/Dunkel und Tastatur
0/250 geprüft. Opt-in-PNGs nutzen denselben GEFECHT_SCREENSHOT_DIR-Testweg.
Die elf Punkte des freigegebenen Ausbaus sind implementiert und unabhängig
geprüft. Die nachfolgenden ursprünglichen Testnotizen bleiben erhalten.

### Gesamtabnahme vom 4. Oktober 2026

- 255 frische Gefechtsregressionen bestanden.
- 454 relevante Gefecht-, Kampf- und Ladezeitprüfungen bestanden.
- Gesamtsuite: 3.318 Tests bestanden; drei bestehende Tests übersprungen.
- `flutter analyze`, beide LOC-Prüfungen und der vollständige CI-Formatcheck
  (`lib test tool`, 991 Dateien, keine Änderungen) bestanden.
- Alle Paketbefunde und die drei Befunde des Gesamtreviews sind behoben:
  stabiler Zahlenfokus einschließlich Cursor, wirksame Ladungsbestätigung nach
  Profilwechsel und gebundene Fernkampf-TP aus der tatsächlichen Schussdistanz.
  Der gezielte Abschlussreview für `aac4425..81cece0` ist ohne offene Befunde.

Die beim Abschluss des elfteiligen Ausbaus geprüften GitHub-Läufe auf `90967bb`
scheiterten am Formatcheck; Tests und Android-Build wurden deshalb übersprungen.
LOC und Firebase-Preview bestanden. Die drei betroffenen Formatdateien sind
lokal korrigiert; der identische Check mit Flutter 3.47.1 besteht jetzt.
Der neuere GitHub-Stand wird in der nachfolgenden Folgepaket-Abnahme festgehalten.

### Regelgrenzen und abgeschlossenes Folgepaket

Allgemeines optionales Zielen, komplexe Gegner-/Manöverfolgen und ein globaler
INI-Phasenablauf bleiben wie vereinbart abgegrenzt. Unbekannte tatsächliche
Entfernungs-TP erzeugen keinen automatischen Schadenswurf; bei unbrauchbarem
Entfernungsprofil bleibt die vorhandene Schussfreigabe gesperrt.

Die Testnotiz zum Zahlenfokus ist erledigt. Das anschließend freigegebene
Folgepaket ist umgesetzt und geprüft:
1. Waffenbezogene Zweihändigkeit für Bogen/Armbrust und zulässige Ausnahmen
   zentral umgesetzt; keine pauschale Umklassifizierung sämtlicher Fernkampfwaffen.
2. Distanzklassenwechsel als eigene Aktion angeboten; AT- und freie
   Aktionskosten sowie gegnerische Bestätigung bleiben regelgemäß erhalten.
3. „Durchhalten“ in „Vitalwerte“ umbenannt; kompakte geschlossene Ansicht
   zeigt LeP, aktivierte AsP und tatsächliche vorhandene Wunden.
4. Die Abfrage „Parade erlaubt?“ entfernt; bekannte regelbedingte Sperren
   und konkret benötigte Angriffsdaten bleiben verbindlich.
5. Meisterparade mit vorab gewählter eigener PA-Erschwernis und einmaligem
   Bonus für die nächste zulässige Aktion abgewickelt; Grenzen dokumentiert.

Diese fünf Punkte erweitern den ursprünglichen elfteiligen Auftrag. Ihre
ursprünglichen Notizen bleiben separat erhalten; es gibt keine neue Persistenz,
keine Katalogmigration und keine ungeprüfte Änderung ihrer Aktionskosten.


### Folgepaket-Abnahme vom 4. Oktober 2026

- Vitalwerte zeigt geschlossen nur LeP, aktivierte AsP und tatsächliche Wunden;
  manuelles Auf-/Zuklappen bleibt bei Ressourcenänderungen erhalten.
- Die allgemeine Paradefrage entfällt. Bekannte Verbote und konkret fehlende
  Angriffsdaten bleiben in der gemeinsamen Prüfung verbindlich.
- Bogen und gewöhnliche Armbrust belegen zentral beide Hände, auch bei alten
  Standardwerten. Balestrina bleibt einhändig; Wurfwaffen werden nicht pauschal
  umklassifiziert. Keine Änderung gespeicherter Waffenfelder.
- Distanzklasse ändern hat einen eigenen Bedienpfad. Regelgemäße AT, freier
  Schritt, Finte, gegnerische Bestätigung und schadensfreier Wechsel bleiben.
- Meisterparade fragt ihre eigene Ansage vorher ab. Erfolg erzeugt einen
  einmaligen Bonus auf die nächste geeignete Angriffs-/Abwehraktion; Abbruch,
  Rundenwechsel und Verkettung behalten die geprüfte Zuordnung. Keine TP-Boni
  und keine Vermischung mit Mirakelbonus. Eine positive Schild-Ansage benötigt
  wegen der unklaren TaW-Grenze eine konkrete manuelle Obergrenze, zusätzlich PA.

Historische Abnahmeprüfung auf `51955b5`: 3.381 bestanden, 3 bestehende Tests übersprungen.
Analyse, vollständiger CI-Formatcheck, tatsächlicher CI-LOC-Check und Gefechts-LOC
bestanden. Paketreviews und Gesamtreview einschließlich nötiger Korrekturen sind
abgeschlossen. Produktstand der Abnahme: `51955b5`.

Allgemeine Folgen misslungener Ansagemanöver bleiben manuell; Meisterparade nennt
die gewählte Ansage und den Folgemalus ausdrücklich. Die unveränderte zusätzliche
breite UI2-LOC-Prüfung findet weiterhin die bestehende 803-Zeilen-Abenteuerdatei.
Zum damaligen Abnahmestand blieb ein nicht blockierender Testnachtrag offen:
ausdrückliche Buchung einer zulässigen Zusatzabwehr mit offenem Meisterparadebonus.
Dieser Nachtrag ist in der nachfolgenden Prüfung abgeschlossen.

Historischer GitHub-Prüfstand auf `50241f2`:
Die Läufe `37198239552` und `37198240229` bestehen Format, Analyse, LOC und Android-
Debug-Build; der Testjob scheitert. Firebase-Preview besteht. Die vollständigen
Fehlerlogs sind per API mit HTTP 403 geschützt; die konkrete Remote-Fehlerausgabe
konnte deshalb nicht unabhängig gelesen werden. Lokal wurden die alten unzulässigen
Nebenhand-Armbrust-Testdaten reproduziert und in `51955b5` auf eine zulässige
Balestrina korrigiert, ohne die Hand- oder Profilregeln aufzuweichen. Der frische
Gesamtlauf dieses neueren Stands besteht; sein GitHub-Lauf steht noch aus.
Der Agent hat keinen Push oder Deployment ausgeführt. Die ursprünglichen Nutzernotizen
bleiben unverändert und außerhalb der Agenten-Commits erhalten.

### Testnachtrag nach PR #208 (4. Oktober 2026)

PR [#208](https://github.com/DennisAdamski/DSA_HeroApp/pull/208) wurde am
4. Oktober 2026 um 17:54 Uhr MESZ nach `test` gemergt (`e289938`). Der lokale
Arbeitsbranch enthält denselben Dateiinhalt wie dieser Merge-Stand und wird
gemäß AGENTS.md weiterverwendet; es erfolgt kein neuer Merge.

- [x] Der Integrationstest in `gefecht_meisterparade_test.dart` führt mit
  einhändiger Hauptwaffe, geführtem Schild und Schildkampf II eine erfolgreiche
  reguläre Schild-Meisterparade mit Ansage 3 und bestätigter Schildgrenze 3 aus.
- [x] Nach dem Löschen der ersten Angriffsdaten wird ein frischer Nahkampfangriff
  mit Finte 1 und wirksamem Schild-WM bereitgestellt. Die gemeinsame Prüfung,
  Dialogvorschau und tatsächliche PA-Probe verwenden genau einmal den Bonus +3.
- [x] Dialog- und Probeabbruch erhalten Bonus sowie reguläres, freies und
  zusätzliches Budget. Der folgende echte Abschluss mit doppeltem Callback
  verbraucht genau eine Zusatzmarke und entfernt den Bonus genau einmal;
  die bereits gebuchte reguläre PA bleibt bei einer Marke.

Keine Produktionsänderung und keine zusätzliche Regelautomatisierung nötig.
Die bestehenden manuellen Grenzen, insbesondere Schild-Ansagegrenze und
Fehlmanöverfolgen, bleiben bestehen.

Frische lokale Prüfungen des Testnachtrags:
- `flutter analyze`: ohne Befund.
- 42 relevante Meisterparade-/Zusatzaktions-/Provider-/Ablauftests bestanden.
- Vollständige Suite: 3.382 bestanden, 3 bestehende Tests übersprungen.
- CI-Formatcheck `dart format --output=none --set-exit-if-changed lib test tool`:
  1.000 Dateien geprüft, keine Änderungen.
- CI-LOC (21 Screens), Gefechts-LOC (25 Dateien) und ergänzte Testdatei: ≤700 Zeilen.
- Breite UI2-LOC-Prüfung: unverändert bestehender Befund
  `lib/ui2/spielen/karto_abenteuerblatt.dart` mit 803 Zeilen; außerhalb des Scopes.
- Unabhängiges Abschlussreview des Test- und Dokumentationsnachtrags: ohne Befund.

AGENTS.md, CLAUDE.md, README.md und betroffene Dokumentation sind geprüft.
Es entsteht kein neues Konzept oder geändertes Produktionsverhalten; der
Prüfnachweis wird nur hier und in `gefecht_implementation.md` ergänzt.

Aktueller veröffentlichter CI-Stand: [Lauf 37214771631](https://github.com/DennisAdamski/DSA_HeroApp/actions/runs/37214771631)
auf `e289938` ist erfolgreich abgeschlossen: Format, Analyse, LOC, Unit-/Widgettests,
Web-Release-Build und Firebase-Hosting. Das ist der bereits erfolgte Remote-Lauf
nach PR #208; für diesen lokalen Testnachtrag existiert noch kein Remote-CI-Lauf.
Kein Push, weiterer Merge oder Deployment durch den Agenten.
