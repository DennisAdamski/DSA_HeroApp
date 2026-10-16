# Magische Kenntnisse

## Erfassen und entwickeln

Zaubererstatus, Tradition, Repräsentation und Ritualkenntnis sind getrennte
Angaben. Ein aktivierter Magiebereich liefert keinen Voll-/Halbzaubererstatus.
Die wirksamen Vorteile bestimmen den Status; ein fehlender oder widersprüchlicher
Befund wird im Dialog ausdrücklich geklärt.

Im Magie-Editor unter **Repr. & SF** öffnet **Magische Tradition einrichten**
die geführte Erfassung. Auch das Hinzufügen von Voll-/Halbzauberer bietet diesen
Dialog an. **Bei Erschaffung enthalten** und **Bereits vorhanden** kosten keine
zusätzlichen AP. **Neu erlernen** führt durch die gemeinsame Erwerbsprüfung.
Der Dialog liefert erst nach Abschluss einen vollständigen Entwurf. Abbruch
bucht keine AP und übernimmt keine Teilentscheidung. Eine offene Planung muss
vor Editoränderungen wie bisher ausdrücklich verworfen werden.

In **Entwicklung → Planen → Magie** stehen Repräsentationen und Ritualkenntnisse
in eigenen Abschnitten. Erwerb und RkW-Steigerung verändern ausschließlich die
Vorschau. Spätere Schritte nutzen die geplanten Kenntnisse; das Entfernen eines
Vorgängers prüft alle Folgeeinträge neu. AP und Verlauf werden beim zentralen
Übernehmen der Runde gebucht. Einzelne Rituale werden weiterhin separat erworben.

## Modell und Bestandsdaten

`HeroSheet.ritualKnowledge` speichert eine `HeroRitualKnowledge` je stabiler
Traditionskennung. `HeroRitualCategory` kann über `traditionId` und den Modus
`traditionKnowledge` darauf verweisen. So verwenden etwa Stab- und Kugelrituale
denselben RkW Gildenmagie. Der Resolver in `ritual_knowledge_rules.dart` ist die
maßgebliche Auflösung, auch für Erwerbsvoraussetzungen.

Eigene freie Kenntnisse und talentbasierte Kategorien bleiben gültig. Beim
Laden findet keine Migration oder Zusammenführung statt. Die Einrichtung zeigt
alte Werte und Lernspalten zur bewussten Auswahl einer maßgeblichen Kenntnis.
Besteht bereits eine gemeinsame Kenntnis, bleibt sie maßgeblich. Alte eigene
Kenntnisse bleiben beim Anbinden als Archiv erhalten und werden im gemeinsamen
Modus nicht ausgewertet. Kategoriekennungen, Rituale und Zusatzfelder bleiben
erhalten. Fehlende Bezüge erzeugen keine Ersatzkenntnis.

Die neuen JSON-Felder sind optional und werden leer ausgelassen; die bestehende
Schema-Version und Inhalts-Hashes unveränderter Bestandshelden bleiben erhalten.
Unbekannte JSON-Felder werden auf allen Ebenen weitergereicht. Das Modell nutzt
die bestehenden Hive-, Transfer-, Editorabgleich- und Synchronisationswege.

## Regelgrundlage und Grenzen

Per DSA-MCP geprüft: **Wege der Helden S. 290**, **Wege der Zauberei S. 19 und
S. 106**, **Epische Stufen S. 5**.

- Erste Repräsentation und vorhandene eigene Ritualkenntnis stammen aus
  Kultur/Profession. Eine pauschale Repräsentation allein aus „Vollzauberer“
  wird nicht vergeben; die Tradition muss gewählt werden.
- Zweite Repräsentation: 2.000 AP für Voll-, 3.000 AP für Halbzauberer,
  KL/IN jeweils 15 und 50 ZfP in der Zielrepräsentation. Dritte: 4.000 AP
  für Vollzauberer, KL 18 und ebenfalls 50 ZfP. Weitere Fälle erfordern eine
  ausdrückliche Entscheidung. Lehrmeister und mindestens ein Jahr intensive
  Ausbildung werden bestätigt.
- Die gegenseitigen Rabatte für Gildenmagie/Scharlatanerie,
  Gildenmagie/Borbaradianismus und Druiden/Geoden werden berücksichtigt.
  Bei Geoden wird Herr der Erde oder Diener Sumus ausdrücklich ausgewählt.
- Fremde Ritualkenntnis: grundsätzlich 250 AP und Meistererlaubnis, Start-RkW 3.
  Eigene Basislernspalte E, Alchimie/Scharlatanerie D; eine fremde Repräsentation
  verteuert um zwei Spalten. Begabungen/Unfähigkeiten werden mitgerechnet.
  Steigerungen erfordern Lehrmeister oder ein geeignetes Buch; der
  Lehrmeisterrabatt setzt tatsächlich bestätigten Unterricht voraus.
- Abweichende Kosten und Voraussetzungen benötigen einen Meisterentscheid mit
  Begründung. Negative Kosten, AP-Erzeugung und doppelte Erwerbe bleiben verboten.
  Die epische Sperre gilt für den Erwerb weiterer Repräsentationen.

Elfen und Schelme erhalten keine erfundene gemeinsame Ritualkenntnis.
Schamanen besitzen vier unabhängige Kenntnisse (Geister rufen, bannen, binden,
aufnehmen); diese bleiben als eigene Kenntnisse erhalten. Eine vollständige
automatische Vergabe von Kultur-/Professionspaketen gehört nicht zu dieser
Erweiterung. Vorteile zu entfernen löscht keine erworbenen Kenntnisse.

## Module und Prüfungen

`tradition_rules.dart` enthält Traditions- und Ritualkenntniszuordnung,
`magic_status_rules.dart` erkennt den Status, `magic_setup_rules.dart` ergänzt
enthaltene Daten, `advancement_magic_knowledge_rules.dart` liefert Optionen,
Prüfung und Anwendung der neuen Befehlsarten `representation`/`ritualKnowledge`.
Widgets unter `lib/ui_shared/` erfassen Entscheidungen und speichern selbst nichts.

Abgedeckt werden Regelkosten/Rabatte, Voraussetzungen, Meisterentscheid,
Vorschau/Reihenfolge, Abbruch, zentrale Übernahme, gemeinsame und freie Werte,
Hive-Neustart, Editor-Konflikte sowie konkurrierende Änderungen zweier Geräte.
Schmale und breite Dialoge werden einschließlich großer Schrift geprüft.
