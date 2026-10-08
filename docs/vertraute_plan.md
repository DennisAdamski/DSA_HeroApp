# Vertraute: Bindung, Entwicklung, Spiel

Stand: Paket V1 in Arbeit (8. Oktober 2026); V2 und V3 sind offen. Das Dokument
hält die Regelquellen, die Nutzerentscheidungen und die Paketaufteilung für
Vertrautentiere von Hexen, Geoden, Zibiljas und Goblin-Schamaninnen fest. Alle
Belege kommen aus dem dsa-rules MCP. Vorbild ist das Reittier-Paket
([reittier_plan.md](reittier_plan.md)).

## Pakete

| Paket | Inhalt | Stand |
|---|---|---|
| V1 Grundlage | Artenkatalog, Bindung mit AP-Buchung bei der Hexe, AP-Anteil und Übertragung, Steigerung nach WdZ, Zauber je Art, ZBA-Ausbildung | in Arbeit |
| V2 Spielansicht | laufende LeP/AsP/AuP je Begleiter im `HeroState` (gemeinsam mit Reittier-P2), Regeneration, Vereinigung, Vertrautenzauber würfeln | offen |
| V3 Gefecht | Vertraute als handelnde Begleiter, magische Angriffe, besondere Kampfregeln, Schaden in die Laufzeitwerte | offen |

## Entscheidungen (Nutzer, 8. Oktober 2026)

- **Steigerung strikt nach WdZ S. 125.** Bestehende Buchungen bleiben stehen
  und rechnen weiter; ein Wert über der neuen Grenze bekommt nur einen Hinweis.
- **AP des Vertrauten:** fest ein Viertel der Abenteuer-AP der Hexe
  (Abenteuerabschluss und Reisebericht), ohne Abzug bei ihr. Für die Zeit
  davor gibt es einmalig „AP-Anteil einrichten“ mit Vorschlag.
  Die erinnerten 10 % stehen in keiner indizierten Quelle: WdZ S. 125 nennt
  ein Viertel, Epische Stufen S. 72 nennt 20 % nur für Dschinne.
- **Hexen-AP werden gebucht:** Die Bindung zählt als ausgegebene AP der
  Hexe, ebenso „AP übertragen“. Je volle 50 übertragene AP steigt die
  Loyalität um 1, höchstens auf 25. Bestandsvertraute lassen sich „ohne
  Buchung“ als gebunden erfassen.
- **Machtvoller Vertrauter: freie Werte.** WdZ S. 124 (geistige Werte bis +40,
  einzelne Werte bis 1,5 × Maximum) widerspricht WdH S. 255 (Maximum +3).
  Die App prüft deshalb bei Machtvollen weder Maxima noch Punkterahmen und
  rechnet nur die Kosten.
- **Tierfertigkeiten:** WdZ nennt „10–50 AP je nach Komplexität“. Die App
  schlägt 10 + 5 × Abrichten-Erschwernis vor (Komm 10, Sitz 10, Laut 15,
  Apport 25, Trick 45), änderbar zwischen 10 und 50.

## Unterschiede zwischen Bestand und WdZ

| Wert | bisher | WdZ S. 125 |
|---|---|---|
| INI | mit F steigerbar, unbegrenzt | nicht steigerbar (fehlt in der Aufzählung) |
| Loyalität | mit F steigerbar | nur über AP-Übertragung (S. 124 „Zur Loyalität“) und die CH-Probe nach einem Jahr Vereinigungen (S. 125) |
| AuP | Zuwachs bis 1,5 × Start | nicht steigerbar |
| AsP | Zuwachs bis 1,5 × Start | unbegrenzt („Astralenergie und Ritualkenntnis … beliebig“) |
| LeP, MR | Zuwachs bis 1,5 × Start (gesamt 2,5 ×) | gesamt höchstens 1,5 × Startwert |
| Eigenschaften, AT, PA | nur durch AP begrenzt | gesamt höchstens 1,5 × Startwert |
| GS | nicht steigerbar | direkt steigerbar, höchstens 1,5 × |
| MR-Kostenart | hinzugekauft | hinzugekauft („LE, AE und MR … wie bei Helden“) |
| RK | direkt, unbegrenzt | stimmt |

## Katalog

Die Daten stehen als Dart-Konstanten in `lib/catalog/vertrauten_katalog.dart`
(Typen in `vertrauten_typen.dart`). `assets/catalogs/house_rules_v1/vertrauten.json`
ist ein per `test/catalog/vertrauten_katalog_test.dart` geprüfter Spiegel; geladen
wird er nicht. Er enthält:

- die zwölf Arten aus WdZ S. 124 (`vart_…`) mit Spannen, festen Werten,
  Bindungskosten, besonderen Kampfregeln und Tiersinnen;
- die Zauberdaten (`vzaub_…`): Lernkosten, Arten, nur Machtvoll, halbe Kosten
  für Machtvolle, mit der Bindung. Das Ritual selbst bleibt im Preset
  `vertrautenmagie_preset.dart` und wird über den Namen verknüpft;
- die Ausbildungsstufen aus ZBA S. 21 (`vausb_…`), wobei das Kampftier für
  Vertraute gesperrt ist;
- die allgemeinen Fertigkeiten aus ZBA S. 21 f. (`vfert_…`).

Texte sind Stichworte, keine Buchzitate.

## Modell

`HeroCompanion.vertrautenBindung` (`VertrautenBindung`,
`lib/domain/hero_companion/vertrauten_bindung.dart`) wird nur bei Belegung
geschrieben und enthält alle Felder nur, wenn sie belegt sind. Sie hält, was
sich nicht aus den Grundwerten ablesen lässt:

- `artId` und `machtvoll`;
- `bindungskosten`: die bei der Hexe gebuchten AP, `null` bei einer Bindung
  ohne Buchung;
- `apUebertragen` als Grundlage der Loyalität;
- `abenteuerApErfasst`: Zähler des AP-Anteils, `null`, solange der Anteil
  nicht eingerichtet ist;
- `ausbildungen` als Liste von `VertrautenAusbildungsbuchung` (Katalog-ID,
  AP, Bezeichnung).

Die Startwerte stehen wie bei jedem Begleiter in seinen Grundwerten.
Gekaufte GS-Stufen trägt `HeroCompanionSpeed.steigerung`, analog zu
`steigerungAt`/`steigerungPa` der Angriffe. Die veröffentlichte App kennt
beide Felder nicht, deshalb führt `veroeffentlichte_app.dart` sie als neu.

## Steigerung

Die Regeln stehen in `lib/rules/derived/companion_steigerung_rules.dart`:

- `vertrautenWertSteigerbar`: INI, Loyalität und AuP sind gesperrt.
- `vertrautenMaxStand`: höchster Steigerungsstand, nämlich ⌊1,5 × Startwert⌋
  − Startwert. AsP und RK sind unbegrenzt.
- `vertrautenSteigerungshinweis(e)`: Hinweise auf Altbuchungen, die den Regeln
  widersprechen.

`steigereBegleiter` weist eine Erhöhung über die Grenze mit einem
`StateError` ab. Diese Prüfung gilt neben der des Dialogstands. GS steigt je
Bewegungsart über `BegleiterSteigerungsziel.geschwindigkeit(art)`; da
Geschwindigkeiten keine ID haben, trifft das Ziel die erste mit dieser Art.
Bestehende Stufen werden nie umgedeutet. Sie zählen weiter in allen Werten,
und der Abschnitt „Kampf- und Bewegungswerte“ listet die Hinweise rot auf.
Die Knöpfe zum Steigern von INI, Loyalität und AuP gibt es nicht mehr. Die
Aktionen liegen in `hero_begleiter/vertrauten_steigerung_aktionen.dart`.

## Offene Punkte

- Die GS der Kröte (0,3) ist als ganze Zahl nicht darstellbar und steht im
  Katalog als 0 mit Hinweis.
- Tag- und Nachtwerte von Eule, Rabe und Falke sind nur als Hinweis
  hinterlegt.
- Der „Göttliche Begleiter“ (Hausregel Erweiterung S. 17) bekommt AP wie ein
  Vertrauter, ist aber nicht modelliert.

## Regelquellen

- WdZ S. 123:
  - Bindung über die SF Vertrautenbindung: 80 AP (Katze, Schlange, Eule,
    Falke, Hund, Affe, Rabe, Wiesel, Iltis), 100 AP (Kröte, Spinne), 120 AP
    für einen Machtvollen Vertrauten.
  - Mit der Bindung erhält das Tier AE, RK (Vertrautenmagie) 3 und
    Zwiegespräch, eine Kröte zusätzlich Krötenschlag.
  - Generierung: bis zu 20 Punkte für je 2 AP, höchstens bis zum
    Tabellenmaximum. Zusätzlich je bis +3 AsP und LeP für je 5 AP sowie AuP
    für je 2 AP.
- WdZ S. 124:
  - Startwerttabelle und besondere Kampfregeln.
  - Loyalität beginnt bei 15 und steigt je 50 übertragene AP um 1, höchstens
    auf 25.
  - ZBA-Ausbildung kostet TaP* × 10 AP des Vertrauten, Tricks 10–50 AP; das
    Kampftier ist üblicherweise nicht wählbar.
  - Machtvolle Vertraute siehe Entscheidungen.
- WdZ S. 125:
  - Entwicklung mit Tabelle F (siehe Tabelle oben).
  - Regeneration: ein aufgerundetes Zehntel der maximalen LE bzw. AE, +1 bei
    Körperkontakt.
  - Angriffe gelten als magisch; Aurapanzer für 125 AP ab AE 20.
  - Vereinigung bei Vollmond: Hexe und Tier zahlen je 1W6 AsP, ein
    versäumtes Treffen kostet −1 LeP und −1 LO.
  - AP-Übertragung nur von der Hexe zum Tier, permanent.
- WdZ S. 126–128:
  - Vertrautenzauber werden mit AP des Vertrauten im Vollmondritual erlernt.
  - In Kontakt gelten die Eigenschaften der Hexe; zaubert der Vertraute
    allein, gelten seine Eigenschaften mit +15 Erleichterung.
- WdH S. 255: Machtvoller Vertrauter (5 GP).
- ZBA S. 19–21: Loyalitätstabelle, Ausbildungsstufen, allgemeine Fertigkeiten.
