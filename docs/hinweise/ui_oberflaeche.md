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
  Providerbeobachtung aufmacht. Die Reihenfolge folgt der Häufigkeit am
  Tisch: Ressourcen, Häufige Proben,
  Eigenschaften, Kampf, Effekte, Zustand (und Begleiter), Dabei, Abenteuer
  samt Standort, Vor- und Nachteile, Würfelprotokoll. Das ist nur die
  Standardanordnung; jede Kachel lässt sich verschieben (Kachelraster, unten).
  Die Schnellaktionen sind **keine Kachel**: sie stehen fest im Seitenkopf
  zwischen „Am Spieltisch“ und „Anordnen“ (`KartoSeitenkopf.mitte`; ab
  `kMitteNebenTitelAb` (1200 dp, bricht dort nie um; **die Schwelle wächst mit der Schriftskalierung**, weil Titel und Aktion nicht flexibel sind und sonst die Zeile überläuft) in einer Zeile, schmaler unter der Titelzeile),
  auch im Anordnen-Modus; das Kürzel Strg+K steht nur im Tooltip von „Probe suchen“, nicht als Chip. **Vergrößern:** Jede Kachel hat in ihrer Kopfzeile den Namen als Klickfläche (Key `karto-kachel-<id>-vergroessern`, `KartoKachelSteuerung.onVergroessern`, leises `open_in_full`-Symbol); sie öffnet die Kachel in einem Dialog (`_vergroessern` in `karto_spielansicht.dart`, Key `karto-kachel-<id>-popup`, Schließen `karto-kachel-popup-zu`). Der Dialog liest `heroComputedProvider` selbst (nie den beim Öffnen erfassten Snapshot), baut denselben Inhalt mit Größenstufe nach echter Breite ohne Einklappknopf und schreibt nur über die Aktionen der Kachel. Im Anordnen-Modus gibt es den Knopf nicht. Standardbreiten (per Simulation auf wenig Leerfläche bei 2–4 Spalten gewählt): Ressourcen ganze Breite, Vor- und Nachteile sowie Protokoll schmal, Abenteuer Gewicht 450. Ein früher gespeicherter Eintrag `schnellaktionen`
  wird beim Auflösen übergangen und bleibt erhalten. Jede Schnellaktion trägt eine
  eigene Signalfarbe (`kartoSchnellaktionStil` in `karto_spielaktionen.dart`:
  Gefecht `messing`, Probe `meer`, Regeln `kueste`, Rast `moos`, Schaden
  `siegel`; Tönung 14 % auf `feld`, Symbol und Kante in der Farbe, Beschriftung
  `schrift`). Die Schnellaktionen enthalten „Regeln“ (Key
  `karto-spiel-regeln`): der vorhandene Regelnachschlag über die Brücke
  (`regelnNachschlagen`, `regelnNachschlagenVerfuegbar`); wo es keinen
  Regelindex gibt (Mobile), entfällt der Knopf. Die Eigenschaften stehen als
  schmale Würfelleiste (`KartoAbschnitt.dicht`,
  `InspectorAttributeProbes(kompakt: true)`: einzeilige Karten in 8, 4 oder 2
  Spalten; die klassische Optik bleibt beim Standard). Der Abschnitt
  „Abenteuer“ (`karto_abenteuer_abschnitt.dart`) trägt Titel, aventurisches
  Datum, Standort (`KartoStandortZeile`, hängt am Zustand, nicht am
  Abenteuer; die Eingabe schlägt Orte aus `orte.json` vor, `KartoOrtFeld` mit
  `sucheOrte`, Freitext bleibt erlaubt, der Kartenlink entfällt für Namen, die
  nur als Region, Staat, Fluss oder Straße bekannt sind, `kartenlinkSinnvoll`), Kurzbeschreibung (3 Zeilen, „Mehr“), eine Schnell-Erfassung
  für Notizen und die Karten für Personen und Notizen. Alles lässt sich dort
  direkt ändern; „Öffnen“ (Key `karto-spiel-abenteuer-oeffnen`) bleibt der Weg
  zum Vollblatt. Gezeigt werden zunächst drei Personen und vier Notizen nach
  der gewählten Sortierung, „Alle zeigen“ klappt inline auf. Ohne laufendes
  Abenteuer bleibt der Abschnitt mit dem Standort stehen. Der Seitenkopf heißt
  immer schlicht „Am Spieltisch“. Der Schreibweg liegt gemeinsam mit dem
  Abenteuerblatt im Mixin `KartoAbenteuerSchreiben`
  (`karto_abenteuer_schreiben.dart`). Alle ui2-Schreibwege auf den Bogen
  (Abenteuer, Reiseroute, Dabei, Merkmalsblatt, Anordnen/Einklappen) laufen
  über `KartoHeldSchreiben` (`karto_held_schreiben.dart`): frisch über
  `updateHero`, Planungssperre mit `planungsSperre`, wahlweise Doppelklick-Schutz
  (`einzeln`), Fehlertext in `fehler`. Die Editorprüfung
  (`vorHeldenbearbeitung`) gehört nicht in diesen Weg: Sie ist keine
  Datensicherung (Editorentwürfe gleichen je Schlüssel frisch ab), sondern bleibt
  Stellen vorbehalten, die einen eigenen Bearbeitungsmodus beginnen. Die
  Standortspeicherung läuft weiter über
  die Brücke (`standortSetzen`). Die Ressourcenwerte sind kompakt: Wert und
  Fehlbetrag teilen eine Zeile, die ganze Zelle ist das Tippziel; der Wert hat
  Vorrang, passt der Fehlbetrag nicht daneben, rückt er unter den Wert (das
  Maximum wird nie gekürzt). **In einer weiten Kachel** (`KartoKachelGroesse.weit`,
  also auch im Vergrößern-Dialog) trägt jede Zelle eine Knopfreihe −5, −1, +1, +5
  unter dem Balken (`KartoRessourcenwert.onSchritt`, Keys
  `karto-ressource-<art>-minus-5|minus-1|plus-1|plus-5`; eine zusammenhängende
  Leiste auf `senke` mit Haarlinien zwischen den Segmenten, 48 dp hoch, statt
  vier umrandeter Kästen). Die Zellen sind dann
  mindestens 240 dp breit, und die Spaltenzahl ist ausgewogen
  (`KartoRessourcenleiste.ausgewogeneSpalten`: 4 Ressourcen bei Platz für 3 ergeben
  2×2). Kompakt und normal bleibt alles wie vorher. Geschrieben wird über
  `KartoBestandsAdapter.ressourceSchritt` und `schreibeRessourcenSchritt`
  (`karto_spiel_bruecke.dart`, gemeinsam mit dem Ressourcenblatt):
  `aendereZustandMitMeldung` auf dem frisch geladenen Wert, Untergrenze
  `kVitalFloor` (−10), keine Obergrenze (Überheilung). Ohne `aktion`-Guard, damit
  jeder schnelle Klick zählt; UI2 kennt keine Grenze. Den
  Re-Entrancy-Guard reicht `KartoWorkspace` als `KartoLaufzeitAktion` herein;
  die Spielansicht macht keinen zweiten Fehlerweg auf.
- **Kachelraster der Spielansicht (SPIEL-07).** Statt Haupt- und Seitenspalte
  stehen die Abschnitte als Kacheln im `KartoKachelraster`
  (`karto_kachelraster.dart`): Rastereinheit mindestens 300 dp
  (`kRasterEinheitMin`), Spaltenzahl aus der **Ansichtsbreite**, höchstens 4;
  Breiten `schmal` (1 Einheit), `mittel` (2), `voll` (ganze Zeile), auf die
  Spaltenzahl gekappt. Höhe = Inhalt. Die **Spalte** jeder Kachel folgt nur aus
  Reihenfolge, Breite und dem Richtgewicht der Art
  (`KartoSpielkachelArt.gewicht`, `kartoRasterBelegung`), nie aus der echten
  Höhe: Einklappen oder neue Daten verschieben nur Kacheln darunter in
  derselben Spalte, keine wechselt Spalte oder Breite (ein früheres
  „Ausweichen“ in Lücken entfiel). Die senkrechte Lage folgt der echten
  Unterkante. **Lückenschluss:** Beginnt die nächste Kachel einer Spalte tiefer
  (eine mehrspaltige Kachel wartet auf ihre tiefste Spalte), wird die Kachel
  darüber in einem zweiten Durchgang bis an sie heran gedehnt, mit
  **Mindesthöhe** statt fester Höhe (mit fester Höhe wäre sie eine
  Layoutgrenze, wachsender Inhalt erreichte das Raster nicht). Lagen ändern
  sich dadurch nie; die letzte Kachel einer Spalte behält ihre Höhe.
  `KartoRasterKachel.dehnbar: false` nimmt eine Kachel aus (eingeklappte
  Kacheln, auch als Anordnungskarte). Eine Kachel muss die Mindesthöhe füllen: der
  äußere `KartoAbschnitt` tut das (`StackFit.passthrough` an der Akzentkante);
  wer ihn in `Align` oder ähnliches wickelt, lässt wieder ein Loch. Die
  Richtgewichte sind an gemessene Höhen der Standardbreite angelehnt
  (14.11.2026) und sollten ihnen folgen, wenn eine Kachel deutlich wächst.
  **Eine Flächenstufe:** alle Kacheln liegen auf `feld`; die frühere `senke`
  für Kampf, Effekte, Zustand und Begleiter wechselte im freien Raster
  scheinbar zufällig. Unterschieden wird über Symbol (jede Kachel trägt eines,
  `spielkachelSymbol`) und `KartoAkzent`. **Kopf-Bedienung bei Bedarf:**
  Vergrößern-Symbol und Einklapp-Pfeil des äußeren Abschnitts sind mit
  angeschlossener Maus nur sichtbar, solange Zeiger oder Fokus in der Kachel
  liegen (`_Kachelzeiger`/`_BeiBedarf` in `karto_abschnitt.dart`,
  `AnimatedOpacity`; bleiben im Baum, klickbar und in der Semantik). Ohne Maus
  und eingeklappt (Pfeil) bleiben sie stehen. Kinder werden ohne Intrinsics
  ausgelegt, `LayoutBuilder` in Kacheln ist erlaubt. Was eine Kachel erlaubt (Breiten, Standardbreite, Ausblenden,
  Einklappen), legt `KartoSpielkachelArt` in `karto_spielraster_ordnung.dart`
  fest; Ressourcen lassen sich weder ausblenden noch einklappen. Gespeichert wird **je Held** in `HeroSheet.spielansicht`
  (`HeroSpielansicht`/`HeroSpielkachel`, nur bei Belegung im JSON; Kacheln mit
  `id`, damit der Sync je Kachel zusammenführt). `loeseSpielansichtAuf` setzt
  fehlende Kacheln an ihre Standardstelle und übergeht unbekannte IDs,
  `schreibeSpielansicht` lässt diese samt unbekannter Felder an ihrer Stelle
  stehen und schreibt die Standardbreite nicht. „Anordnen“ im Seitenkopf
  öffnet nach `vorHeldenbearbeitung` einen Entwurf. Darin steht je Kachel eine
  `KartoAnordnungskarte` (Symbol, Titel, Breite; gleiche Spalte wie später) mit
  gesperrter **Live-Vorschau** des echten Inhalts (Key `karto-kachel-<id>-vorschau`,
  Etikett mit Stufe und Breite `…-vorschau-stufe`): der Inhalt wird in der
  Größenstufe der echten Kachelbreite gebaut (`vorschau`-Rückruf aus `_kachel`),
  ist mit `IgnorePointer`/`ExcludeFocus`/`ExcludeSemantics` nicht bedienbar
  und steht in **echter Höhe** (keine Kappung mehr, seit 14.11.2026): so zeigt
  der Anordnen-Modus, wie groß jede Kachel ist, und das Raster packt und dehnt
  die Karten wie später die Kacheln. Eine eingeklappte Kachel zeigt keine
  Vorschau, nur „… · Eingeklappt“ (Key `…-breite-name`). Die Vorschau folgt
  sofort einer geänderten Breite. Ziehen am Griff oder am Titel (nach
  kurzem Halten), eine Einfügelinie zeigt „davor“ oder „danach“, abgelegt wird
  einfügend (`fuegeSpielkachelEin`), dazu Pfeile, Breitenmenü, Ausblenden,
  „Standard“; erst „Fertig“ schreibt einmal frisch
  über `updateHero`, ohne Änderung gar nicht. Den Einklappknopf zeigt der
  äußerste `KartoAbschnitt` einer Kachel über `KartoKachelSteuerung`; er
  schreibt sofort nur den einen Eintrag (`mitEingeklappt`). Während einer
  Planung sind Anordnen und Einklappen gesperrt. Jede Kachel kennt ihre **Größenstufe** `KartoKachelGroesse`
  (`kompakt` <420, `normal` <600, `weit` ab 600 dp **Kachelbreite**, nicht
  Fensterbreite), über `KartoKachelSteuerung.groesseVon(context)` auch in
  verschachtelten Abschnitten lesbar; Inhalte zeigen mit der Stufe mehr oder
  ordnen sich um, statt nur zu strecken (mittlere und volle Kacheln sind immer
  `weit`, eine schmale erst in sehr großen Fenstern). **Kampf:** In `weit` steht
  neben den Probenchips das Panel „Kampfwerte“ (`karto_kampfinhalt.dart`,
  `KartoKampfInhalt`/`KartoKampfwerte`): belegte Hände (`gefechtsHandbelegung`),
  INI (`kampfInitiative` + Würfel), TP (`gefechtsAngriffsanzeige`), RS, BE
  (Keys `karto-kampf-ini|tp|rs|be`), bei Fernkampf Ladezeit, Geschoss,
  Entfernung, bei Belegung Wundabzug von Schwert-/Schildarm und
  Waffenmeisterschaft. Reine Anzeige aus der Kampfvorschau, ohne Rechnung; die
  wichtigsten Zeilen stehen oben.
  Die Kachel bleibt standardmäßig schmal; das Panel erscheint nach dem
  Verbreitern oder im Vergrößern-Dialog. **Eigenschaften:** Die Kachel erlaubt
  seit 14.11.2026 auch „Schmal“ (Standard bleibt „Mittel“); schmal stehen die
  acht Karten als 4 × 2. Die Kachel passt ihre Spalten (8, 4, 2, 1) schon an die Breite an;
  in `weit` zeigt eine Karte einen Wundabzug zusätzlich als „−4“ an der Karte
  selbst (`InspectorAttributeCard.abzugZeigen`, vom Adapter über die Stufe
  geschaltet), sonst nur im Tooltip. Mehr gibt die Datenlage nicht her, die
  Stufen `kompakt`/`normal` bleiben unverändert. **Begleiter:** In `weit` stehen mehrere Begleiter nebeneinander
  (Karten ab `KartoBegleiterAbschnitt.kartenbreiteMin` = 320 dp, Spalten über
  `kartoAusgewogeneSpalten`), und jede Karte trägt einen Block „Kampf“ aus
  `begleiterKampfprofil` (INI, RS, BE, MR, Geschwindigkeiten, je Angriff AT, PA,
  TP, DK, beim Reittier der Ausbildungsstand; Keys
  `karto-begleiter-<id>-kampf|kampfwerte|angriff-<i>|reittier`). Ab 540 dp
  Kartenbreite steht der Block rechts neben den Werten, sonst darunter. Die
  Bedienung der Werte ist unverändert. **Abenteuer:** Karten und Kartenraster waren schon breitenabhängig. In `weit`
  stehen Personen und Notizen **nebeneinander** (Key
  `karto-spiel-abenteuer-spalten`, Personen 2 : Notizen 3), solange beide
  vorhanden sind und nicht gesucht wird; sonst wie bisher untereinander. Die
  Obergrenzen (3 Personen, 4 Notizen) ergeben ähnlich hohe Spalten.
  Zu beachten: eine mittlere Kachel ist immer weit, die Kachel erlaubt nur
  „Mittel“ und „Voll“; nicht weit ist sie nur bei einspaltiger Ansicht. **Reiseroute:** In `weit` zeigt die Kachel `kReiserouteWeit` (5) statt
  `kReiserouteKurz` (3) Stationen, `kReiserouteNotizWeit` (4) statt 2 Notizzeilen
  und je Station den Avesmaps-Link, den sonst nur das Blatt hat; der Zähler am
  Knopf „Ganze Route“ folgt der Obergrenze der Stufe. **Zustand:** In `weit` mit mindestens
  `KartoZustandsblock.zweiSpaltenAb` (624 dp) stehen zwei Spalten nebeneinander
  (`karto_spiel_bruecke.dart`): links Belastung über Wunden, beide von Anfang an
  aufgeklappt (`anfangsAufgeklappt`, danach frei einklappbar, nicht gespeichert),
  rechts die Statuswerte ohne Trennlinie (`mitTrenner: false`). Schmaler, in
  `kompakt`/`normal` und außerhalb einer Kachel bleibt es bei der einen Spalte
  mit eingeklappten Abschnitten; die Statuswerte stehen dann als flaches
  **Wertraster** (`InspectorStatuswerteBlock.raster`, 4 Spalten, bei wenig
  Platz 2; Karten mit Kürzel, Ergebnis und Modifikator-Marke, Keys
  `workspace-status-kachel-<Label>`). Ein Tipp öffnet ein kleines Blatt
  (`workspace-status-blatt-<Label>`) mit derselben `InspectorValueRow`; es liest
  den Snapshot selbst neu, bleibt für mehrere Schritte offen und meldet Fehler
  im eigenen `ZustandFehlerBereich`. MR öffnet nichts; während einer Planung
  ist nur BE antippbar. Zeilen, Raster und Blatt teilen eine Beschreibung
  (`_statuswerte`), die Schreibwege sind dieselben. **Die Spielansicht** baut
  den Block mit `spielZustand(mitBelastung: false)`: Zustand = Wunden +
  Statuswerte, Erschöpfung und Überanstrengung stehen in „Dabei“; das Gefecht
  behält die Belastung (Standard `true`). Die klassischen Abschnitte bekamen nur
  optionale Parameter mit unverändertem Standard; Schreibwege unverändert. „Dabei“ hält Betrag,
  Stift und Münzschritte beieinander und lässt die Verbrauchsgegenstände ab
  `kDabeiZweispaltigAb` (560 dp Kachelbreite) zweispaltig fließen.
  Die Kachel „Reiseroute“ (`karto_reiseroute.dart`) zeigt die jüngsten
  Stationen von `HeroSheet.reiseStationen` als Zeitleiste und öffnet das
  Reiseroute-Blatt; Details in [reiseroute_plan.md](../reiseroute_plan.md).
  Das Blatt zeigt zuerst die Tabelle (`KartoReiseTabelle`, Keys
  `karto-reise-tabelle`, `karto-reise-zeile-<id>`), umschaltbar auf die
  Zeitleiste (`karto-reise-ansicht`). Ortsfelder lesen
  `ortsverzeichnisProvider` (Wiki Aventurica plus Avesmaps); wer ein neues
  Ortsfeld baut, ruft beim Öffnen `AvesmapsOrteAnforderung.fordereAn()`, nie
  beim Bauen der Spielansicht. Erneutes Öffnen prüft die Liste wieder unter
  Beachtung von Tagescache und Fehlerpause. Standortdialoge beobachten ohne
  feste `orte`-Liste das laufende Verzeichnis und die Online-Suche;
  `KartoStandortZeile.liveOrte` aktiviert dies für die Abenteuer-Kachel.
  Enter übernimmt den sichtbaren hervorgehobenen Vorschlag auch online.
  In Tests bleibt Avesmaps ohne Override aus;
  Orte mit Position kommen dort über `avesmapsOrteProvider.overrideWith`.
  **Standort (13.11.2026):** Die Kachel „Standort“
  (`KartoSpielkachelArt.standort` hinter der Reiseroute,
  `ui2/spielen/standort/karto_standort_kachel.dart`) folgt der Infotafel von
  Avesmaps: Name, Ortsklasse und Gebiet, eigene Lageskizze
  (`KartoLageskizze`, `CustomPainter`, kein Kartenbild), Fakten mit 96 dp
  Bezeichnungsspalte, „In der Nähe“ (`kNaheOrteKurz`/`kNaheOrteWeit`) und
  Rücklinks. Rechnung in `standort_lage_rules.dart`. Avesmaps-Daten erst nach
  „Kartendaten laden“ (`fordereAn()`); eine früher geladene Tagesliste liest
  `avesmapsOrteProvider` auch ohne Anforderung aus dem Speicher (ohne Netz).
  Ortsdetails (`avesmapsOrtsdetailsProvider`) nur nach der Anforderung. Der
  Eingabedialog ist `zeigeStandortDialog`; gespeichert wird über
  `standortSetzen`. Tests überschreiben `avesmapsOrteSpeicherProvider` statt
  den Heldenspeicher zu öffnen.
  **Karte (13.11.2026):** `lib/ui2/karte/` zeichnet die Aventurien-Karte im
  Stil von Avesmaps selbst (`KartoKarte`, `CustomPainter`, keine
  Kartenbibliothek); die Lageskizze der Standort-Kachel ist ein nicht
  interaktiver Ausschnitt, `zeigeKarte` das Vollbild. Stilwerte nur aus
  `karto_karten_stil.dart` (Kanon von Avesmaps, Marken kippen nicht mit dem
  Theme), Geometrie aus `karten_rules.dart`. Kein Kartenbild von avesmaps.de;
  Kacheln nur von der eigenen Site (`KARTEN_KACHELN`, ohne Angabe Papier mit
  Landschimmer, Tests laden so nie ein Bild). Der Kachelspeicher lädt nur in
  `benoetige`, nie beim Zeichnen. Ein Tipp auf die interaktive Karte kommt
  wegen des Doppeltipps verzögert (in Tests 400 ms pumpen).
  Ortsfakten (Einwohner, Tempel, wichtige Orte) kommen aus
  `ortsfaktenProvider`; Tests überschreiben ihn statt das Asset zu laden.
  Die Standort-Kachel gliedert mit `_Rubrik` (Bezeichnung plus Haarlinie),
  Wege und Gottheiten sind `_Marke`n; Reihenfolge und Gruppierung rechnen
  `reiheNachVielfalt` und `tempelNachGottheit`, nie das Widget.
  **Wildnis (12.11.2026):** Die Kachel „Wildnis“ (`KartoSpielkachelArt.wildnis`,
  `ui2/spielen/wildnis/karto_wildnis_kachel.dart`) ist **eine** Kachel für alle
  Wildnistätigkeiten; oben wählt man die Tätigkeit (der Umschalter erscheint ab
  zwei Tätigkeiten). Gemeinsam sind Standort, Landschaft (Vorschlag aus
  `findeOrt` + `landschaftenFuerOrt`), Jahreszeit (aus
  `resolveCurrentAdventureDate`), Geländekunde und Ortskenntnis (aus
  `werteWildnisSonderfertigkeitenAus`, von Hand überschreibbar), Dauer, AsP,
  Erschwernis, TaW aus den Bestandteil-Talenten, die Probe über
  `KartoGefechtsAdapter.gefechtsProbe` (schreibt selbst ins Würfelprotokoll,
  kein Import aus `lib/ui`; ohne Gefechtsbrücke bleibt der Knopf gesperrt) und
  die Ergebnisanzeige. Die Kachel schreibt nichts am Helden; Eingaben und
  Ergebnis leben nur im Widget, jede Eingabe verwirft das Ergebnis. AsP werden
  nicht abgebucht. Das Vergrößern-Popup liefert das Raster; in `weit` zeigt die
  Vorschau mehr Zeilen (`kWildnisVorschauWeit` statt `kWildnisVorschauKurz`),
  „Alle N anzeigen“ blendet in jeder Größe die ganze Liste ein. Zeilen mit
  `WildnisErgebnisZeile.erlaeuterung`/`quelle` klappen per Antippen auf
  (Kräuter: Wirkung, Kurzbeschreibung bzw. Sperrhinweis ohne Katalogpasswort,
  Bestimmung, Erntezeit, Grundmenge, Zoo-Botanica-Seite).
  `erschwernisHinweis` erklärt einen Erschwernisanteil aus der Wahl (gezielte
  Kräutersuche: Suchschwierigkeit des Krauts), `zielAngaben` zeigt die Angaben
  zum gewählten Ziel unter der Zusammenfassung.
  **Neue Tätigkeit** (Nahrung sammeln, Pirschjagd …): Unterklasse von
  `KartoWildnisTaetigkeit` (`karto_wildnis_taetigkeit.dart`: Talentbestandteile,
  Eigenschaften, Landschaften und Landschaftsvorschlag je Ort, Dauern, eigene
  Wahlen `KartoWildnisOption`, `erschwernis`, `baueProbe`, `auswerten`,
  `vorschau`) plus Regelfunktion in `lib/rules/derived/`, dann ein Eintrag in
  `kartoWildnisTaetigkeiten`; Kachel und Raster bleiben unverändert. Als
  erste ist `KartoKraeutersucheTaetigkeit` (KL/IN/FF laut WdE S. 113, nicht das
  MU/IN/FF des Standard-Metatalents) umgesetzt. Standardplatz: vor dem
  Würfelprotokoll, damit bestehende Anordnungen nicht verschoben werden.
  **Vor- und Nachteile:** In `weit` zeigt die eingeklappte Übersicht
  (`KartoMerkmalsuebersicht`) je Art bis zu `kMerkmaleZeilenWeit` (3) statt einer
  Zeile, also mehr Einträge ohne Aufklappen; aufgeklappt stehen Vorteile und
  Nachteile nebeneinander (Key `karto-merkmale-spalten`), solange beide Arten
  Einträge haben. Mehr gibt die Datenlage nicht her (Wirkungstexte stehen schon
  aufgeklappt). Kompakt, normal und außerhalb einer Kachel unverändert; der
  Aufklappzustand bleibt die geräteweite Einstellung.
  **Würfelprotokoll:** Die Kachel ist die Klasse `KartoProtokollAbschnitt`
  (`karto_wuerfelprotokoll.dart`), damit sie die Stufe lesen kann. In `weit`
  zeigt sie `kProtokollWeit` (8) statt `kProtokollKurz` (5) Würfe, „Alle
  anzeigen“ erscheint erst darüber, und der Adapter (`spielProtokoll`) setzt die
  Würfe als **Tabelle** (`InspectorDiceLogSection.tabellarisch`: Kopfzeile Zeit,
  Probe, Würfe, Ziel, Ergebnis; Restpunkte TaP*/ZfP* unter dem Ergebnis, dort
  auch „Nochmal würfeln“ und die Rücknahme-Aktion; Keys
  `dice-log-tabellenkopf`, `dice-log-zeile-<ms>`). Die Tabelle gilt nur mit
  Grenze (das Blatt mit allen Würfen und Filtern bleibt bei Karten) und fällt
  unter `tabellenBreiteMin` (520 dp) oder bei Schrift über das 1,3-Fache auf die
  Karten zurück, weil feste Spalten dann nicht mehr tragen. Daten sind
  unverändert (`DiceLogEntry`), Schreibwege auch.
  **Häufige Proben:** In `weit` stehen die Proben nebeneinander
  (`ProbenFavoritenListe.spaltenbreite`, vom Adapter mit
  `KartoBestandsAdapterImpl.kFavoritenSpaltenbreite` = 260 dp gesetzt; höchstens
  3 Spalten, ausgewogen wie `kartoAusgewogeneSpalten`: 4 Proben bei Platz für 3
  ergeben 2×2; Key `proben-favoriten-spalten-<n>`), in der Reihenfolge der
  Favoriten von links nach rechts. Tipp, Menü und Schreibweg bleiben
  unverändert; mehr Information gibt es nicht (Name und Detail aus den
  Kandidaten der Suche). **Dabei:** In `weit` zeigt der Block
  `kDabeiSichtbarWeit` (12) statt `kDabeiSichtbar` (6) Verbrauchsgegenstände,
  weil sie ohnehin in zwei Spalten fließen. **Aktive Effekte:** unverändert. Es
  gibt höchstens drei Chips (Axxeleratus, Armatrutz, Attributo), die schon als
  `Wrap` nebeneinander stehen; die Datenlage (`ActiveSpellEffectChip`: Name,
  Bonus, Restlaufzeit) trägt keine weitere Darstellung, ein Füllinhalt wäre
  unehrlich.
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
  deshalb entscheidet der aktive Bereich, nicht die Position im Baum. Das
  Kürzel hängt an `KartoProbenkuerzel` (`lib/ui2/widgets/karto_probenkuerzel.dart`),
  einem `HardwareKeyboard`-Handler statt `CallbackShortcuts`: im Browser fiel der
  Fokus nach einem Klick auf freie Fläche aus dem Bereich, Flutter behandelte
  die Taste nicht, und der Browser öffnete seine eigene Suche. Der Handler
  greift nur, solange sein Bereich aktiv ist und seine Route oben liegt (nicht
  unter Dialogen oder dem Gefecht, das dasselbe Widget nutzt); Strg+Umschalt+K
  bleibt dem Browser.
- Häufige Proben (Favoriten, nur UI2): `HeroSheet.probenFavoriten` speichert je
  Eintrag nur `art:ref` (`HeroProbenFavorit.id`, deterministisch, damit der
  Sync-Merge die Liste je Element zusammenführt); nie Name oder Wert, Ziel und
  Herleitung entstehen beim Würfeln. Die Kandidaten kommen aus
  `beobachteProbeKandidaten` (`probe_quick_search.dart`), die Suche zeigt den
  Stern nur mit `mitFavoriten: true` (klassische Oberfläche ohne). Schreiben nur
  frisch über `aendereHeldMitMeldung` und die Listenregeln in
  `proben_favoriten_rules.dart` (Höchstzahl `kProbenFavoritenMax`). Die Liste
  im Spielbereich ist `ProbenFavoritenListe` hinter
  `KartoBestandsAdapter.spielFavoritenproben`.
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
  zusätzlich nach dem offenen Plan, sofern er Einträge hat (ein leerer
  Plan endet in beiden Oberflächen ohne Rückfrage); aufgelegte Screens (Einstellungen,
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
  der Verwaltung. Der Datumsdialog (`KartoDatumDialog`) zeigt unter den Feldern
  die **Feiertage in der Nähe** des gewählten Tages (7 Tage davor, 14 danach;
  Rechnung in `feiertageInDerNaehe`, nicht im Widget), folgt Tag und Monat
  sofort und verlinkt die Feiertagsliste der Wiki Aventurica über den
  injizierbaren `KartoLinkOeffner` (`oeffneExtern` aus `karto_standort.dart`). Notizen und Personen sind sortierbar
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
  `HeroAdventurePersonEntry` tragen `ort` (Freitext) und `datum` als
  `HeroAdventureDateValue` wie Reisestationen und Abenteuer (Tag, Monat, Jahr;
  Teilangaben erlaubt; eingegeben über `KartoDatumFelder`). Ein Datum, das eine
  Zwischenfassung als Text speicherte, zerlegt `HeroAdventureDateValue.lese`;
  Unlesbares bleibt vollständig im Jahr. Beide stehen nur bei Belegung im JSON
  (`istBelegt`), die Bestandshashes bleiben. Neue Einträge (Dialog **und**
  Schnell-Erfassung) bekommen sie vorbelegt: Ort aus `HeroState.standort`
  (`bereinigeStandort`), Datum aus `abenteuerDatumWert` des Abenteuers; fehlt eines, bleibt das Feld leer, nichts
  wird erfunden. Gelesen wird beim Anlegen in `_vorbelegung()` des Mixins
  `KartoAbenteuerSchreiben`. Beim Bearbeiten stehen die gespeicherten Werte im
  Dialog, ein Bestandseintrag wird nicht von selbst befüllt; unveränderte Felder
  stempeln kein `lastModified`. Die „Quest“ ist das Abenteuer selbst und kein
  eigenes Feld. Die Karten zeigen eine leise Zeile „Ort · Datum“.
  **Suche** (`karto_abenteuer_suche.dart`): Suchknopf im Abenteuerabschnitt und
  im Blatt, Suchfeld darunter. `sucheInAbenteuern` durchsucht Titel/Text/Ort/Datum
  der Notizen und Name/Beschreibung/Ort/Datum der Personen **aller** Abenteuer
  des Helden; jedes Wort muss vorkommen, Umlaute und Groß-/Kleinschreibung gelten
  nicht (`vergleichsschluessel` = `suchFaltung` aus `string_normalize.dart`, dieselbe Faltung wie Probensuche und Kurzregeln: „ö“, „oe“ und „o“ fallen zusammen).
  Das Abenteuer, von dem aus gesucht wird, steht vorn (im Abschnitt das
  laufende, im Blatt das gezeigte), die übrigen mit dem zuletzt angelegten
  zuerst; Treffer folgen der gewählten Sortierung. Mit Suchtext ersetzen die
  Treffer die Karten (das Limit von drei Personen/vier Notizen entfällt).
  Treffer im eigenen Abenteuer bearbeitet man direkt, Treffer in anderen öffnen
  deren Blatt (im Abschnitt über `onAbenteuerOeffnen` und damit den
  Editorschutz, im Blatt direkt). Die Suche liest nur und schreibt nie.
  **Zuletzt gewürfelt (SPIEL-01, Teilstand):** Unter den Schnellaktionen im Seitenkopf
  steht ein Streifen mit bis zu `kZuletztGewuerfeltMax` (6) Marken
  (`KartoZuletztGewuerfelt`, `karto_zuletzt_gewuerfelt.dart`). Welche Proben
  erscheinen, entscheidet `zuletztGewuerfelteProben`
  (`lib/rules/derived/zuletzt_gewuerfelt_rules.dart`): neueste zuerst, jede
  Probe (Verweis, sonst Art und Titel) einmal, nur wiederholbare Einträge
  (`probeEintragIstWiederholbar`, dieselbe Regel wie der Wiederholen-Knopf im
  Protokoll). Ein Tipp öffnet über die Brücke (`probeWiederholen`) den normalen
  Probendialog mit den aktuellen Werten. Der Streifen speichert und
  synchronisiert nichts, er liest nur das Würfelprotokoll (höchstens
  `HeroState.diceLogMax` Einträge); ohne wiederholbaren Wurf entfällt er.
  **Vor- und Nachteile klappen auf (SPIEL-01):** `KartoMerkmalsuebersicht`
  zeigt eingeklappt je Art eine Zeile mit Auslassung (höchstens zwei Zeilen),
  aufgeklappt jeden Eintrag einzeln mit Wirkungstexten. Der Umschalter (Key
  `karto-spiel-merkmale-umschalten`, „Alle zeigen (n)“ / „Einklappen“) schreibt
  nur `AppSettings.merkmaleAufgeklappt` (`merkmaleAufgeklapptProvider`,
  `SettingsActions.setMerkmaleAufgeklappt`): geräteweit und ohne Sync (der
  Remote-Abgleich der Einstellungen betrifft nur Geheimnisse), nie der Held,
  daher ohne `aktion`-Guard und ohne Editorprüfung. Standard ist eingeklappt.
  **Dabei (SPIEL-02, Teilstand):** `KartoDabeiAbschnitt`
  (`karto_dabei_abschnitt.dart`) steht in der Hauptspalte vor dem Abenteuer
  und zeigt den Geldstand (`HeroSheet.dukaten`) mit Münzschritten D/S/K sowie
  einem Dialog „Betrag ändern“ (Hinzufügen/Abziehen) und die
  Verbrauchsgegenstände des Inventars mit −/+ (ab `kDabeiSichtbar` = 6 mit
  „Alle zeigen“). Die Regeln liegen in `spiel_dabei_rules.dart`:
  `dabeiVerbrauchsgegenstaende` nimmt nur manuelle Verbrauchsgegenstände des
  Helden (keine mit dem Kampf verknüpften, keine abgelegten, keine von
  Begleitern getragenen); Munition bleibt im Kampfbereich. **Beim Begleiter
  (10.11.2026):** Was ein Begleiter trägt, steht darunter je Begleiter als
  „Beim Begleiter: <Name>“ (`dabeiBegleiterVerbrauch`, Reihenfolge der
  Begleiter am Helden; Einträge eines nicht mehr vorhandenen Begleiters in
  einer Gruppe „Begleiter“; gleiche Auswahl wie beim Helden mit Träger
  `begleiter`, `istDabeiBegleiterVerbrauchsgegenstand`). Die Zeilen zählen mit
  −/+ über denselben Schritt `mitVerbrauchsmengenSchritt` (Träger und Träger-ID
  bleiben), haben aber kein „Benutzen“, weil der Held sie nicht bei sich hat;
  Keys `karto-dabei-begleiter-<gruppe>-<zeile>`. Die Last des Begleiters zählt
  nicht zur Belastung des Helden. Jeder Klick schreibt
  frisch über `HeroActions.updateHero`: `mitGeldSchritt` und
  `mitVerbrauchsmengenSchritt` rechnen vom **gespeicherten** Wert, finden den
  Eintrag über die Instanz-ID und ändern nur ihr Feld (Menge über
  `mitInventarMenge`, 0 bis 9999, ein aufgebrauchter Eintrag bleibt stehen).
  Anders als der Münzknopf im Inventar kappt `mitGeldSchritt` nie still bei 0:
  ein Abzug über den Bestand ist ein `StateError`, die Abzugsknöpfe sind dann
  gesperrt. Freitext- oder von einer älteren App abweichende Mengen und ein
  unlesbarer Geldstand bleiben unangetastet (Hinweis statt Schritt). **Benutzen:**
  Verbrauchsgegenstände mit Vitalwirkung oder Elixierwirkung
  (`dabeiBenutzbar`, dieselbe Entscheidung wie im Gefechtsinventar) zeigen
  „Benutzen“ (nur, wenn die Bestandsbrücke ein `KartoGefechtsAdapter` ist, und
  nicht bei Menge 0). Es öffnet über `gefechtsVitalwirkung` den bestehenden
  Anwenden-/Einnehmen-Dialog, der Wirkung (Zustand) und das Stück (Bogen)
  selbst bucht; der Block schreibt dabei nichts. Der Aufruf läuft über `aktion`.
  **Munition (07.11.2026):** Zwischen Geld und Verbrauchsgegenständen steht,
  sobald eine benannte Fernkampfwaffe benannte Geschosse führt, der Abschnitt
  „Munition“ (`dabeiMunition`, je Geschoss Name, Waffe, „aktiv“ für das
  gewählte Geschoss, Bestand mit −/+; Keys `karto-dabei-munition-<i>`). Der
  Bestand gehört dem Kampf-Slot (`RangedProjectile.count`): `mitMunitionsSchritt`
  ändert über `mitKampfAenderung`/`mitGeschossSchritt` nur diesen Bestand,
  gerechnet vom gespeicherten Wert (0 bis `kGeschossHoechstbestand`), Waffe und
  Geschoss über ihre IDs, ohne ID über Name und Position. Den verknüpften
  Inventareintrag gleicht `updateHero` beim Speichern selbst ab; der Block
  schreibt nie ins Inventar. Solange ein Gefecht des Helden läuft
  (`gefechtProvider`), ist die Munition gesperrt (Hinweis
  `kDabeiMunitionImGefecht`), weil das Gefecht Ladezustand und Schuss am
  Bestand führt und eine fremde Bestandsänderung den Ladezustand zurücksetzen
  würde; Geld und Verbrauchsgegenstände bleiben bedienbar.
  **Belastung (10.11.2026):** Am Ende des Blocks steht der Abschnitt
  „Belastung“ (`_Belastung`), gespeist aus `HeroComputedSnapshot.tragkraft`
  (`berechneTragkraft` in `tragkraft_rules.dart`, WdS S. 144). Seit 14.11.2026
  knapp: **eine Zeile** „Belastung x / y Stein“ (1 Stein = 1 kg, Key
  `karto-dabei-last`, „≥ “ davor, wenn getragene Einträge kein Gewicht haben),
  bei Überschreitung in Siegelfarbe mit der Marke „BE +n“
  (`karto-dabei-last-hinweis`). Die Herleitung (`tragkraftFormel`), die volle
  Folge (`TragkraftErgebnis.hinweis`: BE +1 je angefangene 50 % über der TK,
  über 2 × TK Verschnaufpausen alle KO Spielrunden, ab 4 × TK Absetzen alle
  5 × KO Schritt) und der Mindestwert-Hinweis stehen im Tooltip der Zeile.
  **Last** = Gewicht aller vom Helden getragenen Einträge (Stückgewicht × Menge;
  was ein Begleiter trägt, zählt nicht) plus Geld (Dukat 25 g, Silbertaler,
  Heller und Kreuzer je 5 g bei kleinstmöglicher Münzzahl, Geographia
  Aventurica S. 141) plus die **Hälfte** von allem, was eng am Körper
  getragen wird (`istAmLeibGetragen`, Tischregel des Nutzers vom 10.11.2026:
  Rüstung, Kleidung, getragene Ausrüstungsgegenstände und Waffen in den
  Händen, also jede angelegte bzw. ausgerüstete Ausrüstung; das Buch nennt nur
  Kleidung und Rüstung, WdS S. 144). Alles andere zählt voll: Gepäck, nicht
  angelegte Waffen und Rüstungen, Geschosse und Verbrauchsgut. **Tragkraft** =
  dauerhafte KK (`HeroStatInputs.permanent`, ohne laufende Zauber wie Attributo
  oder Karnifilo, im Snapshot als `permanentAttributes`), bei epischer
  KK-Haupteigenschaft mit aktiver Regel × 1,5 (aufgerundet, Epische Stufen Kap.
  2.1), plus die Tragkraftquellen des Helden. Die Quellen liegen additiv in
  `HeroSheet.tragkraftBoni` (`HeroTragkraftBonus`: Name, `stein`, optional `kk`
  nur für die Tragkraft; nur bei belegter Liste im JSON, Sync-Merge je ID). Nur
  **Dauerhaftes** gehört dorthin (Bärenrune bis zur Sonnenwende, dauerhafte
  Gegenstände), keine Kurzzeitzauber. **Gepflegt werden die Quellen im
  Inventar-Tab** (`TragkraftQuellenAbschnitt` in
  `lib/ui/screens/hero_inventory/tragkraft_quellen_abschnitt.dart`, unter dem
  Geldfeld, Keys `inventory-tragkraft-*`): „Tragkraft y Stein“ mit der
  Herleitung im Tooltip, die Quellen als Chips mit ×, „+ Bärenrune“ rechnet
  RkP\* × 10 Stein (Wege der Alchimie S. 161) und bietet die Hausregel „KK +1“
  („Erweiterung und Überarbeitung des Regelwerks“ Kap. 10) als Schalter; „+
  Andere Tragkraftquelle“ nimmt Name, Stein und KK. Quellen schreiben frisch
  über `aendereHeldMitMeldung` (`mitTragkraftBonus`, `ohneTragkraftBonus`) und
  sind während einer Planung gesperrt. In „Dabei“ stehen unter der Lastzeile
  Erschöpfung und Überanstrengung mit −/+, **nebeneinander** (Key
  `karto-dabei-stufen-nebeneinander`), sobald zwei Zellen à
  `kDabeiStufenZelleMin` (120 dp) passen, sonst untereinander
  (Laufzeitzustand, geschrieben über `updateHeroState` vom gespeicherten Wert,
  nie unter 0, auch während einer Planung bedienbar wie im Zustandsblock). Der
  Zustand der Spielansicht führt sie deshalb nicht mehr.
  Offen: Gepäck-Gewichte der Waffen- und Rüstungs-Slots sind nur so genau wie
  das im Inventar eingetragene Gewicht; die optionale Reiseregel „BE aus
  zusätzlicher Last je 25 %“ (WdS S. 144, Erschöpfung im Marsch) ist nicht
  eingerechnet.
  Der Block
  sperrt sich während einer Planung; die Schritte reihen sich je Held ein und
  haben bewusst keinen Doppelklickschutz, damit jeder Klick zählt. Ohne
  `aktion`-Guard und ohne Editorprüfung, wie der Abenteuerabschnitt: der
  Editorentwurf gleicht sich feldweise mit dem gespeicherten Bogen ab.
  **Würfelprotokoll (SPIEL-05):** `InspectorDiceLogSection` ist der gemeinsame
  Baustein von Inspector-Probe-Tab und Spielansicht (über die Brücke
  `spielProtokoll`). Die Spielansicht zeigt nur die neuesten `kProtokollKurz`
  (5) Würfe ohne Filter (`hoechstens`); „Alle anzeigen (n)“ öffnet die ganze
  Historie samt Filtern als Blatt (`zeigeWuerfelprotokoll`,
  `karto_wuerfelprotokoll.dart`), das `heroComputedProvider` selbst liest.
  Der Inspector-Tab der klassischen Oberfläche bleibt vollständig. Spielabende: `gruppiereNachSpielabend`
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
  für die `probeEintragIstWiederholbar` gilt, einen Knopf ein. Maßgeblich ist
  der stabile `DiceLogEntry.probenVerweis` (Format der häufigen Proben,
  `talent:<id>`, `zauber:<id>`, `eigenschaft:<Kürzel>`, `kampf:attacke`; erzeugt
  über `probenVerweis()` und `ResolvedProbeRequest.verweis`, nur bei Belegung im
  JSON). Nur Einträge ohne Verweis (ältere, Ersatzproben, Gefecht) werden noch am
  Titelpräfix (`kTalentprobeTitel` usw. in `probe_request_rules.dart`) und an der
  Probeart erkannt. Weder neutrale Einträge noch Buchungen. `wiederholeProbe`
  (`probe_quick_search.dart`) sucht unter denselben Kandidaten wie die
  Schnellsuche nach dem Verweis (`candidate.favorit.id`), ohne Verweis nach
  gleichem Titel **und** gleicher Art, und öffnet den normalen
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
  Muster: `_awaitCatalogReady` in `lib/ui/screens/heroes_home_screen.dart`,
  allgemein `warteAufAsyncWert` (`ui/screens/shared/async_wert_abwarten.dart`,
  mit Timeout). Held-gebundene Bausteine, die auch heldenlos laufen, lesen
  den Katalog über `beobachteHeldenKatalog`
  (`ui/screens/shared/held_katalog.dart`); Dialogrouten liegen außerhalb des
  `PlanungsBearbeitungsBereich`, die Helden-ID wird deshalb beim Öffnen
  mitgegeben.
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
