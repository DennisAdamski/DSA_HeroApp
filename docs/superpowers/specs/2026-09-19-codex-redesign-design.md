# Codex-Redesign: Umsetzungsspezifikation

Stand: 19.09.2026 · Codebasis: `8501232b` · Status: für nachfolgende Umsetzung.
Auftrag: freigegebenes Mockup in die vorhandene Flutter-App überführen.
Einstieg und Startprompts: [Redesign-Übergabe](../../redesign_implementation.md).

## Freigegebenes Ziel und vorhandenes Fundament

Visuelle Referenz sind [HTML-Mockup](../../mockups/hero-workspace-redesign.html)
und die dort verlinkten Desktop-/Mobilbilder. Helle, ruhige Arbeitsflächen,
dunkle Navigation, gut lesbare Tabellen und zurückhaltende Fantasy-Details.
Drei Bereiche heißen **Spielen**, **Held verwalten**, **Entwicklung planen**.

Der inzwischen vorhandene Kartograph-Unterbau bleibt erhalten: `KartoTheme`,
`Abstand`, `Strich`, `KartoBreite`, Spectral und Inter Tight. Das ist die
technische Gestaltungsbasis; Cinzel/Segoe UI aus dem HTML werden nicht
zusätzlich als konkurrierendes Flutter-Designsystem eingeführt.
Den visuellen Gesamteindruck anhand echter Flutter-Screenshots überprüfen.
Heller Modus ist die Hauptreferenz, dunkler Modus bleibt bedienbar.

> **Nachtrag 22.09.2026 — Maße und Flächen freigegeben.** Der Satz oben
> untersagte ursprünglich auch „große Rundungen“. Die Abnahme von R1–R3 hat
> gezeigt, dass dadurch der sichtbare Abstand zum Mockup blieb: Abschnitte
> trugen nur einen Rahmen auf dem Seitengrund und standen mit Radius 2 als
> gleichförmige Formularkästen untereinander. Freigegeben sind seither
> `kKartoRadius` 8 (plus `kKartoRadiusKlein` 4) und die dreistufige
> Flächenhierarchie `senke`/`blatt`/`feld`. **Die Schriften und die
> Token-Architektur sind davon ausdrücklich nicht berührt.** Umsetzung und
> Begründung stehen in [redesign_acceptance.md](../../redesign_acceptance.md)
> im Abschnitt „Gestalterische Überarbeitung“.

`AppRootSwitch` unter `SyncConflictGate` bleibt die Startweiche. Kein zweites
`MaterialApp`, `AppStartupGate`, Repository oder Sync-System. Die bestehende
Oberfläche bleibt bis zu einer gesonderten Ablösung auswählbar.

## Funktionsmatrix: nichts durch das Mockup verlieren

| Bestehender Bereich / Funktion | Neuer Ort | Bestehender Einstieg |
|---|---|---|
| Heldenwahl und leerer Speicher | Heldenauswahl vor dem Workspace | `heroListProvider`, `selectedHeroIdProvider`, `selectedHeroSelectionActionsProvider` |
| Ressourcen, Zustände und Wunden | Spielen; Details erreichbar | `heroComputedProvider`, `InspectorVitalsTab`, Wundendialoge |
| Eigenschaften-, Talent-, Kampf- und Zauberproben | Spielen: Probensuche und Schnellaktionen | `probe_quick_search.dart`, `probe_request_factory.dart`, `dice_log_persistence.dart` |
| Rast und aktive Effekte | Spielen: direkte Aktionen | `showRestDialog`, `showActiveSpellEffectsDialog` |
| Würfelhistorie und Filter | Spielen: Protokoll | `InspectorDiceLogSection`, `HeroState.diceLog` |
| Stammdaten, Herkunft, Merkmale, Avatar | Held verwalten: Übersicht | `WorkspaceTabIds.overview` |
| Talente, Sprachen, Schriften, Sonderfertigkeiten | Held verwalten: Talente | `WorkspaceTabIds.talents` |
| Waffen, Rüstung, Kampftalente, Manöver, Rechner | Held verwalten: Kampf | `WorkspaceTabIds.combat` |
| Zauber und magische Fähigkeiten | Held verwalten: Magie, vorhandene Sichtbarkeitsregel | `WorkspaceTabIds.magic` |
| Ausrüstung und Gegenstände | Held verwalten: Inventar | `WorkspaceTabIds.inventory` |
| Chroniken, Kontakte, Abenteuer und Verbindungen | Held verwalten: Notizen-Bereich | `WorkspaceTabIds.notes` |
| Reisebericht | Held verwalten: Reisebericht | `WorkspaceTabIds.reisebericht` |
| Begleiter | Held verwalten: Begleiter | `WorkspaceTabIds.begleiter` |
| Gruppen und externe Helden | Held verwalten: Gruppe | `WorkspaceTabIds.gruppe` |
| AP, Erwerb, Steigerung, Fähigkeitenbaum, Vorschau und Historie | Entwicklung planen | `advancementSessionProvider`, `lib/ui/screens/advancement/` |
| Import/Export, Einstellungen, Konto/Sync, Kataloge, Regelsuche | Globale Aktionen bzw. bisherige Fachdialoge | `workspace_import_export_actions.dart`, `SettingsScreen`, `rules_lookup_dialog.dart` |

Die kanonische Abschnittsliste und Sichtbarkeit kommen aus
`workspace_tab_spec.dart`; UI2 führt keine zweite manuell gepflegte Neuner-Liste
ein. Die Matrix beschreibt Funktionsparität, keine Erlaubnis für neue Regeln.
Rituale und Liturgien behalten ihren aktuellen Erwerbsweg; sie erhalten nicht
nebenbei ein erfundenes `AdvancementKind`.

## Architektur und begrenzter Übergangsadapter

Neue Anordnung und Navigation gehören nach `lib/ui2/`. Bestehende fachlich
umfangreiche Ansichten sollen zunächst weiterverwendet werden. Dazu wird in R1
eine explizite, vorübergehende UI-Brücke eingeführt:

- `lib/ui2/shell/karto_bestands_adapter.dart`: Schnittstelle ohne Import aus
  `lib/ui/`, `lib/data/` oder konkretem Repository. Enthält nur Widget-Fabriken
  und Aufrufe vorhandener Dialoge, keine Regeln und keine Persistenz.
- `lib/ui/bridges/karto_bestands_adapter_impl.dart`: Implementierung mit
  Bestandswidgets. Bei wachsendem Umfang nach Verwaltung/Spielen/Planung in
  dieser Bridge-Schicht aufteilen. Kein universeller Service-Locator.
- `AppRootSwitch` erstellt die Implementierung und injiziert sie in
  `KartoShell`. Nur diese Datei innerhalb von `lib/ui2/` importiert aus `lib/ui/`.
- Bestandsimporte in neuen Fachwidgets bleiben verboten. Die bisherige Aussage
  „nur die Startweiche verbindet beide Bäume“ wird bei R1 präzisiert: Die
  Startweiche ist der einzige Verdrahtungspunkt; der injizierte Adapter ist die
  dokumentierte Übergangsverbindung. Keine unmarkierten Ausnahmen.
- Verwaltung nutzt einen herausgelösten `WorkspaceManagementBody` ohne äußere
  AppBar, globale Navigation oder zweiten Inspector. Kein kompletter
  `HeroWorkspaceScreen` als verschachtelter Screen in einem Screen.
- Der Adapter wird abschnittsweise entbehrlich, sobald ein Bereich vollständig
  nach UI2 übertragen ist. Seine Entfernung ist kein Abnahmekriterium von R3.

Diese Brücke ist eine bewusste Planentscheidung: Funktionsparität vor einem
gleichzeitigen Neuschreiben aller neun Fachbereiche. Dokumentation und Tests
der bestehenden Oberfläche werden beim Herauslösen mitgeführt.

### Geplante öffentliche Übergabeverträge

R1 führt diese Namen ein; sie existieren am Ausgangsstand noch nicht:

```dart
/// Die drei Aufgabenbereiche innerhalb desselben Helden.
enum KartoArbeitsbereich { spielen, verwalten, entwickeln }

/// Prüft das Verlassen eines Editors; false erhält Ansicht und Entwurf.
typedef KartoVerlassenPruefung = Future<bool> Function();
```

`KartoWorkspace({super.key, required String heroId,
required KartoBestandsAdapter bestand})` ist der gemeinsame Host.
`KartoShell({super.key, required KartoBestandsAdapter bestand})` zeigt
Heldenauswahl oder Workspace. Kein unabhängiger zweiter Heldenauswahl-Provider.

Minimaler Adaptervertrag für R1 (Methoden jeweils dokumentieren):

```dart
abstract interface class KartoBestandsAdapter {
  Widget verwaltung({
    required String heroId,
    required bool korrekturenGesperrt,
    required ValueChanged<KartoVerlassenPruefung?> onVerlassenRegistriert,
  });
  Widget planKatalog(String heroId);
  Widget planHistorie(String heroId);
  Widget spielDetails(String heroId);
  Future<void> heldenVerwalten(BuildContext context);
  Future<void> einstellungen(BuildContext context);
  Future<void> probeSuchen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
  });
  Future<void> rast({required BuildContext context, required String heroId});
  Future<void> effekte({required BuildContext context, required String heroId});
}
```

Die Schnittstelle darf Flutter, Riverpod und das lokale Bereichsmodell
importieren. `spielDetails` ist in R1 der vorhandene Inspector als befristeter
Inhalt, kein zweites Zustandsmodell. `heldenVerwalten` öffnet vorübergehend
`HeroesHomeScreen` für Anlegen/Import und weitere Listenaktionen; beim Rückweg
liest die Shell die vorhandene Auswahl erneut. `einstellungen` öffnet den
bestehenden `SettingsScreen`. Beide Wege laufen nach dem Workspace-Guard.
R2 ersetzt die Spielanordnung und zerlegt
sichtbare Bausteine, ohne die Regellogik zu kopieren. Neue Adaptermethoden erst
mit konkretem Aufrufer und Test ergänzen; beide Seiten im selben Commit ändern.

## Zustands- und Schreibregeln

1. `heroComputedProvider(heroId)` liefert gemeinsam Held, Laufzeitzustand,
   Aktivierungen, Attribute, Ressourcenmaxima und Kampfvorschau. UI2 liest
   dessen Ableitungen nicht nochmals einzeln. Die Heldenliste darf ihren
   Listenprovider nutzen, die Planung ihren Sitzungskatalog und -provider.
2. UI2 schreibt Heldenzustand über `heroActionsProvider`; Steigerungen über
   den bestehenden `AdvancementSessionController`, der den vorhandenen
   Schreibpfad benutzt. Kein direktes `repo.saveHero` im Widget.
3. Eingaben, die Daten überschreiben, verwenden den aktuellen Zustand beim
   Anwenden und melden Speicherfehler sichtbar. Kein Erfolgshinweis vor dem
   abgeschlossenen Future und kein blindes Zurückschreiben alter Snapshots.
4. Wechsel von Spielen zu Verwaltung/Entwicklung erhält die Steigerungssitzung.
   Nur ausdrückliches Verwerfen oder erfolgreiche Übernahme schließt sie.
   Ein Katalogfehler darf keine leere oder zweite Sitzung starten.
5. Während eine Sitzung existiert, sind manuelle `HeroSheet`-Korrekturen und
   Import gesperrt. Hinweis mit Weg zur Planung anzeigen. Spielen zeigt
   gespeicherte Werte, niemals `session.preview` als bereits wirksamen Helden.
   Laufzeitaktionen auf `HeroState` bleiben über bestehende Wege möglich.
6. Dirty-Guard der Verwaltung gilt für Moduswechsel, Heldenwechsel, Zurück,
   Einstellungen mit Oberflächenwechsel und Rückkehr zur Bestandsoberfläche.
   Speichern fehlgeschlagen oder „Weiter bearbeiten“ bedeutet: nicht wechseln.
7. Heldenwechsel und Verlassen des Workspace fragen zusätzlich bei einem
   offenen Plan nach Weiterplanen / Verwerfen / Übernehmen. Keine automatische
   Persistenz eines Entwurfs, keine neue JSON-Struktur für Navigationszustand.
8. Konto-/Repositorywechsel übernimmt das vorhandene Sitzungsverhalten.
   Gelöschter Held führt in einen erklärten Leerzustand; keine fremden Daten
   unter einer alten ID anzeigen. Dialoge bleiben schließbar.

## Layout und Bedienung

- Breakpoints aus `KartoBreite`: 744, 1024, 1366 dp; keine HTML-Pixelwerte als
  zweite Breakpoint-Sammlung. Unter 744 drei gut erreichbare Modusziele,
  Details als Sheet oder normaler Folgeabschnitt. Ab 1366 dunkle Navigation,
  Arbeitsfläche und Kontextspalte. Dazwischen schmalere Navigation und Details
  nur soweit der Inhalt Platz hat.
- Im Spielen-Modus: Ressourcen zuerst, dann Schnellaktionen/Kampf, Effekte und
  Würfelprotokoll. Mobile Reihenfolge bleibt sinnvoll ohne eine rechte Spalte.
- Neue Textgrößen, Farben und Abstände kommen aus den bestehenden Token.
  Dunkle Navigation benötigt eigene semantische Hintergrund-/Textrollen;
  `schriftAufSignal` nicht ungeprüft auf dunklem Hintergrund benutzen.
- Fokus sichtbar, Tastaturbedienung, Tooltips/semantische Namen für Icons,
  mindestens 48 dp bedienbare Ziele und lesbare Anzeige bei Textskalierung 2.
- Listenaktionen stehen im Abschnittskopf und heißen `+ <Singular>`.
  Leere Listen erhalten Erklärung und passende Aktion, keine Demo-Einträge.
- Loading, Fehler, fehlender Katalog, unbekannter Held, leere Suche und
  fehlende Berechtigungen sind sichtbare Zustände mit sinnvollem Rückweg.

## Mockup-Elemente mit eigenem Folgeumfang

| Mockup zeigt | Erster produktiver Stand R1–R3 | Eigenständige Folgearbeit |
|---|---|---|
| Schaden mit Rücknahme | Bestehende Ressourcen- und Wundenbedienung erreichbar; keine pauschale Schadens-/Undo-Schaltfläche vortäuschen | ARCH-01/05/06: Schadensregeln, atomare Operation und konfliktfeste Korrektur |
| KR-Zähler und gemeinsames Weiterzählen | Vorhandene Effektlaufzeiten bedienbar | Neue Rundensemantik erst mit definiertem Umfang; keine implizite Spielleiterverwaltung |
| Favoriten | Eigenschafts-/Kampf-Schnellproben und komplette Probensuche | Persistente persönliche Favoriten brauchen Modell, Umfang und Sync-Entscheidung |
| Strukturiert erworbene Merkmale | Vorhandene Katalogauswahl/Textspeicherung unverändert | ARCH-02: Migration und regelwirksame Struktur |
| Durchgängig identische Ausrüstungsinstanzen | Vorhandene Inventar-/Kampfzuordnung weiterverwenden | ARCH-03: Instanz-IDs und Migration |
| Frei wählbares Regelprofil, vollständige Wert-Herleitung | Nur tatsächlich vorhandene Einstellungen/Herleitungen anzeigen | ARCH-04: Versionierung und nachvollziehbare Ergebnisse |
| Offline-/Sync-Status | Nur echte Providerzustände; sonst Statusangabe weglassen | ARCH-06: persistente Outbox und Konfliktmodell |

R1–R3 ergeben einen produktiven UI-Zwischenstand. Sie schließen weder alle sieben
Roadmap-Punkte noch ARCH-01 mit seinem zusätzlichen Schadensablauf vollständig ab.
