# Reittiere: Ausbildung, Reiterkampf, Spiel

Stand: Paket P1 in Arbeit. Dieses Dokument hält die Regelquellen, die getroffenen
Entscheidungen und die Paketaufteilung für Pferde und andere Reittiere fest.
Belege stammen aus dem dsa-rules MCP.

## Ziel

Ein Reittier soll sich regelkonform entwickeln, im Kampf einsetzbar sein und im
Spiel interaktiv mitlaufen. Bisher speichert die App Begleiter nur und zeigt sie
an; Ausbildung ist Freitext, und Reiterkampf ist nicht modelliert.

## Pakete

| Paket | Inhalt | Stand |
|---|---|---|
| P1 Pferd-Grundlage | Reit-SF im Katalog, Ausbildungskatalog, Ausbildungsmodell am Begleiter, abgeleitete Wirkwerte, Ausbildungsschritte und Pferde-SF im Begleiter-Tab, gewürfelte Ausbildungsproben | in Arbeit |
| P2 Spielansicht | laufende LeP/AuP/Wunden je Begleiter im `HeroState`, Begleiterkarte in `lib/ui2/spielen/`, LO-Probe, Reiten-Probe mit Stufenmodifikator, Pferdeangriffe würfeln, Rittmeister-Boni | offen |
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
- **Ausbildungsproben** lassen sich würfeln, eine Buchung geht aber auch ohne
  Würfeln (bezahlter Zureiter, ZBA S. 37).

## Regelquellen

### Reit-Sonderfertigkeiten (WdS S. 102)

| SF | Voraussetzung | Kosten | Kern |
|---|---|---|---|
| Reiterkampf | TaW Reiten 7 | 200 AP | Reiten-Zuschläge im Kampf halbiert; gegen Fußkämpfer AT +3, +2 TP mit geeigneten Waffen |
| Turnierreiterei | TaW Reiten 10, SF Reiterkampf | 100 AP | Lanzenreiten +5; Ansagen bis zur Lanzenreiten-AT |
| Kriegsreiterei | TaW Reiten 10, SF Reiterkampf | 300 AP | Zuschläge geviertelt; Pferd PA +3; Niederreiten, Hufschlag, Trampeln |

Im Katalog: `ksf_reiterkampf`, `ksf_turnierreiterei`, `ksf_kriegsreiterei` in
`assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json`. Ob sie aktiv
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
