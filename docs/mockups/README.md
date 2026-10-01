# Klickbarer Codex-Entwurf

Stand: 19.09.2026. Gestaltungsrichtung: heller Codex mit dunkler Navigation,
Petrol für Aktionen, Messing als Akzent und dezenten Fantasy-Details.

Die Datei [hero-workspace-redesign.html](hero-workspace-redesign.html) direkt
im Browser öffnen. CSS, JavaScript und die vorhandene lokale Cinzel-Schrift
werden über relative Pfade geladen. Es sind kein Build, keine Installation und
keine Internetverbindung nötig. Die Dateien innerhalb des Repositorys belassen,
damit die relativen Schriftpfade erhalten bleiben.

## Gezeigte Bereiche

- **Spielen:** Ressourcen, häufige Proben mit Filter und Suche, Beispielwürfe,
  Schaden übernehmen und zurücknehmen, Rast, Kampfrunden, Effektlaufzeit,
  Beispielherleitung der Attacke und Notizen zum Spielabend.
- **Held verwalten:** gemeinsames Inventar mit Waffenwechsel, Gegenstände
  hinzufügen, Merkmale mit expliziter Auswahl und editierbare Biografie.
- **Entwicklung planen:** Steigerungen vormerken, aus dem Entwurf entfernen,
  AP-Vorschau und gemeinsame Übernahme der ausgewählten Beispielsteigerungen.
  Vorgemerkte Schritte bleiben beim Bereichswechsel erhalten.

Die Ansicht passt sich schmalen Bildschirmen an. `Strg K` bzw. `Cmd K` fokussiert
die Suche; Dialoge sind per Tastatur bedienbar und mit `Escape` schließbar.
„Zurücksetzen“ lädt die Beispieldaten neu.

## Vorschaubilder

- [Spielen auf dem Desktop](hero-workspace-redesign-desktop.png)
- [Steigerungsplanung](hero-workspace-redesign-planning.png)
- [Spielen auf dem Smartphone](hero-workspace-redesign-mobile.png)

## Prüfung am 19.09.2026

Im Edge-Browser wurden die Navigation, Filter und Suche, Beispielwürfe, Schaden
und Rücknahme, Rast, Effektablauf, Waffenwechsel, Gegenstandserfassung,
Biografieänderungen sowie Steigerungsplanung und Übernahme geprüft.
Leere Suchergebnisse und als Text eingegebene HTML-Zeichen wurden ebenfalls
geprüft. Dabei traten keine JavaScript-Laufzeitfehler auf.

Alle drei Bereiche wurden bei 320, 390, 768, 1024 und 1440 Pixeln Breite auf
horizontalen Überlauf geprüft. Desktop-, Planungs- und Mobilansicht wurden
zusätzlich visuell begutachtet. Direktes Öffnen der HTML-Datei ohne Server und
das Laden der lokalen Gestaltung funktionieren.

`flutter analyze --no-pub` und die beiden Tests aus
`test/ui/smoke/widget_test.dart` waren erfolgreich. Wegen eines hängenden
Windows-Batch-Starts wurde dafür das installierte `flutter_tools.snapshot`
direkt mit dem zugehörigen Dart-SDK aufgerufen.

## Abgrenzung zur App

Dies ist ein eigenständiger HTML-Prototyp für
[ARCH-01 der Architektur-Roadmap](../architecture_roadmap.md#arch-01--oberfläche-nach-spielsituationen-organisieren),
mit sichtbaren Beispielen für die Ziele aus ARCH-02, ARCH-03, ARCH-04 und ARCH-06.
Er implementiert keine Flutter-Oberfläche und schließt keinen Roadmap-Punkt ab.

Die Spielfigur, AP-Kosten, Herleitungen, Regenerationswerte und Würfelergebnisse
sind vorgegebene Beispieldaten. JavaScript simuliert lediglich die Bedienung;
es enthält keine verbindliche DSA-Regelengine. Insbesondere werden Wunden und
die Auswirkungen aktiver Zauber nicht regeltechnisch berechnet.

Alle Änderungen bleiben im Arbeitsspeicher der Browserseite und verfallen beim
Neuladen. Es gibt keine Speicherung echter Heldendaten, keinen Konto-Zugriff,
keinen Netzwerk-Sync und keinen Import aus der App. „Offline verfügbar“ und das
Regelprofil sind Bestandteile des dargestellten Zielbilds.

## Dateien und Verantwortung

- `hero-workspace-redesign.html`: Struktur, Navigation und Dialogcontainer.
- `hero-workspace-redesign.css`: Gestaltung, lokale Schrift und Breakpoints.
- `hero-workspace-redesign.js`: Beispieldaten und flüchtiger Interaktionszustand.
- `hero-workspace-redesign-*.png`: überprüfte Vorschaubilder.
- `gefecht.html`, `gefecht.css`, `gefecht.js`: Gefecht-Entwurf (siehe unten),
  Struktur, Gestaltung sowie Beispieldaten und flüchtiger Zustand.

Das bestehende `combat-tracker-mockup.html` bleibt ein separater Entwurf.
Die neuen Redesign-Dateien und diese Anleitung werden gezielt versioniert;
die allgemeine Ignore-Regel für sonstige lokale Mockups bleibt bestehen.
Vor einer Umsetzung in Flutter die Roadmap-Abhängigkeiten, vollständige
Funktionsabdeckung und noch offenen Produktentscheidungen prüfen.

## Gefecht-Entwurf (Stand 01.10.2026)

Die erste Flutter-Version dieses freigegebenen Entwurfs ist im Bereich Spielen
angebunden. [Umsetzung, Grenzen und Prüfungen](../gefecht_implementation.md)
halten den aktuellen App-Stand getrennt von diesem Beispieldaten-Prototyp fest.

[gefecht.html](gefecht.html) ist der Entwurf für einen eigenen Kampf-Screen
„Gefecht“ in Kartograph-Optik. Farben, Schriften (Spectral, Inter Tight),
Abstände und Linienstärken entsprechen `lib/ui2/theme/` und
`lib/ui2/foundation/`. Die Datei direkt im Browser öffnen. Über die Leiste
oben lassen sich der Held (Kriegerin mit Schild und Bogen, Kampfmagier mit
Stab, Rondra-Geweihte mit Liturgien), die Breite (Handy 390, Tablet 820, Breit 1200, Sehr breit 1440) und
Hell/Dunkel umschalten. Ein Startzustand lässt sich auch über die Adresse
setzen, z. B. `gefecht.html#magier,390,dunkel,gefecht`.

Der [Arbeitsplan für das Gefecht](gefecht-plan.md) hält Anordnung,
Regelbelege, offene Annahmen und die nächsten Designentscheidungen fest.
Dateien: `gefecht.html`, `gefecht.css`, `gefecht.js`,
`gefecht-aktionen.js` (Freigaben und Rundensteuerung) und
`gefecht-ausruestung.js` (Ausrüstungsdialog).
Geprüfte Vorschauen: [Desktop](gefecht-desktop.png), [Handy](gefecht-handy.png),
[Ausrüstungspopup](gefecht-ausruestung.png).

Gezeigt werden:

- Spielansicht in Ruhe mit kompakter Kampfzusammenfassung und
  „Gefecht beginnen“. Mit Aufmerksamkeit geht es direkt mit 6 statt 1W6
  in den Vollbild-Screen; sonst bleibt die INI-Wahl (würfeln oder echten
  Wurf eintragen). Diese gewünschte Abkürzung folgt dem App-Modell; die
  Abweichung zum WdS-Orientieren ist im Plan ausdrücklich dokumentiert. „Zurück“ lässt das Gefecht laufen,
  die Spielansicht zeigt dann ein Band „Gefecht läuft“.
- Kompakter Takt über die gesamte Breite: INI, Aktionsmarken und Rundenwechsel;
  darunter drei direkte Umwandlungsschalter sowie Auswahlfelder für Haltung,
  Gegnerzahl und tatsächliche DK. Aufschlüsselung und Regelhinweise öffnen sich über den INI-Knopf.
  Nur wirksame Sonderzustände und laufende Handlungen brauchen Zusatzplatz.
- Angriff, sichtbare Manöver und Abwehr stehen vor den Ressourcen. Manöver
  zeigen „bereit“, „prüfen“ oder „gesperrt“ mit Grund, Nutzen und Aktionsarten.
  Am Handy ist „Durchhalten“ zunächst eingeklappt; Wunden oder niedrige LE
  öffnen es. Die vollständige SF-Liste bleibt in Details. Waffen und
  Rüstungsteile wechseln in einem eigenen Popup; Ziehkosten bleiben erhalten,
  Rüstungsdauer wird noch manuell berücksichtigt.
- Aktionsmenü nach WdS S. 55: Position, Bewegen, Orientieren, Waffe ziehen,
  Nachladen, Sprinten, Gegenstand benutzen, Talent einsetzen, Mirakel und
  die Freien Aktionen (Rufen, Schritt, Drehen, Artefakt, Waffe fallen
  lassen, sich zu Boden werfen). Was mehrere Aktionen dauert, läuft als
  längerfristige Handlung über die Runden; jede andere Aktion außer Schritt
  und Drehen fragt vor dem Unterbrechen nach.
- Ausweichen als eigener Dialog: gewöhnliches Ausweichen verbraucht eine
  Freie Aktion, kostet immer INI −4 und lässt bei Gelingen desorientiert
  zurück; Gezieltes Ausweichen (nur mit SF Ausweichen I) verbraucht die
  Abwehraktion und kostet nur bei Misslingen INI −2. Distanzklasse,
  Gegnerzahl, Haltung und Mirakel gehen in den Zielwert ein. Bei unbekannter
  DK wartet der Würfelknopf auf eine ausdrückliche Auswahl.
- Würfe mit Folgen: Patzer mit Bestätigung und Patzertabelle (INI-Verlust,
  Sturz, Rest der Runde verloren), bestätigte glückliche Parade zählt nicht
  als Aktion, misslungene Ansage erschwert die nächste Aktion, misslungene
  Abwehr bietet „Schaden erhalten“ an.
- Durchhalten mit Kampfunfähigkeit (LE 1–5, einmal pro Kampf mit
  Selbstbeherrschung +12 zu ignorieren), Lebensgefahr (Frist W6 × KO KR, die
  mit jeder Kampfrunde sinkt) und der Optionalregel „niedrige LE“, die sich
  oben in der Leiste abschalten lässt.
- Angriff, Manöver, Verteidigung, Effekte und Würfelprotokoll;
  Waffenwechsel heißt jetzt „Ziehen“ und kostet je nach Scheide Aktionen.
- Zauber, Rituale und Liturgien: Der Bereich erscheint nur bei Helden, die
  so etwas besitzen, und benennt sich nach dem Inhalt. Jeder Eintrag öffnet
  ein Detailblatt. Die Probe fällt zu Beginn des Wirkens; ein misslungener
  Zauber wird nach der halben Dauer bemerkt und kostet die Hälfte, eine
  misslungene Liturgie ein Fünftel. Liturgien tragen ihren Grad
  (Probenzuschlag, Kosten). Wiederholungen sind um +3 je Fehlversuch
  erschwert (die Begrenzung auf eine SR ist noch offen), aufrechterhaltene
  Zauber erschweren Kampfwürfe (+1) und
  Zauberproben (+3). Ein Treffer während des Wirkens verlangt eine
  Selbstbeherrschungs-Probe +SP. Die Geweihte zeigt dazu das Mirakel.

Regelstellen (über den lokalen dsa-rules-Index geprüft): WdS S. 53–58
(Kampfablauf, Aktionen, Orientieren, Kampfunfähigkeit, Haltung), S. 66–70
(Ausweichen, Klingenwand), S. 72 f. und 78 (Zusatzaktionen), S. 74
(Aufmerksamkeit), S. 79 (Optional: hohe Initiative-Werte), S. 81 f.
(Umwandeln, Überzahl), S. 84 (Kampfunfähigkeit ignorieren), S. 209
(Kurzreferenz); Basisregelwerk S. 296 (Patzer, glückliche Würfe);
Errata WdS; LC S. 5 und WdZ S. 14 f. (Zaubern im Kampf, Störungen,
aufrechterhaltene Zauber); WdG S. 251 und LL S. 9–13, 84 f., 134
(Liturgien, Mirakel); Hausregel „Erweiterung und Überarbeitung“ S. 2 f.
(Ausweichen, INI zu Beginn der ersten Aktion, Ausdauer).

Alle Zahlen sind Beispieldaten, die Rechnung ist bewusst vereinfacht.
Würfe sind Zufallszahlen im Browser; die App würfelt weiterhin über ihren
Probendialog. Die Zauberdaten stammen aus `magie.json`, die Beschreibungen
der karmalen Sonderfertigkeiten aus `karmale_sonderfertigkeiten.json`.
Rituale sind Einträge in Ritualkategorien, wie der Held sie in der App
anlegt; die beiden Liturgien tragen Grad, Dauer und Wirkungsdauer aus dem
Liber Liturgium. Annahmen, die der Entwurf sichtbar macht: Die
Liturgieprobe fällt wie die Zauberprobe zu Beginn; „Position und
Orientieren in einer Aktion“ (Hausregel) verlangt weiter die IN-Probe des
Orientierens; ein Mirakel auf Ausweichen wirkt wie auf eine Eigenschaft.

Die erste Iteration wurde am 01.10.2026 mit 18 Browserprüfungen und 22
isolierten Verhaltensprüfungen geprüft. Die zweite Iteration ergänzt den
INI-Start, direkte Umwandlung und das Ausrüstungspopup; ihre 28 Browserprüfungen
und acht isolierten Prüfungen bestehen ebenfalls. Die geprüften Layouts zeigen keinen
horizontalen Überlauf; JavaScript-Laufzeitfehler wurden nicht beobachtet.
Die genauen Fälle und bewusst offenen Regelsituationen stehen im
[Gefecht-Plan](gefecht-plan.md#6-prüfnachweis-dieser-iteration).
Plan und Mockup bleiben die Grundlage für weitere gemeinsame Entwurfsarbeit.
Die produktive App wird in dieser Iteration nicht geändert.

## Übergang zur Flutter-Umsetzung

Die [Redesign-Übergabe](../redesign_implementation.md) enthält drei konkrete
Umsetzungspläne mit Startprompts für weitere Agenten. Sie nutzen das inzwischen
vorhandene Kartograph-Fundament unter `lib/ui2/`, übernehmen die drei
Arbeitsbereiche und grenzen simulierte Funktionen von vorhandener Fachlogik ab.
Die Pläne sind Arbeitsaufträge, kein Nachweis ihrer Umsetzung.

Alle drei Pakete sind inzwischen umgesetzt. Wie der Flutter-Stand tatsächlich
aussieht, zeigen die echten Screenshots unter
[`docs/screenshots/redesign-r3/`](../screenshots/redesign-r3/); die Abnahme mit
Funktionsmatrix und verbliebenen Grenzen steht in
[redesign_acceptance.md](../redesign_acceptance.md). Dieses Mockup bleibt die
gestalterische Vorlage, nicht der Stand der App.
