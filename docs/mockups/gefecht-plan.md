# Gefecht: Arbeitsplan und Design

Stand: 01.10.2026 · Abgenommener Entwurf

Die erste Flutter-Umsetzung und ihre Grenzen sind in
[gefecht_implementation.md](../gefecht_implementation.md) dokumentiert.
Die folgenden Entwurfsentscheidungen bleiben als Grundlage erhalten.

Der [klickbare Entwurf](gefecht.html) soll am Spieltisch beantworten:
**Was kann ich jetzt tun, was bringt es, was kostet es und was folgt danach?**
Plan und Mockup dienten der Abnahme vor der Flutter-Umsetzung. Beispielrechnungen und Zufallswürfe im Browser
sind keine neue produktive Regelimplementierung.

Geprüfte Vorschauen: [Desktop](gefecht-desktop.png), [Handy](gefecht-handy.png),
[Ausrüstungsdialog](gefecht-ausruestung.png).

### Gefecht beginnen

Vor der INI-Abfrage wird die SF **Aufmerksamkeit** geprüft. Mit ihr wird im
gewünschten Startablauf der maximale Wurf angesetzt (in den Beispielen 6 statt
1W6) und direkt das Gefecht geöffnet. Ohne Aufmerksamkeit bleibt der Dialog zum
Würfeln oder Eintragen des echten Wurfs. Der Beispieldirektstart über die Adresse
berücksichtigt dieselbe SF.

Das folgt dem vorhandenen App-Modell in `lib/rules/derived/combat_rules.dart`
(`initiativeFixedRollTotal`), ist aber keine durch WdS bestätigte Startregel:
WdS S. 56, MCP-Chunk 6973, setzt das Maximum durch die Aktion Orientieren;
Aufmerksamkeit verkürzt diese auf eine Aktion ohne Probe. Orientieren vor
Kampfbeginn ist dort ausgeschlossen. Die Abweichung ist eine ausdrücklich
gewünschte Produktentscheidung für diesen Entwurf. Kampfreflexe und Kampfgespür
werden nicht mit dem Ersatz des Wurfs verwechselt.

## 1. Anordnung

### Rundensteuerung über die gesamte Breite

Die frühere hohe Taktkarte mit leeren Flächen neben der Ansage entfällt.
Eine gemeinsame Leiste bündelt:

1. **INI, offene Aktionsmarken, KR und Rundenwechsel.** Marken zeigen Angriff,
   Abwehr, freie Aktionen und gegebenenfalls Zusatzparaden. Verbrauch und Sperre
   bleiben direkt erkennbar.
2. **Umwandeln** als drei direkt erreichbare Schaltflächen, ohne Pickliste.
   „1 AT · 1 PA“ bezeichnet den normalen Rundenplan;
   „2 PA“ beziehungsweise „2 AT“ zeigt den Umwandlungszuschlag an.
   Die aktive Option ist markiert; gesperrte Optionen sind deaktiviert.
   **Haltung, Gegnerzahl und aktuelle DK** bleiben kompakte Auswahlfelder.
   Zwei Schildparaden und „Weitere Aktionen“ stehen daneben und brechen bei
   Bedarf in die nächste Zeile um.

INI-Aufschlüsselung, Umwandlungsregeln und manuelle INI-Korrekturen öffnen sich
über den INI-Knopf. Nur wirksame Sonderzustände wie Desorientierung, Sprinten,
Patzer, aufrechterhaltene Zauber und laufende Handlungen belegen eine Zusatzzeile.
Haltung und Gegnerzahl werden nicht noch einmal als große Zustandskarte gezeigt.

Haltung ist eine **manuelle Situationskorrektur**. Regelgerechtes Aufstehen läuft
über „Weitere Aktionen → Position“ und kostet eine Aktion. Die Gegnerzahl meint
für die Beispielmodifikatoren die gleichzeitig relevanten Nahkampfgegner.
Die DK-Auswahl beginnt mit „offen“; die Waffen-DK ersetzt keine erfasste Kampfdistanz.

### Kampfoptionen vor unterstützenden Daten

| Breite | Reihenfolge und Aufteilung |
| --- | --- |
| Handy | Rundensteuerung → Angriff → Manöver → Verteidigung → Wirken → Durchhalten → Effekte → Protokoll |
| Tablet | Rundensteuerung durchgehend; links Angriff, Manöver und Wirken; rechts Verteidigung, Durchhalten und Effekte |
| Desktop | Rundensteuerung durchgehend; links Angriff, Manöver und Wirken; Mitte Verteidigung; rechts Durchhalten und Effekte |

Am Handy beginnt „Durchhalten“ eingeklappt mit LeP und Wundenzahl. Bei Wunden
oder einem aktiven Malus durch niedrige LE öffnet sich der Bereich automatisch.
Die Schnellaktionen bleiben unten erreichbar und spiegeln die Freigaben der
Hauptbereiche. Nur die vollständige SF-Liste steht in Details.

### Ausrüstung im eigenen Popup

„Waffe wechseln“ im Angriff und „Teile wechseln“ unter Rüstung öffnen denselben
Ausrüstungsdialog im passenden Bereich. Zwei direkte Bereichsschalter führen
zwischen Waffen und Rüstungsteilen. Die Hauptansicht enthält die geführte Waffe
sowie RS und BE; Ersatzwaffen und einzelne Rüstungsschalter entfallen dort.

Waffen zeigen Werte, Ziehkosten und den aktuellen Zustand. Ziehen verwendet
die bisherige Aktionssimulation; ein längerer Wechsel wird als Handlung
fortgesetzt, nicht sofort abgeschlossen. Ohne passende Aktion ist er gesperrt.
Rüstungsteile lassen sich im Popup an- und ablegen, und RS/BE werden aktualisiert.
Das korrigiert den erfassten Ausrüstungszustand; An- und Ablegedauer werden noch
nicht automatisch als Kampfhandlungen simuliert und bleiben vor der App-Abnahme
zu klären. Ein Hinweis im Dialog erinnert an den Zeitbedarf am Spieltisch.

## 2. Erkennbare Freigaben

Manöver stehen offen im Hauptfluss. Ein erlerntes, gerade gesperrtes Manöver
bleibt zum Nachlesen erreichbar; sein Würfelknopf im Detail ist deaktiviert.

| Status | Bedeutung | Beispiel |
| --- | --- | --- |
| bereit | Nach den erfassten Voraussetzungen ausführbar | Wuchtschlag, passende DK, offene Angriffsaktion |
| prüfen | Ein relevanter Kontextwert fehlt oder braucht eine Bestätigung | DK unbekannt; besondere Gegnervoraussetzung |
| gesperrt | Eine erfasste Voraussetzung widerspricht der Aktion | Keine passende Aktion; Hammerschlag mit Schwertern |

Jede Zeile zeigt den Nutzen, den Status mit kurzer Begründung und die benötigten
Aktionsarten. Der Detaildialog enthält Zielwert, Ansage, Aktionsverbrauch,
Voraussetzungen und Folgen. Umwandlungszuschläge stehen bereits im Zielwert.
Für Ausweichen wird zunächst die Variante und die tatsächliche DK gewählt;
ein bloßer AW-Basiswert wird nicht als fertiger Zielwert ausgegeben.

„Bereit“ bezieht sich auf den **erfassten** Zustand. Gegnerische Finte, Größe,
Angriffsart, Sicht, Gelände und weitere Sonderregeln müssen vor einer echten
App-Freigabe ebenfalls berücksichtigt oder ausdrücklich zur Prüfung angeboten
werden. Der Entwurf beansprucht keine vollständige automatische Regelprüfung.

## 3. Im Mockup berücksichtigt

- [x] Rundenbeginn-Ansage, Haltung und Gegnerzahl verdichten; freie Seitenflächen
  der bisherigen Taktkarte beseitigen.
- [x] Umwandeln über drei direkte Schaltflächen anbieten, ohne Pickliste.
- [x] Mit Aufmerksamkeit die INI-Abfrage überspringen und den maximalen
  Wurf ansetzen; ohne die SF manuelle Wahl beibehalten.
- [x] Waffen und Rüstungsteile in ein separates Popup verlagern.
- [x] Manöver sichtbar vor Ressourcen anordnen; Nutzen und Freigabe anzeigen.
- [x] Anzeige und Ausführung verwenden gemeinsame Aktionskostenprüfungen.
  Ohne passende Marke entsteht kein Kampf- oder Ausweichwurf.
- [x] Zuschlag einer umgewandelten Aktion vor dem Wurf anzeigen und anwenden.
- [x] Gewöhnliche Schildparaden von Waffenparade und gezieltem Ausweichen trennen.
  Zusatzparaden bezahlen keine längerfristigen Handlungen.
- [x] Hammerschlag mit dem Beispiel-Langschwert sperren; alle Kampfaktionen
  müssen noch verfügbar sein. Nach einer früheren Parade ist er gesperrt.
- [x] Ausweichen wartet bei unbekannter DK auf Auswahl; erfolgreiche freie
  Ausweichaktion verlangt Position + Orientieren. INI −4 gilt auch bei Scheitern.
- [x] Hohe-INI-Boni erst bei der ersten tatsächlich genutzten Aktion fixieren.
- [x] Ungeladene oder leere Fernkampfwaffen vor Wurf und Munitionsverbrauch sperren.
- [x] Wirken braucht zum Beginn eine reguläre Aktion und ausreichend Energie
  für bekannte feste Kosten. Variable Kosten bleiben manuell zu prüfen.
- [x] Hausregel für kritische Treffer nennen: TP verdoppeln, keine Zusatzwunde.

## 4. Regelvalidierung über den DSA MCP

Grundlage sind DSA 4.1 und die im MCP enthaltenen Hausregeln. Hausregeln gehen
bei den hier benannten Abweichungen vor. Seitenangaben entsprechen dem MCP-Index
und können von der gedruckten Paginierung abweichen.

| Thema | Bestätigte Regel | Beleg im MCP |
| --- | --- | --- |
| Umwandeln | In der Regel +4; zweite Attacke bei INI −8, nicht unter 0. Mit Schild AT → PA ohne Zuschlag; Stab ab TaW 10 beide Richtungen ohne Zuschlag. | WdS S. 82, Chunks 7046–7047 |
| Zeitpunkt | Ansage zu Rundenbeginn; Aufmerksamkeit bis zur eigenen Initiativphase; Kampfgespür auch später. Eine bereits erklärte Umwandlung lässt sich nicht zurücknehmen. | WdS S. 82, Chunk 7046 |
| Hammerschlag | Alle nicht freien Aktionen; nicht nach vorheriger Parade. Schwerter sind keine erlaubte Kampftechnik. Waffen- und Gegnervoraussetzungen beachten; Scheitern eröffnet einen Passierschlag. | WdS S. 64, Chunk 6996 |
| Zwei Schildparaden | Schildkampf II, BE höchstens 4, kein Turmschild; beide gewöhnlich, keine Manöver und kein Umwandeln dieser Paraden. | WdS S. 72, Chunks 7019–7020 |
| Zusatzaktionen | Zusätzlich zur entsprechenden regulären Aktion; nicht für längerfristige Handlungen. Nach zwei dafür verwendeten regulären Aktionen entfällt die Zusatzaktion. | Errata WdS S. 3–4, Chunk 25631 |
| Freies Ausweichen | Freie Aktion, immer INI −4; bei Gelingen desorientiert, bis Position folgt. | WdS S. 67–68, Chunks 7006–7007 |
| Gezieltes Ausweichen | SF Ausweichen I, reguläre Abwehraktion; doppelte DK-Zuschläge; Scheitern INI −2, keine Desorientierung. | WdS S. 67–68, Chunks 7006–7007 |
| Ausweich-DK und Position | Frei kein DK-Wechsel; gezielt optional eine DK zurück, zwei mit weiteren +4. Position und Orientieren gemeinsam für eine Aktion. | Hausregel „Erweiterung und Überarbeitung“ S. 2–3, Chunks 25817–25818 |
| Hohe INI | Boni ab INI 21/31/41; Hausregel bestimmt sie zu Beginn der ersten Aktion. | WdS S. 79, Chunk 7039; Hausregel S. 2–3, Chunks 25817–25818 |
| Orientieren | Normal zwei Aktionen mit IN-Probe; Aufmerksamkeit eine Aktion ohne Probe. Kampfverluste werden behoben, nicht Wund- oder Magieverluste. | WdS S. 56, Chunk 6973 |
| Kritische Treffer und Wunden | Hausregel verdoppelt auch KK-Schaden, gewährt keine Zusatzwunde und kombiniert globale mit zonalen Wundfolgen. | Hausregel S. 2–3, Chunk 25818 |
| Mirakel | Auch auf Ausweichen möglich; eine Aktion, 5 KaP; Eigenschafts- und Talentbonus unterscheiden sich. | LL S. 9–10, Chunk 25843 |
| Liturgien | Gradmodifikator und Kosten; Scheitern kostet ein Fünftel, mindestens 1 KaP. Wiederholung innerhalb einer SR erschwert um +3. | LL S. 11–12, Chunk 25844 |

## 5. Offene Entwurfsarbeit vor der App-Umsetzung

Diese Punkte sind bewusst noch keine abgeschlossene Regelimplementierung:

1. **Initiativphase und verbindliche Ansagen:** Der Prototyp hat keine globale
   Phasenuhr. Die Ansagesperre orientiert sich am Verbrauch eigener Aktionen.
   Aufmerksamkeit, spätere Umwandlung mit Kampfgespür, unveränderliche erklärte
   Ansagen und die zweite Aktion bei INI −8 brauchen ein eindeutiges Bedienmodell.
2. **Gegnerkontext:** Anzahl allein reicht nicht. Größe, Angriff, Finte,
   Umstelltsein, DK-Wechsel und weitere Voraussetzungen sollen nur abgefragt
   werden, wenn sie die gewählte Option beeinflussen. Normale AT/PA/FK und
   Manöver brauchen dieselbe nachvollziehbare Kontextprüfung.
3. **Waffen und Sonderfertigkeiten:** Die Beispieldaten ersetzen keinen
   vollständigen Katalogabgleich. Umwandlungsverbote, BE-/Turmschildgrenzen,
   Klingenwand sowie weitere Zusatzaktionsarten vollständig abdecken.
   Hausregelausnahmen bei der DK beachten: Finte zur DK-Verkürzung und
   Parademanöver mit der kürzeren Waffe bleiben gesonderte Fälle.
   Klingenwand ist aktuell nur nachlesbar und keine nutzbare geteilte Parade.
4. **Folgen und Kosten:** Zielwert und Marken sind simuliert. Manöverschaden,
   Passierschläge, optionale DK-Bewegung, globale plus zonale Wundfolgen und
   Sonderfälle bei Glück/Patzer benötigen eigene überprüfte Abläufe.
5. **Magie und Karma:** Zeitpunkt der Liturgieprobe und die konkrete
   Mirakel-Bonusformel für AW bleiben sichtbar markierte Annahmen. Die
   Wiederholungserschwernis wird vereinfacht je Fehlversuch gezählt; die
   Begrenzung auf eine SR sowie negative Fertigkeitswerte fehlen noch.
6. **Nächste gemeinsame Designprüfung:** Leiste bei vielen Bonusmarken und
   laufender Handlung, Auswahl mit Tastatur, Ausweichdialog, gesperrte Manöver,
   Verletzungen sowie die Höhe der Handyansicht am Spieltisch beurteilen.

Erst nach dieser Entwurfsabnahme entsteht ein verbindlicher Flutter-Arbeitsplan.
Er soll gemeinsame Regelmodule unter `lib/rules/derived/`, flüchtigen
Gefechtszustand, vorhandene Proben-/Schadensdialoge und eine klare Trennung von
UI, Ressourcenpersistenz und Katalogtexten vorsehen. Keine Browserfunktion wird
ungeprüft in Widget, Provider oder Domain-Modell übernommen.

## 6. Prüfnachweis dieser Iteration

Erste Iteration am 01.10.2026: 18 Browserprüfungen mit lokalem Edge über das DevTools-Protokoll,
darunter fünf Layoutvarianten (390/820/1200/1440, Hell/Dunkel, drei Beispielhelden),
Haltung und Gegnerzahl, explizite DK, INI-Dialog, Umwandlungszielwert,
Aktionsverbrauch, Rundenwechsel und gesperrter Hammerschlag. Keine
JavaScript-Laufzeitfehler und kein horizontaler Überlauf in diesen Varianten.
Zusätzlich 22 isolierte Verhaltensprüfungen für Aktionsbudget, Ausrüstung,
INI-Fixierung, Zusatzparaden, Kampfsperren, Manöverstatus und mobile Reihenfolge.
Die fünf vor der Änderung fehlgeschlagenen Freigabeprüfungen bestehen jetzt.

Die Prüfscripte und Bildschirmaufnahmen liegen im temporären Prüfverzeichnis.
Zwei geprüfte Vorschauen sind zusätzlich bei diesem Plan abgelegt.
Sie sind Nachweise für diesen Stand, keine produktive Testsuite.

Zusätzliche Projektprüfung: `flutter analyze` ohne Befunde;
`flutter test test/rules/combat_rules_test.dart test/ui/combat/hero_combat_tab_test.dart`
mit 123 erfolgreichen Tests. Flutter-Dateien wurden nicht geändert.

Zweite Iteration am 01.10.2026: 28 Browserprüfungen ohne Laufzeitfehler oder
horizontalen Überlauf in den fünf geprüften Layoutvarianten. Zusätzlich zur
ersten Browsermatrix geprüft: INI-Start mit/ohne Aufmerksamkeit und manuellem
Wurf, direkte Umwandlungsoptionen, ausgelagerte Ausrüstung, Rüstungsschalter
samt BE-Aktualisierung sowie Waffenwechsel mit zwei tatsächlich verbrauchten
Aktionen. Acht isolierte Prüfungen decken dieselben neuen Abläufe ab.
Vorschauen für Desktop, Handy und Ausrüstungsdialog wurden aktualisiert.

## Folgeausbau ab 1b79203 (02.10.2026)

Der verbindliche Paketplan steht in [gefecht_next_plan.md](../gefecht_next_plan.md).
Im klickbaren Entwurf ?ffnet **Neue Bedienabl?ufe** in der Vorschauleiste
Orientieren, Gegnerkontext, Ziehen und den Wirkabschluss. Die neue Datei
`gefecht-folgeablaeufe.js` zeigt Dialogabl?ufe mit fl?chtigen Beispielen;
sie ver?ndert keine Heldendaten und simuliert keine produktive Speicherung.
Die alten Bildschirmaufnahmen belegen den Entwurf vom 01.10., nicht diese Dialoge.

- **Orientieren:** Dauer und Kriegskunstbonus vorbelegen, Ungest?rtheit best?tigen,
  INI vorher/nachher ohne nachgeschaltete Korrektureingabe. Position + Orientieren
  kostet nach Hausregel eine Aktion; die IN-Probe bleibt ohne Aufmerksamkeit n?tig.
- **Kontext:** Aktion w?hlen, nur relevante unbekannte Werte erfassen; Finte pro
  Angriff, DK getrennt von Waffen-DK. Zielwert zeigt seine Anteile. Kontaktwechsel
  verwirft Angriffsdaten. Distanz?nderung verursacht keinen Schaden und wartet bei
  Ann?herung auf die gegnerische Abwehrbest?tigung.
- **Ziehpopup:** SF automatisch, Trageposition und Griffbereitschaft/Handbelegung
  gezielt best?tigen. Schnellziehen vom G?rtel bezahlt eine freie Marke.
  Restdauer sch?tzt die gew?hlte stabile Slot-ID bis zur frischen ?bernahme.
- **Wirken:** Repr?sentation, eindeutige Dauer/Kosten und weitere Modifikatoren
  best?tigen. Startprobe einmal auswerten; Resthandlung zeigt eingefrorenes
  Ergebnis, Fortsetzen, St?rung und ausdr?cklich best?tigten Abbruch.
- **Abschluss:** Kosten und unterst?tzte eigene Effekte zusammen ?bernehmen;
  Ressourcendialog mit Abschlusskosten, bestehende Effektwerteingaben. Getrennt
  ?bernommene Kosten bleiben markiert, w?hrend ?brige Folgen offen sind.
  Speicherfehler bietet erneute ?bernahme ohne Wurf oder Doppelbuchung.

Regelbelege: WdS 55?56 (6972?6973), 67?68 (7006?7007), 80 (7040?7041);
Hausregel S.2?3 (25817?25818); WdZ 13?17 (4972?4976,4981?4982);
LL 9?14 (25843?25845) und karmale Hausregel S.25?26 (25835).
Aufmerksamkeit-Start, Klingent?nzer-Maximum 12 beim Orientieren und Aufrundung
halber Aktionsmarken sind App-Konventionen. Liturgieprobenzeitpunkt,
Unterbrechungsfolgen, permanente Kosten, Mirakel-Bonusrundung/AW-Zuordnung,
Repr?sentationsausnahmen und Patzer bleiben ohne vollst?ndiges Profil manuell.
Der fr?here Browsertext mit einem angenommenen Liturgieprobenzeitpunkt ist
keine Regelbest?tigung; das Folgeprofil verlangt eine explizite Best?tigung.

Keine neue Hauptkarte und keine Persistenz laufender Gefechte. Die globale
Initiativphasensteuerung bleibt ein eigenes sp?teres Paket mit mehreren Teilnehmern.
