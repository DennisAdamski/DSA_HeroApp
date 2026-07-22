# Konzept: Spielunterstützung („Spielmodus")

Stand: 2026-07-12 · Status: Entwurf zur Abstimmung

Ziel: Die App soll während einer laufenden DSA-Session aktiv unterstützen — Proben würfeln, Kampf führen, Ressourcen pflegen und Regeln nachschlagen. Dieses Konzept baut bewusst auf dem auf, was bereits existiert, statt Neues daneben zu stellen.

## 1. Bestandsaufnahme

Bereits vorhanden und im Spiel nutzbar:

- **Probe-Engine** (`lib/domain/probe_engine.dart`, `lib/rules/derived/probe_engine_rules.dart`): Eigenschafts-, Talent-, Zauber-, AT/PA-, Ausweichen-, INI- und Schadenswürfe, digital oder manuell, inkl. Spezialisierung und situativen Modifikatoren.
- **Würfelprotokoll** (`DiceLogEntry`, max. 14 Einträge pro Held) im Inspector-Probe-Tab.
- **Inspector-Panel** im Workspace mit Probe-, Vitals-, Rast- und Magie-Tab; Tablet-Layout mit permanentem Inspector.
- **Vitalwerte & Regeneration**: LeP/AsP/KaP/Au-Stepper, Erschöpfung/Überanstrengung, Rast-Dialog mit strukturierter Regenerationslogik.
- **Wunden & Trefferzonen**: `wund_rules.dart`, `trefferzonen_rules.dart`, Wunden-Dialoge inkl. INI- und Unterdrückungslogik.
- **Kampfkonfiguration**: Waffen, Schilde, Rüstungen, Manöver, Kampfvorschau (AT/PA/TP/INI), Beidhändig-Aktionskarte.
- **Gruppe & externe Helden**: `ExternerHeld` (Visitenkarten-Niveau mit maxLep/maxAsp/maxAu/iniBase), Gruppenverwaltung, optionaler Firestore-Sync (auf Windows nur Konto-Sync, keine nativen Firestore-Gruppenaktionen).
- **dsa-rules MCP-Server** (`tool/mcp_dsa_rules/`): Hybrid-Suche (FTS5 + Embeddings) über Regelbücher/Hausregeln — aktuell nur als Entwicklungswerkzeug für Claude Code, nicht aus der App erreichbar.

Fazit: Einzelproben und Ressourcenpflege sind weitgehend abgedeckt. Die großen Lücken sind ein **rundenbasierter Kampf-Tracker über mehrere Teilnehmer** und ein **Regel-Nachschlag in der App**.

## 2. Die vier Bausteine

### 2.1 Proben & Würfeln — ausbauen, nicht neu bauen

Lücke: Im Spiel will man eine beliebige Probe würfeln, ohne erst in den richtigen Tab zu navigieren.

Vorschlag:

- **Proben-Schnellsuche** im Workspace-Header (Suchfeld/Command-Palette): tippe „Sinnenschärfe" oder „Fulminictus" → direkt der bestehende Probendialog via `probe_request_factory`. Durchsucht Eigenschaften, Talente, Zauber, Kampfaktionen des Helden.
- **Würfelprotokoll erweitern**: Limit von 14 auf sessiontauglich (z. B. 50) anheben, optional Filter nach Probeart.
- Optional später: „Zuletzt gewürfelt"-Chips für schnelle Wiederholungsproben.

Aufwand: klein. Risiko: gering, reine UI-Schicht über bestehender Engine.

### 2.2 Kampf-Tracker — der größte neue Baustein

Lücke: Es gibt keine Rundenverwaltung, keine Initiative-Reihenfolge über mehrere Teilnehmer, keinen geführten Ablauf „Schaden erhalten → SP → Wunde".

Vorschlag: neuer Workspace-Bereich **„Kampf" (Encounter)**:

- **Teilnehmer**: eigener Held (volle Werte), externe Helden aus der Gruppe (Visitenkarten-Niveau), frei angelegte Gegner (Name, INI-Basis, LeP, RS, AT/PA optional). Gegner als leichtgewichtiges neues Modell `EncounterOpponent`, optional als wiederverwendbare Vorlagen gespeichert.
- **Initiative**: INI-Wurf über die bestehende Probe-Engine (für den eigenen Helden inkl. aller Modifikatoren), manuelle Eingabe für andere; sortierte Reihenfolge, Rundenzähler, „Nächster"-Button.
- **Aktionen am Zug**: für den eigenen Helden die bestehenden AT/PA-/Manöver-Dialoge (`combat_at_pa_dialog.dart`, `combat_maneuver_dialog.dart`) direkt aus dem Tracker aufrufen; Schadenswurf → geführte Übernahme beim Ziel.
- **Schaden erhalten**: geführter Dialog TP → RS-Abzug (Zone via `trefferzonen_rules`) → SP → Wundschwelle → Wunde in `WundZustand` übernehmen, LeP/Au im `HeroState` abziehen. Alles über bestehende Regeln, nur orchestriert.
- **Effekt-Dauern**: aktive Zauber/Effekte (`ActiveSpellEffectsState`) bekommen optional eine Dauer in KR und zählen beim Rundenwechsel herunter, mit Hinweis beim Ablauf.
- **Persistenz**: laufender Kampf in eigener Hive-Box (`encounters`), damit App-Neustart mitten im Kampf unkritisch ist. Kein Cloud-Sync in der ersten Ausbaustufe (Windows-Einschränkung bei Firestore beachten).

Aufwand: mittel bis groß, aber gut schneidbar (siehe Phasen). Regellogik gehört nach `lib/rules/derived/encounter_rules.dart`, Zustand nach `lib/domain/encounter/`.

### 2.3 Ressourcen live führen — Feinschliff

Weitgehend vorhanden (Vitals-Tab, Stepper, Rast). Ergänzungen:

- Schnellzugriff auf LeP/AsP/Au direkt im Kampf-Tracker (ohne Tab-Wechsel).
- AsP-Abzug direkt aus dem Zauberproben-Dialog anbieten (Kosten eintragen → übernehmen), falls noch nicht vorhanden.
- Zustände wie Betäubung/Furcht zunächst als freie Marker mit optionaler Dauer im Encounter, ohne eigene Regelautomatik.

Aufwand: klein.

### 2.4 Regel-Nachschlag in der App

Lücke: Die Wissensbasis des MCP-Servers ist in der App nicht erreichbar.

Drei Optionen:

| Option | Idee | Bewertung |
|---|---|---|
| **A: FTS5 read-only (empfohlen für Phase 1)** | Die App liest die vom MCP-Indexer erzeugte SQLite-DB (`%LOCALAPPDATA%/dsa-rules-mcp/`) direkt per `sqlite3`-Package (FTS5 ist im gebündelten SQLite enthalten). Nur Keyword-Suche, keine Embeddings. | Schnell umsetzbar, kein Python zur Laufzeit nötig. Auf Desktop direkter Pfadzugriff; auf Web per manuellem Datei-Upload (siehe unten); mobil später via DB-Export/Import. Semantische Suche entfällt — für „Wie ging nochmal Binden?" reicht FTS meist. |
| **B: Lokaler HTTP-Modus des Python-Servers** | Server bekommt einen HTTP-Endpunkt, App fragt localhost ab. | Volle Hybrid-Suche, aber Python-Prozess muss laufen; nur Desktop; Betriebsaufwand. Eher nicht. |
| **C: Kuratiertes Regel-Kompendium als Katalog** | Häufig gebrauchte Spielregeln (Manöver, Zustände, Proben-Sonderfälle) redaktionell als Katalogquelle unter `assets/catalogs/` pflegen, ggf. v3-verschlüsselt wie die bestehenden geschützten Felder. | Beste UX (strukturiert, offline, überall), aber redaktioneller Aufwand. Guter Langfristweg, ergänzt A. |

Urheberrecht: Volltexte offizieller Regelwerke sind für den Privatgebrauch auf dem eigenen Gerät unkritisch, dürfen aber nicht in Builds/Syncs wandern. Option A bleibt eine lokale, nutzerseitige Datenquelle; Option C sollte auf eigene Zusammenfassungen und Hausregeln beschränkt bleiben (Verschlüsselungsmuster existiert bereits). Hinweis: Ich bin kein Anwalt — im Zweifel die Fan-Richtlinien von Ulisses prüfen.

**Web-Erweiterung von Option A:** Im Browser gibt es weder `dart:ffi` noch einen Nutzer-lokalen Standardpfad. Die Web-Variante nutzt `package:sqlite3/wasm.dart` (WebAssembly-Build von SQLite, `web/sqlite3.wasm`) mit einer `IndexedDbFileSystem`-Persistenz. Der Nutzer lädt die am Desktop mit `dsa-rules-cli refresh` erzeugte `index.sqlite` einmalig über einen Datei-Upload in der App hoch (`lib/data/rules_search/rules_index_search_web.dart`); sie bleibt danach origin-gebunden im Browser gespeichert und muss nicht bei jedem Seitenaufruf erneut hochgeladen werden. Es findet **keine** Kopplung an bestehende Cloud-Sync-Mechanismen (Helden-Sync etc.) statt — der Regeltext bleibt rein nutzerseitig auf dem jeweiligen Gerät/Browser, damit er nicht unbeabsichtigt zu einem Verbreitungsweg geschützter Volltexte wird. Eine serverseitige Reindexierung im Browser ist nicht möglich; Aktualisierungen erfordern weiterhin einen Desktop-Lauf plus manuellen Re-Upload.

## 3. Umsetzungsreihenfolge

**Phase 1 — Schnelle Wirkung (klein):**
1. Proben-Schnellsuche im Workspace
2. Würfelprotokoll-Limit + Filter
3. Regel-Nachschlag Option A (FTS5 read-only, Desktop)

**Phase 2 — Kampf-Tracker MVP (mittel):**
4. Encounter-Modell + Hive-Persistenz + Teilnehmerverwaltung (Held, externe Helden, einfache Gegner)
5. INI-Reihenfolge, Rundenzähler, Zugreihenfolge
6. „Schaden erhalten"-Flow (TP → SP → Wunde → HeroState)

**Phase 3 — Tiefe (nach Bedarf):**
7. AT/PA-/Manöver-Dialoge aus dem Tracker, Schadensübergabe an Ziele
8. Effekt-Dauern in KR, Zustands-Marker
9. Gegner-Vorlagen, ggf. Gruppen-Sync des Trackers (nicht Windows), Kompendium (Option C)

Jede Phase ist eigenständig auslieferbar; Tests je Regelmodul gemäß `docs/test_strategy.md`.

## 4. Entscheidungen (abgestimmt am 2026-07-12)

1. Rolle am Tisch: **nur Spieler** — Gegner im Tracker bleiben Minimalwerte (INI, LeP, RS).
2. Regel-Nachschlag: **Option A, Desktop reicht** (FTS5 read-only auf der MCP-Index-DB).
3. Kampf-Tracker: **lokal genügt**, kein Gruppen-Sync in den ersten Ausbaustufen.
4. Reihenfolge: **wie vorgeschlagen** (Phase 1 vor Kampf-Tracker).
5. Regel-Nachschlag Web (abgestimmt am 2026-07-13): **Option A auf Web erweitert**, per manuellem `index.sqlite`-Upload und `sqlite3`-WASM/IndexedDB (siehe 2.4). Mobile bleibt vorerst außen vor.

## 5. Status Regel-Nachschlag Web (Stand 2026-07-23)

Implementierung ist inhaltlich fertig (`lib/data/rules_search/rules_index_search_web.dart`,
Upload-/Ersetzen-Flow in `rules_lookup_dialog.dart`, `web/sqlite3.wasm`,
Cache-Header in `firebase.json`), inklusive eines Workarounds für den
WAL-Journal-Modus, den `IndexedDbFileSystem` nicht unterstützt. Ein Bug in der
Fehleranzeige beim "Index ersetzen" (Fehlermeldung erschien nur im
Erstimport-Leerzustand, nicht im Suchzustand) wurde behoben.

Zusätzlich verifiziert: `flutter build web --release` kompiliert fehlerfrei
(inkl. Wasm-Dry-Run), und ein lokal servierter Build liefert `sqlite3.wasm`
korrekt mit `Content-Type: application/wasm` aus.

Noch offen — **nicht** weil kein Browser verfügbar wäre (Edge ist installiert
und läuft headless einwandfrei, `flutter devices` listet es als Web-Device),
sondern weil der dafür nötige interaktive Browser-Test in der bisherigen
Entwicklungsumgebung nicht automatisiert werden konnte: `flutter test
--platform chrome` (offiziell deprecated) scheitert beim Start von Edge nach
3 schnellen Fehlversuchen (~500 ms) mit "Failed to launch browser" — ein
Launch-Detection-Problem in flutter_tools' Chromium-Launcher mit Edges
Prozessmodell, nicht am Browser selbst (ein manueller Headless-Start mit
identischen Flags liefert einen funktionierenden DevTools-Endpunkt). Ein
Browser-Automatisierungswerkzeug wie `chromium-cli` oder Playwright, um
`flutter run -d edge` stattdessen zu steuern und zu screenshotten, war in der
Umgebung nicht installiert.

- Automatisierte Tests für `rules_index_search_web.dart` und den
  Upload-/Ersetzen-Flow im Dialog (`flutter test --platform chrome` oder ein
  Ersatz dafür, z. B. `flutter run -d edge` + Playwright/`chromium-cli`).
- Ein manueller Durchlauf mit einer echten, von `dsa-rules-cli refresh`
  erzeugten `index.sqlite` (Upload, Suche, Neuladen der Seite, Persistenz
  über `IndexedDbFileSystem` prüfen).
- Verifikation, dass die aktuellen Firebase-Hosting-Header ohne
  COOP/COEP-Header ausreichen (erwartet ja, da `IndexedDbFileSystem` statt
  des OPFS-Sync-Access-Handle-Pools verwendet wird — der lokale Dev-Server
  bestätigt nur den `application/wasm`-Content-Type, keine Cross-Origin-
  Isolation-relevanten Header; eine echte Browser-Konsole wurde nicht
  geprüft).

Diese drei Punkte brauchen entweder eine funktionierende
`flutter test --platform chrome`/Edge-Kombination oder ein installiertes
Browser-Automatisierungswerkzeug (z. B. `chromium-cli`, Playwright), um
`flutter run -d edge` zu steuern.
