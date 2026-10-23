# Katalog, Vor-/Nachteile, Herkunft und Sonderfertigkeiten

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Die kanonische Katalogquelle bleibt `assets/catalogs/house_rules_v1/`.
- Vor- und Nachteile liegen dort katalogisiert in `vorteile.json` und
  `nachteile.json`, ihre Regelwirkungen deklarativ als `wirkungen`
  (`lib/catalog/hero_trait_effect.dart`). Der Held speichert sie seit ARCH-02
  strukturiert in `HeroSheet.vorteilEintraege`/`nachteilEintraege`
  (`HeroMerkmal`: Katalog-ID, Wert, Auswahl, Textfragment). **Die Liste
  führt**; `vorteileText`/`nachteileText` sind nur ihre Projektion für ältere
  App-Versionen. Ändert eine ältere Version den Text, meldet
  `gleicheMerkmaleAb` die Abweichung. Sie wird **nie** still aufgelöst,
  auch nicht von `saveHero`: Die Übersicht sperrt das Bearbeiten, bis der
  Nutzer „Text übernehmen“ oder „Liste behalten“ wählt. Listen nur bei
  Belegung schreiben (Hash-Pins); migriert wird erst in `saveHero`
  (`merkmaleZumSpeichern`, nur mit geladenem Katalog), zur Laufzeit ohne
  Speichern. Mehrdeutiges wird nie geraten. Regeln erhalten Vor-/Nachteile
  nur über `werteMerkmaleAus` (`lib/rules/derived/hero_merkmal_*_rules.dart`):
  Katalogisiertes wirkt über die ID, Freies über den Textparser, nie beides.
  Ohne Katalog rechnet alles über den Text der Liste; der Äquivalenztest in
  `test/rules/hero_merkmal_rules_test.dart` hält beide Wege gleich — eine neue
  Katalogwirkung braucht dort einen passenden Namensweg oder eine bewusste
  Ausnahme. Die Einstiegsfunktionen verlangen `required RulesCatalog?
  catalog`: in `lib/` immer den vorhandenen Katalog durchreichen,
  `catalog: null` (Textweg) nur in Tests. Details in
  `docs/technical_overview.md` Abschnitt 4.11.
- **Herkunftsmodifikatoren (ARCH-02, umgesetzt, Stand 13. Oktober 2026):**
  `HeroBackground.herkunftsModifikatoren` (`lib/domain/hero_herkunft.dart`,
  `hero_herkunfts_modifikator.dart`, flach im Helden-JSON, nur bei Belegung
  geschrieben, `formatVersion: 1`) hält die strukturierten Einträge je
  `HeroHerkunft` (Rasse, Kultur, Profession); `HeroMerkmal.herkunft` ist ein
  reines Metadatum. Fehlender Container = nicht migriert, drei leere Listen =
  ausdrücklich keine Einträge. Unbekannte Version, Nicht-Objekte, nicht
  verstandene Einträge und Gruppen bleiben roh erhalten
  (`unverstandeneRohdaten`/`unverstandeneGruppen`), doppelte IDs ebenso; sie
  sperren nur die betroffene Gruppe (`istGruppeBearbeitbar`). Migration,
  Migration (`hero_herkunft_migration_rules.dart`, UUID v5 aus Herkunft,
  Position und Fragment, Texte bleiben unverändert, Abweichung nur über
  `loeseHerkunftsAbweichung`) und Auswertung stehen. **Wirkung:**
  `werteHerkunftAus` (`hero_herkunft_rules.dart`) ist der einzige Weg, auf dem
  Herkunft rechnet: Parser (`parseModifierTextsForHero`), Quellenaufschlüsselung
  und Ressourcenaktivierung übergeben den Rohtext der Herkunft nie mehr an den
  Textparser (`modifier_text_parser.dart`). Direkte Einträge führen über ihre
  strukturierten Felder, freie Einträge über ihren Text; ohne Container, bei
  unbekannter Version oder gesperrter Gruppe gilt der Kompatibilitätstext.
  Aktivierung folgt den erkannten Codes, nie der Summe. **Schreiben:**
  `saveHero` ruft `herkunftZumSpeichern` auf (nur bei fehlendem Container);
  Gruppen ändert ausschließlich `ersetzeHerkunftsEintraege`
  (`hero_herkunft_bearbeitung_rules.dart`: Liste und Textprojektion der
  Gruppe gemeinsam, auf dem frisch geladenen Stand, `StateError` bei
  gesperrter oder inzwischen geänderter Gruppe). Beidseitige Änderungen am
  Container sind im Sync und im Editorentwurf ein sichtbarer Konflikt.
  **Bedienung:** Die Übersicht zeigt je Gruppe eine `HeroHerkunftSection`
  (`ui/screens/hero_overview/`, rechnet nichts, Callbacks), der Tab hält
  `_draftHerkunft`; `bestaetigeBearbeitungBeiPlanung` läuft vor Dialog und
  Entfernen. Die Herkunft eines Merkmals ändert der gemeinsame Dialog
  `lib/ui_shared/merkmal_herkunft_dialog.dart` (Übersicht und UI2-Merkmalsblatt,
  nur Metadatum). Abschluss und Gesamtstatus laut
  [Plan](../superpowers/plans/2026-10-10-arch02-herkunftsmerkmale.md).
- Begabungen und Unfähigkeiten wirken über die Katalogwirkung `lernspalte`
  auf ihre Ziele; `ermittleBegabungen` (`hero_begabung_rules.dart`) liefert
  je Talent, Zauber, Sprache/Schrift und Ritualkenntnis einen
  `LernspaltenBefund`. **Abgeleitet, nie am Ziel gespeichert**: das Häkchen
  `gifted` bleibt daneben, eine Begabung aus Vorteil erscheint gesperrt
  (`BegabungHaekchen`). Begabung wirkt wie das Häkchen (eine Spalte,
  Maximum +5), Merkmale je passendem Merkmal; Unfähigkeit verteuert um eine
  Spalte. Neue Kostenstellen nehmen den Befund, nie `entry.gifted` allein.
  Der Textweg kennt keine Lernspalten (bewusste Ausnahme im
  Äquivalenztest).
- Zauber-Erwerbsblatt: `lib/rules/derived/spell_catalog_filter_rules.dart`
  kombiniert gelernte Repräsentationen, ein Merkmal und Mindestverbreitung.
  Maßgeblich ist die tatsächliche Zauberrepräsentation (`Dru(Elf)2` → `Elf`);
  Repräsentation und Verbreitung müssen am selben Katalogeintrag passen.
  „Alle“ erhält die Lernoptionen für fremde Zauber; der Filter ändert keine AP-Regeln.
- Mehrfach erwerbbare allgemeine Sonderfertigkeiten (Kulturkunde, Geländekunde,
  Ortskenntnis, Akklimatisierung, Berufsgeheimnis) tragen im Katalog ihre
  Auswahlmöglichkeiten (`mehrfachwaehlbar`, `varianten`, `ap_erstwerb`,
  `ap_folgeerwerb`). Jede erworbene Instanz wird als eigener Eintrag
  `Basisname (Variante)` in `HeroSheet.talentSpecialAbilities` gespeichert;
  Namensaufbau und gestaffelte AP-Vorschläge liegen in
  `lib/rules/derived/special_ability_variant_rules.dart`.
- Magische Sonderfertigkeiten nutzen dieselbe Mechanik mit `varianten_gruppen`
  (Varianten mit gruppenspezifischen Kosten): Merkmalsgroßmeister und Arkane
  Meisterschaft nach Merkmalsklassifikation, die 17 Ritualgruppen der Kategorie
  `Traditionsrituale` je Einzelritual. Merkmalskenntnisse, Repräsentationen,
  Zauberspezialisierungen und Ritualkenntnisse sind dagegen eigene Felder im
  Heldenmodell und werden nicht als Sonderfertigkeit gepflegt; ihre AP-Kosten
  stehen in `lib/rules/derived/magic_acquisition_rules.dart` bzw.
  `learning_rules.dart`. Ihre Katalogeinträge tragen deshalb
  `nur_information: true` und erscheinen im Picker ohne Erwerbsschalter.
- Vor-/Nachteile mit `{choice}` im `selectionTemplate` tragen im Katalog ihre
  Auswahl (`choiceLabel`, `choices`, `choiceSource`, `choiceFreeText`);
  `resolveTraitChoices` (`lib/catalog/hero_trait_choices.dart`) loest
  katalogabgeleitete Quellen auf. „Herausragende Eigenschaft" ist der einzige
  Eintrag mit echter Regelwirkung
  (`lib/rules/derived/attribute_trait_rules.dart`): er hebt Startwert **und**
  aktuellen Wert, das Maximum folgt über `ceil(start × 1,5)`. Die Eigenschaft
  wird deshalb **ohne** diesen Bonus eingetragen. Startwerte und Maxima gibt es
  nur über `computeHeroEffectiveStartAttributes` /
  `computeHeroAttributeMaximums` — `HeroSheet.startAttributes` trägt bereits das
  Ergebnis und darf nie erneut modifiziert werden. Details in
  `docs/technical_overview.md` Abschnitt 4.10.
- Erwerbsvoraussetzungen liegen zusätzlich zum Freitext `voraussetzungen` als
  maschinenlesbarer Block `voraussetzungen_struktur` im Katalog
  (`lib/catalog/special_ability_requirement.dart`, Schema in
  `docs/technical_overview.md` Abschnitt 4.9). Gepflegt für magische,
  allgemeine, Kampf- und karmale Sonderfertigkeiten sowie Manöver.
  Die Gottheit prüft die Art `gottheit` gegen `HeroSheet.gottheit` (ohne
  erfasste Gottheit nur Hinweis); nicht modellierte karmale Voraussetzungen
  wie Entrückung bleiben Hinweise zur manuellen Prüfung. Geprüft wird über `buildHeroRequirementContext` und
  `evaluateRequirements` (`lib/rules/derived/`). Ein offener Punkt sperrt nie:
  Die UI zeigt eine Checkliste (`lib/ui/widgets/requirement_checklist.dart`)
  und verlangt im Erwerbsdialog die Bestätigung „Trotzdem erwerben
  (Meisterentscheid)".
- Kampf-Voraussetzungen brauchen eigene Bedingungsarten, weil sie auf Dinge
  außerhalb der SF-Kataloge zeigen: `manoever` (steht in `manoever.json`),
  `basiswert` (AT/PA/FK/INI), `waffenmeister` (liegt in
  `combatConfig.waffenmeisterschaften`), dazu `nachteil` und `rasse_verboten`.
  Die Katalogtests unter `test/catalog/` lösen jede Referenz gegen ihren
  Bezugskatalog auf — ohne sie fällt ein Tippfehler erst im Betrieb auf, und
  dort nur als stillschweigend unerfüllte Bedingung.
- Ob eine Kampf-SF bei einem Helden aktiv ist, beantwortet ausschließlich
  `isCombatSpecialAbilityActive` (`lib/rules/derived/combat_special_ability_state.dart`).
  Ein Teil der Kampf-SF steht nicht unter `activeCombatSpecialAbilityIds`,
  sondern in eigenen Feldern (`ausweichenI`, `kampfreflexe`,
  `globalArmorTrainingLevel`); diese Zuordnung darf nicht in der UI dupliziert
  werden.
- Aufeinander aufbauende Sonderfertigkeiten teilen sich eine `kette` mit
  gemeinsamer `id` und aufsteigender `stufe`; jede Stufe bleibt ein eigener
  Katalogeintrag mit eigenen Kosten und Voraussetzungen
  (`lib/rules/derived/special_ability_chain_rules.dart`). Ketten-Logik und
  Stufen-Karte (`lib/ui/screens/shared/special_ability_chain_card.dart`) sind
  generisch über `SpecialAbilityEntry`
  (`lib/catalog/special_ability_entry.dart`), damit Kampf-Ketten (`Ausweichen`,
  `Rüstungsgewöhnung`, `Schildkampf`, `Parierwaffen`, `Beidhändiger Kampf`)
  dieselbe Darstellung bekommen wie die magischen. Alte Sammelnamen wie
  `Eiserner Wille I / II` bleiben als `alias_namen` der ersten Stufe erhalten,
  damit Bestandshelden erkannt werden.
- Die unmittelbare Vorstufe steht auch in `voraussetzungen_struktur`, einschließlich
  Zusatzpaketen und Ketten mit unnummerierter erster Stufe. Der Asset-Test
  `test/data/special_ability_chain_integrity_test.dart` prüft Vollständigkeit,
  eindeutige Stufen und rückwärts gerichtete Stufenabhängigkeiten.
- `rules/derived/special_ability_visibility_rules.dart` filtert unpassende Magie-/
  Karmabereiche anhand der effektiven Ressourcenaktivierung; Bestand und geplante
  Erwerbe bleiben sichtbar. `shared/special_ability_visibility_toggle.dart`
  speichert `HeroSheet.showInapplicableSpecialAbilities` (Standard `false`, dann
  kein JSON-Feld). Picker und Fähigkeitenbaum verwenden dieselbe Präferenz.
  `AdvancementSessionController.setShowInapplicableSpecialAbilities` persistiert
  ausschließlich die Einstellung und aktualisiert bei offener Runde deren Basis
  mit erneutem Replay. Weder Entwurf noch AP werden dabei übernommen; fremde
  Heldenänderungen lösen weiterhin einen Konflikt aus.
- Magische SF im Split-Katalog unterscheiden `tradition` von einer benannten
  `ritualkenntnis`: Eine Repräsentation ersetzt keinen geforderten RkW.
  Varianten-, Kultur- und Gemeinschaftsbedingungen bleiben, soweit nicht
  modelliert, ausdrückliche Hinweise für die manuelle Prüfung. Quellen und
  offene Folgearbeiten stehen in `docs/rules_mapping_house_rules_v1.md`
  unter „Katalogkorrektur magischer Voraussetzungen (11. Oktober 2026)“.
- Aktivierbare Hausregel-Pakete liegen eingebaut unter
  `assets/catalogs/house_rules_v1/packs/<packId>/manifest.json`.
- Eingebaute Pack-Manifeste muessen ausserdem explizit in `pubspec.yaml`
  als Flutter-Assets registriert sein, damit der Settings-Screen sie laden kann.
- Importierte Hausregel-Pakete liegen im Heldenspeicher unter
  `house_rule_packs/<version>/<packId>/manifest.json`.
- Reisebericht-Daten bleiben separat unter `assets/catalogs/reiseberichte/house_rules_v1/`.
  Buchen und Zuruecknehmen der Reisebericht-Belohnungen haben eine Quelle:
  die Posten in `reisebericht_rules.dart` (ID, Inhalt, Bedingung).
  `berechneReiseberichtBuchung` bucht Neues und nimmt zurueck, was
  enthakt, geloescht oder unterschritten wurde (auch Schwellen-, Gruppen-
  und Meta-Boni). Altdaten werden nie rueckwirkend korrigiert. Neue
  Belohnungsarten gehoeren in `_buchungsposten`, nie in eine eigene
  Buchungsfunktion.
- Geschuetzte Katalog-Felder (Wirkung/Varianten von Zaubern, Erklaerungstexte
  von Manoevern sowie von Kampf-, allgemeinen, karmalen und magischen
  Sonderfertigkeiten, `kurztext`/`hinweise`/`hausregel_text` des
  Kurzregel-Kompendiums) sind v3-verschluesselt
  (AES-GCM, globaler Salt im Manifest `catalog_salt_v3`). Beim Unlock
  entschluesselt `decryptedCatalogSourceDataProvider` den ganzen Katalog
  einmal — Detail in `docs/technical_overview.md` Abschnitt 5.3. Passwoerter
  werden vor PBKDF2 NFC-normalisiert, damit Eingaben mit Umlauten
  unabhaengig von NFC/NFD-Codepoint-Repraesentation funktionieren.
- **Regelbuch-Langtexte nie im Klartext einchecken.** Neue oder neu importierte
  Texte aus Regelwerken (`erklarung_lang`, `wirkung`, `variants`, ...) gehen
  nur verschluesselt ins Repo: Feld in `PROTECTED_FIELDS` von
  `tool/encrypt_catalog_fields.py` und in
  `test/catalog/geschuetzte_langtexte_test.dart` eintragen, dann
  `python tool/encrypt_catalog_fields.py --format v3` ausfuehren. Das
  Passwort liegt lokal in `docs/Passwort.env` (`KATALOG_PASSWORT=...`, in
  `.gitignore`; alternativ Umgebungsvariable oder `--password`). Das Tool
  prueft das Passwort vorab an einem vorhandenen `enc:3:`-Wert und bricht bei
  Abweichung ohne Aenderung ab. Angezeigt wird ein Feld in der UI nur ueber
  `resolveProtectedValue` (Locked-Hinweis ohne Passwort); Regelrechnung darf
  kein verschluesseltes Feld lesen.
- Die App besitzt dafuer eine eigene In-App-Verwaltung unter
  `Einstellungen > Hausregeln > Hausregelverwaltung`.
