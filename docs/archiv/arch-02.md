# Archiv — ARCH-02 Regelrelevante Eigenschaften strukturiert speichern

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

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

**Fortsetzung 10.10.2026 — Herkunftsmerkmale; umgesetzt 12./13.10.2026.**
Die [schriftliche Spezifikation](../superpowers/specs/2026-10-10-arch02-herkunftsmerkmale-design.md)
war freigegeben, der [Implementierungsplan](../superpowers/plans/2026-10-10-arch02-herkunftsmerkmale.md)
ist in sechs Aufgaben ausgeführt. Direkte Herkunftsmodifikatoren sind
strukturiert (`HeroBackground.herkunftsModifikatoren`, `formatVersion: 1`),
freie Fragmente bleiben erhalten, Vor-/Nachteile tragen die Herkunft als
Metadatum (`HeroMerkmal.herkunft`) ohne zweite regelwirksame Kopie. Ein
vollständiger Herkunftskatalog, automatische Generierung und AP-Buchungen
bleiben separate Folgeumfänge.

- [x] Versionierten Herkunftsdatenvertrag und optionale Merkmalsherkunft
  einschließlich unbekannter Felder, Werte und ausdrücklich leerer Listen
  umsetzen. *(Aufgabe 1, `158572e8`.)*
- [x] Idempotente Migration, Textprojektion und ausdrücklichen Abgleich mit
  älteren Apps ergänzen; wiederholte Modifikatorfragmente erhalten.
  *(Aufgabe 2, `c56001a4`.)*
- [x] Gemeinsame Herkunftsauswertung für Werte, Startwerte, Quellen und
  Ressourcenaktivierung einführen; Doppelwirkungen ausschließen.
  *(Aufgabe 3, `b9bb7f00`.)*
- [x] Speicherung, Editor-Rebuild, Hive, Import/Export und Zwei-Geräte-Sync
  einschließlich Mischbetrieb und Feldschutz absichern. *(Aufgabe 4,
  `83e33717`.)*
- [x] Herkunftsbearbeitung und Vorschau mit dem Schutz offener Planungen
  verbinden; bestehende Vor-/Nachteile um Herkunftsangaben ergänzen.
  *(Aufgabe 5, `9c881c46`.)*
- [x] Automatisierte Abnahme abschließen. *(Aufgabe 6, siehe unten.)*
- [ ] Manuelle Bedienprüfung auf einem echten Gerät; danach ARCH-02-Gesamtstatus
  prüfen.

*Abnahme (automatisiert).* `flutter analyze --no-pub` ohne Befund, LOC-Budget
eingehalten. Gesamtsuite seriell mit eigenem `DSA_MCP_DATA_DIR`: 4689
bestanden, 3 übersprungen, 2 fehlgeschlagen; beide waren Tests der
Workspace-Übersicht, die die entfallenen Textfelder `rasse_mod` & Co.
ansprachen, und sind angepasst
(`test/ui/workspace/hero_workspace_edit_mode_test.dart`, Datei danach einzeln
grün: 32 bestanden, 3 übersprungen). Die Gesamtsuite wurde danach nicht
vollständig wiederholt.

*Entscheidungen und Grenzen.*

- Die drei Textfelder der Übersicht sind durch Listen ersetzt; `*ModText`
  bleiben als Projektion für ältere Apps und gelten bei unbekannter
  Containerversion oder gesperrter Gruppe als Rechengrundlage.
- Ändern beide Geräte dieselbe Herkunftsgruppe (auch verschiedene Einträge),
  entsteht ein sichtbarer Sync-Konflikt, weil sich auch beide Textprojektionen
  ändern. Das generische Zusammenführen blieb unverändert.
- Eine Textabweichung durch eine ältere App wird nie beim Speichern aufgelöst,
  nur über „Geänderten Text übernehmen“ / „Liste behalten“.
- Das UI2-Merkmalsblatt ist bei offener Planung schreibgeschützt; die Aktion
  „Herkunft ändern“ erscheint dort deshalb nicht.
- Nicht geprüft: Gerätebedienung (360 px/Textfaktor 2 nur per Widgettest) und
  Live-Sync mit Firebase.

*Automatisierte Abnahme wiederholt (16.10.2026).* `flutter analyze --no-pub`
ohne Befund; Gesamtsuite seriell (`--concurrency=1`, eigenes
`DSA_MCP_DATA_DIR`): 6177 bestanden, 3 übersprungen, 0 fehlgeschlagen. Damit
ist die in der Abnahme oben vermerkte unvollständige Wiederholung nachgeholt.

*Checkliste für die manuelle Bedienprüfung (offen, Gerät nötig).* Erst wenn
alle Punkte bestanden sind, ARCH-02 oben abhaken:

- [ ] Übersicht: je Gruppe Rasse/Kultur/Profession einen direkten Modifikator
  und ein freies Fragment anlegen, ändern, entfernen; Werte im Bogen stimmen.
- [ ] Merkmal: Herkunft über den gemeinsamen Dialog ändern (Übersicht und
  UI2-Merkmalsblatt); Wirkung bleibt unverändert, nur das Metadatum wechselt.
- [ ] Schmal (360 px) und Textfaktor 2: keine Überläufe in Herkunftskarten,
  Dialogen und Merkmalsblatt.
- [ ] Offene Planung: Bearbeiten fragt nach, „Abbrechen“ erhält die Sitzung,
  UI2-Merkmalsblatt ist schreibgeschützt.
- [ ] Abweichung durch ältere App (Textfeld geändert): Bearbeiten gesperrt bis
  „Text übernehmen“ oder „Liste behalten“; nichts wird still aufgelöst.
- [ ] Export → Import desselben Helden: Herkunft, Stufen, Varianten und
  Freitexte identisch.
- [ ] Live-Sync mit zwei Geräten (Firebase): gleiche Änderung in einer Gruppe
  auf beiden Geräten ergibt einen sichtbaren Konflikt, verschiedene Gruppen
  führen still zusammen.
