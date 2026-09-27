# Test Strategy

## Ziel

Die Testsuite ist fachlich getrennt, damit Regeln/Formeln isoliert und
technische UI-Aspekte getrennt getestet werden.

## Verbindliche Grundregel

- Regel-/Formeltests gehoeren **nur** nach `test/rules/`.
- UI-Tests unter `test/ui/` pruefen nur technische Aspekte:
  Rendering, Interaktion, Navigation, Persistenz-Flows.
- Mischtests (Regel + Technik in einer Testklasse) sind nicht erlaubt.

## Ordnerstruktur

- `test/rules/`: pure Logik, Formeln, Validierung
- `test/ui/`: Widget-/Smoke-/Performance-Tests der bestehenden Oberfläche
- `test/ui2/`: dasselbe für die neue Oberfläche (`lib/ui2/`), gespiegelt zur
  Quellstruktur. Beide Bäume laufen während des Oberflächen-Neubaus
  nebeneinander; `test/ui/` wird erst entfernt, wenn die alte Oberfläche fällt.
- `test/state/`: Provider- und Stream-Verhalten
- `test/data/`: Loader/Transfer/Repository-nahe Tests
- `test/domain/`: Serialisierung/Model-Roundtrips
- `test/workspace/`: Workspace-Koordinationslogik
- Steigerungsrunden: `test/rules/advancement_rules_test.dart` prüft Replay und
  Abhängigkeiten; `test/domain/hero_advancement_entry_test.dart` die persistierte
  Historie; `test/state/advancement_session_test.dart` Planung, Entfernen,
  Übernahme und Konflikte; `test/ui/advancement/` die getrennte Bedienung.
- Aktive Einträge und Erwerbsblatt:
  `test/rules/advancement_scope_rules_test.dart` prüft, was als „auf dem Bogen“
  gilt (eingeblendete Werte ohne Wert eingeschlossen), die Aufteilung in
  `active`/`inactive`, die nächste Stufe begonnener Ketten, Alias-Namen als
  Erwerbsnachweis und die Aktivierungskosten des Schritts `-1 → 0`.
  `test/ui/advancement/advancement_activation_sheet_test.dart` prüft Suche,
  Artfilter, den Schalter „Nur erwerbbare“, die Bestandsdarstellung erworbener
  Sonderfertigkeiten, die Suchbrücke und die Bedienbarkeit auf 390 und 320 px.
- Eigenschaftsvorschau: `test/rules/advancement_impact_rules_test.dart` prüft
  Rundung, Herkunftsboni, Inventar-/Zustandsmodifikatoren, Begabung und normale,
  Kampf-, Zauber- sowie epische Grenzen. Die Katalog-Widgettests prüfen
  Live-Zielwerte, Abbrechen, Vormerken/Entfernen, Ressourcenfreischaltung und
  die gemeinsame Scrollbarkeit von Basiswerten und Optionen auf 320 px Breite.
- Fähigkeitenbaum und Manöver: `test/rules/advancement_skill_tree_test.dart`
  prüft UND-/ODER-Verknüpfungen, Vorstufen, Zyklen und Planungsstatus;
  `test/rules/advancement_maneuver_test.dart` prüft Erwerb, Talentbindung,
  Duplikate und Katalog-Roundtrips. `test/ui/advancement/advancement_skill_tree_ui_test.dart`
  deckt Erwerbsbedienung, Suche und Details auf schmalen Bildschirmen ab.
  `advancement_ability_details_test.dart` prüft vollständige Beschreibungstexte,
  Variantenkosten, Kampfboni, aufgelöste Manövernamen, Scrollbarkeit und
  passwortgeschützte Regeltexte im Detaildialog.

## Bestandsfixtures (ARCH-07)

Unter `test/fixtures/heroes/` liegen synthetische Bestandshelden als
Transfer-Bundles, genau so, wie die App sie exportiert. Sie vertreten Daten,
die schon auf Geräten und in der Cloud liegen:

| Datei | Deckt ab |
|---|---|
| `f01_krieger_normal` | Nah- und Fernkampfwaffe mit Geschossen, Schild, Rüstung, benannte Modifikatoren, Notiz, laufendes Abenteuer, Wunde, Würfelprotokoll |
| `f02_geode_magisch` | Repräsentation mit Traditionswahl, Zauber, Rituale, aktiver Armatrutz, Altname `Eiserner Wille I / II` |
| `f03_geweihter_karmal` | KaP aus der Profession, abgeschaltete Magie, karmale SF |
| `f04_episch` | epische Felder, Haupteigenschaften, Aktivierungsregel |
| `f05_freitext_merkmale` | unerkannte Freitext-Merkmale, Dauermodifikator nur in `persistentMods` |
| `f06_gleichnamige_ausruestung` | je zwei gleichnamige Waffen, Geschosse und Rüstungsteile mit verschiedenen Inventardaten |
| `f07_legacy_schema1` | handgeschriebener Altstand: Transferversion 1, ohne `schemaVersion`, nur alte Schlüssel |
| `f08_steigerungshistorie` | Schemaversion 27 mit übernommener Historie; `f08b` mit unbekannter Steigerungsart |

Regeln:

- **Fixtures werden nie angepasst.** Bricht ein Test daran, ist der Code
  inkompatibel zu vorhandenen Daten geworden — wie bei den Krypto-Goldens.
  Ein neues Format bekommt eine neue Datei.
- Eine neue Migration bringt eine eigene Fixture mit altem Stand mit, dazu
  einen Test, dass erneutes Laden nichts weiter verändert.
- `bestandshelden_kompatibilitaet_test.dart` pinnt die Inhalts-Hashes jeder
  Fixture. Ändert sich einer, bekäme jeder gleich gespeicherte Held einen
  neuen Hash und der Konto-Sync meldete Konflikte. Anpassen nur zusammen mit
  einer bewusst eingeführten Migration.
- Fehler, die diese Tests aufdecken, werden nicht nebenbei behoben: Der Test
  hält das heutige Verhalten mit dem Kommentar `Befund ARCH-07-Bx` fest, der
  Befund steht mit Folgeauftrag in `docs/architecture_roadmap.md`.

Laden über `test/test_support/hero_fixtures.dart` (`Bestandsheld`,
`ladeBestandsheld`, `expectNurGeaendert` mit reihenfolgestrengem Pfad-Diff).

Die Regelwerte je Fixture (`test/rules/bestandshelden_regelwerte_test.dart`)
rechnet `buildHeroComputedSnapshot` gegen den **echten** Katalog
(`test/test_support/real_catalog.dart`: alle eingebauten Hausregel-Pakete
aktiv, ohne Inhaltspasswort, einmal pro Test-Isolat geladen). Die
Erwartungen stehen als Dart-Map im Test, damit Befundkommentare daneben
stehen können. Aktualisiert werden sie nur im selben Commit wie eine gewollte
Regel- oder Kataloganpassung, mit Zeilenkommentar zum Grund — nie per Kopie
der Ist-Ausgabe.

### Ablauf über echte Speichergrenzen

`test/data/bestandsheld_ablauf_test.dart` arbeitet mit `HiveHeroRepository`
in einem temporären Verzeichnis statt mit `FakeRepository`. Für jede Fixture
prüft er Import → Schließen → Neu öffnen → Export, für f01 zusätzlich den
ganzen Ablauf mit Steigerungsrunde, Ausrüstungswechsel, Treffer samt Wunde,
langer Rast, Neustart und Re-Import als neuer Held. Jeder Schritt vergleicht
den gespeicherten Stand mit `expectNurGeaendert` gegen die Felder, die er
ändern darf.

Fallstricke mit echtem Hive:

- Boxnamen gelten pro Isolat. Ein Repository, das ein Test nicht schließt,
  liefert dem nächsten Test dieselbe offene Box — auch mit anderem Pfad.
  Deshalb registriert jeder Test sein Schließen per `addTearDown`, und das
  temporäre Verzeichnis (`hiveTempVerzeichnis`) wird vorher registriert, also
  erst danach gelöscht. Unter Windows scheitert das Löschen sonst an offenen
  Dateien.
- Wie in der App zuerst den `ProviderContainer` verwerfen, dann das
  Repository schließen.
- `FakeRepository` setzt kein `lastModified`, Hive schon — Vergleiche über
  beide Repositories hinweg laufen über `ohneZeitstempel` oder die
  Inhalts-Hashes.

## Zuordnungsmatrix

| Testdatei | Gruppe | Zweck |
|---|---|---|
| `test/rules/ap_level_rules_test.dart` | rules | AP-Level-Formeln |
| `test/domain/attribute_codes_test.dart` | domain | Attributcode-Parsing/Mapping |
| `test/rules/combat_rules_test.dart` | rules | Kampfberechnungen |
| `test/rules/magic_rules_test.dart` | rules | Magische Regelwirkungen wie Axxeleratus |
| `test/rules/combat_talent_validation_test.dart` | rules | Verteilungsregeln fuer Kampftalente |
| `test/rules/derived_stats_test.dart` | rules | Abgeleitete Basiswerte |
| `test/rules/modifier_text_parser_test.dart` | rules | Text-Modifier-Parsing |
| `test/rules/meta_talent_rules_test.dart` | rules | Meta-Talent-Mittelwerte, Validierung und Aktivierung |
| `test/rules/talent_be_rules_test.dart` | rules | Talent-BE-Regeln |
| `test/rules/talent_value_rules_test.dart` | rules | Formel `TaW + Mod + eBE` |
| `test/rules/bestandshelden_regelwerte_test.dart` | rules | Abgeleitete Werte der Bestandsfixtures gegen den echten Katalog, epische Wundhalbierung, Befunde B1/B7 |
| `test/rules/bestandshelden_ausruestung_test.dart` | rules | Inventar-Kampf-Abgleich mit gleichnamigen Exemplaren, Befunde B2/B3 |
| `test/ui/combat/hero_combat_tab_test.dart` | ui | Combat-UI-Interaktion/Struktur |
| `test/ui/combat/hero_combat_talents_tab_test.dart` | ui | Combat-Talents-UI-Validierungsfluss |
| `test/ui/talents/hero_talents_tab_test.dart` | ui | Talents-UI-Interaktion |
| `test/ui/workspace/hero_workspace_edit_mode_test.dart` | ui | Workspace-Edit-Flow |
| `test/ui/workspace/hero_workspace_import_export_test.dart` | ui | Workspace Import/Export UI |
| `test/ui/workspace/workspace_header_test.dart` | ui | Kompakter Tablet-/Desktop-Workspace-Header inkl. Bild-Fallback |
| `test/ui/home/heroes_home_screen_test.dart` | ui | Startscreen/Navigation |
| `test/ui/performance/ui_rebuild_guardrails_test.dart` | ui | Rebuild-Guardrail |
| `test/ui/smoke/widget_test.dart` | ui | Minimaler App-Start bis zum leeren Startscreen |
| `test/state/hero_actions_avatar_focus_test.dart` | state | Persistenz des Header-Fokuspunkts fuer Avatarbilder |
| `test/state/hero_by_id_provider_test.dart` | state | Provider-ID-Lookup |
| `test/state/hero_computed_snapshot_test.dart` | state | Combined compute pipeline |
| `test/state/hero_provider_lookup_strategy_test.dart` | state | Lookup-Strategie ohne Listenscan |
| `test/state/hero_repository_stream_test.dart` | state | Repository-Streams |
| `test/domain/avatar_gallery_entry_test.dart` | domain | Fokuspunkt-Roundtrip fuer Avatar-Galerieeintraege |
| `test/data/catalog_loader_test.dart` | data | Katalog-Loading/Validierung |
| `test/data/catalog_model_test.dart` | data | Katalogmodell Roundtrip |
| `test/data/hero_actions_import_export_test.dart` | data | Actions Import/Export |
| `test/data/bestandsheld_ablauf_test.dart` | data | Echte Hive-Speichergrenze je Bestandsheld und Ablauf Import bis Export mit Neustart, Befund B4 |
| `test/domain/hero_sheet_model_test.dart` | domain | HeroSheet-Kompatibilitaet |
| `test/domain/hero_transfer_bundle_test.dart` | domain | Transfer-Bundle-Kontrakt |
| `test/domain/bestandshelden_kompatibilitaet_test.dart` | domain | Bestandsfixtures: Fixpunkt nach einmaligem Laden, Inhalts-Hashes, Altschlüssel, Befunde B1/B5/B6 |
| `test/workspace/workspace_area_registry_test.dart` | workspace | Area-Registry |
| `test/workspace/workspace_tab_edit_controller_test.dart` | workspace | Tab-Edit-Controller |
| `test/ui2/shell/app_root_switch_test.dart` | ui2 | Weiche zwischen bestehender und neuer Oberfläche |
| `test/ui2/shell/karto_workspace_journey_test.dart` | ui2 | Durchgehender Ablauf mit echten Schreibvorgängen |
| `test/ui2/shell/karto_workspace_visual_test.dart` | ui2 | Sieben Breiten × zwei Helligkeiten × Textskalierung 1/2; erzeugt mit `--dart-define=R3_SCREENSHOT_DIR=…` echte PNGs |

## Fallstricke bei Oberflächentests

`scrollUntilVisible` hält an, sobald der Finder greift. Eine `ListView` baut
aber über den sichtbaren Bereich hinaus, das gesuchte Element kann also
außerhalb des Fensters liegen und ein `tap()` daneben gehen. Davor gehören
`ensureVisible` **und** `pumpAndSettle`: der Scroll wirkt erst im nächsten
Frame, sonst rechnet der Tap mit der alten Position.

Zwei weitere Muster führen zu Tests, die **hängen statt zu scheitern** — sie laufen
dann bis zum Zeitlimit und melden nichts Brauchbares.

**Teardown-Reihenfolge bei Stream-Repositories.** `addTearDown` läuft
rückwärts. Wer erst den Container und danach das Repository registriert,
schließt den Stream, solange der Provider noch daran hängt:

```dart
// Falsch: close() laeuft zuerst und wartet auf einen Zuhoerer,
// den erst dispose() abmeldet.
addTearDown(container.dispose);
addTearDown(settingsRepository.close);

// Richtig: dispose() zuerst, dann close().
addTearDown(settingsRepository.close);
addTearDown(container.dispose);
```

**`pumpAndSettle` auf Bildschirmen mit Ladezustand.** Ein
`CircularProgressIndicator` animiert endlos, `pumpAndSettle` wartet also bis zu
seinem Zehn-Minuten-Limit. Wenn ein Test nur wissen muss, welcher Bildschirm
montiert ist, genügen einzelne `pump`-Aufrufe.

Dazu gilt die Regel aus `CLAUDE.md` auch im Test: auf einen asynchronen
Provider nie mit `read(provider.future)` warten. Wer einen Provider am Leben
halten muss, nimmt `container.listen(...)`.

## Laufbefehle

```bash
flutter analyze
dart format --output=none --set-exit-if-changed lib/ test/
flutter test test/rules
flutter test test/ui
flutter test test/ui2
flutter test
```
