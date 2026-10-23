# Oberfläche: Bestand, Kartograph (UI2), Theme und Bedienung

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- [Redesign umsetzen](../redesign_implementation.md) enthält drei aufeinander
  aufbauende Agentenpläne, Startprompts und die gemeinsame Umsetzungsspezifikation
  unter `docs/superpowers/`. Ausgangspunkt ist das vorhandene UI2-Fundament;
  R1 samt Bestandsbrücke, R2 und R3 sind implementiert und ARCH-01 ist
  abgenommen (manuelle Bedienprüfung 15.10.2026); der Nachweis steht in
  [docs/redesign_acceptance.md](../redesign_acceptance.md). Vor Folgearbeit
  den Paketstatus und die Nachprüfung lesen. Die Navigation hat drei Arbeitsbereiche.
- `CodexPageScaffold` legt eine transparente `Material`-Fläche über den
  Seitenhintergrund, damit `ListTile`-/`ExpansionTile`-Hintergründe und
  Ink-Effekte sichtbar bleiben. Der Regressionstest liegt unter
  `test/ui/widgets/codex_page_scaffold_test.dart`. Dasselbe gilt für
  `KartoPapier` und `KartoFlaeche`: beide tragen diese Schicht selbst
  (`test/ui2/widgets/karto_tintenschicht_test.dart`). Flutter prüft in
  `ListTile.build` jede `ColoredBox`, `DecoratedBox` und `ShapeDecoration` mit
  Farbe zwischen Kachel und nächstem `Material` — jede neue farbige Fläche,
  die Bestandskacheln aufnimmt, braucht deshalb ebenfalls eine eigene
  `Material`-Schicht (oder `ListTileMaterial`).
- Die adaptive Settings-Navigation wird von `lib/ui/screens/settings_screen.dart`
  orchestriert; wiederverwendbare Teilseiten liegen unter
  `lib/ui/screens/settings/`.
- **Die Oberfläche wird neu gebaut.** Bestand (`lib/ui/`) und Neubau
  (`lib/ui2/`, Bildsprache „Kartograph") laufen nebeneinander;
  `AppSettings.oberflaeche` wählt unter `Einstellungen > Darstellung`. Die
  Weiche ist `AppRootSwitch` (`lib/ui2/shell/karto_app_root.dart`) als `child`
  von `SyncConflictGate` — der **einzige Verdrahtungspunkt** beider Bäume und
  die einzige Datei unter `lib/ui2/`, die aus `lib/ui/`
  importiert. Sie muss dort bleiben: ein zweites `AppStartupGate` baute
  Heldenspeicher, Sync und Katalog ein zweites Mal auf. Dass ein Wechsel nichts
  darunter anfasst, hängt daran, dass der Settings-Listener des Gates nur auf
  `heroStoragePath` reagiert; `test/ui2/shell/app_root_switch_test.dart` pinnt
  das. Der Neubau liest nur `heroComputedProvider` (nie dessen vier
  Ableitungen einzeln) und schreibt nur über `heroActionsProvider`.
  Die UI-Variante `klassisch` ist entfallen, es gibt nur noch Hell und Dunkel.
- **Der Neubau hat drei Arbeitsbereiche für denselben Helden**
  (`KartoArbeitsbereich`: `spielen`, `verwalten`, `entwickeln`). `KartoShell`
  zeigt Heldenwahl oder `KartoWorkspace`, die Bereichsnavigation
  (`karto_modus_navigation.dart`) ist rein darstellend und ändert selbst keinen
  Provider. Die dunkle Navigation über dem hellen Codex hat eigene Token
  (`navigation`, `navigationText`, `navigationMuted`); `schriftAufSignal` gehört
  zu `meer`/`siegel` und darf dort **nicht** ersatzweise stehen.
- **`KartoBestandsAdapter` ist die dokumentierte Übergangsbrücke** zu den
  vorhandenen Fachansichten, solange UI2 sie noch nicht selbst trägt. Die
  Schnittstelle liegt in `lib/ui2/shell/karto_bestands_adapter.dart` und
  importiert nichts aus `lib/ui/`, `lib/data/` oder einem Repository; die
  Implementierung `KartoBestandsAdapterImpl`
  (`lib/ui/bridges/karto_bestands_adapter_impl.dart`) hält die Bestandswidgets.
  Die Richtung ist entscheidend: `lib/ui/` importiert aus `lib/ui2/`, nie
  umgekehrt. `AppRootSwitch` erzeugt die Implementierung und injiziert sie;
  produktive Konstruktoren bekommen keinen stillen Fallback-Adapter. Neue
  Adaptermethoden nur mit konkretem Aufrufer und Test, beide Seiten im selben
  Commit. Die Brücke wird abschnittsweise entbehrlich, ihre Entfernung ist kein
  Abnahmekriterium.
- **Der Konto-Sync steht als ruhiger Eintrag im Workspace**
  (`_SyncAnzeige` in `karto_workspace.dart`, Key `karto-sync-anzeige`): breit im
  Navigationsfuß, schmal als AppBar-Symbol mit Tooltip. Wortlaut und Rangfolge
  (Konflikte, offene Entscheidungen, Fehler, laufender Abgleich, Zeitpunkt) liefert
  `beschreibeKartoSync` aus dem `SyncStatusSnapshot`; ohne Konto gibt es keinen
  Eintrag. Der Zeitpunkt ist absolut, weil der Statusstrom nur Änderungen meldet.
  Konflikte löst man weiter unter „Einstellungen > Konto & Sync“.
- **Die Spielansicht des Neubaus liegt in `lib/ui2/spielen/`.**
  `KartoSpielansicht` liest `heroComputedProvider(heroId)` **einmal** und reicht
  den `HeroComputedSnapshot` an alle Abschnitte weiter — auch an die
  Adaptermethoden, damit die Brücke für dieselben Werte keine zweite
  Providerbeobachtung aufmacht. Die Reihenfolge ist überall
  Schnellaktionen (ganz oben), Ressourcen, Abenteuer samt Standort,
  Eigenschaften, Vor- und Nachteile, Kampf, Effekte, Zustand,
  Würfelprotokoll. Die Schnellaktionen enthalten „Regeln“ (Key
  `karto-spiel-regeln`): der vorhandene Regelnachschlag über die Brücke
  (`regelnNachschlagen`, `regelnNachschlagenVerfuegbar`); wo es keinen
  Regelindex gibt (Mobile), entfällt der Knopf. Die Eigenschaften stehen als
  schmale Würfelleiste (`KartoAbschnitt.dicht`,
  `InspectorAttributeProbes(kompakt: true)`: einzeilige Karten in 8, 4 oder 2
  Spalten; die klassische Optik bleibt beim Standard). Der Abschnitt
  „Abenteuer“ (`karto_abenteuer_abschnitt.dart`) trägt Titel, aventurisches
  Datum, Standort (`KartoStandortZeile`, hängt am Zustand, nicht am
  Abenteuer), Kurzbeschreibung (3 Zeilen, „Mehr“), eine Schnell-Erfassung
  für Notizen und die Karten für Personen und Notizen. Alles lässt sich dort
  direkt ändern; „Öffnen“ (Key `karto-spiel-abenteuer-oeffnen`) bleibt der Weg
  zum Vollblatt. Gezeigt werden zunächst drei Personen und vier Notizen nach
  der gewählten Sortierung, „Alle zeigen“ klappt inline auf. Ohne laufendes
  Abenteuer bleibt der Abschnitt mit dem Standort stehen. Der Seitenkopf heißt
  immer schlicht „Am Spieltisch“. Der Schreibweg liegt gemeinsam mit dem
  Abenteuerblatt im Mixin `KartoAbenteuerSchreiben`
  (`karto_abenteuer_schreiben.dart`); die Standortspeicherung läuft weiter über
  die Brücke (`standortSetzen`). Die Ressourcenwerte sind kompakt: Wert und
  Fehlbetrag teilen eine Zeile, die ganze Zelle ist das Tippziel. Ab
  `KartoBreite.breit` wandern Kampf, Effekte und Zustand in eine Seitenspalte,
  das Protokoll bleibt der letzte Abschnitt beider Anordnungen. Den
  Re-Entrancy-Guard reicht `KartoWorkspace` als `KartoLaufzeitAktion` herein;
  die Spielansicht macht keinen zweiten Fehlerweg auf.
- **Vor- und Nachteile bearbeitet UI2 im Merkmalsblatt**
  (`lib/ui2/merkmale/`), nach dem Muster des Abenteuerblatts: modal, eigener
  Schreibweg über `HeroActions.updateHero` und `aendereMerkmale`
  (nur die Merkmalslisten samt Projektion), Fehler im Blatt, bei offener
  Planung schreibgeschützt. Eine Abweichung durch eine ältere App löst es nur
  über die beiden Knöpfe (`loeseMerkmalAbweichung`); bis dahin ist Anlegen und
  Ändern dieser Art gesperrt, `aendereMerkmale` wirft sonst. Karteninhalt
  (Katalogname, Stufe/Auswahl, Wirkungstexte, Herkunft) liefert
  `beschreibeMerkmal` (`hero_merkmal_anzeige_rules.dart`) aus denselben
  Beträgen wie die Rechnung. Einstieg ist der Abschnitt „Vor- und Nachteile“
  der Spielansicht; vor Abenteuer- und Merkmalsblatt läuft dieselbe
  Editorprüfung `vorHeldenbearbeitung`. Der Übersichts-Tab der Verwaltung
  bleibt parallel bestehen.
- `KartoRessourcenwert` ist rein darstellend. Der Balkenanteil wird auf 0..1
  begrenzt, der **gespeicherte Wert nie**: negative Lebenspunkte, Überheilung
  und Maximum 0 bleiben unverkürzt lesbar. AsP und KaP zeigt
  `KartoRessourcenleiste` nur bei tatsächlich aktivierter Ressource
  (`resourceActivation`), nie aufgrund einer Profession. Karma bekommt bewusst
  keine eigene Farbe — nur LeP, AsP und AuP haben ein Ressourcentoken.
  Bearbeitet wird über `ressourceBearbeiten`, das in der Brücke den vorhandenen
  `InspectorVitalBlock` in einem Blatt öffnet (±5/±1, Zurücksetzen,
  Untergrenze `kVitalFloor`). **Nicht** `showResourceStepperDialog`: der klemmt
  auf `0..max` und könnte negative Werte gar nicht erzeugen.
  Ressourcenänderungen verwenden `HeroActions.updateHeroState`: vor dem
  Schreiben den Zustand aus dem gemeinsamen Repository neu laden und nur das
  betroffene Feld ersetzen. Ein beim Rendern erfasster Gesamtsnapshot darf
  zwischenzeitliche Änderungen anderer Ressourcen nicht überschreiben.
  Dieser Weg ist keine Transaktion gegen parallele externe Schreibvorgänge.
- Eigenschafts- und Kampf-Schnellproben liegen seit R2 als
  `InspectorAttributeProbes` und `InspectorCombatProbes` in
  `inspector/widgets/`; `InspectorProbeTab` ist nur noch ihre Zusammenstellung.
  Beide Oberflächen benutzen dieselben Bausteine und dieselben Widget-Keys.
  Requests entstehen ausschließlich über `probe_request_factory.dart`
  (Re-Export von `rules/derived/probe_request_rules.dart`; TaW* je Talent
  liefert `talent_probe_rules.dart` für Probensuche und Gefecht),
  gewürfelt und protokolliert wird über `showLoggedProbeDialog` — UI2 kennt
  keine W20-/W6-Simulation. Strg/Cmd+K öffnet dieselbe Suche, aber nur im
  Bereich Spielen: der `IndexedStack` hält die anderen Bereiche am Leben,
  deshalb entscheidet der aktive Bereich, nicht die Position im Baum.
- `InspectorArcaneEffectsBlock` ist Consumer-Wrapper um die darstellende
  `InspectorArcaneEffectsView`. Die Chipliste baut
  `lib/rules/derived/active_spell_display_rules.dart` — eigene Datei, weil
  `active_spell_rules.dart` von `combat_rules` und `magic_rules` importiert
  wird und sie deshalb nicht zurückholen darf.
- Der Kopf von `WorkspaceManagementBody` (nur UI2) ist der
  `KartoSeitenkopf`, bewusst kompakt (auch auf Tablets): nur der Tab als
  Titel, ohne Kontext- und Unterzeile (`WorkspaceTabSpec.helper` bleibt für die
  klassische UI); `management-active-title` hängt über `titelSchluessel` daran.
  Links von „Bearbeiten“ steht „Probe suchen“ (`management-probe-suche`, schmal
  nur Symbol), dieselbe Suche wie im Spielen-Bereich; Strg/Cmd+K gilt in
  Spielen und Verwalten (`_mitProbenkuerzel`). `CodexTabHeader` entfällt unter
  Kartograph (nur `trailing` bleibt), weil der Seitenkopf schon titelt; die
  Talente-Toolbar ist dort einzeilig. Die oberste Reiterreihe
  setzt Meer-Unterstrich und Schrift selbst, alle inneren Reiter kommen als
  ruhige Pille aus dem Feinschliff. In UI2 zeigt der Planungsverlauf keine
  AP-Zeilen (`AdvancementHistoryPanel.zeigeApZeilen: false`), die Bilanz
  steht auf breiten Fenstern rechts über der Historie, mobil als Gleichung
  über dem Katalog. `HeroesHomeScreen` bekommt dort
  `onHeldOeffnen` und `onEinstellungen`: „Held öffnen“ wählt den Helden für
  den Kartograph-Workspace statt den klassischen `HeroWorkspaceScreen`
  aufzulegen.
- **Tabs, Editoraktionen und Leave-Guard der Heldenverwaltung liegen im
  `WorkspaceManagementCoordinator`** (`lib/ui/screens/workspace/`), den
  **beide** Oberflächen benutzen: der bestehende `HeroWorkspaceScreen` und der
  `WorkspaceManagementBody` des neuen Rahmens. Eine zweite
  Bearbeitungsimplementierung darf nicht entstehen, sonst laufen Speichern,
  Verwerfen und Tabwechsel auseinander. Die Abschnittsliste kommt weiterhin aus
  `buildWorkspaceTabs`/`visibleWorkspaceTabsForHero`; UI2 pflegt keine zweite.
  Eine laufende Verlassen-Prüfung sperrt auch die direkten Editoraktionen
  einschließlich Speichern und Abbrechen. Der Koordinator meldet Beginn und
  Ende dieser Sperre an beide Hosts, auch bei Abbruch oder Speicherfehler.
- **Offene Entwicklung erhält die Verwaltung zum Ansehen.** Vor Bearbeiten
  und direkten Heldenbogenaktionen fragt `shared/planung_bearbeiten_guard.dart`
  nach: „Abbrechen“ erhält die Sitzung; „Planung verwerfen und bearbeiten“
  verwirft ausschließlich den noch nicht übernommenen Plan. Der Guard
  serialisiert Rückfragen je Held, prüft die Sitzungs-ID nach dem Dialog und
  sperrt Bearbeiten während der Übernahme. `PlanungsBearbeitungsBereich`
  reicht die Helden-ID an eingebettete Ausrüstungseditoren weiter. Das Geldfeld
  und Ausrüstungsformen bleiben durch `PlanungsFormularSchutz` während einer
  Planung nur lesbar; Inventardetails lassen sich über den Namen öffnen.
  Scrollen und Abschnittswechsel bleiben möglich. `aendereHeldImEditor`
  behält die technische Schreibsperre als Rückfall. Wechsel, die den Workspace
  abbauen (Heldenwahl,
  Heldenliste, Rückkehr zur Bestandsoberfläche, System-Zurück), fragen
  zusätzlich nach dem offenen Plan; aufgelegte Screens (Einstellungen,
  Token-Blatt) prüfen nur den Editor, weil die Sitzung im gemeinsamen
  `ProviderScope` liegt und einen Push überlebt.
  Beim tatsächlichen Oberflächenwechsel in den Einstellungen greift jedoch
  dieselbe Planabfrage: `KartoBestandsAdapter.einstellungen` reicht
  `vorOberflaechenwechsel` an `SettingsScreen.beforeSurfaceChange` weiter.
  Beide Settings-Layouts prüfen vor dem Schreiben; Abbruch und fehlgeschlagene
  Planübernahme erhalten Oberfläche und Sitzung. Laufende Wechsel sind gesperrt.
- **Solange beide Oberflächen parallel laufen, müssen ihre Themes
  ineinander überblendbar sein.** `MaterialApp` animiert den Themenwechsel,
  und `TextStyle.lerp` wirft, sobald zwei Stile verschiedene `inherit`-Werte
  tragen oder einer von beiden `null` ist. Daraus folgen zwei Regeln für
  `buildKartoTheme`: Schriftrollen entstehen per `copyWith` auf
  `ThemeData.textTheme` (ein mit dem Konstruktor gebauter `TextStyle` trägt
  `inherit: true`, Materials Stile `false`), und kein Komponenten-Theme setzt
  einen Textstil, den das Codex-Theme nicht auch setzt. Beides ist in
  `test/ui2/theme/karto_theme_uebergang_test.dart` gepinnt. Der Fehler zeigt
  sich **nur** beim Übergang, nie beim Bau eines einzelnen Themes.
- Kartograph-Token liegen in `lib/ui2/theme/` (`KartoTheme` als
  `ThemeExtension`, 25 rollenbenannte Farben einschließlich der drei
  Ressourcenfarben, `messing`/`messingNavigation` und `schatten`, zwei
  Paletten), die
  helligkeitsunabhängigen Skalen in `lib/ui2/foundation/` (`Abstand`,
  `Strich`, `KartoBreite`, `KartoTiefe`, `Bewegung`). Abstände, Linienstärken und Breakpoints gehören
  bewusst **nicht** ins Theme. Linienstärke trägt die Hierarchie: `kueste`,
  `grat` und `hoehenlinie` sind fest an die gleichnamigen Farbtoken gepaart.
  Das Token-Blatt (`lib/ui2/debug/karto_token_sheet.dart`) zeigt alles auf
  einer Seite und ist im Debugmodus aus der neuen Oberfläche erreichbar.
- **Tiefe trägt die Fläche, Gliederung die Linie** — beide dreistufig.
  `senke` < `blatt` < `feld` gilt in **beiden** Paletten (hell wird `feld`
  heller, dunkel weniger dunkel); gesetzt wird eine Stufe nie direkt, sondern
  über `KartoFlaeche` / `KartoFlaechenstufe`
  (`lib/ui2/widgets/karto_flaeche.dart`), das auch die Paarung Strichgewicht ↔
  Farbtoken erzwingt. Verteilung: Seitengrund `blatt`, Abschnitte/Karten/
  Dialoge `feld`, Kontextspalten und Eingabefelder `senke`, schwebendes
  (Tooltip, Snackbar) `senke`. Ein Eingabefeld auf `feld` wäre innerhalb eines
  Abschnitts farbgleich und damit unsichtbar. **Liegendes wirft keinen
  Schatten, Schwebendes schon**: Dialog, Blatt, Menü, Snackbar, Tooltip und
  die Hover-Anhebung antippbarer Karten nehmen `KartoTiefe`
  (`lib/ui2/foundation/karto_tiefe.dart`, zwei Stufen, Farbe `schatten`);
  Karten, Chips und Knöpfe bleiben bei `elevation: 0`. Verläufe gibt es nur
  im Navigationsgrund und im Wappenschein. Radien: `kKartoRadius` 8 für
  Flächen, `kKartoRadiusKlein` 4 für Chips und Knöpfe — mehr Stufen nicht.
- **Atmosphäre kommt aus Ornament, Papier und kurzer Bewegung**, nie aus neuer
  Bedeutung. Ornamente (`lib/ui2/widgets/karto_ornamente.dart`: Kompassrose,
  Kompassring, Höhenlinien, Zierlinie, Stern) sind deterministische
  CustomPainter ohne Semantik und Hit-Test und zeichnen in `messing` — das ist
  **nie** Textfarbe, deshalb genügt 3:1 als Grafik. `KartoPapier`
  (`lib/ui2/widgets/karto_papier.dart`) legt hell die vorhandene
  Pergamenttextur per Multiplikation auf `blatt`, dunkel bleibt der Grund
  glatt; Rasterbilder müssen `KartoPapier.textur` vorab laden. Jede Animation
  nimmt ihre Dauer über `kartoDauer` (`lib/ui2/foundation/karto_bewegung.dart`)
  und steht bei abgeschalteten Systemanimationen sofort am Ziel. Begleitflächen
  heben sich nur über `KartoAkzent` (Messingkante, astrale Tönung) ab, nie
  über freie Farben.
- Im Bestandsbaum (`buildKartoCompatTheme`) trägt `bodySmall` die aufrechte
  Datenschrift statt der kursiven Spectral-Legende
  (`buildKartoBestandsTextTheme` in `karto_typography.dart`): die
  Altansichten setzen dort fast alle kleinen Beschriftungen. Von den
  Schriftrollen weicht nur dieser Slot ab;
  `test/ui/bridges/karto_compat_theme_test.dart` hält `inherit` und die
  Überblendbarkeit fest.
- **Komponenten-Textstile gibt es nur verschachtelt.** `buildKartoFeinschliff`
  (`lib/ui2/theme/karto_feinschliff.dart`) setzt Dialogtitel (`titel`),
  `DataTable`, `ExpansionTile`, die ruhigen inneren Reiter (`senke`-Pille),
  das Blatt (Radius 8, Küste) und `KartoRahmen` als Dialogform
  (`lib/ui2/theme/karto_rahmen.dart`: Küste rundum, Messingkante oben). Er
  liegt als `Theme` in `KartoShell` und wird in `buildKartoCompatTheme`
  erneut angewendet, weil Routen nur das Wurzeltheme sehen; das überblendete
  Wurzeltheme bleibt ohne Komponenten-Textstile
  (`test/ui2/theme/karto_feinschliff_test.dart`). Die Container-Rollen des
  `ColorScheme` sind dagegen reine Farben und liegen im Wurzeltheme
  (Auswahl in Messing, sonst fiele Material auf siegelrot zurück).
- Aufgelegte Seiten aus dem Bestand (Einstellungsdetail, Katalog- und
  Hausregelverwaltung, Heldenliste, Anmeldung) nehmen das Theme ihres
  Aufrufers per `InheritedTheme.captureAll` mit; sonst fiele unter
  Kartograph die Brücke weg und `CodexTheme` auf Pergament zurück.
- **Bestandsbausteine haben eine Kartograph-Variante, die klassische
  Oberfläche bleibt Zeichen für Zeichen, wie sie war.** Erkannt wird über
  `kartoVariante(context)` (`lib/ui/widgets/karto_variante.dart`): nur
  Kartograph führt `KartoTheme` im Theme, das Codex-Theme allein
  `CodexTheme` — nie `KartoTheme.of`, das fiele auf die helle Palette zurück.
  Dort liegen auch `epischerAkzent` (klassisch Goldgelb, Kartograph Messing)
  und `kartoRadiusOder`. Umgestellt sind u. a. `CodexSectionCard`,
  `CodexTabHeader`, `CodexMetricTile`, `CodexBadge`, `CodexEmptyState`,
  `CodexPageScaffold`, `FlexibleTable` (neu `numerischeSpalten`, nur unter
  Kartograph rechtsbündig), `ResponsiveAdaptiveTable`, `EditAwareTableCell`,
  `InspectorVitalBlock`, `AnimatedDiceRow`, `AdvancementOptionCard`,
  `skill_tree_branch.dart`, Reisebericht-Farben, Heldenliste und Anmeldung.
  `test/ui/widgets/karto_variante_test.dart` prüft jeden Baustein unter
  beiden Themes. Neue Bestandsbausteine folgen demselben Muster.
- Jede Arbeitsfläche beginnt mit `KartoSeitenkopf`
  (`lib/ui2/widgets/karto_seitenkopf.dart`): Kontextzeile, Titel, eine Aktion,
  getrennt durch Weißraum statt Linie. Er ist die **einzige** Verwendung von
  `titelGross`, und die Kontextzeile steht nur dort, nie über einem Abschnitt.
  In der Spielansicht bleibt der Titel `Am Spieltisch`; Titel, Datum und
  Kurzbeschreibung des laufenden Abenteuers stehen im Abenteuerabschnitt.
  `KartoSeitenkopf.onTap` bleibt als Baustein bestehen, die Spielansicht nutzt
  es nicht mehr. Der Abenteuerabschnitt öffnet das Abenteuerblatt
  (`lib/ui2/spielen/karto_abenteuerblatt.dart`, Dialoge geteilt in
  `karto_abenteuer_dialoge.dart`): Datum, Zusammenfassung,
  Notizen und Personen lesen und pflegen, Abschluss und Belohnungen bleiben in
  der Verwaltung. Notizen und Personen sind sortierbar
  (`karto_abenteuer_sortierung.dart`: zuletzt bearbeitet, neueste, älteste,
  alphabetisch); die Wahl ist die geräteweite Einstellung
  `AppSettings.abenteuerSortierung` und schreibt nie den Helden. „Zuletzt
  bearbeitet“ liest `lastModified` an `HeroNoteEntry` und
  `HeroAdventurePersonEntry` (UTC, nur bei Belegung im JSON); Blatt und
  Verwaltungsdialoge stempeln nur echte Änderungen. Einträge ohne Stempel
  folgen, jüngste Erfassung zuerst. Sortiert wird über Indizes, damit das
  Bearbeiten weiter den Originalindex gegen den frischen Stand prüft. Das Blatt ist eine eigene Seite (Grund `blatt`); Personen
  und Notizen stehen als `feld`-Karten im `KartoKartenraster`
  (`lib/ui2/widgets/karto_kartenraster.dart`, geteilt mit der Heldenwahl),
  Personen mit demselben `KartoKompassring` wie die Heldenmarke, Anlegen als leise `senke`-Kachel am Rasterende. Es ist UI2-eigen, weil der Notizen-Tab beim Speichern seinen
  **ganzen** Entwurf (Notizen, Kontakte, alle Abenteuer) über den Helden legt.
  Das Blatt schreibt dagegen nur dieses eine Abenteuer, über
  `HeroActions.updateHero` (frisch laden, dann ändern, analog zu
  `updateHeroState`) und `ersetzeAbenteuer`
  (`karto_laufendes_abenteuer.dart`). Vor dem Öffnen läuft die Editorprüfung
  der Verwaltung, sonst überschriebe ein späteres Speichern dort die Einträge.
  Gespeichert und Fehler angezeigt wird im Blatt selbst, **nicht** über
  `KartoLaufzeitAktion`: das Öffnen läuft bereits in deren Re-Entrancy-Guard,
  jede weitere Aktion darin würde still verworfen. Bei offener Planung ist das
  Blatt schreibgeschützt, weil jede Heldenänderung den Inhalts-Hash der Runde
  bräche.
  **Ort und Datum an Notizen und Personen (SPIEL-06):** `HeroNoteEntry` und
  `HeroAdventurePersonEntry` tragen die Freitextfelder `ort` und `datum`
  (aventurisches Datum als Anzeigetext, kein Datumswert; so bleibt auch „ca.
  Mitte Boron“ möglich). Beide stehen nur bei Belegung im JSON, die Bestandshashes
  bleiben. Neue Einträge (Dialog **und** Schnell-Erfassung) bekommen sie
  vorbelegt: Ort aus `HeroState.standort` (`bereinigeStandort`), Datum aus
  `abenteuerDatum` des Abenteuers; fehlt eines, bleibt das Feld leer, nichts
  wird erfunden. Gelesen wird beim Anlegen in `_vorbelegung()` des Mixins
  `KartoAbenteuerSchreiben`. Beim Bearbeiten stehen die gespeicherten Werte im
  Dialog, ein Bestandseintrag wird nicht von selbst befüllt; unveränderte Felder
  stempeln kein `lastModified`. Die „Quest“ ist das Abenteuer selbst und kein
  eigenes Feld. Die Karten zeigen eine leise Zeile „Ort · Datum“.
  **Suche** (`karto_abenteuer_suche.dart`): Suchknopf im Abenteuerabschnitt und
  im Blatt, Suchfeld darunter. `sucheInAbenteuern` durchsucht Titel/Text/Ort/Datum
  der Notizen und Name/Beschreibung/Ort/Datum der Personen **aller** Abenteuer
  des Helden; jedes Wort muss vorkommen, Umlaute und Groß-/Kleinschreibung gelten
  nicht (`vergleichsschluessel`, wie die Sortierung; „ö“ wird „o“, nicht „oe“).
  Das Abenteuer, von dem aus gesucht wird, steht vorn (im Abschnitt das
  laufende, im Blatt das gezeigte), die übrigen mit dem zuletzt angelegten
  zuerst; Treffer folgen der gewählten Sortierung. Mit Suchtext ersetzen die
  Treffer die Karten (das Limit von drei Personen/vier Notizen entfällt).
  Treffer im eigenen Abenteuer bearbeitet man direkt, Treffer in anderen öffnen
  deren Blatt (im Abschnitt über `onAbenteuerOeffnen` und damit den
  Editorschutz, im Blatt direkt). Die Suche liest nur und schreibt nie.
  **Würfelprotokoll (SPIEL-05):** `InspectorDiceLogSection` ist der gemeinsame
  Baustein von Inspector-Probe-Tab und Spielansicht (über die Brücke
  `spielProtokoll`). Spielabende: `gruppiereNachSpielabend`
  (`dice_log_abende.dart`) teilt das Protokoll bei mehr als sechs Stunden Pause
  (`kDiceLogAbendPause`); die Abende stehen fest, **bevor** gefiltert wird, ein
  Filter verschluckt also keine Pause. Überschriften („Heute“, „Gestern“, „Fr,
  16.10.2026“, dazu die Zahl der Würfe) gibt es nur bei mehr als einem Abend;
  ein einziger Abend sieht aus wie zuvor (die klassische Optik bleibt). Reine
  Anzeige. Ziele und Restpunkte: `DiceLogEntry` hat die additiven Felder
  `zielwerte` (alle Zielwerte bei mehr als einem, in `jsonSchluessel`) und
  `restpunkte` (verbleibender Pool); beide stehen nur bei Belegung im JSON und
  werden nur für 3W20-Proben mit Ausgleichspool gesetzt
  (`diceLogEntryFromResult`). Alte Einträge behalten ihre Anzeige („Ziel: n“),
  weil sich TaP* nicht zurückrechnen lässt. Die Anzeige nennt „Ziele: 13/12/14“
  und bei gelungener Probe „TaP*: n“ (Zauber „ZfP*“); bei Misslingen keine
  Punkte. Nochmal würfeln: `onWiederholen` der Sektion blendet an Einträgen,
  für die `diceLogEntryKannWiederholtWerden` gilt (Titel mit Präfix `Eigenschaftsprobe:`,
  `Talentprobe:`, `Zauberprobe:` oder `Schnellprobe:` und passender Probeart,
  weder neutral noch Buchung), einen Knopf ein. `wiederholeProbe`
  (`probe_quick_search.dart`) sucht unter denselben Kandidaten wie die
  Schnellsuche nach gleichem Titel **und** gleicher Art und öffnet den normalen
  Probendialog mit den **aktuellen** Werten ohne die damaligen
  Situationsmodifikatoren; `wiederholeProbeMitHinweis` meldet, wenn nichts
  passt. Die Provider müssen geladen sein (die Protokollansicht hält sie
  ohnehin offen).
  Der Seitentitel `Am Spieltisch` darf die Navigationsbeschriftung nicht
  wiederholen; die Navigationsprüfungen erwarten sie genau einmal.
  In der Planung entfällt der zusätzliche Seitentitel auf allen Breiten:
  der Katalog führt bereits die Überschrift „Steigerungen planen“.
- Die dunkle Bereichsnavigation trägt oben die Markenzeile und
  `KartoHeldenmarke` (Avatar oder Monogramm im `KartoKompassring`, Name,
  Profession) und unten `Heldenauswahl` und `Workspace-Menü`; auf breiten Fenstern gibt es deshalb
  **keine** `AppBar`, auf schmalen bleibt sie. Beide Tooltips müssen wortgleich
  erhalten bleiben. Der Avatar kommt über `KartoBestandsAdapter.heldenbild`,
  nicht über ein eigenes Bildwidget auf `avatarBytesProvider`: Bilder rendert
  ausschließlich `AvatarGalleryImage`. Die Heldenwahl bekommt dieselbe
  Methode als `heldenbild` hereingereicht. „Entwicklung planen“ zeigt die Zahl
  vorgemerkter Einträge der offenen Runde als Marke; der Semantics-Name bleibt
  unverändert, die Zahl steht als Wert. Der Bereichswechsel blendet über, der
  `IndexedStack` darunter bleibt.
- Zahlen mit Bezugsgröße werden als **ein** `Text.rich` aus mehreren Spans
  gesetzt, nicht als mehrere `Text`. So trägt der aktuelle Wert das Gewicht und
  die Bezugsgröße bleibt leise, während `find.text` die Zeile weiterhin als
  Ganzes findet — der Finder fällt bei fehlendem `Text.data` auf
  `textSpan.toPlainText()` zurück. Genutzt von `KartoRessourcenwert`
  (`'27 / 22'`) und `KartoApUebersicht` (`'Frei zu Beginn: 1375 AP'`); beide
  Formate sind wörtlich gepinnt.
- Schriften des Neubaus: **Spectral** (statisch, vier eigene Schnitte) für
  Titel, **Inter Tight** (nur variabel, Gewicht über `fontVariations`) für
  Daten. Innerhalb einer Familie darf kein `asset:`-Pfad zweimal stehen —
  genau das machen Merriweather und Cinzel heute, deren Fettschnitt deshalb
  dieselben Glyphen liefert wie der reguläre. `test/ui2/theme/` prüft das
  doppelt: das Manifest auf doppelte Pfade, und `karto_weights_test.dart`
  **misst** die Zeichenbreiten, weil eine Behauptung im Manifest sonst nicht
  auffällt. Tests, die Schriften brauchen, laden sie über
  `test/ui2/theme/karto_test_fonts.dart`; ohne das misst `flutter test` die
  Ersatzschrift.
- Auf einen asynchronen Provider darf **nicht** mit
  `ref.read(provider.future)` gewartet werden. In Riverpod 3.2 wird diese
  Future bei einem Fehler nie erfüllt — der Provider geht in `AsyncLoading`
  **mit** angehängtem Fehler, und auch das `onError` der Future feuert nie;
  zusätzlich wird ein Provider ohne aktiven Listener nach einer Änderung
  seiner Abhängigkeiten gar nicht erst neu gebaut. Beides zusammen ergibt
  einen Ladezustand, der nie endet. Wer warten muss, abonniert stattdessen den
  `AsyncValue` (`ref.listenManual`) und wertet `error` und `hasValue` aus;
  Muster: `_awaitCatalogReady` in `lib/ui/screens/heroes_home_screen.dart`.
  Die Katalogkette in `lib/state/catalog_providers.dart` benutzt weiterhin
  `await ref.watch(dep.future)` — bewusst: ein `ref.watch(dep)` im
  Provider-Body macht den Provider rebuild-abhängig und bricht dadurch den
  Erfolgsfall, sobald niemand lauscht. Fehler in der Kette bleiben deshalb
  unsichtbar; auffangen muss sie die wartende Stelle per Timeout.
- Dialoge, die auf dem Root-Navigator liegen, müssen sich **selbst**
  schließen. Ein `Navigator.pop()` des Aufrufers hinter einem
  `context.mounted`-Guard genügt nicht: `SyncConflictGate` tauscht den
  `HeroesHomeScreen` unter der `MaterialApp` aus, die Dialog-Route überlebt
  das, und ein `canPop: false`-Dialog bleibt dann ohne jeden Schließweg
  stehen. Wartende Dialoge brauchen zusätzlich Timeout und Abbruch.
- Der Settings-Bereich `Rechtliches` enthaelt den inoffiziellen Fanprojekt-,
  Marken- und Rechtehinweis fuer DSA und Ulisses Spiele.
- `AppSettings.tabellenAnsicht` (`automatisch`, `tabelle`, `karten`)
  ueberstimmt die Breiten-Automatik von `ResponsiveAdaptiveTable`. Ohne diese
  Einstellung weichen breite Tabellen auf Tablet-Breiten zwingend auf Karten
  aus. Bedienbar im Talente-Tab und unter `Einstellungen > Darstellung`.
- `PersistedTableColumnLayout` bindet `FlexibleTable`, `ResponsiveAdaptiveTable`
  und `DataTable` an geraeteweite Breiten unter `AppSettings.tableColumnWidths`;
  nur stabile, textlastige Spalten-IDs erhalten Resize-Griffe im Tabellenmodus.
  Selektive Settings-Provider halten Breiten-Saves aus der Katalog-Pipeline und
  dem vollstaendigen Zaubertab heraus; die Tabellen selbst lesen ihre Breiten
  ueber `tableColumnWidthsProvider(tableId)`.
- ListTile-/SwitchListTile-Kacheln in farbig dekorierten Panels sollen ueber
  `lib/ui/widgets/list_tile_material.dart` einen lokalen Material-Layer
  erhalten, damit Flutter-3.44-Ink- und Tile-Hintergruende sichtbar bleiben.
