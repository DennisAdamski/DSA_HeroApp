# To-do-Liste: Weiterentwicklung der Heldenverwaltung

Stand: 18.09.2026. Grundlage ist die Diskussion „Wenn du die App komplett neu
bauen würdest, was würdest du anpassen?“ und der anschließende Auftrag, alle
sieben Vorschläge für nachfolgende Agenten festzuhalten.

Diese Liste beschreibt geplante Verbesserungen, keine bereits umgesetzte
Architektur. Der aktuelle Auftrag umfasst ausschließlich ihre Dokumentation.
Die Bestandsaufnahme beruht auf Code und Dokumentation; die laufende Oberfläche
wurde dafür nicht praktisch geprüft. Vor einer Umsetzung den jeweiligen
Ist-Zustand erneut prüfen und den konkreten Teilumfang festlegen.

## Arbeitsweise und gemeinsame Grenzen

- Verbindlich bleibt [AGENTS.md](../AGENTS.md). Die Aufgaben sollen schrittweise
  in der bestehenden App umgesetzt werden. Ein vollständiger Neubau ist durch
  diese Liste nicht beschlossen.
- Flutter und Riverpod sowie die Trennung zwischen `HeroSheet`, `HeroState`
  und reinen Regelberechnungen beibehalten. Berechnungen gehören weiterhin
  ausschließlich nach `lib/rules/derived/`.
- Die kanonischen Katalogquellen bleiben die Split-JSON-Dateien unter
  `assets/catalogs/house_rules_v1/`. Bestehende Regelmodule und Tests weiterverwenden.
- Vor Änderungen an gespeicherten Modellen Migration, JSON-Import/-Export und
  Sync-Kompatibilität festlegen. Unbekannte Bestandsdaten erhalten und unklare
  Zuordnungen sichtbar machen. Bestehende Krypto-Wire-Formate unverändert lassen.
- Offene Produktentscheidungen sind pro Aufgabe benannt. Bei ihrer Umsetzung
  anhand des dann gültigen Auftrags klären; sie gelten hier nicht als entschieden.
- Pro abgeschlossenem Teilumfang Tests, Dokumentation und Commit gemeinsam
  abschließen. Ergebnis mit Aufgaben-ID und Commit in dieser Liste nachführen;
  relevante Erkenntnisse nach Duplikatprüfung in Mempalace hinterlegen.

## Übersicht und Reihenfolge

Die IDs entsprechen den sieben Punkten der ursprünglichen Empfehlung.
„Grundlage“ bezeichnet technische Vorarbeiten, „Aufbau“ darauf aufsetzende
Verbesserungen und „Begleitend“ fortlaufende Absicherung.

- [ ] **ARCH-01 — Oberfläche nach Spielsituationen organisieren** · Aufbau
- [ ] **ARCH-02 — Regelrelevante Eigenschaften strukturiert speichern** · Grundlage
- [ ] **ARCH-03 — Gemeinsame Ausrüstungsdaten für Inventar und Kampf** · Grundlage
- [ ] **ARCH-04 — Versionierte Regelprofile und erklärbare Berechnungen** · Aufbau
- [ ] **ARCH-05 — Schreibende Aktionen fachlich aufteilen** · Grundlage
- [ ] **ARCH-06 — Zusammengehörige Änderungen gemeinsam speichern und synchronisieren** · Aufbau
- [ ] **ARCH-07 — Nutzerabläufe und Datenmigrationen absichern** · Begleitend

Empfohlener Einstieg: unter ARCH-07 repräsentative Bestandsfälle sichern, dann
ARCH-02 und ARCH-03 in getrennten Teilprojekten bearbeiten. ARCH-05 kann zunächst
bestehendes Verhalten ohne Modellwechsel entflechten. ARCH-04 baut auf den
strukturierten Daten auf; ARCH-06 nutzt die fachlichen Operationsgrenzen aus
ARCH-05. Die Umsetzung von ARCH-01 folgt diesen Grundlagen, während die Prüfung
der Bedienabläufe und ein Oberflächenentwurf schon früher möglich sind.
ARCH-07 begleitet jede Phase und wird nicht erst am Ende begonnen.

Für den bereits begonnenen Oberflächen-Neubau konkretisieren die
[Redesign-Pläne R1–R3](redesign_implementation.md) einen früher lieferbaren
UI-Teilumfang von ARCH-01 auf vorhandenen Modellen und Aktionen. Dieser
Teilumfang benötigt keine vorgezogene Datenmigration. Erweiterungen wie
strukturierte Merkmale, Regelprofile und atomarer Schaden mit Korrektur bleiben
an ihre hier genannten Grundlagen gebunden; ARCH-07 begleitet auch R1–R3.

## ARCH-01 — Oberfläche nach Spielsituationen organisieren

**Ist-Zustand:** Der Workspace ist nach Fachgebieten wie Talente, Kampf, Magie
und Inventar gegliedert. Bearbeiten und Steigern sind bereits getrennt;
Steigerungsrunden, Proben-Schnellsuche und Inspector existieren.

**Ziel:** Drei verständliche Arbeitsbereiche: **Spielen**, **Held verwalten**
und **Entwicklung planen**. Spielen priorisiert Ressourcen, häufige Proben,
Kampfaktionen und aktive Effekte. Verwaltung erschließt die vollständigen Daten
und manuelle Korrekturen. Entwicklung bündelt Erwerb, Voraussetzungen, AP und
Auswirkungsvorschau.

**Einstieg:** `lib/ui/screens/hero_workspace_screen.dart`,
`lib/ui/screens/workspace/workspace_tab_spec.dart`,
`lib/ui/screens/workspace/probe_quick_search.dart`,
`lib/ui/screens/workspace/inspector/`, `lib/ui/screens/advancement/` und
[Spielmodus-Konzept](spielmodus_konzept.md).

**Entwurfsstand 19.09.2026:** Ein [klickbares Codex-Mockup](mockups/hero-workspace-redesign.html)
zeigt die drei Arbeitsbereiche mit Beispieldaten. Bedienung und Abgrenzungen
stehen in der [Mockup-Anleitung](mockups/README.md). Es ist ein visueller Entwurf;
die Flutter-Umsetzung und die vollständige Funktionszuordnung bleiben offen.

- [ ] Vorhandene Aktionen den drei Arbeitsbereichen zuordnen und Navigation für
  schmale sowie breite Ansichten entwerfen; aktuelle Funktionen vollständig erfassen.
- [ ] Bestehende Proben-, Steigerungs- und Inspector-Komponenten wiederverwenden;
  die Spielansicht um direkten Zugriff auf häufige Aktionen ergänzen.
- [ ] „Schaden erhalten“ als zusammenhängenden Ablauf mit Ressourcenänderung,
  gegebenenfalls Wunden und nachvollziehbarer Korrekturmöglichkeit anbieten.
  *(Ablauf, Dialog und UI2-Schnellaktion umgesetzt, siehe ARCH-05 Teilstand
  (3). Korrigiert wird bisher von Hand anhand des Protokolleintrags; eine
  Rücknahme hängt an ARCH-06, deshalb bleibt der Punkt offen.)*

**Abnahme:** Häufige Spielaktionen sind direkt aus der Spielansicht erreichbar.
Manuelle Korrektur und AP-pflichtige Entwicklung bleiben unterscheidbar. Ein
Bereichswechsel verliert keine ungespeicherten Eingaben oder Steigerungsentwürfe.
Der Schadensablauf verwendet dieselben Regeln wie die übrige App.

**Prüfung:** Widgettests unter `test/ui/workspace/`, `test/ui/advancement/` und
`test/ui/shared/`; Bedienprüfung auf schmalen und breiten Fenstern. Neue fachliche
Schadensregeln separat unter `test/rules/` prüfen.

**Umsetzungsstand 19.09.2026:** Die Flutter-Umsetzung hat als
Oberflächen-Neubau begonnen. Bestand (`lib/ui/`) und Neubau (`lib/ui2/`)
laufen parallel, `AppSettings.oberflaeche` schaltet um. Fertig sind:

- **Aufräumen.** Toter Legacy-Screen entfernt, UI-Variante `klassisch` samt
  zweitem Theme gestrichen.
- **Naht und Umschalter.** `AppRootSwitch` als `child` von `SyncConflictGate`;
  ein Wechsel tauscht nur den Bildschirm und baut Heldenspeicher, Sync und
  Katalog nicht neu auf (`test/ui2/shell/app_root_switch_test.dart`).
- **Token-Schicht.** Farb-, Abstands-, Linien- und Schriftskalen unter
  `lib/ui2/theme/` und `lib/ui2/foundation/`, Sichtprüfung über das
  Token-Blatt. Dabei fiel auf, dass Merriweather und Cinzel ihren Fettschnitt
  nur behaupten: Regular und 700 zeigen in `pubspec.yaml` auf dieselbe Datei.
  Der Neubau verhindert das durch zwei Tests, einen auf das Manifest und einen,
  der die Zeichenbreiten misst.

**Planungsstand nach Mockup-Freigabe, 19.09.2026:** Die
[Umsetzungspläne mit Agentenprompts](redesign_implementation.md) setzen auf dem
vorhandenen UI2-Fundament auf. Für diese Folgeaufträge gelten die **drei
Arbeitsbereiche des freigegebenen Mockups**. Damit wird der ältere Vorschlag
mit zwei Bereichen ersetzt. Entwicklung bleibt technisch eine Sitzung, erhält
aber einen eigenen sichtbaren Bereich. R1–R3 decken den ersten produktiven
UI-Stand ab, nicht den zusätzlichen atomaren Schadensablauf.

**Umsetzungsstand 20.09.2026 — Paket R1 fertig:** Der Neubau ist ein
benutzbarer Rahmen mit echten Helden. Umgesetzt sind die drei Arbeitsbereiche
mit dunkler Navigation, die Heldenwahl über die vorhandenen Provider und der
Schutz ungespeicherter Eingaben bei Modus-, Helden- und Oberflächenwechsel
einschließlich System-Zurück. Tabs, Editoraktionen und Leave-Guard der
Verwaltung liegen jetzt im gemeinsamen `WorkspaceManagementCoordinator`, den
beide Oberflächen benutzen; die vollständigen Fachansichten erreicht der
Neubau vorerst über die injizierte Brücke `KartoBestandsAdapter`. Nachweise,
Commit-IDs und Abgrenzungen stehen unter „R1: Übergabe“ in den
[Umsetzungsplänen](redesign_implementation.md).

**ARCH-01 bleibt trotzdem offen.** Die Spielanordnung mit echten Werten und
Bestandsaktionen ist umgesetzt (R2), ebenso die gestalterische Integration der
Fachansichten und der Entwicklungsbereich samt Gesamtabnahme (R3, siehe
[redesign_acceptance.md](redesign_acceptance.md)). „Schaden erhalten“ gibt es
seit dem ARCH-05-Teilstand (3) als geführten Ablauf in beiden Oberflächen;
es fehlt noch die nachvollziehbare Rücknahme, die an ARCH-06 hängt.

**Abhängigkeiten / offene Entscheidungen:** Schreibende Spielaktionen auf
ARCH-05/06 aufbauen. Navigation, Favoritenverhalten und Korrekturbedienung sind
noch zu konkretisieren. Die im Spielmodus-Konzept vereinbarte Spielerrolle
beibehalten; eine Spielleiterverwaltung ist kein impliziter Bestandteil.

## ARCH-02 — Regelrelevante Eigenschaften strukturiert speichern

**Ist-Zustand:** Vor- und Nachteile sind katalogisiert, werden am Helden aber in
`HeroSheet.vorteileText` und `HeroSheet.nachteileText` gespeichert. Regelwirkungen
werden teilweise aus diesen Texten und Herkunftsmodifikator-Texten geparst.

**Ziel:** Regelrelevante Merkmale über stabile Katalog-IDs mit Stufe, Auswahl und
definierten Wirkungen speichern. Anzeigenamen und beschreibender Freitext sind
unabhängig davon. Voraussetzungen, AP-Kosten und Berechnungen verwenden dieselben
strukturierten Angaben.

**Einstieg:** `lib/domain/hero_sheet.dart`, `lib/catalog/hero_trait_text.dart`,
`lib/catalog/hero_trait_choices.dart`, `lib/rules/derived/modifier_parser.dart`,
`lib/rules/derived/attribute_trait_rules.dart`,
`lib/rules/derived/hero_stat_inputs.dart`,
`assets/catalogs/house_rules_v1/vorteile.json` und `nachteile.json` im selben Ordner.

- [x] Ein Modell für erworbene Merkmale samt Stufe, Auswahl, Herkunft und
  Verknüpfung mit dem Katalog definieren; zunächst Vor- und Nachteile abdecken.
  *(Herkunft als Zuordnungsweg; Herkunft aus Rasse/Kultur/Profession ist
  Folgeschritt, siehe Teilstand.)*
- [x] Eine versionierte Migration aus den Textfeldern entwickeln: eindeutige
  Treffer zuordnen, Mehrdeutigkeiten und unbekannte Texte unverändert erhalten
  und zur Prüfung anzeigen. Migration darf beim erneuten Laden nichts verdoppeln.
- [x] Regelauswertung, Erwerbsprüfung und Bearbeitung auf strukturierte Einträge
  umstellen; doppelte Anwendung aus Alttext und neuem Eintrag ausschließen.

**Abnahme:** Umbenennung eines Katalogeintrags verändert seine Wirkung nicht.
Stufen und Varianten bleiben beim Speichern sowie Import/Export erhalten.
Bestandshelden behalten ihre Werte, sofern keine ausdrücklich begründete
Regelkorrektur vorliegt. Unbekannte Freitexte gehen nicht verloren.

**Prüfung:** Bestehende Parser- und Merkmalsregeltests unter `test/rules/`,
Katalogtests unter `test/catalog/`, Modelltests unter `test/domain/` sowie
`test/data/hero_actions_import_export_test.dart` um Migrationsfälle ergänzen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-07 liefert Bestandsfixtures.
Schema, Behandlung eigener regelwirksamer Merkmale und Übergangsformat sind zu
entscheiden. Herkunftsmerkmale als eigenen Folgeschritt abgrenzen. Der Parser
bleibt während der Übergangsphase als Import-/Kompatibilitätshilfe verfügbar.

**Teilstand 28.09.2026 — Vor- und Nachteile strukturiert.** Alle drei
Unterpunkte sind umgesetzt, die Abnahmekriterien geprüft. Der Hauptpunkt
bleibt offen, bis Herkunftsmerkmale (Rasse, Kultur, Profession) als
Folgeschritt entschieden sind und die manuelle Bedienprüfung vorliegt.

*Entscheidungen (mit dem Nutzer abgestimmt).*

- **Die Liste führt.** `HeroSheet.vorteilEintraege`/`nachteilEintraege`
  (`HeroMerkmal`) sind maßgeblich. `vorteileText`/`nachteileText` bleiben
  als Projektion für die veröffentlichte App bestehen, die nur sie kennt.
  Ändert eine ältere Version den Text, wird die Abweichung angezeigt. Sie wird
  nie still übernommen oder verworfen, auch nicht von `saveHero`; der Nutzer
  entscheidet zwischen „Text übernehmen“ und „Liste behalten“.
- **Wirkungen deklarativ im Katalog** (`wirkungen`: `basiswert`,
  `eigenschaft`, `schalter`, `wundschwelle`, `rast`), ausgewertet über die
  Katalog-ID in `hero_merkmal_wirkung_rules.dart`. 18 Einträge tragen
  Wirkungen, genau die bisher per Namen wirkenden.
- Eigene regelwirksame Merkmale (`LEP+2`) und unbekannte Texte bleiben freie
  Einträge und wirken weiter über den Parser. Mehrdeutige Alttexte werden
  nicht geraten: Sie bleiben frei, tragen ihre Kandidaten und lassen sich
  in der Übersicht zuordnen.
- Übergangsformat: additiv, nur bei Belegung geschrieben. Laden bleibt ein
  Fixpunkt, die Hash-Pins der Bestandshelden sind unverändert. Migriert wird
  zur Laufzeit ohne Speichern und persistent erst beim nächsten `saveHero`
  (mit geladenem Katalog).

Commits:

- `8143e44` — Katalog: `HeroTraitEffect`, `wirkungen` an 18 Einträgen,
  Katalogtest.
- `76916d8` — Domain: `HeroMerkmal`, neue Listen in `HeroSheet`, Wächter
  für unbekannte Felder und Aufzählungswerte, Nachbildung der
  veröffentlichten App verwirft die Listen.
- `0566a54` (+ `26a2cac`) — Regeln: Zuordnung, Projektion,
  Abweichungserkennung, Migration beim Speichern und Wirkung über die
  Katalog-ID. Umgestellt sind Parser, Wundschwelle, Rast,
  Ressourcenaktivierung, Quellenaufschlüsselung, Startwerte und
  Voraussetzungen.
- `3423c83` — Übersicht bearbeitet die Liste. Katalogbezug bleibt beim
  Ändern erhalten, Abweichung und Kandidatenwahl sind sichtbar.
- `e56b90f` — Fixture f09, Hive-, Sync- und Widgettests, Dokumentation
  (technische Übersicht 4.11).

*Prüfungen.*

- Äquivalenztest: Für jeden wirkenden Katalogeintrag rechnen Katalog- und
  Textweg über alle Werte und Auswahlen gleich (Modifikatoren, Rast,
  Wundschwelle, Magieaktivierung).
- Umbenennungstest: Neuer Name im Katalog und im Text wirkt über die ID
  weiter; der reine Namensweg rechnet dann 0.
- Weitere Proben: Zuordnungstabelle einschließlich Komma-Templates,
  römischer Stufen und fester Auswahllisten; Idempotenz; keine
  Doppelanwendung.
- Hive: f01, f02, f03, f05 und f07 werden einmal migriert, danach bleibt der
  Stand fest bei gleichen Regelwerten; Export und Import als Kopie erhalten
  die Liste.
- Sync: Die veröffentlichte App verwirft die Liste; ihr Text wird ohne
  Upload und Konflikt neu zugeordnet. Eine Version, die die Liste bewahrt und
  nur den Text ändert, erzeugt eine sichtbare Abweichung. Ein fremdes
  Speichern löst sie nicht auf.
- Widgettests: Katalogbezug, unveränderte Merkmale bei Speichern ohne
  Änderung, beide Auflösungen der Abweichung, Kandidatenwahl.
- Gegenprobe: Ohne Abweichungserkennung scheitern sechs Proben (Sync, Regeln,
  Übersicht).
- `flutter analyze --no-pub` ohne Befund, volle Suite grün (2749 bestanden,
  3 übersprungen). Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. ~~Mehrere UI-Direktaufrufer rechneten ohne Katalog, also über den
   Namen.~~ *Erledigt mit `63bd0f9`:* Die Einstiegsfunktionen verlangen
   `required RulesCatalog? catalog`, jeder Aufrufer in `lib/` reicht den
   Katalog durch (kein `catalog: null` in `lib/`). Dabei fiel ein echter
   Fehlerweg auf und ist behoben: Das Steigerungs-Replay
   (`applyAdvancementAttributeValue`) rechnete das Startwert-Delta ohne
   Katalog, die Option mit — nach einer Umbenennung von „Herausragende
   Eigenschaft“ hätte es einen falschen Rohwert geschrieben. Die
   Magie-Tab-Sichtbarkeit nimmt den Katalog über `laufenderRegelkatalog`,
   ohne das Laden selbst anzustoßen; bis er geladen ist, gilt der Namensweg.
   Neue Katalogwirkungen brauchen weiterhin einen passenden Namensweg oder
   eine bewusste Ausnahme im Äquivalenztest.
2. Die Migration setzt beim Speichern einen geladenen Katalog voraus
   (`rulesCatalogProvider` ohne Warten). Ohne ihn bleibt der Held Bestandsheld
   und wird beim nächsten Speichern migriert. Der Import eines Bestandshelden
   migriert deshalb nur, wenn der Katalog schon geladen ist.
3. Die veröffentlichte App verwirft die Listen bei jedem eigenen Speichern.
   Danach wird neu migriert; manuell zugeordnete Kandidaten gehen dabei
   verloren und erscheinen erneut zur Prüfung.
4. Herkunftsmerkmale (`rasseModText`, `kulturModText`,
   `professionModText`), die `Herkunft` eines Merkmals aus der Generierung
   und AP-Buchung für nachträgliche Vor-/Nachteile sind nicht Teil dieses
   Teilstands. `trait_ap_cost_rules.dart` bleibt ungenutzt.
5. ~~UI2 bearbeitet Vor-/Nachteile nur über die Bestandsbrücke.~~
   *Erledigt:* Das UI2-Merkmalsblatt (`lib/ui2/merkmale/`, Commits
   `fbe7cd4` Regeln, `71a5a3b` Oberfläche) zeigt Merkmalskarten wie im
   Mockup und bearbeitet sie mit Katalogbezug. Einstieg ist der Abschnitt
   „Vor- und Nachteile“ der Spielansicht; der Übersichts-Tab bleibt.
6. `AvatarSnapshot` vergleicht weiter Texte. Nach der ersten Migration
   unterscheiden sich nur Trennzeichen, nicht die Fragmente.
7. *Nachtrag (Commits `c2b1b54`, `f0afcb6`):* `parseAttributeCode` kannte
   „Gewandtheit“ nur falsch geschrieben; die Zuordnung liest jetzt
   Doppelpunkte als Trenner und speichert Eigenschaften als Kürzel.
   Begabungen und Unfähigkeiten wirken über die neue Wirkungsart
   `lernspalte` auf ihre Ziele (Talent, Talentgruppe, Nah-/Fernkampf,
   Sprachen/Schriften, Zauber, Merkmal je Treffer, Ritualkenntnis),
   abgeleitet in `hero_begabung_rules.dart` und nicht gespeichert.
   „Begabung für X“ wird über die aufgelöste Auswahlliste eindeutig. Katalogvorschauen
   (Talente, Kampftalente, Zauber, Repräsentationsdialog) zeigen die
   wirksame Spalte samt Quelle; Widget-Tests decken Talente, beide
   Kampftalent-Ansichten, Zauber, Zauberkatalog und Rituale ab
   (`test/test_support/begabung_katalog.dart` lädt dafür die echten
   Katalogeinträge). Offen: Zauberspezialisierungen zählen jede Begabung
   wie das Häkchen als eine Spalte (wie bisher ohne Merkmal, Hauszauber und
   Unfähigkeit). Der Textweg (ohne Katalog) kennt keine Lernspalten, das ist
   die bewusste Ausnahme im Äquivalenztest.

## ARCH-03 — Gemeinsame Ausrüstungsdaten für Inventar und Kampf

**Ausgangszustand:** Kampfausrüstung und Inventar werden über
`reconcileInventoryWithCombat` abgeglichen. Verknüpfungsschlüssel für Waffen,
Rüstung und Geschosse enthielten Namen; es bestehen mehrere Darstellungen eines
Gegenstands mit unterschiedlichen Zuständigkeiten für seine Felder.

**Ziel:** Jeden konkreten Gegenstand einmal mit stabiler Instanz-ID speichern.
Kampfkonfiguration und Ausrüstungsplätze referenzieren ihn. Eine Katalog-ID
beschreibt den Gegenstandstyp, eine Instanz-ID das konkrete Exemplar.

**Einstieg:** `lib/domain/hero_inventory_entry.dart`, `lib/domain/combat_config/`,
`lib/rules/derived/inventory_sync_rules.dart`,
`lib/rules/derived/inventory_modifier_rules.dart`, `lib/state/hero_actions.dart`,
`lib/ui/screens/hero_inventory/` und `lib/ui/screens/hero_combat/`.

- [ ] Zuständigkeiten für Gegenstandseigenschaften, Menge und ausgerüstete Slots
  festlegen und ein gemeinsames Modell mit stabilen Referenzen einführen.
- [ ] Vorhandene Kampf-/Inventareinträge migrieren; gleichnamige Exemplare,
  individuelle Eigenschaften und Geschossmengen verlustfrei erhalten.
- [ ] Umbenennen, Ablegen, Verkaufen und Ausrüsten auf das gemeinsame Modell
  umstellen; den namensbasierten Abgleich nach abgesicherter Migration ablösen.

**Abnahme:** Zwei gleichnamige Waffen bleiben unabhängig bearbeitbar. Umbenennen
ändert keine Zuordnung und verliert keine Zusatzdaten. Entfernen eines
Gegenstands hinterlässt keine ungültigen Slot-Referenzen. Kampfwerte und
Inventarmodifikatoren beziehen sich konsistent auf die tatsächlich ausgerüsteten
Exemplare; Import/Export erhält IDs und Verknüpfungen.

**Prüfung:** `test/domain/hero_inventory_entry_model_test.dart`, vorhandene
Inventar-/Kampfregeltests unter `test/rules/`, `test/ui/inventory/` und
Import-/Exporttests um Migration, Namensgleichheit und Slotwechsel ergänzen.

**Abhängigkeiten / offene Entscheidungen:** Bestandsfälle aus ARCH-07 nutzen.
Mengenstapel, aufgeteilte Munition und Identitätsregeln beim Kopieren eines Helden
vor der Modelländerung klären. Schreibvorgänge mit ARCH-05/06 abstimmen.

**Teilstand 27.09.2026 — B2/B3 behoben:** Kampf-Slots für Waffen,
Geschosse, Rüstung und Nebenhand tragen stabile IDs. Beim Laden erhalten
Bestandsdaten deterministische IDs und die Inventar-Namensverweise werden
in Slot-Reihenfolge migriert; neue Slots bekommen beim Speichern UUIDs.
Damit bleiben gleichnamige Exemplare nach Entfernen oder Umbenennen
unabhängig. Domain-Tests pinnen die einmalig geänderten Inhalts-Hashes und
prüfen den Fixpunkt, Regeltests die beiden Befunde, ein Hive-Test Neustart
und Export. `flutter analyze --no-pub` und die vollständige Flutter-Suite
waren grün (2.278 bestanden, drei übersprungen). Die vollständige
ARCH-03-Abnahme ist damit **nicht** erreicht: Das gemeinsame Gegenstandsmodell,
Katalog-IDs und die übrigen Schreibabläufe fehlen. Gemischte Bearbeitung
mit älteren App-Versionen ist wegen der neuen verschachtelten IDs nicht
abgesichert. Auch eine reine ID-Migration kann bei gleichzeitig geänderter
Cloud-Version einen sichtbaren Sync-Konflikt auslösen. Der zugehörige
Fix-Commit ist `f0c9ffc`. *(Überholt durch den Teilstand vom 28.09.2026:
Das Verweisformat ist jetzt mit der veröffentlichten App verträglich.)*

**Teilstand 28.09.2026 — Versions- und Sync-Kompatibilität der
Ausrüstungsdaten.** Umgesetzt wurde der Teilumfang „unbekannte verschachtelte
Felder“, beschränkt auf die Ausrüstung.

*Entscheidung: bewahren statt sperren.* Die Ausrüstungsmodelle sind
unveränderlich, werden per `copyWith` geändert und haben stabile Slot-IDs.
Gespeichert wird zentral, und Hash sowie Konflikt-Diff arbeiten auf
`toJson()`. Damit lassen sich unbekannte Felder verlustfrei erhalten. Eine
sichtbare Schreibsperre wäre nur für nicht-additive Formatänderungen nötig;
solche gibt es nicht. Festgehalten ist stattdessen die Formatregel „nur
additiv, eine neue Bedeutung bekommt einen neuen Schlüssel“
(technische Übersicht, Abschnitt 2.1). Die veröffentlichte App (`main`) lässt
sich nicht ändern. Das noch unveröffentlichte Verweisformat wurde deshalb so
gewählt, dass sie damit verträglich arbeitet.

Drei Commits:

- `f28cb1a` — Zehn Ausrüstungsmodelle bewahren unbekannte Felder:
  `CombatConfig`, Waffe, Fernkampfprofil, Geschoss, Distanzstufe, Rüstung,
  Rüstungsstück, Nebenhand, Inventareintrag und Modifikator. Neu aufbauende
  Wege arbeiten jetzt per `copyWith`: `_mergeEntry` sowie die Editoren für
  Nebenhand, Geschoss, Distanzstufe und Begleiterrüstung. Katalogschlüssel
  gelangen nicht in Heldendaten. Die Hash-Pins bleiben unverändert.
- `192cf41` — Befund B10: Die Sync-Basis ist der lokale Stand. Ein bloßer
  Abgleich lädt keine verkürzte Fassung mehr hoch.
- `cc8ffaa` — `sourceRef` bleibt der Namensverweis, der ID-Verweis steht
  in `slotRef`. Dabei wurde ein Fehler gefunden und behoben: Die Pfeilzahl
  des zweiten gleichnamigen Bogens landete beim ersten. Die Hash-Pins von
  f01, f02, f04 und f06 haben sich einmalig geändert.

*Prüfungen.* Getestet ist jeder Weg aus dem Auftrag: Laden, Bearbeiten
(Abgleich, Editoren, `HeroActions`), Speichern mit echtem Hive samt
Neustart, Import/Export (überschreiben und als Kopie) und der Zwei-Geräte-Sync
mit einem Stand einer neueren Version. Dazu kommen eine gleichzeitig
geänderte Cloud (sichtbarer Konfliktpfad, keepRemote/keepLocal/keepBoth ohne
stillen Verlust) und der Mischbetrieb mit einer Nachbildung der
veröffentlichten App (`test/test_support/veroeffentlichte_app.dart`). Die
Gegenproben scheitern jeweils ohne den Fix. `flutter analyze` war ohne
Befund, die volle Suite grün (2353 bestanden, 3 übersprungen).

*Verbleibende Risiken, ausdrücklich außerhalb dieses Teilumfangs:*

1. ~~Andere verschachtelte Modelle verlieren unbekannte Felder weiterhin:
   `OffhandAssignment`, `CombatSpecialRules`, `CombatManualMods`,
   `WaffenmeisterConfig`, Talente, Zauber, Rituale, die eigenen Felder von
   `HeroCompanion`, Abenteuer und Notizen. Seit B10 geschieht das erst bei
   einer echten Änderung, nicht mehr beim bloßen Abgleich. Der Konflikt-Diff
   zeigt diese Felder nicht.~~ *Erledigt im Teilstand „Alle verschachtelten
   Modelle“ unten.*
2. ~~Unbekannte **Enum-Werte** fallen auf Standardwerte zurück (`itemType`,
   `source`, `traegerTyp`, `combatType`, Nebenhand-`type`, `shieldSize`,
   Modifikator-`kind`) und werden bei einer Änderung überschrieben.~~
   *Erledigt im Teilstand „Unbekannte Aufzählungswerte“ unten.*
3. Die veröffentlichte App verwirft alles Unbekannte, Slot-IDs und
   `slotRef`, und nach jedem Upload dieser Version schreibt sie einmal
   zurück (Echo). Verknüpfungen und Inventardaten überleben; UUIDs und
   Felder neuerer Versionen nicht. Ihr eigenes B2/B3-Verhalten bleibt. Eine
   Offline-Änderung, die mit dem Echo zusammenfällt, ergibt einen sichtbaren
   Konflikt, im Vergleich auch mit geänderten IDs. Verhindern ließe sich das
   Echo nur serverseitig, etwa über Firestore-Regeln.
4. Erhaltene Felder können gegenüber hier bearbeiteten Werten veralten;
   spätere Versionen müssen sie prüfen. `mainWeapon` spiegelt nur die
   gewählte Waffe. Mehr als fünf Distanzstufen werden weiterhin gekürzt.
5. Unbekannte Felder des Transfer-Umschlags gehen verloren. Eine höhere
   `transferSchemaVersion` wird sichtbar abgelehnt.
6. Vorabdaten dieses Branches (ID in `sourceRef`), die zusätzlich die
   veröffentlichte App durchlaufen haben, können falsch zugeordnet werden.
   Das betrifft nur Entwicklergeräte.
7. B10 setzt voraus, dass Laden ein Fixpunkt ist. Die Fixture-Tests sichern
   das ab; ein Fehler wie B1 brächte je Abgleich einen stillen Upload zurück.
8. Befund B9 ist als Kleinfix behoben: `_mergeEntry` stützt sich auf den
   bestehenden Eintrag, Typ und Träger verknüpfter Einträge bleiben erhalten.

*Nächster Schritt:* das gemeinsame Gegenstandsmodell nach den
Abnahmekriterien oben. Außerdem für neue Felder und Enum-Werte die Formatregel
anwenden. Vor einem nicht-additiven Formatwechsel braucht es eine sichtbare
Schreibsperre, die ältere Versionen bereits kennen.

**Teilstand 28.09.2026 (2) — Alle verschachtelten Modelle bewahren
unbekannte Felder.** Restrisiko 1 des vorigen Teilstands ist erledigt.
Hintergrund: ARCH-02 und ARCH-03 bringen neue verschachtelte Felder, und nur
Geräte, die bereits eine Version mit diesem Schutz haben, verlieren sie
nicht. Dieser Stand muss deshalb veröffentlicht sein, bevor ein neues Format
kommt.

*Umfang.* Jedes Modell, das im JSON von `HeroSheet` oder `HeroState` steht,
trägt jetzt eigene `unbekannteFelder` und ein eigenes `jsonSchluessel`
(Liste in der technischen Übersicht, Abschnitt 2.1) — 61 Modelle
einschließlich der zehn aus `f28cb1a`. Ausgenommen ist nur `OffhandSlot`,
das nie geschrieben wird. Neuaufbauten per Konstruktor sind auf `copyWith`
umgestellt: Normalisierung der Nebenhand-Auswahl und der
Talentmodifikatoren, die Modifikator-, Ritual-, Meta-Talent-, SF-,
Zauberdetail-, Abenteuer-, Begleiter-, Übersichts- und Zaubereffekt-Dialoge,
das Abenteuerblatt, Wunden und volle Rast sowie die in `saveHero` neu
errechneten Startwerte (`Attributes.uebernimmWerte`; ohne das erbten sie die
Felder der Rohstartwerte). Objekte, die nur Felder einer neueren Version
tragen, gelten nicht mehr als leer (Text-Overrides, Effekt-Zusatzdaten,
Geburtsdatum).

Commits:

- `0512fac` — Kampf-Rest (Nebenhand-Auswahl, Kampf-SF, manuelle
  Modifikatoren, Waffenmeister samt Bonus).
- `ea8db81` — Talente, Zauber, Rituale, Sprachen, Sonderfertigkeiten.
- `a8bde70` — Begleiter, Abenteuer, Notizen, Kontakte, Gruppen,
  Reisebericht; dazu Befund B11 (Kleinfix).
- `9db8406` — Eigenschaften, Grundwerte, SE-Pools, Ressourcenschalter,
  Geburtsdatum, Bilder, Schnappschuss, Steigerungsverlauf.
- `177b4a3` — Laufzeitzustand: Zaubereffekte, Wirkungsdauer, Wunden,
  Würfelprotokoll, temporäre Modifikatoren.
- `66a7c70` — Vollständigkeitswächter über jede Objektebene.

*Prüfungen.* `zukunftsfelder.dart` deckt jetzt 71 Stellen im Helden
und 7 im Zustand ab, `veroeffentlichte_app.dart` bildet den Verlust in
allen Modellen nach. Geprüft sind Laden (Tabellentest je Modell,
Vollständigkeitswächter über jede Objektebene eines voll belegten Helden
und aller Bestandshelden), Bearbeiten über `HeroActions` und die Editoren
(Widgettests), echtes Hive mit Neustart, Import/Export überschreibend und
als Kopie, Zwei-Geräte-Sync mit Held und Zustand einer neueren Version
einschließlich gleichzeitig geänderter Cloud sowie der Mischbetrieb mit dem
Echo der veröffentlichten App. Gegenproben: Mit vorübergehend leerem
`sammleUnbekannteFelder` scheitern alle Modell- und Ablaufproben; mit
einzeln zurückgesetzten Editoren scheitert jeweils der zugehörige
Widgettest. Dabei fiel auf, dass der Sync-Test den Stand der neueren
Version bisher durch das hiesige Modell schickte und ohne Fix nicht
scheiterte; die Felder werden jetzt direkt ins JSON gesetzt. Die Hash-Pins
der Bestandshelden sind unverändert.

*Verbleibende Risiken:*

1. ~~Unbekannte **Enum-Werte** (Restrisiko 2 oben) und unbekannte
   Wundzonen. Konzept vorgelegt, Umsetzung nach Bestätigung.~~ *Erledigt im
   Teilstand „Unbekannte Aufzählungswerte“ unten.*
2. Was eine bestehende Normalisierung verwirft, verliert auch seine
   unbekannten Felder: Personen, SE-Zeilen und Beute ohne Inhalt,
   Talentmodifikatoren ohne Beschreibung, Ritualkategorien ohne oder mit
   doppelter ID, Zusatzfelder ohne Bezeichnung, ungültige Gesichtsbefunde.
3. Restrisiken 3 bis 7 des vorigen Teilstands gelten unverändert; die
   veröffentlichte App verwirft jetzt nachweislich in allen Modellen.
4. Ein Nutzer, der einen Wert bewusst zurücksetzt (Ritualkategorie auf
   Talentbezug, Zauber-Overrides auf den Katalog), nimmt die Felder des
   entfallenden Objekts mit; bleibt das Objekt bestehen, bleiben sie.

*Nächster Schritt:* unbekannte Enum-Werte nach bestätigtem Konzept (siehe
folgenden Teilstand).

**Teilstand 28.09.2026 (3) — Unbekannte Aufzählungswerte.** Restrisiko 2
des ersten und Restrisiko 1 des zweiten Teilstands sind erledigt. Damit
bewahrt diese Version alles, was eine neuere Version in Held und Zustand
schreibt, soweit es kein bestehendes Normalisieren verwirft (Restrisiko 2
des zweiten Teilstands).

*Konzept (bestätigt).* Kennt diese Version einen Aufzählungswert nicht,
rechnet sie wie bisher mit dem Ersatzwert. Den Rohwert merkt sich das Modell
in `unbekannteEnumWerte` (JSON-Schlüssel → Rohwert, eine eigene Map neben
`unbekannteFelder`) und schreibt ihn in `toJson` anstelle des Ersatzes
zurück. Fehlende und leere Angaben gelten wie bisher als fehlend, es wird
nichts geschrieben, was vorher nicht dastand; Laden bleibt ein Fixpunkt, die
Hash-Pins der Bestandshelden sind unverändert. Änderungsregel: Ein `copyWith`
mit einem **anderen** Wert überschreibt den Rohwert, derselbe Wert (etwa
ein Dialog, der alle Felder neu durchreicht) lässt ihn stehen. Werkzeuge in
`unbekannte_json_felder.dart`: `leseEnumWert`, `enumNachName`,
`festeEnumWerte`, `mitUnbekanntenEnumWerten`, `ohneGeaenderteEnumWerte`.

*Umfang.* 18 Felder in 14 Modellen: Inventareintrag (`itemType`, `source`,
`traegerTyp`), Inventarmodifikator (`kind`), Waffenslot (`combatType`),
Nebenhand (`type`, `shieldSize`), Waffenmeister-Bonus (`type`),
Ritualkategorie (`knowledgeMode`) und ihr Zusatzfeld (`type`), Begleiter
(`typ`), Abenteuer (`status`) mit SE-Belohnung (`targetType`) und Beute
(`itemType`), Wirkungsdauer (`unit`), Würfelprotokoll (`type`,
`automaticOutcome`) und der Monat des aventurischen Datums. Unbekannte
Wundzonen hält `WundZustand.unbekannteZonen`: Sie zählen nicht mit, bleiben
beim Bearbeiten bekannter Zonen stehen und heilen bei der vollen Rast.
Dazu die Befunde B12 und B13 als Kleinfixe (Befundtabelle unten): beide
hätten sonst mit dem Ersatzwert Daten verloren bzw. verdoppelt.

Commit: `9d2aeaa`.

*Prüfungen.* `zukunftsfelder.dart` setzt zusätzlich an 15 Stellen im Helden
und 4 im Zustand einen unbekannten Wert (`zukunftsWert`, eine Wundzone
`zukunftsZone`); `veroeffentlichte_app.dart` schreibt dort wie die
veröffentlichte App den Ersatz. Ein Tabellentest je Feld prüft Ersatz,
Rohwert, Fixpunkt, beide Zweige der Änderungsregel und unverändertes
Verhalten bekannter, fehlender und leerer Werte. Die Ablauf-, Hive-,
Import/Export- und Zwei-Geräte-Proben aus Teilstand (2) laufen mit denselben
Helden und decken die Aufzählungen dadurch mit ab. Gegenproben: Ohne das
Merken in `leseEnumWert` scheitern 40 Tabellen- und Sync-Proben sowie die
Ablaufprobe; ohne `unbekannteZonen` die Wundprobe, der Sync und der Ablauf;
ohne B12- bzw. B13-Fix die jeweilige Abgleichprobe (B13 auch der Ablauf).
Eine Änderungsregel „nie überschreiben“ bzw. „immer löschen“ lässt je 16
Proben scheitern (das Würfelprotokoll hat kein `copyWith`). Die Hash-Pins
der Bestandshelden sind unverändert; `flutter analyze --no-pub` und die
volle Suite sind grün (2673 bestanden, 3 übersprungen).

*Verbleibende Risiken:*

1. Regeln rechnen mit dem Ersatz. Ein Modifikator unbekannter Art wirkt
   etwa als Eigenschaftsmodifikator (`stat`) auf sein `targetId`, eine
   unbekannte Kampfart als Nahkampf, ein unbekannter Abenteuerstatus als
   laufend. Die Anzeige zeigt den Ersatz, nicht den Rohwert.
2. Verknüpfte Inventareinträge übernehmen `itemType` und `source` bei jedem
   Abgleich aus ihrem Slot; ein unbekannter Typ dort wird deshalb durch
   den Slottyp ersetzt. Ein verknüpfter Eintrag mit unbekannter Quelle
   bleibt nach B12 unverändert, folgt aber auch keinen Slotänderungen mehr.
3. Abgedeckt sind alle Stellen, an denen Held und Zustand einen
   Aufzählungswert parsen; ausgenommen bleiben das nur gelesene
   `OffhandSlot.mode` und die Steigerungsart, die B5 schon bewahrt.
   Eigenschaftskürzel, Repräsentationen und ähnliche Kennungen liegen als
   Text im Modell und bleiben ohnehin roh. Zahlen, die beim Laden begrenzt
   werden (etwa Zoom und Fokus der Bilder), zählen zu den Normalisierungen
   aus Restrisiko 2 des zweiten Teilstands.
4. Restrisiken 2 bis 4 des zweiten Teilstands gelten unverändert.

*Nächster Schritt:* das gemeinsame Gegenstandsmodell nach den
Abnahmekriterien oben. Dieser Stand muss vorher veröffentlicht sein.

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
[Katalog-Workflow](catalog_import_workflow.md).

- [ ] Profilzuordnung, Versionierung und Auflösung definieren; Bestandshelden
  mit ihrem bisher wirksamen Regelsatz übernehmen.
- [ ] Vorschau für Profil-/Paketupdates implementieren: geänderte Werte und
  Erwerbsvoraussetzungen anzeigen, erst durch Übernahme verbindlich machen.
- [ ] Ein gemeinsames Ergebnisformat für Regelherleitungen einführen und
  schrittweise auf Basiswerte, Kampf, Talente, Magie und Steigerungen anwenden.
  Die UI zeigt die Herleitung aus dem Regelmodul, ohne sie selbst nachzurechnen.

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

## ARCH-05 — Schreibende Aktionen fachlich aufteilen

**Ist-Zustand:** `HeroActions` bündelt unter anderem Erstellung, Normalisierung,
Speichern, Import/Export und Avataroperationen. `SyncingHeroRepository` verbindet
lokale Speicherung, Remote-Abgleich und Konfliktbehandlung. Beide bündeln viele
Verantwortlichkeiten und erschweren isolierte Änderungen.

**Ziel:** Kleine, fachlich benannte Anwendungsabläufe wie „Steigerungsrunde
übernehmen“, „Ausrüstung wechseln“, „Rast abschließen“ und „Held importieren“.
Sie koordinieren Prüfung und Speicherung; Regelberechnungen bleiben in den
Regelmodulen. Riverpod bindet die Abläufe an die Oberfläche.

**Einstieg:** `lib/state/hero_actions.dart`,
`lib/state/advancement_providers.dart`, `lib/data/hero_repository.dart`,
`lib/data/syncing_hero_repository.dart`,
`lib/ui/screens/workspace/rest_dialog.dart` und `lib/rules/derived/advancement_apply.dart`.

- [x] Schreibpfade inventarisieren und pro Ablauf Eingaben, Ergebnis,
  Vorbedingungen, Seiteneffekte und Speichergrenzen festhalten.
  *([schreibpfade_inventar.md](schreibpfade_inventar.md))*
- [x] Einen abgegrenzten Ablauf zunächst ohne Verhaltensänderung extrahieren,
  mit expliziten Abhängigkeiten statt uneingeschränktem Zugriff auf alle Provider.
  *(„Rast abschließen“; bewusst mit zwei kleinen Verhaltensänderungen, siehe
  Teilstand.)*
- [ ] Weitere Abläufe nach demselben Prinzip entflechten; bestehende Aufrufer
  schrittweise migrieren und benötigte Kompatibilitätseinstiege erhalten.
  *(Stand 05.10.2026: Rast, Laufzeitzustand, Schaden erhalten, die
  Sofortaktionen des Bogens und des Kampf-Tabs sowie der Inventareditor sind
  frisch; offen sind die Editorentwürfe, siehe Teilstände (1) bis (8).)*

**Abnahme:** Abläufe sind ohne gerenderte Oberfläche prüfbar. Normalisierung und
Validierung haben je eine klare Zuständigkeit. Widgets und Provider enthalten
keine neu duplizierten Regelberechnungen. Fehler beim Speichern werden an die
aufrufende Oberfläche weitergegeben; bisheriges Verhalten bleibt abgesichert.

**Prüfung:** Betroffene Tests unter `test/state/` und `test/data/`, insbesondere
`test/state/advancement_session_test.dart`, sowie die jeweiligen Widgettests.

**Abhängigkeiten / offene Entscheidungen:** Kann mit einer verhaltenserhaltenden
Extraktion beginnen. Zuschnitt und Ablage der Anwendungsschicht am ersten
konkreten Ablauf festlegen; keine zusätzlichen Schichten ohne klaren Nutzen.
Operationsgrenzen bilden die Grundlage für ARCH-06.

**Teilstand 29.09.2026 — Schreibpfade inventarisiert, „Rast abschließen“
als erster Ablauf.** Die ersten beiden Unterpunkte sind umgesetzt. Der
Hauptpunkt bleibt offen, bis weitere Abläufe entflochten sind.

*Entscheidungen (mit dem Nutzer abgestimmt).*

- **Ablage:** `lib/ablaeufe/` für Anwendungsabläufe ohne Riverpod und
  Flutter. Abhängigkeiten kommen per Konstruktor, aus `data/` nur die
  `HeroRepository`-Schnittstelle. Ein Wächtertest prüft die Importe
  (`test/ablaeufe/abhaengigkeiten_test.dart`). Die Riverpod-Bindung liegt
  in `lib/state/ablauf_providers.dart`. `HeroActions` bleibt als
  Kompatibilitätseinstieg bestehen.
- **Erster Ablauf „Rast abschließen“, nicht streng verhaltensneutral:**
  - Der Ablauf lädt den Zustand frisch und ersetzt nur die Rastfelder, statt
    den beim Rendern erfassten Zustand zurückzuschreiben. Das entspricht dem
    `updateHeroState`-Muster. Zuvor gingen Würfelprotokolle, Wunden oder
    Effekte verloren, die zwischen Öffnen und Übernehmen gespeichert wurden.
  - Speicherfehler erscheinen im Panel, und beide Aktionen sind gesperrt,
    solange gespeichert wird. Vorher gab es weder Fehleranzeige noch Schutz
    vor doppeltem Übernehmen.
  - Die Rast rechnet auf den gespeicherten Werten. Ohne Zwischenänderung ist
    das Ergebnis dasselbe wie bisher.
- **Regel statt Widget:** Die Vorschau- und Phasenrechnung, die Zuordnung
  von Aktivität zu Teilregeln und die Probenauswertung stehen jetzt in
  `rest_outcome_rules.dart`. Einzige bewusste Rechenabweichung: Ein
  negatives Maximum gilt als 0. Bisher warf `clamp` dort einen Fehler.

Commits:

- `7b08cd1` — Regel: `computeRestOutcome`, `RestActivity`,
  `isRestProbeSuccessful`, `RestRollSlot`, `applyRestOutcome`.
- `63935d3` — `lib/ablaeufe/zustand_schreiben.dart`
  (`aendereGespeichertenZustand`). `HeroActions.saveHeroState` und
  `updateHeroState` stempeln bzw. delegieren darüber. Dazu der Wächtertest
  und der Eintrag in CLAUDE.md.
- `3ee08b9` — `RastAbschliessen`, `baueRastProtokoll`,
  `rastAbschliessenProvider`. Der Hive-Ablauftest führt den Fullrestore
  jetzt über den Ablauf.
- `80b2944` — `RestPanel` nutzt Regel und Ablauf und zeigt Fehler an; dazu
  der Widgettest `rest_panel_test.dart`.
- `5597211` — Aufteilung in Teildateien unter `workspace/rest/`,
  verhaltensfrei. `rest_dialog.dart` schrumpft von 1574 auf 637 Zeilen.
- Abschluss-Commit mit Inventar und Dokumentation.

*Prüfungen.*

- Regeltests für jede Aktivität, darunter Bettruhe mit und ohne zweite
  Phase, außerdem Krankheit, fehlende Würfe, Probengrenzen, Begrenzung auf
  das Maximum, die bisherigen Eigenheiten und das negative Maximum.
- Ablauftests mit `FakeRepository`:
  - Zwischenänderungen bleiben erhalten; es ändern sich nur die erwarteten
    Felder (`expectNurGeaendert`).
  - Protokoll: Reihenfolge, Texte, Zeitstempel und Grenze.
  - fehlender Zustand und Fehlerweitergabe.
- Widgettests:
  - Übernehmen schreibt Werte und Protokoll.
  - Fehleranzeige bei Übernehmen und Fullrestore.
  - Sperre während des Speicherns.
  - Fullrestore mit Bestätigung und Abbruch.
  - Die bestehenden Workspace-Tests laufen unverändert.
- Gegenproben:
  - Ohne Sperre scheitert der Sperrtest.
  - Mit einem verbotenen Import scheitert der Wächter.
- `flutter analyze --no-pub` ohne Befund, volle Suite grün (2842
  bestanden, 3 übersprungen); die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Maxima und KO/IN-Zielwerte kommen aus dem berechneten Snapshot, der
   `tempMods` des Zustands einbezieht. Ändern sie sich zwischen letzter
   Anzeige und Übernehmen, rechnet die Rast mit dem alten Wert. Ein
   Neuberechnen im Ablauf bräuchte Katalog und Hausregeln (ARCH-06).
2. Laden, Ändern und Schreiben ist keine Transaktion gegen parallele
   Schreibwege, wie bei `updateHeroState`.
3. Die Würfelprotokolleinträge der Rast tragen jetzt den Zeitpunkt des
   Speicherns statt den ihres Aufbaus. Der Unterschied liegt im
   Millisekundenbereich.
4. Nächste Kandidaten nach demselben Muster (Befunde im Inventar):
   - ~~die Snapshot-Schreibwege des Zustands: Ressourcen, Zaubereffekte,
     Würfelprotokoll per `unawaited`, Wunden~~ *Erledigt im Teilstand
     „Snapshot-Schreibwege des Zustands“ unten.*
   - ~~danach „Schaden erhalten“ als eigener Ablauf (Voraussetzung für
     ARCH-01)~~ *Erledigt im Teilstand „Schaden erhalten“ unten.*
   - ~~`_filterKnownTraitWarnings` wartet mit `rulesCatalogProvider.future`
     und kann bei einem Katalogfehler hängen.~~ *Erledigt als Kleinfix:*
     `saveHero` wartet über ein Abo mit Zeitlimit (20 s) und speichert bei
     Fehler oder Zeitüberschreitung mit ungefilterten Restfragmenten.
     Nachgewiesen und abgesichert ist der Hänger bei einem nie fertigen
     Katalog (`test/state/hero_actions_katalog_warten_test.dart`). Weitere
     `.future`-Wartestellen stehen im Inventar (Befund 2).

**Teilstand 29.09.2026 (2) — Snapshot-Schreibwege des Zustands.** Befund 1
des [Schreibpfad-Inventars](schreibpfade_inventar.md) ist behoben. Der
Hauptpunkt bleibt offen: Die Bogen-Schreibwege und „Schaden erhalten“
stehen noch aus.

*Befund.* Würfelprotokoll, Ressourcen-Stepper, Inspector-Vitals und -Magie,
Belastung, Zaubereffekte und Wunden schrieben einen beim Rendern erfassten
Zustand vollständig zurück. Was ein anderer Schreibweg in der Zwischenzeit
gespeichert hatte, ging dabei verloren: etwa ein Wurf, der während eines
offenen Dialogs protokolliert wurde. Selbst `updateHeroState` schützte nicht
vor zwei nicht abgewarteten Aufrufen. Beide lasen denselben Stand, der
zweite überschrieb den ersten. Nachgewiesen ist das für zwei direkt
nacheinander protokollierte Würfe.

*Entscheidungen.*

- **Reihenfolge statt Transaktion:** `aendereGespeichertenZustand` reiht
  Änderungen je Speicher und Held ein. Die Warteschlange hängt per
  `Expando` am Speicherobjekt statt an einem globalen oder Riverpod-Zustand.
  Dadurch profitieren alle bestehenden Aufrufer ohne Umbau, auch
  `RastAbschliessen`, und getrennte Speicher blockieren einander nicht. Ein
  Fehler hält die folgenden Änderungen nicht auf. Keine Transaktion
  gegenüber Schreibwegen an der Funktion vorbei (ARCH-06).
- **Ein UI-Einstieg:** `aendereZustandMitMeldung`
  (`lib/ui/screens/shared/zustand_aendern.dart`) lädt frisch, ersetzt nur
  die eigenen Felder und zeigt Fehler als Snackbar „… nicht gespeichert“.
  Die UI2-Ressourcenbrücke nutzt denselben Weg.
- **Absolut oder relativ:** Ressourcen bleiben absolut (der angezeigte Wert
  ±1 bzw. ±5), wie in der UI2-Brücke. Der Stepper klemmt auf `0..max`; ein
  relativer Schritt vom gespeicherten Wert könnte ein gespeichertes
  negatives LeP sonst auf 0 heben. Belastung, Wunden, Unterdrückung und
  Restdauer zählen dagegen vom gespeicherten Wert, dort gibt es keine
  solche Grenze.
- **Regel statt Widget:** Die Zustandsänderungen der Zaubereffekte stehen in
  `active_spell_state_rules.dart`. Die drei fast gleichen Wege „Wunde
  hinzufügen“ (Detaildialog, Inspector-Sektion, Inspector-Karte) sind jetzt
  einer (`fuegeWundeHinzu`).
- **Kleine Verhaltensänderungen:** Ist der Zustand im Provider noch nicht
  geladen, schreiben Würfelprotokoll und Zaubereffekte trotzdem, statt still
  nichts zu tun. `HeroActions.updateHeroState` liefert den gespeicherten
  Zustand; der Unterdrückungsdialog sieht dadurch den tatsächlich
  gespeicherten Wundzustand.

Commits:

- `93ebab4` — Reihenfolge je Held in `aendereGespeichertenZustand`, dazu
  `updateHeroState` mit Rückgabewert.
- `53700fa` — Regel `active_spell_state_rules.dart` mit Tests.
- `3dedf8d` — Oberfläche: alle genannten Schreibwege frisch, Fehler
  sichtbar, Wundabläufe zusammengeführt.
- Abschluss-Commit mit Inventar und Dokumentation.

*Prüfungen.*

- Ablauftests (`test/ablaeufe/zustand_schreiben_test.dart`): Zwei
  gleichzeitige Änderungen bleiben beide erhalten; ein Fehler hält die
  folgende Änderung nicht auf; verschiedene Helden warten nicht aufeinander.
- Regeltests (`test/rules/active_spell_state_rules_test.dart`): jede
  Funktion; nur die eigenen Felder ändern sich; Zählen ist wiederholbar.
- Widgettests (`test/ui/shared/zustand_frisch_schreiben_test.dart`): Ein
  anderer Schreibweg speichert nach dem Aufbau Wurf, KaP und Bauchwunde.
  Geprüft wird, dass sie nach jeder Bedienung erhalten bleiben: zwei nicht
  abgewartete Würfe, Stepper, Belastung mit zwei schnellen Klicks,
  Zaubereffekt umschalten, Restdauer zählen und Wunde hinzufügen samt
  Unterdrückungsdialog. Dazu Fehleranzeigen für Stepper und Würfelprotokoll.
- Gegenproben: Ohne Warteschlange scheitert der Ablauftest mit zwei
  gleichzeitigen Änderungen. Mit dem alten Oberflächencode scheitern alle
  acht Widgettests.
- `flutter analyze --no-pub` ohne Befund, volle Suite grün (2864
  bestanden, 3 übersprungen). Die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Snapshot-Schreibwege des Zustands bleiben im Übersichtseditor
   (Editorentwurf, Bogen und Zustand getrennt), beim Anlegen und beim
   Import. Wer `HeroActions.saveHeroState` nutzt, ist nicht eingereiht.
2. ~~Ressourcen bleiben absolut: Zwei Klicks, bevor die Oberfläche den ersten
   Stand zeigt, ergeben einen Schritt statt zwei.~~ *Erledigt im Nachtrag
   unten.*
3. Der Inspector-Vitals- und -Magie-Tab haben keinen eigenen Widgettest. Sie
   nutzen denselben Einstieg wie der geprüfte Stepper.
4. Snapshot-Schreibwege des **Bogens** bleiben: Dauermodifikatoren,
   Wundschwelle, Inventar, Kampf und die Sofortaktionen der Übersicht.
   *Die Sofortaktionen sind im Teilstand (5) behoben; Inventareditor und
   Kampf bleiben.*
5. ~~Nächster Schritt: „Schaden erhalten“ als eigener Ablauf. Er kann jetzt auf
   `aendereGespeichertenZustand` und `aendereWundZustand` aufsetzen und ist
   die Voraussetzung für ARCH-01. Die Korrekturmöglichkeit bleibt an ARCH-06
   gebunden.~~ *Erledigt im Teilstand „Schaden erhalten“ unten.*

*Nachtrag 29.09.2026 — schnelles Tippen mit Konto-Sync.* Eine manuelle
Prüfung zeigte: Wer schnell viele AsP verbraucht, bekommt eine Fehlermeldung
hinter dem Blatt und Sync-Konflikte. Nachgestellt mit einer verzögerten Cloud,
die jeden Schreibvorgang als Echo zurückschickt:

- Ohne Warteschlange (Stand `main`) kamen von zehn Klicks vier in der Cloud
  an. Die Uploads liefen parallel auf derselben Basisrevision; der zweite
  und das Echo des ersten sahen wie eine fremde Änderung aus, es entstand
  ein Konflikt mit sich selbst.
- Mit der Warteschlange dieses Teilstands gab es keinen Konflikt mehr, aber
  jeder Klick wartete zwei Netzwege ab. Die Anzeige lief hinterher, und
  Klicks auf den veralteten angezeigten Wert gingen verloren.

*Entscheidungen (mit dem Nutzer abgestimmt: Fehler wie beim Rastpanel,
jede Eingabe soll sicher verarbeitet werden).*

- **Lokal sofort, Cloud gebündelt:** `SyncingHeroRepository.saveHeroState`
  endet nach dem lokalen Speichern. `GebuendelteLaeufe` lädt je Held im
  Hintergrund hoch, nie zwei gleichzeitig, immer den neuesten lokalen Stand;
  zehn Klicks ergeben höchstens zwei Uploads. Online-Stände, die während
  eines Uploads eintreffen, werden erst danach bewertet: Solange er läuft,
  ist der lokale Stand voraus, und das eigene Echo sähe fremd aus. `syncNow`
  wartet auf laufende Uploads und lädt über dieselbe Bündelung hoch. Der
  Bogen (`saveHero`) wartet weiterhin auf seinen Upload.
- **Jeder Klick zählt:** Ressourcenknöpfe melden eine `RessourcenAenderung`
  (`ressourcen_aenderung_rules.dart`) statt eines fertigen Werts: ein Schritt
  vom gespeicherten Wert oder Setzen (Zurücksetzen auf das Maximum). Grenzen
  gelten nur in Schrittrichtung; ein −1 hebt gespeicherte negative LeP
  nicht auf 0, ein +1 senkt keine Überheilung.
- **Fehler dort, wo bedient wird:** `ZustandFehlerBereich` und
  `ZustandFehlerAnzeige` zeigen „… nicht gespeichert“ im Stepper, im
  UI2-Ressourcenblatt, im Zaubereffekt- und Wundendialog, in den
  Inspector-Tabs Vitals und Magie sowie im UI2-Zustandsblock; der nächste
  Erfolg blendet die Meldung aus. Die Snackbar bleibt Rückfall. Netzfehler
  erreichen diese Anzeige nicht mehr, sie stehen im Sync-Status und
  `syncNow` holt den Upload nach.

Commits: `b744dcd` (Sync), `02693f2` (Regel und Oberfläche) und der
Dokumentations-Commit.

*Prüfungen.* `test/data/zustand_schnell_tippen_sync_test.dart` (Cloud mit
40 ms Laufzeit, Echo vor der Antwort): Zehn Klicks stehen lokal ohne
Wartezeit, weniger als zehn Uploads, kein Konflikt. Offline bleibt jeder Klick
lokal und `syncNow` holt ihn nach. Eine gemeldete fremde Änderung wird
übernommen, eine nicht gemeldete wird ein Konflikt. Dazu
`gebuendelte_laeufe_test.dart`, `ressourcen_aenderung_rules_test.dart` und
Widgettests für fünf schnelle Klicks im Stepper, drei −5 im UI2-Blatt bis
zur Untergrenze und Fehler im Blatt bzw. Dialog. Gegenproben: Mit dem alten
Sync-Code scheitert der Latenztest (877 ms). Ohne Zurückstellen der Echos
entsteht der Selbstkonflikt. Mit absolutem Setzen scheitern beide
Schnellklick-Tests. Zwei Zwei-Geräte-Tests warten jetzt im Offline-Abschnitt
auf den Hintergrund-Upload (`warteAufUebertragungen`), weil er sonst erst
nach dem Umschalten liefe.

*Verbleibende Risiken.*

1. Zwischen lokalem Speichern und Upload liegt jetzt ein Fenster. Wird die
   App darin beendet, holt der nächste `syncNow` den Stand nach (wie offline).
   Ein anderes Gerät sieht ihn erst dann.
2. Ein Upload, der offline angestoßen wurde und erst wieder online läuft,
   überträgt den Zustand vor dem nächsten Abgleich des Helden. Ändern zwei
   Geräte offline Held **und** Zustand, kann der Zustands-Konflikt dann als
   eigener Eintrag statt gebunden an den Helden erscheinen, wie schon
   bisher beim Speichern mit Verbindung.
3. Fehler beim Protokollieren eines Wurfs erscheinen weiter als Snackbar,
   weil der Probendialog keinen eigenen Fehlerbereich hat. Da der Upload
   nicht mehr dazugehört, bleiben dafür nur lokale Speicherfehler.
4. Der Bogen (`saveHero`) wartet weiter auf seinen Upload; schnelle
   Bogenänderungen (Inventar) laufen nicht über die Bündelung.

**Teilstand 29.09.2026 (3) — „Schaden erhalten“ als Ablauf.** Der
Hauptpunkt bleibt offen: Die Bogen-Schreibwege stehen noch aus.

*Entscheidungen (mit dem Nutzer abgestimmt).*

- **Wunden sind ein Vorschlag.** Ob ein Treffer Wunden schlägt, hängt auch
  vom Angriff ab (Pfeile senken die Wundschwelle um 2). Der Dialog fragt
  diesen Modifikator ab und schlägt je echt überschrittener
  Wundschwellenstufe (0,5 KO, KO, 1,5 KO, 2 KO, jeweils mit Eisern bzw.
  Glasknochen) eine Wunde vor. Der Nutzer entscheidet über die Zahl.
- **Zone:** wählbar oder per W20 über `resolveTrefferzone`. Die Zusatzwürfe
  (Kopf 2W6 INI-Malus, Brust/Bauch 1W6 SP je Wunde, dritte Kopfwunde 2W6 SP)
  kommen aus der vorhandenen Trefferzonentabelle; `TrefferzonenZusatzwurf`
  trägt dafür jetzt seine Wirkung.
- **TP(A) als Umschalter:** Ausdauerschaden senkt nur AuP, höchstens bis 0,
  und schlägt keine Wunden. Ein Überlauf auf LeP ist nicht vorgesehen.
- **LeP ohne Untergrenze,** wie bei der Anzeige in UI2. RS kommt vorbelegt
  aus der Kampfvorschau (Gesamt-RS, Zonenrüstung gibt es im Modell nicht)
  und ist änderbar.
- **Korrektur:** Jede Buchung erzeugt einen Protokolleintrag mit
  `ProbeType.damage` und allen Werten; einen neuen Aufzählungswert gibt es
  bewusst nicht. Eine Rücknahme gehört zu ARCH-06.
- **Oberfläche:** Der Dialog liegt im Bestand (`workspace/schaden/`), weil
  Würfel und Wundunterdrückung dort liegen. UI2 öffnet ihn über die neue
  Brückenmethode `KartoBestandsAdapter.schadenErhalten` als dritte
  Schnellaktion. Nach neuen Wunden folgt die vorhandene Unterdrückungsabfrage
  (`bieteWundUnterdrueckungAn`, aus `fuegeWundeHinzu` herausgelöst).

Commits:

- `83c3567` — Regel `schaden_rules.dart` mit Tests, Wirkung der
  Zusatzwürfe.
- `41d1070` — Ablauf `SchadenErhalten`, Protokoll, Provider, Ablauftests.
- `fc37de6` — Dialog im Inspector-Vitals-Tab mit Widgettests.
- `7a05c3d` — UI2-Schnellaktion über die Brücke, Adapter- und
  Spielansichtstests; der Test gegen erfundene Bedienelemente prüft weiter
  Rundenzähler und Rücknahme.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests (`test/rules/schaden_rules_test.dart`): SP-Grenze, „echt
  größer“ an jeder Stufe, Angriffsmodifikator, Merkmalsbonus, vier Wunden,
  Kappung an der vollen Zone, Kopf-INI, Brust-Zusatz, negative LeP, AuP bis
  0, nur die eigenen Felder ändern sich, widersprüchliche Buchungen werden
  abgewiesen.
- Ablauftests (`test/ablaeufe/schaden_erhalten_test.dart`): nur LeP, Wunden,
  Protokoll und Stempel ändern sich; Protokolltext; Ausdauer; eine
  Zwischenänderung (LeP, AsP, Wunde, Wurf) bleibt erhalten, und die Kappung
  richtet sich nach dem gespeicherten Stand; fehlender Zustand;
  Fehlerweitergabe.
- Widgettests (`test/ui/workspace/schaden_dialog_test.dart`): vorbelegter
  RS, Vorschlag und W20-Zone mit Zusatzwurf, überstimmter Vorschlag mit
  Angriffsmodifikator, volle Zone, Ausdauer, Fehler im Panel, Sperre während
  des Speicherns, Dialog schließt sich und bietet die Unterdrückung an. Dazu
  der Brückentest im Kompatibilitätstheme und die UI2-Schnellaktion.
- Gegenproben: Ohne Kappung an den freien Plätzen scheitern der Regeltest
  „volle Zone“ und der Ablauftest mit Zwischenänderung. Rechnet der Ablauf
  auf einem veralteten statt dem frischen Stand, scheitern der
  Zwischenänderungs- und der Leerzustandstest.
- `flutter analyze --no-pub` ohne Befund, volle Suite grün (2913
  bestanden, 3 übersprungen). Die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Keine Rücknahme; eine falsche Buchung korrigiert der Nutzer von Hand
   (ARCH-06).
2. ~~Die Unterdrückungsabfrage unterdrückte höchstens eine Wunde.~~
   *Behoben (Nutzervorgabe):* Alle Wunden eines Angriffs werden nur
   gemeinsam unterdrückt, in einem Speichervorgang; die Erschwernis nimmt
   `computeSbUnterdrueckungErschwernis` mit der Zahl neuer Wunden (+8 bzw.
   +12). Widgettest „alle Wunden eines Angriffs werden gemeinsam
   unterdrückt“; mit Unterdrückung nur einer Wunde scheitert er.
7. ~~**Noch per dsa-rules-MCP am Rechner zu validieren** (in dieser Umgebung
   war der Server nicht erreichbar): LeP ohne Untergrenze; TP(A) mit
   RS-Abzug und ohne Überlauf auf LeP; Wunden über die freien Plätze einer
   Zone verfallen. Außerdem die Rundung der Wundschwellen: Gelten sie als
   reale (gebrochene) Werte, z. B. 6,5 bei KO 13, oder werden sie immer
   aufgerundet? Heute rundet `computeWundschwelle` ab, die Stufen runden
   kaufmännisch (Befund 4); je nach Ergebnis beide angleichen.~~
   *Validiert und korrigiert in Teilstand (4):* TP(A) trifft zur Hälfte auch
   die LeP; Wundschwellen sind ganzzahlig und kaufmännisch gerundet.
3. Wundschwellen und RS stammen aus dem berechneten Snapshot. Die
   Zusatzwürfe beziehen sich auf die angezeigte Wundzahl der Zone; kappt der
   gespeicherte Stand die Wunden stärker, bleibt der eingetragene
   Zusatzschaden trotzdem gebucht.
4. ~~Befund: Das einzelne `computeWundschwelle` (Inspector „WS n“) rechnet
   KO/2 abgerundet ohne den Eisern/Glasknochen-Bonus, die Stufen rechnen
   kaufmännisch gerundet mit ihm. Der Ablauf nutzt die Stufen; die Anzeige
   kann bei ungeradem KO oder mit Eisern abweichen. Nicht behoben.~~
   *Behoben in Teilstand (4):* `computeWundschwelle` ist die erste Stufe.
5. Kein Encounter: Schaden wird nicht aus einem Angriff übergeben, sondern
   eingetragen (Spielmodus-Konzept Phase 3).
6. ~~Nächster Schritt: die Snapshot-Schreibwege des **Bogens**
   (Dauermodifikatoren, Wundschwelle, Inventar, Kampf, Sofortaktionen der
   Übersicht).~~ *Sofortaktionen erledigt im Teilstand (5); Inventareditor
   und Kampf sind der nächste Schritt.*

**Teilstand 29.09.2026 (4) — Schadensregeln per dsa-rules-MCP validiert.**
Die offenen Annahmen aus Teilstand (3) sind gegen *Wege des Schwerts* (WdS),
das *Basisregelwerk* (BRW) und die Hausregeln im dsa-rules-MCP geprüft.
Der Hauptpunkt von ARCH-05 bleibt offen (Bogen-Schreibwege).

*Befunde.*

| Annahme aus (3) | Befund | Quelle |
| --- | --- | --- |
| LeP ohne Untergrenze | bestätigt; LE ≤ 0 lebensbedrohlich, unter −KO tot (Zäher Hund 1,5 × KO) | WdS S. 57 |
| TP(A): RS wird abgezogen | bestätigt | WdS S. 57, 88 |
| TP(A) senkt nur AuP | **falsch:** SP(A) von der AuP, zusätzlich die Hälfte als echte SP von der LeP | WdS S. 57, 88; BRW S. 138 |
| TP(A) schlägt keine Wunden | **falsch:** die echten SP schlagen Wunden, WS dabei üblicherweise +2 | WdS S. 58, 88; BRW S. 139 |
| kein Überlauf AuP → LeP | bestätigt; bei 0 AuP kampfunfähig | WdS S. 57, 84 |
| Wunden über den freien Plätzen verfallen | bestätigt; höchstens 3 je Zone, SP gehen voll von der Gesamt-LE | WdS S. 109 |
| Rundung der Wundschwellen | ganzzahlig, kaufmännisch („halbe KO ist gerundet 7“ bei KO 13) | WdS S. 58; BRW S. 139; WdZ S. 7 |
| Stufen 0,5 / 1 / 1,5 / 2 KO | **teilweise falsch:** nur drei Stufen, höchstens 3 Wunden je Treffer; für 2 KO keine Quelle, auch nicht in den Hausregeln | WdS S. 58 |
| Eisern/Glasknochen ±2 auf alle Stufen | bestätigt, kumulativ mit dem Angriffsmodifikator | WdS S. 58 |
| „Pfeile −2“ | nicht belegt; genannt sind Armbrustbolzen, Gezielter Stich und „bestimmte Waffen“ (−2), waffenlos und Stumpfer Schlag (+2) | WdS S. 58 |
| Zusatzwürfe der Zonen | bestätigt (Kopf 2W6 INI, Brust/Bauch 1W6 SP je Wunde, dritte Kopfwunde 2W6 SP) | WdS S. 109 |
| SB-Unterdrückung | bestätigt (4 je Gesamtwunde; mehrere aus einem Treffer gemeinsam, +8/+12) | WdS S. 83 |

*Korrekturen (Nutzerentscheidungen: TP(A) nach WdS, 2-KO-Stufe überall
entfernen).*

- `echteSchadenspunkte`/`SchadensBuchung.echteSp`: bei TP(A) die Hälfte der
  SP(A), kaufmännisch gerundet. `wendeSchadenAn` senkt bei TP(A) die AuP um
  die SP(A) bis 0 **und** die LeP um die echten SP plus Zusatzschaden; Wunden
  laufen für beide Arten gleich. Die Sperre „Ausdauerschaden verursacht keine
  Wunden“ ist entfallen.
- Dialog: Zone, Modifikator, Wunden und Zusatzwürfe auch bei TP(A); der
  Modifikator wird beim Wechsel mit +2 (TP(A)) bzw. 0 vorbelegt. Die
  Vorschau zeigt AuP und LeP. Hilfetext „Armbrustbolzen −2, waffenlos +2“.
- Protokoll bei TP(A): `TP(A) 8 − RS 1 = 7 SP(A) · 4 SP auf LeP`, `total`
  ist der LeP-Verlust.
- `WundschwellenStufen` hat nur noch drei Stufen; der Vorschlag reicht bis 3,
  der Wunden-Detaildialog zeigt „2 KO“ nicht mehr.
- `computeWundschwelle` ist die erste Stufe (kaufmännisch, samt
  Eisern/Glasknochen); Befund 4 ist damit behoben.

*Prüfungen.* Regeltests (`schaden_rules_test.dart`: Rundung der echten SP,
AuP und LeP bei TP(A), Wunden aus echten SP, höchstens 3 Wunden, Beispiele
KO 13 aus WdS S. 58; `wund_rules_test.dart`: KO 15 → 8, Gleichheit mit der
ersten Stufe), Ablauftests (TP(A) mit und ohne Wunde samt Protokoll) und
Widgettests (TP(A)-Vorschau, Vorbelegung, Wundvorschlag, Rückwechsel).
`bestandshelden_regelwerte_test.dart`: Die Wundschwelle von f01 (7 → 9) und
f04 (9 → 11, drei Fälle) zählt jetzt Eisern mit, f02 und f07 (6 → 7) runden
KO 13 kaufmännisch; die Fixtures und die Hash-Pins sind unverändert.
Gegenproben: Mit `KO ~/ 2` scheitern beide `computeWundschwelle`-Tests,
ohne den LeP-Anteil die drei TP(A)-Regeltests. `flutter analyze --no-pub`
ohne Befund, volle Suite grün (2921 bestanden, 3 übersprungen).

*Randbefunde, bewusst ohne Änderung (Folgeaufträge).*

1. Die Hausregel „Mindestschaden“ ist eine Sammlung von Überlegungen ohne
   Entscheidung; `berechneSchadenspunkte` bleibt bei `max(0, TP − RS)`.
2. Kritische Treffer schlagen automatisch eine Wunde mehr, sobald die WS
   überschritten ist (WdS S. 85). Das deckt die änderbare Wundzahl ab.
   *Korrigiert in Teilstand (6):* Die Hausregel „Erweiterung und
   Überarbeitung des Regelwerks“ (S. 3) hebt das auf: „Kritische Treffer
   richten aber keine zusätzliche Wunde an.“
3. Mit Trefferzonen *ersetzen* die Zonenwunden (WdS S. 109) die pauschalen
   −2 je Wunde (S. 57); `computeWundEffekte` addiert beide. Das ist eigens
   gegen Regelwerk und Hausregeln zu prüfen. *Geprüft im Teilstand (5),
   siehe Folgeauftrag „Zonenwunden nach WdS“ unten; umgesetzt in
   Teilstand (6).*
4. Die Tabelle der Zonenwunden kennt weitere Folgen (Kopf: MU/KL/IN −2;
   Brust/Bauch: KO/KK −1; dritte Wunde: Bewusstlosigkeit und 1 LeP je KR),
   die das Modell nicht abbildet. *Ebenfalls Teil des Folgeauftrags;
   umgesetzt in Teilstand (6).*

**Teilstand 29.09.2026 (5) — Sofortaktionen des Bogens frisch.** Befund 1
des [Schreibpfad-Inventars](schreibpfade_inventar.md) ist für die
Sofortaktionen des Bogens behoben. Der Hauptpunkt bleibt offen, weil der
Inventareditor, das Kampf-Sofortspeichern und die Editorentwürfe weiter
Snapshots schreiben.

*Befund.* Dauermodifikatoren, Wundschwelle, die Sofortaktionen der
Übersicht, Inventar-Löschen und Dukaten, Abenteuerabschluss und
Vertrauten-Steigerung schrieben einen beim Rendern erfassten Bogen ganz
zurück. Was ein anderer Weg (UI2-Blatt, Editor, anderes Gerät) zwischendurch
gespeichert hatte, ging verloren. Zwei schnelle Klicks auf „GS +“ zählten
einmal, Fehler blieben meist unsichtbar. `updateHero` lud zwar frisch, war
aber nicht eingereiht. Eine offene Steigerungsrunde brach jede dieser
Änderungen still („Der Held wurde inzwischen geändert“). Das Löschen im
Inventar schrieb außerdem die Geschossmengen des Snapshots zurück, und der
Abenteuerabschluss prüfte den Doppelabschluss nur an der Anzeige.

*Entscheidungen (mit dem Nutzer abgestimmt: Umfang „Sofortaktionen“,
Planung „gesperrt mit Hinweis“).*

- **Warteschlange für den Bogen, auch für `saveHero`:**
  `aendereGespeichertenHelden` (`lib/ablaeufe/held_schreiben.dart`) lädt
  frisch und speichert über die injizierte Normalisierung. `updateHero`
  delegiert daran; `saveHero` reiht sich über `reiheBogenvorgangEin` in
  dieselbe Warteschlange ein. So überholt ein Editorentwurf keine laufende
  frische Änderung, und die Hash-Prüfung der Steigerungsrunde sieht jede
  eingereihte Änderung. Beide liefern den normalisierten, gespeicherten
  Helden. Den `Expando`-Baustein teilen sich Zustand und Bogen
  (`ReihenfolgeJeHeld`) mit getrennten Warteschlangen. Gibt eine Änderung
  dasselbe Objekt zurück, wird nichts gespeichert.
- **Ein UI-Einstieg:** `aendereHeldMitMeldung` neben
  `aendereZustandMitMeldung`, mit demselben Fehlerweg; fachliche Gründe
  erscheinen ohne „Bad state:“.
- **Planung:** Bei offener Steigerungsrunde schreibt der Einstieg nichts und
  meldet den Grund. Inspector-Statuswerte und das Wundschwellen-Zahnrad sind
  zusätzlich sichtbar gesperrt (Hinweiszeile bzw. Tooltip); BE bleibt, sie
  liegt nur im Arbeitsspeicher. Die übrigen Wege liegen in der Verwaltung,
  die während einer Planung ohnehin gesperrt ist.
- **Schritt statt Wert:** Dauermodifikatoren (über `RessourcenAenderung`),
  AP addieren und die Münzknöpfe zählen vom gespeicherten Wert. Eingetippte
  Beträge und Dialogergebnisse (Modifikatorlisten, Epik) bleiben absolut,
  ersetzen aber nur ihren Schlüssel. Der Ressourcendialog schreibt nur
  umgestellte Schalter.
- **Regel statt Widget:** `modifikator_aenderung_rules.dart`,
  `epic_status_rules.dart`, `inventar_aenderung_rules.dart`,
  `begleiter_aenderung_rules.dart`, dazu `mitApSchritt`,
  `mitRessourcenSchaltern`, `quittiereEigenschaftsHinweis`,
  `schliesseAbenteuerAb`/`oeffneAbenteuerWieder` und `steigereBegleiter`.
- **Keine Doppelbuchung:** Epik wird nie zweimal aktiviert, ein gespeichert
  schon abgeschlossenes Abenteuer nicht erneut gebucht, eine
  Vertrauten-Steigerung auf einen inzwischen geänderten Ausgangsstand
  abgewiesen. Inventar-Löschen findet den Eintrag über seinen Inhalt; ist er
  geändert oder fort, erscheint ein Fehler statt eines falschen Treffers.
- **Nebenbei behoben:** Der AP-Betragsdialog entsorgte seinen Controller vor
  dem Ende der Schließanimation und warf. Der nie aufgerufene Weg
  `onSaveImmediate` im Begleiter-Tab ist entfernt.

Commits:

- `598d490` — Ablauf `aendereGespeichertenHelden`, `ReihenfolgeJeHeld`,
  `saveHero`/`updateHero` eingereiht mit Rückgabewert, Ablauftests.
- `ba40066` — Regeln samt Tests.
- `3d26d97` — `aendereHeldMitMeldung`, Inspector-Statuswerte und
  Wundschwelle, Planungssperre.
- `758c9d6` — Übersicht-Sofortaktionen, AP-Dialog.
- `1297737` — Inventar, Abenteuerabschluss, Vertrauten-Steigerung.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Ablauftests (`test/ablaeufe/held_schreiben_test.dart`): frisches Laden,
  Rückgabe der Normalisierung, fehlender Held, „nichts zu speichern“, zwei
  nicht abgewartete Änderungen, ein eingereihter Vorgang wartet, Fehler hält
  nicht auf, verschiedene Helden sowie Bogen und Zustand warten nicht
  aufeinander. `hero_actions_update_hero_test.dart`: normalisierter
  Rückgabewert, zwei schnelle Schritte, `saveHero` überholt keine laufende
  Änderung, Hash-Prüfung sieht eine eingereihte Änderung.
- Regeltests: `bogen_sofortaenderung_rules_test.dart`,
  `begleiter_aenderung_rules_test.dart`, `abenteuer_abschluss_rules_test.dart`.
- Widgettests gegen eine Zwischenänderung (`BogenTestRepository`, die
  Oberfläche liest über den Index, nur frisches Laden sieht sie):
  `test/ui/shared/held_frisch_schreiben_test.dart` (Statuswerte: Schritt,
  drei schnelle Klicks, Zurücksetzen, Fehler im Zustandsblock, Sperre;
  Wundschwelle: Schlüssel, Fehler im Dialog, Sperre; zentraler Einstieg bei
  Planung), `test/ui/overview/uebersicht_frisch_schreiben_test.dart` (AP,
  Ressourcenschalter samt Fehler im Blatt, beide Modifikatordialoge, Epik
  samt Doppelaktivierung, Hinweisquittung),
  `test/ui/inventory/inventar_frisch_schreiben_test.dart` (Löschen nach
  Verschiebung, geänderter Eintrag, schnelle Münzschritte, Tippen,
  Tippen plus Münzschritt, Fehler) und
  `test/ui/shared/verwaltung_frisch_schreiben_test.dart` (Abenteuer auf dem
  gespeicherten Stand, kein Doppelabschluss, Vertrauten-Steigerung,
  abgewiesener Ausgangsstand).
- Gegenproben: Ohne Warteschlange scheitern sechs Ablauf- und
  `HeroActions`-Proben. Mit dem alten Oberflächencode scheitern 8 von 9
  Spielansichtsproben, alle 9 Übersichtsproben und 9 von 10 Inventar-,
  Abenteuer- und Begleiterproben; die jeweils bestehende prüft Verhalten,
  das schon vorher stimmte.
- `flutter analyze --no-pub` ohne Befund, Zeilenbudget eingehalten, volle
  Suite grün (2993 bestanden, 3 übersprungen). Die Hash-Pins der
  Bestandshelden sind unverändert. Eine manuelle Bedienprüfung auf Geräten
  steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Inventareditor und Kampf-Sofortspeichern (Waffenwahl, Geschosse ±,
   Slots) schreiben weiter Snapshots, ebenso alle Editorentwürfe. Sie sind
   jetzt eingereiht, überholen also keine frische Änderung, aber der zuletzt
   ausgelöste Schreibvorgang gewinnt. Nächster Schritt: Inventareditor
   (Einträge ohne ID, ARCH-03) und Kampf. *Kampf erledigt im Teilstand (7);
   der Inventareditor bleibt.*
2. Der Bogen wartet weiter auf seinen Upload; mit Konto laufen schnelle
   Klicks auf „GS +“ je Netzweg nach, gehen aber nicht verloren. Eine
   Bündelung wie beim Zustand (`GebuendelteLaeufe`) wäre ein eigener
   Sync-Auftrag.
3. Die Warteschlange hält auch während der Normalisierung, die bis zu 20 s
   auf den Katalog warten kann, wenn er fehlt und Parser-Restfragmente da
   sind.
4. Keine Transaktion gegen Schreibwege an der Warteschlange vorbei:
   `setShowInapplicableSpecialAbilities` (direkt über das Repository), der
   Startimport und Sync-Übernahmen (ARCH-06).
5. Eine Änderung, die selbst `saveHero` oder `updateHero` aufruft, wartete
   auf sich selbst. Kein Weg tut das; es steht in CLAUDE.md.
6. Das Abschließen eines Abenteuers verwirft wie bisher einen offenen
   Notizentwurf (`_syncDraftFromHero(force: true)`); der Knopf steht nur
   außerhalb des Bearbeitens.

**Folgeauftrag „Zonenwunden nach WdS“ (per dsa-rules-MCP geprüft,
29.09.2026).** Randbefund 3 aus Teilstand (4) ist bestätigt. Die Hausregeln
kennen kein eigenes Wundsystem; „Schmerzlos“ (Erweiterung und Überarbeitung
des Regelwerks, S. 8: „alle ersten bzw. auch alle zweiten Wunden in einer
Zone ignorieren“) setzt Zonenwunden voraus.

| Befund | Quelle |
| --- | --- |
| Nicht lokalisierte Wunde: AT, PA, FK, INI-Basis und GE je −2, GS −1 | WdS S. 58; BRW S. 194 |
| „Die folgenden Regelungen **ersetzen** die Angaben zu nicht-lokalisierten Wunden“ | WdS S. 109 |
| Wundbedingte Eigenschaftsverluste wirken nicht auf AT-, PA-, FK- und INI-Basiswerte; GS nie unter 1 | WdS S. 111 |
| Kopf: MU, KL, IN, INI-Basis −2, INI −2W6; dritte: +2W6 SP, bewusstlos | WdS S. 108 f. |
| Brust (auch Rücken): AT, PA, KO, KK −1, +1W6 SP; dritte: bewusstlos | WdS S. 108 f. |
| Arm: AT, PA, KK, FF −2 **mit diesem Arm**; dritte: Arm handlungsunfähig | WdS S. 108 f. |
| Bauch: AT, PA, KO, KK, GS, INI-Basis −1, +1W6 SP; dritte: bewusstlos | WdS S. 108 f. |
| Bein: AT, PA, GE, INI-Basis −2, GS −1; dritte: Sturz, kein Nahkampf | WdS S. 108 f. |
| Pauschal −3 auf Talent- und Zauberproben je Wunde | keine Quelle (Regelwerk und Hausregeln) |

`computeWundEffekte` addiert heute die pauschalen −2 **und** eigene
Zonenwerte, die zu keiner Zone der Tabelle passen (etwa Arm: AT/PA −4 und
FK −6 insgesamt, Kopf AT/PA/FK −1 und Zauber −3). Offene Entscheidungen vor
der Umsetzung: Gilt immer das Zonensystem (das Modell kennt keine
unlokalisierten Wunden)? Wie werden FK (in der Tabelle nicht genannt) und
der Armbezug („mit diesem Arm“, Schwert- oder Schildarm) behandelt? Werden
Eigenschaftsverluste (MU, KL, IN, KO, KK, GE, FF) als Modifikatoren
modelliert, ohne auf die Basiswerte zu wirken? Entfällt die pauschale
Probenerschwernis, und was bedeutet dann die epische KO-Halbierung? Die
Regelwerte der Bestandshelden mit Wunden (f01, f04) ändern sich dabei.
*Per dsa-rules-MCP geklärt und umgesetzt in Teilstand (6).* Die Annahme
oben, die Hausregeln kennten kein eigenes Wundsystem, war falsch: Sie
verlangen die kombinierte Wirkung beider Systeme.

**Teilstand 30.09.2026 (6) — Zonenwunden nach WdS.** Der Folgeauftrag ist
umgesetzt. Der Hauptpunkt von ARCH-05 bleibt offen (Inventareditor, Kampf,
Editorentwürfe).

*Nachprüfung per dsa-rules-MCP.* Die offenen Fragen des Folgeauftrags sind
gegen Regelwerk und Hausregeln geprüft:

| Frage | Befund | Quelle |
| --- | --- | --- |
| Zonensystem statt Gesamtsystem? | **beides:** „Wunden haben die kombinierte Wirkung einer Wunde nach Zonensystem und nach Gesamtsystem“ | Hausregel „Erweiterung und Überarbeitung des Regelwerks“ S. 3 |
| Gesamtsystem je Wunde | AT, PA, FK, INI-Basis, GE −2; GS −1; die GE-Änderung wirkt auf keinen Basiswert | WdS S. 58; BRW S. 194 |
| Zonentabelle | wie im Folgeauftrag; Brust gilt auch für den Rücken | WdS S. 108 f. |
| FK bei Armwunden | in der Zonentabelle nicht genannt; FK sinkt nur allgemein | WdS S. 108 f. |
| Armbezug | „wenn er diesen Arm benutzt“; Schwert- und Schildarm werden unterschieden | WdS S. 108 f. |
| Eigenschaftsverluste | wirken nicht auf AT-, PA-, FK- und INI-Basis; GS durch Wunden nie unter 1 | WdS S. 111 |
| Pauschal −3 auf Proben je Wunde | keine Quelle | Regelwerk und Hausregeln |
| Epische KO | „Die Erschwernis und die resultierende Erschöpfung durch das Unterdrücken von Wunden sind halbiert“ | Epische Stufen S. 4 |
| Unterdrücken | SB +4 je Gesamtwunde, +8/+12 für mehrere aus einem Treffer; nach dem Kampf 1W6 Erschöpfung | WdS S. 83 |
| Kopf-INI 2W6 | Verlust des **aktuellen** Initiativewerts | WdS S. 109 |

*Entscheidungen (mit dem Nutzer abgestimmt).*

- **Kombiniert und additiv:** allgemeine Abzüge plus Zonenabzüge,
  gerechnet in `wund_zonen_rules.dart` als Daten
  (`kWundAllgemein`, `wundZonenWirkung`).
- **Keine pauschale Proben-Erschwernis mehr.** Wunden senken die
  Eigenschaften nur für Proben (`HeroComputedSnapshot.probenEigenschaften`,
  `wendeWundVerlusteAn`). Abgeleitete Werte (AT/PA/FK/INI-Basis, LeP,
  AuP, AsP, MR, Wundschwelle, TP/KK) rechnen mit den effektiven Werten.
- **Armwunden armgebunden:** rechter Arm = Schwertarm (AT/PA der
  Hauptwaffe im Nahkampf), linker Arm = Schildarm (Nebenhandwaffe,
  Schild-PA). Mit dem Vorteil Linkshänder umgekehrt, über den neuen
  Katalogschalter `linkshaender` (ARCH-02-Muster wie Flink). KK/FF −2
  wirken auf Proben mit Hinweis „nur mit diesem Arm“. Kein FK-Armanteil.
- **Kopf-2W6 nur als Hinweis:** `kopfIniMalus` bleibt gespeichert
  (Format unverändert), senkt aber nicht mehr die INI-Basis.
- **Epische KO** halbiert die SB-Erschwernis beim Unterdrücken, die
  Erschöpfung erscheint halbiert als Hinweis. Die frühere Halbierung der
  Probenabzüge entfällt; ihr Text in `epic_main_attribute_rules.dart` ist
  korrigiert.
- **Dritte Wunde:** nur Kopf, Brust, Rücken und Bauch machen kampfunfähig;
  Arm aktionsunfähig, Bein Sturz und kein Nahkampf, jeweils als Hinweis.
- **Annahmen:** Eine Parierwaffe hat keinen eigenen PA-Wert; die Haupt-PA
  trägt nur den Schwertarm. Beidhändige Helden gelten wie Rechtshänder.
  Die SB-Probe zählt die neuen Wunden bereits mit. Rast-Proben bleiben ohne
  Wundverluste, weil die Rast Wunden im selben Schritt heilt.

Commits:

- `c517f0e` — Linkshänder als Katalogschalter (`adv_linkshaender`,
  `hasLinkshaenderFromVorteile`, Äquivalenztest).
- `7477b8f` — Regeln: `wund_zonen_rules.dart`, `WundEffekte` neu,
  Probenwerte, Armmalus in der Kampfvorschau, GS-Grenze, epische KO,
  Trefferzonen mit Linkshänder, alle Probenaufrufer; Bestandshelden-Werte.
- `786317b` — Oberfläche: Zusammenfassung über
  `wund_anzeige_rules.dart`, Armrollen, Wundmarkierung an Eigenschaftswerten,
  Schritt „Wunden Schwertarm“ in der Waffenrechnung, W20 im Schadensdialog.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests: `wund_zonen_rules_test.dart` (je Zone, Linkshänder, dritte
  Wunde, Unterdrückung und Erschöpfung, SB-Halbierung, Probenwerte,
  GS-Grenze, Anzeige), `wund_arm_kampf_test.dart` (Schwert-/Schildarm,
  Linkshänder, Nebenhand, Fernkampf, Parierwaffe, Ersatzpfad gleich
  Snapshot, keine Wirkung auf abgeleitete Werte, GS ≥ 1),
  `epic_main_attribute_rules_test.dart`, `trefferzonen_rules_test.dart`,
  Äquivalenz- und Parsertests für Linkshänder.
- Bestandshelden (`bestandshelden_regelwerte_test.dart`), von Hand
  hergeleitet: f01 (Armwunde links + Holzschild) AT-/PA-Basis 4 → 6,
  FK-Basis 1 → 5, Kampf-AT/PA 9/8 → 11/10, Ausweichen 0 → 2, Schild-PA 7
  unverändert; neu „f01 mit Linkshänder“ (Kampf-AT/PA 9/8, Schild-PA 9);
  f04 mit Brustwunde FK-Basis 6 → 7, SB-Erschwernis episch 2, sonst 4.
  Neu projiziert: `wundEigenschaften`, `sbErschwernis`, `kampf.schildPa`.
  Fixtures und Hash-Pins sind unverändert.
- Widgettests: `test/ui/workspace/wunden_dialog_test.dart`
  (Zusammenfassung, Armrollen, Linkshänder, SB-Probe gegen Probenwerte ohne
  Startabzug, epische Halbierung, Schnellsuche), Linkshänder-W20 und
  epische Unterdrückung in `schaden_dialog_test.dart`, Wundmarkierung der
  Eigenschaftskarte in `karto_spiel_bruecke_test.dart`.
- Gegenproben: Armanteil pauschal in `atMalus` → 9 Proben scheitern;
  Linkshänder ignoriert → 2; Verluste in `effectiveAttributes` → 12;
  2W6 in der INI-Basis → Kopfprobe; ohne GS-Grenze → 2; ohne Halbierung →
  SB-Regel, f04 und die epische Unterdrückung im Dialog; Textweg ohne Token
  → Äquivalenztest `adv_linkshaender`; SB-Probe bzw. Schnellsuche mit
  effektiven Werten, W20 ohne Linkshänder, Karte ohne Grundwerte → je der
  zugehörige Widgettest.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten, volle Suite grün (3009 bestanden,
  3 übersprungen). Ein Zwischenlauf scheiterte einmal an
  `rules_index_search_io_test.dart`, weil der laufende dsa-rules-MCP-Server
  `index_remote.sqlite` offen hielt; unabhängig von dieser Änderung, der
  nächste Lauf war grün. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und Folgeaufträge.*

1. ~~Die Vorschau des Kampf-Tabs (`hero_combat_tab.dart`,
   `combat_weapons_section.dart`, `combat_weapons_overview_table.dart`)
   rechnet ohne `derivedStats` und damit ohne jede Wunde (Rest von B7).
   `computeCombatPreviewStats` nimmt jetzt `wunden`; die Aufrufer reichen
   sie noch nicht durch. Eigener Folgeauftrag.~~ *Erledigt im Teilstand (7).*
2. Paraden mit einer Parierwaffe werden nicht gesondert gerechnet; ein
   Schildarm-Abzug trifft sie nicht.
3. KK/FF −2 einer Armwunde gelten für alle Proben; ob der Arm beteiligt
   ist, entscheidet der Tisch (Hinweis im Wundendialog).
4. Talent- und Magie-Tab bauen ihre Probenwerte aus eigenen effektiven
   Eigenschaften, die Inventar-, benannte und temporäre Modifikatoren nicht
   kennen (vorbestehend); die Wundverluste kommen jetzt hinzu.
5. Hausregel „mehr als KO×2 TP(A) → 3 Wunden in der Zone“ (S. 3) und der
   Vorteil Schmerzlos (S. 8) sind nicht modelliert; der Wundvorschlag bleibt
   änderbar. Die Obergrenze „Wunden ≤ KO/2, darüber handlungsunfähig“ (BRW
   S. 194) steht nicht im Modell.
6. Der Kopf-INI-Wurf gilt nur im laufenden Kampf; wer die Kampf-INI der
   App nutzt, zieht ihn selbst ab (Hinweis im Wundendialog).

*Nachtrag 30.09.2026 — SB-Erschwernis beim Unterdrücken.* Eine Rückmeldung
hielt es für falsch, dass beim Unterdrücken alle Wunden zählen und nicht nur
die des aktuellen Angriffs. Erneut per dsa-rules-MCP geprüft (keine Errata,
keine Hausregel dazu): WdS S. 83 erschwert die Probe „pro insgesamt
erlittener Wunde um 4 Punkte“, mehrere Wunden aus einem Treffer pauschal
um +8/+12; WdS S. 111 zählt ausdrücklich alle bisherigen Wunden („zwei
Wunden in der Brust … dann eine Wunde im Kopf … Selbstbeherrschungs-Probe
+12“); vor Kampfbeginn gilt „die vierfache Anzahl der Wunden“. **Mit dem
Nutzer entschieden: nach WdS.** Unterdrückte Wunden zählen also mit
(Kampfverlauf: eine Wunde +4, die nächste einzelne +8, zwei aus einem
Treffer +8). Die Rechnung war richtig; geändert ist nur die Anzeige
(`4 × 3 Wunden insgesamt = 12`, Hinweis im Wundendialog) samt Regeltest
für den Kampfverlauf.

**Teilstand 30.09.2026 (7) — Kampf-Tab frisch, Kampfvorschau mit Wunden.**
Das Kampf-Sofortspeichern (Risiko 1 aus Teilstand 5) und Folgeauftrag 1 aus
Teilstand (6) sind umgesetzt. Der Hauptpunkt von ARCH-05 bleibt offen
(Inventareditor, Editorentwürfe).

*Befund.* Im Lesemodus schrieb der Kampf-Tab bei jeder Bedienung den beim
Rendern erfassten Helden samt ganzer Kampfkonfiguration zurück
(`_persistCombatConfigIfReadonly`). Betroffen waren Waffen- und
Nebenhandwahl, Entfernung, Geschosswahl und -bestand, Editorergebnisse,
Entfernen, Talent und BF in der Waffentabelle sowie Rüstungs- und
Nebenhandteile. Folgen:

- Was ein anderer Weg zwischendurch speicherte, ging verloren.
- Schnelle Klicks auf „Geschosse ±“ konnten verloren gehen. Nach dem ersten
  Speichern setzte der Rebuild den Entwurf zurück, obwohl der zweite Klick
  noch ausstand.
- Die Bedienung traf Slots über ihre Position.

Außerdem verschob das Entfernen einer Waffe bzw. eines Nebenhandteils die
Nebenhandzuordnung nicht. Die Nebenhand fiel dann weg oder zeigte auf ein
anderes Teil; das war vorbestehend, nicht erst durch Nebenläufigkeit.
Die Vorschau im Kampf-Tab (Kampfwerte, Waffentabelle, Waffeneditor)
rechnete ohne Basiswerte und damit ohne Wunden.

*Entscheidungen.*

- **Muster aus Teilstand (5):** Die Bedienung läuft über einen Einstieg
  `_aendereKampf`. Im Lesemodus schreibt er frisch über
  `aendereHeldMitMeldung`, im Bearbeitungsmodus ändert er wie bisher nur den
  Entwurf. Die Anzeige folgt dem gespeicherten Wert, der Entwurf wird nicht
  vorab gesetzt. Fehler erscheinen als Snackbar „… nicht gespeichert“, und
  die Auswahlfelder springen auf den gespeicherten Stand zurück.
- **Identität statt Position:** Die Regeln in `kampf_aenderung_rules.dart`
  finden Waffen, Geschosse, Rüstungs- und Nebenhandteile über ihre stabile
  ID (ARCH-03 B2/B3). Ohne ID zählt der Inhalt ohne IDs, weil das Speichern
  benannten Slots erst dabei eine vergibt. Die Sektionen melden dafür den
  angezeigten Slot statt nur seiner Position.
- **Editorergebnisse:** Hat sich der gespeicherte Slot seit dem Öffnen des
  Editors geändert (etwa sein Geschossbestand), wird das Ergebnis
  abgewiesen statt überschrieben, wie bei der Vertrauten-Steigerung. Der
  breite Editor bleibt dann offen.
- **Schritt statt Wert:** Geschossbestände zählen vom gespeicherten Bestand
  (0 bis 9999). Getroffen wird das angezeigte Geschoss, nicht das
  inzwischen gewählte.
- **Nebenbei behoben:** Beim Entfernen rücken aktive Waffe und Nebenhand
  nach. Die toten Controller `combat-main-*` werden nicht mehr nachgeführt.
- **Vorschau:** Der Helfer `kampfvorschau` reicht Modifikatoren, effektive
  Eigenschaften, Basiswerte und Wunden aus `heroComputedProvider` durch.
  Kampf-Tab, Inspector und Spielansicht rechnen damit dieselben Werte. Die
  Sektionen bekommen auch die Hausregel für epische Vorteile, die dort
  bisher immer als aktiv galt.

Commits:

- `923f869` — Regeln `kampf_aenderung_rules.dart` mit Tests.
- `5c8d551` — Kampf-Tab schreibt Sofortänderungen frisch, Widgettests.
- `c15d0a2` — Kampfvorschau mit Wunden.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests (`test/rules/kampf_aenderung_rules_test.dart`, 40 Proben):
  - Suche über ID bzw. Inhalt samt Positionshilfe; nachträglich vergebene
    IDs; geänderte oder entfernte Slots werden gemeldet.
  - Gleicher Held bei „nichts geändert“.
  - Geschossschritt vom gespeicherten Bestand mit Grenzen, getroffen wird
    das angezeigte Geschoss.
  - Ersetzen wird bei geändertem Ausgang abgewiesen.
  - Entfernen verschiebt aktive Waffe und Nebenhand (Waffe und Teil); die
    letzte Waffe bleibt.
  - Unbekannte Felder bleiben erhalten.
- Widgettests (`test/ui/combat/kampf_frisch_schreiben_test.dart`) mit
  `BogenTestRepository`:
  - Waffenwahl nach einer Einfügung davor, die fremde Änderung bleibt.
  - Drei schnelle „Geschosse +“ ab einem fremd gesetzten Bestand.
  - Nebenhandwahl.
  - Speicherfehler samt Zurückspringen der Auswahl.
  - Bearbeitungsmodus schreibt erst mit Speichern.
  - Entfernen mit Nebenhand.
  - BF in der Tabelle.
  - Editorergebnis auf eine geänderte Waffe.
  - Rüstungs- und Nebenhandteil entfernen.
- `test/ui/combat/kampfvorschau_wunden_test.dart`: Kampfwerte (AT, PA,
  Kampf-INI) und Waffentabelle (INI) gleichen mit Bauchwunde dem Snapshot,
  der ohne Wunde höher liegt.
- Gegenproben:
  - Mit dem alten Oberflächencode scheitern 9 von 10 Widgettests; es besteht
    nur der Bearbeitungsmodus, dessen Verhalten gleich bleibt.
  - Ohne Nachrücken der Verweise scheitern drei Regelproben.
  - Ohne Zurücksetzen der Auswahlfelder scheitert der Fehlertest.
  - Mit der alten Vorschau scheitern beide Vorschau-Widgettests.
- Die bestehenden Kampf-Tab- und Rebuild-Tests laufen unverändert.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten. Volle Suite grün (3063 bestanden, 3 übersprungen). Die Hash-Pins der
  Bestandshelden sind unverändert. Eine manuelle Bedienprüfung auf Geräten
  steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. ~~Inventareditor (`_saveEntries`) und alle Editorentwürfe schreiben weiter
   Snapshots, eingereiht. Der Inventareditor ist der nächste Schritt; seine
   Einträge haben keine ID (ARCH-03).~~ *Inventareditor erledigt im
   Teilstand (8); die Editorentwürfe bleiben.*
2. Der Bogen wartet weiter auf seinen Upload. Mit Konto laufen schnelle
   Geschossklicks je Netzweg nach, gehen aber nicht verloren (wie „GS +“).
3. Entfernungsstufen haben keine ID und werden über die Position gewählt.
   Es sind immer genau fünf.
4. Ein Geschoss ohne ID (unbenannt) wird über seinen Inhalt samt Bestand
   gefunden. Ändert ein anderer Weg den Bestand zwischendurch, meldet der
   nächste Klick „inzwischen geändert“, statt falsch zu zählen.
5. Die Slotprüfung (`_validateWeaponSlotsForConfig`) liegt weiter im Widget
   und läuft bei jeder Sofortänderung auf der ganzen Konfiguration. Eine
   bereits gespeicherte ungültige Konfiguration sperrt deshalb alle
   Sofortänderungen, wie bisher.

**Teilstand 05.10.2026 (8) — Inventareditor frisch.** Risiko 1 aus
Teilstand (7) ist für den Inventareditor umgesetzt. Der Hauptpunkt von
ARCH-05 bleibt offen (Editorentwürfe).

*Befund.* `_saveEntries` schrieb beim Anlegen und Bearbeiten den beim Rendern
erfassten Helden per `saveHero` zurück. Dazu leitete es die ganze
Kampfkonfiguration neu ab. Folgen:

- Was ein anderer Weg zwischendurch speicherte, ging verloren. Besonders
  betroffen waren Geschossbestände aus dem Kampf-Tab:
  `_applyInventoryChangesToCombat` schrieb **alle** Geschossmengen des alten
  Inventars zurück.
- Bearbeiten traf den Eintrag über seine Position. Der breite Editor blieb
  an seiner Position stehen, auch wenn sich die Liste darunter verschob. Sein
  Entwurf landete dann auf einem anderen Gegenstand.
- Ein Editorergebnis auf einen inzwischen geänderten Gegenstand überschrieb
  diesen, statt abgewiesen zu werden.

*Entscheidungen.*

- **Muster aus Teilstand (7):** Ein Eintrag wird über seinen Inhalt
  gefunden, weil Inventareinträge keine ID haben (ARCH-03). Ein
  Editorergebnis auf einen geänderten oder entfernten Gegenstand wird
  abgewiesen (`mitGeaendertemInventarEintrag`). Der Tab merkt sich den
  geöffneten Gegenstand (`_bearbeiteterEintrag`), nicht nur seine Position.
- **Fehler im Editor:** Der neue Einstieg `aendereHeldImEditor`
  (`zustand_aendern.dart`) prüft die Planung wie `aendereHeldMitMeldung`,
  reicht Fehler aber an den Aufrufer weiter. `InventoryItemEditor` zeigt sie
  wie bisher selbst, ohne „Bad state:“, und bleibt offen.
  `aendereHeldMitMeldung` nutzt denselben Einstieg.
- **Kampfabgleich als Regel:** Ein verknüpfter Eintrag gibt seine
  Markierungen an den Slot weiter. Eine im Editor geänderte Geschossmenge
  geht nur an das eigene Geschoss (`slotRef ?? sourceRef`). Ein manueller
  Eintrag lässt den Kampf unberührt. Der Abgleich liegt damit nicht mehr im
  Widget (Befund 6 des Schreibpfad-Inventars, teilweise).
- **Auswahl nach dem Speichern:** über den Inhalt im gespeicherten Helden,
  neue Einträge von hinten (gleiche Gegenstände), verknüpfte notfalls über
  `slotRef`.

Commits:

- `0d692cb` — Regeln `mitNeuemInventarEintrag` und
  `mitGeaendertemInventarEintrag` mit Tests.
- `55bdcc6` — Inventareditor schreibt frisch, Widgettests.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests (`test/rules/inventar_aenderung_rules_test.dart`):
  - Anhängen lässt den Kampf stehen; ein neuer Eintrag ist bei Gleichheit der
    hintere.
  - Ersetzen trifft den Eintrag nach einer Verschiebung; ein geänderter oder
    entfernter Eintrag wird abgewiesen; „nichts geändert“ liefert denselben
    Helden.
  - Ein manueller Eintrag lässt den Kampf unverändert.
  - Die Geschossmenge erreicht nur den eigenen von zwei gleichnamigen Bögen,
    eine abweichende fremde Menge bleibt, eine unveränderte Menge schreibt
    nicht.
  - Markierungen gehen an den Slot; unbekannte Felder bleiben.
- Widgettests (`test/ui/inventory/inventar_frisch_schreiben_test.dart`) mit
  `BogenTestRepository`, schmal und breit:
  - Ein neuer Gegenstand nach einer fremden Kampfänderung lässt diese stehen.
  - Bearbeiten nach einer Einfügung davor trifft den geöffneten Gegenstand.
  - Ein fremd geänderter Gegenstand wird abgewiesen; die Meldung steht im
    breiten Editor, der Entwurf bleibt.
  - Der breite Editor bleibt beim geöffneten Gegenstand, wenn sich die Liste
    sichtbar verschiebt.
  - Eine Geschossmenge erreicht nur ihren eigenen Bogen, fremde Bestände
    bleiben.
  - Ein Speicherfehler bleibt im Editor.
- `test/ui/shared/held_frisch_schreiben_test.dart`: `aendereHeldImEditor`
  reicht die Planungssperre an den Aufrufer weiter und schreibt nichts.
- Gegenprobe: Mit dem alten Oberflächenstand des Inventars scheitern alle
  sechs neuen Editortests; die bestehenden Lösch- und Dukatentests bestehen.
- Die bestehenden Inventar-, Abgleichs- und Frisch-Schreib-Tests laufen
  unverändert.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten. Volle Suite grün (3400 bestanden,
  3 übersprungen). Die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Die Editorentwürfe (Übersicht, Talente, Magie, Begleiter, Notizen,
   Reisebericht, Kampf-Editor) schreiben weiter Snapshots, eingereiht. Sie
   sind der nächste Schritt von ARCH-05.
2. Zwei inhaltlich gleiche Einträge sind nicht unterscheidbar. Bearbeitet
   wird dann der erste; das Ergebnis ist dasselbe wie beim Löschen.
3. Ein verknüpfter Eintrag, dessen Slot ein anderer Weg zwischendurch
   geändert hat (etwa Geschossbestand), wird abgewiesen. Der Nutzer muss den
   Editor schließen und neu öffnen.
4. Eine nicht als Zahl lesbare Geschossmenge setzt den Bestand wie bisher auf
   0.

## ARCH-06 — Zusammengehörige Änderungen gemeinsam speichern und synchronisieren

**Ist-Zustand:** Heldenblatt und Spielzustand werden getrennt gespeichert und
synchronisiert. Steigerungsrunden bündeln bereits Werte, AP/SE und Historie im
Heldenblatt. Die Sync-Logik bindet zugehörige Zustandskonflikte an Heldenkonflikte;
diese Schutzmechanismen müssen erhalten bleiben.

**Ziel:** Fachlich zusammengehörige Änderungen als Einheit behandeln, auch bei
Abbruch oder Neustart. Ein Änderungsprotokoll und eine dauerhafte Warteschlange
machen lokale Änderungen, ausstehenden Sync und Korrekturen nachvollziehbar.
Der Betrieb ohne Konto oder Netzwerk bleibt möglich.

**Einstieg:** `lib/data/hero_repository.dart`, `lib/data/hive_hero_repository.dart`,
`lib/data/syncing_hero_repository.dart`, `lib/data/sync/`,
`lib/domain/sync_models.dart`, `lib/domain/hero_advancement_entry.dart` und
`lib/ui/screens/sync_conflict_gate.dart`.

- [ ] Für die Abläufe aus ARCH-05 festlegen, welche Daten gemeinsam verbindlich
  werden müssen, und einen geeigneten Speichervertrag mit Wiederanlauf definieren.
- [ ] Lokale Änderung und ausstehenden Sync dauerhaft zusammen erfassen;
  wiederholte Übertragung darf eine Aktion nicht erneut anwenden.
- [ ] Änderungsprotokoll und fachlich gültige Korrekturaktionen ergänzen.
  Unabhängige Änderungen nur nach definierten Konfliktregeln zusammenführen;
  widersprüchliche Änderungen bleiben sichtbar entscheidbar.

**Abnahme:** Ein Abbruch hinterlässt keine halbe fachliche Buchung. Ein Neustart
verliert keinen ausstehenden Abgleich. Wiederholungen buchen keine AP und keinen
Schaden doppelt. Heldenblatt und zugehöriger Zustand werden bei Konflikten nicht
unbemerkt aus widersprüchlichen Versionen kombiniert. Korrekturen bleiben im
Verlauf erkennbar; bereits übernommene Steigerungshistorie wird nicht gelöscht.

**Prüfung:** Fehler- und Wiederanlauftests in `test/data/`, insbesondere
`syncing_hero_repository_test.dart`, Gateway-/Transporttests sowie
`test/ui/screens/sync_conflict_gate_test.dart`. Zwei simulierte Geräte mit
gemeinsamer Ausgangsversion und unabhängigen bzw. konkurrierenden Änderungen prüfen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-05 definiert die Einheiten;
ARCH-02/03/04 beeinflussen gespeicherte Referenzen. Speichertechnik, Remote-Protokoll,
Granularität der Zusammenführung und zulässige Korrekturen gesondert entscheiden.
Ein Datenbankwechsel ist mit dieser Liste nicht beschlossen. Die vorhandenen
nativen und REST-Sync-Pfade berücksichtigen.

## ARCH-07 — Nutzerabläufe und Datenmigrationen absichern

**Ist-Zustand:** Regel-, Domain-, Daten-, Provider- und Widgettests sind bereits
getrennt vorhanden. Die CI prüft unter anderem Analyse, Tests und einen
Web-Release-Build. Für den Umbau braucht es zusätzlich gezielte Nachweise über
vollständige Abläufe, alte Datenformate und unterbrochene Synchronisierung.

**Ziel:** Repräsentative Bestandshelden und kritische Nutzerabläufe sichern die
schrittweise Weiterentwicklung ab. Die Trennung der Testverantwortlichkeiten aus
der [Teststrategie](test_strategy.md) bleibt erhalten.

**Einstieg:** `test/domain/hero_sheet_model_test.dart`,
`test/data/hero_actions_import_export_test.dart`,
`test/data/syncing_hero_repository_test.dart`, `test/state/advancement_session_test.dart`,
`test/ui/smoke/widget_test.dart` und `.github/workflows/flutter-tests.yml`.

- [x] Kleine, anonymisierte bzw. synthetische Bestandsfixtures mit erwarteten
  Ergebnissen anlegen: normale, magische/karmale und epische Helden, eigene
  Textmerkmale, gleichnamige Ausrüstung und ältere Schema-Versionen.
- [x] Den Ablauf „importieren → steigern → ausrüsten → Spielaktion → schließen
  → wieder öffnen → exportieren“ auf Erhalt der gespeicherten Daten absichern.
  Tests für jede neue Migration direkt im jeweiligen Modellumbau ergänzen.
- [x] Unterbrochenen Sync, Wiederholung und Konflikte zweier Geräte reproduzierbar
  testen; automatisierte Prüfungen und nötige manuelle Plattformprüfungen in der
  Teststrategie sowie der CI nachvollziehbar verorten.

**Abnahme:** Jede eingeführte Migration hat einen Bestandsfall und einen Test
für erneutes Laden ohne weitere Veränderung. Kritische Abläufe prüfen reale
Speicher-/Ladegrenzen. Erwartungen für Regelwerte stehen in Regeltests, während
UI-/Ablauftests Navigation, Persistenz und Fehlerbehandlung prüfen. Abgedeckte
Plattformen und verbleibende manuelle Prüfungen sind ausdrücklich dokumentiert.

**Abhängigkeiten / offene Entscheidungen:** Vor ARCH-02/03 mit Fixtures beginnen
und alle Aufgaben begleiten. Umfang echter Integrationstests, Geräteauswahl und
CI-Ausführung anhand der betroffenen Plattformpfade konkretisieren.

**Umsetzungsstand 27.09.2026 — Grundausstattung fertig.** Die drei
Unterpunkte sind erledigt; der Hauptpunkt bleibt offen, weil ARCH-07 jede
weitere Aufgabe begleitet (neue Migration → neue Fixture). Branch
`task/2026-09-27-arch07-bestandsfixtures`, Commits `2c82021` (Sync-Fakes
ausgelagert), `1878edd` (`buildHeroComputedSnapshot` als reine Funktion,
verhaltensneutral), `a4f13ff` (Fixtures, Domain), `16a9e53` (Regelwerte,
Ausrüstung), `bb73400` (echter Hive-Ablauf) und der Abschluss-Commit mit dem
Zwei-Geräte-Sync und dieser Dokumentation.

- **Fixtures:** neun Bestandshelden unter `test/fixtures/heroes/` (normal,
  magisch, karmal, episch, Freitext-Merkmale, gleichnamige Ausrüstung,
  handgeschriebener Altstand ohne Schemaversion, Schemaversion 27 mit
  Historie und eine Variante mit unbekannter Steigerungsart). Die Regeln zu
  Unveränderlichkeit, Formatwächter-Hashes und Aktualisierung der Regelwerte
  stehen in der [Teststrategie](test_strategy.md#bestandsfixtures-arch-07).
- **Ablauf:** `test/data/bestandsheld_ablauf_test.dart` mit echtem Hive über
  Neustart und Export hinweg, dazu Import → Neustart → Export für jede Fixture.
- **Zwei Geräte:** `test/data/sync_zwei_geraete_test.dart` mit gemeinsamer
  Cloud, Netzabbruch mitten im Abgleich, verlorener Antwort, Neustart (auch mit
  echtem Hive) und allen drei Konfliktauflösungen einschließlich gebundenem
  Zustand. Das Test-Fake hasht dafür jetzt wie die echten Gateways
  (`heroContentHash`) und prüft auch bei Zuständen die Vorrevision.
- **Prüfungen:** `flutter analyze` ohne Befund, vollständige Suite grün.
  Plattformabdeckung und verbleibende manuelle Prüfungen stehen in der
  Teststrategie; die CI braucht keine Änderung.

**Befunde.** Das Paket ist verhaltensneutral: Die Tests halten das heutige
Verhalten mit dem Kommentar `Befund ARCH-07-Bx` fest, behoben wird in eigenen
Aufträgen.

| ID | Risiko | Befund | Nachweis | Folgeauftrag |
|---|---|---|---|---|
| B1 | hoch | Der Inspector schreibt Dauermodifikatoren nach `persistentMods`. Ist `statModifiers` leer, spiegelt `HeroSheet.fromJson` sie dorthin; `derived_stats.dart` zählt beides, die Kampfvorschau nur `persistentMods`. Nach jedem Laden stehen die Werte doppelt (f07: LeP 36 statt 34), im Sync folgt ein zusätzlicher Upload. | Domain-, Regel- und Sync-Test (f05, f07) | Sofortfix empfohlen, vor ARCH-02 |
| B2 | mittel | Entfernt man die erste von zwei gleichnamigen Waffen, erbt die zweite deren Inventardaten (Wert, Beschreibung, Gewicht). | `bestandshelden_ausruestung_test.dart` | ARCH-03 |
| B3 | mittel | Umbenennen einer Waffe verliert ihre Inventardaten. | `bestandshelden_ausruestung_test.dart` | ARCH-03 |
| B4 | niedrig | Ohne Konto stempelt `HiveHeroRepository` `lastModified` nur, wenn es fehlt; geladene Objekte bringen ihren Stempel mit, er bleibt der des ersten Speicherns. Mit Konto stempelt `SyncingHeroRepository` korrekt. Die Konfliktansicht zeigt dadurch nach dem Anmelden veraltete Zeiten für Offline-Helden. | `bestandsheld_ablauf_test.dart` | ARCH-06 oder Kleinfix |
| B5 | mittel | Eine unbekannte Steigerungsart (`kind`) wirft beim Laden und macht den ganzen Helden unlesbar — etwa nach einem Export aus einer neueren App-Version. | Domain-Test (f08b) | Versionsstrategie vor ARCH-02 |
| B6 | mittel/hoch | Unbekannte Felder gehen bei `fromJson`/`toJson` verloren. Ein Gerät mit älterer App überschreibt per Sync die neueren Felder. | Domain-Test | Versionsstrategie vor ARCH-02/03 |
| B7 | mittel/hoch | Nahkampf-AT/PA der Kampfvorschau rechnen mit eigenen Modifikatoren (`combat_rules.dart`: `persistentMods`, Textmodifikatoren, `tempMods`). Wundabzüge fehlen nachweislich, obwohl AT-Basis und Initiative sie enthalten; laut Code fehlen dort auch benannte und Inventar-Modifikatoren (nicht eigens getestet). | Regeltest (f01, f04 mit Wunde) | eigener Regelauftrag, Bezug ARCH-04 |
| B8 | mittel | Offline geänderte Laufzeitwerte (LeP, AsP, Wunden …) lädt `syncNow` nicht hoch: `_syncHeroStates` überträgt nur Zustände, die online noch fehlen. Erst die nächste Zustandsänderung mit Verbindung holt sie nach; wechselt man vorher das Gerät, sieht es den alten Stand. | `sync_zwei_geraete_test.dart` | eigener Sync-Auftrag, Bezug ARCH-06 |
| B9 | niedrig/mittel | `_mergeEntry` baut verknüpfte Inventareinträge aus dem Slot neu auf und übernimmt nur eine feste Feldliste. Typ (`typ`) und Träger (`traegerTyp`, `traegerId`) gehen bei jedem Speichern verloren, obwohl der Inventareditor den Träger auch für verknüpfte Einträge anbietet. | `bestandsheld_ablauf_test.dart` (f01) | behoben (Kleinfix, siehe Aktualisierung) |
| B10 | hoch | Nach dem Übernehmen eines Online-Stands merkte sich die Sync-Basis den Hash des Schreibers. Konnte diese Version den Stand nicht verlustfrei darstellen, lud ein bloßer Abgleich die verkürzte Fassung ohne Konflikt hoch und löschte fremde Felder auf allen Geräten. | `sync_app_versionen_test.dart` | behoben (`192cf41`) |
| B11 | mittel | Der Angriffsdialog der Begleiter baute einen bearbeiteten Angriff neu auf und setzte die gekauften AT/PA-Steigerungen (`steigerungAt`/`steigerungPa`) auf 0 zurück; die ausgegebenen AP blieben gebucht. | `test/ui/begleiter/begleiter_angriff_test.dart` | behoben (Kleinfix, `a8bde70`) |
| B12 | mittel | Ein verknüpfter Inventareintrag mit unbekannter Quelle (`source`) galt über den Ersatz `manuell` als manueller Eintrag; der Abgleich legte für seinen Slot einen zweiten, verknüpften Eintrag an. | `unbekannte_verschachtelte_felder_test.dart` (Inventarabgleich) | behoben (minimal abgesichert, `9d2aeaa`) |
| B13 | mittel | Ein Waffenslot mit unbekannter Kampfart fiel auf Nahkampf zurück; Verweismigration und Abgleich verwarfen seine Geschosse samt Inventardaten, Mengenänderungen liefen ins Leere. | `unbekannte_verschachtelte_felder_test.dart`, `bestandsheld_ablauf_test.dart` | behoben (Kleinfix, `9d2aeaa`) |

**Aktualisierung 27.09.2026:** B1 (`d5f111c`), B7 (`de36df2`), B8
(`20102a0`), B4 (`9eebf93`) sowie B5/B6 (`6be321c`) haben Fix-Commits.
B2/B3 sind im ARCH-03-Teilstand oben behoben. Bei B6 bleiben unbekannte
Felder *innerhalb* verschachtelter Objekte ungeschützt; der Fix bewahrt
unbekannte Felder oberster Ebene und unbekannte Steigerungsarten. Nächster
Architekturschritt ist die Versions- und Sync-Kompatibilität für neue
verschachtelte Felder, bevor ARCH-03 über den B2/B3-Teilfix hinausgeht.

**Aktualisierung 28.09.2026:** B6 deckt jetzt auch die Ausrüstung ab
(`f28cb1a`); andere verschachtelte Modelle bleiben ungeschützt, siehe den
ARCH-03-Teilstand vom 28.09.2026. B10 ist mit `192cf41` behoben, B9 ist neu
und gehört zu ARCH-03.

**Aktualisierung 28.09.2026 (B9):** Vorgezogen als Kleinfix, weil jedes
Speichern Daten verlor. `_mergeEntry` (`inventory_sync_rules.dart`) baut
verknüpfte Einträge nicht mehr aus dem Slot neu auf, sondern ändert den
bestehenden Eintrag per `copyWith`; aus dem Slot kommen nur Identität,
magisch/geweiht, `istAusgeruestet` (Ausrüstung) und `anzahl` (Geschosse).
Der Test in `bestandsheld_ablauf_test.dart` setzt an f01 Typ und Träger,
speichert, ändert den Kampf und prüft nach dem Neustart. Die Fixtures und
Hash-Pins bleiben unverändert, keine trägt Typ oder Träger.

**Aktualisierung 28.09.2026 (verschachtelte Modelle):** B6 deckt jetzt alle
verschachtelten Modelle von Held und Zustand ab, siehe ARCH-03-Teilstand
„Alle verschachtelten Modelle“. Neu ist B11, als Kleinfix behoben, weil
jedes Bearbeiten eines Begleiterangriffs gekaufte Steigerungen verlor.

**Aktualisierung 28.09.2026 (Aufzählungswerte):** B6 bewahrt jetzt auch
unbekannte Aufzählungswerte und Wundzonen, siehe ARCH-03-Teilstand
„Unbekannte Aufzählungswerte“. B12 und B13 traten erst mit dem Ersatzwert
zutage und sind mit `9d2aeaa` behoben: B12 minimal (der Eintrag deckt seinen
Slot ab und bleibt unverändert), B13 über `MainWeaponSlot.fuehrtGeschosse`,
das auch eine unbekannte Kampfart als geschossführend behandelt.

## Abschluss und Übergabe je Aufgabe

Eine Aufgabe erst in der Übersicht abhaken, wenn ihre Abnahmekriterien erfüllt
und die zugehörigen Prüfungen erfolgreich sind. Bei Teilergebnissen bleibt der
Hauptpunkt offen. Unter dem jeweiligen Abschnitt ergänzen:

- umgesetzter Teilumfang und Datum;
- zugehörige Commits und gegebenenfalls weiterführender Detailplan;
- tatsächlich ausgeführte Prüfungen und Ergebnis;
- verbleibende Entscheidungen, Risiken und nächster konkreter Schritt.

Als Mindestprüfung gelten `flutter analyze` und die relevanten `flutter test`-
Läufe gemäß AGENTS.md. README, CLAUDE.md und betroffene Dokumentation im selben
Commit aktualisieren. Diese Liste hält Aufgabenstatus und offene Arbeit fest;
die technische Gesamtdokumentation beschreibt weiterhin das tatsächlich
implementierte Verhalten.
