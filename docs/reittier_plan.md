# Reittiere: Ausbildung, Reiterkampf, Spiel

Stand: Paket P1 umgesetzt (8. Oktober 2026), P2 und P3 offen. Dieses Dokument hält die Regelquellen, die getroffenen
Entscheidungen und die Paketaufteilung für Pferde und andere Reittiere fest.
Belege stammen aus dem dsa-rules MCP.

## Ziel

Ein Reittier soll sich regelkonform entwickeln, im Kampf einsetzbar sein und im
Spiel interaktiv mitlaufen. Bisher speichert die App Begleiter nur und zeigt sie
an; Ausbildung ist Freitext, und Reiterkampf ist nicht modelliert.

## Pakete

| Paket | Inhalt | Stand |
|---|---|---|
| P1 Pferd-Grundlage | Reit-SF im Katalog, Ausbildungskatalog, Ausbildungsmodell am Begleiter, abgeleitete Wirkwerte, Ausbildungsschritte und Pferde-SF im Begleiter-Tab, gewürfelte Ausbildungsproben | umgesetzt |
| P2 Spielansicht | laufende LeP/AuP/Wunden je Begleiter im `HeroState` (**LeP/AuP/AsP-Modell `HeroState.begleiterZustaende` mit Anzeige für alle Begleiter seit Vertraute-V2, Wunden offen**), Begleiterkarte in `lib/ui2/spielen/`, LO-Probe, Reiten-Probe mit Stufenmodifikator, Pferdeangriffe würfeln, Rittmeister-Boni | offen |
| P3 Gefecht | Schalter „Beritten“, Reiter-SF-Boni nach Hausregel, Reit-AT/PA, Pferdemanöver, Sturmangriff zu Pferd, Pferd als Ziel | offen |

## Entscheidungen

- **Steigerung nur über Ausbildung (ZBA).** Reittiere bekommen keine AP. Die
  AP-Steigerung mit Komplexität F bleibt den Vertrauten vorbehalten.
- **Regelbasis Reiterkampf:** Hausregel „Erweiterung und Überarbeitung des
  Regelwerks“ S. 19 f. (PDF-Fassung) vor WdS S. 100 ff.; ergänzt um ZBA
  S. 39 f. Die ältere Einzeldatei „Reiterkampf Überarbeitung.odt“ gilt nicht.
- **Kampfpferd** (Reiten-Probe im Kampf −3 statt −1): leichtes, mittelschweres
  und schweres Streitross, tulamidisches und novadisches Kriegspferd,
  Schützenpferd, Streitwagenpferd.
- **Widersprüche in der ZBA:** Gezielter Biss gilt als *allgemein* (S. 39, nicht
  S. 36). Bei Nervosität lernt ein Pferd Schrecksicher und Stillstand nur mit
  Abrichten +8 (S. 37).
- **Rittmeister** setzt die SF Kriegsreiterei voraus; die Hausregel lässt ihn
  ohne geschultes Pferd ohnehin nur als Kriegsreiterei gelten.
- **Halbierte Ausbildungsmodifikationen** (fundiert begonnen, ländlich
  weitergeführt) werden abgerundet.
- **GS(+a/+b) und AU(+a/+b)** der Ausbildungsvarianten gelten für Trab/Galopp.
- **Pferde-Vor-/Nachteile** bleiben Freitext; Regeln erkennen Lernfähig,
  Nervosität, Gutmütig und Magiegespür über den Text.
- **Novadisches Kriegspferd:** „wie das tulamidische, aber zusätzlich … LO +3“
  wird als zusätzliche Loyalität gelesen, zusammen also LO +5.
- **Ausbildungsproben** lassen sich würfeln, eine Buchung geht aber auch ohne
  Würfeln (bezahlter Zureiter, ZBA S. 37).

## Katalog

Die Ausbildungsdaten stehen als Dart-Konstanten in
`lib/catalog/reittier_ausbildung_katalog.dart` (Stufenschritte,
Reiten-Modifikatoren, Varianten) und `lib/catalog/pferde_sf_katalog.dart`
(Pferde-SF, Unarten); die Typen in `reittier_ausbildung_typen.dart`, die Enums
für Stufe und Art in `lib/domain/hero_companion/reittier_ausbildungsstufe.dart`.
`assets/catalogs/house_rules_v1/reittier_ausbildung.json` ist ein Spiegel, den
`test/catalog/reittier_ausbildung_katalog_test.dart` gegen die Konstanten
prüft; geladen wird er nicht. Gespeicherte Helden verweisen nur über die IDs
`pvar_…`, `psf_…` und `punart_…`. Texte sind kurze eigene Zusammenfassungen.

## Regeln und Wirkwerte

- `lib/rules/derived/reittier_ausbildung_rules.dart`: aktuelle Stufe und Art,
  Herleitung und Summe der Ausbildungsmodifikationen, nächste Schritte mit
  Sperrgrund und Hinweisen, Reiten-Modifikator (normal/Kampf, ländlich,
  Kampfpferd, Magierpferd), Lernbarkeit von Pferde-SF, Gangart- und
  Kraftfaktor-Erkennung.
- `lib/rules/derived/begleiter_wirkwert_rules.dart`: Wirkwerte = Grundwert +
  Steigerung + Ausbildung. Die Ausbildung ändert KK und LO, AT aller
  Angriffe, TP nur bei Tritten/Hufschlägen (am Namen erkannt), GS bei Trab
  und Galopp (am Namen erkannt) sowie Trag- und Zugkraftfaktor.
  `companionEffektivwert` bleibt ohne Ausbildung, weil die
  Vertrauten-Steigerung darauf aufbaut.
- `lib/rules/derived/tp_ausdruck_rules.dart`: TP-Zuschlag in „1W6+4“-Angaben.
- `begleiterKampfprofil` zeigt die Wirkwerte und ein `ReittierProfil`
  (Stufe, Art, Variante, Kampfpferd, Reiten normal/Kampf).
- Ausbildung wirkt nur bei `BegleiterTyp.reittier` mit erfasster
  Ausbildung; die Variante nur, wenn der Schritt nach „geschult“ in der App
  gebucht wurde. AU-Modifikationen erscheinen nur als Hinweis, weil der
  Begleiter einen einzigen AU-Wert führt.

## Oberfläche

Der klassische Begleiter-Tab (`lib/ui/screens/hero_begleiter_tab.dart`), den
auch der Kartograph-Workspace über `workspace_tab_spec.dart` nutzt, zeigt bei
Reittieren den Abschnitt „Reittier-Ausbildung“
(`hero_begleiter/begleiter_ausbildung_section.dart`, Dialoge in
`begleiter_ausbildung_dialoge.dart`):

- **Editorfelder** (über `speichereEditorEntwurf`): Ausbildung erfassen
  (Ausgangsstufe, -art, Variante), Ausgangsstand ändern, Unarten (`+ Unart`),
  Ausbildung entfernen.
- **Sofortbuchungen** (`begleiter_ausbildung_aktionen.dart`, über
  `aendereHeldMitMeldung`, bei offener Planung gesperrt): `+ Ausbildungsschritt`,
  Rücknahme des letzten Schritts und `+ Pferde-SF` im
  Sonderfertigkeiten-Abschnitt. Sie gehen in der Ansicht und im
  Bearbeitungsmodus, solange keine ungespeicherten Änderungen offen sind.
  Gesperrte Schritte und nicht regulär lernbare SF lassen sich nur mit
  „Trotzdem (Meisterentscheid)“ buchen.
- **Ansicht:** Eigenschaften, Loyalität, Angriffe (AT, TP), Geschwindigkeiten
  sowie Trag- und Zugkraft zeigen die Wirkwerte; der Bearbeitungsmodus den
  eingetragenen Grundwert. Der alte Freitext heißt bei Reittieren
  „Ausbildung (Notiz)“.
- **Gefecht (UI2):** eine Zeile mit Stufe, Variante und Reiten-Modifikatoren.
- **Ausbilderproben würfeln:** Im Schrittdialog hat jede geforderte Probe
  einen Würfelknopf, im Pferde-SF-Dialog die Lernprobe (Abrichten +5 bzw. +8).
  Der Request entsteht über `ausbilderprobeFuer`
  (`lib/rules/derived/reittier_ausbilderprobe_rules.dart`) und
  `talentprobeFuer` mit vorbelegter Erschwernis; gewürfelt und protokolliert
  wird mit `showLoggedProbeDialog`. Eine misslungene Probe zählt im
  Schrittdialog als Fehlschlag. Führt der Held das Talent nicht, steht der
  Grund im Dialog; gebucht werden kann trotzdem (Zureiter).

Texte setzt `reittier_ausbildung_anzeige_rules.dart` zusammen.

## Offene Punkte nach P1

- **Rittmeister:** Boni auf das Pferd (AT/PA/TP, GS, MR je Kategorie) und die
  Rückfallregel ohne geschultes Pferd kommen mit P2/P3; ein Hausregel-Patch
  liefe ohne aktives Epik-Paket ins Leere.
- **AU:** Der Begleiter führt einen einzigen AU-Wert; AU-Modifikationen für
  Trab/Galopp stehen nur in der Herleitung.
- **Gangarten:** Trab und Galopp werden am Namen der Geschwindigkeit erkannt.
  Ein Vorlagenknopf „Gangarten anlegen“ (Schritt/Trab/Galopp) fehlt noch;
  „Schritt 1,5“ aus der ZBA ist als ganze Zahl nicht darstellbar.
- **Rassenvorlagen:** Die ZBA-Rasseneinträge nennen Werte und geeignete,
  mögliche und unmögliche Ausbildungsvarianten. Ein Rassenkatalog zum
  Vorbelegen ist nicht umgesetzt; der Capriola-Ausschluss prüft nur Familie
  und Gattung als Text.
- **Pferde-Vor-/Nachteile** bleiben Freitext.

## Regelquellen

### Reit-Sonderfertigkeiten (WdS S. 102)

| SF | Voraussetzung | Kosten | Kern |
|---|---|---|---|
| Reiterkampf | TaW Reiten 7 | 200 AP | Reiten-Zuschläge im Kampf halbiert; gegen Fußkämpfer AT +3, +2 TP mit geeigneten Waffen |
| Turnierreiterei | TaW Reiten 10, SF Reiterkampf | 100 AP | Lanzenreiten +5; Ansagen bis zur Lanzenreiten-AT |
| Kriegsreiterei | TaW Reiten 10, SF Reiterkampf | 300 AP | Zuschläge geviertelt; Pferd PA +3; Niederreiten, Hufschlag, Trampeln |

Im Katalog: `ksf_reiterkampf`, `ksf_turnierreiterei`, `ksf_kriegsreiterei` in
`assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json`, mit
v3-verschlüsselten Erklärtexten in eigenen Worten wie alle Kampf-SF. Ob sie aktiv
sind, entscheidet wie bei jeder Kampf-SF `isCombatSpecialAbilityActive`. Das
System-Paket `regelwerk_ueberarbeitung_v1.system` überlagert die Beschreibung
von Reiterkampf und Kriegsreiterei mit der Hausregel.

### Hausregel Reiterkampf (Erweiterung und Überarbeitung S. 19 f.)

- Taktische SF gelten weiter (BE-Grenzen beachten), Blindkampf nie.
- Das Pferd weicht nur aus, wenn es selbst angegriffen wird (Reiter −1 Aktion).
- Pferdetritte und -bisse +1W6 TP; Niederreiten richtet den neuen Trittschaden
  + GS/2 an.
- Sturmangriff vom Pferd braucht Reiterkampf **und** Sturmangriff und richtet
  +4 + GS/2 TP an; mit Finte kombinierbar.
- Ohne SF: nur Wuchtschlag; in DK H/N von Fußsoldaten 3 schwerer zu treffen.
- Reiterkampf: Kampfstile, Finte, Gezielter Stich, Halbschwert, Hammerschlag,
  Niederwerfen, Todesstoß, Wuchtschlag; +2 TP gegen Fußsoldaten; AT +3 nur auf
  geschultem Pferd; Zweihandwaffen +2 (Speere ohne); eBE der Kampftalente
  halbiert.
- Kriegsreiterei: nur mit geschultem Pferd, sonst wie Reiterkampf; zusätzlich
  Gegenhalten und Zusatzaktionen aus BK II/SK II; AT +3 gegen Fußsoldaten;
  Angriff über Kreuz +6.
- Rittmeister: nur mit geschultem Pferd, sonst wie Kriegsreiterei; über Kreuz
  +3; Schilde über Kreuz mit halbem PA-Modifikator.

### Ausbildung (ZBA S. 32–37)

- Stufen ungearbeitet → unerfahren → erprobt → geschult; ländliche Ausbildung
  endet bei erprobt, geschult geht nur fundiert über eine Variante.
- Modifikationen je Schritt:

  | Schritt | ländlich | fundiert |
  |---|---|---|
  | ungearbeitet → unerfahren | keine (Einreiten-Probe +3, Fehlschlag: Unart) | LO +2, KK +1; je 3 einfache Proben Abrichten, Tierkunde, Reiten |
  | unerfahren → erprobt | KK +3, LO +4, AU +2/+1 (ein Jahr Arbeit) | LO +2, KK +2, AU +1/0; je 2 Proben +3 |
  | erprobt → geschult | nicht möglich | Variante + LO +3; je 2 Proben +5 |

  Je drei gescheiterte Proben der fundierten Ausbildung ziehen eine Unart nach
  Meisterwahl nach sich. Fundiert begonnen und ländlich weitergeführt: halbe
  Modifikationen, danach keine weitere Schulung.
- Reiten-Modifikatoren (S. 35): ungearbeitet +3 (Kampf +6), unerfahren +1
  (Kampf +3), erprobt −1 (Kampf 0), geschult −2 (Kampfpferd im Kampf −3, sonst
  −1). Ländliche Tiere im Kampf zusätzlich +3, Kampfhandlungen des Reiters +3.
  Magierpferd −1 für Viertel-, Halb- und Vollzauberer.
- Varianten (S. 32) mit Modifikationen und SF-Listen, z. B. leichtes Streitross
  AT +1, TP (Tritt) +1, LO +1.
- Pferde-SF (S. 36), allgemeine nachträglich per Abrichten +5; Unarten (S. 37 f.).

### Kampf mit dem Pferd (ZBA S. 39 f., für P3)

- Reit-AT = (TaW Reiten + LO + 2 × AT Pferd) / 4; Reit-PA analog mit PA.
- Pferdemanöver mit Reit-AT-Zuschlag: Capriola +5, Corbetto +3, Gezielter Biss
  +1, Gezielter Tritt +1, Kreisel +5, Steigen +1, Niederreiten +3, Sturmangriff
  zu Pferd +3, Trampeln +5. Allgemeine Kampfmanöver brauchen Reiterkampf,
  spezielle Kriegsreiterei.

### Rittmeister (Epische Stufen S. 9)

Schlachtrösser AT/PA/TP +2, Rennpferde GS +1/1/2, Magierpferde MR und
Magiegespür +3; misslungene LO-Proben dürfen wiederholt werden.
