# Vertraute: Bindung, Entwicklung, Spiel

Stand: Pakete V1 und V2 umgesetzt (8. Oktober 2026); V3 ist offen. Das Dokument
hält die Regelquellen, die Nutzerentscheidungen und die Paketaufteilung für
Vertrautentiere von Hexen, Geoden, Zibiljas und Goblin-Schamaninnen fest. Alle
Belege kommen aus dem dsa-rules MCP. Vorbild ist das Reittier-Paket
([reittier_plan.md](reittier_plan.md)).

## Pakete

| Paket | Inhalt | Stand |
|---|---|---|
| V1 Grundlage | Artenkatalog, Bindung mit AP-Buchung bei der Hexe, AP-Anteil und Übertragung, Steigerung nach WdZ, Zauber je Art, ZBA-Ausbildung | umgesetzt |
| V2 Spielansicht | laufende LeP/AsP/AuP je Begleiter im `HeroState` (gemeinsam mit Reittier-P2), Regeneration, Vereinigung, Vertrautenzauber würfeln | umgesetzt |
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
- **Machtvoller Vertrauter: Vorlage + freie Werte.** WdZ S. 124 (geistige
  Werte bis +40, einzelne Werte bis 1,5 × Maximum) widerspricht WdH S. 255
  (Maximum +3). Ein Machtvoller ist meist eine größere Art außerhalb des
  Katalogs, etwa ein Luchs oder eine Boronsotter.
  - Eine Katalogart dient als verwandte Vorlage. Name und alle Startwerte
    sind frei, auch nach unten: Eigenschaften, LeP/AsP/AuP, INI, MR, RS,
    Angriffe (AT/PA/TP) und Geschwindigkeiten.
  - Kosten: 120 AP + 2 AP je Punkt über der Vorlage bei geistigen
    Eigenschaften (MU, KL, IN, CH), AE und MR + 5 AP je Punkt über dem
    Maximum einer geistigen Eigenschaft. Körperliche Eigenschaften und
    Kampfwerte passt der Meister ohne Kosten an (WdZ S. 124).
  - Maxima und Punkterahmen prüft die App nicht.
  - Für die Vertrautenzauber zählt die Vorlage: Ein Chamäleon mit Vorlage
    Kröte darf Krötenzauber lernen, ein Luchs mit Vorlage Katze nicht.
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

## Bindung, AP und Ausbildung

- `vertrauten_bindung_rules.dart`:
  - `vertrautenBindungskosten` stellt die Kosten auf: Grundkosten, 2 AP je
    Punkt, 5 AP je Punkt über dem Maximum (nur Machtvolle), AsP/LeP je 5 AP,
    AuP je 2 AP.
  - `vertrautenGenerierungsFehler` prüft 20 Punkte, die Tabellenmaxima und
    +3 je Zusatzwert; bei Machtvollen nur auf negative Werte.
  - Machtvolle setzen über `VertrautenGenerierung.werte`, `angriffe`,
    `geschwindigkeiten` und `artName` freie Startwerte. Die Kosten laufen
    über `kVertrautenGeistigeKeys` gegen `vertrautenVorlagenwert`. Das
    Formular dafür steht in `hero_begleiter/vertrauten_machtvoll_form.dart`.
  - `bucheVertrautenBindung` setzt die Startwerte: Eigenschaften, INI, MR,
    LeP/AsP/AuP samt `start*`, LO 15, Angriffe in DK H, Geschwindigkeiten,
    natürlichen RS sowie die Vertrautenmagie mit RK 3, Zwiegespräch und
    (Kröte) Krötenschlag. Die Kosten bucht sie als `apSpent` der Hexe, in
    derselben Änderung.
  - `erfasseVertrautenBindung` hält für Bestandsvertraute nur Art und
    Machtvoll fest, ohne Buchung.
- `vertrauten_ap_rules.dart`:
  - `mitVertrautenApAnteil` hängt an `applyAdventureRewards`,
    `revokeAdventureRewards`, `applyReiseberichtRewards` und
    `revokeReiseberichtRewards`. So bucht jeder Weg, der Abenteuer-AP bucht,
    das Viertel mit. Der Zähler sinkt nie unter 0.
  - `richteVertrautenApAnteilEin` macht den einmaligen Nachtrag; den Vorschlag
    liefert `vertrautenNachtragsvorschlag` aus den angewendeten
    Abenteuerbelohnungen und `gebuchteReiseberichtAp`.
  - `uebertrageApAufVertrauten` bucht bei der Hexe und hebt die LO je volle
    50 AP, höchstens auf 25; eine höhere LO sinkt nicht.
- `vertrauten_ausbildung_rules.dart`:
  - `vertrautenZauberZugaenge` liefert je Zauber Lernkosten (halb für
    Machtvolle bei Erster unter Gleichen), Bekanntheit und Sperrgrund (Art,
    nur Machtvoll).
  - `lerneVertrautenZauber` kopiert das Ritual aus dem Preset und zahlt aus
    den AP des Vertrauten.
  - `vertrautenAusbildungSperrgrund`: Kampftier nie, nur eine
    Ausbildungsstufe (Hund zwei), Fertigkeit nur einmal, Ablegen setzt Sitz
    voraus, höchstens KL Tricks.
  - `bucheVertrautenAusbildung` übergeht Sperren nur per Meisterentscheid,
    das Kampftier nie.
  - `vertrautenAusbildungsModifikationen` summiert die gebuchten Stufen.
- `begleiter_wirkwert_rules.dart` rechnet die Tierausbildung ab:
  - Eigenschaften und INI über `begleiterWirksamerWert`;
  - LeP/AuP über `begleiterWirksamerPoolwert`;
  - AT/PA/TP aller Angriffe, PA über `begleiterWirksamerAngriffPa`;
  - GS aller Bewegungsarten.

  Kampfprofil und Gefecht zeigen diese Werte. Grundwerte bleiben unverändert,
  damit die Steigerungsgrenzen am Startwert hängen.

## Oberfläche

Die Oberfläche ist der klassische Begleiter-Tab, den auch der
Kartograph-Workspace über `workspace_tab_spec.dart` nutzt. Bei Vertrauten
zeigt er nach „Kampf- und Bewegungswerte“ den Abschnitt „Vertrautenbindung“
(`hero_begleiter/vertrauten_bindung_section.dart`, Dialoge in
`vertrauten_bindung_dialoge.dart`, Buchungen in
`vertrauten_bindung_aktionen.dart`):

- **Ungebunden:**
  - „Vertrauten binden“: Art, Machtvoll (vorbelegt aus dem Vorteil der Hexe),
    Punkte mit −/+, Zusatz-AsP/LeP/AuP, laufende Kosten und Fehler.
  - „Ohne Buchung erfassen“: nur Art und Machtvoll.
- **Gebunden:**
  - Art, Bindungskosten, AP-Anteil, Übertragung, Ausbildungen, Kampfregeln
    und Tiersinne.
  - Knöpfe „AP-Anteil einrichten“ (nur einmal), „AP übertragen“ und im Kopf
    „+ Ausbildung“. Das Kampftier steht nicht zur Wahl; Sperren lassen sich
    per Meisterentscheid übergehen.
- **Vertrautenmagie:** „+ Zauber“ im Kopf lernt einen Zauber mit
  Zugangsprüfung und Kosten. „Ohne AP erfassen“ ist für schon früher gelernte
  Zauber. Im Bearbeitungsmodus heißt die alte Liste „Ritual ohne AP
  eintragen“ und bleibt als manuelle Korrektur.
- **Sperre:** Alle Buchungen sind Sofortbuchungen über
  `aendereHeldMitMeldung`. Sie ruhen bei ungespeicherten Änderungen und sind
  bei offener Planung gesperrt.

### Manueller Ablauf (Abnahme)

1. Eine Hexe mit freien AP öffnen. Im Begleiter-Tab einen Begleiter anlegen,
   „Typ: Vertrauter“ wählen und speichern.
2. **Binden:** „Vertrauten binden“ öffnen, Katze wählen, zwei Punkte auf GE
   legen. Der Dialog zeigt 84 AP. Nach „Binden“ sind die AP der Hexe um 84
   gesunken. Der Vertraute hat GE 13, LO 15, RK 3, Zwiegespräch, Prankenhieb
   AT 11 und RS 1.
3. **AP vergeben:** „AP-Anteil einrichten“ öffnen. Vorgeschlagen ist ¼ der
   bisher gebuchten Abenteuer- und Reisebericht-AP; bestätigen. Danach
   „AP übertragen“ mit 50 AP: Die Hexe verliert 50 AP, der Vertraute gewinnt
   50, LO steigt auf 16. Ein danach abgeschlossenes Abenteuer mit 200 AP
   schreibt dem Vertrauten automatisch 50 AP gut.
4. **Steigern:** „Bearbeiten“ wählen und MU über den Pfeil steigern. Bis
   1,5 × Startwert geht es, darüber meldet die App die Grenze. INI und
   Loyalität haben keinen Pfeil mehr.
5. **Zauber lernen:** „+ Zauber“ öffnen und Tiersinne wählen (15 AP des
   Vertrauten). Tarnung ist für die Katze gesperrt und lässt sich nur per
   Meisterentscheid lernen.

Abgedeckt durch `test/ui/begleiter/vertrauten_bindung_test.dart`.

## Nachträge zu V1 (Branch V2)

- **Voraussetzungen beim Binden** (`vertrauten_bindung_voraussetzung_rules.dart`):
  Fehlt der Hexe die SF Vertrautenbindung (`magsf_vertrautenbindung`, erkannt
  über Katalogname und `alias_namen`, ohne Katalog über den Namen) oder führt
  sie den Nachteil „Kein Vertrauter“ (`dis_kein_vertrauter`), zeigt der
  Bindungsdialog Hinweise. Gesperrt wird nie: „Binden“ geht dann nur über das
  Häkchen „Trotzdem binden (Meisterentscheid)“, `bucheVertrautenBindung` bleibt
  unverändert.
- **Aurapanzer** (`vertrauten_aurapanzer_rules.dart`, WdZ S. 125): 125 AP aus
  den AP des Vertrauten, Voraussetzung wirksame AE 20. Gespeichert als
  `HeroCompanionSonderfertigkeit` mit `katalogId: magsf_aurapanzer`. Der Katalog
  kennt den Eintrag mit 500 AP (Held, WdH 285), der Vertrauten-Preis ist
  eine bewusste Abweichung. Offene Voraussetzungen (AE, freie AP) gehen nur per
  Meisterentscheid; doppelter Erwerb und Nicht-Vertraute nie. Sofortbuchung über
  `aendereHeldMitMeldung` mit Prüfung des Dialogstands (`apAusgegeben`).

## V2: laufende Werte und Spieltisch

### Entscheidungen (Nutzer, 8. Oktober 2026)

- **E1 Versäumtes Treffen:** zwei getrennte Buchungen, kein Journal. LeP laufen
  über `aendereZustandMitMeldung`, die LO über `aendereHeldMitMeldung`. Scheitert
  die zweite, bleibt die erste stehen; der Dialog „Treffen versäumt“ bietet die
  fehlende Buchung einzeln zum Nachholen an.
- **E2 Regeneration:** läuft mit der Rast der Hexe. Der Rastdialog zeigt je
  Vertrautem „regeneriert“, „Körperkontakt“ und die Wahl +1 LeP / +1 AsP. Die
  Regeneration steht im selben Zustandsdokument wie die Rast
  (`RastAbschliessen.uebernehmeRast(vertrautenRast:)`). Es gibt keinen eigenen
  Knopf; „Volle Erholung“ lässt Begleiter unberührt.
- **E3 Reittiere:** Die laufenden Werte (LeP/AsP/AuP mit Schrittknöpfen) gelten
  für **jeden** Begleiter, auch Reittiere und sonstige. Vertrautenaktionen bleiben
  gebundenen Vertrauten vorbehalten. Reittier-P2 ergänzt nur noch Wunden und Proben.

### Festlegungen im Paket (im PR zu bestätigen)

- **„voll“ ist `null`.** Ein Wert gleich dem wirksamen Maximum wird nicht
  gespeichert. Steigt das Maximum (Steigerung, Ausbildung), bleibt ein voller
  Begleiter voll.
- **Grenzen:** LeP bis −10 (wie beim Helden), AsP/AuP bis 0, nach oben das Maximum
  nur in Schrittrichtung (`RessourcenAenderung`).
- **Verwaiste Zustände** gelöschter Begleiter bleiben stehen und werden ignoriert.
  Ein Aufräumen erzeugte im Sync Konflikte („gelöscht/geändert“).
- **Sync:** `begleiterZustaende/<id>/currentLep|Asp|Aup` zählen als Zähler
  (`zaehlerInMaps`), wenn Basis, Lokal und Online einen Zahlenwert tragen; sonst
  normale Zusammenführung mit Konflikt bei verschiedener Änderung.
- **Ritualkosten** liest `parseRitualKosten` nur, wo der Preset-Text eindeutig ist
  („3 AsP“, „2 AsP pro Spielrunde“, „3 AsP + 2 AsP pro Spielrunde“, „Alle AsP“);
  sonst fragt der Dialog. Der Betrag ist immer änderbar; abgezogen wird erst nach
  Bestätigung. Die Probe protokolliert unabhängig davon der Probendialog.
- **UI2-Reihenfolge:** „Begleiter“ steht in der Seitenspalte nach „Zustand“, vor
  dem Würfelprotokoll (laufende Werte wie dort).
- **Aurapanzer** (Nachtrag A2): `katalogId` `magsf_aurapanzer` mit dem Preis
  125 AP aus WdZ S. 125 statt der 500 AP des Katalogs für Helden.

### Modell und Regeln

- `HeroState.begleiterZustaende` (`BegleiterZustand` mit `currentLep`, `currentAsp`,
  `currentAup`; `null` = voll; nur bei Belegung im JSON; Wunden kommen später
  additiv dazu). Der Wächter, `zustandMitZukunftsfeldern` und
  `veroeffentlichte_app.dart` kennen den Eintrag.
- `begleiter_zustand_rules.dart`: `mitBegleiterPool`, `begleiterAktuellerPool`,
  `begleiterPoolSchritt`.
- `vertrauten_spiel_rules.dart`: Regeneration (⌈max/10⌉ je Phase, Körperkontakt
  +1 LeP **oder** +1 AsP), Vereinigungsverlust, versäumtes Treffen, LO +1,
  `VertrautenRast`.
- `vertrauten_zauber_probe_rules.dart`: RK-Probe (Kontakt: Eigenschaften der Hexe
  nach Wunden; allein: Eigenschaften des Vertrauten, Erleichterung +15), KL-/LO-
  und CH-Probe, `parseRitualKosten`.
- Ablauf `VertrautenVereinigung` (ein Dokument: Hexe-AsP, Vertrauten-AsP, zwei
  Protokolleinträge).

### Oberfläche

- **Begleiter-Tab:** Abschnitt „Laufende Werte“ (alle Begleiter) und
  „Vertrautenaktionen“ (Vereinigung, Treffen versäumt, CH-Probe → LO +1, Zauber
  würfeln, KL-/LO-Probe). LO-Buchungen ruhen bei ungespeicherten Änderungen.
- **Rastdialog:** Abschnitt „Vertraute“ (`rest_vertraute_section.dart`).
- **UI2:** `KartoBegleiterAbschnitt` (`ui2/spielen/karto_begleiterkarte.dart`),
  Bedienung über die Brücke (`begleiterWertAendern` ohne Guard,
  `vertrautenAktionen` öffnet dieselben Aktionen in einem Dialog).
- **Gefecht:** `GefechtBegleiter` zeigt zusätzlich „Aktuell: LeP x/y · …“; sonst
  nichts Neues (handelnde Begleiter: V3).

### Manueller Ablauf (Abnahme)

1. Begleiter-Tab, gebundener Vertrauter: „Laufende Werte“, bei LeP „−5“. Die
   Anzeige springt von 24/24 auf 19/24; der Zustand der Hexe bleibt unberührt.
2. Rastdialog, „Schlaf“: Beim Vertrauten „Körperkontakt“ wählen und
   „Übernehmen“. Er gewinnt ⌈24/10⌉ = 3 LeP plus 1 durch den Kontakt.
3. „Vereinigung“: Würfe eintragen (oder würfeln lassen) und buchen. Hexe und
   Vertrauter verlieren je ihren Wurf an AsP; im Würfelprotokoll stehen zwei
   Einträge.
4. „Zauber würfeln“, Tiersinne, Körperkontakt an: Die Probe zeigt KL/IN/IN der
   Hexe und den Pool RK. Danach schlägt der Dialog 3 AsP vor; nach „AsP abziehen“
   sinken die AsP des Vertrauten (ohne Kontakt: Eigenschaften des Tiers, +15).

Abgedeckt durch `test/ui/begleiter/vertrauten_spiel_test.dart`,
`test/ablaeufe/vertrauten_vereinigung_test.dart`,
`test/ablaeufe/rast_abschliessen_test.dart`, `test/rules/vertrauten_spiel_rules_test.dart`,
`test/ui2/spielen/karto_begleiterkarte_test.dart` und
`test/ui/shared/zustand_frisch_schreiben_test.dart`.

## Offene Punkte

- Die GS der Kröte (0,3) ist als ganze Zahl nicht darstellbar und steht im
  Katalog als 0 mit Hinweis.
- Tag- und Nachtwerte von Eule, Rabe und Falke sind nur als Hinweis
  hinterlegt.
- „GE +2 oder FF +2“ des Zirkustiers steht nur im Hinweis, weil die Wahl
  nicht modelliert ist.
- Die Rücknahme eines Abenteuers, das vor dem Einrichten des AP-Anteils
  gebucht wurde, zieht dem Vertrauten nichts ab, weil der Zähler bei 0
  stehen bleibt.
- Wunden und Zonen der Begleiter fehlen im Laufzeitmodell (V3/Reittier-P3);
  Schaden an Begleitern wird von Hand über die Schrittknöpfe gebucht.
- Die LO-Probe (Gefahr) und die KL-Probe sind Würfelhilfen; die Folgen
  (Loyalitätsänderung) entscheidet der Meister, die App bucht sie nicht.
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
- V2-Belege (dsa-rules MCP): Regeneration, Vereinigung und Aurapanzer WdZ S. 125;
  Vertrautenmagie, Kontakt-/Alleinregel (+15) WdZ S. 126; Rituale mit Probe und
  Kosten WdZ S. 126–128; Krötenschlag (alle AsP, SP = eingesetzte AsP) S. 127;
  Aurapanzer-Wirkung Wege der Zauberei S. 32. Die Hausregeln enthalten keine
  abweichende Vertrautenregel.
- WdZ S. 126–128:
  - Vertrautenzauber werden mit AP des Vertrauten im Vollmondritual erlernt.
  - In Kontakt gelten die Eigenschaften der Hexe; zaubert der Vertraute
    allein, gelten seine Eigenschaften mit +15 Erleichterung.
- WdH S. 255: Machtvoller Vertrauter (5 GP).
- ZBA S. 19–21: Loyalitätstabelle, Ausbildungsstufen, allgemeine Fertigkeiten.
