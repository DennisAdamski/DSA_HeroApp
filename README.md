# DSA Heldenverwaltung

Flutter-App zur Verwaltung von Helden für *Das Schwarze Auge* (DSA) mit lokalem
Datenmodell, regelgestützten Berechnungen und katalogbasierten Inhalten.
Eigenschaften, Talente, Kampf, Magie, Inventar, Chroniken, Kontakte, Abenteuer,
Import/Export und Hausregel-Kataloge laufen in einer Anwendung zusammen; ein
optionales Konto synchronisiert Helden zwischen Geräten.

- **Web-App:** https://heldensync-ccf0b.web.app
- **Testversion:** https://heldensync-test.web.app

DSA Heldenverwaltung ist ein inoffizielles, kostenloses Fanprojekt und steht
nicht in Verbindung zu Ulisses Spiele.

## Inhalt

- [Funktionsumfang](#funktionsumfang)
- [Technischer Aufbau](#technischer-aufbau)
- [Schnellstart](#schnellstart)
- [Tests und Qualität](#tests-und-qualität)
- [Veröffentlichung](#veröffentlichung)
- [Projektstruktur](#projektstruktur)
- [Dokumentation](#dokumentation)
- [Pflege dieser Seite](#pflege-dieser-seite)

## Funktionsumfang

Die ausführliche Beschreibung steht in
[Funktionsumfang im Detail](docs/funktionsumfang.md).

- **Helden:** Anlegen mit Roh-Startwerten, Stammdaten und Biografie, Vor- und
  Nachteile aus dem Katalog, effektive Startwerte und Eigenschaftsmaxima.
- **Drei Arbeitsbereiche:** **Spielen**, **Held verwalten** und **Entwicklung
  planen**. Die Planung ist eine heldenweite Steigerungsrunde: Änderungen werden
  erst mit **Änderungen übernehmen** wirksam, inklusive AP-Reservierung, Historie
  und Fähigkeitenbaum für Sonderfertigkeiten und Manöver.
- **Talente und Sprachen:** allgemeine Talente, Kampf- und Meta-Talente,
  Spezialisierungen, Sondererfahrungen, Begabungen, Sprachen und Schriften.
- **Kampf:** Waffen, Nebenhand, Parierwaffen, Schilde und Rüstungen mit
  Kampfvorschau; eine flüchtige Gefechtssitzung führt Runden, INI, Aktionen,
  Distanzklassen und Fernkampf.
  Details: [Gefecht](docs/gefecht_implementation.md).
- **Magie:** Zauber, Repräsentationen, Traditionen, Rituale und laufende
  Zaubereffekte. Details: [Magische Kenntnisse](docs/magische_kenntnisse.md),
  [Zaubereffekte](docs/zaubereffekte_integrationsplan.md).
- **Spieltisch:** Vitalwerte, Rast und Regeneration, „Schaden erhalten“ mit
  Trefferzonen und Wunden, Proben-Schnellsuche, Würfelprotokoll und
  Regel-Nachschlag mit Kurzregeln.
- **Inventar und Abenteuer:** Ausrüstung, Dukaten, Chroniken, Kontakte und
  Abenteuer mit geführtem Abschluss (AP, Sondererfahrungen, Beute).
- **Begleiter:** Reittiere und Vertraute
  ([Reittiere](docs/reittier_plan.md), [Vertraute](docs/vertraute_plan.md)).
- **Daten und Kataloge:** Import/Export als JSON-Bundle, eigene
  Katalogeinträge, aktivierbare Hausregel-Pakete und eine Katalogverwaltung in
  den Einstellungen.
- **Speicherung und Sync:** lokal ohne Konto; mit Login getrenntes Konto-Profil
  und Abgleich über Firestore mit sichtbarer Konfliktentscheidung.
  Details: [Konto-Sync](docs/hinweise/sync_konto.md).

Plattformen: Web, Windows, macOS, Linux, iOS/iPadOS und Android.

## Technischer Aufbau

```text
UI (lib/ui/ Bestand, lib/ui2/ Neubau „Kartograph“)
  -> State Layer mit Riverpod (lib/state/)
    -> Anwendungsabläufe ohne Riverpod (lib/ablaeufe/)
    -> Domain-Modelle (lib/domain/)
    -> Regelmodule (lib/rules/derived/)
    -> Repository/Data Layer (lib/data/)
    -> Katalog-Layer (lib/catalog/)
```

Technischer Stack: Flutter und Dart, `flutter_riverpod`, `hive_ce` für die
lokale Persistenz, Firebase (Auth, Firestore, Storage, Hosting, App Check) für
Konto und Web, Python-Werkzeuge unter `tool/` für Katalogaufbereitung und
Wartung.

Grundprinzipien:

- Domain-Modelle sind unveränderlich, serialisierbar und werden nur additiv
  erweitert; unbekannte Felder bleiben erhalten.
- Regellogik liegt ausschließlich in `lib/rules/derived/`. UI und Provider
  rufen Regelmodule auf, rechnen aber nicht selbst.
- Schreibende Abläufe wie „Rast abschließen“ oder „Schaden erhalten“ liegen in
  `lib/ablaeufe/`: frisch laden, über Regeln rechnen, speichern.
- Katalogdaten werden zur Laufzeit aus Split-JSON unter
  `assets/catalogs/house_rules_v1/` geladen.
- Bestand und Neubau der Oberfläche laufen parallel und werden unter
  `Einstellungen > Darstellung` umgeschaltet. Sie teilen Heldenspeicher, Sync,
  Kataloge und Regelmodule.

Mehr dazu: [Technischer Überblick](docs/technical_overview.md) und
[Architektur-Roadmap](docs/architecture_roadmap.md).

## Schnellstart

Voraussetzungen: Flutter SDK (stable) und je nach Zielplattform Xcode, Android
Studio oder die passende Desktop-Toolchain.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Lokales Web-Debuggen:

```bash
flutter run -d chrome --web-port=5000
```

Schlägt die Firebase-Initialisierung fehl, startet die App im lokalen Modus;
nur Konto und Cloud-Funktionen bleiben dann deaktiviert.

**iOS/iPadOS:** `bash tool/ios_bootstrap_spm.sh` auf einem Mac mit Xcode 15+,
Details in [iOS/Xcode-Setup](docs/ios_xcode_setup.md).

**Windows:**

```bash
flutter build windows --release
dart run msix:create
```

`flutter_secure_storage_windows` braucht ATL/MFC aus Visual Studio. Scheitert
der Build an `atlstr.h` oder `atls.lib`, in der verwendeten Visual-Studio- bzw.
Build-Tools-Instanz die Komponente `C++ ATL/MFC` nachinstallieren. Prüfung von
Release-Artefakten: [Windows-Antivirus-Audit](docs/windows_antivirus_audit.md).

## Tests und Qualität

```bash
flutter analyze
flutter test
python tool/check_screen_loc_budget.py --max-lines 700
python -m unittest tool.test_pdf_catalog_agent
```

`flutter analyze` bricht in der CI auch bei `info`-Lints ab. Für
AES-verschlüsselte PDFs im `pdf_catalog_agent` wird zusätzlich
`cryptography>=3.1` benötigt. Testaufbau und Regeln:
[Teststrategie](docs/test_strategy.md).

## Veröffentlichung

Arbeitsbranch → PR nach `test` → Abnahme → PR von `test` nach `main`.
`test` veröffentlicht nach erfolgreichen Prüfungen auf
https://heldensync-test.web.app, `main` die produktive Version. Pushes auf
`main` werden automatisch nach `test` gemergt. Beide Versionen teilen Konten
und Cloud-Helden. Details: [Web-Veröffentlichung](docs/web_deployment.md).

## Projektstruktur

```text
lib/
  ablaeufe/       Schreibende Anwendungsabläufe
  catalog/        Katalog-Loader und Runtime-Katalog
  data/           Repository, Persistenz und Datei-I/O
  domain/         Persistierte und Laufzeit-Modelle
  rules/derived/  Fach- und Regellogik
  state/          Riverpod-Provider und berechnete Snapshots
  ui/             Bestandsoberfläche
  ui/bridges/     Übergangsbrücke der Bestandsansichten zum Neubau
  ui2/            Neubau „Kartograph“

assets/
  catalogs/house_rules_v1/  Split-JSON-Kataloge und Hausregel-Pakete
  catalogs/reiseberichte/   Separater Reisebericht-Katalog
  heroes/                   Beispielhelden

tool/             Python- und Shell-Helfer für Import, Analyse, CI und Wartung
docs/             Technische und fachliche Projektdokumentation
```

## Dokumentation

- Einstieg für Entwicklung und Agenten: [CLAUDE.md](CLAUDE.md),
  [AGENTS.md](AGENTS.md) und die Themenhinweise unter
  [docs/hinweise/](docs/hinweise/)
- Architektur: [Technischer Überblick](docs/technical_overview.md),
  [Architektur-Roadmap](docs/architecture_roadmap.md),
  [Schreibpfade](docs/schreibpfade_inventar.md)
- Kataloge: [Katalog-Import](docs/catalog_import_workflow.md),
  [Hausregel-Zuordnung](docs/rules_mapping_house_rules_v1.md),
  [PDF-Agent](docs/pdf_agent_workflow.md),
  [Kurzregel-Kompendium](docs/kurzregeln_redaktion.md)
- Fachpläne: [Gefecht](docs/gefecht_implementation.md),
  [Zaubereffekte](docs/zaubereffekte_integrationsplan.md),
  [Spielmodus](docs/spielmodus_konzept.md),
  [Reiseroute](docs/reiseroute_plan.md),
  [Redesign](docs/redesign_implementation.md)
- Betrieb: [Web-Veröffentlichung](docs/web_deployment.md),
  [Sicherheit](docs/security_operations.md),
  [Datenschutz und Rechtstexte](docs/legal_privacy_operations.md),
  [Feedback](docs/feedback_betrieb.md),
  [UI-Performance](docs/ui_performance_measurements.md)

## Pflege dieser Seite

Diese README ist die Startseite des Repositorys. Sie enthält nur, was sich
selten ändert: Zweck, Links, Funktionsbereiche in einer Zeile, Aufbau,
Schnellstart und Dokumentationsindex. Detailbeschreibungen neuer Funktionen
gehören in [Funktionsumfang im Detail](docs/funktionsumfang.md) oder den
passenden Fachplan, nicht hierher. Keine schnell veraltenden Zahlen wie
Schemaversionen eintragen.
