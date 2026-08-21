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
- Erwerbsvoraussetzungen liegen zusätzlich zum Freitext `voraussetzungen` als
  maschinenlesbarer Block `voraussetzungen_struktur` im Katalog
  (`lib/catalog/special_ability_requirement.dart`, Schema in
  `docs/technical_overview.md` Abschnitt 4.9). Gepflegt für magische,
  allgemeine und Kampf-Sonderfertigkeiten; karmale fehlen bewusst, weil
  Liturgiekenntnis, Gottheit und Entrückung im `HeroSheet` kein Gegenstück
  haben. Geprüft wird über `buildHeroRequirementContext` und
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
- Laufende Zaubereffekte (`Axxeleratus`, `Attributo`, `Armatrutz`) stehen in
  `lib/rules/derived/active_spell_rules.dart` und werden über
  `Magie-Tab > Zauber aktivieren` gepflegt. Zusatzdaten je Effekt (Zahlenwert
  und Wirkungsdauer) liegen in `HeroState.activeSpellEffects.effectDetails`.
  Der `Armatrutz` addiert seinen erzauberten RS in
  `lib/rules/derived/armatrutz_rules.dart` zur getragenen Rüstung, ohne
  Behinderung zu erzeugen; bei abgelaufener Wirkungsdauer fällt der Bonus weg.
  Die Wirkungsdauer selbst (`lib/domain/spell_duration.dart`,
  `lib/rules/derived/spell_duration_rules.dart`) ist effektunabhängig:
  Kampfrunden, Spielrunden und weitere Zeiteinheiten werden nie ineinander
  umgerechnet, der Countdown bleibt manuell, und abgelaufene Effekte werden
  nur angezeigt statt automatisch abgeschaltet.
- Traditionen und Leiteigenschaften stehen in
  `lib/rules/derived/tradition_rules.dart` (Wege der Zauberei S. 19). Die
  Traditionen eines Helden sind die Vereinigung aus `representationen` und den
  Namen seiner Ritualkategorien — Derwische, Zibiljas, Zaubertänzer und
  Schamanen haben laut Regelwerk keine Repräsentation, wären über sie also nie
  erreichbar. Trägt eine Repräsentation mehrere Traditionen (nur `Geo`: Herr
  der Erde → KL, Diener Sumus → IN), hält
  `HeroSheet.repraesentationsTraditionen` die Wahl fest;
  `HeroSheet.magicLeadAttribute` ist nur noch die bewusste Abweichung davon.
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
- Entscheidungen zu Offline-Helden (`Offline-Held: …`-Konflikte beim Wechsel in
  ein Konto) müssen persistiert werden, sonst wiederholt sich die Frage bei
  jedem Start: die Konfliktliste lebt nur im Speicher und keiner der drei
  Auflösungswege verändert das Offline-Profil. `SyncingHeroRepository` schreibt
  dafür ein `OfflineHeroReview` in die Box `offline_hero_review_v1` im
  Konto-Profil (`lib/data/hive_offline_hero_review_store.dart`). Der Offline-Held
  selbst wird nie gelöscht. Widerrufbar unter
  `Einstellungen > Konto & Sync > Offline-Helden`.
- Avatar-Bilddateien synchronisiert der Konto-Sync **nicht** mit: sein Payload
  ist `HeroSheet.toJson()` und trägt nur Dateinamen. Die Bytes wandern über
  Firebase Storage (`avatars/{uid}/{fileName}`). `SyncingAvatarStorage`
  (`lib/data/syncing_avatar_storage.dart`) legt sich dafür um die
  plattformspezifische `AvatarFileStorage`: schreiben local-first mit
  Best-Effort-Upload, lesen mit Cloud-Fallback samt lokalem Cachen. Ob der
  Decorator greift, entscheidet `AvatarFileStorage.isCloudBacked` — im Web ist
  die Plattformimplementierung selbst der Cloud-Speicher, dort wäre er ein
  doppelter Weg. Löschen betrifft immer beide Seiten und alle Quellen; die
  frühere Sonderbehandlung von `quelle == 'ki'` gibt es nicht mehr.
- Bestandsbilder holt `AvatarBackfillService`
  (`lib/data/avatar_backfill_service.dart`) nach, angestoßen in
  `AppStartupGate` **nach** `syncNow()` und ohne `await`. Die Reihenfolge ist
  korrektheitsrelevant: vor dem Sync wäre die lokale Galerie veraltet, und ein
  auf einem anderen Gerät gelöschtes Bild käme wieder hoch. Der Service darf
  **nie** `saveHero()` aufrufen — das änderte `lastModified` und löste bei
  jedem Start eine Konfliktwelle aus. Abgeglichene Dateien vermerkt die Box
  `avatar_sync_v1` (`lib/data/hive_avatar_sync_marker_store.dart`); sie liegt
  im Kontoprofil, weil der `avatare`-Ordner bewusst profilübergreifend geteilt
  bleibt (eine Umstellung auf `accounts/<uid>/avatare/` würde jeden
  Bestandsavatar unsichtbar machen).
- Dateinamen dürfen nie aus `heroId` und `entryId` rekonstruiert werden:
  Bestandshelden tragen den Legacy-Eintrag `{heroId}_legacy` mit dem Dateinamen
  `{heroId}.png`, der dabei verlorenginge. Maßgeblich ist immer
  `AvatarGalleryEntry.fileName`.
- Ob ein Held ein Bild hat, beantwortet `HeroAppearance.hatBild`, welches
  angezeigt wird `HeroAppearance.aktivesBild`. `avatarFileName` bleibt als
  Bestandsfeld im Modell (Entfernen erzeugte auf jedem Gerät einen Helden-Diff
  und damit Konflikte), wird aber nicht mehr gelesen. Bilder rendert
  ausschließlich `AvatarGalleryImage`
  (`lib/ui/widgets/avatar_gallery_image.dart`) über `avatarBytesProvider`. Die
  Bytes sind `Uint8List` und müssen unverändert an `Image.memory` gereicht
  werden — ein `Uint8List.fromList(...)` im Widget verfehlt den globalen
  `ImageCache` bei jedem Rebuild, weil `MemoryImage` seine Bytes per Identität
  vergleicht.
- Ein fehlgeschlagener Bildzugriff darf nie stumm als „kein Bild" erscheinen.
  `AvatarLoadException` (`lib/data/avatar_load_failure.dart`) trägt den Grund
  (nicht angemeldet, keine Berechtigung, zu groß, Netzwerk, unbekannt);
  `AvatarGalleryImage` zeigt Laden, Fehlen und Fehlschlag als drei getrennte
  Zustände. Nur echtes `object-not-found` liefert weiterhin `null`. Wichtig für
  Web: `firebase_storage_web` lädt die Bytes nicht über das JS-SDK, sondern per
  `getMetadata()` → `getDownloadURL()` → `http.readBytes`, und `guard()` reicht
  alles außer Firebase-Fehlern unverändert durch — ein reines
  `on FirebaseException` verpasst deshalb Netzwerk- und Typfehler.
- Die Web-App läuft bewusst auch ohne Login (`WebAuthGate` reicht `null` durch).
  Ohne Konto gibt es keinen Cloud-Pfad und damit keine Avatarbilder.
- Beim lokalen Web-Debuggen ist `flutter run -d chrome --web-port=5000`
  **Pflicht**, nicht Komfort: Firebase Auth und Hive persistieren pro Origin,
  und die CORS-Regel des Storage-Buckets nennt genau diesen Port. Ein
  zufälliger Port bedeutet abgemeldete Sitzung, leeren Speicher **und**
  blockierte Bilder.
- Der Storage-Bucket braucht eine **CORS-Konfiguration**, sonst sind Avatare im
  Web unsichtbar. `firebase_storage_web.getData()` lädt die Bytes per
  `http.readBytes` von der Download-URL — ein normaler Browser-Fetch. Diese
  Antwort trägt ohne Bucket-Konfiguration kein `Access-Control-Allow-Origin`,
  der Browser verwirft sie, und es kommt nur `ClientException: Failed to fetch`
  an. Achtung bei der Diagnose: Eine `OPTIONS`-Anfrage auf dieselbe URL
  antwortet mit `Access-Control-Allow-Origin: *` (Upload-Server) und führt in
  die Irre — geprüft werden muss der **GET**. Die Konfiguration liegt als
  `cors.json` im Repo und wird **nicht** von `firebase deploy` übertragen,
  sondern mit
  `gsutil cors set cors.json gs://heldensync-ccf0b.firebasestorage.app`
  (z. B. in der Google Cloud Shell). Neue Origins müssen dort ergänzt werden;
  GCS erlaubt keine Wildcard innerhalb einer Origin.
- Im Web liegen geladene Avatarbytes zusätzlich in der Hive-Box
  `avatar_blobs_v1` (IndexedDB, `lib/data/hive_avatar_blob_cache.dart`), damit
  ein Reload sie nicht erneut herunterlädt. Der Cache ist inhaltsadressiert und
  kann nicht veralten, weil `AvatarGalleryEntry.fileName` eine UUID trägt;
  aufzuräumen sind nur verwaiste Einträge, das erledigt
  `AvatarCacheReconciler` beim Start nach `syncNow()`. Bewusst **kein**
  `SyncingAvatarStorage` im Web: dort gilt der lokale Write als Erfolg, aber
  IndexedDB ist kein haltbarer Speicher — im Browser zählt ein Bild erst als
  gespeichert, wenn der Upload durch ist.
- Inhaltlich identische Datensätze sind aber kein Konflikt: `isSyncContentIdentical`
  (`lib/domain/sync_object_diff.dart`) entscheidet das mit derselben Logik wie
  die Konflikt-UI (umsortierte Listen, `lastModified`/`schemaVersion` zählen als
  gleich); in dem Fall übernimmt die App die Online-Version und überspringt den
  Datensatz. Nur echte Unterschiede erzeugen einen Konflikt und werden als
  Tabelle `Feld | Online | Lokal` gezeigt
  (`lib/ui/widgets/sync_conflict_comparison_table.dart` mit den deutschen
  Feldnamen aus `lib/ui/widgets/sync_conflict_field_labels.dart`), sowohl im
  Start-Gate als auch unter `Einstellungen > Konto & Sync`.
- Laufzeitzustände (`HeroState`) tragen wie `HeroSheet` ein `lastModified`,
  damit die Konflikt-UI beim `Zustand:`-Konflikt nicht auf beiden Seiten
  `Unbekannt` anzeigt. Gehasht wird ein Zustand ausschließlich über
  `heroStateContentHash` (`lib/domain/sync_models.dart`), das den Zeitstempel
  entfernt — genau wie `heroContentHash`. Wer irgendwo `stableContentHash`
  direkt auf `state.toJson()` anwendet, baut einen Scheinkonflikt bei jedem
  Speichern ein.
- `FirebaseBootstrapResult.isAccountSyncAvailable` steuert den privaten
  Konto-Sync; `isFirestoreAvailable` steht für native Firestore-Funktionen wie
  Gruppen-Cloudaktionen und bleibt auf Windows deaktiviert.
- Der Settings-Bereich `Rechtliches` enthaelt den inoffiziellen Fanprojekt-,
  Marken- und Rechtehinweis fuer DSA und Ulisses Spiele.
- Epische Helden waehlen je eine geistige und eine koerperliche
  Haupteigenschaft (`HeroSheet.epicMainAttributes`). Sie definieren die Boni
  aus Kap. 2.1 und sind vom 25-%-AP-Aufschlag ausgenommen
  (`isEpicMainAttribute` in `lib/rules/derived/epic_main_attribute_rules.dart`,
  Parameter `isMainAttribute` in `epic_ap_cost_rules.dart`). Der
  `EpicActivationDialog` hat dafuer einen Korrekturmodus; Einstieg ist das
  Stern-Symbol der Sektion `AP und Level`.
- Die Haupteigenschafts-Boni aus Kap. 2.1 liegen als
  `epicMainAttributeBonuses` mit `EpicBonusUmsetzung` je Einzelbonus vor.
  Gerechnet werden nur zwei: eBE-Halbierung bei KK-Talenten
  (`epicTalentEbeMultiplier` → `computeTalentEbe`) und die halbierte
  Wund-Proben-Erschwernis bei KO (`computeWundEffekte`). Die IN-Finte
  erscheint als Hinweis in der Kampfvorschau (Muster:
  `buildAxxeleratusDefenseHint`). Alle uebrigen Boni sind in der UI
  ausdruecklich als `manuell` gekennzeichnet — mangels Modell fuer
  Tragkraft, Gift, Krankheit, Handwerk und gezieltes Ausweichen.
- `AppSettings.tabellenAnsicht` (`automatisch`, `tabelle`, `karten`)
  ueberstimmt die Breiten-Automatik von `ResponsiveAdaptiveTable`. Ohne diese
  Einstellung weichen breite Tabellen auf Tablet-Breiten zwingend auf Karten
  aus. Bedienbar im Talente-Tab und unter `Einstellungen > Darstellung`.
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
- Zusaetzlich zum manuellen Weg (lokal bauen bzw. Web-Upload) kann die
  Index-DB per Server-Sync bezogen werden (`lib/domain/rules_index_remote_config.dart`,
  `lib/data/rules_search/rules_index_remote_client.dart`,
  `lib/data/rules_search/rules_index_sync_service.dart`; Desktop-Cache-Pfad
  `index_remote.sqlite` in `rules_index_search_io.dart`, UI in
  `_RulesIndexServerCard` (`settings_pages.dart`) und im
  Regel-Nachschlag-Dialog). Die Datei bleibt unverschluesselt; das Download-
  Feature ist stattdessen hinter dem bestehenden Katalog-Entschluesselungs-
  passwort gated (kein zweites Passwort). Details und der bewusste
  Schutz-Trade-off stehen in `docs/spielmodus_konzept.md` Abschnitt 6.

## Pflegehinweis

Schnell veraltende Details gehoeren nicht in diese Datei. Wenn sich Architektur, Workflows oder Fachlogik aendern, aktualisiere stattdessen die passende Datei in `README.md` oder unter `docs/`.
