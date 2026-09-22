# Redesign-Abnahme R1–R3

Stand: 22.09.2026. R3 wird gegen den integrierten Stand `d9caee7d` geprüft.
Grundlage: [Spezifikation](superpowers/specs/2026-09-19-codex-redesign-design.md),
[R3-Plan](superpowers/plans/2026-09-19-redesign-03-abschluss.md) und
[Übergaben samt Nachprüfung](redesign_implementation.md).

## Umfang und Datenpfade

Der Kartograph-Workspace verbindet Spielen, Held verwalten und Entwicklung
planen mit demselben Repository, Katalog und ProviderScope wie die bestehende
Oberfläche. Die Bestandsbrücke erhält die Fachansichten und ihre Dialoge.
Eine Steigerung bleibt bis zur erfolgreichen Übernahme ausschließlich in der
bestehenden `AdvancementSession`. Die Spielansicht zeigt gespeicherte Werte.

`buildKartoCompatTheme` übersetzt die bestehenden Codex-Farbrollen in
Kartograph-Token innerhalb der Brücke. Die globale Codex-Gestaltung, der
Oberflächenumschalter und sein Standardwert bleiben erhalten. Es gibt keine
neuen Architekturpakete, Persistenzformate oder Katalogquellen.

## Funktionsparität

Die Einstiege wurden gegen die kanonische Abschnittsliste
`workspace_tab_spec.dart` geprüft. Fachtests testen weiterhin die gemeinsam
genutzten Ansichten; die UI2-Tests prüfen zusätzlich deren echte Verdrahtung.

| Funktion der Spezifikation | Einstieg im Kartograph | Nachweis |
|---|---|---|
| Heldenwahl, leerer Speicher, fehlender Held | Heldenauswahl; Zurück im Workspace | `karto_workspace_test.dart`, `app_root_switch_test.dart`, Journey |
| Ressourcen, Zustände, Wunden | Spielen → Ressourcen ändern / Zustand | `karto_spiel_bruecke_test.dart`, `karto_ressourcenwert_test.dart`, `karto_spielansicht_test.dart` |
| Eigenschaften-, Talent-, Kampf- und Zauberproben | Spielen → Schnellproben / Probe suchen / Strg+K | `karto_spielaktionen_test.dart`, Bestandsbrückentests, Journey; bestehende Probe-Tests |
| Rast und aktive Effekte | Spielen → Rast / Effekte | `karto_spielverlauf_test.dart`, bestehende Rast- und Effektprüfungen |
| Würfelhistorie und Filter | Spielen → Würfelprotokoll am Ende | Journey, `karto_spielverlauf_test.dart`, `dice_log_filter_test.dart` |
| Stammdaten, Herkunft, Merkmale, Avatar | Held verwalten → Übersicht | `karto_verwaltung_test.dart`, Journey, `test/ui/overview/`, `avatar_gallery_image_test.dart` |
| Talente, Sprachen, Schriften, Sonderfertigkeiten | Held verwalten → Talente | Verwaltungskategorien-Test, `test/ui/talents/` |
| Waffen, Rüstung, Kampftalente, Manöver, Rechner | Held verwalten → Kampf | Verwaltungskategorien-Test, `test/ui/combat/` |
| Zauber, magische Fähigkeiten | Held verwalten → Magie bei bestehender Ressourcenaktivierung | Sichtbarkeitstest, `test/ui/magic/`; Rituale behalten ihren bisherigen Weg |
| Ausrüstung und Gegenstände | Held verwalten → Inventar | Speichern/Abbrechen/Fehler in `karto_verwaltung_test.dart`, `test/ui/inventory/`, visuelles Raster |
| Chroniken, Kontakte, Abenteuer, Verbindungen | Held verwalten → Chroniken, Kontakte & Abenteuer | Erreichbarkeit und Editorfälle in `karto_verwaltung_test.dart`, vorhandene Workspace-Tests |
| Reisebericht | Held verwalten → Reisebericht | Echte Ansicht im Verwaltungskategorien-Test |
| Begleiter | Held verwalten → Begleiter | Echte Ansicht im Verwaltungskategorien-Test |
| Gruppen, externe Helden | Held verwalten → Gruppe | Verwaltungskategorien-Test, `test/ui/gruppe/` |
| AP, Erwerb, Steigerung, Fähigkeitenbaum, Vorschau, Historie | Entwicklung planen; mobil AP und Historie | `test/ui2/entwicklung/`, `test/ui/advancement/`, `advancement_session_test.dart`, Journey |
| Import/Export | Workspace-Menü → Helden verwalten → Importieren / Exportieren | `karto_workspace_global_actions_test.dart`, `hero_workspace_import_export_test.dart`, `hero_actions_import_export_test.dart` |
| Einstellungen, Konto/Sync, Kataloge | Workspace-Menü → Einstellungen | Global-Actions-Test; `settings_screen_test.dart`, `settings_sync_page_test.dart`; Kontodienste über bestehende Fakes, kein echter Login |
| Regelsuche | Held verwalten → Regeln nachschlagen auf unterstützten Plattformen | Bestandsdialog und `rules_lookup_dialog_test.dart`; Indexverfügbarkeit bleibt getrennte Voraussetzung |

Import/Export nutzt weiterhin die Bestandsliste. Ein Import kann anschließend
den bestehenden Fachworkspace öffnen. Das ist ein erhaltener Übergangsweg,
keine zweite Datenhaltung. Der Guard prüft einen offenen Plan vor dem Aufruf
der Liste. Exporttests ersetzen nur die Dateiauswahl, nicht die Erzeugung der
Transferdaten. Avatar- und Gruppentests verwenden isolierte Speicher/Gateways;
es wurden keine persönlichen Bilder, Konten oder Cloudgruppen verändert.

## Schutz vor Datenverlust

- Ressourcenänderungen laden den aktuellen Laufzeitzustand vor dem gezielten
  Schreiben; Regression aus `1d2dba8b` bleibt erhalten.
- Die gesamte Verlassen-Prüfung sperrt parallele Editoraktionen einschließlich
  des asynchronen Speicherns; Regression aus `6aed325d` bleibt erhalten.
- Erst der tatsächliche Oberflächenwechsel in den Einstellungen prüft den
  Plan, nicht bereits das Öffnen der Einstellungen; `d9caee7d` bleibt erhalten.
- Moduswechsel erhalten die Sitzung. Planung sperrt alle manuellen
  Heldenbogenänderungen. Wo Bestandsansichten keinen verlässlichen
  Nur-Lesen-Vertrag besitzen, bleibt die komplette Verwaltung gesperrt.
- Übernahmefehler und parallele Heldenänderungen erhalten den Entwurf.
  Laufende Saves sperren weitere Planänderungen; frühere Historie ist nicht
  löschbar. Konto-/Repository- und Heldenwechsel behalten die bestehenden
  Schutzregeln.

## Responsivität und Bedienung

Das Flutter-Prüfraster in `karto_workspace_visual_test.dart` umfasst 320, 390,
744, 768, 1024, 1366 und 1440 dp, beide Helligkeiten und Textskalierung 1/2
(28 Kombinationen, Höhe 1000 dp). Es benutzt die echten Projektschriften,
einen langen Namen, vier Ressourcen, reale Inventareinträge und eine echte
Steigerungsaktion. Leere Listen und Fehlerfälle werden gezielt in Fachtests
geprüft, statt sämtliche Datenvarianten miteinander zu kreuzen.

`karto_workspace_accessibility_test.dart` bedient Tab, Strg+K, Escape und
System-Zurück, prüft benannte Navigation und erhält Eingaben beim abgebrochenen
Verlassen. Das ist eine Prüfung von Flutter-Fokus, Semantik und Interaktion;
ein manueller Durchlauf mit NVDA/VoiceOver und echter Touch-Hardware wurde
nicht durchgeführt. Die Widgettests simulieren Pointer-/Touch-Eingaben.

## Echte Flutter-Screenshots

Die PNGs werden vom Flutter-Test-Renderer über `RenderRepaintBoundary.toImage`
erzeugt, mit `KartoShell`, `KartoBestandsAdapterImpl`, echten Providern und
geladenen Spectral-/Inter-Tight-Schriften. Sie sind keine HTML-Mockups und
keine nachgezeichneten Bilder. Datenquelle ist ein isoliertes FakeRepository,
nicht der persönliche Heldenspeicher. Testheld: **Rondra Alrike von Gareth und
den Silberquellen**, freie AP zu Beginn 1375, vier aktivierte Ressourcen;
der kleine Testkatalog dient der reproduzierbaren Eigenschaftsplanung.

Erzeugung (lokaler SDK-Aufruf entspricht `flutter test`):

```text
flutter test --no-pub test/ui2/shell/karto_workspace_visual_test.dart
  --dart-define=R3_SCREENSHOT_DIR=docs/screenshots/redesign-r3
```

Erzeugt wurden 14 PNGs (1,1 MB) in `docs/screenshots/redesign-r3/`: je
`spielen`, `verwaltung`, `inventar`, `planung` bei 390 dp hell, 1024 dp dunkel
und 1440 dp hell, dazu `plan-details` für das mobile Sheet. Die Namen tragen
Breite und Helligkeit, etwa `planung-1440-light.png`.

**Sichtprüfungsbefund.** Die dunkle Navigation steht bei 1024 und 1440 dp über
die volle Höhe, bei 390 dp als Bottom-Bar; der helle Codex trägt die Inhalte in
beiden Helligkeiten lesbar. Die Detailspalte der Planung zeigt bei 1440 dp
Steigerungsmodus, laufende Runde und übernommene Historie nebeneinander, bei
390 dp führt „AP und Historie" dieselben Inhalte im Sheet. Die AP-Zeile nennt
an beiden Breiten dieselben drei Werte aus der Sitzung (1375 / 410 / 965 AP).
Diesmal fand die Sichtprüfung **keinen** Fehler, den die Widgettests übersehen
hätten — anders als in R1 (zu niedrige Navigationsleiste) und R2 (Protokoll in
der Spaltenmitte). Bewusste Abweichung vom Mockup: auf 390 dp beansprucht die
Planung mit AP-Block, Sheet-Einstieg und Katalogkopf rund zwei Drittel der
Höhe, bevor die erste Steigerungskarte beginnt.

## Prüfprotokoll

| Prüfung | Ergebnis |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | 755 Dateien, 0 geändert |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` vollständig | +1997 ~3, alle bestanden (Ausgangsstand R2: +1946 ~3) |
| Durchgehende Journey mit echten Writes | bestanden |
| Aufgabe 1: Verwaltung und Theme | bestanden |
| Aufgabe 2: Entwicklung, Sitzungen, Regeln | bestanden (`test/ui2/entwicklung` und `test/ui/advancement` 28/28) |
| Visuelles Raster | 28/28 Kombinationen bestanden, kein Überlauf |
| `python tool/check_screen_loc_budget.py` | OK, 21 Dateien ≤ 700 Zeilen |
| `python tool/check_screen_loc_budget.py --root lib/ui2 --recursive` | OK, 22 Dateien ≤ 700 Zeilen |

### Befunde der Abschlussprüfung

Der zuerst abgelegte Stand war **nicht lauffähig**: `Strich.haar` existiert
nicht (`Strich` kennt nur `hoehenlinie`, `grat`, `kueste`, `ufer`), wodurch der
gesamte `lib/ui2/`-Baum nicht übersetzte und zehn Testdateien schon beim Laden
scheiterten. Danach blieben 16 Fehlschläge. Behoben wurden:

1. **Erfundenes Token.** Drei Stellen in `lib/ui2/entwicklung/` auf
   `Strich.hoehenlinie` gesetzt — die Stärke, die laut `karto_stroke.dart` fest
   zum verwendeten Farbtoken `hoehenlinie` gehört.
2. **Verirrter Import.** `test/ui2/shell/karto_workspace_global_actions_test.dart`
   trug `import 'dart:ui' show PointerDeviceKind;` hinter der Klassendeklaration;
   ersetzt durch `package:flutter/gestures.dart` im Importblock, wie im
   Bestandstest `resizable_table_columns_test.dart`.
3. **Überlaufender Katalogkopf.** Alle sieben `RenderFlex`-Überläufe (87 bis
   1085 px) stammten aus `advancement_catalog.dart`: ein fixer, nicht
   scrollbarer Kopf über `Expanded(ListView)`. Der Kopf behält jetzt seine
   natürliche Höhe, solange sie passt, und scrollt erst in sich, wenn der Liste
   sonst keine Zeile mehr bliebe. Das betraf auch den Bestand — der tracked
   Test `karto_bestands_integration_test.dart` lief bei 320 dp schon bei
   normaler Schrift auf 172 px Überlauf.
4. **Überlaufender AP-Kopf.** `KartoEntwicklungsansicht` hatte dieselbe Bauart;
   sie bekam dieselbe Begrenzung mit reservierter Kataloghöhe.
5. **Veraltete Knopfsuche.** R3 benannte den Übernahmeknopf in „Änderungen
   übernehmen" um und gab ihm `ValueKey('karto-plan-commit')`; zwei Teststellen
   suchten weiter den exakten Text „Übernehmen", der jetzt nur noch am
   Dialogknopf des Verlassen-Guards hängt. Beide nutzen nun den Key.
6. **Zwei Tests ohne Implementierung.** Tabellenziffern für die numerischen
   Inventarspalten und die sichtbare Meldung bei fehlgeschlagenem Speichern im
   Inventareditor wurden nachgezogen; der Fehler lief bisher als unbehandelte
   asynchrone Ausnahme ins Leere und der Entwurf blieb ohne Hinweis stehen.

Zwei Fehlschläge des Rastertests waren keine Produktfehler, sondern Testfallen:
`scrollUntilVisible` hält an, sobald der Finder greift, während die `ListView`
über den sichtbaren Bereich hinaus baut, und `ensureVisible` wirkt erst nach
einem Frame. Der Test ruft jetzt `ensureVisible` und `pumpAndSettle` vor dem
Tippen.

Der Windows-Batchstarter hängt in dieser Umgebung. Deshalb wird das
installierte `flutter_tools.snapshot` mit dem zugehörigen Dart-SDK ausgeführt.
Der SDK-Cache benötigt Zugriff außerhalb des Repositorys. Es wurde kein
`flutter clean` benötigt und kein Deployment ausgeführt.

## Bewusste Grenzen und Folgearbeit

| Mockup-Funktion | Stand nach dem UI-Paket | Getrennter Folgeumfang |
|---|---|---|
| Schaden und Rücknahme | Ressourcen-/Wundendialoge erreichbar | ARCH-01/05/06: fachlicher Schadensablauf, atomare Operation, konfliktfeste Korrektur |
| Gemeinsamer Kampfrundenzähler | Bestehende Effektlaufzeiten bedienbar | Rundensemantik und Umfang festlegen |
| Persönliche Favoriten | Schnellproben und vollständige Suche | Persistenz, Umfang und Sync festlegen |
| Strukturierte Merkmale | Katalogauswahl und Freitext bleiben erhalten | ARCH-02: Modell und Migration |
| Identische Inventarinstanzen | Bestehende Inventar-/Kampfzuordnung | ARCH-03: Instanz-IDs und Migration |
| Regelprofil und vollständige Herleitung | Tatsächlich vorhandene Einstellungen/Vorschauen | ARCH-04: Versionierung und nachvollziehbare Ergebnisse |
| Offline-/Sync-Anzeige | Keine erfundenen Statusangaben | ARCH-06: persistente Outbox und Konfliktmodell |

ARCH-01 bleibt wegen des Schadensablaufs **teilweise offen**. ARCH-02 bis
ARCH-06 werden durch eine neue Darstellung nicht erledigt. Die Brücke und
alten Screens bleiben bestehen; eine spätere Ablösung und jede Änderung des
Oberflächenstandards erfordern einen eigenen Auftrag.

## Gestalterische Überarbeitung (22.09.2026)

Die Abnahme oben prüfte Funktionsumfang und Informationsarchitektur. Der
Bildvergleich zwischen `docs/mockups/hero-workspace-redesign-desktop.png` und
dem damaligen `spielen-1440-light.png` zeigte danach, dass die **visuelle**
Qualität des Mockups nicht erreicht war. Ursache war nicht die Schriftwahl,
sondern die Anwendung der vorhandenen Token.

### Befund

| # | Befund | Ursache |
|---|---|---|
| 1 | Keine Flächenhierarchie; sechs gleich aussehende Kästen | `KartoAbschnitt` setzte nur einen Rahmen, kein `color`. Inhalt und Seitengrund waren beide `blatt`. |
| 2 | Dunkle Navigationsspalte zu ~85 % leer | Sie trug nur die drei Bereichsziele. |
| 3 | Kein Seitenkopf | Die Schriftrolle `titelGross` (34) kam nirgends vor; alles begann bei 18. |
| 4 | Kursivrauschen | Eine 15-px-Kursivzeile unter **jedem** Abschnittstitel, meist ohne Aussage. |
| 5 | Ressourcen betonten das Falsche | `'27 / 22'` ganz in Ressourcenfarbe, beide Zahlen gleich groß; 2,5-dp-Balken direkt unter dem Text las sich als Unterstreichung. |
| 6 | „Formular“ statt „Codex“ | Radius 2 auf allem, dazu überall dieselbe 1-px-Kante. |

### Entscheidung

Freigegeben wurde, Maße und Flächenbehandlung an das Mockup anzugleichen;
Schriften und Token-Architektur blieben unberührt. Der Nachtrag steht in
`docs/superpowers/specs/2026-09-19-codex-redesign-design.md`.

**Die Palette musste dafür nicht geändert werden.** `feld` und `senke`
kodierten die richtige Beziehung zu `blatt` bereits, wurden aber fast nur als
Eingabefüllung benutzt. Aus der Umwidmung entstand die dreistufige
Flächenhierarchie `senke` < `blatt` < `feld`, die in beiden Paletten dieselbe
Richtung hat. `karto_contrast_test.dart` prüft Text gegen alle drei Flächen
bereits auf 4,5:1, die Umwidmung war damit abgesichert.

Geändert wurden: `kKartoRadius` 2 → 8 (neu daneben `kKartoRadiusKlein` 4 für
Chips, Knöpfe und Kacheln), `KartoBreite.seitenrand` 16/20/24/32 → 20/28/36/44,
Panelkante von `grat` auf `hoehenlinie`, Eingabefüllung von `feld` auf `senke`
(ein Feld ist eingelassen, nicht erhoben; auf `feld` wäre es innerhalb eines
Abschnitts farbgleich).

### Neue Bausteine

| Datei | Aufgabe |
|---|---|
| `lib/ui2/widgets/karto_flaeche.dart` | `KartoFlaeche` mit `KartoFlaechenstufe`; erzwingt die Paarung Strichgewicht ↔ Farbtoken wie `Strich` |
| `lib/ui2/widgets/karto_seitenkopf.dart` | Kontextzeile, Seitentitel, eine Seitenaktion; einzige Verwendung von `titelGross` |
| `lib/ui2/shell/karto_heldenmarke.dart` | Bild oder Monogramm in gleicher Ringfassung, Name, Herkunft |

Die Identitätsspalte zeigt den echten Avatar. Weil Bilder ausschließlich
`AvatarGalleryImage` rendern darf, läuft er über die neue Adaptermethode
`KartoBestandsAdapter.heldenbild`. `avatarBytesProvider` wäre aus UI2 direkt
erreichbar — ein eigenes Bildwidget darauf verlöre die drei getrennten
Zustände und den `ImageCache`-Treffer. Helden ohne Bild bekommen ein
ringgefasstes Monogramm.

Auf breiten Fenstern entfällt die `AppBar`; „Heldenauswahl“ und
„Workspace-Menü“ wandern in den Fußbereich der Spalte und behalten ihre
Tooltips. Auf schmalen Fenstern bleibt alles wie zuvor.

### Warum kein Test brach

Die bestehenden Pins blieben unverändert gültig, auch die heiklen:

- **`find.text('23 / 35')`** überlebt die Aufteilung in großen Wert und leises
  Maximum, weil `Text.rich` verwendet wird und `_MatchTextFinder` bei fehlendem
  `Text.data` auf `textSpan.toPlainText()` zurückfällt
  (`flutter_test/lib/src/finders.dart`). Dieselbe Technik trägt die AP-Zeilen
  `'Frei zu Beginn: 1375 AP'`.
- **`LinearProgressIndicator`** bleibt als Widgettyp erhalten; geändert wurden
  nur `minHeight` (2,5 → 5) und die Rinnenfarbe (`raster` statt `hoehenlinie`).
- **`kKartoRadius`** wird in `karto_compat_theme_test.dart` gegen die Konstante
  verglichen, nicht gegen einen Zahlenwert.
- Alle Abschnittstitel, Navigationslabels, Verwaltungstexte und `ValueKey`
  blieben wörtlich. Die Seitentitel sind deshalb bewusst **„Am Spieltisch“**
  und **„Nächste Schritte“**: eine Wiederholung der Navigationsbeschriftungen
  hätte die `findsOneWidget`-Prüfungen gebrochen.

Neu hinzugekommen sind `test/ui2/widgets/karto_flaeche_test.dart`,
`test/ui2/widgets/karto_seitenkopf_test.dart`,
`test/ui2/shell/karto_heldenmarke_test.dart` und
`test/ui2/shell/karto_identitaet_test.dart` (Anbindung von `heldenbild`).

### Sichtprüfungsbefunde

Zwei Fehler fanden erst die neu erzeugten Screenshots, keine Widgetprüfung:

1. **Der Seitenkopf der Planung stand zentriert.** `Column` richtet seine
   schrumpfenden Kinder ohne `crossAxisAlignment: stretch` mittig aus. Betraf
   auch den Sperrhinweis der Verwaltung.
2. **Auf 390 dp verschärfte der neue Seitentitel ein bekanntes Platzproblem.**
   Die Abnahme oben hatte bereits notiert, dass die Planung dort zwei Drittel
   der Höhe braucht, bevor die erste Steigerungskarte beginnt. Schmale Fenster
   bekommen in der Planung deshalb **keinen** Seitentitel; der Katalog darunter
   führt mit „Steigerungen planen“ ohnehin seine eigene Überschrift.

Außerdem wurde die Navigationsspalte dreistufig breit (272/248/208 dp): mit
durchgehend 232 dp nahm sie auf Tabletbreiten fast ein Drittel der Fläche ein.

### Bewusst nicht enthalten

Keine neuen Funktionen. Die Negativprüfung in
`test/ui2/spielen/karto_spielverlauf_test.dart` blieb unverändert und sperrt
weiterhin Schadensknopf, KR-Zähler, Favoriten und erfundene Sync-Angaben.

Die über `KartoBestandsAdapter` eingebundenen Ansichten aus `lib/ui/` wurden
nicht überarbeitet; sie erben nur die Theme-Änderungen über
`buildKartoCompatTheme`. Sichtbar bleibt das an drei Stellen: der
Steigerungskatalog führt unter dem Seitentitel seine eigene Überschrift samt
kursiver Erläuterung, seine Metazeilen sind weiterhin punktverbundene
Fließtexte (`Wert: 15 · Maximum: 21 · SE: 0`) statt ausgerichteter Zahlen, und
die Rechtsausrichtung numerischer Inventarspalten steht weiterhin aus.
