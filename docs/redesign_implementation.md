# Redesign umsetzen: Übergabe an weitere Agenten

Stand: 19.09.2026 · geprüfter Ausgangsstand: `8501232b`.

Dieses Dokument enthält **Umsetzungspläne und kopierfertige Startprompts** für
das freigegebene [Mockup](mockups/README.md). **R1 ist umgesetzt** (siehe
Übergabestatus); R2 und R3 sind noch offen.

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
| R2 | offen | noch keine | Spielansicht in UI2 noch nicht implementiert |
| R3 | offen | noch keine | Integrierte Planung und Gesamtabnahme noch offen |

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

**Abweichungen und bewusste Grenzen.**

1. Bei offener Planung ersetzt ein erklärter Sperrhinweis die **gesamte**
   Verwaltungsfläche, statt einzelne Schreibaktionen zu deaktivieren. Inventar-
   und Gruppenaktionen speichern sofort und lassen sich noch nicht einzeln
   abschalten; eine scheinbar bearbeitbare Fläche wäre schlechter. Der Plan
   lässt diesen Zwischenstand ausdrücklich zu.
2. `spielDetails` ist in R1 der vorhandene `InspectorPanel`, ergänzt um die
   Direktaktionen Probe, Rast und Effekte. Die Spielanordnung des Mockups
   ersetzt R2.
3. Einstellungen und Token-Blatt prüfen nur den Editor-Dirty-Guard, nicht den
   offenen Plan. Sie legen einen Screen auf den Workspace, bauen ihn nicht ab,
   und die Sitzung liegt im gemeinsamen `ProviderScope`. Die Planabfrage
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

## Prüfung dieser Planungsänderung

Am 19.09.2026 wurden die lokalen Dokumentlinks, Codeblock-Abschlüsse und
genannten vorhandenen Einstiegspunkte geprüft. `flutter analyze --no-pub`
meldete keine Probleme; `flutter test --no-pub test/ui/smoke/widget_test.dart
test/ui2` bestand mit 47 Tests. Beide Flutter-Befehle liefen über das installierte
`flutter_tools.snapshot` mit dessen Dart-SDK. Diese Prüfungen bestätigen den
unveränderten Ausgangscode, nicht die noch ausstehende Umsetzung von R1–R3.
