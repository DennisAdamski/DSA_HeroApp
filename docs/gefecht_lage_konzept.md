# Gefechtslage – Konzept und Vorbereitungsschritte

Stand: 16.10.2026. Zielbild ist der Entwurf
[docs/mockups/gefecht-lage.html](mockups/gefecht-lage.html) (Beschreibung in
[docs/mockups/README.md](mockups/README.md#gefechtslage-entwurf-stand-16102026)):
mehrere frei definierte Gegner mit Größe, Lage und eigenem Schadens- und
Wundstand, Angriffe auf ein oder mehrere Ziele, die eigene Seite aus der
Heldengruppe und daraus abgeleitet Vor- und Nachteile durch Überzahl.

Die Begegnung bleibt in allen Schritten **flüchtig** (kein JSON, kein
Repository, Prozessneustart verwirft sie). Die harten Regeln 2 und 3 aus
`CLAUDE.md` greifen erst, falls sie später gespeichert werden soll; dann
braucht sie `jsonSchluessel`, `unbekannteFelder` und belegungsabhängiges
Schreiben.

## Ausgangslage

- `Gefechtsbegegnung` (`lib/domain/gefecht_gegner.dart`,
  `state/gefecht_begegnung_provider.dart`) führt Gegner mit stabiler ID, Name,
  LeP, RS und INI sowie einmalige Buchungs-IDs.
- Gegner stehen bereits in der gemeinsamen INI-Folge
  (`_zeitpunkte` in `state/gefecht_initiative_provider.dart`), der
  Klingensturm wählt mehrere Begegnungsgegner als Ziele.
- Die Gegnerzahl war eine manuelle Zahl (`gefechtsGegnerzahl`); sie wirkte
  nur auf das Ausweichen (−2 je weiterem Gegner, Sperre ab vier).
- Die Wundrechnung der Helden (`computeWundschwellenStufen`,
  `schlageWundenVor`, `WundZone`) ist wiederverwendbar.

## Schritte

| Nr. | Schritt | Status |
| --- | --- | --- |
| 1 | Gegnermodell erweitern | umgesetzt (16.10.2026) |
| 2 | Trefferliste statt LeP-Abzug | umgesetzt (16.10.2026) |
| 3 | Ausgeschiedene Gegner herausnehmen | umgesetzt (16.10.2026) |
| 4 | Überzahl-Regelmodul | umgesetzt bis auf Konzentration und Taktik-Bedienung (16.10.2026) |
| 5 | Eigene Seite als Teilnehmerliste | umgesetzt (16.10.2026) |
| 6 | Gegnerwerte als Vorgabe übernehmen | umgesetzt (16.10.2026) |
| 7 | INI der Gegner mit Überzahl und Wunden | umgesetzt (16.10.2026) |

### 1. Gegnermodell erweitern

`Gefechtsgegner` erhält Größenklasse (`GefechtsGroesse`, Vorgabe mittel),
Körperbau (Zweibeiner/Tier), Status (kämpft, kampfunfähig, tot, geflohen),
`bindet` (Teilnehmer-ID) und `ko`. `lep` bedeutet jetzt die LeP zu Beginn;
LeP und RS dürfen unbekannt (`null`) sein. Die Distanzklasse wird **nicht**
am Gegner gespeichert: Sie gilt je Paarung Held–Gegner und steckt bereits in
der Heldensitzung (`Gefechtszustand.dk`). Eine Lagekarte zeigt sie relativ
zum betrachteten Helden.

### 2. Trefferliste statt LeP-Abzug

Jede bestätigte Buchung wird als `Gefechtsgegnertreffer` (Buchungs-ID, TP,
direkt, Zone, manuelle Wunden, Runde, Angreifer) am Gegner abgelegt.
`gefechtsGegnerstand` leitet SP, verbleibende LeP und Wunden je Zone ab:
SP = max(0, TP − RS), direkte SP umgehen den RS (WdS S. 56); Wunden über
KO/2, zwei über KO, drei über 1,5 × KO (WdS S. 57), höchstens drei je Zone
(WdS S. 109). Ohne RS bleiben die TP sichtbar und werden verrechnet, sobald
der RS bekannt ist; ohne KO zählen nur manuell bestätigte Wunden. Treffer
lassen sich zurücknehmen; ihre Buchungs-ID bleibt verbraucht.

### 3. Ausgeschiedene Gegner herausnehmen

Nur kämpfende Gegner haben einen INI-Zeitpunkt (`gefechtsGegnerHandelt`);
Kampfunfähige handeln nicht (Basis S. 139), bleiben aber angreifbar. Tote und
geflohene Gegner sind kein Ziel mehr (`gefechtsGegnerAngreifbar`): weder als
Ziel der Heldensitzung noch im Klingensturm oder als Ziel einer Fremdwirkung.
`gefechtsAngreifbareGegner` belegt Kämpfende vor Kampfunfähigen vor. Ein
bereits gewähltes Ziel wird nicht automatisch gewechselt.

Statusvorschläge (`gefechtsGegnerStatusvorschlag`, nur auf Tipp
übernommen, nur mit bekannten LeP): ≤ 5 LeP kampfunfähig (außer Zäher Hund,
Eisern), ≤ 0 LeP lebensbedrohlich und bewusstlos, unter −KO tot
(Basis S. 139); Tiere fliehen meist, wenn ihre LeP auf ein Drittel gesunken
sind, und sind bei 0 LeP kampfunfähig und tödlich verwundet (WdS S. 114).
Ein Vorschlag ist immer ernster als der aktuelle Status; Tote und Geflohene
erhalten keinen.

### 4. Überzahl-Regelmodul

Neues reines Modul `gefecht_ueberzahl_rules.dart`. Eingang: Gegner der
Begegnung (Status, `bindet`, Größe) und eigene Teilnehmer (Schritt 5).
Ausgang je Verteidiger und Seite (WdS S. 81, optional):

- INI +1 je Kopf Überzahl für alle Kämpfer der überlegenen Seite, höchstens +4.
- Je zusätzlichem Gegner PA-Basis −1 (wirkt auf Parade und Ausweichen),
  Ausweichen zusätzlich −1; höchstens drei Gegner im Blick (−2), ein vierter
  steht im Rücken und ist nicht parierbar.
- Angreifer in der Überzahl AT +1.
- Konzentration auf einen Gegner zu Beginn der KR: kein Malus gegen ihn,
  die übrigen weder parierbar noch angreifbar.
- Sehr große Wesen und Wesen kleiner als winzig zählen nicht (WdS S. 114,
  dort für Tiere); fliegende Gegner ebenfalls nicht.

**Stand 16.10.2026:**

- Ein Gegner zählt, wenn er kämpft, jemanden bindet und nicht sehr groß ist
  (`gefechtsGegnerZaehltFuerUeberzahl`). Ohne Bindung gilt er als nicht im
  Nahkampf; Fernkämpfer der Gegner bleiben so außen vor.
- `gefechtMitInitiativeProvider` setzt `Gefechtszustand.gebundeneGegner` aus
  den Bindungen; `gefechtsGegnerzahl` nimmt die Angabe im Aktionsdialog vor
  den Bindungen vor der Rundenleiste. Mit Bindungen ist die Rundenleiste
  gesperrt („Gegner (Liste)“).
- Parade: PA-Basis −1 je weiterem Gegner (neu, Nutzerentscheidung
  16.10.2026). Ausweichen −2 je weiterem Gegner, beides höchstens für drei
  Gegner im Blick. Die frühere Sperre „ab vier Gegnern kein Ausweichen“ ist
  entfernt (nicht belegt; Nutzerentscheidung, Ausweichen nicht zu sperren).
- AT +1 (`kGefechtsUeberzahl`), wenn mindestens zwei Helden der gemeinsamen
  Initiative dasselbe kämpfende Ziel gewählt haben (`ueberzahlAngriff`);
  seit Schritt 5 zählen nur Nahkämpfer der eigenen Seite, auch externe
  Gefährten mit diesem Ziel.
- Die Gegnerkarte setzt die Bindung je Gegner und zeigt Kräfteverhältnis,
  INI-Bonus der überlegenen Seite und die eigene Abwehrlage. Der INI-Bonus
  wird erst mit Schritt 7 verrechnet.
- Offen: Konzentration auf einen Gegner (braucht eine Paradesperre gegen die
  übrigen) und die Bedienung der Taktik (Probe, Anführerwahl). Die Regeln der
  Taktik sind fertig (`gefechtsTaktikAufhebungErschwernis`,
  `gefechtsTaktikVerteilung`, `gefechtsTaktikMisslungen`,
  `setzeGefechtstaktik`); „aufgehoben“ nimmt den Gegnern den INI-Bonus, die
  Paarungen legt danach die Bindung fest.

#### Überzahl durch Kriegskunst aufheben oder verbessern

Die Überzahl ist nicht fest: Der Anführer einer Seite kann sie mit einer
Kriegskunst-Probe (`tal_kriegskunst`, Spezialisierung Taktik hilft)
aufheben oder die eigene Lage verbessern (WdS S. 81, optional „Die Aktion
Taktik“; als Aktion auch WdS S. 55):

- **Verbessern:** Einmal pro Kampf als einfache Aktion. Die übrig behaltenen
  TaP werden möglichst gleichmäßig auf die INI der Kampfgefährten mit
  positivem TaW Kriegskunst verteilt, höchstens 6 Punkte, nie auf den
  Anführer selbst. Der Bonus darf über INI-Basis +6 hinausgehen, wird einmal
  vergeben und kann im Kampf wieder abgebaut werden. Bei Misslingen verliert
  jeder Positionierte 1 INI.
- **Aufheben:** Eine Kriegskunst-Probe, erschwert um die doppelte Überzahl der
  Gegner, positioniert die Gefährten so, dass der Überzahl-Modifikator der
  Gegner vollständig entfällt. Der Anführer bestimmt dann die Kampfpaarungen
  (also `bindet`).
- Bei einer Überraschung darf der Anführer erst nach gelungener IN-Probe
  Punkte verteilen.

Für das Modul heißt das: Die Überzahl je Seite braucht einen flüchtigen
Taktikstand der Begegnung (Anführer, Ergebnis „aufgehoben“ oder verteilte
INI-Punkte je Teilnehmer, bereits genutzt; `Gefechtstaktik` in der
Begegnung). „Aufgehoben“ setzt den INI-Bonus der gegnerischen Überzahl auf
null; Abwehrmali folgen weiter den Bindungen. Verteilte Punkte erscheinen als
eigener Herleitungsschritt der INI (ARCH-04). Die Probe selbst läuft über den
vorhandenen Probendialog; die App schreibt das Ergebnis nur nach Bestätigung.

### 5. Eigene Seite als Teilnehmerliste

Flüchtiger `Gefechtsmitstreiter` in der Begegnung: Name, Herkunft (Held der
App oder externer Held), INI, Beteiligung (Nahkampf, Fernkampf, nicht dabei),
Ziel. Vorbelegt aus den verbundenen Helden der gemeinsamen Initiative und aus
`gruppenMitgliederProvider` (`ExternerHeld.iniBase`). Nur Nahkämpfer zählen
für die Überzahl. Für Fernkämpfer gilt beim Schuss ins Getümmel die
Hausregel der App (`gefechtsGetuemmelZuschlag`: pauschal +3, mit
Scharfschütze +2, Meisterschütze +1, Waffenmeister 0) statt des Zuschlags je
Kämpfer aus WdS S. 97; das Mockup zeigt noch die Lesart je Kämpfer.

**Stand 16.10.2026:** `gefechtsEigeneSeiteProvider(heroId)` bildet die Seite
aus dem Helden, den verbundenen Helden der gemeinsamen Initiative und
automatisch den externen Gefährten ihrer Heldengruppen; eine Visitenkarte mit
`quelleHeroId` eines mitkämpfenden Helden erscheint nicht doppelt. Ohne
Festlegung kämpfen alle im Nahkampf. `Gefechtsmitstreiter` in der Begegnung
hält Beteiligung (Nahkampf, Fernkampf, nicht dabei) und das Ziel externer
Gefährten; Helden wählen ihr Ziel im eigenen Gefecht. „Nicht dabei“ löst
Bindungen und Ziel. Die Gegnerkarte zeigt „Eure Seite“ und bietet nur
Beteiligte zur Bindung an.

### 6. Gegnerwerte als Vorgabe übernehmen

`waehleGefechtsgegner` übernimmt die zuletzt für diese Paarung gesetzte DK;
der Fernkampf belegt die Zielgröße aus der Größenklasse sichtbar vor
(winzig +8 … sehr groß −2, WdS S. 97).

**Stand 16.10.2026:** `Gefechtszustand.dkJeGegner` merkt die DK je Gegner;
ein Zielwechsel stellt sie wieder her, sonst gilt die Start-DK der Waffe.
Die Zielsituation des Fernkampfs startet mit dem Zuschlag der Größenklasse
(`gefechtsZielgroesseZuschlag`), „Kampfgetümmel“ ist vorbelegt, wenn der
Gegner jemand anderen als den Schützen bindet, und „Sehr großer Gegner“ im
Aktionsdialog (Hammerschlag) folgt der Größenklasse. Alle Vorgaben bleiben
änderbar. Für Tierangriffe: groß nur mit Schild
parierbar, sehr groß gar nicht (WdS S. 114); Hausregel „Fortgeschrittene
Monsterparade“ (Epische Stufen) erweitert das.

### 7. INI der Gegner

`_zeitpunkte` rechnet den Überzahlbonus (Schritt 4, nach Taktik) und −2 je
Wunde in die Gegner-INI ein, als nachvollziehbare Herleitung. Der Bonus der
eigenen Helden folgt als eigener Herleitungsschritt in `gefechtsInitiative`.

**Stand 16.10.2026:** Überzahl gibt es nur, wenn beide Seiten im Nahkampf
stehen. `gefechtsGegnerIni` = erfasste INI + Überzahlbonus der Gegner +
Wundabzug (`gefechtsGegnerIniWundmalus`: je Wunde INI-Basis −2 plus
Zonenanteil, kombiniert wie bei Helden). `Gefechtszustand.lageIni` hält den
Anteil aus Überzahl und Taktik eines Helden (`gefechtsLageIni`, nicht für
Unbeteiligte); `gefechtsInitiative` zählt ihn mit, die INI-Herleitung zeigt
ihn als Schritt „Überzahl und Taktik“. Die Gegnerkarte zeigt die aktuelle
Gegner-INI mit ihren Anteilen. Die gewürfelten 2W6 einer Kopfwunde trägt der
Nutzer weiterhin als INI-Korrektur des Gegners ein.

## Bewusst später

Lagekarte mit Ziehen und Animationen, Treffer auf mehrere Ziele über den
Angriffsdialog (baut auf Schritt 2 und 4 auf), Trefferzonen für Tiere
(Rumpf, Bein, Kopf, Schwanz; `WundZone` kennt nur menschliche Zonen),
Speichern der Begegnung.
