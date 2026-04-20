# DSA Heldenverwaltung

Flutter-App zur Verwaltung von Helden fuer *Das Schwarze Auge* (DSA) mit lokalem Datenmodell, regelgestuetzten Berechnungen und katalogbasierten Inhalten.

Die App ist auf eine moeglichst umfangreiche Heldenverwaltung ausgelegt: Eigenschaften, Talente, Kampf, Magie, Inventar, Chroniken, Kontakte, Abenteuer, Import/Export und hausregelbasierte Katalogdaten werden in einer lokalen Anwendung zusammengefuehrt.

## Inhalt

- [DSA Heldenverwaltung](#dsa-heldenverwaltung)
  - [Inhalt](#inhalt)
  - [Projektueberblick](#projektueberblick)
  - [Funktionsumfang](#funktionsumfang)
    - [Heldenverwaltung](#heldenverwaltung)
    - [Speicherung](#speicherung)
    - [Uebersicht und Stammdaten](#uebersicht-und-stammdaten)
    - [Talente und Sprachen](#talente-und-sprachen)
    - [Kampf](#kampf)
    - [Magie](#magie)
    - [Workspace und Regeneration](#workspace-und-regeneration)
    - [Inventar, Chroniken, Kontakte und Abenteuer](#inventar-chroniken-kontakte-und-abenteuer)
    - [Datenimport und Kataloge](#datenimport-und-kataloge)
  - [Technischer Aufbau](#technischer-aufbau)
  - [Schnellstart](#schnellstart)
  - [Wie eine solche App aufgebaut werden kann](#wie-eine-solche-app-aufgebaut-werden-kann)
  - [Projektstruktur](#projektstruktur)
  - [Tests und Qualitaet](#tests-und-qualitaet)
  - [Windows-Antivirus-Audit](#windows-antivirus-audit)
  - [Erstellen einer Windows App](#erstellen-einer-windows-app)
  - [Weiterfuehrende Dokumentation](#weiterfuehrende-dokumentation)
  - [Hinweise](#hinweise)

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
- Auf Web-Zielplattformen liegen Einstellungen und Heldendaten stattdessen im
  browserlokalen Speicher; die UI zeigt dafuer den logischen Pfad
  `Browser-Speicher/...` an
- Custom-Kataloge werden im aktiven Heldenspeicher unter
  `custom_catalogs/<katalogversion>/<sektion>/<id>.json` gespeichert und
  koennen dadurch ueber einen synchronisierten Cloud-Ordner mitlaufen
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
- Abenteuer-Sondererfahrungen fuer Eigenschaften und Grundwerte werden direkt in den Steigerungsdialogen angezeigt und beim Steigern verbraucht
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
- Aktionskarte fuer beidhändigen Kampf mit Falsche-Hand-Mali, Doppelangriff und Zusatzaktionen aus Beidhändigem Kampf beziehungsweise Parierwaffen
- Verwaltung aktiver Manoever und katalogbasierter Kampf-Sonderfertigkeiten
- Kampf-Sonderfertigkeiten und Manöver bleiben als getrennte Katalogquellen modelliert; die Kampf-UI filtert Doppelungen anhand der Manöver-Namen aus
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
- Tablet-Layouts fuer iPad und breite Fenster: Icon-Rail im Portrait, permanenter Inspector im Landscape und ein kompakter zweizeiliger Workspace-Header mit aktivem Bereich, Bildausschnitt und Kernwerten

### Inventar, Chroniken, Kontakte und Abenteuer

- Direkt bearbeitbares Inventar als kompakte Tabelle fuer Ausruestung und sonstige Gegenstaende inklusive magischer und geweihter Markierungen
- Freie Chroniken mit Titel und Beschreibung
- Verbindungen/Kontakte mit Ort, Sozialstatus, Loyalitaet, Beschreibung und optionaler Abenteuer-Zuordnung
- Abenteuer als Chip-Uebersicht mit fokussierter Detailansicht; neue Abenteuer, Notizen und Personen werden jeweils ueber Popups angelegt oder bearbeitet
- Abenteuer pflegen Status (`Aktuell` oder `Abgeschlossen`), weltliche und aventurische Start-/Enddaten, ein aktuelles aventurisches Datum, abenteuerbezogene Notizen und Personen direkt in der Detailansicht
- AP-Belohnung, fest zugeordnete Sondererfahrungen, Dukaten und Abschluss-Beute werden gesammelt im gefuehrten `Abschliessen`-Dialog gepflegt und anschliessend atomar in AP, SE-Pools, Dukatenstand und Inventar uebernommen
- Ein Abschluss kann fachlich sicher wieder zurueckgenommen werden; Abenteuer-Beute bleibt dabei bewusst vom Kampf-Inventar entkoppelt

### Datenimport und Kataloge

- Import und Export kompletter Helden als JSON-Bundle
- Gruppen-Snapshots und Firestore-Sync uebertragen Avatarbilder nur als
  kompakte Vorschaubilder; wenn kein kleines Thumbnail erzeugt werden kann,
  erscheint auf anderen Geraeten stattdessen der Platzhalter
- Konfliktbehandlung beim Import vorhandener Helden
- Katalogdaten aus `assets/catalogs/house_rules_v1/`
- Katalogeintraege koennen strukturierte Herkunfts- und Freischaltmetadaten
  (`ruleMeta`) fuer offizielle Regeln, Hausregeln, Quellbelege und epische
  Opt-in-Inhalte tragen
- Settings-Bereich `Katalogverwaltung` zum Einsehen aller Basisdaten sowie zum
  Anlegen, Bearbeiten und Loeschen synchronisierbarer Custom-Eintraege
- Hero-Exporte koennen benoetigte Custom-Katalogeintraege mitsenden, damit
  referenzierte Hausregeln beim Import direkt wieder aufloesbar sind
- Reisebericht-Daten liegen bewusst separat unter
  `assets/catalogs/reiseberichte/house_rules_v1/` und gehoeren nicht zur
  editierbaren Settings-Katalogverwaltung
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

Die UI nutzt seit dem iPad-Redesign ein gemeinsames Layoutmodell aus
`lib/ui/config/app_layout.dart` und wiederverwendbare Split-Views aus
`lib/ui/widgets/codex_split_view.dart`, damit Home und Workspace auf
Tablet-Breiten konsistent zwischen Fokusansicht und Master-Detail wechseln.
```

Grundprinzipien des Projekts:

- Domain-Modelle sind immutable und serialisierbar
- Regellogik liegt ausschliesslich in `lib/rules/derived/`
- UI und Provider rufen Regelmodule auf, rechnen aber nicht selbst
- Katalogdaten werden zur Laufzeit aus Split-JSON geladen
- `HeroSheet` nutzt Schema-Version `23`, `HeroState` Schema-Version `5`

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

Wichtig fuer Tests auf dem eigenen iPad:

- Der erste iOS-Bootstrap muss auf einem Mac mit Xcode 15+ laufen und
  aktualisiert dabei das Xcode-Projekt fuer den SPM-Workflow.
- In Xcode brauchst du fuer persoenliches Signing einen eigenen, eindeutigen
  Bundle Identifier.
- Wenn du den Bundle Identifier aenderst und den Gruppen-Sync ueber Firebase
  nutzen willst, solltest du anschliessend `flutterfire configure` erneut
  ausfuehren, damit `lib/firebase_options.dart` wieder dazu passt.
- Schlaegt die Firebase-Initialisierung fehl, startet die App trotzdem im
  lokalen Modus weiter; nur Gruppen-Sync und andere Cloud-Funktionen bleiben
  deaktiviert.

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
- `docs/pdf_agent_workflow.md` fuer den lokalen PDF-Agenten und die DSA-Wissensbasis
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
  catalogs/reiseberichte/   Separater Reisebericht-Katalog
  heroes/                   Seed-Helden

tool/
  Python- und Shell-Helfer fuer Import, Analyse und Wartung
  pdf_catalog_agent/  Lokaler Dokument-Agent fuer PDF-, DOCX- und ODT-Wissensbasis

docs/
  Technische und prozessuale Projektdokumentation
```

## Tests und Qualitaet

Empfohlene Standardbefehle:

```bash
flutter analyze
flutter test
python tool/check_screen_loc_budget.py --max-lines 700
python -m unittest tool.test_pdf_catalog_agent
```

Fuer AES-verschluesselte PDFs im `pdf_catalog_agent` wird zusaetzlich
`cryptography>=3.1` in der aktiven Python-Laufzeit benoetigt.

Zusatzlich vorhanden:

- Widget- und State-Tests fuer UI, Provider und Regeln
- Performance-Guardrails fuer Rebuild-Verhalten
- Manuelles UI-Profiling ueber Flutter DevTools bei Bedarf

Weitere Referenzen:

- `lib/catalog/vertrautenmagie_preset.dart` enthaelt das getypte
  Vertrautenmagie-Preset fuer freie Ritualkategorien.
- `assets/catalogs/house_rules_v1/vertrautenmagie_rituale.json` enthaelt das
  passende JSON-Snippet derselben Daten fuer Import, Review und Referenz.

## Windows-Antivirus-Audit

Fuer Release-Pruefungen auf Windows gibt es eine eigene Dokumentation unter
`docs/windows_antivirus_audit.md`. Sie fasst die statischen Audit-Befunde,
heuristisch auffaellige, aber legitime Laufzeitfunktionen und den empfohlenen
Pruefablauf fuer EXE- oder MSIX-Artefakte zusammen.

Fuer die optionale Artefaktpruefung liegt ein PowerShell-Helfer unter
`tool/audit_windows_artifact.ps1`. Er dokumentiert SHA-256, Dateimetadaten,
Authenticode-Status und optional einen lokalen Microsoft-Defender-Scan.

## Erstellen einer Windows App

```bash
flutter pub get
flutter build windows --release
flutter pub run msix:create
```

## Weiterfuehrende Dokumentation

- `docs/technical_overview.md`
- `docs/catalog_import_workflow.md`
- `docs/pdf_agent_workflow.md`
- `docs/rules_mapping_house_rules_v1.md`
- `docs/test_strategy.md`
- `docs/ui_performance_measurements.md`
- `docs/ios_xcode_setup.md`
- `docs/windows_antivirus_audit.md`

## Hinweise

- Die kanonische Katalogquelle fuer die App bleibt `assets/catalogs/house_rules_v1/`.
- Benutzerdefinierte Katalogeintraege liegen nie im Einstellungsordner,
  sondern immer im aktuell aktiven Heldenspeicher.
- `assets/catalogs/reiseberichte/house_rules_v1/reisebericht.json` bleibt ein
  separater Runtime-Katalog ausserhalb der editierbaren Settings-Sektionen.
- Excel-Dateien im Repo-Root sind Upstream-Quellen fuer die Katalogaufbereitung.
- Platzhalter- und Legacy-Dateien werden bewusst nicht automatisch entfernt.
