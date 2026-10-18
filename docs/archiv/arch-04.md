# Archiv — ARCH-04 Regelprofile und erklärbare Berechnungen (Teilstände 1–14)

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

## ARCH-04 — Versionierte Regelprofile und erklärbare Berechnungen

**Ist-Zustand:** Aktive Hausregelpakete werden aus gemeinsamen Einstellungen
aufgelöst. `ModifierSourceBreakdown` erklärt bereits einen Teil der
Modifikatorherkunft; eine einheitliche Herleitung aller Regelwerte fehlt.

**Ziel:** Helden erhalten ein explizites Regelprofil mit festgelegten
Paketversionen. Gruppen können eine gemeinsame Vorgabe liefern. Ein Regelupdate
zeigt vor Übernahme seine Auswirkungen. Berechnungen liefern neben Ergebnissen
ihre Basis, Modifikatoren, Bedingungen und Quellen.

**Einstieg:** `lib/state/house_rules_providers.dart`,
`lib/state/catalog_providers.dart`, `lib/catalog/house_rule_pack.dart`,
`lib/catalog/house_rule_catalog_resolver.dart`,
`lib/catalog/house_rule_provenance.dart`, `lib/domain/hero_sheet.dart`,
`lib/rules/derived/modifier_source_breakdown.dart` und
[Katalog-Workflow](../catalog_import_workflow.md).

- [ ] Profilzuordnung, Versionierung und Auflösung definieren; Bestandshelden
  mit ihrem bisher wirksamen Regelsatz übernehmen. *(Modell und Auflösung
  Teilstand 12, Erstübernahme per Knopf Teilstand 14; Gruppenvorgabe offen.)*
- [x] Vorschau für Profil-/Paketupdates implementieren: geänderte Werte und
  Erwerbsvoraussetzungen anzeigen, erst durch Übernahme verbindlich machen.
  *(Teilstand 13 ohne, Teilstand 14 mit Oberfläche.)*
- [x] Ein gemeinsames Ergebnisformat für Regelherleitungen einführen und
  schrittweise auf Basiswerte, Kampf, Talente, Magie und Steigerungen anwenden.
  Die UI zeigt die Herleitung aus dem Regelmodul, ohne sie selbst nachzurechnen.
  *(Format und Basiswerte seit Teilstand 1, Eigenschaften seit Teilstand 2,
  Kampfvorschau seit Teilstand 3, Schild- und Parierwaffen-PA seit
  Teilstand 4, Gefechtswerte Teilstand 6, Begleiter Teilstand 7, Talente
  Teilstand 8, Zauber Teilstand 9, Steigerungskosten Teilstand 10, Lernregeln Teilstand 11; Regelprofil-Grundlage Teilstand 12, Updatevorschau Teilstand 13, Oberfläche je Held Teilstand 14; offen bleibt
  der Erwerbsdialog, siehe Teilstand 10/11.)*

**Abnahme:** Zwei Helden mit verschiedenen Profilen können parallel geöffnet
werden, ohne einander zu beeinflussen. Gleiche Eingaben und Regelversionen
liefern reproduzierbare Ergebnisse. Ein Update verändert den Helden erst nach
Übernahme; angezeigte Herleitung und tatsächlich verwendeter Wert stimmen überein.

**Prüfung:** `test/state/house_rules_providers_test.dart`,
`test/catalog/house_rule_catalog_resolver_test.dart` sowie Regel- und UI-Tests
für Profilwechsel, Updatevorschau und Herleitungen ergänzen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-02/03 erleichtern eindeutige
Wirkungsquellen. Gruppenvererbung gegenüber einer festen Profilkopie, Aufbewahrung
alter Paketstände und Verhalten bei fehlenden Paketen klären. Import/Export und
Sync müssen die reproduzierbare Profilzuordnung mittragen.

**Entscheidungen 13.10.2026 (Nutzer).**

- **Reihenfolge:** zuerst das Herleitungsformat (ohne Daten- und
  Syncänderung), danach Regelprofil und Updatevorschau.
- **Profilquelle: live von der Gruppe.** Ein Gruppenheld folgt der aktuellen
  Vorgabe seiner Gruppe; eine geänderte Vorgabe wird ihm als Vorschau
  angeboten. Das braucht Firestore und ist deshalb unter Windows nicht
  verfügbar; dort und ohne Gruppe gilt die eigene Auswahl. Offen für den
  Profilteilumfang: Verhalten bei mehreren Gruppen eines Helden, beim
  Verlassen der Gruppe und ohne Verbindung.
- **Paketstand am Helden.** Der Held trägt die Patches seiner Pakete als
  Kopie und rechnet nach einem App-Update mit dem alten Stand weiter, bis die
  Vorschau übernommen wird. Ein fehlendes Paket rechnet aus der Kopie weiter
  und zeigt einen Hinweis. Der Basiskatalog selbst wird nicht eingefroren.

**Teilstand 1, 13.10.2026 — Herleitungsformat und Basiswerte.** Der dritte
Unterpunkt ist begonnen, der Hauptpunkt bleibt offen.

*Befund.* Die Basiswerttabelle der Übersicht rechnete „Modifikator“ und
„Start“ selbst nach (`totalMods` ohne Wunden, eigener Level-Anteil, Start als
Differenz). Dadurch erschienen Kampfreflexe/Kampfgespür, Wundabzüge, die
Rüstungsbehinderung der GS und der begrenzte Au-Level epischer Helden im
Start statt im Modifikator; der Dialog listete eine eigene Quellenliste.

*Umsetzung.*

- **Format:** `Herleitung`/`HerleitungsSchritt`/`HerleitungsArt`
  (`lib/rules/derived/herleitung.dart`). Der Wert ist die Summe der Schritte;
  Begrenzungen und Vervielfachungen sind eigene Ausgleichsschritte. Damit
  stimmen angezeigte Herleitung und verwendeter Wert per Konstruktion überein.
- **Basiswerte:** `computeBasiswertHerleitungen`
  (`basiswert_herleitung_rules.dart`) für LeP, Au, AsP, KaP, MR, INI-Basis,
  AT/PA/FK-Basis, GS und Ausweichen. `computeDerivedStatsFromInputs` liest
  die Werte dort ab und legt die Herleitungen in `DerivedStats.herleitungen`.
  Die Grundwertformeln sind als `grundwert*`-Funktionen herausgezogen und
  werden von den bisherigen `compute*`-Funktionen mitbenutzt.
- **Quellen:** jeder eigene Modifikator einzeln mit seinem Text, der
  Textanteil nach Rasse, Kultur, Profession, Vor- und Nachteilen
  (`HeroStatInputs.textAufteilung`). Passt die Aufteilung nicht exakt, bleibt
  der Textanteil ein Schritt.
- **Oberfläche:** Die Basiswerttabelle liest Start und Modifikator aus der
  Herleitung, der Modifikatordialog zeigt sie samt Formel, Quelle und
  Ergebnis. Sichtbare Änderung: Sonderfertigkeiten, Wunden und Behinderung
  stehen jetzt in der Modifikatorspalte; die Summe ist unverändert.

*Prüfungen.*

- `test/rules/basiswert_herleitung_rules_test.dart` (17 Proben): Format,
  Untergrenze, Gleichheit mit den Einzelformeln, eigene Modifikatoren nur am
  eigenen Wert, Kampfreflexe/Kampfgespür als SF-Schritte, GS mit Axxeleratus
  und Wundgrenze, Rückfall bei unpassender Aufteilung; für alle zehn
  Bestandshelden mit Wunde zerlegen die Modifikatorschritte genau
  `DerivedStats.modifiers`, und der Textanteil ist nach Herkunft aufgeteilt.
- `test/ui/overview/basiswert_herleitung_anzeige_test.dart`: INI-Modifikator
  mit Kampfreflexe (vorher 0), Dialog mit Formel, Quelle und Ergebnis.
- Die gepinnten Regelwerte der Bestandshelden
  (`bestandshelden_regelwerte_test.dart`) sind unverändert grün; kein Modell
  und kein JSON-Format geändert.

*Nächste Schritte.* ~~Eigenschaften~~ (Teilstand 2), dann die
Kampfvorschau (AT/PA/FK je Waffe, INI, Ausweichen, RS/BE), danach Talente,
Magie und Steigerungen. Das Regelprofil folgt als eigener Teilumfang nach
den Entscheidungen oben.

Commit: `365e3b2`. Vollständige Suite danach grün (4710 bestanden,
3 übersprungen).

**Teilstand 2, 13.10.2026 — Eigenschaften.** `computeEigenschaftHerleitungen`
(`eigenschaft_herleitung_rules.dart`) leitet jede Eigenschaft aus dem
eingetragenen Wert, Rasse/Kultur/Profession/Vor-/Nachteilen, jedem eigenen
Modifikator, Inventar und (nur für die effektiven Werte) temporären
Zauberboni her. `computeHeroStatInputs` liest permanente und effektive
Eigenschaften daraus ab, statt Modifikatoren selbst zu addieren; die
effektive Herleitung steht in `HeroComputedSnapshot.eigenschaftHerleitungen`.
Der Eigenschaftsdialog der Übersicht zeigt sie; beide Modifikatordialoge
teilen dafür `HerleitungsAbschnitt`
(`ui/screens/hero_overview/herleitung_abschnitt.dart`), die Übersicht ruft
`computeModifierSourceBreakdown` nicht mehr selbst auf. Wundbedingte
Eigenschaftsverluste bleiben bewusst außerhalb (sie gelten nur für Proben,
`probenEigenschaften`).

*Prüfungen.* `test/rules/eigenschaft_herleitung_rules_test.dart`
(Quellen, Zauberschritt nur mit temporären Boni, Rückfall bei unpassender
Aufteilung; für alle Bestandshelden gleicht die Herleitung den effektiven
Werten und ist nach Herkunft aufgeteilt) und ein Widgettest für den
Eigenschaftsdialog in `basiswert_herleitung_anzeige_test.dart`. Gepinnte
Regelwerte der Bestandshelden unverändert.
Commit: `6f79e3b`. Vollständige Suite danach grün (4724 bestanden,
3 übersprungen).

**Teilstand 3, 13.10.2026 — Kampfvorschau.**

*Befund.* Die „Berechnungsschritte“ des Kampf-Tabs
(`weapon_detail_expansion.dart`) rechneten selbst nach, und ihre Schritte
ergaben teils nicht das Ergebnis: Die AT-Basis war ein Restwert, in dem der
Bonus eines waffenlosen Kampfstils verschwand (in der PA fehlte er ganz);
unter Axxeleratus fehlte im Ausweichen der PA-Anteil des Zaubers (2 Punkte);
die Fernkampf-INI zeigte weder INI-Wurf noch Axxeleratus noch Kampfstil; der
Nebenhandwaffe fehlten AT-/PA- bzw. FK-Basis und Schildarmwunden; Begrenzungen
(Helden-INI ≥ 0, Ausweichen ≥ 0, eBE ≤ 0) waren unsichtbar.

*Umsetzung.*

- **Regeln:** `kampf_herleitung_rules.dart` (RS, BE Kampf, eBE, AT/FK, PA,
  PA mit INI-Parade-Bonus, TP-Zuschlag) und `kampf_ini_herleitung_rules.dart`
  (Helden-, Waffen-, Kampf-INI, Ausweichen) ordnen die Bausteine der
  Kampfvorschau als Schritte an. `computeCombatPreviewStats` liest AT, PA,
  TP, INI, Ausweichen, RS, BE und eBE dort ab
  (`CombatPreviewStats.herleitungen`, Nebenhandwaffe
  `OffhandCombatPreview.herleitungen`); die Summen und Klemmungen im
  Kampfmodul entfallen. Neu ist `mitObergrenze` im Herleitungsformat; die
  höhere Waffen-INI einer Nebenhandwaffe ist ein eigener Schritt. Die
  Nebenhand-Vorschau liegt jetzt im Teil `combat_offhand_preview_rules.dart`.
- **Oberfläche:** `KampfHerleitungDetails` ersetzt die alte Erweiterung und
  zeigt nur die Herleitungen über das neue gemeinsame `HerleitungsSchritte`;
  neu sichtbar ist der Abschnitt Rüstungsschutz/Behinderung/eBE. Die Ladezeit
  bleibt eine Aufzählung (Halbierung und Teilung sind nicht additiv).
- **Nebenbei:** `hero_overview_tab.dart` lag seit Teilstand 1 mit 707 Zeilen
  über dem LOC-Budget der CI; `_DerivedRow` liegt jetzt im eigenen Teil
  `hero_overview_derived_row.dart`.

*Prüfungen.* `test/rules/kampf_herleitung_rules_test.dart` (Begrenzungen,
Axxeleratus in PA/Ausweichen/TP, AT-Basis als Grundwert, Schwertarm- und
Schildarmwunden, Rüstungsgewöhnung, Nebenhand-INI-Modifikator und schnellere
Nebenhandwaffe, Fernkampf gleich `computeRangedAtValue`, Ausweichen gleich
`computeAusweichen`; alle zehn Bestandshelden mit und ohne Armwunden und
Axxeleratus) und `test/ui/combat/kampf_herleitung_anzeige_test.dart`
(Axxeleratus-Zeilen in PA und Ausweichen, Nebenhand mit AT-Basis und
Schildarmwunde, Einstieg aus dem Kampf-Tab). Verhaltensneutral: gepinnte
Regelwerte der Bestandshelden, `combat_rules_test.dart`,
`gefecht_kampfmittel_rules_test.dart` und `test/ui/combat` unverändert grün;
kein Modell und kein JSON-Format geändert.

*Befund, nicht behoben.* Ein Waffenmeister-AT-Bonus wurde bei Fernkampfwaffen
angezeigt, aber nie gerechnet (`computeRangedAtValue` kennt ihn nicht). Die
Anzeige folgt jetzt der Rechnung; ob der Bonus im Fernkampf gelten soll, ist
per dsa-rules-MCP gegen WdS/Arsenal zu klären (eigener Regelauftrag).

*Nächste Schritte.* Schild-/Parierwaffen-PA (`computeOffhandModifierSnapshot`)
und die Gefechtswerte (`gefecht_held_rules.dart` setzt sein Ausweichen
weiterhin selbst aus den Einzelwerten zusammen, mit INI-Bonus und BE 0)
als Herleitung; danach Talente, Magie und
Steigerungen.

Commit: `2da15ee`. Vollständige Suite danach grün (4749 bestanden,
3 übersprungen).

**Nachtrag 13.10.2026 — Berechnungsschritte durchsuchbar (Nutzerwunsch).**
Ein (i) neben „Regeln nachschlagen“ öffnet alle Herleitungen des Helden in
einem durchsuchbaren Dialog: im Heldenbogen, in der UI2-Verwaltung und in
UI2 zusätzlich in der Navigation (in allen drei Arbeitsbereichen; schmal in
der Kopfleiste). Regeln: `herleitung_uebersicht_rules.dart`
(`sammleHerleitungen`, `filtereHerleitungen`); Dialog
`herleitung_suche_dialog.dart`; Brücke `KartoBestandsAdapter.berechnungsschritte`.
Gezeigt wird der gespeicherte Stand; ein ungespeicherter Kampf-Entwurf
erscheint weiterhin nur in den Berechnungsschritten des Kampf-Tabs. Neue
Herleitungen (Talente, Magie, Steigerungen) werden dort ergänzt.
Prüfungen: `test/rules/herleitung_uebersicht_rules_test.dart`,
`test/ui/workspace/herleitung_suche_test.dart`, neue Fälle in
`test/ui2/spielen/karto_spielaktionen_test.dart`.

**Teilstand 4, 13.10.2026 — Schild und Parierwaffe (Paket A).**
Plan der Folgepakete: A Schild-/Parierwaffen-PA in der Kampfvorschau,
B Gefechtswerte auf denselben Herleitungen, C Zielwert und Erschwernis im
Gefechtsdialog als Herleitung, D (optional) Begleiter.

*Umsetzung A.* `herleiteSchildPa` (`kampf_herleitung_rules.dart`): PA-Basis,
Axxeleratus, Schild-WM, SF Schildkampf (Linkhand +1, Schildkampf I +3,
Schildkampf II +5, Quelle die wirkende SF), eBE-PA-Anteil und Wunden des
Schildarms. `computeOffhandModifierSnapshot` liest `shieldPa` dort ab und
nimmt PA-Basis und Axxeleratus getrennt (`paBasis`, `axxeleratusPa`). Die
Parierwaffe erscheint in der Haupthand-PA als „Nebenhand PA“ (ihr WM) und
„SF Parierwaffen“ (−4/−1/+2, Quelle die SF). Neu: `KampfHerleitungen.schildPa`,
Eintrag „Schild-Parade“ in der Berechnungsschritte-Suche und im Kampf-Tab.
Verhaltensneutral.

*Prüfungen.* `kampf_herleitung_rules_test.dart` (Schild-PA je SF-Stufe mit
Axxeleratus, Rüstung und Schildarmwunde; Parierwaffe je SF-Stufe; ohne
Linkhand kein PA-Anteil; Gleichheit mit `shieldPa` für alle Bestandshelden),
Widgettest für den Abschnitt „Schild-Parade“. Commit: `c8be027`.
Vollständige Suite danach grün (4788 bestanden, 3 übersprungen).

*Regelbefunde vor Paket B (per dsa-rules-MCP geprüft, nicht behoben).*

1. **Ausweichen im Gefecht ohne BE.** WdS S. 67: Ausweichen ist eine Probe
   auf den PA-Basiswert, „unter anderem um die volle BE der Rüstung
   erschwert“ (Tabelle „Behinderung +BE“). Die Kampfvorschau zieht die BE ab,
   das Gefecht (`gefecht_held_rules.dart`, `beKampf: 0`) nirgends; dort ist
   Ausweichen um die BE zu hoch. Paket B übernimmt die Herleitung der
   Vorschau und behebt das. *(Beim Umsetzen richtiggestellt: Die BE wirkte
   im Gefecht bereits, nämlich als Erschwernis `w.be` in
   `pruefeGefechtsaktion`; nur `beKampf: 0` im Grundwert war irreführend.
   Eine Fehlrechnung bestand nicht, siehe Teilstand 5.)*
2. **INI-Bonus auf die Schild-Parade.** Das Gefecht gibt PA, Schild-PA und
   Ausweichen denselben INI-Bonus (`gefechtsIniBonus`: über 20 +1, über 30
   +2, über 40 +3), die Vorschau nur PA (ohne Obergrenze) und Ausweichen,
   nicht der Schild-PA. Eine Quelle für den Bonus fand sich weder in den
   Regelwerken noch in den Hausregeln; Nutzerentscheidung offen.
3. Waffenmeister-AT im Fernkampf, siehe Teilstand 3.

**Teilstand 5, 14.10.2026 — Gefechtswerte auf denselben Herleitungen (Paket B).**

*Umsetzung.* Das Gefecht rechnet AT, PA, Schild-PA und Ausweichen nicht mehr
aus Einzelwerten nach, sondern nimmt die Herleitungen der Kampfvorschau
(`gefecht_herleitung_rules.dart`, blattartig):

- **Ausweichen:** `Gefechtswerte.ausweichenHerleitung` hält die Vorschau-
  Herleitung samt BE. `herleiteGefechtsAusweichen` ersetzt deren Schritt
  „INI-Bonus“ durch „INI-Bonus (Sitzung)“ (`gefechtsIniBonus`, Gefechts-INI)
  und wendet die Untergrenze 0 auf die neue Summe an; `gefechtsAusweichen(s, w)`
  liefert den Zielwert vor Erschwernissen. Die BE steht jetzt als Schritt in
  der Herleitung und läuft **nicht mehr zusätzlich** als Erschwernis
  (`erschwernis += (gegner − 1) * 2`). Rechenfolge also: Untergrenze 0 vor
  den Gegnerzuschlägen, wie in der Vorschau. Von Hand gebaute `Gefechtswerte`
  (Tests) ohne Herleitung erhalten eine synthetische mit `−be`.
- **Kampfmittelprofile:** `atHerleitung`/`paHerleitung` (`at == atHerleitung.wert`).
  Haupt-PA ist die Vorschau-PA ohne die Schritte „Nebenhand PA“ und „SF
  Parierwaffen“ (`kNebenhandPaSchritt`, `kParierwaffenSfSchritt`); Nebenwaffe
  und Waffenlos lesen ihre eigene Vorschau, Schild die Schild-PA-Herleitung.
  Die `anteile`-Zeilen erzeugt `herleitungsZeile` aus den sichtbaren Schritten
  („Hauptwaffen-PA ohne Parierwaffenanteil: 14 (PA-Basis 9, …)“); die
  handgeschriebenen „im Grundwert enthalten“-Zeilen entfallen. Eine
  Fernkampf-Hauptwaffe zeigt keine PA-Zeile mehr (bisher „…: 0“).
- Verhaltensneutral bis auf die Klemmung: Ein Ziel unter 0 vor den
  Gegnerzuschlägen gibt es nicht mehr.

*Prüfungen.* `test/rules/gefecht_herleitung_rules_test.dart`: Ersetzen des
INI-Schritts und Neuklemmung, alle zehn Bestandshelden (mit und ohne
Armwunden und Axxeleratus, Sitzungswürfe 0/12/25/35): Ausweichen = Vorschau
ohne INI-Bonus + Sitzungsbonus, PA = `w.pa` + Sitzungsbonus, AT = `w.at`,
Profile gleich Vorschau; BE wirkt genau einmal; schwere Rüstung klemmt auf 0.
`gefecht_vorgaben_rules_test.dart` erwartet die BE nicht mehr in der
Erschwernis, sondern im Zielwert. Vollständige Suite danach grün (4806
bestanden, 3 übersprungen), `flutter analyze` ohne Befund.

*Entschieden (Nutzer, 14.10.2026).* Regelbefund 2: Der Gefechts-INI-Bonus
gilt auch für die Schild-Parade. Das Gefecht tut das bereits (PA und Schild-PA
erhalten `gefechtsIniBonus`), es bleibt also unverändert; ein Test hält die
Entscheidung fest. Die Kampfvorschau gibt der Schild-PA weiterhin keinen
INI-Anteil (nur „PA mit INI-Parade-Bonus“ der Haupthand); ob sie ihn zeigen
soll, ist noch nicht entschieden.

*Entschieden (Nutzer, 14.10.2026).* Regelbefund 3: Der AT-WM-Bonus eines
Waffenmeisters gilt auch bei Fernkampfwaffen, sonst bliebe er dort wirkungslos
(die Regelsuche in WdS/Arsenal fand keine Aussage dagegen). `herleiteFernkampfAt`
hat dafür den Schritt „Waffenmeister AT“ (Haupt- und Nebenhand),
`computeRangedAtValue` den Parameter `waffenmeisterAtBonus`; die bisher nur
angezeigte `waffenmeisterAtBonus` der Vorschau wirkt damit tatsächlich.
Dadurch ändert sich der FK-Wert jedes Helden mit Fernkampf-Waffenmeister;
Test `Waffenmeister im Fernkampf` in `kampf_herleitung_rules_test.dart`.

Vollständige Suite danach grün (5710 bestanden, 3 übersprungen),
`flutter analyze` ohne Befund.

*Offen.* Keine Regelbefunde mehr.
*Nächste Schritte:* C Zielwert und Erschwernis im Gefechtsdialog als
Herleitung (der Sitzungsschritt ist dafür vorbereitet), D optional Begleiter.

**Teilstand 6, 14.10.2026 — Zielwert und Erschwernis im Gefechtsdialog (Paket C).**

*Umsetzung.* Der Aktionsdialog zeigt unter „Berechnung und Regeltext“ zwei
Herleitungen der Prüfung, Katalog- und Regeltext stehen darunter:

- **Erschwernis:** `pruefeGefechtsaktion` hält jede Erschwernis benannt in
  `Gefechtspruefung.modifikatoren`; deren Summe ist `erschwernis`. Der frühere
  Sammelposten „Weitere Zuschläge/Budget/BE“ entfällt. Benannt sind Nach
  Bewegen (+4), Distanzklassenwechsel, Zweite Attacke/Parade (Umwandlung),
  Schild-WM entfällt, Weitere Gegner (2 je Gegner), Gezieltes Ausweichen je
  Distanzklasse (H 8 / N 4 / S 2), die Kontext- und Fernkampfanteile sowie die
  eigene Eingabe „Weitere Erschwernis“. Manöver zerlegen ihren Zuschlag in
  Manöverzuschlag, Schildführung, Waffenloses Manöver neben Waffe und
  Waffenmeister-Erleichterung (`zuschlagsAnteile`); Ansagen, Zielen,
  Meisterparade und Ansagefolge hängen ihre Anteile wie bisher an.
- **Zielwert:** `Gefechtspruefung.zielHerleitung` hält den Grundwert vor der
  Erschwernis: die Vorschau-Herleitung von AT/FK, PA, Schild-PA
  (`Gefechtswerte.atHerleitung` usw.) plus „INI-Bonus (Sitzung)“, beim
  Ausweichen die Herleitung aus Paket B, bei bestätigtem Grundzielwert dieser.
  Die Ergänzungsschichten reichen das Feld durch.
- **Modul:** `gefecht_zielwert_herleitung_rules.dart` macht daraus
  `herleiteGefechtsZielwert` (Grundwert minus Erschwernis) und
  `herleiteGefechtsErschwernis`; beide liefern `null`, wenn die Summe vom Wert
  der Prüfung abwiche, dann zeigt der Dialog wie bisher Textzeilen.
- **Oberfläche:** `GefechtBerechnung(herleitungen:)` zeigt sie über das neue
  `GefechtHerleitungSchritte`. UI2 darf `HerleitungsSchritte` (`lib/ui/`) nicht
  importieren (`ui2_import_richtung_test.dart`); das Gegenstück ist klein und
  rechnet nichts.
- Verhaltensneutral: Zielwert und Erschwernis aller Prüfungen bleiben gleich.

*Prüfungen.* `test/rules/gefecht_zielwert_herleitung_rules_test.dart`: für
jede Gefechtsaktion in elf Zuständen (Bewegen, vier Distanzklassen, drei
Gegner, zweite AT/PA, Finte mit Schild-WM-Abzug, Fernkampf mit Getümmel, hohe
INI), Nah- und Fernkampf, mit und ohne bestätigten Grundzielwert und
Zuschlag: Anteile ergeben die Erschwernis, Grundwert minus Erschwernis den
Zielwert; benannte Anteile je Regel; Dialogpfad mit echtem Helden (Ansagen,
Manöver, manuelle Handlung, alle Kampfmittelprofile).
`test/ui2/spielen/gefecht_zielwert_herleitung_test.dart`: Anzeige im
Aktionsdialog.

Vollständige Suite danach grün (5700 bestanden, 3 übersprungen),
`flutter analyze` ohne Befund.

**Teilstand 7, 14.10.2026 — Begleiter (Paket D).**

*Umsetzung.* `begleiter_herleitung_rules.dart` ordnet die wirksamen Werte eines
Begleiters als Schritte an, mit denselben Bausteinen wie
`begleiter_wirkwert_rules.dart`: Grundwert (bei Pools der Startwert),
„Steigerung (AP)“, „Reittier-Ausbildung“ (KK, Loyalität, AT) und
„Tierausbildung“ eines Vertrauten (Eigenschaften, INI, LeP, AuP, AT, PA).
Herleitungen gibt es für MU–KK, INI, Loyalität, LeP/AuP/AsP/MR sowie AT und PA
jedes Angriffs (PA nur, wo eine Parade möglich ist). TP und Geschwindigkeiten
bleiben Text bzw. Aufzählung, weil sie keine reine Summe sind. Neu im
Überblick: Bereich „Begleiter“ in `sammleHerleitungen(begleiter:)` und damit
in der (i)-Suche; im Gefecht zeigt jedes Begleiterprofil unter „Berechnung“
INI, Pools und Angriffe mit mehr als einem Schritt. Verhaltensneutral: die
Werte selbst rechnen weiter `begleiter_wirkwert_rules.dart` und das
Kampfprofil, die Herleitungen werden nur daneben gestellt und gegen sie
geprüft.

*Prüfungen.* `test/rules/begleiter_herleitung_rules_test.dart` (Reittier und
Vertrauter: Summen gleich `begleiterWirksamerWert`/`-Poolwert`/`-AngriffAt`/
`-Pa` und Kampfprofil; benannte Schritte je Quelle; Suche) und ein Widgettest
in `gefecht_begleiter_werte_test.dart`.

Vollständige Suite danach grün (5709 bestanden, 3 übersprungen),
`flutter analyze` ohne Befund.

*Nachtrag (Nutzerentscheidung, 14.10.2026).* Die Kampfvorschau zeigt der
Schild-PA jetzt den INI-Anteil wie der Haupthand-PA:
`KampfHerleitungen.schildPaMitIniParade` (INI-Parade-Bonus der
Kampfinitiative), `OffhandCombatPreview.shieldPaMitIniParadeMod`; Kampf-Tab
(Kachel und Berechnungsschritte) und (i)-Suche nehmen diese Werte. `shieldPa`
und die Gefechtsprofile bleiben ohne INI-Anteil, weil das Gefecht den INI-Bonus
der Sitzung selbst aufschlägt; die Regelentscheidung aus Teilstand 5 gilt damit
in Vorschau und Gefecht.
Vollständige Suite danach grün (5709 bestanden, 3 übersprungen),
`flutter analyze` ohne Befund.

*Stand ARCH-04 Kampf.* Pakete A bis D sind erledigt; offen bleiben
Lernspalte und Erwerbsdialog der Steigerungen (Talente: Teilstand 8, Zauber: Teilstand 9, Steigerungskosten: Teilstand 10).

**Teilstand 8, 14.10.2026 — Talente.**

*Entscheidungen (Nutzer).* Die Ausrüstung erscheint **je Gegenstand** als
eigener Schritt, nicht als Summe. Der Talent-BE-Override (kurzfristige,
situative BE-Änderung ohne Rüstungswechsel) ist in der eBE-Herleitung als
eigener Schritt „BE-Anpassung (situativ)“ sichtbar.

*Umsetzung.*

- `InventoryModifierAggregation.talentQuellen` (Gegenstand, Wert, Gruppe),
  `HeroComputedSnapshot.inventoryTalentQuellen`; `talentMods` bleibt die Summe.
- `talent_herleitung_rules.dart`: `herleiteTalentEbe` (Grundwert BE-Regel bei
  BE Kampf, situative Anpassung, epische KK-Halbierung als Ausgleichsschritt),
  `herleiteTalentTaw`, `herleiteMetaTalentTaw`, `herleiteProbenEigenschaften`
  (effektive Eigenschaft samt Quellen plus Schritt „Wunden“), `herleiteTalent`,
  `talentTawNachId`, `sammleTalentHerleitungen`.
- `talentProbenwertFuer` liest TaW\* und eBE aus der Herleitung
  (`TalentProbenwert.herleitung`); verhaltensneutral, per Test gegen
  `computeTalentComputedTaw`/`computeTalentEbe` für alle Bestandshelden mit
  und ohne Override gepinnt.
- Wertesuche: Bereich „Talente“ (TaW\* und eBE je Nicht-Kampftalent mit Wert
  sowie je Meta-Talent), lazy im Dialog gebaut, nicht im Snapshot.
- Talente-Tab: Zeilen, Mobilkarten und Metatalente lesen TaW\*/eBE aus den
  Herleitungen (auf dem Entwurf); Talent- und Meta-Talent-Detail zeigen
  „Herleitung TaW\*“ und „Herleitung eBE“.
- **Verhaltensänderung:** Die SB-Probe beim Unterdrücken von Wunden
  (`wund_unterdrueckung_dialog.dart`, `wunden_detail_dialog.dart`) nimmt TaW\*
  jetzt wie jede Talentprobe (Ausrüstungsbonus, eBE der Selbstbeherrschung);
  der Unterdrückungsdialog rechnet die Eigenschaften aus dem Snapshot
  (temporäre Eigenschaftsboni zählen mit).

*Nachtrag (Nutzerentscheidung, 14.10.2026).* Das Gefecht beachtet den
Talent-BE-Override: `gefechtsProbenkandidaten`, `gefechtsTalentprobe` und
`gefechtsLiturgieprobe` nehmen `talentBeOverride`; Probenwahl, Magie-Liste,
Wirkdialog, Selbstbeherrschung bei Reserve und Unterbrechung lesen ihn aus
`talentBeOverrideProvider`. Dabei bekamen Liturgie-, Reserve- und
Unterbrechungsprobe auch erstmals das Epic-Flag (halbierte eBE bei KK-Proben);
vorher galt dort immer „nicht episch“.

*Nachtrag Basis-/Spezial-Talente und Ausweichen (14.10.2026).* Regelbasis:
Wege des Schwerts S. 16 f. (Basis-Talente darf jeder proben, auch mit TaW 0
oder negativ; Spezial-Talente nur aktiviert mit TaW ≥ 0) und Basisregelwerk
S. 113 (Ableiten auf verwandte Fertigkeit, Meisterentscheid). Die Tabelle
liegt als Dart-Konstante in `lib/catalog/talent_nutzung_katalog.dart`
(`basis` je Talent, `ersatz` mit Richtzuschlag und Bedingung aus der Zeile
„Ersatzweise verwendbare Fertigkeiten“ jedes Talents), nicht in
`talente.json`, weil die Basisassets laut Katalog-Workflow nur über die
Python-Werkzeuge entstehen; `test/catalog/talent_nutzung_katalog_test.dart`
gleicht sie mit dem echten Katalog ab. `talent_nutzung_rules.dart`:
`talentEintragFuerProbe` (zentrale Zulassung, von `talentProbenwertFuer` und
`herleiteTalent` genutzt), `talentErsatzOptionen`; in `talent_probe_rules.dart`
`talentErsatzprobeFuer` und `talentErsatzproben`. Folgen: Basis-Talente sind in
Probensuche und Gefechtsprobenwahl auch ohne Bogeneintrag würfelbar (TaW 0),
nicht aktivierte Spezial-Talente und negative Werte nicht mehr; die
Selbstbeherrschungsprobe im Gefecht braucht keinen eingetragenen Wert mehr.
Ausweichproben („Reiten (über Körperbeherrschung −10)“) erscheinen in beiden
Suchen nur bei einer Sucheingabe und tragen den Hinweis „Meisterentscheid“.
Offen: Eigenschaftsprobe als Ausweichen (Zuschlag ≥ 7, `kEigenschaftsprobeErsatzZuschlag`)
gibt es weiterhin als eigene Eigenschaftsprobe; Kampftalente behalten ihr
Katalogfeld `alternatives`.

*Befunde, offen.* Die Probenziele des Würfelknopfs im Talente-Tab nutzen weiter `wendeWundVerlusteAn` direkt; der
Probendialog zeigt TaW\* nur als Zahl (Herleitung dort ist ein Folgepaket).

*Prüfungen.* `test/rules/talent_herleitung_rules_test.dart`,
`test/rules/inventory_modifier_rules_test.dart` (Quellen),
`test/rules/gefecht_talentprobe_rules_test.dart` (Override im Gefecht),
erweiterte Talente-Tab-Tests (Herleitung, situative BE-Anpassung).

**Teilstand 9, 14.10.2026 — Zauber (ZfW\*).**

*Befund.* Drei Stellen bauten die Zauberprobe je für sich: Probensuche
(`probe_quick_search.dart`), Gefecht (`gefechtsZauberprobe`,
`gefechtsZauberliste`) und der Würfelknopf im Magie-Tab. Der Magie-Tab rechnete
die Eigenschaften aus `computeEffectiveAttributes` ohne die temporären
Eigenschaftsboni des Zustands (etwa Attributo), die beiden anderen nahmen
`probenEigenschaften`; die Behandlung eines Zaubers ohne ZfW war uneinheitlich
(Suche und Tab würfelten ihn mit ZfW 0, das Gefecht nicht).

*Umsetzung.* `zauber_herleitung_rules.dart`: `herleiteZfw` (ZfW und
Modifikator als Schritte), `zauberProbenwertAus` (aus einem Entwurfseintrag
und den Probenwerten) und `zauberProbenwertFuer` (aus dem Snapshot),
`zauberprobeAus`, `sammleZauberHerleitungen`. Alle drei Stellen nehmen diese
Funktionen; ein Zauber ohne ZfW wird nirgends mehr gewürfelt (der Magie-Tab
meldet „Zauber ist nicht aktiviert“), die Kette muss genau drei bekannte
Eigenschaften nennen. Der Magie-Tab würfelt damit gegen die Probenwerte des
gespeicherten Stands (Wunden und temporäre Boni), den ZfW nimmt er weiter aus
dem Entwurf. Wertesuche: Bereich „Zauber“ (ZfW\* je aktiviertem Zauber).
Verhaltensneutral bis auf die genannten Angleichungen.

*Prüfungen.* `test/rules/zauber_herleitung_rules_test.dart`.

*Offen.* Zauberspezialisierung, Merkmalskenntnis- und Repräsentationsboni
sowie AsP-Kosten sind keine Teile des ZfW\* und stehen nicht in der
Herleitung.

**Teilstand 10, 14.10.2026 — Steigerungskosten.**

*Befund.* Der Steigerungsdialog (`steigerungs_dialog.dart`, genutzt vom
Steigerungskatalog und der Vertrauten-Steigerung) setzte die Kette
Grundkosten der Spalte → Sondererfahrung → epischer Aufschlag →
Lehrmeister-Nachlass selbst aus `berechneSteigerungskosten`,
`applyEpicApSurcharge` und `apMitLehrmeister` zusammen; wie die AP entstanden,
war nur teilweise sichtbar („AP-Kosten“, Epos-Aufschlag).

*Umsetzung.* `steigerung_herleitung_rules.dart`: `herleiteSteigerungskosten`
liefert `Steigerungskosten` mit einer `Herleitung` (Grundkosten mit Spalte und
Wertebereich, Sondererfahrung als Nachlass, epischer Aufschlag, Lehrmeister)
und den Zwischenständen `kostenVorAufschlag`/`kostenNachAufschlag`. Die Summe
ist die gebuchte AP-Zahl; Rundung (Aufschlag, Lehrmeister) steckt in den
Beträgen der Schritte. Der Dialog liest alle Zahlen daraus ab und zeigt die
Schritte eingeklappt unter „Berechnung der AP-Kosten“. Verhaltensneutral: der
Test `steigerung_herleitung_rules_test.dart` vergleicht über mehr als 1000
Kombinationen (Spalte, Wertebereich, SE, episch, Haupteigenschaft,
Lehrmeister) mit der bisherigen Kette.

*Offen.* Die Lernspalte selbst (Katalogspalte, Begabung, Unfähigkeit,
Hausregel) bleibt der Text „Lernkomplexität X“ (`effectiveTalentLernkomplexitaet`).
Die Sondererfahrungs-Ausnahme des Aufschlags (Hausregel Kap. 2.2) greift im
Dialog wie bisher auf die schon verbilligten Kosten; unverändert übernommen.

*Nachtrag 16.10.2026 — Erwerbsdialog und Nachteilsabbau.* Die Kette „Kosten →
epischer Aufschlag → Lehrmeister“ steht jetzt als Regel in
`erwerb_herleitung_rules.dart` (`herleiteErwerbskosten`, `Erwerbskosten`);
`erwerb_dialog.dart` und `nachteil_abbau_dialog.dart` lesen Kosten, Aufschlag
und die eingeklappte „Berechnung der AP-Kosten“ daraus ab und rechnen nichts
mehr selbst. Verhaltensneutral: `erwerb_herleitung_rules_test.dart` vergleicht
über alle Kombinationen (Aufschlag, epischer Inhalt, Begabung/SE, Lehrmeister,
Spezialisierungs-Verdopplung) mit der bisherigen Kette. Damit ist der
Erwerbsdialog-Punkt von Teilstand 10 erledigt; offen bleibt die Lernspalte als
Herleitung für Talente.

**Teilstand 11, 14.10.2026 — Lernregeln: Hexalogien, Gegenelement, Gedächtnis,
Lehrmeister.**

*Anlass (Nutzer).* AP-Kosten weichen je nach Lehrmeister, Begabung und
Unfähigkeit, Gedächtnis-Vorteilen und – bei Zaubern – weiteren Faktoren ab;
besonders beeinflussen sich die Zauber einer Hexalogie. Die Regeln wurden mit
dem dsa-rules-MCP geprüft (Belege unten) und die Abweichungen der App behoben.

*Belege.* Hexalogien: Wege der Zauberei S. 384 („Der Zauber einer Hexalogie
mit dem höchsten ZfW wird normal gesteigert, alle anderen werden eine Spalte
leichter aktiviert und bis zu diesem Wert leichter gesteigert“; Zauber des
Gegenelements profitieren nicht davon). Gegenelement: WdZ S. 382 (Feuer–Wasser,
Erz–Luft, Humus–Eis; Merkmalskenntnis oder Begabung in einem speziellen Element
macht dessen Gegenelement eine Spalte schwerer, „Elementar (gesamt)“ und die SF
Elementarharmonisierte Aura heben das auf). Beispiel Rafik S. 385 als Test.
Repräsentation: WdZ S. 74 / WdS S. 171 (fremd zwei Spalten, Schelme drei,
Schelm–Scharlatan zwei, Gildenmagier–Scharlatan und –Borbaradianer eine).
Gutes/Eidetisches Gedächtnis: WdH S. 251/253 (¾ bzw. ½ der Kosten für
Wissenstalente, Sprachen/Schriften und Zauberfertigkeiten, nicht kombinierbar,
nach der Spalte, „drei Viertel der AP der verbilligten Spalte“). Lehrmeister:
Hausregel „Erweiterung und Überarbeitung“ Kap. 6 (20 %, TaW 15+, nur Talente
und Zauberfertigkeiten, bis Stufe + 3).

*Umsetzung.*

- `hexalogie_katalog.dart`: sieben Hexalogien mit den Zaubern des
  Basiskatalogs (Wände, Geschosse, Explosionen, Leiber, Verzauberung eines
  Geschosses, Bewegung, Wirbel), `Magieelement` mit Gegenelement.
- `zauber_lernspalte_rules.dart`: `zauberLernspalte` liefert Spalte,
  Herleitung **in Spalten** (Katalog, Hauszauber, Merkmalskenntnis, Begabung,
  Unfähigkeit, fremde Repräsentation, Gegenelement) und die Hexalogie-Lage
  (`hexalogieBisWert` = höchster ZfW der anderen gelernten Zauber der Gruppe).
  Dieselbe Rechnung nutzen Steigerungsoption und Zaubertabelle des Magie-Tabs
  (dort mit einem Hexalogie-Symbol samt Hinweis).
- `berechneSteigerungskosten(erleichterungBisWert:)`: jeder Schritt bis zu
  diesem Zielwert (die Aktivierung eingeschlossen) kostet eine weitere Spalte
  weniger, zusammen mit Sondererfahrung.
- `lernkosten_faktor_rules.dart`: Gutes/Eidetisches Gedächtnis als
  Kostenfaktor; `Lernregeln` bündelt Hexalogie, Faktoren, Spaltenherleitung und
  Hinweise an der `AdvancementOption`. Die Steigerungskosten-Herleitung führt
  „Hexalogie“ und den Faktor als eigene Schritte.
- `fremdeRepraesentationsSpalten` (`magic_rules.dart`) ersetzt den pauschalen
  Zuschlag von zwei Spalten.
- Lehrmeister nur noch bei Talenten (auch Sprachen/Schriften) und Zaubern
  (`AdvancementOption.lehrmeisterMoeglich`) und nur bis Stufe + 3
  (`lehrmeisterMaxWert`); darüber entfällt der Nachlass, der Dialog sagt es.
- Steigerungsdialog: „Berechnung der AP-Kosten“ zeigt die Lernspalte in
  Spalten, dann die AP-Schritte.

*Prüfungen.* `zauber_lernspalte_rules_test.dart` (Rafik-Beispiel, Gegenelement,
Hexalogie ohne Geschwister, Spaltensummen über den ganzen Katalog, Repräsentation),
`hexalogie_katalog_test.dart` (gegen den echten Katalog),
`lernregeln_advancement_test.dart`, erweiterte `steigerung_herleitung_rules_test`
und `steigerungs_dialog_test`.

*Bewusst offen.*

- Zweite Repräsentation desselben Zaubers (Expertenregel, WdZ S. 74): der Held
  speichert einen Zauber nur einmal.
- Hexalogien nur mit den Zaubern des Basiskatalogs; eigene Katalogzauber ordnet
  nichts einer Hexalogie zu. Merkmalskenntnis **und** Begabung in einem Element
  und seinem Gegenelement (Expertenhinweis) gilt als Summe.
- Gedächtnis-Vorteile und Akademische Ausbildung bei Sonderfertigkeiten,
  Rituale, Ritualkenntnis und Liturgien; die Akademische Ausbildung wirkt nur
  bei der Erschaffung.
- Selbststudium und gegenseitiges Lehren (optionale Regeln), Lehrmeister-Gebühren
  nach Gruppenzugehörigkeit (⅓, Randgruppen +20 %), Aktivierung nur mit Mentor.
- Die Vorschau im Zauberkatalog und der Repräsentationsdialog des Magie-Tabs
  zeigen das Gegenelement noch nicht.

**Teilstand 12, 14.10.2026 — Regelprofil am Helden: Modell, Auflösung, Provider.**

*Umfang (verhaltensneutral).* `HeroSheet.regelProfil` (`HeroRegelProfil`,
`lib/domain/hero_regelprofil.dart`) hält die **aktiven** Hausregelpakete des
Helden mit Manifestkopie und Prüfsumme sowie die Katalogversion. Ohne Profil
(`null`, der Bestand) folgt der Held unverändert den globalen Einstellungen;
das Feld wird nur bei Belegung geschrieben, Hashes und Bestandshelden bleiben
gleich. Ein nicht verstandenes Profil (`formatVersion` > 1) wird wie keines
behandelt und roh erhalten. Die Paketliste ist im Sync atomar (Schlüssel
`paketId`, keine `id`): zwei Geräte mergen sie nie elementweise.

*Auflösung.* `loeseRegelProfilAuf` (`lib/catalog/regelprofil_aufloesung.dart`)
ist rein: Manifestkopien → `HouseRuleCatalogResolver` → `CatalogRuntimeData` →
`RulesCatalog`. Die Kopie im Profil entscheidet über die Wirkung; Pakete
außerhalb des Profils sind für den Helden aus; unlesbare Kopien werden
gemeldet und übersprungen. `regelProfilAusGlobalemStand` bildet den bisher
wirksamen Stand ab (Test: identische Katalogdaten). Eigene Katalogeinträge
bleiben global.

*Provider.* `regelProfilAufloesungProvider` (Family je Profil, Helden mit
gleichem Profil teilen die Auflösung), `heroRulesCatalogProvider(heroId)`,
`heroEpicAdvantagesActiveProvider(heroId)` und `heroHouseRuleActiveProvider`
in `hero_providers.dart`. `heroComputedProvider`, der Speicherweg
(`HeroActions.saveHero`), die Gefechts-Initiative und alle heldengebundenen
Oberflächen in `lib/ui` und `lib/ui2` lesen den Katalog des Helden. Globale
Leser (Gate, Einstellungen, Katalogverwaltung) bleiben bewusst bei
`rulesCatalogProvider`.

*Offen.* Migration/Übernahme eines Profils nur durch bewusste Nutzeraktion
(schreibt sonst Hashes um); Updatevorschau (Diff zweier Auflösungen, geänderte
Werte, Erwerbsvoraussetzungen, Gate-Änderungen im Basiskatalog); Oberfläche je
Held; Hinweis bei fehlendem/geändertem Paket; Gruppenvorgabe („live von der
Gruppe“, eigenes Teilprojekt, Firestore-Regeln verbieten heute
Gruppen-Updates); Import/Export prüfen.

**Teilstand 13, 14.10.2026 — Updatevorschau für Regelprofile (ohne Oberfläche).**

*Umfang.* Reine Vorschau, was ein Paketupdate für einen Helden mit Profil
ändern würde, und eine bewusste Übernahme. Ohne Übernahme ändert sich nichts am
Helden (Hashes, Sync).

- `catalog/regelprofil_vergleich.dart`: Diff zweier `loeseRegelProfilAuf`-Läufe.
  Je Katalogsektion neue, entfernte und geänderte Einträge mit Feldpfad, Werten
  und Paketursache (aus dem Herkunftsindex); `SperrAenderung` für Basiseinträge,
  die ein Paket über `ruleMeta.sourceKey` ein- oder ausblendet; Pakethinweise
  `fehlt` / `aktualisiert` / `kopieVeraendert` / `unlesbar`. Ausgabe sortiert,
  gleiche Eingaben liefern dasselbe Ergebnis. `schlageProfilVor` hebt jedes
  Paket des Profils auf den aktuellen Stand; neue Pakete kommen nie von selbst
  hinzu (`zusaetzlichePaketIds`).
- `rules/derived/regelprofil_vorschau_rules.dart`: Auswirkung geänderter oder
  entfallener Erwerbsvoraussetzungen auf bereits erworbene Fähigkeiten und
  Manöver (`ErworbenAuswirkung`: nichtErworben, unveraendert, neuOffen,
  nichtMehrOffen, entfallen) und Herleitung vorher/nachher je Wert. Die
  Zusammenstellung der Herleitungen steht jetzt in
  `sammleHerleitungenAusSnapshot` und wird von Berechnungssuche und Vorschau
  geteilt; angezeigter und verwendeter Wert sind so dieselben.
- `ablaeufe/regelprofil_uebernehmen.dart` (`RegelProfilUebernehmen`) setzt das
  Profil über `HeroActions.updateHero` (`aendereGespeichertenHelden`, ein
  Dokument). `uebernehmeRegelProfil` weist ein inzwischen geändertes Profil mit
  `StateError` ab und liefert bei gleichem Profil denselben Helden (kein
  Schreiben). `updateHero` bekam dafür einen optionalen `validationCatalog`, damit
  die Normalisierung den Katalog des **neuen** Profils nutzt.
  `aendereHeldMitMeldung` kommt erst mit der Oberfläche dazu (braucht Kontext,
  Planungsprüfung und Fehleranzeige).
- Provider: `regelProfilVergleichProvider(profil)` (geteilt je Profil),
  `regelProfilVorschauProvider(heroId)` (`null` ohne verstandenes Profil),
  `regelProfilUebernehmenProvider`.

*Befund und Korrektur.* Der Resolver sperrte Einträge nur, wenn sein
Paketkatalog das Paket kannte. Ein Profil enthält aber nur seine **aktiven**
Pakete; ließ es etwa `epic_rules_v1.combat_sf` weg, blieben dessen 53 Einträge
sichtbar, anders als im globalen Stand. `loeseRegelProfilAuf` und
`HouseRuleCatalogResolver.resolve` nehmen deshalb `bekanntePaketIds`
(`regelProfilAufloesungProvider` reicht die Pakete der App durch). Betrifft nur
Helden mit Profil; heute schreibt die App keines automatisch.

*Entscheidung.* Der Basiskatalog bleibt nicht eingefroren. Beide Auflösungen
rechnen gegen die aktuellen Basisdaten, verglichen werden Paketkopie gegen
aktuellen Paketstand. Änderungen von `sourceKey` im Basiskatalog selbst zeigt
der Vergleich nur, wenn der Aufrufer `vorherigeBasisDaten` mitgibt; im
Produktivpfad entstehen Sperränderungen durch Profil- und Paketwechsel.

*Abnahme.* Zwei Helden mit verschiedenen Profilen (ein Container) und je ein
Held in zwei `ProviderContainer`n bleiben getrennt
(`test/state/regelprofil_vorschau_provider_test.dart`); ein Update ändert den
Helden erst nach der Übernahme (Ablauf-, Provider- und Regeltests); Bestandshelden
und Hash-Pins sind unverändert.

*Offen.* Oberfläche je Held (Profil wählen, Vorschau zeigen, übernehmen,
Erstübernahme `null → Profil` für Bestandshelden); Gruppenvorgabe („live von der
Gruppe“, Firestore-Regeln verbieten heute Gruppen-Updates). Dazu offene
Fragen: Verhalten bei **mehreren Gruppen** eines Helden, beim **Verlassen der
Gruppe** und **ohne Verbindung** (offline gilt weiter die Kopie im Profil;
wessen Vorgabe gilt, wenn zwei Gruppen verschiedene Pakete verlangen?).
Import/Export prüfen (trägt der Export das Profil mit, was passiert beim Import
in eine App mit anderem Paketstand?).

**Teilstand 14, 14.10.2026 — Oberfläche je Held: Regelprofil festhalten, Vorschau, Übernahme.**

*Umfang.* Die Übersicht (Bestand und UI2-Verwaltung teilen den Tab) zeigt am Ende
die Karte „Regelprofil“ (`ui/screens/hero_overview/hero_regelprofil_section.dart`):

- **Ohne Profil** (Bestand): Hinweis „folgt den globalen Hausregeln“ und der Knopf
  „Aktuellen Regelstand festhalten“. Nach Rückfrage (Paketliste, Hinweis auf
  Speichern und Sync-Änderung) schreibt `uebernehmeRegelProfil(von: null, auf:
  globalesRegelProfilProvider)` das Profil; geschrieben wird nur durch diese
  bewusste Aktion. Der Knopf bleibt gesperrt, bis die Auflösung des Profils
  geladen ist, damit die Normalisierung dessen Katalog bekommt.
- **Mit Profil:** festgehaltene Pakete (Titel aus der Manifestkopie) und der
  Paketstand: „aktuell“ oder „Update steht an“ mit Zahl der Katalogeinträge,
  Werte und betroffenen erworbenen Fähigkeiten. „Vorschau ansehen“ öffnet
  `RegelprofilVorschauDialog` (Pakethinweise, erworbene Fähigkeiten, Werte
  vorher/nachher, Katalogeinträge mit Feldpfad und Paketursache, Ein-/Ausblendungen);
  erst „Übernehmen“ verändert den Helden.
- **Nicht verstandenes Profil** (neuere App): nur Hinweis, keine Aktion.
- Fehler beim Speichern stehen im Dialog bzw. in der Karte (`ZustandFehlerBereich`),
  eine offene Planung wird wie bei jeder Sofortaktion vorher abgefragt.

*Unterbau.* `globalesRegelProfilProvider` (`regelprofil_vorschau_providers.dart`)
liefert den Stand, den die Erstübernahme festhalten würde.
`aendereHeldMitMeldung`/`aendereHeldImEditor` nehmen einen optionalen
`validationCatalog` (Katalog des neuen Profils) und reichen ihn an `updateHero`;
bestehende Aufrufer bleiben unverändert.

*Prüfung.* `test/ui/overview/hero_regelprofil_section_test.dart` (echter Katalog):
Festhalten schreibt den globalen Stand, Abbrechen schreibt nichts, Vorschau ändert
den Helden nicht, Übernahme setzt den aktuellen Paketstand, Speicherfehler bleibt
im Dialog sichtbar, unbekannte Formatversion bietet keine Aktion.

*Offen.* Gruppenvorgabe („live von der Gruppe“, mehrere Gruppen, Verlassen,
Offline); Auswahl zusätzlicher Pakete in der Vorschau (`zusaetzlichePaketIds`);
Zurückführen eines Profils auf „folgt global“; Import/Export; ein Einstieg in der
UI2-Navigation (heute nur die Übersichtskarte); Epische Nachteile lesen weiterhin
den globalen Schalter statt des Profils (`hero_overview_epic_section.dart`).

**Teilstand 15, 18.10.2026 — Herleitungsreste der Proben.**

*Befund.* Die SB-Probe der Wunddialoge übergab keine TaW\*-Herleitung, keine
Zauberprobe eine ZfW\*-Herleitung (Magie-Tab, Probensuche, Gefecht), die
Liturgieprobe im Gefecht keine TaW\*-Herleitung. Vier Gefechtsumbauten
(`gefechtsProbeMitBonus`, `modifiziereGefechtsWirkprobe`,
`gefechtRequestFuerAuftrag`, `gefechtsProbeMitAnsagefolgemalus`) bauten
`ResolvedProbeRequest` neu und verloren `poolHerleitung`.

*Regelklärung (offener Punkt aus Teilstand 9).* Zauberspezialisierung: „im
spezialisierten Aspekt“ zwei zusätzliche effektive ZfP, höchstens eine je Zauber
(WdH S. 292 f.) – bedingt, deshalb wie die Talentspezialisierung ein Schalter
(+2) im Probendialog und kein ZfW\*-Schritt. Merkmalskenntnis: nur „eine Spalte
leichter erlernen“ (WdH S. 289), steht in der Lernspalten-Herleitung.
Repräsentation: Lernspalte (hergeleitet) und Zaubertechnik; fehlende
Komponenten sind Veränderte Technik, eine spontane Modifikation (WdZ S. 21).
AsP-Kosten: Katalogtext, oft Freitext; nur Hinweis im Regelhinweis der Probe.

*Umsetzung.* `ResolvedProbeRequest.copyWith` nimmt `targets`, `basePool` und
`poolHerleitung`; die vier Gefechtsumbauten laufen darüber, der Mirakelbonus auf
den Pool ergänzt den Schritt „Mirakelbonus“. `buildSpellProbeRequest` nimmt
`zfwHerleitung`, `hasSpecialization` und `hinweise`; `ZauberProbenwert` trägt
`spezialisierungen` und `kosten`, `zauberprobeAus` und `gefechtsZauberprobe`
übergeben Herleitung, Schalter und Hinweise (`zauberprobenHinweise`).
`talentHerleitungNachId` (Grundlage von `talentTawNachId`) und
`sbProbeHerleitung` liefern die SB-Herleitung an beide Wunddialoge; der Fallback
ohne Snapshot übergibt keine.

*Prüfungen.* `test/rules/zauber_herleitung_rules_test.dart` (Herleitung = Pool,
Spezialisierung als Schalter, Kostenhinweis), `gefecht_wirken_rules_test.dart`
(Umbauten behalten die Herleitung, Mirakelbonus als Schritt),
`talent_herleitung_rules_test.dart` (`talentHerleitungNachId`),
`test/ui/workspace/wunden_dialog_test.dart` („TaW\* herleiten“ im SB-Dialog).
`flutter analyze --no-pub` ohne Befund in den geänderten Dateien; Gesamtsuite
seriell: 6241 bestanden, 3 übersprungen, 0 fehlgeschlagen. Commit `89331747`.

*Offen.* Unverändert die Punkte unter „Herleitungen“ in der Roadmap
(Eigenschaftsprobe als Ausweichen, bewusst offene Lernregeln).
