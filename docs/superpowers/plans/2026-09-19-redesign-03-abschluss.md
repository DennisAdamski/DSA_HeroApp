# R3: Verwaltung, Entwicklung und Gesamtabnahme — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task.
> Steps use checkboxes for tracking. R1 and R2 must be integrated first.

**Goal:** Verwaltung und AP-Planung passen zum neuen Workspace; alle bisherigen
Funktionen bleiben erreichbar und der gesamte Redesign-Zwischenstand ist geprüft.

**Architecture:** R1-Navigation und Bestandsadapter weiterführen. Fachansichten
gestalterisch integrieren, vorhandene `AdvancementSession` als einzige
Entwurfsquelle verwenden. Keine zweite Steigerungs- oder Inventarlogik.

**Tech Stack:** Flutter, Riverpod, Karto-/Codex-ThemeExtensions, vorhandene
Advancement-Provider und Regeltests, Widgettests und visuelle Flutter-Abnahme.

**Spec:** [Umsetzungsspezifikation](../specs/2026-09-19-codex-redesign-design.md)
und [Übergaben R1/R2](../../redesign_implementation.md).

## Global Constraints

- AGENTS/CLAUDE, aktuellen Status/Diff und integrierte Vorgänger prüfen.
- Bestehende Speicherung, Kryptoformate und Split-JSON-Kataloge unverändert.
- Der Umfang ist die Benutzeroberfläche. Merkmalsmigration, Inventarinstanz-IDs,
  Regelprofile, Outbox und konfliktfestes Undo bleiben separate Roadmap-Aufträge.
- R1 hat bereits Start/Commit/Discard der Sitzung verdrahtet. Diesen Weg
  verbessern und testen, nicht einen zweiten Controller oder Commitpfad bauen.
- Kein Löschen des Bestands, keine automatische Aktivierung für alle Nutzer.
- Jede abgeschlossene Aufgabe mit `flutter analyze`, relevanten Tests,
  Dokumentation und gezieltem Commit abschließen.

## Aufgabe 1: Verwaltungsansichten gestalterisch integrieren

**Anlegen:** `lib/ui/bridges/karto_compat_theme.dart`,
`test/ui2/shell/karto_verwaltung_test.dart`,
`test/ui/bridges/karto_compat_theme_test.dart`.

**Ändern:** Adapterimplementierung, `WorkspaceManagementBody` aus R1,
gezielt gemeinsame Bestandsbausteine unter `lib/ui/widgets/`, soweit für
Lesbarkeit und responsive Anordnung nötig. Änderungen pro Baustein begrenzen.

- [ ] Zuerst Bestandsparität testen: alle sichtbaren Abschnitte aus
  `workspace_tab_spec.dart` erreichbar, dieselben Fachaktionen registriert.
  Magie bleibt abhängig von der bestehenden Sichtbarkeitsregel.
- [ ] Neue Darstellung auf bestehende Farbrollen abbilden, damit übernommene
  Widgets nicht unbemerkt in das alte Standardtheme zurückfallen. Funktion
  `ThemeData buildKartoCompatTheme(ThemeData base)` in der Bridge-Schicht:
  `KartoTheme` aus `base` lesen, `CodexTheme` als zusätzliche Extension setzen,
  andere Extensions und Schriftstile erhalten. UI2 importiert diese Funktion
  nicht selbst; der Adapter wendet sie um Bestandsinhalte/Dialoge an.
- [ ] Mapping als konkrete Ausgangsbasis: `parchment → blatt`,
  `parchmentStrong → senke`, `panel → feld`, `panelRaised → senke`,
  `ink → schrift`, `inkMuted → schriftLeise`, `brass/accent → meer`,
  `brassMuted/rule → hoehenlinie`, `success → moos`, `warning → wachs`,
  `danger → siegel`. Beide Gradients mit identischen Start-/Endfarben aus
  `blatt` beziehungsweise `senke` bilden, Radien auf `kKartoRadius`,
  `showDecoration: false`. Lesbarkeit und Themenübergang testen.
- [ ] Theme testet erhaltenes `KartoTheme`, passendes Hell/Dunkel, gleichbleibende
  TextStyle-`inherit`-Werte und unauffällige Animation. Nicht das appweite
  Codex-Theme verändern oder erneut Cinzel/Merriweather in UI2 einführen.
- [ ] Kopfzeilen vereinheitlichen: Titel, erläuternder Text, passende
  Abschnittsaktion. Hinzufügen gemäß AGENTS als `+ <Singular>` im Kopf.
  Datenwerte ausrichten, numerische Spalten mit Tabellenziffern; Breiten aus
  dem vorhandenen adaptiven Tabellenverhalten statt starrer Desktopwerte.
- [ ] Inventar, Biografie und Merkmale aus dem Mockup mit realen Ansichten
  prüfen. Namen/Freitexte bleiben unverändert erhalten; bestehende
  Katalog-Picker verwenden. Keine neuen strukturierten Trait-IDs behaupten.
- [ ] Sperrverhalten aus R1 verbessern, soweit vorhandene Edit-Verträge
  differenzierte Deaktivierung erlauben. Beim offenen AP-Entwurf bleiben
  tatsächlich sämtliche manuellen HeroSheet-Schreibwege gesperrt.
- [ ] Pro Verwaltungskategorie mindestens Erreichbarkeit prüfen; für Übersicht,
  Inventar und Notizen zusätzlich Speichern/Abbrechen und Fehlerfälle. Die
  bestehenden Fachtests für Kampf/Magie/Gruppe bleiben grün.
- [ ] Ausführen: `flutter test test/ui2 test/ui/bridges test/ui/workspace
  test/ui/overview test/ui/inventory test/ui/talents test/ui/combat
  test/ui/magic test/ui/gruppe` und `flutter analyze`.
- [ ] Commit: `ui2: Bestandsverwaltung in die Kartograph-Gestaltung integrieren`.

## Aufgabe 2: Entwicklung als vollständigen Arbeitsbereich ausarbeiten

**Anlegen:** `lib/ui2/entwicklung/karto_entwicklungsansicht.dart`,
`test/ui2/entwicklung/karto_entwicklungsansicht_test.dart`.

**Ändern:** `karto_workspace.dart`, Adapterimplementierung; bei Bedarf
bestehende reine Darstellungsbausteine unter `lib/ui/screens/advancement/`.

**Lesen:** `lib/state/advancement_providers.dart`,
`advancement_catalog.dart`, `advancement_history_panel.dart`,
`advancement_impact_panel.dart`, `advancement_activation_sheet.dart`,
`advancement_skill_tree_view.dart`, `advancement_catalog_actions.dart`.

- [ ] Zuerst Verhaltenstests auf Basis von `advancement_workspace_test.dart`
  und `advancement_session_test.dart` erstellen. Den echten Provider mit
  FakeRepository verwenden; `commit` nicht vollständig wegmocken.
- [ ] `KartoEntwicklungsansicht({super.key, required String heroId,
  required KartoBestandsAdapter bestand})` bauen: Katalog und Erwerbsaktionen
  zentral, Plan/AP/Historie im Kontextbereich. Auf Mobil als erreichbar
  beschriftetes Detail-Sheet oder Abschnitt; keine 900-dp-Zweispaltenzwänge.
- [ ] Werte direkt aus Sitzung lesen: `base.apAvailable`, `apReserved`,
  `preview.apAvailable`, `entries`, `errors`, `isSaving`, `canCommit`.
  Die UI subtrahiert AP nicht noch einmal. Fehler eines einzelnen Eintrags
  bleiben sichtbar; Entfernen löst das bestehende Replay aus.
- [ ] Beispiel für die verbindliche Anzeige, keine neue Kostenrechnung:

```dart
Text('Frei zu Beginn: ${session.base.apAvailable} AP');
Text('Reserviert: ${session.apReserved} AP');
Text('Danach verfügbar: ${session.preview.apAvailable} AP');
```

- [ ] Bestehendes Erwerbsblatt, Varianten, Sondererfahrung, Fähigkeitenbaum,
  Voraussetzungen und Auswirkungsvorschau erreichbar halten. Eine kleine
  Mockup-Auswahl darf den vollständigen Steigerungskatalog nicht ersetzen.
- [ ] „Änderungen übernehmen“ ist nur bei `canCommit` aktiv. Während
  `isSaving` sämtliche Planänderungen und Mehrfachübernahme sperren. Erfolg
  nach abgeschlossenem Commit anzeigen, Fehler am erhaltenen Entwurf zeigen.
- [ ] Mindestens folgende realen Szenarien prüfen: Vormerken verändert den
  gespeicherten Helden nicht; Moduswechsel erhält den Plan; manuelle Korrektur
  bleibt gesperrt; Entfernen einer Voraussetzung macht Folgeeintrag ungültig;
  Übernehmen bucht genau einmal; frühere Historie ist nicht löschbar.
- [ ] Zusätzlich: Held parallel geändert → Übernahme abgelehnt und Entwurf
  erhalten; Repository-Save fehlgeschlagen → erneuter Versuch möglich;
  Konto-/Repositorywechsel → vorhandene Schutzregeln greifen; Heldenwechsel
  → kein Entwurf landet bei der falschen ID. Nicht auf feste Demo-AP testen.
- [ ] Ausführen: `flutter test test/ui2/entwicklung test/ui/advancement
  test/state/advancement_session_test.dart test/rules/advancement_rules_test.dart
  test/rules/advancement_impact_rules_test.dart` und `flutter analyze`.
- [ ] Commit: `ui2: Entwicklungsbereich mit bestehender AP-Sitzung vervollständigen`.

## Aufgabe 3: Vollständige Abnahme und verbleibende Grenzen

**Anlegen:** `docs/redesign_acceptance.md`,
`test/ui2/shell/karto_workspace_journey_test.dart`.

**Aktualisieren:** README/CLAUDE, `docs/test_strategy.md`,
`docs/architecture_roadmap.md`, `docs/redesign_implementation.md`,
`docs/mockups/README.md` mit Link zum tatsächlichen Flutter-Stand.

- [ ] Einen durchgehenden Widgettest aufbauen: vorhandenen Helden öffnen →
  Probe durchführen → Protokoll sehen → Verwaltungsänderung speichern →
  Steigerung vormerken → Spielen zeigt weiter gespeicherte Werte → zurück zur
  Planung → übernehmen → neue Werte sichtbar. Dazu FakeRepository mit
  beobachtbaren Schreibvorgängen nutzen; keine erneuten Fachformeln im Test.
- [ ] Die Funktionsmatrix der Spec zeilenweise in `redesign_acceptance.md`
  abhaken, jeweils mit UI-Einstieg und Test oder manueller Prüfung. Import/Export,
  Einstellungen/Konto, Gruppen, Reisebericht, Begleiter, Avatar und Regelsuche
  ausdrücklich prüfen; sie sind im kleinen Mockup nur teilweise sichtbar.
- [ ] Prüfraster: 320, 390, 744, 768, 1024, 1366, 1440 dp; Hell und Dunkel;
  Textskalierung 1 und 2; Maus/Tastatur und Touch. Bei langen Namen, leeren
  Listen und vier Ressourcen kein unzugängliches Steuerelement. Nicht jeden
  Datenfall mit jeder Kombination kreuzen: Grenzfälle gezielt auswählen.
- [ ] Fokusfolge, Escape/Zurück, Screenreader-Labels und Dialogschließbarkeit
  praktisch prüfen. Eingaben bleiben bei abgebrochenem Navigationsversuch stehen.
- [ ] Echte Flutter-Screenshots für Spielen, Verwaltung und Planung sowie
  mindestens eine mobile Ansicht erzeugen. In `docs/redesign_acceptance.md`
  mit Datum, Größe und Testheld beschreiben. Keine HTML-Screenshots als Nachweis
  der Flutter-Implementierung verwenden.
- [ ] Gegen die Mockup-Bilder visuell prüfen: dunkle Navigation, klare
  Hierarchie, ruhige Flächen, lesbare Tabellen und erreichbare Kontextaktionen.
  Notwendige Abweichungen wegen realer Daten und Kartograph-Token benennen.
- [ ] `python tool/check_screen_loc_budget.py` und
  `python tool/check_screen_loc_budget.py --root lib/ui2 --recursive`
  ausführen. Kein Umgehen durch
  unkontrolliert große `part`-Dateien.
- [ ] Abschließend `flutter analyze` und `flutter test` ausführen. Nur bei
  vollständig erfolgreichen relevanten Checks committen. Infrastrukturfehler
  von Produktfehlern unterscheiden, konkrete nicht ausführbare Prüfungen nennen.
- [ ] In `redesign_acceptance.md` verbleibende Mockup-Folgearbeiten aus der
  Spec aufnehmen. ARCH-01 nur im erreichten Teilumfang aktualisieren, offen
  lassen wegen des zusätzlichen Schadensablaufs. ARCH-02 bis ARCH-06 nicht
  durch eine neue Darstellung als erledigt markieren.
- [ ] Kein Umschalten des Defaults, keine Bereinigung alter Screens und kein
  Release/Deployment in diesem Paket. Beides braucht einen späteren konkreten
  Ablösungsauftrag nach der Abnahme.
- [ ] Abschlusscommit: `docs: Redesign-Abnahme und verbleibende Fachaufgaben festhalten`.
  R3-Übergabe mit Implementierungscommits und Tests aktualisieren, relevante
  Erkenntnisse knapp nach Mempalace-Duplikatprüfung hinterlegen.
