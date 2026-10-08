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
- `test/ablaeufe/`: Anwendungsabläufe aus `lib/ablaeufe/` (ARCH-05) ohne
  Oberfläche und ohne Riverpod, direkt mit `FakeRepository`; Uhr und
  Fehlerfälle werden hereingereicht. `abhaengigkeiten_test.dart` ist der
  Importwächter der Schicht. Rechenerwartungen bleiben in `test/rules/`
  (für die Rast `rest_outcome_rules_test.dart`), die Abläufe prüfen frisches
  Laden, nur die erwarteten geänderten Felder, Protokoll, Stempel und
  Fehlerweitergabe. Die Bedienung (Fehleranzeige, Sperre während des
  Speicherns) prüft `test/ui/workspace/rest_panel_test.dart`.
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
| `f08_steigerungshistorie` | Schemaversion 27 mit übernommener Historie |
| `f08b_unbekannte_steigerungsart` | wie f08, letzter Verlaufseintrag mit einer Steigerungsart aus einer neueren App-Version |
| `f09_strukturierte_merkmale` | f05 mit Vor-/Nachteilen im strukturierten Format (ARCH-02): katalogisiert mit Wirkung, frei (`LEP+2`, eigener Tick) und mehrdeutig mit Kandidaten |

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
- Der B2/B3-Teilfix vergibt beim Laden deterministische Kampf-Slot-IDs und
  ergänzt verknüpfte Inventareinträge um `slotRef`. `sourceRef` bleibt der
  Namensverweis für die veröffentlichte App. Die Fixture-Dateien bleiben
  unverändert; Hash-Pins wurden nur für betroffene Helden aktualisiert
  (f01, f02, f04, f06). Der Domain-Test begrenzt die JSON-Änderungen auf IDs
  und `slotRef` und prüft den Fixpunkt nach erneutem Laden sowie gemischte
  ID-/Namensverweise. Ein Hive-Test
  entfernt und benennt einen der beiden gleichnamigen Dolche aus `f06` um
  und prüft Neustart sowie Export. Widgettests stellen sicher, dass die
  Editoren für Geschosse und Nebenhandteile ihre Instanz-ID erhalten.
- ARCH-02 (strukturierte Vor-/Nachteile) ändert beim Laden nichts; die
  Hash-Pins bleiben. Migriert wird erst beim Speichern:
  `test/data/merkmal_migration_test.dart` speichert f01, f02, f03, f05 und f07
  mit echtem Hive, prüft nach dem Neustart Liste, Projektion, Fixpunkt und
  gleiche Regelwerte und exportiert/importiert als Kopie. f09 steht für das
  neue Format; seine Regelwerte sind aus f05 hergeleitet.
- **Mischbetrieb mit der veröffentlichten App** (`main`, vor ARCH-03) bildet
  `test/test_support/veroeffentlichte_app.dart` nach:
  - `wieVeroeffentlichteApp` entfernt, was sie beim Speichern verliert
    (Slot-IDs, `slotRef`, die Merkmalslisten `vorteilEintraege`/
    `nachteilEintraege`, unbekannte Felder in jedem verschachtelten Modell)
    und setzt unbekannte Aufzählungswerte auf ihren Ersatz,
    `zustandWieVeroeffentlichteApp` dasselbe für den Laufzeitzustand
    einschließlich unbekannter Wundzonen;
  - `zuordnungWieVeroeffentlichteApp` portiert ihre Namenszuordnung auf JSON.

  `test/domain/inventar_verweise_test.dart` prüft damit die Ladetabelle der
  Verweise, die Vorabfassung und, dass sie jede Fixture vollständig und in
  Reihenfolge zuordnet — auch nach Entfernen, Umbenennen und Hinzufügen.
  `sync_app_versionen_test.dart` prüft ihre Änderungen und ihr Echo über den
  Konto-Sync.
- **Felder einer neueren App-Version** simuliert
  `test/test_support/zukunftsfelder.dart`. `mitZukunftsfeldern` ergänzt f01
  im heutigen Format um Beispielinhalte, die die Fixture nicht belegt
  (Waffenmeisterschaft, Talentmodifikator, Meta-Talent, Zauber mit
  Overrides, Ritualkategorie, Begleiter, Abenteuerinhalte, Kontakt, Gruppe,
  Reiseberichtseintrag, Geburtsdatum, Bild, Schnappschuss, Verlaufseintrag),
  und setzt an jeder verschachtelten Ebene ein `zukunftsfeld` — 71 Stellen
  von der Ausrüstung bis zum Gesichtsbefund. Dazu schreibt es an 15
  Aufzählungsfeldern den unbekannten Wert `zukunftsWert` (nur an Stellen,
  die kein Abgleich neu setzt, also am manuellen Inventareintrag).
  `zustandMitZukunftsfeldern` macht dasselbe für den Laufzeitzustand
  (Modifikatoren, Zaubereffekt samt Dauer, Wunden, Würfelprotokoll; dazu
  vier Aufzählungswerte bzw. die Wundzone `zukunftsZone`).
  `istZukunftsWertPfad` unterscheidet beide Pfadarten. Beide
  liefern die Pfade im Format von `jsonUnterschiede`; eine neue Fixture ist
  nicht nötig, weil das Format dasselbe bleibt. `bearbeiteVerschachtelteModelle`
  und `bearbeiteZustand` ändern je Modell ein bekanntes Feld per `copyWith`,
  wie es die Editoren tun.
  `test/domain/unbekannte_ausruestungsfelder_test.dart` und
  `test/domain/unbekannte_verschachtelte_felder_test.dart` prüfen die Modelle
  einzeln (bekannte Schlüssel, Laden, Bearbeiten, unverändertes JSON ohne
  Zukunftsfeld), dazu Altschlüssel, Sonderfälle und den Fixpunkt. Die
  Tabelle `_enumFelder` prüft je Aufzählungsfeld Ersatz, Rohwert, Fixpunkt,
  die Änderungsregel (derselbe Wert behält, ein anderer überschreibt) und
  unverändertes Verhalten bekannter, fehlender und leerer Werte; die Gruppe
  „Inventarabgleich“ hält die Befunde B12 und B13 fest. Der
  **Vollständigkeitswächter** dort setzt in jede Objektebene eines voll
  belegten Helden und Zustands sowie aller Bestandshelden einzeln ein
  Zukunftsfeld; ein künftiges Modell ohne `unbekannteFelder` fällt so ohne
  Tabellenpflege auf. Hive-Ablauf (Import überschreibend und als Kopie,
  Bearbeiten über `HeroActions`, Neustart, Export), Zwei-Geräte-Sync mit dem
  Stand einer neueren Version (auch Zustand und gleichzeitig geänderte Cloud)
  und Widgettests der Editoren (Ritual, Talentmodifikator, Begleiterangriff,
  Abenteuerblatt, Übersicht, Zaubereffekte) prüfen die Wege.
  Der Begleiterangriff-Test kontrolliert auch die Spaltenausrichtung von
  DK, AT, PA und TP mit aktiven Steigerungsbuttons; Layoutfehler werden
  dabei nicht unterdrückt.
- **Gegenproben**: Jeder dieser Tests scheitert ohne den Fix. Nachgewiesen
  wird das, indem man die Editor-Dateien einzeln per `git stash` zurücksetzt
  oder `sammleUnbekannteFelder` vorübergehend eine leere Map liefern lässt.
  Für Aufzählungen entsprechend: `leseEnumWert` merkt den Rohwert nicht,
  `WundZustand.fromJson` verwirft unbekannte Zonen, `ohneGeaenderteEnumWerte`
  löscht nie bzw. immer, oder B12/B13 werden einzeln zurückgenommen.
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

### Abbruch und Wiederanlauf (ARCH-06)

`test/ablaeufe/vorgaenge_wiederaufnehmen_test.dart` simuliert einen Absturz
als Schritt, der nie fertig wird (`Completer<void>().future`): Der Import läuft
nicht abgewartet bis dorthin (`pumpEventQueue`), danach nimmt ein **neues**
`FakeRepository` auf denselben Listen den Vorgang wieder auf. Ein neues
Repository ist nötig, weil die Warteschlange je Held am Speicherobjekt hängt
und der hängende Schritt sie sonst blockierte. Dasselbe Muster mit zwei
Geräten und echtem Journal steht in `test/data/sync_speichervertrag_test.dart`.

### Zwei Geräte am Konto-Sync

`test/data/sync_zwei_geraete_test.dart` hängt zwei `SyncingHeroRepository`
an eine gemeinsame In-Memory-Cloud (`test/test_support/sync_geraete.dart`):

- `GeteilteCloud` zählt Schreibvorgänge je Held und Zustand — so lässt sich
  „die Wiederholung bucht nichts doppelt“ nachweisen.
- `GeraeteRemote` ist die Leitung eines Geräts: `offline`,
  `schreibvorgaengeBisAbbruch` (Abbruch mitten im Abgleich) und
  `naechsteAntwortVerlieren` (Schreibvorgang kommt an, Antwort nicht). Nutzdaten
  gehen wie bei Firestore als JSON über die Leitung.
- `JsonHeroRepository` speichert lokal wie Hive nur JSON; `FakeRepository`
  gäbe dieselbe Objektinstanz zurück und verdeckte Effekte des Ladens.
- `SyncTestGeraet.neustart()` baut das Repository neu, Speicher und
  Metadaten bleiben.
- `SyncingHeroRepository.saveHeroState` endet nach dem **lokalen** Speichern,
  der Upload läuft gebündelt im Hintergrund. Ein Test, der danach die Cloud
  prüft oder die Leitung umschaltet („offline gespeichert, dann online“),
  wartet vorher mit `warteAufUebertragungen()`, sonst läuft der Upload erst
  nach dem Umschalten.

Das Cloud-Fake (`fake_remote_hero_sync_gateway.dart`) hasht wie die echten
Gateways mit `heroContentHash` und prüft auch bei Zuständen die Vorrevision.
Mit dem früheren Hash inklusive `lastModified` wäre jede Runde ein Upload
gewesen.

Weil das Fake mit dem Hash dieser App rechnet, sieht es nie einen Stand, den
die App nicht verlustfrei darstellt. Dafür gibt es
`speichereFremdenStand`/`speichereFremdenZustand`: Sie legen JSON einer
**anderen App-Version** ab und rechnen den Hash wie Firestore über das rohe
JSON des Schreibers. Gelesen wird aber mit dem `fromJson` dieser App.
`GeteilteCloud` zählt diese Schreibvorgänge mit.
`test/data/sync_app_versionen_test.dart` prüft damit Befund B10: kein
Rückschrieb beim bloßen Abgleich, Konflikt statt Überschreiben, eine vor B10
gemerkte Basis und einen Zustand mit neuerer Schemaversion. Mit
`mitZukunftsfeldern` prüft er außerdem Felder einer neueren Version in der
Ausrüstung: verlustfrei darstellbar, Bearbeiten über `HeroActions` mit echtem
Katalog, gleichzeitig geänderte Cloud mit sichtbarem Feld im Konflikt-Diff
und alle drei Auflösungen.

### Web-CI und Plattformabdeckung

PRs nach `test`/`main` und Pushes auf diese Branches prüfen Formatierung, Analyse,
Tests, LOC-Budget und Web-Release-Build. Nur erfolgreiche Push-Läufe
veröffentlichen das geprüfte Artefakt. Android-Builds und automatische
Branch-Previews entfallen. Automatische Main-Test-Merges rufen dieselbe CI
mit dem exakten Test-Commit auf. Siehe [Web-Veröffentlichung](web_deployment.md).

Die CI (`.github/workflows/flutter-tests.yml`) führt alle Tests auf
`ubuntu-latest` aus, die Hive-Tests also mit echtem Dateisystem. Automatisch
**nicht** abgedeckt sind und bleiben manuell zu prüfen:

- Web: Hive auf IndexedDB, Avatar-Cache, Datei-Upload im Regel-Nachschlag;
- Android, iOS und Windows mit ihren echten Speicherpfaden;
- Dateiauswahl für Import und Export (`file_picker`);
- Konto-Sync gegen ein echtes Firebase-Backend, nativ und über REST
  (Windows), einschließlich Storage-CORS.

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
| `test/rules/bestandshelden_regelwerte_test.dart` | rules | Abgeleitete Werte der Bestandsfixtures gegen den echten Katalog, Zonenwunden (f01 Schildarm samt Linkshänder-Variante, f04 Brustwunde), epische Halbierung der SB-Erschwernis, Befunde B1/B7 |
| `test/rules/wund_zonen_rules_test.dart` | rules | Wunden nach Gesamt- und Zonensystem je Zone, Armrollen, dritte Wunde, Unterdrückung, Probenwerte, GS-Grenze, Anzeige |
| `test/rules/wund_arm_kampf_test.dart` | rules | Armwunden in der Kampfvorschau (Schwert-/Schildarm, Linkshänder, Nebenhand, Fernkampf, Parierwaffe), keine Wirkung auf abgeleitete Werte |
| `test/ui/workspace/wunden_dialog_test.dart` | ui | Wundendialog (Zusammenfassung, Armrollen), SB-Probe gegen Probenwerte, epische Halbierung, Schnellsuche mit gesenkten Werten |
| `test/rules/bestandshelden_ausruestung_test.dart` | rules | Inventar-Kampf-Abgleich mit gleichnamigen Exemplaren, Befunde B2/B3, Felder neuerer Versionen im Abgleich |
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
| `test/data/bestandsheld_ablauf_test.dart` | data | Echte Hive-Speichergrenze je Bestandsheld und Ablauf Import bis Export mit Neustart, Befunde B4/B9, Felder neuerer Versionen in allen verschachtelten Modellen von Held und Zustand |
| `test/data/sync_zwei_geraete_test.dart` | data | Zwei Geräte an einer Cloud: Abbruch, verlorene Antwort, Neustart (auch mit Hive), Konfliktauflösungen samt Zustand, Befunde B1/B8 |
| `test/data/zustand_schnell_tippen_sync_test.dart` | data | Schnelles Tippen mit Konto-Sync gegen eine verzögerte Cloud mit Echo: jeder Klick zählt, lokal ohne Wartezeit, gebündelte Uploads, kein Konflikt mit sich selbst, offline nachgeholt, fremde Änderung übernommen bzw. als Konflikt gemeldet |
| `test/data/sync/gebuendelte_laeufe_test.dart` | data | Bündelung der Zustands-Uploads: ein Folgelauf, unabhängige Schlüssel, Fehler, `nachLauf` |
| `test/data/sync_app_versionen_test.dart` | data | Sync mit anderen App-Versionen: Basis gleich lokaler Stand (B10), Felder einer neueren Version in Held und Zustand samt gleichzeitig geänderter Cloud, veröffentlichte App im Mischbetrieb (auch ihr Echo), geänderter Vor-/Nachteiltext mit und ohne bewahrte Liste (ARCH-02) |
| `test/data/merkmal_migration_test.dart` | data | ARCH-02: einmalige Migration der Vor-/Nachteiltexte beim Speichern mit echtem Hive, Fixpunkt, gleiche Regelwerte, Export/Import |
| `test/rules/hero_merkmal_rules_test.dart` | rules | ARCH-02: Zuordnung der Alttexte, Abweichungen, Hinzufügen, Wirkung über die Katalog-ID, Umbenennung, Äquivalenz von Katalog- und Textweg |
| `test/catalog/trait_effect_catalog_test.dart` | catalog | Deklarative `wirkungen` der Vor-/Nachteile: Arten, Ziele, Vorzeichen, Vollständigkeit |
| `test/domain/hero_sheet_model_test.dart` | domain | HeroSheet-Kompatibilitaet |
| `test/domain/hero_transfer_bundle_test.dart` | domain | Transfer-Bundle-Kontrakt |
| `test/domain/bestandshelden_kompatibilitaet_test.dart` | domain | Bestandsfixtures: Fixpunkt nach einmaligem Laden, Inhalts-Hashes, Altschlüssel, Befunde B1/B5/B6 |
| `test/domain/unbekannte_ausruestungsfelder_test.dart` | domain | Unbekannte Felder in den zehn Ausrüstungsmodellen, Altschlüssel, Katalogschutz, Fixpunkt mit f01 |
| `test/domain/unbekannte_verschachtelte_felder_test.dart` | domain | Unbekannte Felder in allen übrigen Modellen von Held und Zustand, unbekannte Aufzählungswerte und Wundzonen, Befunde B12/B13, Altschlüssel, Sonderfälle, Vollständigkeitswächter über jede Objektebene |
| `test/domain/inventar_verweise_test.dart` | domain | Ladetabelle `sourceRef`/`slotRef`, Vorabfassung, Mischbetrieb mit der veröffentlichten App |
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
