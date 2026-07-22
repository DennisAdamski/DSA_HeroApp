# CLAUDE.md - DSA Heldenverwaltung

Kurze Einstiegsdatei fuer neue Sessions. Diese Datei bleibt absichtlich klein und enthaelt nur stabile Hinweise.

## Zuerst lesen

- `AGENTS.md` ist die verbindliche Agentenrichtlinie.
- `README.md` beschreibt Produktumfang, Architekturueberblick und Standard-Workflows.
- Detaildokumentation liegt bei Bedarf in `docs/technical_overview.md`, `docs/test_strategy.md`, `docs/catalog_import_workflow.md`, `docs/pdf_agent_workflow.md`, `docs/rule_audit_regelwerk_ueberarbeitung.md`, `docs/ios_xcode_setup.md` und `docs/windows_antivirus_audit.md`.

## Projektkontext

- `dsa_heldenverwaltung` ist eine Flutter-App zur Verwaltung von DSA-Helden.
- Die App nutzt lokale Persistenz, katalogbasierte Inhalte und getrennte Regellogik.
- Regellogik gehoert nach `lib/rules/derived/`.
- Aventurische Waehrungsumrechnung fuer Dukaten/Silber/Kreuzer liegt in
  `lib/rules/derived/currency_rules.dart`.
- Die kanonische Katalogquelle bleibt `assets/catalogs/house_rules_v1/`.
- Vor- und Nachteile liegen dort katalogisiert in `vorteile.json` und
  `nachteile.json`; die Heldenübersicht speichert Auswahlen weiterhin
  kompatibel in `HeroSheet.vorteileText` und `HeroSheet.nachteileText`.
- Aktivierbare Hausregel-Pakete liegen eingebaut unter
  `assets/catalogs/house_rules_v1/packs/<packId>/manifest.json`.
- Eingebaute Pack-Manifeste muessen ausserdem explizit in `pubspec.yaml`
  als Flutter-Assets registriert sein, damit der Settings-Screen sie laden kann.
- Importierte Hausregel-Pakete liegen im Heldenspeicher unter
  `house_rule_packs/<version>/<packId>/manifest.json`.
- Die App besitzt dafuer eine eigene In-App-Verwaltung unter
  `Einstellungen > Hausregeln > Hausregelverwaltung`.
- Die adaptive Settings-Navigation wird von `lib/ui/screens/settings_screen.dart`
  orchestriert; wiederverwendbare Teilseiten liegen unter
  `lib/ui/screens/settings/`.
- `Einstellungen > Konto & Sync` steuert optionalen Firebase-Login,
  manuellen Konto-Sync und Konfliktaufloesung. Ohne Login nutzt die App das
  lokale Offline-Profil; mit Login nutzt sie ein getrenntes Profil unter
  `Helden/accounts/<uid>`.
- Konto-Sync für Helden läuft über `SyncingHeroRepository`, ein
  plattformspezifisches Remote-Gateway (`FirestoreHeroSyncGateway`, auf Windows
  `RestFirestoreHeroSyncGateway`), `HiveSyncMetadataStore` und die Modelle in
  `lib/domain/sync_models.dart`. Konflikte dürfen nicht still überschrieben
  werden; die UI muss lokal, online oder beide behalten anbieten.
- `FirebaseBootstrapResult.isAccountSyncAvailable` steuert den privaten
  Konto-Sync; `isFirestoreAvailable` steht für native Firestore-Funktionen wie
  Gruppen-Cloudaktionen und bleibt auf Windows deaktiviert.
- Der Settings-Bereich `Rechtliches` enthaelt den inoffiziellen Fanprojekt-,
  Marken- und Rechtehinweis fuer DSA und Ulisses Spiele.
- Reisebericht-Daten bleiben separat unter `assets/catalogs/reiseberichte/house_rules_v1/`.
- Geschuetzte Katalog-Felder (Wirkung/Varianten von Zaubern, Erklaerungstexte
  von Manoevern und Kampf-Sonderfertigkeiten) sind v3-verschluesselt
  (AES-GCM, globaler Salt im Manifest `catalog_salt_v3`). Beim Unlock
  entschluesselt `decryptedCatalogSourceDataProvider` den ganzen Katalog
  einmal — Detail in `docs/technical_overview.md` Abschnitt 5.3. Passwoerter
  werden vor PBKDF2 NFC-normalisiert, damit Eingaben mit Umlauten
  unabhaengig von NFC/NFD-Codepoint-Repraesentation funktionieren.
- Projektsprache ist Deutsch; sichtbare UI-Texte sollen echte Umlaute und das Eszett verwenden, wenn technisch moeglich.
- ListTile-/SwitchListTile-Kacheln in farbig dekorierten Panels sollen ueber
  `lib/ui/widgets/list_tile_material.dart` einen lokalen Material-Layer
  erhalten, damit Flutter-3.44-Ink- und Tile-Hintergruende sichtbar bleiben.
- Der Windows-Release-Audit fuer EXE/MSIX-Artefakte ist in `docs/windows_antivirus_audit.md` beschrieben; der zugehoerige Helfer liegt unter `tool/audit_windows_artifact.ps1`.
- Spielunterstuetzung ("Spielmodus") ist in `docs/spielmodus_konzept.md` konzipiert.
  Phase 1 umfasst die tab-unabhaengige Proben-Schnellsuche
  (`lib/ui/screens/workspace/probe_quick_search.dart`), Filter-Chips im
  Wuerfelprotokoll und den Regel-Nachschlag. Der Nachschlag liest die vom
  dsa-rules MCP-Indexer erzeugte SQLite-DB read-only per FTS5 und ist auf
  Desktop und Web sichtbar (Mobile blendet den Einstieg weiterhin aus).
  Implementierung unter `lib/data/rules_search/` (Conditional-Import-Fassade
  `rules_index_search.dart` mit IO-/Web-/Stub-Variante, plattformneutrale
  Typen in `rules_index_types.dart`), UI in
  `lib/ui/screens/workspace/rules_lookup_dialog.dart`. Desktop liest die
  Datenbank direkt vom lokalen Standardpfad (`rules_index_search_io.dart`);
  Web hat keinen Dateisystemzugriff und nutzt stattdessen `package:sqlite3`
  im WASM-Modus (`rules_index_search_web.dart`, Binärdatei `web/sqlite3.wasm`)
  mit `IndexedDbFileSystem`-Persistenz — der Nutzer laedt die am Desktop
  erzeugte `index.sqlite` einmalig ueber einen Datei-Upload im Dialog hoch;
  sie bleibt danach origin-gebunden im Browser gespeichert.
  `web/sqlite3.wasm` ist eine eingecheckte Binaerdatei, kein Build-Artefakt:
  das `sqlite3`-Package liefert auf pub.dev nur C-Quellen fuer den WASM-Build
  (`assets/wasm/` im Package), keine fertige `.wasm`. Bei einem Versionswechsel
  von `sqlite3` in `pubspec.yaml` muss `web/sqlite3.wasm` manuell gegen die
  passende `sqlite3.wasm` aus den GitHub-Releases von
  github.com/simolus3/sqlite3.dart (Tag zur Package-Version) ersetzt werden.

## Pflegehinweis

Schnell veraltende Details gehoeren nicht in diese Datei. Wenn sich Architektur, Workflows oder Fachlogik aendern, aktualisiere stattdessen die passende Datei in `README.md` oder unter `docs/`.
