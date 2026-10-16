# CLAUDE.md - DSA Heldenverwaltung

Kurze Einstiegsdatei fuer neue Sessions. Sie enthaelt nur die harten Regeln und
einen Themenindex; Details stehen nach Thema in [docs/hinweise/](docs/hinweise/).
`AGENTS.md` ist die verbindliche Agentenrichtlinie.

## Projekt

- `dsa_heldenverwaltung`: Flutter-App zur Verwaltung von DSA-Helden mit lokaler
  Persistenz (`hive_ce`, Boxen halten `Map`/`Uint8List`, keine `TypeAdapter`),
  katalogbasierten Inhalten und getrennter Regellogik. Projektsprache Deutsch;
  sichtbare Texte mit echten Umlauten und Eszett.
- Regellogik gehoert nach `lib/rules/derived/` (nie in Widgets, Provider oder
  Modelle). Fachliche Schreibablaeufe liegen in `lib/ablaeufe/` (ohne Riverpod
  und Flutter, Abhaengigkeiten per Konstruktor).
- Kanonische Katalogquelle: `assets/catalogs/house_rules_v1/` (Split-JSON,
  Hausregel-Pakete unter `packs/<id>/manifest.json`, in `pubspec.yaml` als
  Assets zu registrieren).
- Zwei Oberflaechen laufen parallel: Bestand `lib/ui/` und Neubau `lib/ui2/`
  („Kartograph“). Einziger Verdrahtungspunkt ist `AppRootSwitch`
  (`lib/ui2/shell/karto_app_root.dart`); `lib/ui2` importiert sonst nichts aus
  `lib/ui`.

## Harte Regeln (Verstoss = Datenverlust oder Sync-Konflikte)

1. **Krypto nie anpassen.** `lib/crypto/aes_primitives.dart` ist blattartig; die
   Golden-Tests (`test/catalog/catalog_crypto_golden_test.dart`,
   `test/data/secrets_cipher_golden_test.dart`) und BlazeFace-Fixtures werden
   nicht angepasst, wenn sie brechen: dann ist die Implementierung inkompatibel.
2. **Modelle nur additiv und verlustfrei.** Jedes neue Feld in `jsonSchluessel`
   eintragen (auch gelesene Altschluessel), unbekannte Felder in
   `unbekannteFelder`, Enums ueber `leseEnumWert` + `_enumFelder`-Tabelle.
   Bestehende Objekte **nur per `copyWith`** aendern. Neue Modelle in
   `test/domain/unbekannte_verschachtelte_felder_test.dart` aufnehmen.
3. **Hashes schuetzen.** Felder nur bei Belegung ins JSON schreiben (sonst aendert
   sich `heroContentHash` bei jedem Bestandshelden und der Sync meldet
   Konflikte). Fixtures unter `test/fixtures/heroes/` und die Hash-Pins in
   `bestandshelden_kompatibilitaet_test.dart` nie anpassen; ein neues Format
   bekommt eine neue Datei. Zustaende nur ueber `heroStateContentHash` hashen.
4. **Frisch schreiben.** Bogen und Zustand nie als beim Rendern erfassten
   Snapshot speichern: frisch laden, nur die eigenen Felder aendern
   (`aendereHeldMitMeldung`, `aendereZustandMitMeldung`, `aendereHeldImEditor`,
   Ablaeufe). Eine Aenderung ruft nie selbst `saveHero`/`updateHero` auf.
   Ressourcenschritte zaehlen vom gespeicherten Wert. Jeder Ablauf schreibt
   genau ein Dokument (Ausnahme Import mit `Vorgangsjournal`).
5. **Sync.** Konflikte nie still ueberschreiben. Den Schreiber-Hash (`remoteHash`)
   nie als `localHash` merken. `AvatarBackfillService` ruft nie `saveHero`.
   Avatar-Dateinamen nie aus `heroId`/`entryId` bauen (`AvatarGalleryEntry.fileName`).
6. **Eigenschaften und Wunden.** Zauber-/Elixierquellen rechnen Eigenschaften
   nur ueber `effektiveTempAttributeMods`. Wundverluste wirken nur auf Proben
   (`probenEigenschaften`/`wendeWundVerlusteAn`), nie ueber `effectiveAttributes`.
   Vor-/Nachteile nur ueber `werteMerkmaleAus`, Herkunft nur ueber
   `werteHerkunftAus`; Startwerte/Maxima nur ueber `computeHeroEffectiveStartAttributes`/
   `computeHeroAttributeMaximums`.
7. **Katalog durchreichen.** Regelfunktionen verlangen `required RulesCatalog?
   catalog`: in `lib/` immer den vorhandenen Katalog uebergeben, `catalog: null`
   nur in Tests. Held-gebundene Leser nehmen `heroRulesCatalogProvider(heroId)`,
   nie `rulesCatalogProvider`. Ein Regelprofil wird nie automatisch geschrieben.
8. **Oberflaeche.** Keine Regelrechnung im Widget. Farbige Flaechen, die
   `ListTile`s aufnehmen, brauchen eine eigene `Material`-Schicht. Bestandsbausteine
   unterscheiden Themes ueber `kartoVariante(context)`, die klassische Optik bleibt
   unveraendert. Beide Themes muessen ineinander ueberblendbar bleiben
   (`TextStyle.lerp`, `inherit`).
9. **Riverpod.** Auf asynchrone Provider nie mit `ref.read(provider.future)`
   warten (Fehler enden nie); `ref.listenManual` auf den `AsyncValue`. Objekte
   in `AppStartupGate._buildScope` brauchen Wertgleichheit und stabile Instanz.
   Dialoge auf dem Root-Navigator schliessen sich selbst.
10. **Web/Plattform.** Web-Interop nur ueber `package:web` + `dart:js_interop`
    (bedingte Importe auf `dart.library.js_interop`, nie `dart.library.html`).
    Lokales Web-Debuggen mit `--web-port=5000`. `sqlite3` und `web/sqlite3.wasm`
    sowie `sqlite3_flutter_libs` nur gemeinsam bewegen.
11. **Qualitaet.** `flutter analyze` bricht auch bei `info`-Lints ab (CI). Tests
    seriell (`--concurrency=1`), Details in `docs/test_strategy.md`.
12. **Gruppen.** `gruppen/*` ist ein vollständig gesperrter Legacy-Pfad und
    wird nie clientseitig reaktiviert oder automatisch beansprucht.
    `groups_v2/*` ist UID-gebunden; Einladungen bleiben Backendoperationen.

## Themenindex (docs/hinweise/)

| Datei | Inhalt |
| --- | --- |
| [persistenz_modelle.md](docs/hinweise/persistenz_modelle.md) | hive_ce, AES, Krypto-Wire-Format, unbekannte Felder, Bestandshelden, Scope-Overrides |
| [inventar_ausruestung.md](docs/hinweise/inventar_ausruestung.md) | Slot-/Instanz-IDs, Menge/Stapel, Artefakte (Matrix, Spruchspeicher), Tränke und Elixiere |
| [regeln_herleitung.md](docs/hinweise/regeln_herleitung.md) | `Herleitung` (ARCH-04), Regelprofil am Helden, Wunden, Schaden erhalten/zurücknehmen, epische Boni, Kalender, Traditionen |
| [steigerung.md](docs/hinweise/steigerung.md) | Steigerungssitzung, Katalog mit fünf Bereichen, Fähigkeitenbaum, Eigenschaftsfolgen |
| [katalog_sonderfertigkeiten.md](docs/hinweise/katalog_sonderfertigkeiten.md) | Vor-/Nachteile, Herkunftsmodifikatoren, Begabung, Sonderfertigkeiten, Voraussetzungen, Hausregel-Pakete, geschützte Felder |
| [magie_effekte.md](docs/hinweise/magie_effekte.md) | Magische Kenntnisse, MAG-EFF (Zaubereffekte, Instanzen, Heilung, Schutz), laufende Effekte |
| [gefecht_begleiter.md](docs/hinweise/gefecht_begleiter.md) | Gefecht (UI2 und Regelmodule), Reittiere, Vertraute |
| [ui_oberflaeche.md](docs/hinweise/ui_oberflaeche.md) | Kartograph-Neubau, Workspace, Theme/Token, Planungsschutz, Bestandsvarianten, Tabellen |
| [schreibwege.md](docs/hinweise/schreibwege.md) | Abläufe (ARCH-05), Speichervertrag (ARCH-06), frisches Schreiben von Zustand und Bogen, Editorentwürfe |
| [sync_konto.md](docs/hinweise/sync_konto.md) | Konto-Sync, Konfliktregeln, Sync-Basis, Offline-Helden, Zustandsbindung |
| [web_avatare.md](docs/hinweise/web_avatare.md) | Avatare (Storage, Backfill, Gesichtserkennung), CORS, Web-Cache, Web-Debuggen |
| [plattform_werkzeuge.md](docs/hinweise/plattform_werkzeuge.md) | Web-Interop, Lints, Windows-Audit, Feedback als GitHub-Issue, Spielmodus/Regelnachschlag, SQLite |

## Weitere Dokumente

- `README.md` (Produktumfang, Architektur, Workflows), `docs/technical_overview.md`,
  `docs/test_strategy.md`, `docs/catalog_import_workflow.md`,
  `docs/pdf_agent_workflow.md`, `docs/rule_audit_regelwerk_ueberarbeitung.md`,
  `docs/ios_xcode_setup.md`, `docs/windows_antivirus_audit.md`,
  `docs/web_deployment.md`; `tool/sync_main_to_test.sh` mergt Main in Test.
- Sicherheitsbetrieb, App Check, Key-Einschränkungen und Incident-Ablauf:
  [security_operations.md](docs/security_operations.md).
- Öffentliche Rechtstexte, Verarbeitungstätigkeiten, TOM und Löschkonzept:
  [legal_privacy_operations.md](docs/legal_privacy_operations.md).
- [Architektur-Roadmap](docs/architecture_roadmap.md): nur Status und offene
  Punkte; abgenommene Aufgaben im [Archiv](docs/archiv/README.md). Bei
  Architekturarbeiten den Status pruefen und nach Teilumfaengen aktualisieren.
- Fachplaene: [Zaubereffekte](docs/zaubereffekte_integrationsplan.md),
  [Gefecht](docs/gefecht_implementation.md),
  [Gefechtslage](docs/gefecht_lage_konzept.md), [Reittiere](docs/reittier_plan.md),
  [Vertraute](docs/vertraute_plan.md), [Redesign](docs/redesign_implementation.md)
  mit [Abnahme](docs/redesign_acceptance.md), [Schreibpfade](docs/schreibpfade_inventar.md),
  [ARCH-06-Abnahme](docs/arch06_abnahme.md), [Magische Kenntnisse](docs/magische_kenntnisse.md),
  [Spielmodus](docs/spielmodus_konzept.md), [Feedback](docs/feedback_github_plan.md).
- Assets: [Waffensymbole](docs/fantasy_weapon_assets.md),
  [Fantasy-Assets](docs/fantasy_assets.md). Mockups: [docs/mockups/](docs/mockups/README.md).
- Die frühere lange Einstiegsliste steht in
  [fruehere_einstiegsliste.md](docs/hinweise/fruehere_einstiegsliste.md).

## Pflegehinweis

Diese Datei bleibt klein. Neue Regeln, die bei Verstoss Daten kosten, kommen als
Kurzpunkt unter „Harte Regeln“; alles andere in die passende Datei unter
`docs/hinweise/` (mit Verweis im Index) oder in `docs/`. Schnell veraltende
Details gehoeren weder hierher noch in die Hinweise: Architektur-, Workflow-
oder Fachaenderungen in `README.md` bzw. `docs/` nachfuehren.
