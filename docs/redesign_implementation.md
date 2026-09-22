# Redesign umsetzen: Übergabe an weitere Agenten

Stand: 19.09.2026 · geprüfter Ausgangsstand: `8501232b`.

Dieses Dokument enthält **Umsetzungspläne und kopierfertige Startprompts** für
das freigegebene [Mockup](mockups/README.md). **R1, R2 und R3 sind umgesetzt**
(siehe Übergabestatus). Die Abnahme steht in
[redesign_acceptance.md](redesign_acceptance.md).

## Empfehlung

Den bereits begonnenen Neubau unter `lib/ui2/` weiterführen. Flutter, Riverpod,
Heldenspeicher, Kataloge und Regelmodule bleiben die gemeinsame Grundlage.
Zuerst die neue Oberfläche mit echten Daten benutzbar machen, anschließend die
fachlichen Erweiterungen der [Architektur-Roadmap](architecture_roadmap.md)
getrennt bearbeiten. Die sieben Architekturpunkte sind kein einzelner UI-Auftrag.

Vorhanden sind bereits die Umschaltung `Oberflaeche.codex/kartograph`, die
Startweiche unterhalb von `SyncConflictGate`, Farb- und Abstandstoken, lokale
Schriften sowie Tests des Themenwechsels. Diese Arbeit aus `269270be` und
`8501232b` wird weiterverwendet. Die Variante `klassisch` wurde bereits entfernt;
kein Agent soll sie neu anlegen oder die Token-Schicht nochmals bauen.

Das Mockup gibt **drei Arbeitsbereiche** vor: Spielen, Held verwalten und
Entwicklung planen. Diese Freigabe ersetzt für die folgenden Pläne den älteren
Vorschlag mit zwei Bereichen. Entwicklung bleibt technisch eine flüchtige
Steigerungssitzung, bekommt aber einen eigenen sichtbaren Bereich.

## Reihenfolge und Zuständigkeiten

| Paket | Auftrag | Voraussetzung | Ergebnis |
|---|---|---|---|
| [R1: Rahmen und Navigation](superpowers/plans/2026-09-19-redesign-01-workspace.md) | UI2 an echte Helden anbinden, drei Bereiche, vollständige Verwaltung über einen begrenzten Bestandsadapter, Schutz vor Datenverlust | Ausgangsstand prüfen | Benutzbarer Rahmen mit vorhandenen Fachansichten |
| [R2: Spielansicht](superpowers/plans/2026-09-19-redesign-02-spielen.md) | Ressourcen, Proben, Kampf, Effekte, Rast und Würfelprotokoll in der neuen Anordnung | R1 integriert und getestet | Spielansicht mit echten Werten und bestehenden Aktionen |
| [R3: Verwaltung, Planung und Abnahme](superpowers/plans/2026-09-19-redesign-03-abschluss.md) | Bestandsansichten gestalterisch integrieren, Entwicklung mit AP-Vorschau und Historie, mobile und fachliche Regression prüfen | R1 und R2 integriert | Erster zusammenhängender Redesign-Stand hinter dem bestehenden Umschalter |

Die Pakete **nacheinander** in separaten Agentensitzungen ausführen. Sie ändern
gemeinsame Shell- und Adapterdateien; gleichzeitiges Bearbeiten desselben
Worktrees ist dafür ungeeignet. Pro Paket kleine getestete Commits. Kein
automatisches Löschen des Bestands und kein Wechsel des Standardwerts der
Oberflächeneinstellung.

Gemeinsame Grundlage ist die
[Umsetzungsspezifikation](superpowers/specs/2026-09-19-codex-redesign-design.md).
Sie enthält Funktionszuordnung, Übergangsadapter, Zustandsregeln und die bewusst
noch nicht abgedeckten Mockup-Funktionen. Jeder Plan benennt konkrete Dateien,
Verhaltensprüfungen und Abnahmekriterien. Geplante neue Klassen und Dateien sind
in diesen Dokumenten als solche beschrieben, nicht als bereits vorhandene APIs.

## Startprompt für Agent 1

```text
Setze Paket R1 aus docs/superpowers/plans/2026-09-19-redesign-01-workspace.md um.
Lies zuerst AGENTS.md, CLAUDE.md, docs/redesign_implementation.md und
docs/superpowers/specs/2026-09-19-codex-redesign-design.md.
Prüfe git status, git diff und den aktuellen Code; Ausgangsstand des Plans ist
8501232b, inzwischen abgeschlossene Schritte dürfen nicht erneut gebaut werden.
Das Mockup ist freigegeben: drei Bereiche, heller Codex, dunkle Navigation.
Führe das vorhandene UI2-/Kartograph-Fundament weiter. Implementiere nur R1,
mit echten Providern, vollständigem Erhalt der Bestandsfunktionen und den
beschriebenen Navigationsschutzmechanismen. Prüfe insbesondere den einzigen
App-Start, den Themenwechsel und ungespeicherte Eingaben.
Führe flutter analyze und die im Plan genannten Tests aus, erstelle danach
gemäß AGENTS.md gezielte Commits und aktualisiere den Übergabestatus.
Berichte zum Schluss Commit-IDs, Prüfungen, Abweichungen und den Einstieg für R2.
Keine neue Mockup-Runde und keine zusätzliche Bestätigung für bereits
festgelegte Gestaltungsentscheidungen. Bei einem echten Widerspruch zum
aktuellen Code die betroffene Entscheidung konkret benennen.
```

## Startprompt für Agent 2

```text
Setze Paket R2 aus docs/superpowers/plans/2026-09-19-redesign-02-spielen.md um.
Lies AGENTS.md, CLAUDE.md, docs/redesign_implementation.md und die darin
verlinkte Umsetzungsspezifikation. Prüfe zuerst, dass R1 integriert ist und
seine Abnahmetests bestehen; passe Pfade nur an dokumentierte Änderungen an.
Baue die Spielansicht des freigegebenen Mockups mit echten Heldendaten und
vorhandenen Regel-/Aktionspfaden. Nutze heroComputedProvider als gemeinsame
Wertquelle. Übernimm keine JavaScript-Beispielregeln oder Demo-Ergebnisse.
Beachte die Abgrenzung für Schaden/Undo, Favoriten, Rundenzähler und Regelprofile.
Prüfe schmale und breite Fenster sowie weltliche, magische und geweihte Helden.
Führe flutter analyze und die im Plan genannten Tests aus. Dokumentiere und
committe getestete Teilumfänge gemäß AGENTS.md. Aktualisiere den Übergabestatus
mit Commit-IDs, geprüften Abläufen und verbliebenen fachlichen Grenzen.
Implementiere R2; beginne R3 nicht ungefragt in derselben Sitzung.
```

## Startprompt für Agent 3

```text
Setze Paket R3 aus docs/superpowers/plans/2026-09-19-redesign-03-abschluss.md um.
Lies AGENTS.md, CLAUDE.md, docs/redesign_implementation.md und die verlinkte
Umsetzungsspezifikation. Prüfe die Übergaben und Tests von R1 und R2.
Integriere alle bestehenden Verwaltungsbereiche in die neue Gestaltung und
den vorhandenen AdvancementSessionController in den Bereich Entwicklung planen.
AP-Vorschau, Erwerbsblatt, Fähigkeitenbaum, Konfliktprüfung und historische
Einträge müssen erhalten bleiben. Ein Moduswechsel darf den Entwurf nicht
verwerfen; manuelle Heldenkorrektur und AP-Planung dürfen nicht konkurrieren.
Prüfe die vollständige Funktionsmatrix, echte Datenflüsse, Themenübergänge,
Tastaturbedienung und responsive Ansichten. Erstelle aktuelle Flutter-Screenshots
für die visuelle Abnahme und dokumentiere Abweichungen vom Mockup.
Führe flutter analyze und die im Plan genannten Tests aus, dokumentiere und
committe gemäß AGENTS.md. Behalte den vorhandenen Oberflächenumschalter.
Markiere ARCH-01 nicht als vollständig erledigt, solange der fachliche
Schadensablauf offen ist. Liefere einen klaren Stand der noch offenen Aufgaben.
```

## Welche GPT dafür?

**Meine Empfehlung: GPT-6 Astra mit hoher Denktiefe (`high`), sofern in deiner
Modellauswahl verfügbar.** Die schwierigste Arbeit ist hier die Integration:
zwei Oberflächen, Bearbeitungszustände, Riverpod und Steigerungsentwürfe müssen
zusammenpassen. Für alle drei Pakete dasselbe leistungsfähige Modell zu wählen,
vereinfacht die Übergaben. Die Wahl von `high` ist eine Empfehlung für dieses
Projekt, keine Vorgabe der Dokumentation.

OpenAI beschreibt GPT-6 Astra als sein leistungsfähigstes Modell für komplexe
End-to-End-Aufgaben. [Offizielle Modellbeschreibung](https://developers.openai.com/api/docs/models/gpt-6-astra).
Für klar abgegrenzte Gestaltungskorrekturen nach R1 ist **GPT-5.6 Terra** eine
Alternative mit einem anderen Verhältnis von Leistungsfähigkeit und Kosten.
[Offizielle Modellübersicht](https://developers.openai.com/api/docs/models/all).
Die abschließende Integrationsprüfung würde ich wieder mit Astra durchführen.

Diese Empfehlung wurde am 19.09.2026 gegen die offiziellen Quellen geprüft.
Die tatsächlich angebotenen Modelle hängen von deiner Oberfläche und deinem
Zugang ab. Es ist keine Änderung an `.mcp.json` nötig, um diese Pläne zu nutzen.

## Übergabestatus

Die folgenden Felder ergänzt jeweils der ausführende Agent mit seinem echten
Ergebnis. Ein grüner Testlauf der Dokumentation setzt kein Umsetzungshäkchen.

| Paket | Status | Implementierungscommits | Nachweis / Abweichungen |
|---|---|---|---|
| R1 | umgesetzt | `80f7d69c`, `76c8029c`, `ee4aec62` | siehe Abschnitt „R1: Übergabe“ |
| R2 | umgesetzt | `e4d52dfd`, `24cadcc1`, `6faab4c2`, `1bb47e8e` | siehe Abschnitt „R2: Übergabe“ |
| R3 | umgesetzt | `832066da`, `0258aa11` | siehe Abschnitt „R3: Übergabe“ |

### R1: Übergabe

**Umgesetzt.** `KartoArbeitsbereich` mit den drei Bereichen, die rein
darstellende `KartoModusNavigation` samt eigenen Navigationstoken und
Kontrastprüfung, der aus dem Bestands-Workspace herausgelöste
`WorkspaceManagementCoordinator`, den **beide** Oberflächen benutzen, der
`WorkspaceManagementBody` ohne äußere Navigation und Inspector, die
Übergangsbrücke `KartoBestandsAdapter`/`KartoBestandsAdapterImpl`, die echte
Heldenwahl über die vorhandenen Provider sowie der gemeinsame Verlassen-Guard
für Moduswechsel, Heldenwechsel, Menüwege und System-Zurück.

**Tatsächlich gebauter Adaptervertrag** — unverändert gegenüber der Spec:
`verwaltung`, `planKatalog`, `planHistorie`, `spielDetails`, `heldenVerwalten`,
`einstellungen`, `probeSuchen`, `rast`, `effekte`. Keine zusätzliche Methode.

**Prüfungen** (lokal, Flutter-Toolchain des Projekts):

| Befehl | Ergebnis |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | 729 Dateien, 0 geändert |
| `flutter analyze --no-pub` | No issues found |
| `python tool/check_screen_loc_budget.py --max-lines 700` | OK, 21 Dateien |
| `flutter test --no-pub` | +1903 ~3, exit 0 |

Responsives Verhalten ist bei 320, 390, 744, 1024 und 1440 dp getestet, jeweils
doppelt: gegen einen Fake-Adapter (`karto_workspace_test.dart`) und gegen die
echten Bestandsansichten (`karto_bestands_integration_test.dart`), dazu bei
Textskalierung 2. `app_root_switch_test.dart` und
`karto_theme_uebergang_test.dart` blieben unverändert grün; der
Oberflächenwechsel baut Repository, Sync und Katalog weiterhin nicht neu auf.

**Visuelle Abnahme in der laufenden Windows-App** (Debug-Build, DPI-Skalierung
1,0, Fensterbreiten exakt gesetzt, echter Heldenspeicher mit vier Helden):
Umschalten unter `Einstellungen > Darstellung` wechselt das Thema live ohne
Ausnahme. Bei 390 dp erscheint die Navigation als Bottom-Bar, bei 744 und
1024 dp als schmale Leiste, bei 1440 dp breit mit Detailspalte in der Planung —
überall ohne horizontalen Überlauf. Geprüfte Abläufe: Moduswechsel über alle
drei Bereiche, Verwaltung mit allen Abschnitten und echten Werten, Start einer
Steigerungssitzung mit geladenem Katalog, Vormerken einer Eigenschaft
(MU 16 → 17, 480 AP, Auswirkungsvorschau AsP +1), Verlassen-Versuch mit
Planabfrage, „Weiterplanen“ erhält den Entwurf, „Verwerfen“ räumt ihn ab,
Sperrhinweis der Verwaltung bei offener Planung, Einstellungen bei offener
Planung ohne Planabfrage mit anschließend unveränderter Sitzung, Rückweg zur
bestehenden Oberfläche. Der Held blieb dabei unverändert (31402 AP vorher wie
nachher); es wurde nichts übernommen.

Die Sichtprüfung fand einen Fehler, den kein Widgettest sehen konnte: die
dunkle Navigationsleiste bekam auf Tablet- und Desktopbreiten nur die Höhe
ihrer drei Ziele und saß als Block mitten in der hellen Fläche. Behoben in
`6208f7e5`. Offene gestalterische Grobheit ohne Funktionsfehler: der
Sperrhinweis der Verwaltung steht einzeln auf sonst leerer Fläche — die
gestalterische Integration der Bestandsansichten ist Gegenstand von R3.

**Abweichungen und bewusste Grenzen.**

1. Bei offener Planung ersetzt ein erklärter Sperrhinweis die **gesamte**
   Verwaltungsfläche, statt einzelne Schreibaktionen zu deaktivieren. Inventar-
   und Gruppenaktionen speichern sofort und lassen sich noch nicht einzeln
   abschalten; eine scheinbar bearbeitbare Fläche wäre schlechter. Der Plan
   lässt diesen Zwischenstand ausdrücklich zu.
2. `spielDetails` ist in R1 der vorhandene `InspectorPanel`, ergänzt um die
   Direktaktionen Probe, Rast und Effekte. Die Spielanordnung des Mockups
   ersetzt R2.
3. Das Öffnen von Einstellungen und Token-Blatt prüft nur den Editor-Dirty-Guard,
   nicht den offenen Plan. Sie legen einen Screen auf den Workspace, bauen ihn
   nicht ab, und die Sitzung liegt im gemeinsamen `ProviderScope`. Seit der
   Nachprüfung prüft ein tatsächlicher Oberflächenwechsel innerhalb der
   Einstellungen zusätzlich den Plan. Die Planabfrage
   greift bei Heldenwahl, Heldenliste, Rückkehr zur Bestandsoberfläche und
   System-Zurück.
4. ARCH-01 bleibt offen: der atomare Schadensablauf mit Rücknahme fehlt
   weiterhin, ebenso R2 und R3.

**Einstieg für R2.** Die Spielanordnung ersetzt `_spielen()` in
`lib/ui2/shell/karto_workspace.dart`. `heroComputedProvider(heroId)` ist die
gemeinsame Wertquelle, `heroActionsProvider` der Schreibweg. Neue
Adaptermethoden nur mit konkretem Aufrufer und Test, beide Seiten im selben
Commit. Der Verlassen-Guard in `karto_workspace_navigation.dart` bleibt
unangetastet; keine zweite fachliche Steigerungsprüfung.

Für jede Übergabe dokumentieren: ausgeführte Befehle und Ergebnis, tatsächlich
verwendete Schnittstellen, Screenshots, verbliebene Fehler und fachliche
Abgrenzungen. Relevante Erkenntnisse anschließend nach Duplikatprüfung knapp
in Mempalace im Wing `flutter_application_1` ablegen.

### R2: Übergabe

**Umgesetzt.** Die Spielansicht des Mockups liegt in `lib/ui2/spielen/`:
`KartoSpielansicht` als Host, `KartoRessourcenleiste`/`KartoRessourcenwert`,
`KartoSpielaktionen` und `KartoAbschnitt` als Rahmen. Sie liest
`heroComputedProvider(heroId)` **einmal** und reicht den `HeroComputedSnapshot`
an alle Abschnitte weiter, auch an die Adaptermethoden. Der provisorische
`InspectorPanel` aus R1 ist damit abgelöst.

**Anordnung.** Ressourcen, Schnellaktionen, Eigenschaften, Kampf, Effekte,
Zustand, Würfelprotokoll. Ab `KartoBreite.breit` stehen Kampf, Effekte und
Zustand in einer Seitenspalte (280 dp, ab `sehrBreit` 320 dp); das Protokoll
schließt beide Anordnungen ab.

**Tatsächlich gebauter Adaptervertrag.** `spielDetails` ist **entfallen** — die
neue Anordnung ersetzt es, und die Brücke soll abschnittsweise kleiner werden.
Neu, jeweils mit Aufrufer und Test im selben Commit:
`spielEigenschaftsproben`, `spielKampfproben`, `spielEffekte`, `spielZustand`,
`spielProtokoll`, `ressourceBearbeiten` (mit dem UI2-eigenen Aufzählungstyp
`KartoRessource`). Unverändert: `verwaltung`, `planKatalog`, `planHistorie`,
`heldenVerwalten`, `einstellungen`, `probeSuchen`, `rast`, `effekte`. Die
Spielbausteine der Brücke liegen in `lib/ui/bridges/karto_spiel_bruecke.dart`.

**Herauslösungen im Bestand** (Verhalten und Widget-Keys unverändert):
`InspectorAttributeProbes` und `InspectorCombatProbes` aus `InspectorProbeTab`
(der dadurch von 299 auf 61 Zeilen schrumpft und nun beide Oberflächen
beliefert), sowie die darstellende `InspectorArcaneEffectsView` aus
`InspectorArcaneEffectsBlock`, der Consumer-Wrapper bleibt. Die Chipliste der
Effekte wandert aus dem Widget in die neue Regeldatei
`lib/rules/derived/active_spell_display_rules.dart`.

**Prüfungen** (lokal, Flutter-Toolchain des Projekts):

| Befehl | Ergebnis |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | 743 Dateien, 0 geändert |
| `flutter analyze --no-pub` | No issues found |
| `python tool/check_screen_loc_budget.py --max-lines 700` | OK, 21 Dateien |
| `flutter test --no-pub` | +1946 ~3, exit 0 (Ausgangsstand: +1903 ~3) |

Neue Testdateien: `test/ui2/spielen/karto_ressourcenwert_test.dart`,
`karto_spielansicht_test.dart`, `karto_spielaktionen_test.dart`,
`karto_spielverlauf_test.dart` und `test/ui/bridges/karto_spiel_bruecke_test.dart`.
Geprüft sind weltlicher, magischer und geweihter Held, gelöschter Held,
Ladefehler, Speicherfehler ohne falsche Erfolgsmeldung, negative LeP,
Überheilung, Maximum 0, langer Ressourcenname, Textskalierung 2, Hell und
Dunkel sowie 320, 390, 744, 1024 und 1440 dp.

**Visuelle Abnahme.** Zwei Wege, weil einer allein nicht gereicht hätte.

1. *Gerenderte Bilder.* Die echte Spielansicht wurde mit
   `KartoBestandsAdapterImpl` und den echten Schriften als PNG rasterisiert —
   drei Archetypen (weltlich ohne AsP/KaP, magisch mit AsP, geweiht mit KaP)
   mal 390, 744, 1024 und 1440 dp — und angesehen. Das fand einen Fehler, den
   kein Widgettest bemerkt hatte: auf schmalen Fenstern stand das
   Würfelprotokoll mitten in der Spalte statt am Ende, weil die einspaltige
   Anordnung Haupt- und Seitenabschnitte nur hintereinanderhängte. Behoben in
   `1bb47e8e`, der Reihenfolgetest prüft die Position jetzt mit.
2. *Laufende Windows-App* (Debug-Build, echter Heldenspeicher, DPI 1,0). Der
   Bildschirminhalt einer Flutter-Windows-App ist mit GDI (`CopyFromScreen`,
   `PrintWindow`) **nicht** auslesbar — die Titelleiste kommt durch, die
   GPU-komponierte Client-Fläche bleibt weiß. Stattdessen wurde über den
   VM-Service `ext.flutter.debugDumpRenderTree` die gezeichnete Geometrie
   ausgewertet, bei jeder der vier Breiten neu:

   | Fensterbreite | Spielansicht | Navigation | LeP-Kachel | Überläufe |
   |---|---|---|---|---|
   | 390 dp | 390 × 778 | 390 × 66 (unten) | 326 | 0 |
   | 744 dp | 560 × 844 | 184 × 844 | 244 | 0 |
   | 1024 dp | 840 × 844 | 184 × 844 | 250,7 | 0 |
   | 1440 dp | 1208 × 844 | 232 × 844 | 269,3 | 0 |

   Die Summen gehen auf (Fensterbreite minus Navigationsbreite, Höhe minus
   AppBar und gegebenenfalls Bottom-Bar), die dunkle Navigation steht weiterhin
   über die volle Höhe, und an keiner Breite meldet der Renderbaum einen
   Überlauf. Genau die Fehlerklasse aus R1 — eine Fläche, die in ihre
   Constraints passt, aber zu klein gezeichnet wird — ist damit ausgeschlossen.
   Der geöffnete Held war ein magischer; die Archetypen deckt Weg 1 ab.
   Es wurden keine Heldendaten verändert: es wurde nur gelesen, in der App
   nichts bedient und kein Schreibweg ausgelöst.

**Abweichungen und bewusste Grenzen.**

1. Nicht gebaut, weil ohne echten Zustand erfunden: pauschaler Schadens- und
   Rücknahmeknopf, KR-Zähler und „Nächste Kampfrunde“, persistente Favoriten,
   Offline-/Sync-Status, Notizen im Verlauf. Die Abgrenzungstabelle der Spec
   gilt unverändert; ein Test in `test/ui2/spielen/` hält ihre Abwesenheit fest.
   Ressourcen und Wunden bleiben über die vorhandenen Wege bedienbar.
2. Das Mockup zeigt Ressourcenhinweise wie „6 LeP fehlen“. Solche Texte hätten
   eine eigene Regelaussage; die Spielansicht zeigt stattdessen Wert, Maximum
   und Balken.
3. Die Bestandswidgets im Zustandsabschnitt sind für eine breitere Fläche
   gebaut. In der 280 dp schmalen Seitenspalte kürzt die Belastungszeile ihren
   Hinweistext per Ellipse. Kein Funktionsfehler, aber eine gestalterische
   Grobheit — die Integration der Bestandsansichten ist Gegenstand von R3.
4. Die Ressourcenbearbeitung öffnet den vorhandenen `InspectorVitalBlock`
   statt `showResourceStepperDialog`. Der Stepper klemmt hart auf `0..max` und
   könnte die geforderten negativen Lebenspunkte gar nicht erzeugen.
5. ARCH-01 bleibt offen: der atomare Schadensablauf mit Rücknahme fehlt
   weiterhin, ebenso R3.

**Einstieg für R3.** Verwaltung und Planung tragen noch die Bestandsgestaltung;
der Sperrhinweis bei offener Planung steht weiterhin allein auf leerer Fläche.
`KartoAbschnitt` aus `lib/ui2/spielen/` ist der vorhandene Abschnittsrahmen und
dürfte beim Gestalten der übrigen Bereiche der Ausgangspunkt sein — dann
sinnvollerweise nach `lib/ui2/` hochgezogen. Der Verlassen-Guard in
`karto_workspace_navigation.dart` blieb in R2 unangetastet und sollte es
bleiben.

## Nachprüfung und Korrekturen vom 20.09.2026

Eine nachträgliche Codeprüfung fand drei Lücken in R1/R2. Die folgenden
Korrekturen ergänzen die ursprünglichen Übergaben:

- **R2, Ressourcen:** Der Schreibweg lädt den Laufzeitzustand unmittelbar vor
  der gezielten Änderung über `HeroActions.updateHeroState` neu. Ein
  Regressionstest aktualisiert AsP zwischen Rendern und LeP-Klick und prüft,
  dass LeP −1 diese AsP erhält. Die bestehenden Repository-Schnittstellen
  bleiben unverändert; dies führt keine globale Schreibtransaktion ein.
- **R1, Editoraktionen:** Der gemeinsame `WorkspaceManagementCoordinator`
  sperrt direkte Aktionen während der gesamten Verlassen-Prüfung, samt deren
  asynchronem Speichern. Der Header zeigt die Sperre unmittelbar an und wird
  nach Abbruch oder Fehler wieder freigegeben. Der Regressionstest hält einen
  Guard-Save offen, betätigt erneut Speichern und weist genau einen Write nach.
- **R1, Einstellungen:** Die Bestandsbrücke reicht optional
  `vorOberflaechenwechsel` an `SettingsScreen.beforeSurfaceChange` weiter.
  Das bloße Öffnen erhält die Planung. Erst der Oberflächenschalter fragt
  „Weiterplanen / Verwerfen / Übernehmen“ ab, bevor er die Einstellung schreibt.
  Schmale Detailseiten und breite geteilte Ansichten verwenden denselben
  Ablauf. Abbruch oder fehlgeschlagene Übernahme verhindern den Wechsel;
  erneute Klicks während einer laufenden Prüfung sind gesperrt.

**Prüfung:** `flutter analyze --no-pub` ohne Befund. Die folgenden relevanten
Tests bestanden mit **293 erfolgreichen Tests und 3 bestehenden Überspringungen**.
Die neuen Regressionstests reproduzierten vor den Fixes die Fehler und sind
danach grün; die Settings-Tests prüfen 390 und 1200 dp, alle Planentscheidungen
und einen fehlgeschlagenen Save mit anschließend erfolgreichem Versuch.

```text
flutter test --no-pub test/ui2 test/ui/workspace test/ui/shared
  test/ui/advancement test/ui/inventory test/ui/gruppe test/ui/bridges
  test/ui/smoke test/ui/screens/settings_screen_test.dart
  test/ui/screens/settings_sync_page_test.dart test/ui/dice_log_filter_test.dart
  test/state/advancement_session_test.dart test/state/hero_computed_snapshot_test.dart
  test/rules/rest_rules_test.dart test/rules/spell_duration_rules_test.dart
```

Die drei festgestellten Abnahmefehler sind behoben. R3 und die bereits
dokumentierten Architekturabgrenzungen bleiben unverändert offen.

### R3: Übergabe

**Umgesetzt.** `buildKartoCompatTheme` (`lib/ui/bridges/karto_compat_theme.dart`)
bildet die Codex-Farbrollen innerhalb der Brücke auf Kartograph-Token ab; der
Adapter legt es um Bestandsinhalte und Dialoge, UI2 importiert es nicht selbst.
`KartoEntwicklungsansicht` (`lib/ui2/entwicklung/`) ordnet Katalog, AP-Vorschau
und Historie an und liest alle Werte unverändert aus der laufenden
`AdvancementSession`.

**Prüfungen** (lokal, Flutter-Toolchain des Projekts):

| Befehl | Ergebnis |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | 755 Dateien, 0 geändert |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | +1997 ~3, alle bestanden (Ausgangsstand: +1946 ~3) |
| `python tool/check_screen_loc_budget.py` | OK, 21 Dateien |
| `python tool/check_screen_loc_budget.py --root lib/ui2 --recursive` | OK, 22 Dateien |

Das visuelle Raster deckt 320, 390, 744, 768, 1024, 1366 und 1440 dp in beiden
Helligkeiten bei Textskalierung 1 und 2 ab (28 Kombinationen) und erzeugt auf
Wunsch echte PNGs über `--dart-define=R3_SCREENSHOT_DIR=…`.

**Der zuerst abgelegte Stand war nicht lauffähig.** `Strich.haar` gibt es
nicht, wodurch `lib/ui2/` nicht übersetzte und zehn Testdateien schon beim
Laden scheiterten; danach blieben 16 Fehlschläge. Die sechs Ursachen und ihre
Behebung stehen in [redesign_acceptance.md](redesign_acceptance.md) unter
„Befunde der Abschlussprüfung“. Zwei davon betrafen den Bestand: der Kopf von
`AdvancementCatalog` lief bei 320 dp schon bei normaler Schrift über, und ein
fehlgeschlagenes Speichern im Inventareditor verschwand als unbehandelte
asynchrone Ausnahme.

**Abweichungen und bewusste Grenzen.**

1. Bei offener Planung bleibt die **gesamte** Verwaltungsfläche gesperrt; die
   Begründung aus R1 gilt unverändert.
2. Die Rechtsausrichtung numerischer Spalten wurde nicht umgesetzt, nur die
   Tabellenziffern. Kein Test deckt die Ausrichtung ab, und sie hätte das
   visuelle Raster berührt.
3. ARCH-01 bleibt wegen des fehlenden Schadensablaufs **teilweise offen**;
   ARCH-02 bis ARCH-06 sind durch eine neue Darstellung nicht erledigt.
4. Brücke und alte Screens bleiben bestehen. Eine Ablösung und jede Änderung
   des Oberflächenstandards brauchen einen eigenen Auftrag.

## Prüfung dieser Planungsänderung

Am 19.09.2026 wurden die lokalen Dokumentlinks, Codeblock-Abschlüsse und
genannten vorhandenen Einstiegspunkte geprüft. `flutter analyze --no-pub`
meldete keine Probleme; `flutter test --no-pub test/ui/smoke/widget_test.dart
test/ui2` bestand mit 47 Tests. Beide Flutter-Befehle liefen über das installierte
`flutter_tools.snapshot` mit dessen Dart-SDK. Diese Prüfungen bestätigen den
unveränderten Ausgangscode, nicht die noch ausstehende Umsetzung von R1–R3.
