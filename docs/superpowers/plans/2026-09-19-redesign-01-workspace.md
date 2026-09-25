# R1: Workspace-Rahmen und Navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task.
> Steps use checkboxes for tracking. Run this package before R2 and R3.

**Goal:** Die bestehende UI2-Shell wird ein benutzbarer, adaptiver Workspace
mit echten Helden, drei Aufgabenbereichen und geschützten Bearbeitungszuständen.

**Architecture:** Vorhandenen Kartograph-Unterbau fortsetzen. Den gemeinsamen
Unterbau über Provider nutzen, bestehende Fachansichten über den in der Spec
definierten, injizierten Bestandsadapter einbinden. Keine neue Regelengine.

**Tech Stack:** Flutter, Dart, Riverpod, vorhandene Karto-Themes und Widgettests.

**Spec:** [Umsetzungsspezifikation](../specs/2026-09-19-codex-redesign-design.md)
und [Auftragsübersicht](../../redesign_implementation.md).

## Global Constraints

- `AGENTS.md` und `CLAUDE.md` lesen. Basis `8501232b`, nicht blind voraussetzen.
  `git status --short`, `git diff`, `git log -5 --oneline` ausführen. Einen
  vorhandenen Arbeitsbranch weiterverwenden; fremde Änderungen erhalten.
- `lib/ui2/theme/`, `lib/ui2/foundation/` und `AppRootSwitch` sind vorhanden.
  Sie nicht neu erzeugen. Keine Bestandsdateien oder Themes pauschal entfernen.
- Drei Modi sind festgelegt. Der abweichende ältere Zwei-Modi-Vorschlag ist
  für diesen Auftrag überholt. Die technische Steigerungssitzung bleibt bestehen.
- Kein zweites Startup-Gate und keine fachliche Formel im Widget/Adapter.
- Öffentliches Dart mit `///`, kleine Dateien, keine neue Screen-Datei über
  700 Zeilen. Keine UI2-Direktimporte aus `lib/ui/` außer `karto_app_root.dart`.
- Jede abgeschlossene Aufgabe: relevante Tests plus `flutter analyze`,
  Dokumentation und gezielter Commit. Kein Commit bei fehlgeschlagenen Checks.

## Aufgabe 1: Navigationsvertrag und Gestaltung des Rahmens

**Ändern:** `lib/ui2/theme/karto_tokens.dart`,
`lib/ui2/debug/karto_token_sheet.dart`, `test/ui2/theme/karto_contrast_test.dart`.

**Anlegen:** `lib/ui2/shell/karto_arbeitsbereich.dart`,
`lib/ui2/shell/karto_modus_navigation.dart`,
`test/ui2/shell/karto_modus_navigation_test.dart`.

- [ ] `KartoArbeitsbereich` aus der Spec einführen. Navigation als rein
  darstellendes Widget mit `bereich`, `onAuswahl` und `kompakt` bauen. Sie
  ändert keinen Provider selbst. Labels vollständig, auch per Semantik.
- [ ] Zuerst diesen Verhaltenstest schreiben; er schlägt vor der Implementierung
  wegen des fehlenden Widgets fehl. Im Test die beiden neuen Shell-Dateien
  sowie `material.dart` und `flutter_test.dart` importieren:

```dart
testWidgets('drei Modi sind erreichbar und melden die Auswahl', (tester) async {
  KartoArbeitsbereich? gewaehlt;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: KartoModusNavigation(
      bereich: KartoArbeitsbereich.spielen,
      kompakt: false,
      onAuswahl: (wert) => gewaehlt = wert,
    )),
  ));
  expect(find.text('Spielen'), findsOneWidget);
  expect(find.text('Held verwalten'), findsOneWidget);
  await tester.tap(find.text('Entwicklung planen'));
  expect(gewaehlt, KartoArbeitsbereich.entwickeln);
});
```

- [ ] `KartoModusNavigation` mit genau diesen Constructor-Parametern umsetzen;
  `bereich` typisiert, `onAuswahl: ValueChanged<KartoArbeitsbereich>`,
  `kompakt: bool`. Desktop als vertikale dunkle Navigation, kompakt als drei
  Ziele mit lesbaren Kurzlabels und vollständigen semantischen Namen.
- [ ] Semantische Token `navigation`, `navigationText`, `navigationMuted`
  ergänzen, inklusive Konstruktor, `copyWith`, `lerp`, heller/dunkler Palette.
  Geeigneter Start: dunkler Grund `0xFF162C30`, heller Text `0xFFF2EDE1`;
  Kontrasttest entscheidet über die endgültigen Werte. Vorhandene Rollen und
  Schriften erhalten, keine weiteren externen Fonts laden.
- [ ] Textkontrast der Navigation mindestens 4,5:1 testen. Bestehenden
  Themenübergang zwischen Codex/Kartograph und Hell/Dunkel mitprüfen.
- [ ] Ausführen: `flutter test test/ui2/shell/karto_modus_navigation_test.dart
  test/ui2/theme` und `flutter analyze`. Erwartung: alle Tests grün, kein Lint.
- [ ] Commit: `ui2: drei Arbeitsbereiche und dunkle Navigation ergänzen`.

## Aufgabe 2: Bestandsverwaltung ohne verschachtelten Workspace herauslösen

**Lesen:** `lib/ui/screens/hero_workspace_screen.dart`,
`lib/ui/screens/workspace/workspace_layout.dart`, `workspace_tab_spec.dart`,
`workspace_tab_registry.dart`, `workspace_navigation_guard.dart`,
`lib/ui/screens/workspace_edit_contract.dart`.

**Anlegen:** `lib/ui/screens/workspace/workspace_management_body.dart`,
`lib/ui2/shell/karto_bestands_adapter.dart`,
`lib/ui/bridges/karto_bestands_adapter_impl.dart`,
`test/ui/workspace/workspace_management_body_test.dart`.

**Gezielt ändern:** bestehender Workspace und Layout-Part zur gemeinsamen
Nutzung der herausgelösten Verwaltungskoordination; bestehende Edit-Tests.

- [ ] Die Schnittstelle aus der Spec wortgleich als Ausgangspunkt anlegen.
  Die Implementierung heißt `KartoBestandsAdapterImpl`. Sie baut den neuen
  Verwaltungsbody und delegiert Katalog/Historie/Inspector/Dialoge an die
  bestehenden Komponenten. Kein Repository im Adapter öffnen.
- [ ] Vor dem Herauslösen Tests für Dirty-Guard schreiben: Abbruch erhält
  Entwurf; Verwerfen verwirft; Speichern wartet und wechselt erst bei Erfolg;
  Speicherfehler lässt Ansicht und Eingabe erhalten. Die Fixtures aus
  `hero_workspace_edit_mode_test.dart` wiederverwenden.
- [ ] `WorkspaceManagementBody` aus Tab-Inhalt, Tab-Auswahl, Registry,
  Editoraktionen und Leave-Guard herauslösen. Globale Navigation, Heldenkopf,
  Inspector und Steigerung gehören nicht in dieses Widget. Den bestehenden
  Workspace auf denselben Body/Koordinator umstellen, statt eine zweite
  Bearbeitungsimplementierung zu kopieren.
- [ ] Constructor-Vertrag des Bodys: `heroId`, `korrekturenGesperrt` und
  `onVerlassenRegistriert` entsprechend der Adaptermethode `verwaltung`.
  Beim Mount die aktuelle Prüfung registrieren, beim Dispose abmelden;
  keine `setState`-Aufrufe in einem bereits entsorgten Host.
- [ ] Abschnittsliste mit `buildWorkspaceTabs(heroId: heroId,
  callbacksForTab: callbacksForTab)` und
  `visibleWorkspaceTabsForHero(hero: hero, tabs: allTabs)` bilden. IDs,
  Discard-/Edit-Callbacks, Headeraktionen und Import/Export erhalten.
- [ ] Bei `korrekturenGesperrt` alle `HeroSheet`-Mutationen verhindern, auch
  sofort speichernde Inventar-/Gruppenaktionen. Nicht bloß „Bearbeiten“
  ausblenden. Für noch nicht einzeln deaktivierbare Altansichten vorerst einen
  erklärten Sperrzustand mit Weg zur Planung zeigen; keine scheinbar bearbeitbare
  Fläche. Das genaue Verhalten in der Übergabe nennen.
- [ ] Fehler-/Leerzustände sowie nicht sichtbaren Magie-Tab testen. Kein
  Funktionsverlust: jede sichtbare Bestands-ID bleibt erreichbar.
- [ ] Ausführen: `flutter test test/ui/workspace test/ui/advancement
  test/ui/inventory test/ui/gruppe` und `flutter analyze`.
- [ ] Dokumentiere Adapter und gemeinsame Verwaltung in `CLAUDE.md`.
  Commit: `workspace: Verwaltungsinhalt für den neuen Rahmen herauslösen`.

## Aufgabe 3: Heldenwahl und drei Modi an echte Provider anschließen

**Ändern:** `lib/ui2/shell/karto_shell.dart`, `karto_app_root.dart`,
`test/ui2/shell/app_root_switch_test.dart`.

**Anlegen:** `lib/ui2/shell/karto_heldenwahl.dart`,
`lib/ui2/shell/karto_workspace.dart`,
`lib/ui2/shell/karto_workspace_navigation.dart`,
`test/ui2/shell/karto_workspace_test.dart`.

- [ ] Tests zuerst: leerer Heldenspeicher; Auswahl eines existierenden Helden;
  gelöschte gespeicherte Auswahl; Fehler beim Laden; gültiger zuletzt gewählter
  Held. Testsetup aus `app_root_switch_test.dart` mit `FakeRepository` nutzen.
- [ ] `AppRootSwitch` injiziert `KartoBestandsAdapterImpl` in `KartoShell`.
  Direkte Shell-Tests bekommen einen kleinen Fake-Adapter; produktive
  Konstruktoren bekommen keinen stillen Demo-/Fallback-Adapter.
- [ ] Heldenwahl aus `heroListProvider`, aktive ID aus `selectedHeroIdProvider`,
  Auswahl speichern über `selectedHeroSelectionActionsProvider.selectHero`.
  Bei fehlenden Helden bleibt Rückkehr zur Bestandsoberfläche möglich; vorhandene
  Anlegen-/Importwege über den Adapter zugänglich halten.
- [ ] `KartoWorkspace` verwendet `heroComputedProvider(heroId)`, erhält
  `heroId` und `bestand` gemäß Spec. Zuerst echte Loading-/Error-/Missing-Zustände
  rendern, dann Heldenkopf, Modusnavigation und Inhaltsflächen.
- [ ] Verwaltung über Adapter einsetzen, Spielen vorläufig über
  `spielDetails(heroId)`, Entwicklung über `planKatalog`/`planHistorie`.
  Die Spielanordnung wird in R2 ersetzt; vorhandene Werte schon jetzt echt.
- [ ] Beim ersten Eintritt in Entwicklung nach erfolgreichem Edit-Guard und
  geladenem Katalog `start(hero: ..., catalog: ...)` auf dem vorhandenen
  Sitzungscontroller aufrufen. Bei vorhandener Sitzung nur anzeigen, nie erneut
  `start`. Katalogfehler sichtbar mit Wiederholen/Zurück; nicht auf
  `ref.read(provider.future)` warten (siehe CLAUDE.md).
- [ ] Übernehmen/Verwerfen über vorhandenen Controller und `session.canCommit`
  anbinden. Ein Wechsel der drei Modi erhält den Plan. Gespeicherter Held und
  Vorschau bleiben unterscheidbar; die Verwaltung erhält die Sitzungssperre.
- [ ] Alle Verlassenwege durch denselben Guard in
  `karto_workspace_navigation.dart` führen. Browser-/System-Zurück einschließen.
  Keine zweite fachliche Steigerungsprüfung in diesem Koordinator.
- [ ] Layout mit `LayoutBuilder`/`KartoBreite`: 320 und 390 dp ohne Überlauf,
  Tablet und Desktop mit kontextabhängiger Detailfläche. Bestandsscrollbereiche
  erhalten begrenzte Höhe; keine unbeschränkte `TabBarView` im Scrollview.
- [ ] Tests für Moduswechsel mit Dirty-Editor, behaltenem Plan, fehlgeschlagenem
  Save, schnellem Doppelklick, Heldenwechsel und Oberflächenwechsel ergänzen.
- [ ] Ausführen: `flutter test test/ui2/shell test/ui/workspace
  test/ui/advancement test/state/advancement_session_test.dart` und
  `flutter analyze`.
- [ ] Commit: `ui2: echten Helden-Workspace mit geschützten Moduswechseln anbinden`.

## Aufgabe 4: R1 abnehmen und übergeben

- [ ] Flutter bei 390, 744, 1024 und 1440 dp öffnen; Moduswechsel und Rückweg
  zur bestehenden Oberfläche praktisch prüfen. Keine Behauptung „fertiges
  Redesign“: Spielinhalt und gestalterische Fachansichten folgen in R2/R3.
- [ ] Nachweisen, dass Repository/Katalog beim Oberflächenwechsel nicht neu
  erzeugt werden und `karto_theme_uebergang_test.dart` grün bleibt.
- [ ] `flutter analyze`, `flutter test test/ui2 test/ui/workspace
  test/ui/advancement test/ui/smoke` ausführen. Alte Test-Erwartungen nur ändern,
  wenn die neue Navigation die Änderung begründet; Verhaltensprüfungen erhalten.
- [ ] `README.md`, `CLAUDE.md`, `docs/architecture_roadmap.md` und betroffene
  Anleitungen prüfen/aktualisieren. Status R1 und konkrete Adaptermethoden in
  `docs/redesign_implementation.md` mit Commit-IDs nachführen. ARCH-01 bleibt offen.
- [ ] Gezielten Abschlusscommit erstellen und Mempalace-Duplikatprüfung/
  kurzen Eintrag gemäß AGENTS.md ausführen. R2 beginnt auf diesem Stand.
