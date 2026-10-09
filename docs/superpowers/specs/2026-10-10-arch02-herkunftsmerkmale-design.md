# ARCH-02: Strukturierte Herkunftsmerkmale

Stand: 10.10.2026. Schriftliche Spezifikation vom Nutzer freigegeben, noch
nicht implementiert. Der [Implementierungsplan](../plans/2026-10-10-arch02-herkunftsmerkmale.md)
liegt zur Prüfung vor.
Ausgangspunkt: `f97be35b` auf `test` und
[ARCH-02 in der Roadmap](../../architecture_roadmap.md#arch-02--regelrelevante-eigenschaften-strukturiert-speichern).

## Auftrag und Grenzen

Herkunftsmodifikatoren aus Rasse, Kultur und Profession werden strukturiert
gespeichert und bearbeitet. Vor-/Nachteile können zusätzlich ihre Herkunft
ausweisen. Bestandswerte, Freitexte und die Kompatibilität mit älteren Apps
bleiben erhalten. Herkunft und Zuordnungsweg sind unterschiedliche Angaben.

Dieser Teilumfang enthält keinen vollständigen Herkunftskatalog, keine
automatische Generierung von Herkunftspaketen und keine AP-Buchungen für
Vor-/Nachteile. Ein bloßes Umbenennen der Rasse, Kultur oder Profession lädt
keine Wirkungen nach und entfernt keine bestehenden Einträge. Die bisher
ausstehende manuelle ARCH-02-Bedienprüfung bleibt eine eigene Abnahme.

## Befund und Architekturentscheidung

`HeroBackground` speichert Namen und die drei Modifikator-Texte; es gibt
keine Katalogdefinitionen für Rassen, Kulturen oder Professionen.
`modifier_parser.dart` erkennt in Herkunftstexten direkte `CODE+N`- bzw.
`CODE-N`-Fragmente. Herkunfts-Eigenschaftsboni beeinflussen laufende Werte
und Startwerte. Benannte Vor-/Nachteile werden in diesen Texten bislang
nicht wie in den Vor-/Nachteilfeldern ausgewertet.

Die Übersicht schreibt und berechnet ihre Vorschau über diese Texte.
`modifier_source_breakdown.dart` zerlegt Wirkungen nach Herkunft;
`resource_activation_rules.dart` erkennt AsP-/KaP-Codes unabhängig von
deren Summe. Nur den Hauptparser umzustellen wäre deshalb unvollständig.

Gewählt wird eine strukturierte Darstellung direkter Herkunftsmodifikatoren
mit unverändert erhaltenen freien Fragmenten. Bestehende `HeroMerkmal`-Listen
bleiben der einzige Speicherort katalogisierter Vor-/Nachteile; ihre Herkunft
wird dort als Metadatum ergänzt. Eine zusätzliche Kopie in einer Herkunftsliste
würde Doppelwirkungen und widersprüchliche Bearbeitung ermöglichen.

Ein vollständiger Herkunftskatalog wäre eine spätere fachliche Erweiterung.
Eine reine Herkunftsmarkierung an `HeroMerkmal` reicht dagegen nicht aus:
sie strukturiert die heutigen direkten Modifikatoren nicht.

## Datenvertrag

Die vorgeschlagenen neuen Modelle liegen in `lib/domain/hero_herkunft.dart`.
Sie enthalten Daten und Serialisierung, keine Regelberechnungen.

`HeroBackground` erhält optional `herkunftsModifikatoren`. Im flachen
Helden-JSON wird dieses Objekt auf Root-Ebene gespeichert, mit `formatVersion: 1`
und den getrennten Listen `rasse`, `kultur`, `profession`. Die Herkunft ergibt
sich aus der Liste; sie wird nicht zusätzlich am Modifikatoreintrag gespeichert.

Ein `HeroHerkunftsModifikator` enthält:

| Angabe | Vertrag |
|---|---|
| `id` | Stabile Eintragsidentität; Umbenennung und Wertänderung erhalten sie |
| `art` | `eigenschaft`, `basiswert` oder `frei` |
| `ziel` | Normalisiertes Eigenschafts- oder Basiswertkürzel bei strukturierten Einträgen |
| `betrag` | Vorzeichenbehaftete ganze Zahl, einschließlich null |
| `text` | Erhaltenes Fragment bzw. Kompatibilitätsdarstellung |
| Unbekannte Felder/Enumwerte | Verlustfrei erhalten; keine automatische Umdeutung |

Neue Einträge bekommen neue IDs. Migration erzeugt reproduzierbare IDs aus
Herkunft, Fragmentposition und Fragmentinhalt; doppelte Fragmente an verschiedenen
Positionen bleiben unterschiedliche Einträge. Nach persistentem Speichern werden
IDs nicht erneut aus Inhalt oder Position erzeugt.

Fehlendes Objekt bedeutet Bestandsformat. Ein vorhandenes Objekt mit drei
leeren Listen bedeutet ausdrücklich keine Herkunftsmodifikatoren und muss
geschrieben werden. Einträge entfernen darf keinen Rückfall auf alte Texte
auslösen. Ohne Migration oder Bearbeitung wird das neue Objekt nicht geschrieben;
`fromJson`/`toJson` von Bestandsfixtures behalten ihren bisherigen Inhalt.

Unbekannte Formatversionen, Arten und Ziele bleiben im Rohformat erhalten
und sichtbar prüfbedürftig. Eine unbekannte Gesamtversion wird nicht als
Version 1 interpretiert; die Herkunftsbearbeitung bleibt dafür gesperrt.
Die bestehende Textprojektion liefert den kompatiblen Regelweg. Bekannte
Einträge und unbekannte Teilstücke dürfen nicht dieselbe Wirkung zweimal liefern.

`HeroMerkmal` erhält optional `herkunft` mit `rasse`, `kultur` oder `profession`.
Fehlen bedeutet nicht bekannt/angegeben; Migration rät diese Angabe nicht.
`zuordnung` beschreibt weiterhin ausschließlich Katalogwahl, Migration oder
freien Eintrag. Herkunft ändern beeinflusst weder Katalog-ID noch Regelwirkung
oder AP. Unbekannte Herkunftswerte bleiben erhalten.

## Migration und Kompatibilitätsabgleich

Das eigene Modul `lib/rules/derived/hero_herkunft_migration_rules.dart`
übernimmt Fragmenterkennung, Projektion und Abweichungsprüfung. Die direkten
Codes und Alias-Normalisierung werden mit dem bisherigen Parser geteilt;
es entsteht kein zweiter abweichender Satz unterstützter Codes.

Migration zerlegt nach den bisherigen Herkunftstrennern Zeilenumbruch, Komma
und Semikolon. Jedes eindeutige direkte Fragment wird strukturiert. Unbekannte
Fragmente bleiben frei, in ursprünglicher Reihenfolge und ohne inhaltlichen
Verlust. Wiederholungen werden nicht dedupliziert. Insbesondere darf die
Vor-/Nachteil-Migration mit ihrer Deduplizierung nicht unverändert verwendet werden.
Benannte Vorteile in Herkunftstexten werden nicht automatisch katalogisiert,
wenn dies eine bisher nicht vorhandene Wirkung aktivieren würde.

Die direkte Migration benötigt keinen geladenen Katalog. Laden führt keine
Schreiboperation aus; Regeln können eine flüchtige strukturierte Sicht verwenden.
`saveHero` persistiert die Migration einmalig, auch beim Import über den regulären
Speicherpfad. Wiederholung bleibt ein Fixpunkt und verändert keine AP oder
Laufzeitressourcen. Ein höherer vorhandener Schemawert wird nicht abgesenkt;
der additive Teilvertrag wird über seine eigene Formatversion erkannt.

Die drei Texte sind bei vorhandenem Objekt dessen Projektion. Ein Vergleich
der geordneten Fragmentfolge ignoriert ausschließlich äußere Leerzeichen und
die genannten Trenner; Inhalt, Vorzeichen, Reihenfolge und Wiederholungen
bleiben entscheidend. Speicherung ohne Änderung erhält bestehende Fragmente.
Explizit bearbeitete direkte Einträge projizieren als normalisiertes `CODE±N`.

Abweichender Alttext wird weder beim Speichern noch im Sync still übernommen.
Je Herkunft wählt der Nutzer „Text übernehmen“ oder „Liste behalten“.
„Text übernehmen“ migriert genau diese Herkunft neu; „Liste behalten“ erzeugt
deren Projektion erneut. Andere Herkunftslisten bleiben unverändert. Bis zur
Auflösung führt für Regeln die Liste; Speichern anderer Heldenfelder erhält
die Abweichung. Reine Trennzeichenänderung erzeugt keinen Konflikt.

Wenn eine veröffentlichte ältere App das neue Objekt ganz entfernt, wird aus
ihren Texten erneut migriert. Dieser Mischbetrieb kann Eintragsidentitäten und
Herkunftsmetadaten verlieren; er wird als Kompatibilitätsgrenze dokumentiert.
Eine ältere App, die unbekannte Felder bewahrt und nur Texte ändert, erzeugt
dagegen den sichtbaren Abgleich. Die bestehenden Sync-Feldschutzpfade müssen
das neue Objekt und neue Merkmalsmetadaten berücksichtigen.

## Gemeinsame Regelauswertung

`lib/rules/derived/hero_herkunft_rules.dart` liefert je Herkunft laufende
Eigenschaftsboni, Startwertboni, Basiswertboni, Ressourcenaktivierung und
unbekannte Fragmente. Alle Verbraucher verwenden diese Auswertung:
Hauptparser, Quellenaufschlüsselung, Startwerte, Ressourcenaktivierung,
abgeleitete Werte und Bearbeitungsvorschau.

Ein bekannter direkter Eintrag wirkt ausschließlich strukturiert. Freie
Fragmente bleiben im bisherigen Herkunfts-Parserkontext; aus ihnen werden
keine neuen benannten Vorteilswirkungen abgeleitet. Der rohe Herkunftstext
wird bei vorhandener Liste nicht noch einmal zusätzlich ausgewertet.

Eigenschaftsboni beeinflussen laufende und rohe-basierte effektive Startwerte,
ohne schon berechnete `startAttributes` nochmals zu erhöhen. Basiswertboni
werden wie bisher addiert. Bereits ein erkannter AsP-/KaP-Eintrag aktiviert
die entsprechende Ressource, auch bei `ASP+0`, negativen Beträgen oder einer
Summe von null. Herkunft an `HeroMerkmal` ist nur Quelleninformation:
seine Wirkung einschließlich Startwertverhalten bleibt im Vor-/Nachteilregelweg.

Die kleinen Regelmodule dürfen Daten und Parserhilfen verwenden, aber keine
Provider oder Widgets. UI und State delegieren Migration und Berechnung dorthin.
Cache-Schlüssel müssen strukturierte Änderungen berücksichtigen, auch wenn
die Textprojektion noch nicht erneuert wurde.

## Bearbeitung und Schreibpfade

Die bestehenden Herkunftsabschnitte der Übersicht erhalten Eintragslisten mit
Ziel und Betrag sowie freien Fragmenten. Hinzufügen steht im jeweiligen Header
als `+ Herkunftsmodifikator`. Die Vor-/Nachteilbearbeitung erlaubt zusätzlich
eine Herkunftsangabe am vorhandenen Merkmal, einschließlich „Nicht angegeben“.
Es entsteht kein zweiter Erwerbsdialog für dieselben Merkmale.

Die große Übersicht erhält ausgelagerte Herkunftskomponenten; sie hält nur
Entwurf und Speicherkoordination. Vorschau und Speichern verwenden denselben
strukturierten Entwurf. Abbrechen verwirft ausschließlich diesen Entwurf.
Offene Entwicklungsplanungen nutzen den vorhandenen Schutz mit „Abbrechen“
bzw. „Planung verwerfen und bearbeiten“; eine abgebrochene Freigabe verhindert
alle Folgeaktionen. Während einer Textabweichung wird die betroffene Herkunft
erst nach ausdrücklicher Auflösung bearbeitet.

`copyWith`, Root-Schlüsselregistrierung, unbekannte JSON-Felder, Hive,
Import/Export, Editor-Rebuild und Sync werden gemeinsam angepasst.
Stale Entwürfe dürfen parallele Änderungen nicht pauschal überschreiben;
der bestehende Editor-/Feldschutz bleibt maßgeblich. Konfliktanzeigen erhalten
verständliche Bezeichnungen für neue Felder.

## Abnahmekriterien und Prüfungen

1. Bestandsfixtures behalten vor und nach Migration alle Regelwerte und
   Quellenanteile. Laden/Speichern ohne Migration bleibt inhaltsgleich.
2. `MU+1, MU+1` wirkt zweimal; Rasse und Kultur mit gleichem Fragment bleiben
   getrennt. Reihenfolge, unbekannte Texte, negative Beträge und null bleiben erhalten.
3. `ASP+1, ASP-1`, `ASP+0` und negative KaP-Einträge aktivieren Ressourcen
   wie bisher. Herkunftseigenschaften beeinflussen Startwerte genau einmal.
4. Werte bearbeiten, Einträge löschen und die letzte Liste leeren bleiben
   nach Hive-Neuladen, Export und Import erhalten. Migration ist idempotent.
5. Umbenannte katalogisierte Vor-/Nachteile wirken über ihre ID; Herkunft
   ändern erzeugt weder Doppelwirkungen noch andere AP-/Startwertfolgen.
6. Unbekannte Felder, Arten, Ziele, Herkunftswerte und Formatversionen
   überstehen Serialisierung, Editor-Speichern und Sync ohne Verlust.
7. Zwei Geräte bearbeiten unterschiedliche Herkunftsgruppen sowie dieselbe
   Gruppe. Konfliktauflösung erhält die gewählte Fassung; ein Alttextwechsel
   bei bewahrtem Objekt bleibt entscheidbar. Tests bilden veröffentlichte
   ältere Apps und neuere Apps mit unbekannten Feldern gesondert nach.
8. Widgettests prüfen Vorschau/Speichern, beide Abgleichentscheidungen,
   Abbrechen, entfernte letzte Einträge und den offenen Planungsschutz.
   Manuelle Prüfung deckt große Schrift und schmale Ansicht ab.

Bestehende Tests für Parser, Startwerte, Ressourcenaktivierung, Modell,
Merkmalsmigration und App-Versionen bilden die Regression. Neue fokussierte
Tests begleiten die neuen Modelle und Regelmodule. Vor Implementierungsabschluss:
`flutter analyze`, relevante `flutter test`-Läufe und der Screen-LOC-Check.
Die Dokumentation in CLAUDE.md, technischer Übersicht, Teststrategie und Roadmap
wird zusammen mit der Implementierung aktualisiert; ARCH-02 bleibt bis zur
gesamten Abnahme offen.

## Nächster Schritt

Die Spezifikation ist freigegeben. Der Implementierungsplan gliedert
Datenvertrag, Migration/Abgleich, gemeinsame Regeln, Schreibpfade/Sync,
Bearbeitung und Abnahme in überprüfbare Schritte. Nach Planprüfung folgt
die Umsetzung.
Dieser Entwurf ist kein Nachweis bereits implementierten Verhaltens.
