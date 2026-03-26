# DSA Heldenverwaltung

Flutter-App zur Verwaltung von Helden fuer *Das Schwarze Auge* (DSA) mit lokalem Datenmodell, regelgestuetzten Berechnungen und katalogbasierten Inhalten.

Die App ist auf eine moeglichst umfangreiche Heldenverwaltung ausgelegt: Eigenschaften, Talente, Kampf, Magie, Inventar, Notizen, Import/Export und hausregelbasierte Katalogdaten werden in einer lokalen Anwendung zusammengefuehrt.

## Inhalt

- [Projektueberblick](#projektueberblick)
- [Funktionsumfang](#funktionsumfang)
- [Technischer Aufbau](#technischer-aufbau)
- [Schnellstart](#schnellstart)
- [Wie eine solche App aufgebaut werden kann](#wie-eine-solche-app-aufgebaut-werden-kann)
- [Projektstruktur](#projektstruktur)
- [Tests und Qualitaet](#tests-und-qualitaet)
- [Weiterfuehrende Dokumentation](#weiterfuehrende-dokumentation)

## Projektueberblick

Die App verwaltet DSA-Helden lokal auf dem Geraet und kombiniert dabei drei Kernbereiche:

- Persistente Heldendaten mit separatem Laufzeitzustand
- Getrennter lokaler Einstellungsordner und optional konfigurierbarer
  Heldenspeicher auf Desktop-Plattformen
- Regelberechnungen fuer abgeleitete Werte und Kampfvorschau
- Katalogdaten aus versionierten JSON-Assets auf Basis externer Excel-Quellen

Technischer Stack:

- Flutter + Dart
- `flutter_riverpod` fuer State-Management
- `Hive` fuer lokale Persistenz
- JSON-Import/-Export fuer Heldendaten
- Python-Tools unter `tool/` fuer Katalogaufbereitung und Wartung

## Funktionsumfang

### Heldenverwaltung

- Anlegen neuer Helden mit Roh-Startwerten fuer die acht DSA-Eigenschaften
- Persistenz aller Heldendaten inklusive Schema-Versionierung
- Separate Speicherung des Laufzeitzustands wie aktuelle LeP, AsP, KaP und Ausdauer
- Seed-Import von Beispielhelden aus `assets/heroes/`
- Optionaler eigener Heldenspeicherordner auf Windows, macOS und Linux

### Speicherung

- App-Einstellungen liegen immer lokal in einem separaten App-Ordner unter
  `Application Support` bzw. auf Windows in `AppData`
- Heldendaten nutzen standardmaessig einen eigenen Unterordner und koennen auf
  Desktop-Plattformen auf einen frei gewaehlten Ordner umgestellt werden
- Ein ungueltiger benutzerdefinierter Heldenspeicherpfad fuehrt zu einem
  klaren Fehlerzustand statt zu einem stillen Fallback
- Standardpfade liegen direkt unter dem app-spezifischen Support-Ordner, also
  z. B. `.../DSA Heldenverwaltung/Einstellungen` und
  `.../DSA Heldenverwaltung/Helden`

### Uebersicht und Stammdaten

- Pflege von Name, Rasse, Kultur, Profession und Biografiedaten
- Verwaltung von AP, Stufe, Ressourcen und textbasierten Modifikatoren
- Berechnung effektiver Startwerte und Eigenschaftsmaxima
- Gefuehrte AP-Steigerung fuer Eigenschaften und kaufbare Grundwerte
- Parsing von Modifikator-Texten aus Vor-/Nachteilen sowie R/K/P-Feldern

### Talente und Sprachen

- Verwaltung allgemeiner Talente, Kampftalente und Meta-Talente
- Validierung von AT/PA-Aufteilungen bei Kampftalenten
- Unterstuetzung fuer Talentspezialisierungen, Sondererfahrungen, Begabungen und strukturierte Talent-Sonderfertigkeiten
- Steigerungsdialog fuer Talente mit Live-AP-Kosten, SE-Verbrauch, manueller Komplexitaetskorrektur und Lehrmeister-Rabatt
- AP-Steigerung fuer Kampftalente auch direkt im Kampftechniken-Tab
- Eigener Bereich fuer Sprachen und Schriften auf Basis von Katalogdaten

### Kampf

- Pflege von Nah- und Fernkampfwaffen in einer gemeinsamen Kampfkonfiguration
- Unterstuetzung fuer Nebenhand, Parierwaffen, Schilde und Ruestungen
- Kampfvorschau mit AT, PA, TP, INI, Ladezeit, Distanzstufen und Geschossen
- Verwaltung aktiver Manoever und katalogbasierter Kampf-Sonderfertigkeiten
- Waffenmeister-Baukasten mit Voraussetzungen, Boni und Vorschau der Wirkung
- Beruecksichtigung waffenloser Kampfstile und freigeschalteter Manoever

### Magie

- Verwaltung gelernter Zauber inklusive Repruesentation, Tradition und Begabung
- Automatische Aktivierung des Magie-Bereichs ueber AE/AsP-Modifikatoren aus
  Rasse, Kultur, Profession oder Vorteilen mit optionalem manuellem Override
- Globale Leiteigenschaft fuer magische Regeneration im Magie-Bereich
- Anzeige von Verfuegbarkeit, Lernkomplexitaet und heldenspezifischen Anpassungen
- Steigerungsdialog fuer Zauber mit Fremdrepr.-, Hauszauber-, manueller Komplexitaetskorrektur und Lehrmeisterlogik
- Eigener Ritual-Bereich mit Ritualkategorien, Ritualkenntnissen und Ritualen
- Pflege magischer Sonderfertigkeiten mit Beschreibung und aktiver Zaubereffekte

### Workspace und Regeneration

- Vitalwerte enthalten neben LeP, Au, AsP und KaP auch Erschoepfung und Ueberanstrengung mit direkter manueller Anpassung
- Rast-Aktion als Lagerfeuer-Symbol oben rechts in den Vitalwerten fuer Ausruhen, Schlafphase und Bettruhe
- Strukturierte Regenerationslogik fuer LeP, Au und AsP inklusive KO-/IN-Proben und Umweltmodifikatoren
- Dauerhafte Verwaltung von Erschoepfung und Ueberanstrengung im `HeroState`
- Optionaler Fullrestore fuer lange Abwesenheiten: alle Vitalwerte auf Maximum und keine Wunden mehr
- Vorschau und Sammeluebernahme der Rast-Ergebnisse direkt im Workspace

### Inventar, Notizen und Verbindungen

- Direkt bearbeitbares Inventar als kompakte Tabelle fuer Ausruestung und sonstige Gegenstaende
- Notizen mit Titel und Beschreibung
- Verbindungen/Kontakte mit Ort, Sozialstatus, Loyalitaet und Beschreibung

### Datenimport und Kataloge

- Import und Export kompletter Helden als JSON-Bundle
- Konfliktbehandlung beim Import vorhandener Helden
- Katalogdaten aus `assets/catalogs/house_rules_v1/`
- Aufbereitung der Runtime-Kataloge aus Excel-Quellen ueber Skripte in `tool/`

## Technischer Aufbau

Die App folgt einer klar getrennten Schichtenarchitektur:

```text
UI (lib/ui/)
  -> State Layer mit Riverpod (lib/state/)
    -> Domain-Modelle (lib/domain/)
    -> Regelmodule (lib/rules/derived/)
    -> Repository/Data Layer (lib/data/)
    -> Katalog-Layer (lib/catalog/)
```

Grundprinzipien des Projekts:

- Domain-Modelle sind immutable und serialisierbar
- Regellogik liegt ausschliesslich in `lib/rules/derived/`
- UI und Provider rufen Regelmodule auf, rechnen aber nicht selbst
- Katalogdaten werden zur Laufzeit aus Split-JSON geladen
- `HeroSheet` nutzt Schema-Version `21`, `HeroState` Schema-Version `5`

## Schnellstart

Voraussetzungen:

- Flutter SDK
- Dart SDK
- Je nach Zielplattform Android Studio, Xcode oder passende Desktop-Toolchains

Projekt lokal starten:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

iOS/Xcode-Setup auf macOS:

```bash
bash tool/ios_bootstrap_spm.sh
```

Details dazu stehen in `docs/ios_xcode_setup.md`.

## Wie eine solche App aufgebaut werden kann

Wenn du diese App erweitern oder eine aehnliche DSA- oder Charakterverwaltungs-App bauen willst, ist die vorhandene Struktur bereits ein brauchbares Referenzmuster:

1. Modelle fuer persistierte Heldendaten und separaten Laufzeitzustand definieren.
2. Regelberechnungen als reine Funktionen kapseln, statt sie in Widgets oder State-Klassen zu verteilen.
3. Ein Repository-Interface zwischen UI und Persistenz ziehen, damit Speichertechnik austauschbar bleibt.
4. Katalogdaten versioniert und getrennt vom Code halten.
5. Import/Export frueh als stabiles Bundle-Format modellieren.
6. Reaktive UI ueber Provider/Snapshots aufbauen, damit abgeleitete Werte zentral berechnet werden.

Fuer die konkrete Umsetzung im Projekt sind diese Dokus die besten Einstiege:

- `docs/technical_overview.md` fuer Architektur, Datenfluss und Modellschichten
- `docs/catalog_import_workflow.md` fuer den Weg von Excel nach Runtime-JSON
- `docs/rules_mapping_house_rules_v1.md` fuer die fachliche Zuordnung der Hausregeln
- `docs/test_strategy.md` fuer Testaufbau und Qualitaetssicherung

## Projektstruktur

```text
lib/
  catalog/        Katalog-Loader und Runtime-Katalog
  data/           Repository, Persistenz und Datei-I/O
  domain/         Persistierte und Laufzeit-Modelle
  rules/derived/  Fach- und Regellogik
  state/          Riverpod-Provider und berechnete Snapshots
  ui/             Screens, Widgets und Workspace-Layout

assets/
  catalogs/house_rules_v1/  Split-JSON-Kataloge
  heroes/                   Seed-Helden

tool/
  Python- und Shell-Helfer fuer Import, Analyse und Wartung

docs/
  Technische und prozessuale Projektdokumentation
```

## Tests und Qualitaet

Empfohlene Standardbefehle:

```bash
flutter analyze
flutter test
python tool/check_screen_loc_budget.py --max-lines 700
```

Zusatzlich vorhanden:

- Widget- und State-Tests fuer UI, Provider und Regeln
- Performance-Guardrails fuer Rebuild-Verhalten
- Manuelles UI-Profiling ueber Flutter DevTools bei Bedarf

Weitere Referenzen:

- `lib/catalog/vertrautenmagie_preset.dart` enthaelt das getypte
  Vertrautenmagie-Preset fuer freie Ritualkategorien.
- `assets/catalogs/house_rules_v1/vertrautenmagie_rituale.json` enthaelt das
  passende JSON-Snippet derselben Daten fuer Import, Review und Referenz.

## Weiterfuehrende Dokumentation

- `docs/technical_overview.md`
- `docs/catalog_import_workflow.md`
- `docs/rules_mapping_house_rules_v1.md`
- `docs/test_strategy.md`
- `docs/ui_performance_measurements.md`
- `docs/ios_xcode_setup.md`

## Hinweise

- Die kanonische Katalogquelle fuer die App bleibt `assets/catalogs/house_rules_v1/`.
- Excel-Dateien im Repo-Root sind Upstream-Quellen fuer die Katalogaufbereitung.
- Platzhalter- und Legacy-Dateien werden bewusst nicht automatisch entfernt.
