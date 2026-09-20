# To-do-Liste: Weiterentwicklung der Heldenverwaltung

Stand: 18.09.2026. Grundlage ist die Diskussion „Wenn du die App komplett neu
bauen würdest, was würdest du anpassen?“ und der anschließende Auftrag, alle
sieben Vorschläge für nachfolgende Agenten festzuhalten.

Diese Liste beschreibt geplante Verbesserungen, keine bereits umgesetzte
Architektur. Der aktuelle Auftrag umfasst ausschließlich ihre Dokumentation.
Die Bestandsaufnahme beruht auf Code und Dokumentation; die laufende Oberfläche
wurde dafür nicht praktisch geprüft. Vor einer Umsetzung den jeweiligen
Ist-Zustand erneut prüfen und den konkreten Teilumfang festlegen.

## Arbeitsweise und gemeinsame Grenzen

- Verbindlich bleibt [AGENTS.md](../AGENTS.md). Die Aufgaben sollen schrittweise
  in der bestehenden App umgesetzt werden. Ein vollständiger Neubau ist durch
  diese Liste nicht beschlossen.
- Flutter und Riverpod sowie die Trennung zwischen `HeroSheet`, `HeroState`
  und reinen Regelberechnungen beibehalten. Berechnungen gehören weiterhin
  ausschließlich nach `lib/rules/derived/`.
- Die kanonischen Katalogquellen bleiben die Split-JSON-Dateien unter
  `assets/catalogs/house_rules_v1/`. Bestehende Regelmodule und Tests weiterverwenden.
- Vor Änderungen an gespeicherten Modellen Migration, JSON-Import/-Export und
  Sync-Kompatibilität festlegen. Unbekannte Bestandsdaten erhalten und unklare
  Zuordnungen sichtbar machen. Bestehende Krypto-Wire-Formate unverändert lassen.
- Offene Produktentscheidungen sind pro Aufgabe benannt. Bei ihrer Umsetzung
  anhand des dann gültigen Auftrags klären; sie gelten hier nicht als entschieden.
- Pro abgeschlossenem Teilumfang Tests, Dokumentation und Commit gemeinsam
  abschließen. Ergebnis mit Aufgaben-ID und Commit in dieser Liste nachführen;
  relevante Erkenntnisse nach Duplikatprüfung in Mempalace hinterlegen.

## Übersicht und Reihenfolge

Die IDs entsprechen den sieben Punkten der ursprünglichen Empfehlung.
„Grundlage“ bezeichnet technische Vorarbeiten, „Aufbau“ darauf aufsetzende
Verbesserungen und „Begleitend“ fortlaufende Absicherung.

- [ ] **ARCH-01 — Oberfläche nach Spielsituationen organisieren** · Aufbau
- [ ] **ARCH-02 — Regelrelevante Eigenschaften strukturiert speichern** · Grundlage
- [ ] **ARCH-03 — Gemeinsame Ausrüstungsdaten für Inventar und Kampf** · Grundlage
- [ ] **ARCH-04 — Versionierte Regelprofile und erklärbare Berechnungen** · Aufbau
- [ ] **ARCH-05 — Schreibende Aktionen fachlich aufteilen** · Grundlage
- [ ] **ARCH-06 — Zusammengehörige Änderungen gemeinsam speichern und synchronisieren** · Aufbau
- [ ] **ARCH-07 — Nutzerabläufe und Datenmigrationen absichern** · Begleitend

Empfohlener Einstieg: unter ARCH-07 repräsentative Bestandsfälle sichern, dann
ARCH-02 und ARCH-03 in getrennten Teilprojekten bearbeiten. ARCH-05 kann zunächst
bestehendes Verhalten ohne Modellwechsel entflechten. ARCH-04 baut auf den
strukturierten Daten auf; ARCH-06 nutzt die fachlichen Operationsgrenzen aus
ARCH-05. Die Umsetzung von ARCH-01 folgt diesen Grundlagen, während die Prüfung
der Bedienabläufe und ein Oberflächenentwurf schon früher möglich sind.
ARCH-07 begleitet jede Phase und wird nicht erst am Ende begonnen.

Für den bereits begonnenen Oberflächen-Neubau konkretisieren die
[Redesign-Pläne R1–R3](redesign_implementation.md) einen früher lieferbaren
UI-Teilumfang von ARCH-01 auf vorhandenen Modellen und Aktionen. Dieser
Teilumfang benötigt keine vorgezogene Datenmigration. Erweiterungen wie
strukturierte Merkmale, Regelprofile und atomarer Schaden mit Korrektur bleiben
an ihre hier genannten Grundlagen gebunden; ARCH-07 begleitet auch R1–R3.

## ARCH-01 — Oberfläche nach Spielsituationen organisieren

**Ist-Zustand:** Der Workspace ist nach Fachgebieten wie Talente, Kampf, Magie
und Inventar gegliedert. Bearbeiten und Steigern sind bereits getrennt;
Steigerungsrunden, Proben-Schnellsuche und Inspector existieren.

**Ziel:** Drei verständliche Arbeitsbereiche: **Spielen**, **Held verwalten**
und **Entwicklung planen**. Spielen priorisiert Ressourcen, häufige Proben,
Kampfaktionen und aktive Effekte. Verwaltung erschließt die vollständigen Daten
und manuelle Korrekturen. Entwicklung bündelt Erwerb, Voraussetzungen, AP und
Auswirkungsvorschau.

**Einstieg:** `lib/ui/screens/hero_workspace_screen.dart`,
`lib/ui/screens/workspace/workspace_tab_spec.dart`,
`lib/ui/screens/workspace/probe_quick_search.dart`,
`lib/ui/screens/workspace/inspector/`, `lib/ui/screens/advancement/` und
[Spielmodus-Konzept](spielmodus_konzept.md).

**Entwurfsstand 19.09.2026:** Ein [klickbares Codex-Mockup](mockups/hero-workspace-redesign.html)
zeigt die drei Arbeitsbereiche mit Beispieldaten. Bedienung und Abgrenzungen
stehen in der [Mockup-Anleitung](mockups/README.md). Es ist ein visueller Entwurf;
die Flutter-Umsetzung und die vollständige Funktionszuordnung bleiben offen.

- [ ] Vorhandene Aktionen den drei Arbeitsbereichen zuordnen und Navigation für
  schmale sowie breite Ansichten entwerfen; aktuelle Funktionen vollständig erfassen.
- [ ] Bestehende Proben-, Steigerungs- und Inspector-Komponenten wiederverwenden;
  die Spielansicht um direkten Zugriff auf häufige Aktionen ergänzen.
- [ ] „Schaden erhalten“ als zusammenhängenden Ablauf mit Ressourcenänderung,
  gegebenenfalls Wunden und nachvollziehbarer Korrekturmöglichkeit anbieten.

**Abnahme:** Häufige Spielaktionen sind direkt aus der Spielansicht erreichbar.
Manuelle Korrektur und AP-pflichtige Entwicklung bleiben unterscheidbar. Ein
Bereichswechsel verliert keine ungespeicherten Eingaben oder Steigerungsentwürfe.
Der Schadensablauf verwendet dieselben Regeln wie die übrige App.

**Prüfung:** Widgettests unter `test/ui/workspace/`, `test/ui/advancement/` und
`test/ui/shared/`; Bedienprüfung auf schmalen und breiten Fenstern. Neue fachliche
Schadensregeln separat unter `test/rules/` prüfen.

**Umsetzungsstand 19.09.2026:** Die Flutter-Umsetzung hat als
Oberflächen-Neubau begonnen. Bestand (`lib/ui/`) und Neubau (`lib/ui2/`)
laufen parallel, `AppSettings.oberflaeche` schaltet um. Fertig sind:

- **Aufräumen.** Toter Legacy-Screen entfernt, UI-Variante `klassisch` samt
  zweitem Theme gestrichen.
- **Naht und Umschalter.** `AppRootSwitch` als `child` von `SyncConflictGate`;
  ein Wechsel tauscht nur den Bildschirm und baut Heldenspeicher, Sync und
  Katalog nicht neu auf (`test/ui2/shell/app_root_switch_test.dart`).
- **Token-Schicht.** Farb-, Abstands-, Linien- und Schriftskalen unter
  `lib/ui2/theme/` und `lib/ui2/foundation/`, Sichtprüfung über das
  Token-Blatt. Dabei fiel auf, dass Merriweather und Cinzel ihren Fettschnitt
  nur behaupten: Regular und 700 zeigen in `pubspec.yaml` auf dieselbe Datei.
  Der Neubau verhindert das durch zwei Tests, einen auf das Manifest und einen,
  der die Zeichenbreiten misst.

**Planungsstand nach Mockup-Freigabe, 19.09.2026:** Die
[Umsetzungspläne mit Agentenprompts](redesign_implementation.md) setzen auf dem
vorhandenen UI2-Fundament auf. Für diese Folgeaufträge gelten die **drei
Arbeitsbereiche des freigegebenen Mockups**. Damit wird der ältere Vorschlag
mit zwei Bereichen ersetzt. Entwicklung bleibt technisch eine Sitzung, erhält
aber einen eigenen sichtbaren Bereich. R1–R3 decken den ersten produktiven
UI-Stand ab, nicht den zusätzlichen atomaren Schadensablauf.

**Umsetzungsstand 20.09.2026 — Paket R1 fertig:** Der Neubau ist ein
benutzbarer Rahmen mit echten Helden. Umgesetzt sind die drei Arbeitsbereiche
mit dunkler Navigation, die Heldenwahl über die vorhandenen Provider und der
Schutz ungespeicherter Eingaben bei Modus-, Helden- und Oberflächenwechsel
einschließlich System-Zurück. Tabs, Editoraktionen und Leave-Guard der
Verwaltung liegen jetzt im gemeinsamen `WorkspaceManagementCoordinator`, den
beide Oberflächen benutzen; die vollständigen Fachansichten erreicht der
Neubau vorerst über die injizierte Brücke `KartoBestandsAdapter`. Nachweise,
Commit-IDs und Abgrenzungen stehen unter „R1: Übergabe“ in den
[Umsetzungsplänen](redesign_implementation.md).

**ARCH-01 bleibt trotzdem offen.** Die Spielanordnung mit echten Werten und
Bestandsaktionen ist inzwischen umgesetzt (R2). Die gestalterische Integration
der Fachansichten steht aus (R3), und „Schaden erhalten“ als zusammenhängender
Ablauf mit nachvollziehbarer Korrektur fehlt weiterhin — er hängt an ARCH-05
und ARCH-06 und ist kein UI-Teilumfang.

**Abhängigkeiten / offene Entscheidungen:** Schreibende Spielaktionen auf
ARCH-05/06 aufbauen. Navigation, Favoritenverhalten und Korrekturbedienung sind
noch zu konkretisieren. Die im Spielmodus-Konzept vereinbarte Spielerrolle
beibehalten; eine Spielleiterverwaltung ist kein impliziter Bestandteil.

## ARCH-02 — Regelrelevante Eigenschaften strukturiert speichern

**Ist-Zustand:** Vor- und Nachteile sind katalogisiert, werden am Helden aber in
`HeroSheet.vorteileText` und `HeroSheet.nachteileText` gespeichert. Regelwirkungen
werden teilweise aus diesen Texten und Herkunftsmodifikator-Texten geparst.

**Ziel:** Regelrelevante Merkmale über stabile Katalog-IDs mit Stufe, Auswahl und
definierten Wirkungen speichern. Anzeigenamen und beschreibender Freitext sind
unabhängig davon. Voraussetzungen, AP-Kosten und Berechnungen verwenden dieselben
strukturierten Angaben.

**Einstieg:** `lib/domain/hero_sheet.dart`, `lib/catalog/hero_trait_text.dart`,
`lib/catalog/hero_trait_choices.dart`, `lib/rules/derived/modifier_parser.dart`,
`lib/rules/derived/attribute_trait_rules.dart`,
`lib/rules/derived/hero_stat_inputs.dart`,
`assets/catalogs/house_rules_v1/vorteile.json` und `nachteile.json` im selben Ordner.

- [ ] Ein Modell für erworbene Merkmale samt Stufe, Auswahl, Herkunft und
  Verknüpfung mit dem Katalog definieren; zunächst Vor- und Nachteile abdecken.
- [ ] Eine versionierte Migration aus den Textfeldern entwickeln: eindeutige
  Treffer zuordnen, Mehrdeutigkeiten und unbekannte Texte unverändert erhalten
  und zur Prüfung anzeigen. Migration darf beim erneuten Laden nichts verdoppeln.
- [ ] Regelauswertung, Erwerbsprüfung und Bearbeitung auf strukturierte Einträge
  umstellen; doppelte Anwendung aus Alttext und neuem Eintrag ausschließen.

**Abnahme:** Umbenennung eines Katalogeintrags verändert seine Wirkung nicht.
Stufen und Varianten bleiben beim Speichern sowie Import/Export erhalten.
Bestandshelden behalten ihre Werte, sofern keine ausdrücklich begründete
Regelkorrektur vorliegt. Unbekannte Freitexte gehen nicht verloren.

**Prüfung:** Bestehende Parser- und Merkmalsregeltests unter `test/rules/`,
Katalogtests unter `test/catalog/`, Modelltests unter `test/domain/` sowie
`test/data/hero_actions_import_export_test.dart` um Migrationsfälle ergänzen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-07 liefert Bestandsfixtures.
Schema, Behandlung eigener regelwirksamer Merkmale und Übergangsformat sind zu
entscheiden. Herkunftsmerkmale als eigenen Folgeschritt abgrenzen. Der Parser
bleibt während der Übergangsphase als Import-/Kompatibilitätshilfe verfügbar.

## ARCH-03 — Gemeinsame Ausrüstungsdaten für Inventar und Kampf

**Ist-Zustand:** Kampfausrüstung und Inventar werden über
`reconcileInventoryWithCombat` abgeglichen. Verknüpfungsschlüssel für Waffen,
Rüstung und Geschosse enthalten Namen; es bestehen mehrere Darstellungen eines
Gegenstands mit unterschiedlichen Zuständigkeiten für seine Felder.

**Ziel:** Jeden konkreten Gegenstand einmal mit stabiler Instanz-ID speichern.
Kampfkonfiguration und Ausrüstungsplätze referenzieren ihn. Eine Katalog-ID
beschreibt den Gegenstandstyp, eine Instanz-ID das konkrete Exemplar.

**Einstieg:** `lib/domain/hero_inventory_entry.dart`, `lib/domain/combat_config/`,
`lib/rules/derived/inventory_sync_rules.dart`,
`lib/rules/derived/inventory_modifier_rules.dart`, `lib/state/hero_actions.dart`,
`lib/ui/screens/hero_inventory/` und `lib/ui/screens/hero_combat/`.

- [ ] Zuständigkeiten für Gegenstandseigenschaften, Menge und ausgerüstete Slots
  festlegen und ein gemeinsames Modell mit stabilen Referenzen einführen.
- [ ] Vorhandene Kampf-/Inventareinträge migrieren; gleichnamige Exemplare,
  individuelle Eigenschaften und Geschossmengen verlustfrei erhalten.
- [ ] Umbenennen, Ablegen, Verkaufen und Ausrüsten auf das gemeinsame Modell
  umstellen; den namensbasierten Abgleich nach abgesicherter Migration ablösen.

**Abnahme:** Zwei gleichnamige Waffen bleiben unabhängig bearbeitbar. Umbenennen
ändert keine Zuordnung und verliert keine Zusatzdaten. Entfernen eines
Gegenstands hinterlässt keine ungültigen Slot-Referenzen. Kampfwerte und
Inventarmodifikatoren beziehen sich konsistent auf die tatsächlich ausgerüsteten
Exemplare; Import/Export erhält IDs und Verknüpfungen.

**Prüfung:** `test/domain/hero_inventory_entry_model_test.dart`, vorhandene
Inventar-/Kampfregeltests unter `test/rules/`, `test/ui/inventory/` und
Import-/Exporttests um Migration, Namensgleichheit und Slotwechsel ergänzen.

**Abhängigkeiten / offene Entscheidungen:** Bestandsfälle aus ARCH-07 nutzen.
Mengenstapel, aufgeteilte Munition und Identitätsregeln beim Kopieren eines Helden
vor der Modelländerung klären. Schreibvorgänge mit ARCH-05/06 abstimmen.

## ARCH-04 — Versionierte Regelprofile und erklärbare Berechnungen

**Ist-Zustand:** Aktive Hausregelpakete werden aus gemeinsamen Einstellungen
aufgelöst. `ModifierSourceBreakdown` erklärt bereits einen Teil der
Modifikatorherkunft; eine einheitliche Herleitung aller Regelwerte fehlt.

**Ziel:** Helden erhalten ein explizites Regelprofil mit festgelegten
Paketversionen. Gruppen können eine gemeinsame Vorgabe liefern. Ein Regelupdate
zeigt vor Übernahme seine Auswirkungen. Berechnungen liefern neben Ergebnissen
ihre Basis, Modifikatoren, Bedingungen und Quellen.

**Einstieg:** `lib/state/house_rules_providers.dart`,
`lib/state/catalog_providers.dart`, `lib/catalog/house_rule_pack.dart`,
`lib/catalog/house_rule_catalog_resolver.dart`,
`lib/catalog/house_rule_provenance.dart`, `lib/domain/hero_sheet.dart`,
`lib/rules/derived/modifier_source_breakdown.dart` und
[Katalog-Workflow](catalog_import_workflow.md).

- [ ] Profilzuordnung, Versionierung und Auflösung definieren; Bestandshelden
  mit ihrem bisher wirksamen Regelsatz übernehmen.
- [ ] Vorschau für Profil-/Paketupdates implementieren: geänderte Werte und
  Erwerbsvoraussetzungen anzeigen, erst durch Übernahme verbindlich machen.
- [ ] Ein gemeinsames Ergebnisformat für Regelherleitungen einführen und
  schrittweise auf Basiswerte, Kampf, Talente, Magie und Steigerungen anwenden.
  Die UI zeigt die Herleitung aus dem Regelmodul, ohne sie selbst nachzurechnen.

**Abnahme:** Zwei Helden mit verschiedenen Profilen können parallel geöffnet
werden, ohne einander zu beeinflussen. Gleiche Eingaben und Regelversionen
liefern reproduzierbare Ergebnisse. Ein Update verändert den Helden erst nach
Übernahme; angezeigte Herleitung und tatsächlich verwendeter Wert stimmen überein.

**Prüfung:** `test/state/house_rules_providers_test.dart`,
`test/catalog/house_rule_catalog_resolver_test.dart` sowie Regel- und UI-Tests
für Profilwechsel, Updatevorschau und Herleitungen ergänzen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-02/03 erleichtern eindeutige
Wirkungsquellen. Gruppenvererbung gegenüber einer festen Profilkopie, Aufbewahrung
alter Paketstände und Verhalten bei fehlenden Paketen klären. Import/Export und
Sync müssen die reproduzierbare Profilzuordnung mittragen.

## ARCH-05 — Schreibende Aktionen fachlich aufteilen

**Ist-Zustand:** `HeroActions` bündelt unter anderem Erstellung, Normalisierung,
Speichern, Import/Export und Avataroperationen. `SyncingHeroRepository` verbindet
lokale Speicherung, Remote-Abgleich und Konfliktbehandlung. Beide bündeln viele
Verantwortlichkeiten und erschweren isolierte Änderungen.

**Ziel:** Kleine, fachlich benannte Anwendungsabläufe wie „Steigerungsrunde
übernehmen“, „Ausrüstung wechseln“, „Rast abschließen“ und „Held importieren“.
Sie koordinieren Prüfung und Speicherung; Regelberechnungen bleiben in den
Regelmodulen. Riverpod bindet die Abläufe an die Oberfläche.

**Einstieg:** `lib/state/hero_actions.dart`,
`lib/state/advancement_providers.dart`, `lib/data/hero_repository.dart`,
`lib/data/syncing_hero_repository.dart`,
`lib/ui/screens/workspace/rest_dialog.dart` und `lib/rules/derived/advancement_apply.dart`.

- [ ] Schreibpfade inventarisieren und pro Ablauf Eingaben, Ergebnis,
  Vorbedingungen, Seiteneffekte und Speichergrenzen festhalten.
- [ ] Einen abgegrenzten Ablauf zunächst ohne Verhaltensänderung extrahieren,
  mit expliziten Abhängigkeiten statt uneingeschränktem Zugriff auf alle Provider.
- [ ] Weitere Abläufe nach demselben Prinzip entflechten; bestehende Aufrufer
  schrittweise migrieren und benötigte Kompatibilitätseinstiege erhalten.

**Abnahme:** Abläufe sind ohne gerenderte Oberfläche prüfbar. Normalisierung und
Validierung haben je eine klare Zuständigkeit. Widgets und Provider enthalten
keine neu duplizierten Regelberechnungen. Fehler beim Speichern werden an die
aufrufende Oberfläche weitergegeben; bisheriges Verhalten bleibt abgesichert.

**Prüfung:** Betroffene Tests unter `test/state/` und `test/data/`, insbesondere
`test/state/advancement_session_test.dart`, sowie die jeweiligen Widgettests.

**Abhängigkeiten / offene Entscheidungen:** Kann mit einer verhaltenserhaltenden
Extraktion beginnen. Zuschnitt und Ablage der Anwendungsschicht am ersten
konkreten Ablauf festlegen; keine zusätzlichen Schichten ohne klaren Nutzen.
Operationsgrenzen bilden die Grundlage für ARCH-06.

## ARCH-06 — Zusammengehörige Änderungen gemeinsam speichern und synchronisieren

**Ist-Zustand:** Heldenblatt und Spielzustand werden getrennt gespeichert und
synchronisiert. Steigerungsrunden bündeln bereits Werte, AP/SE und Historie im
Heldenblatt. Die Sync-Logik bindet zugehörige Zustandskonflikte an Heldenkonflikte;
diese Schutzmechanismen müssen erhalten bleiben.

**Ziel:** Fachlich zusammengehörige Änderungen als Einheit behandeln, auch bei
Abbruch oder Neustart. Ein Änderungsprotokoll und eine dauerhafte Warteschlange
machen lokale Änderungen, ausstehenden Sync und Korrekturen nachvollziehbar.
Der Betrieb ohne Konto oder Netzwerk bleibt möglich.

**Einstieg:** `lib/data/hero_repository.dart`, `lib/data/hive_hero_repository.dart`,
`lib/data/syncing_hero_repository.dart`, `lib/data/sync/`,
`lib/domain/sync_models.dart`, `lib/domain/hero_advancement_entry.dart` und
`lib/ui/screens/sync_conflict_gate.dart`.

- [ ] Für die Abläufe aus ARCH-05 festlegen, welche Daten gemeinsam verbindlich
  werden müssen, und einen geeigneten Speichervertrag mit Wiederanlauf definieren.
- [ ] Lokale Änderung und ausstehenden Sync dauerhaft zusammen erfassen;
  wiederholte Übertragung darf eine Aktion nicht erneut anwenden.
- [ ] Änderungsprotokoll und fachlich gültige Korrekturaktionen ergänzen.
  Unabhängige Änderungen nur nach definierten Konfliktregeln zusammenführen;
  widersprüchliche Änderungen bleiben sichtbar entscheidbar.

**Abnahme:** Ein Abbruch hinterlässt keine halbe fachliche Buchung. Ein Neustart
verliert keinen ausstehenden Abgleich. Wiederholungen buchen keine AP und keinen
Schaden doppelt. Heldenblatt und zugehöriger Zustand werden bei Konflikten nicht
unbemerkt aus widersprüchlichen Versionen kombiniert. Korrekturen bleiben im
Verlauf erkennbar; bereits übernommene Steigerungshistorie wird nicht gelöscht.

**Prüfung:** Fehler- und Wiederanlauftests in `test/data/`, insbesondere
`syncing_hero_repository_test.dart`, Gateway-/Transporttests sowie
`test/ui/screens/sync_conflict_gate_test.dart`. Zwei simulierte Geräte mit
gemeinsamer Ausgangsversion und unabhängigen bzw. konkurrierenden Änderungen prüfen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-05 definiert die Einheiten;
ARCH-02/03/04 beeinflussen gespeicherte Referenzen. Speichertechnik, Remote-Protokoll,
Granularität der Zusammenführung und zulässige Korrekturen gesondert entscheiden.
Ein Datenbankwechsel ist mit dieser Liste nicht beschlossen. Die vorhandenen
nativen und REST-Sync-Pfade berücksichtigen.

## ARCH-07 — Nutzerabläufe und Datenmigrationen absichern

**Ist-Zustand:** Regel-, Domain-, Daten-, Provider- und Widgettests sind bereits
getrennt vorhanden. Die CI prüft unter anderem Analyse, Tests und einen
Android-Build. Für den Umbau braucht es zusätzlich gezielte Nachweise über
vollständige Abläufe, alte Datenformate und unterbrochene Synchronisierung.

**Ziel:** Repräsentative Bestandshelden und kritische Nutzerabläufe sichern die
schrittweise Weiterentwicklung ab. Die Trennung der Testverantwortlichkeiten aus
der [Teststrategie](test_strategy.md) bleibt erhalten.

**Einstieg:** `test/domain/hero_sheet_model_test.dart`,
`test/data/hero_actions_import_export_test.dart`,
`test/data/syncing_hero_repository_test.dart`, `test/state/advancement_session_test.dart`,
`test/ui/smoke/widget_test.dart` und `.github/workflows/flutter-tests.yml`.

- [ ] Kleine, anonymisierte bzw. synthetische Bestandsfixtures mit erwarteten
  Ergebnissen anlegen: normale, magische/karmale und epische Helden, eigene
  Textmerkmale, gleichnamige Ausrüstung und ältere Schema-Versionen.
- [ ] Den Ablauf „importieren → steigern → ausrüsten → Spielaktion → schließen
  → wieder öffnen → exportieren“ auf Erhalt der gespeicherten Daten absichern.
  Tests für jede neue Migration direkt im jeweiligen Modellumbau ergänzen.
- [ ] Unterbrochenen Sync, Wiederholung und Konflikte zweier Geräte reproduzierbar
  testen; automatisierte Prüfungen und nötige manuelle Plattformprüfungen in der
  Teststrategie sowie der CI nachvollziehbar verorten.

**Abnahme:** Jede eingeführte Migration hat einen Bestandsfall und einen Test
für erneutes Laden ohne weitere Veränderung. Kritische Abläufe prüfen reale
Speicher-/Ladegrenzen. Erwartungen für Regelwerte stehen in Regeltests, während
UI-/Ablauftests Navigation, Persistenz und Fehlerbehandlung prüfen. Abgedeckte
Plattformen und verbleibende manuelle Prüfungen sind ausdrücklich dokumentiert.

**Abhängigkeiten / offene Entscheidungen:** Vor ARCH-02/03 mit Fixtures beginnen
und alle Aufgaben begleiten. Umfang echter Integrationstests, Geräteauswahl und
CI-Ausführung anhand der betroffenen Plattformpfade konkretisieren.

## Abschluss und Übergabe je Aufgabe

Eine Aufgabe erst in der Übersicht abhaken, wenn ihre Abnahmekriterien erfüllt
und die zugehörigen Prüfungen erfolgreich sind. Bei Teilergebnissen bleibt der
Hauptpunkt offen. Unter dem jeweiligen Abschnitt ergänzen:

- umgesetzter Teilumfang und Datum;
- zugehörige Commits und gegebenenfalls weiterführender Detailplan;
- tatsächlich ausgeführte Prüfungen und Ergebnis;
- verbleibende Entscheidungen, Risiken und nächster konkreter Schritt.

Als Mindestprüfung gelten `flutter analyze` und die relevanten `flutter test`-
Läufe gemäß AGENTS.md. README, CLAUDE.md und betroffene Dokumentation im selben
Commit aktualisieren. Diese Liste hält Aufgabenstatus und offene Arbeit fest;
die technische Gesamtdokumentation beschreibt weiterhin das tatsächlich
implementierte Verhalten.
