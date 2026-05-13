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
- Der Windows-Release-Audit fuer EXE/MSIX-Artefakte ist in `docs/windows_antivirus_audit.md` beschrieben; der zugehoerige Helfer liegt unter `tool/audit_windows_artifact.ps1`.

## Pflegehinweis

Schnell veraltende Details gehoeren nicht in diese Datei. Wenn sich Architektur, Workflows oder Fachlogik aendern, aktualisiere stattdessen die passende Datei in `README.md` oder unter `docs/`.
