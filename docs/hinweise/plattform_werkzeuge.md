# Plattform, Werkzeuge, Feedback und Spielmodus

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Web-Interop laeuft ueber `package:web` + `dart:js_interop`, nie ueber
  `dart:html` (deprecated und von `dart2wasm` nicht uebersetzbar). Bedingte
  Importe muessen auf `dart.library.js_interop` stehen, **nicht** auf
  `dart.library.html`: unter dart2wasm ist letzteres `false`, ein Wasm-Build
  zoege dann stillschweigend die Stub-Implementierung. Der Web-Download liegt
  gemeinsam in `lib/data/web_download.dart`.
- `flutter analyze` bricht auch bei `info`-Lints ab, die CI faellt also
  darauf. Die Sprachversion aus `environment: sdk:` steuert mit, welche Lints
  ueberhaupt feuern und wie breit `dart format` umbricht — ein SDK-Bump zieht
  beides nach sich.
- Der Windows-Release-Audit fuer EXE/MSIX-Artefakte ist in `docs/windows_antivirus_audit.md` beschrieben; der zugehoerige Helfer liegt unter `tool/audit_windows_artifact.ps1`.
- Direktes App-Feedback als GitHub-Issue ist lokal implementiert und in
  [docs/feedback_github_plan.md](../feedback_github_plan.md) sowie
  [docs/feedback_betrieb.md](../feedback_betrieb.md) dokumentiert. Gemeinsame
  UI liegt unter `lib/ui_shared/feedback/`, der typisierte Vertrag unter
  `lib/domain/feedback/` und die Gen-2-Functions unter `functions/`. Feedback
  erfordert die bestehende App-Anmeldung; ein GitHub-Konto des Nutzers ist
  nicht erforderlich. Deployment, Secret und echtes Staging-Issue bleiben
  getrennte Freigabeschritte.
- Spielunterstuetzung ("Spielmodus") ist in `docs/spielmodus_konzept.md` konzipiert.
  Phase 1 umfasst die tab-unabhaengige Proben-Schnellsuche
  (`lib/ui/screens/workspace/probe_quick_search.dart`), Filter-Chips im
  Wuerfelprotokoll und den Regel-Nachschlag. Der Nachschlag liest die vom
  dsa-rules MCP-Indexer erzeugte SQLite-DB read-only per FTS5 und ist auf
  Desktop und Web sichtbar (Mobile blendet den Einstieg weiterhin aus). Einstiege
  sind der Verwalten-Kopf und, über die Brücke `KartoBestandsAdapter`, die
  Schnellaktionen der UI2-Spielansicht (Key `karto-spiel-regeln`).
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
  github.com/simolus3/sqlite3.dart ersetzt werden — Tag `sqlite3-<version>`,
  aktuell `sqlite3-3.7.1`. Ein Versatz zwischen Package und `.wasm` faellt
  **nicht** beim Kompilieren auf, sondern erst zur Laufzeit im Browser.
- Die nativen SQLite-Bibliotheken fuer Desktop und Mobile liefert seit
  `sqlite3` 3.x dessen eigener Build-Hook, der SQLite direkt mit der App
  buendelt (unter Windows erscheint es als `sqlite3.dll` im Release-Ordner).
  Das frueher noetige `sqlite3_flutter_libs` ist entfallen: es ist mit
  `0.6.0+eol` end-of-life und enthaelt keinen Code mehr. Beide Pakete
  duerfen nur gemeinsam bewegt werden — ein isolierter Bump von
  `sqlite3_flutter_libs` liesse Desktop und Mobile ohne native Bibliothek
  zurueck. Aus demselben Grund gibt es keinen `open.overrideFor`-Aufruf
  mehr; das Laden uebernimmt vollstaendig der Hook.
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
  **Leerzustand (SPIEL-04):** ohne Index zeigt der Dialog einen gemeinsamen
  Hinweis (`_buildNotice`). Der Server-Download steht als Hauptweg bereit,
  sobald `RulesIndexRemoteConfig.isConfigured` gilt, sonst nennt der Hinweis
  ehrlich, dass kein Regel-Server eingerichtet ist. Auf Web gibt es zusaetzlich
  den Datei-Upload; scheitert der Browser-Download am Netz (meist fehlende
  CORS-Freigabe des Servers), verweist die Fehlermeldung auf den Upload. Die
  Suchansicht zeigt `Vom Server geladen am <Datum>` (`lastSyncedAt`) und
  den Server-Aktualisieren-Knopf auch auf Web. Testnaht: `oeffneIndex` und
  `syncService` am Dialog; `flutter test` laeuft sonst gegen die lokale
  Entwickler-Datenbank. Ob der Server im Browser erreichbar ist (CORS), ist
  **nicht geprueft**.
  **Cloud-Weg (SPIEL-04):** Builds mit `RULES_INDEX_API_URL` laden die
  Wissensbasis ueber die Cloud Function `rulesIndexApi`
  (`functions/src/rules_index/api.ts`, Betrieb in
  [mcp_dsa_rules.md](../mcp_dsa_rules.md)). Der Regelnachschlag wird in allen
  drei Einstiegen (Spielansicht, `workspace_management_body.dart`,
  `hero_workspace_screen.dart`) erst nach dem Entsperren
  (`catalogContentVisibleProvider`) angeboten. `rulesIndexAutoStartProvider`
  (beobachtet in `AppRootSwitch`) startet das Laden im Hintergrund, sobald
  Passwort, Anmeldung, Katalog-Salt und Einstellungen da sind; es laeuft nur,
  wenn die Wissensbasis fehlt oder `rulesIndexRefreshInterval` (14 Tage)
  ueberschritten ist, und hoechstens einmal je Sitzung (`autoStart`). Manuell:
  `RulesIndexAutoSync.start` ueber die Knoepfe im Dialog. Ablauf in
  `RulesIndexSyncService.syncFromCloud`: Passwortnachweis (PBKDF2 per `compute`),
  Zugang, Download der signierten URL (`downloadSigned`, ohne Zugangsdaten),
  bei Bedarf Entpacken (`gunzipIfNeeded`, Web verlaesst sich auf
  `Content-Encoding: gzip`), Pruefung von Groesse und SHA-256, erst dann Import.
  Die installierte Version steht in `RulesIndexRemoteConfig.installedVersion`.
  Der Dialog zeigt Fortschritt, Fehler (nie still) und oeffnet die Suche selbst,
  sobald `RulesIndexSyncState.revision` steigt. Der NAS-Weg bleibt fuer Builds
  ohne Cloud-URL bestehen. **Nicht geprueft:** der echte Lauf gegen Firebase
  (Deploy, Secret, Signierrecht) und das Entpacken im Browser.
- Das Kurzregel-Kompendium (SPIEL-04, Option C) liefert eigene Kurzfassungen
  häufiger Regeln als verschlüsseltes Asset `kurzregeln.json` (67 Einträge,
  jeder mit Buch- und Seitenbeleg). Es ist der Standardreiter „Kurzregeln“ des
  Regel-Nachschlags (`RegelnNachschlagDialog`) und läuft offline auf allen
  Plattformen; der Einstieg erscheint daher auch auf Mobil
  (`isRulesLookupSupported()` ist immer wahr, nur der Reiter „Wissensbasis“
  hängt an `rulesIndexSearchSupported()`) und weiter erst nach dem Entsperren.
  Hausregeln stehen getrennt von der offiziellen Regel. Aufbau,
  Redaktionsablauf und Seitenversatz der Belege:
  [kurzregeln_redaktion.md](../kurzregeln_redaktion.md).
