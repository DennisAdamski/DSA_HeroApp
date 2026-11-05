# Steigerungen und Entwicklungsplanung

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- **Rundung (Entscheidung 27.10.2026):** Wo Regelwerk oder Hausregel keine
  Rundung nennen, gilt „echt gerundet“ (ab n,50 auf, Halbierungen auf; Wege der
  Helden S. 6). Das gilt auch für den Lehrmeister-Nachlass von 20 %. Gedächtnis
  (3/4) und epischer Aufschlag (1,25) runden so; `apMitLehrmeister`
  (`lib/domain/learn/learn_rules.dart`) rechnet ganzzahlig `(4 x + 2) ~/ 5`
  (RULE-FIX-093, behoben).
- Steigerungen laufen getrennt von manuellen Korrekturen als Sitzung:
  `lib/domain/hero_advancement_entry.dart` trägt persistierbare Einträge,
  `lib/rules/derived/advancement*.dart` Optionen und Replay,
  `lib/state/advancement_providers.dart` den flüchtigen Entwurf.
  `lib/ui/screens/advancement/` bietet Katalog und Inspector-Historie;
  `workspace/workspace_advancement.dart` verbindet sie mit dem Workspace.
  `advancement_value_tile.dart` verdichtet Eigenschaften, Talente und Zauber;
  bei ausreichender Breite stehen Eigenschaften links, Basiswerte und Zukäufe
  rechts. `advancement_specialization_dialog.dart` erfasst Talentspezialisierungen.
  Deren Prüfungen liegen in `rules/derived/advancement_specialization_rules.dart`.
  Sie verwenden `AdvancementKind.talent` mit `options.action = specialization`
  und `options.specialization` als Namen; Replay erhält TaW, SE und übrige
  Talentfelder und übernimmt beide Spezialisierungsfelder synchron.
  Empfehlungen für Nicht-Kampftalente liefert `talent_specialization_hints.dart`
  (WdS-Listen je Talentname, nur Auswahlhilfe ohne Sperre; Kampftalente wählen
  weiter aus ihren Waffenkategorien). Der Talentkatalog gruppiert nach
  `advancement_talent_groups.dart` (`TalentGruppe` mit eigener Farbe und
  eigenem Symbol, Sprungleiste, einklappbare Köpfe); ein neues Talent braucht
  dort nur eine passende `group` im Katalog, in den Empfehlungen einen Eintrag
  (der Test gegen den echten Katalog meldet fehlende).
  Nur Übernehmen schreibt Werte, AP/SE und `HeroSheet.advancementHistory`
  gemeinsam, über den Ablauf `SteigerungsrundeUebernehmen`
  (`lib/ablaeufe/steigerungsrunde_uebernehmen.dart`, auch für die
  SF-Anzeige). Alte Einträge sind nicht entfernbar; ungültige Folgeeinträge
  blockieren die Übernahme. Leere Historie darf nicht ins JSON geschrieben
  werden (Bestands-Sync-Hashes). `HeroActions.saveHero` prüft für Sitzungen
  zusätzlich den erwarteten Inhalt vor dem Schreiben.
- Für Talente, Zauber, Sprachen und Schriften zeigt der Steigerungskatalog nur
  Ziele, die der Held **auf dem Bogen führt**.
  Maßgeblich ist der Schlüssel in `talents`/`spells`/`sprachen`/`schriften`,
  nicht der Wert: Ein eingeblendeter Eintrag ohne Wert (`null`) ist vorhanden,
  seine Aktivierungskosten sind nur noch offen. `AdvancementOption.isOwned`
  trägt das für **alle** Arten (Eigenschaften und Grundwerte sind immer `true`);
  zusammen mit `currentValue` ergeben sich die drei Zustände. Den Umfang steuert
  `AdvancementScope` (`lib/rules/derived/advancement_scope_rules.dart`) —
  gefiltert wird vor dem Auflösen, die UI siebt nie 800 Einträge selbst.
  Alles Übrige läuft über das Erwerbsblatt
  (`lib/ui/screens/advancement/advancement_activation_sheet.dart`), das sich
  selbst schließt und das gewählte Ziel zurückgibt; geplant wird erst danach
  beim Aufrufer, damit die Sitzung nur an einer Stelle verändert wird.
  Aktivieren und Steigern sind ein Schritt: `fromValue: -1` auf einen freien
  Zielwert, die Kosten des Schritts `-1 → 0` sind die Aktivierungskosten.
  Bei Sonderfertigkeiten nutzt der Fähigkeitenbaum dagegen `AdvancementScope.all`
  und zeigt auch neue Ketten sowie Manöver;
  `unavailableReason == 'Bereits erworben'` bleibt dabei die Sperre für
  `_validateEntry` und wird nur in der Karte als Bestandsnachweis dargestellt.
  Rituale und Liturgien haben kein `AdvancementKind` und liegen außerhalb des
  Modus — das ist keine Lücke der Aktivfilterung.
- **Der Steigerungskatalog hat fünf Bereiche mit Abschnitten**
  (`advancement_catalog.dart`, `_Bereich`/`_Abschnitt`, Nutzerentscheidung
  11. Oktober 2026): Grundlagen (Eigenschaften & Basiswerte, Vorteile,
  Nachteile), Talente (Talente, Sprachen & Schriften, allgemeine SF), Kampf
  (Kampftalente, SF & Manöver), Magie (Zauber, Merkmalskenntnisse, SF &
  Rituale), Karma (SF & Liturgien). Baumabschnitte nutzen
  `AdvancementSkillTreeView(festerBereich:)`; Magie/Karma erscheinen nur bei
  Befähigung oder Bestand (oder „Unpassende einblenden“). Neue Planungsziele:
  `AdvancementKind.advantage`/`disadvantage` (`advancement_trait_options.dart`,
  Regeln/GP-Tarife in `trait_advancement_rules.dart`, WdS S. 170: nur die
  dort genannten Vorteile zu 50 × GP, Nachteile 100 × GP, Schlechte
  Eigenschaften 50/75 × GP je Punkt, gesellschaftliche nie, episch keine
  Vorteile; geschrieben nur über `aendereMerkmale`), Merkmalskenntnisse als
  `magicAbility` mit `action: merkmalskenntnis`
  (`advancement_merkmalskenntnis_rules.dart`) und Waffenmeister am Kampftalent
  als `talent` mit `action: waffenmeister`; die im bestehenden Editor erstellte
  `WaffenmeisterConfig` reist als JSON in den Optionen
  (`advancement_waffenmeister_options.dart`, WdS S. 192). Den
  Waffen-Großmeister findet `grossmeisterFuerTalent`.
  `special_ability_visibility_rules.dart` blendet magische/karmale SF mit
  unerfüllter `tradition`/`spruchzauberer`/`rasse`/`gottheit`-Voraussetzung
  aus (`passtNichtZumHelden`). `HeroSheet.gottheit` (nur bei Belegung im
  JSON) wählt der Karmaabschnitt und speichert sie wie die SF-Anzeige über
  `AdvancementSessionController.setGottheit`; geprüft wird die neue
  Voraussetzungsart `gottheit` (`karma_gottheit_rules.dart`, Sammelname
  `Zwölfgötter`).
- `rules/derived/advancement_skill_tree.dart` baut Abhängigkeiten und Status
  einschließlich UND-/ODER-Knoten. `ui/screens/advancement/advancement_skill_tree_view.dart`
  bindet Suche, Filter und Erwerbsdetails an die Sitzung; `skill_tree_branch.dart`
  zeichnet die Zweige. `rules/derived/advancement_maneuver_rules.dart` löst
  Manövererwerbe einschließlich talentgebundener IDs (`id::talentId`) auf.
  `learnedManeuverIds` berücksichtigt auch Freischaltungen durch Kampf-SF.
- Der Fähigkeitenbaum ist nach Bereich (Kampf/Allgemein/Magie/Karma) und
  Gruppe gegliedert: `rules/derived/advancement_ability_groups.dart` ordnet
  jede Option einer `FaehigkeitenGruppe` zu (Katalogfelder `kategorie`,
  `typ`, `kette`, `stil_typ`, `kampfTyp`, Manöver-`gruppe`, `nurEpisch`;
  wenige Namenslisten für Spezialkampf/Fernkampf-Pakete). Eine Zusammenhangs-
  komponente liegt in der Gruppe ihrer meisten Knoten (Gleichstand: frühere
  Gruppe), Zweige bleiben `SkillTreeBranch`, freistehende Einträge sind
  `SkillTreeChip`-Kacheln. Köpfe und Sprungleiste teilen sich die
  Bausteine des Talentkatalogs (`GruppenAnzeige`); Gruppen starten
  zugeklappt, Suche und „Nur erlernbar“ klappen Treffergruppen auf. Neue
  Sammelgruppen/Namen nur dort pflegen; `test/rules/advancement_ability_groups_test.dart`
  prüft gegen den echten Katalog, dass jede Gruppe belegt ist.
- `ui/screens/advancement/advancement_ability_details.dart` ergänzt den
  Baum-Detaildialog um die verfügbaren Katalogangaben für Sonderfertigkeiten
  und Manöver. Die Darstellung löst Referenznamen aus dem Sitzungskatalog auf
  und verwendet `resolveProtectedValue` mit dem selektiven Passwort-Provider.
- `AdvancementContext` bündelt Held und Katalog für einen Optionsaufbau.
  `buildHeroRequirementContext` und `parseModifierTextsForHero` dürfen nie
  wieder je Option laufen — sonst baut jede der rund 280 SF-Optionen den
  vollständigen Prüfkontext neu auf. `advancementOptionsProvider` memoisiert
  die Liste je Umfang, damit die Suche keinen Katalogaufbau auslöst.
- Eigenschaftsfolgen: `rules/derived/advancement_impact_rules.dart` liefert
  Basiswertvergleiche und neu steigerbare Werte; `advancement_attribute_rules.dart`
  teilt die effektive Zielwertübertragung mit dem Replay. `hero_stat_inputs.dart`
  bereitet die gemeinsamen Modifikatoren für Übersicht und Vorschau vor.
  `ui/screens/advancement/advancement_impact_panel.dart` zeigt Rundenvergleich
  bzw. Dialogvorschau ohne Buchung; Talentgrenzen bleiben beim Optionsmodul.
