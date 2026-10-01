# Gefecht: Arbeitsplan und Design

Stand: 01.10.2026 · Entwurfsphase

Der [klickbare Entwurf](gefecht.html) soll am Spieltisch beantworten:
**Was kann ich jetzt tun, was bringt es, was kostet es und was folgt danach?**
Wir entwickeln zunächst Plan und Mockup weiter. Die Flutter-App wird erst nach
Abnahme des Entwurfs angepasst. Beispielrechnungen und Zufallswürfe im Browser
sind keine neue produktive Regelimplementierung.

Geprüfte Vorschauen: [Desktop](gefecht-desktop.png), [Handy](gefecht-handy.png).

## 1. Anordnung

### Rundensteuerung über die gesamte Breite

Die frühere hohe Taktkarte mit leeren Flächen neben der Ansage entfällt.
Eine gemeinsame Leiste bündelt:

1. **INI, offene Aktionsmarken, KR und Rundenwechsel.** Marken zeigen Angriff,
   Abwehr, freie Aktionen und gegebenenfalls Zusatzparaden. Verbrauch und Sperre
   bleiben direkt erkennbar.
2. **Umwandeln, Haltung, Gegnerzahl und aktuelle DK** als beschriftete kompakte
   Auswahlfelder. „1 AT · 1 PA“ bezeichnet den normalen Rundenplan;
   „2 PA“ beziehungsweise „2 AT“ zeigt den Umwandlungszuschlag an.
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
Hauptbereiche. Waffenwechsel und die vollständige SF-Liste stehen in Details.

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

Am 01.10.2026: 18 Browserprüfungen mit lokalem Edge über das DevTools-Protokoll,
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
