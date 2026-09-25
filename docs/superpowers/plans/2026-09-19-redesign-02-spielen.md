# R2: Spielansicht mit echten Heldendaten — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task.
> Steps use checkboxes for tracking. R1 must be integrated first.

**Goal:** Die provisorische Inspector-Fläche aus R1 wird zur gut bedienbaren
Spielansicht des Mockups mit Ressourcen, echten Proben, Effekten und Historie.

**Architecture:** UI2 ordnet darstellende Bausteine um einen gemeinsamen
`HeroComputedSnapshot` an. Vorhandene Aktionen und Fachdialoge werden über den
Bestandsadapter aufgerufen. Fachliche Ergebnisse kommen aus bestehenden Regeln.

**Tech Stack:** Flutter, Riverpod, Karto-Token, vorhandene Proben-/Rastmodule.

**Spec:** [Umsetzungsspezifikation](../specs/2026-09-19-codex-redesign-design.md)
und [Übergabe R1](../../redesign_implementation.md).

## Global Constraints

- Status/Diff und R1-Übergabe prüfen; keine Shell oder Token neu bauen.
- Kein Beispielheld, festes Würfelergebnis, erfundener Sync-Status oder
  JavaScript-Regelcode aus `docs/mockups/hero-workspace-redesign.js`.
- Keine neuen Persistenzfelder, Regelprofile, Rundenzähler oder Favoritenmodelle.
  Die dazugehörigen Folgeaufgaben stehen ausdrücklich in der Spec.
- Keine pauschale Schaden-/Undo-Aktion. Vorhandene Ressourcenänderung und
  Wundenverwaltung bleiben erreichbar und werden korrekt benannt.
- Nur `heroComputedProvider` für berechnete Heldenwerte. Bestehende Aktionen
  wiederverwenden; neu notwendige Berechnungen ausschließlich in Regeldateien.
- Prüfungen, Dokumentation und gezielte Commits je abgeschlossener Aufgabe.

## Aufgabe 1: Ressourcen und adaptive Spielanordnung

**Anlegen:** `lib/ui2/spielen/karto_spielansicht.dart`,
`lib/ui2/spielen/karto_ressourcenleiste.dart`,
`lib/ui2/spielen/karto_ressourcenwert.dart`,
`test/ui2/spielen/karto_spielansicht_test.dart`,
`test/ui2/spielen/karto_ressourcenwert_test.dart`.

**Ändern:** `lib/ui2/shell/karto_workspace.dart`, Adaptervertrag und
`lib/ui/bridges/karto_bestands_adapter_impl.dart` nur für konkrete Aufrufe.

- [ ] `KartoRessourcenwert` als darstellendes Widget mit `bezeichnung: String`,
  `aktuell: int`, `maximum: int`, `onBearbeiten: VoidCallback?` vorsehen.
  Keine Persistenz oder DSA-Grenzberechnung in diesem Widget. Balkenanteil ist
  Darstellung; gespeicherte Werte werden dafür nicht stillschweigend gekürzt.
- [ ] Zuerst Rendering und Aktion testen. Dieses vollständige Testverhalten
  verwendet den geplanten Vertrag (Flutter-/Test- und Widget-Import ergänzen):

```dart
testWidgets('Ressource nennt Wert und Maximum und öffnet Bearbeitung',
    (tester) async {
  var geoeffnet = false;
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: KartoRessourcenwert(
      bezeichnung: 'Lebenspunkte',
      aktuell: 23,
      maximum: 35,
      onBearbeiten: () => geoeffnet = true,
    ),
  )));
  expect(find.text('23 / 35'), findsOneWidget);
  await tester.tap(find.byTooltip('Lebenspunkte ändern'));
  expect(geoeffnet, isTrue);
});
```

- [ ] `KartoSpielansicht({super.key, required String heroId,
  required KartoBestandsAdapter bestand})` einführen. `heroComputedProvider`
  einmal lesen und den Snapshot an die darstellenden Abschnitte weitergeben.
- [ ] LeP/AuP und nur tatsächlich aktivierte AsP/KaP aus `resourceActivation`
  zeigen. Negative LeP, Maximum 0, lange Namen und alle vier Ressourcen prüfen.
  Kein AsP-Feld bloß aufgrund einer Beispielprofession einblenden.
- [ ] Bearbeitung über vorhandene Vital-/Ressourcendialoge aus
  `inspector_vital_block.dart` und `resource_stepper_dialog.dart` anbinden.
  Wenn für UI2 ein Aufruf fehlt, den bestehenden Dialogzugang im Adapter
  freilegen; keine zweite Plus-/Minus- oder Grenzlogik schreiben.
- [ ] Große Fenster: zentrale Spielaktionen, seitlich Kampf/Zustände. Kleine
  Fenster: Ressourcen → Aktionen/Kampf → Effekte → Protokoll. Mindestens 48 dp
  Klickziele; Unterbereiche anhand ihrer tatsächlichen Breite umbrechen.
- [ ] Tests mit `FakeRepository`: weltlicher Held ohne AsP/KaP, magischer Held,
  geweihter Held, gelöschter Held, Ladefehler und erfolgreich gespeicherte
  Ressourcenänderung. Speicherfehler darf keine falsche Erfolgsmeldung erzeugen.
- [ ] Ausführen: `flutter test test/ui2/spielen
  test/ui/workspace/inspector/inspector_vital_block_test.dart
  test/state/hero_computed_snapshot_test.dart` und `flutter analyze`.
- [ ] Commit: `ui2: adaptive Ressourcen- und Spielansicht anbinden`.

## Aufgabe 2: Proben und Kampfwerte über die bestehenden Wege

**Anlegen:** `lib/ui2/spielen/karto_spielaktionen.dart`,
`test/ui2/spielen/karto_spielaktionen_test.dart`.

**Lesen/wiederverwenden:** `lib/ui/screens/workspace/probe_quick_search.dart`,
`lib/ui/screens/workspace/inspector/inspector_probe_tab.dart`,
`lib/ui/screens/shared/probe_request_factory.dart`,
`lib/ui/screens/shared/dice_log_persistence.dart`.

**Ändern:** Adapter und Spielansicht; bestehende Proben-Bausteine nur gezielt
aufteilen, wenn ihre Kopplung an die alte Anordnung eine Wiederverwendung verhindert.

- [ ] Zuerst einen Adapter-Fake testen: „Probe suchen“ ruft genau einmal
  `probeSuchen(context: ..., ref: ..., heroId: ...)` für den geöffneten Helden
  auf; „Rast“ und „Effekte“ rufen ihre passenden Methoden auf.
- [ ] Suchaktion prominent wie im Mockup platzieren. Der Suchdialog bleibt die
  vorhandene vollständige Suche nach Eigenschaften, Kampf, Talenten und Zaubern.
  Das Suchfeld nicht als funktionsloses Dekoelement nachzeichnen.
- [ ] Eigenschaften und Kampf-Schnellproben aus dem vorhandenen
  `InspectorProbeTab` als kleinere UI-Bausteine herauslösen und über den
  Adapter bereitstellen. Der bisherige Inspector nutzt dieselben Bausteine.
  Im neuen Layout kein kompletter Tab mit eigenem Protokoll doppelt anzeigen.
- [ ] Request-Aufbau über vorhandene Factories; Würfeln und Protokollierung
  weiterhin über `showLoggedProbeDialog`. UI2 kennt keine W20-/W6-Simulation.
  Offhand, Schild und Ausweichen entsprechend der vorhandenen Kampfvorschau
  zeigen, keine eigene Waffen-Namenszuordnung.
- [ ] Wunden-/Belastungsdetails erreichbar machen. Ein optionales „Warum?“ darf
  nur existierende Herleitungen öffnen; ohne vollständige Daten keinen
  erfundenen Basis-plus-Bonus-Rechenweg anzeigen.
- [ ] Integrationstest: Suche öffnen, echte vorhandene Probe auswählen,
  abbrechen ohne neuen Logeintrag; anschließend bestätigte Probe protokollieren.
  UI-Test prüft den Ablauf, vorhandene Regeltests prüfen Würfelmathematik.
- [ ] Tests für leere Suche und versteckte/nicht verfügbare Zauber ergänzen.
  Tastaturkürzel Strg/Cmd+K nur innerhalb des Workspace aktivieren und beim
  Verlassen entfernen; keine normale Texteingabe in Editoren abfangen.
- [ ] Ausführen: `flutter test test/ui2/spielen test/ui/shared/probe_dialog_test.dart
  test/ui/workspace/inspector test/ui/dice_log_filter_test.dart` und
  `flutter analyze`.
- [ ] Commit: `ui2: echte Proben und Kampfaktionen in der Spielansicht verbinden`.

## Aufgabe 3: Effekte, Rast und Protokoll ohne doppelte Zustände

**Anlegen:** `lib/ui2/spielen/karto_spielverlauf.dart`,
`test/ui2/spielen/karto_spielverlauf_test.dart`.

**Wiederverwenden:** `InspectorDiceLogSection`, `InspectorArcaneEffectsBlock`,
`showActiveSpellEffectsDialog`, `showRestDialog` und vorhandene Regelmodule
`active_spell_rules.dart`, `spell_duration_rules.dart`, `rest_rules.dart`.

- [ ] Zuerst Datenfluss testen: neuer Repository-Zustand erscheint im Verlauf;
  Heldenwechsel zeigt ausschließlich dessen Einträge. Leeres Log ist ein
  erklärter Leerzustand, keine Liste von Mockup-Ereignissen.
- [ ] Protokoll im Adapter mit `InspectorDiceLogSection(entries: snapshot.state.diceLog)`
  bauen. Vorhandene Filter und Reihenfolge erhalten. Keine zweite Ereignisliste
  für fiktive Schaden-/Rastnotizen einführen.
- [ ] Aktive Effekte auch für nichtmagische Helden durch Fremdzauber darstellen.
  Wenn `InspectorArcaneEffectsBlock` aufgeteilt wird, eine darstellende Variante
  mit Snapshot-Daten schaffen; der alte Consumer bleibt Wrapper. UI2 beobachtet
  nicht separat Held, Zustand und die vier abgeleiteten Provider.
- [ ] Effektänderung und Rast über bestehende Dialoge ausführen, danach den
  Providerzustand anzeigen. Abbrechen ändert nichts; doppeltes Bestätigen darf
  keine zusätzliche Anwendung auslösen. Dialoge müssen auch nach Heldenverlust
  oder Sync-Gate-Wechsel schließbar bleiben.
- [ ] Keine globale Schaltfläche „Nächste Runde“: deren betroffene Ressourcen,
  Zustände und gleichzeitige Speicherung sind in diesem UI-Paket nicht definiert.
- [ ] Ausführen: `flutter test test/ui2/spielen
  test/ui/shared/active_spell_effects_dialog_test.dart
  test/ui/workspace/inspector test/rules/rest_rules_test.dart
  test/rules/spell_duration_rules_test.dart` und `flutter analyze`.
- [ ] Commit: `ui2: Effekte Rast und Würfelverlauf zusammenführen`.

## Aufgabe 4: R2 abnehmen und R3 vorbereiten

- [ ] Spielansicht bei 320, 390, 768, 1024 und 1440 dp mit echten Testfixtures
  prüfen; zusätzlich Textskalierung 2 und Hell/Dunkel. Kein horizontaler
  Seitenüberlauf. Breite Datentabellen dürfen lokal scrollen, die Seite nicht.
- [ ] Screenshot von Desktop und Mobilansicht erzeugen und sichtbar gegen das
  Mockup prüfen. Abweichungen für echte Daten/Regelgrenzen dokumentieren.
- [ ] `flutter analyze` und `flutter test test/ui2 test/ui/workspace
  test/ui/shared test/ui/advancement test/state/hero_computed_snapshot_test.dart`
  ausführen; keine sachfremden Testanpassungen.
- [ ] Dokumentation mit tatsächlichen Aktionen, Übergangsadapter-Methoden und
  weiterhin offenen Mockup-Funktionen aktualisieren. R2-Status/Commit-IDs in
  `docs/redesign_implementation.md` setzen. ARCH-01 bleibt teilweise offen.
- [ ] Abschlusscommit und knapper Mempalace-Eintrag nach Duplikatprüfung.
