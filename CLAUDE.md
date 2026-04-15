# CLAUDE.md - DSA Heldenverwaltung

Kurze Einstiegsdatei fuer neue Sessions. Diese Datei bleibt absichtlich klein und enthaelt nur stabile Hinweise.

## Zuerst lesen

- `AGENTS.md` ist die verbindliche Agentenrichtlinie.
- `README.md` beschreibt Produktumfang, Architekturueberblick und Standard-Workflows.
- Detaildokumentation liegt bei Bedarf in `docs/technical_overview.md`, `docs/test_strategy.md`, `docs/catalog_import_workflow.md`, `docs/pdf_agent_workflow.md` und `docs/ios_xcode_setup.md`.

## Projektkontext

- `dsa_heldenverwaltung` ist eine Flutter-App zur Verwaltung von DSA-Helden.
- Die App nutzt lokale Persistenz, katalogbasierte Inhalte und getrennte Regellogik.
- Regellogik gehoert nach `lib/rules/derived/`.
- Die kanonische Katalogquelle bleibt `assets/catalogs/house_rules_v1/`.
- Reisebericht-Daten bleiben separat unter `assets/catalogs/reiseberichte/house_rules_v1/`.
- Projektsprache ist Deutsch; sichtbare UI-Texte sollen echte Umlaute und das Eszett verwenden, wenn technisch moeglich.

## Pflegehinweis

Schnell veraltende Details gehoeren nicht in diese Datei. Wenn sich Architektur, Workflows oder Fachlogik aendern, aktualisiere stattdessen die passende Datei in `README.md` oder unter `docs/`.
