# Archiv — ARCH-05 Schreibende Aktionen fachlich aufteilen

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

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

- [x] Schreibpfade inventarisieren und pro Ablauf Eingaben, Ergebnis,
  Vorbedingungen, Seiteneffekte und Speichergrenzen festhalten.
  *([schreibpfade_inventar.md](../schreibpfade_inventar.md))*
- [x] Einen abgegrenzten Ablauf zunächst ohne Verhaltensänderung extrahieren,
  mit expliziten Abhängigkeiten statt uneingeschränktem Zugriff auf alle Provider.
  *(„Rast abschließen“; bewusst mit zwei kleinen Verhaltensänderungen, siehe
  Teilstand.)*
- [x] Weitere Abläufe nach demselben Prinzip entflechten; bestehende Aufrufer
  schrittweise migrieren und benötigte Kompatibilitätseinstiege erhalten.
  *(Rast, Laufzeitzustand, Schaden erhalten, die Sofortaktionen des Bogens
  und des Kampf-Tabs, der Inventareditor und alle Editorentwürfe sind
  frisch; kein Bogenschreibweg schreibt mehr einen Snapshot.
  „Steigerungsrunde übernehmen“ und „Held importieren“ sind benannte
  Abläufe, die Slotprüfung ist eine Regel. Siehe Teilstände (1) bis (11)
  und den Abschluss.)*

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

**Teilstand 29.09.2026 — Schreibpfade inventarisiert, „Rast abschließen“
als erster Ablauf.** Die ersten beiden Unterpunkte sind umgesetzt. Der
Hauptpunkt bleibt offen, bis weitere Abläufe entflochten sind.

*Entscheidungen (mit dem Nutzer abgestimmt).*

- **Ablage:** `lib/ablaeufe/` für Anwendungsabläufe ohne Riverpod und
  Flutter. Abhängigkeiten kommen per Konstruktor, aus `data/` nur die
  `HeroRepository`-Schnittstelle. Ein Wächtertest prüft die Importe
  (`test/ablaeufe/abhaengigkeiten_test.dart`). Die Riverpod-Bindung liegt
  in `lib/state/ablauf_providers.dart`. `HeroActions` bleibt als
  Kompatibilitätseinstieg bestehen.
- **Erster Ablauf „Rast abschließen“, nicht streng verhaltensneutral:**
  - Der Ablauf lädt den Zustand frisch und ersetzt nur die Rastfelder, statt
    den beim Rendern erfassten Zustand zurückzuschreiben. Das entspricht dem
    `updateHeroState`-Muster. Zuvor gingen Würfelprotokolle, Wunden oder
    Effekte verloren, die zwischen Öffnen und Übernehmen gespeichert wurden.
  - Speicherfehler erscheinen im Panel, und beide Aktionen sind gesperrt,
    solange gespeichert wird. Vorher gab es weder Fehleranzeige noch Schutz
    vor doppeltem Übernehmen.
  - Die Rast rechnet auf den gespeicherten Werten. Ohne Zwischenänderung ist
    das Ergebnis dasselbe wie bisher.
- **Regel statt Widget:** Die Vorschau- und Phasenrechnung, die Zuordnung
  von Aktivität zu Teilregeln und die Probenauswertung stehen jetzt in
  `rest_outcome_rules.dart`. Einzige bewusste Rechenabweichung: Ein
  negatives Maximum gilt als 0. Bisher warf `clamp` dort einen Fehler.

Commits:

- `7b08cd1` — Regel: `computeRestOutcome`, `RestActivity`,
  `isRestProbeSuccessful`, `RestRollSlot`, `applyRestOutcome`.
- `63935d3` — `lib/ablaeufe/zustand_schreiben.dart`
  (`aendereGespeichertenZustand`). `HeroActions.saveHeroState` und
  `updateHeroState` stempeln bzw. delegieren darüber. Dazu der Wächtertest
  und der Eintrag in CLAUDE.md.
- `3ee08b9` — `RastAbschliessen`, `baueRastProtokoll`,
  `rastAbschliessenProvider`. Der Hive-Ablauftest führt den Fullrestore
  jetzt über den Ablauf.
- `80b2944` — `RestPanel` nutzt Regel und Ablauf und zeigt Fehler an; dazu
  der Widgettest `rest_panel_test.dart`.
- `5597211` — Aufteilung in Teildateien unter `workspace/rest/`,
  verhaltensfrei. `rest_dialog.dart` schrumpft von 1574 auf 637 Zeilen.
- Abschluss-Commit mit Inventar und Dokumentation.

*Prüfungen.*

- Regeltests für jede Aktivität, darunter Bettruhe mit und ohne zweite
  Phase, außerdem Krankheit, fehlende Würfe, Probengrenzen, Begrenzung auf
  das Maximum, die bisherigen Eigenheiten und das negative Maximum.
- Ablauftests mit `FakeRepository`:
  - Zwischenänderungen bleiben erhalten; es ändern sich nur die erwarteten
    Felder (`expectNurGeaendert`).
  - Protokoll: Reihenfolge, Texte, Zeitstempel und Grenze.
  - fehlender Zustand und Fehlerweitergabe.
- Widgettests:
  - Übernehmen schreibt Werte und Protokoll.
  - Fehleranzeige bei Übernehmen und Fullrestore.
  - Sperre während des Speicherns.
  - Fullrestore mit Bestätigung und Abbruch.
  - Die bestehenden Workspace-Tests laufen unverändert.
- Gegenproben:
  - Ohne Sperre scheitert der Sperrtest.
  - Mit einem verbotenen Import scheitert der Wächter.
- `flutter analyze --no-pub` ohne Befund, volle Suite grün (2842
  bestanden, 3 übersprungen); die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Maxima und KO/IN-Zielwerte kommen aus dem berechneten Snapshot, der
   `tempMods` des Zustands einbezieht. Ändern sie sich zwischen letzter
   Anzeige und Übernehmen, rechnet die Rast mit dem alten Wert. Ein
   Neuberechnen im Ablauf bräuchte Katalog und Hausregeln (ARCH-06).
2. Laden, Ändern und Schreiben ist keine Transaktion gegen parallele
   Schreibwege, wie bei `updateHeroState`.
3. Die Würfelprotokolleinträge der Rast tragen jetzt den Zeitpunkt des
   Speicherns statt den ihres Aufbaus. Der Unterschied liegt im
   Millisekundenbereich.
4. Nächste Kandidaten nach demselben Muster (Befunde im Inventar):
   - ~~die Snapshot-Schreibwege des Zustands: Ressourcen, Zaubereffekte,
     Würfelprotokoll per `unawaited`, Wunden~~ *Erledigt im Teilstand
     „Snapshot-Schreibwege des Zustands“ unten.*
   - ~~danach „Schaden erhalten“ als eigener Ablauf (Voraussetzung für
     ARCH-01)~~ *Erledigt im Teilstand „Schaden erhalten“ unten.*
   - ~~`_filterKnownTraitWarnings` wartet mit `rulesCatalogProvider.future`
     und kann bei einem Katalogfehler hängen.~~ *Erledigt als Kleinfix:*
     `saveHero` wartet über ein Abo mit Zeitlimit (20 s) und speichert bei
     Fehler oder Zeitüberschreitung mit ungefilterten Restfragmenten.
     Nachgewiesen und abgesichert ist der Hänger bei einem nie fertigen
     Katalog (`test/state/hero_actions_katalog_warten_test.dart`). Weitere
     `.future`-Wartestellen stehen im Inventar (Befund 2).

**Teilstand 29.09.2026 (2) — Snapshot-Schreibwege des Zustands.** Befund 1
des [Schreibpfad-Inventars](../schreibpfade_inventar.md) ist behoben. Der
Hauptpunkt bleibt offen: Die Bogen-Schreibwege und „Schaden erhalten“
stehen noch aus.

*Befund.* Würfelprotokoll, Ressourcen-Stepper, Inspector-Vitals und -Magie,
Belastung, Zaubereffekte und Wunden schrieben einen beim Rendern erfassten
Zustand vollständig zurück. Was ein anderer Schreibweg in der Zwischenzeit
gespeichert hatte, ging dabei verloren: etwa ein Wurf, der während eines
offenen Dialogs protokolliert wurde. Selbst `updateHeroState` schützte nicht
vor zwei nicht abgewarteten Aufrufen. Beide lasen denselben Stand, der
zweite überschrieb den ersten. Nachgewiesen ist das für zwei direkt
nacheinander protokollierte Würfe.

*Entscheidungen.*

- **Reihenfolge statt Transaktion:** `aendereGespeichertenZustand` reiht
  Änderungen je Speicher und Held ein. Die Warteschlange hängt per
  `Expando` am Speicherobjekt statt an einem globalen oder Riverpod-Zustand.
  Dadurch profitieren alle bestehenden Aufrufer ohne Umbau, auch
  `RastAbschliessen`, und getrennte Speicher blockieren einander nicht. Ein
  Fehler hält die folgenden Änderungen nicht auf. Keine Transaktion
  gegenüber Schreibwegen an der Funktion vorbei (ARCH-06).
- **Ein UI-Einstieg:** `aendereZustandMitMeldung`
  (`lib/ui/screens/shared/zustand_aendern.dart`) lädt frisch, ersetzt nur
  die eigenen Felder und zeigt Fehler als Snackbar „… nicht gespeichert“.
  Die UI2-Ressourcenbrücke nutzt denselben Weg.
- **Absolut oder relativ:** Ressourcen bleiben absolut (der angezeigte Wert
  ±1 bzw. ±5), wie in der UI2-Brücke. Der Stepper klemmt auf `0..max`; ein
  relativer Schritt vom gespeicherten Wert könnte ein gespeichertes
  negatives LeP sonst auf 0 heben. Belastung, Wunden, Unterdrückung und
  Restdauer zählen dagegen vom gespeicherten Wert, dort gibt es keine
  solche Grenze.
- **Regel statt Widget:** Die Zustandsänderungen der Zaubereffekte stehen in
  `active_spell_state_rules.dart`. Die drei fast gleichen Wege „Wunde
  hinzufügen“ (Detaildialog, Inspector-Sektion, Inspector-Karte) sind jetzt
  einer (`fuegeWundeHinzu`).
- **Kleine Verhaltensänderungen:** Ist der Zustand im Provider noch nicht
  geladen, schreiben Würfelprotokoll und Zaubereffekte trotzdem, statt still
  nichts zu tun. `HeroActions.updateHeroState` liefert den gespeicherten
  Zustand; der Unterdrückungsdialog sieht dadurch den tatsächlich
  gespeicherten Wundzustand.

Commits:

- `93ebab4` — Reihenfolge je Held in `aendereGespeichertenZustand`, dazu
  `updateHeroState` mit Rückgabewert.
- `53700fa` — Regel `active_spell_state_rules.dart` mit Tests.
- `3dedf8d` — Oberfläche: alle genannten Schreibwege frisch, Fehler
  sichtbar, Wundabläufe zusammengeführt.
- Abschluss-Commit mit Inventar und Dokumentation.

*Prüfungen.*

- Ablauftests (`test/ablaeufe/zustand_schreiben_test.dart`): Zwei
  gleichzeitige Änderungen bleiben beide erhalten; ein Fehler hält die
  folgende Änderung nicht auf; verschiedene Helden warten nicht aufeinander.
- Regeltests (`test/rules/active_spell_state_rules_test.dart`): jede
  Funktion; nur die eigenen Felder ändern sich; Zählen ist wiederholbar.
- Widgettests (`test/ui/shared/zustand_frisch_schreiben_test.dart`): Ein
  anderer Schreibweg speichert nach dem Aufbau Wurf, KaP und Bauchwunde.
  Geprüft wird, dass sie nach jeder Bedienung erhalten bleiben: zwei nicht
  abgewartete Würfe, Stepper, Belastung mit zwei schnellen Klicks,
  Zaubereffekt umschalten, Restdauer zählen und Wunde hinzufügen samt
  Unterdrückungsdialog. Dazu Fehleranzeigen für Stepper und Würfelprotokoll.
- Gegenproben: Ohne Warteschlange scheitert der Ablauftest mit zwei
  gleichzeitigen Änderungen. Mit dem alten Oberflächencode scheitern alle
  acht Widgettests.
- `flutter analyze --no-pub` ohne Befund, volle Suite grün (2864
  bestanden, 3 übersprungen). Die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Snapshot-Schreibwege des Zustands bleiben im Übersichtseditor
   (Editorentwurf, Bogen und Zustand getrennt), beim Anlegen und beim
   Import. Wer `HeroActions.saveHeroState` nutzt, ist nicht eingereiht.
2. ~~Ressourcen bleiben absolut: Zwei Klicks, bevor die Oberfläche den ersten
   Stand zeigt, ergeben einen Schritt statt zwei.~~ *Erledigt im Nachtrag
   unten.*
3. Der Inspector-Vitals- und -Magie-Tab haben keinen eigenen Widgettest. Sie
   nutzen denselben Einstieg wie der geprüfte Stepper.
4. Snapshot-Schreibwege des **Bogens** bleiben: Dauermodifikatoren,
   Wundschwelle, Inventar, Kampf und die Sofortaktionen der Übersicht.
   *Die Sofortaktionen sind im Teilstand (5) behoben; Inventareditor und
   Kampf bleiben.*
5. ~~Nächster Schritt: „Schaden erhalten“ als eigener Ablauf. Er kann jetzt auf
   `aendereGespeichertenZustand` und `aendereWundZustand` aufsetzen und ist
   die Voraussetzung für ARCH-01. Die Korrekturmöglichkeit bleibt an ARCH-06
   gebunden.~~ *Erledigt im Teilstand „Schaden erhalten“ unten.*

*Nachtrag 29.09.2026 — schnelles Tippen mit Konto-Sync.* Eine manuelle
Prüfung zeigte: Wer schnell viele AsP verbraucht, bekommt eine Fehlermeldung
hinter dem Blatt und Sync-Konflikte. Nachgestellt mit einer verzögerten Cloud,
die jeden Schreibvorgang als Echo zurückschickt:

- Ohne Warteschlange (Stand `main`) kamen von zehn Klicks vier in der Cloud
  an. Die Uploads liefen parallel auf derselben Basisrevision; der zweite
  und das Echo des ersten sahen wie eine fremde Änderung aus, es entstand
  ein Konflikt mit sich selbst.
- Mit der Warteschlange dieses Teilstands gab es keinen Konflikt mehr, aber
  jeder Klick wartete zwei Netzwege ab. Die Anzeige lief hinterher, und
  Klicks auf den veralteten angezeigten Wert gingen verloren.

*Entscheidungen (mit dem Nutzer abgestimmt: Fehler wie beim Rastpanel,
jede Eingabe soll sicher verarbeitet werden).*

- **Lokal sofort, Cloud gebündelt:** `SyncingHeroRepository.saveHeroState`
  endet nach dem lokalen Speichern. `GebuendelteLaeufe` lädt je Held im
  Hintergrund hoch, nie zwei gleichzeitig, immer den neuesten lokalen Stand;
  zehn Klicks ergeben höchstens zwei Uploads. Online-Stände, die während
  eines Uploads eintreffen, werden erst danach bewertet: Solange er läuft,
  ist der lokale Stand voraus, und das eigene Echo sähe fremd aus. `syncNow`
  wartet auf laufende Uploads und lädt über dieselbe Bündelung hoch. Der
  Bogen (`saveHero`) wartet weiterhin auf seinen Upload.
- **Jeder Klick zählt:** Ressourcenknöpfe melden eine `RessourcenAenderung`
  (`ressourcen_aenderung_rules.dart`) statt eines fertigen Werts: ein Schritt
  vom gespeicherten Wert oder Setzen (Zurücksetzen auf das Maximum). Grenzen
  gelten nur in Schrittrichtung; ein −1 hebt gespeicherte negative LeP
  nicht auf 0, ein +1 senkt keine Überheilung.
- **Fehler dort, wo bedient wird:** `ZustandFehlerBereich` und
  `ZustandFehlerAnzeige` zeigen „… nicht gespeichert“ im Stepper, im
  UI2-Ressourcenblatt, im Zaubereffekt- und Wundendialog, in den
  Inspector-Tabs Vitals und Magie sowie im UI2-Zustandsblock; der nächste
  Erfolg blendet die Meldung aus. Die Snackbar bleibt Rückfall. Netzfehler
  erreichen diese Anzeige nicht mehr, sie stehen im Sync-Status und
  `syncNow` holt den Upload nach.

Commits: `b744dcd` (Sync), `02693f2` (Regel und Oberfläche) und der
Dokumentations-Commit.

*Prüfungen.* `test/data/zustand_schnell_tippen_sync_test.dart` (Cloud mit
40 ms Laufzeit, Echo vor der Antwort): Zehn Klicks stehen lokal ohne
Wartezeit, weniger als zehn Uploads, kein Konflikt. Offline bleibt jeder Klick
lokal und `syncNow` holt ihn nach. Eine gemeldete fremde Änderung wird
übernommen, eine nicht gemeldete wird ein Konflikt. Dazu
`gebuendelte_laeufe_test.dart`, `ressourcen_aenderung_rules_test.dart` und
Widgettests für fünf schnelle Klicks im Stepper, drei −5 im UI2-Blatt bis
zur Untergrenze und Fehler im Blatt bzw. Dialog. Gegenproben: Mit dem alten
Sync-Code scheitert der Latenztest (877 ms). Ohne Zurückstellen der Echos
entsteht der Selbstkonflikt. Mit absolutem Setzen scheitern beide
Schnellklick-Tests. Zwei Zwei-Geräte-Tests warten jetzt im Offline-Abschnitt
auf den Hintergrund-Upload (`warteAufUebertragungen`), weil er sonst erst
nach dem Umschalten liefe.

*Verbleibende Risiken.*

1. Zwischen lokalem Speichern und Upload liegt jetzt ein Fenster. Wird die
   App darin beendet, holt der nächste `syncNow` den Stand nach (wie offline).
   Ein anderes Gerät sieht ihn erst dann.
2. Ein Upload, der offline angestoßen wurde und erst wieder online läuft,
   überträgt den Zustand vor dem nächsten Abgleich des Helden. Ändern zwei
   Geräte offline Held **und** Zustand, kann der Zustands-Konflikt dann als
   eigener Eintrag statt gebunden an den Helden erscheinen, wie schon
   bisher beim Speichern mit Verbindung.
3. Fehler beim Protokollieren eines Wurfs erscheinen weiter als Snackbar,
   weil der Probendialog keinen eigenen Fehlerbereich hat. Da der Upload
   nicht mehr dazugehört, bleiben dafür nur lokale Speicherfehler.
4. Der Bogen (`saveHero`) wartet weiter auf seinen Upload; schnelle
   Bogenänderungen (Inventar) laufen nicht über die Bündelung.

**Teilstand 29.09.2026 (3) — „Schaden erhalten“ als Ablauf.** Der
Hauptpunkt bleibt offen: Die Bogen-Schreibwege stehen noch aus.

*Entscheidungen (mit dem Nutzer abgestimmt).*

- **Wunden sind ein Vorschlag.** Ob ein Treffer Wunden schlägt, hängt auch
  vom Angriff ab (Pfeile senken die Wundschwelle um 2). Der Dialog fragt
  diesen Modifikator ab und schlägt je echt überschrittener
  Wundschwellenstufe (0,5 KO, KO, 1,5 KO, 2 KO, jeweils mit Eisern bzw.
  Glasknochen) eine Wunde vor. Der Nutzer entscheidet über die Zahl.
- **Zone:** wählbar oder per W20 über `resolveTrefferzone`. Die Zusatzwürfe
  (Kopf 2W6 INI-Malus, Brust/Bauch 1W6 SP je Wunde, dritte Kopfwunde 2W6 SP)
  kommen aus der vorhandenen Trefferzonentabelle; `TrefferzonenZusatzwurf`
  trägt dafür jetzt seine Wirkung.
- **TP(A) als Umschalter:** Ausdauerschaden senkt nur AuP, höchstens bis 0,
  und schlägt keine Wunden. Ein Überlauf auf LeP ist nicht vorgesehen.
- **LeP ohne Untergrenze,** wie bei der Anzeige in UI2. RS kommt vorbelegt
  aus der Kampfvorschau (Gesamt-RS, Zonenrüstung gibt es im Modell nicht)
  und ist änderbar.
- **Korrektur:** Jede Buchung erzeugt einen Protokolleintrag mit
  `ProbeType.damage` und allen Werten; einen neuen Aufzählungswert gibt es
  bewusst nicht. Eine Rücknahme gehört zu ARCH-06.
- **Oberfläche:** Der Dialog liegt im Bestand (`workspace/schaden/`), weil
  Würfel und Wundunterdrückung dort liegen. UI2 öffnet ihn über die neue
  Brückenmethode `KartoBestandsAdapter.schadenErhalten` als dritte
  Schnellaktion. Nach neuen Wunden folgt die vorhandene Unterdrückungsabfrage
  (`bieteWundUnterdrueckungAn`, aus `fuegeWundeHinzu` herausgelöst).

Commits:

- `83c3567` — Regel `schaden_rules.dart` mit Tests, Wirkung der
  Zusatzwürfe.
- `41d1070` — Ablauf `SchadenErhalten`, Protokoll, Provider, Ablauftests.
- `fc37de6` — Dialog im Inspector-Vitals-Tab mit Widgettests.
- `7a05c3d` — UI2-Schnellaktion über die Brücke, Adapter- und
  Spielansichtstests; der Test gegen erfundene Bedienelemente prüft weiter
  Rundenzähler und Rücknahme.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests (`test/rules/schaden_rules_test.dart`): SP-Grenze, „echt
  größer“ an jeder Stufe, Angriffsmodifikator, Merkmalsbonus, vier Wunden,
  Kappung an der vollen Zone, Kopf-INI, Brust-Zusatz, negative LeP, AuP bis
  0, nur die eigenen Felder ändern sich, widersprüchliche Buchungen werden
  abgewiesen.
- Ablauftests (`test/ablaeufe/schaden_erhalten_test.dart`): nur LeP, Wunden,
  Protokoll und Stempel ändern sich; Protokolltext; Ausdauer; eine
  Zwischenänderung (LeP, AsP, Wunde, Wurf) bleibt erhalten, und die Kappung
  richtet sich nach dem gespeicherten Stand; fehlender Zustand;
  Fehlerweitergabe.
- Widgettests (`test/ui/workspace/schaden_dialog_test.dart`): vorbelegter
  RS, Vorschlag und W20-Zone mit Zusatzwurf, überstimmter Vorschlag mit
  Angriffsmodifikator, volle Zone, Ausdauer, Fehler im Panel, Sperre während
  des Speicherns, Dialog schließt sich und bietet die Unterdrückung an. Dazu
  der Brückentest im Kompatibilitätstheme und die UI2-Schnellaktion.
- Gegenproben: Ohne Kappung an den freien Plätzen scheitern der Regeltest
  „volle Zone“ und der Ablauftest mit Zwischenänderung. Rechnet der Ablauf
  auf einem veralteten statt dem frischen Stand, scheitern der
  Zwischenänderungs- und der Leerzustandstest.
- `flutter analyze --no-pub` ohne Befund, volle Suite grün (2913
  bestanden, 3 übersprungen). Die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Keine Rücknahme; eine falsche Buchung korrigiert der Nutzer von Hand
   (ARCH-06).
2. ~~Die Unterdrückungsabfrage unterdrückte höchstens eine Wunde.~~
   *Behoben (Nutzervorgabe):* Alle Wunden eines Angriffs werden nur
   gemeinsam unterdrückt, in einem Speichervorgang; die Erschwernis nimmt
   `computeSbUnterdrueckungErschwernis` mit der Zahl neuer Wunden (+8 bzw.
   +12). Widgettest „alle Wunden eines Angriffs werden gemeinsam
   unterdrückt“; mit Unterdrückung nur einer Wunde scheitert er.
7. ~~**Noch per dsa-rules-MCP am Rechner zu validieren** (in dieser Umgebung
   war der Server nicht erreichbar): LeP ohne Untergrenze; TP(A) mit
   RS-Abzug und ohne Überlauf auf LeP; Wunden über die freien Plätze einer
   Zone verfallen. Außerdem die Rundung der Wundschwellen: Gelten sie als
   reale (gebrochene) Werte, z. B. 6,5 bei KO 13, oder werden sie immer
   aufgerundet? Heute rundet `computeWundschwelle` ab, die Stufen runden
   kaufmännisch (Befund 4); je nach Ergebnis beide angleichen.~~
   *Validiert und korrigiert in Teilstand (4):* TP(A) trifft zur Hälfte auch
   die LeP; Wundschwellen sind ganzzahlig und kaufmännisch gerundet.
3. Wundschwellen und RS stammen aus dem berechneten Snapshot. Die
   Zusatzwürfe beziehen sich auf die angezeigte Wundzahl der Zone; kappt der
   gespeicherte Stand die Wunden stärker, bleibt der eingetragene
   Zusatzschaden trotzdem gebucht.
4. ~~Befund: Das einzelne `computeWundschwelle` (Inspector „WS n“) rechnet
   KO/2 abgerundet ohne den Eisern/Glasknochen-Bonus, die Stufen rechnen
   kaufmännisch gerundet mit ihm. Der Ablauf nutzt die Stufen; die Anzeige
   kann bei ungeradem KO oder mit Eisern abweichen. Nicht behoben.~~
   *Behoben in Teilstand (4):* `computeWundschwelle` ist die erste Stufe.
5. Kein Encounter: Schaden wird nicht aus einem Angriff übergeben, sondern
   eingetragen (Spielmodus-Konzept Phase 3).
6. ~~Nächster Schritt: die Snapshot-Schreibwege des **Bogens**
   (Dauermodifikatoren, Wundschwelle, Inventar, Kampf, Sofortaktionen der
   Übersicht).~~ *Sofortaktionen erledigt im Teilstand (5); Inventareditor
   und Kampf sind der nächste Schritt.*

**Teilstand 29.09.2026 (4) — Schadensregeln per dsa-rules-MCP validiert.**
Die offenen Annahmen aus Teilstand (3) sind gegen *Wege des Schwerts* (WdS),
das *Basisregelwerk* (BRW) und die Hausregeln im dsa-rules-MCP geprüft.
Der Hauptpunkt von ARCH-05 bleibt offen (Bogen-Schreibwege).

*Befunde.*

| Annahme aus (3) | Befund | Quelle |
| --- | --- | --- |
| LeP ohne Untergrenze | bestätigt; LE ≤ 0 lebensbedrohlich, unter −KO tot (Zäher Hund 1,5 × KO) | WdS S. 57 |
| TP(A): RS wird abgezogen | bestätigt | WdS S. 57, 88 |
| TP(A) senkt nur AuP | **falsch:** SP(A) von der AuP, zusätzlich die Hälfte als echte SP von der LeP | WdS S. 57, 88; BRW S. 138 |
| TP(A) schlägt keine Wunden | **falsch:** die echten SP schlagen Wunden, WS dabei üblicherweise +2 | WdS S. 58, 88; BRW S. 139 |
| kein Überlauf AuP → LeP | bestätigt; bei 0 AuP kampfunfähig | WdS S. 57, 84 |
| Wunden über den freien Plätzen verfallen | bestätigt; höchstens 3 je Zone, SP gehen voll von der Gesamt-LE | WdS S. 109 |
| Rundung der Wundschwellen | ganzzahlig, kaufmännisch („halbe KO ist gerundet 7“ bei KO 13) | WdS S. 58; BRW S. 139; WdZ S. 7 |
| Stufen 0,5 / 1 / 1,5 / 2 KO | **teilweise falsch:** nur drei Stufen, höchstens 3 Wunden je Treffer; für 2 KO keine Quelle, auch nicht in den Hausregeln | WdS S. 58 |
| Eisern/Glasknochen ±2 auf alle Stufen | bestätigt, kumulativ mit dem Angriffsmodifikator | WdS S. 58 |
| „Pfeile −2“ | nicht belegt; genannt sind Armbrustbolzen, Gezielter Stich und „bestimmte Waffen“ (−2), waffenlos und Stumpfer Schlag (+2) | WdS S. 58 |
| Zusatzwürfe der Zonen | bestätigt (Kopf 2W6 INI, Brust/Bauch 1W6 SP je Wunde, dritte Kopfwunde 2W6 SP) | WdS S. 109 |
| SB-Unterdrückung | bestätigt (4 je Gesamtwunde; mehrere aus einem Treffer gemeinsam, +8/+12) | WdS S. 83 |

*Korrekturen (Nutzerentscheidungen: TP(A) nach WdS, 2-KO-Stufe überall
entfernen).*

- `echteSchadenspunkte`/`SchadensBuchung.echteSp`: bei TP(A) die Hälfte der
  SP(A), kaufmännisch gerundet. `wendeSchadenAn` senkt bei TP(A) die AuP um
  die SP(A) bis 0 **und** die LeP um die echten SP plus Zusatzschaden; Wunden
  laufen für beide Arten gleich. Die Sperre „Ausdauerschaden verursacht keine
  Wunden“ ist entfallen.
- Dialog: Zone, Modifikator, Wunden und Zusatzwürfe auch bei TP(A); der
  Modifikator wird beim Wechsel mit +2 (TP(A)) bzw. 0 vorbelegt. Die
  Vorschau zeigt AuP und LeP. Hilfetext „Armbrustbolzen −2, waffenlos +2“.
- Protokoll bei TP(A): `TP(A) 8 − RS 1 = 7 SP(A) · 4 SP auf LeP`, `total`
  ist der LeP-Verlust.
- `WundschwellenStufen` hat nur noch drei Stufen; der Vorschlag reicht bis 3,
  der Wunden-Detaildialog zeigt „2 KO“ nicht mehr.
- `computeWundschwelle` ist die erste Stufe (kaufmännisch, samt
  Eisern/Glasknochen); Befund 4 ist damit behoben.

*Prüfungen.* Regeltests (`schaden_rules_test.dart`: Rundung der echten SP,
AuP und LeP bei TP(A), Wunden aus echten SP, höchstens 3 Wunden, Beispiele
KO 13 aus WdS S. 58; `wund_rules_test.dart`: KO 15 → 8, Gleichheit mit der
ersten Stufe), Ablauftests (TP(A) mit und ohne Wunde samt Protokoll) und
Widgettests (TP(A)-Vorschau, Vorbelegung, Wundvorschlag, Rückwechsel).
`bestandshelden_regelwerte_test.dart`: Die Wundschwelle von f01 (7 → 9) und
f04 (9 → 11, drei Fälle) zählt jetzt Eisern mit, f02 und f07 (6 → 7) runden
KO 13 kaufmännisch; die Fixtures und die Hash-Pins sind unverändert.
Gegenproben: Mit `KO ~/ 2` scheitern beide `computeWundschwelle`-Tests,
ohne den LeP-Anteil die drei TP(A)-Regeltests. `flutter analyze --no-pub`
ohne Befund, volle Suite grün (2921 bestanden, 3 übersprungen).

*Randbefunde, bewusst ohne Änderung (Folgeaufträge).*

1. Die Hausregel „Mindestschaden“ ist eine Sammlung von Überlegungen ohne
   Entscheidung; `berechneSchadenspunkte` bleibt bei `max(0, TP − RS)`.
2. Kritische Treffer schlagen automatisch eine Wunde mehr, sobald die WS
   überschritten ist (WdS S. 85). Das deckt die änderbare Wundzahl ab.
   *Korrigiert in Teilstand (6):* Die Hausregel „Erweiterung und
   Überarbeitung des Regelwerks“ (S. 3) hebt das auf: „Kritische Treffer
   richten aber keine zusätzliche Wunde an.“
3. Mit Trefferzonen *ersetzen* die Zonenwunden (WdS S. 109) die pauschalen
   −2 je Wunde (S. 57); `computeWundEffekte` addiert beide. Das ist eigens
   gegen Regelwerk und Hausregeln zu prüfen. *Geprüft im Teilstand (5),
   siehe Folgeauftrag „Zonenwunden nach WdS“ unten; umgesetzt in
   Teilstand (6).*
4. Die Tabelle der Zonenwunden kennt weitere Folgen (Kopf: MU/KL/IN −2;
   Brust/Bauch: KO/KK −1; dritte Wunde: Bewusstlosigkeit und 1 LeP je KR),
   die das Modell nicht abbildet. *Ebenfalls Teil des Folgeauftrags;
   umgesetzt in Teilstand (6).*

**Teilstand 29.09.2026 (5) — Sofortaktionen des Bogens frisch.** Befund 1
des [Schreibpfad-Inventars](../schreibpfade_inventar.md) ist für die
Sofortaktionen des Bogens behoben. Der Hauptpunkt bleibt offen, weil der
Inventareditor, das Kampf-Sofortspeichern und die Editorentwürfe weiter
Snapshots schreiben.

*Befund.* Dauermodifikatoren, Wundschwelle, die Sofortaktionen der
Übersicht, Inventar-Löschen und Dukaten, Abenteuerabschluss und
Vertrauten-Steigerung schrieben einen beim Rendern erfassten Bogen ganz
zurück. Was ein anderer Weg (UI2-Blatt, Editor, anderes Gerät) zwischendurch
gespeichert hatte, ging verloren. Zwei schnelle Klicks auf „GS +“ zählten
einmal, Fehler blieben meist unsichtbar. `updateHero` lud zwar frisch, war
aber nicht eingereiht. Eine offene Steigerungsrunde brach jede dieser
Änderungen still („Der Held wurde inzwischen geändert“). Das Löschen im
Inventar schrieb außerdem die Geschossmengen des Snapshots zurück, und der
Abenteuerabschluss prüfte den Doppelabschluss nur an der Anzeige.

*Entscheidungen (mit dem Nutzer abgestimmt: Umfang „Sofortaktionen“,
Planung „gesperrt mit Hinweis“).*

- **Warteschlange für den Bogen, auch für `saveHero`:**
  `aendereGespeichertenHelden` (`lib/ablaeufe/held_schreiben.dart`) lädt
  frisch und speichert über die injizierte Normalisierung. `updateHero`
  delegiert daran; `saveHero` reiht sich über `reiheBogenvorgangEin` in
  dieselbe Warteschlange ein. So überholt ein Editorentwurf keine laufende
  frische Änderung, und die Hash-Prüfung der Steigerungsrunde sieht jede
  eingereihte Änderung. Beide liefern den normalisierten, gespeicherten
  Helden. Den `Expando`-Baustein teilen sich Zustand und Bogen
  (`ReihenfolgeJeHeld`) mit getrennten Warteschlangen. Gibt eine Änderung
  dasselbe Objekt zurück, wird nichts gespeichert.
- **Ein UI-Einstieg:** `aendereHeldMitMeldung` neben
  `aendereZustandMitMeldung`, mit demselben Fehlerweg; fachliche Gründe
  erscheinen ohne „Bad state:“.
- **Planung:** Bei offener Steigerungsrunde schreibt der Einstieg nichts und
  meldet den Grund. Inspector-Statuswerte und das Wundschwellen-Zahnrad sind
  zusätzlich sichtbar gesperrt (Hinweiszeile bzw. Tooltip); BE bleibt, sie
  liegt nur im Arbeitsspeicher. Die übrigen Wege liegen in der Verwaltung,
  die während einer Planung ohnehin gesperrt ist.
- **Schritt statt Wert:** Dauermodifikatoren (über `RessourcenAenderung`),
  AP addieren und die Münzknöpfe zählen vom gespeicherten Wert. Eingetippte
  Beträge und Dialogergebnisse (Modifikatorlisten, Epik) bleiben absolut,
  ersetzen aber nur ihren Schlüssel. Der Ressourcendialog schreibt nur
  umgestellte Schalter.
- **Regel statt Widget:** `modifikator_aenderung_rules.dart`,
  `epic_status_rules.dart`, `inventar_aenderung_rules.dart`,
  `begleiter_aenderung_rules.dart`, dazu `mitApSchritt`,
  `mitRessourcenSchaltern`, `quittiereEigenschaftsHinweis`,
  `schliesseAbenteuerAb`/`oeffneAbenteuerWieder` und `steigereBegleiter`.
- **Keine Doppelbuchung:** Epik wird nie zweimal aktiviert, ein gespeichert
  schon abgeschlossenes Abenteuer nicht erneut gebucht, eine
  Vertrauten-Steigerung auf einen inzwischen geänderten Ausgangsstand
  abgewiesen. Inventar-Löschen findet den Eintrag über seinen Inhalt; ist er
  geändert oder fort, erscheint ein Fehler statt eines falschen Treffers.
- **Nebenbei behoben:** Der AP-Betragsdialog entsorgte seinen Controller vor
  dem Ende der Schließanimation und warf. Der nie aufgerufene Weg
  `onSaveImmediate` im Begleiter-Tab ist entfernt.

Commits:

- `598d490` — Ablauf `aendereGespeichertenHelden`, `ReihenfolgeJeHeld`,
  `saveHero`/`updateHero` eingereiht mit Rückgabewert, Ablauftests.
- `ba40066` — Regeln samt Tests.
- `3d26d97` — `aendereHeldMitMeldung`, Inspector-Statuswerte und
  Wundschwelle, Planungssperre.
- `758c9d6` — Übersicht-Sofortaktionen, AP-Dialog.
- `1297737` — Inventar, Abenteuerabschluss, Vertrauten-Steigerung.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Ablauftests (`test/ablaeufe/held_schreiben_test.dart`): frisches Laden,
  Rückgabe der Normalisierung, fehlender Held, „nichts zu speichern“, zwei
  nicht abgewartete Änderungen, ein eingereihter Vorgang wartet, Fehler hält
  nicht auf, verschiedene Helden sowie Bogen und Zustand warten nicht
  aufeinander. `hero_actions_update_hero_test.dart`: normalisierter
  Rückgabewert, zwei schnelle Schritte, `saveHero` überholt keine laufende
  Änderung, Hash-Prüfung sieht eine eingereihte Änderung.
- Regeltests: `bogen_sofortaenderung_rules_test.dart`,
  `begleiter_aenderung_rules_test.dart`, `abenteuer_abschluss_rules_test.dart`.
- Widgettests gegen eine Zwischenänderung (`BogenTestRepository`, die
  Oberfläche liest über den Index, nur frisches Laden sieht sie):
  `test/ui/shared/held_frisch_schreiben_test.dart` (Statuswerte: Schritt,
  drei schnelle Klicks, Zurücksetzen, Fehler im Zustandsblock, Sperre;
  Wundschwelle: Schlüssel, Fehler im Dialog, Sperre; zentraler Einstieg bei
  Planung), `test/ui/overview/uebersicht_frisch_schreiben_test.dart` (AP,
  Ressourcenschalter samt Fehler im Blatt, beide Modifikatordialoge, Epik
  samt Doppelaktivierung, Hinweisquittung),
  `test/ui/inventory/inventar_frisch_schreiben_test.dart` (Löschen nach
  Verschiebung, geänderter Eintrag, schnelle Münzschritte, Tippen,
  Tippen plus Münzschritt, Fehler) und
  `test/ui/shared/verwaltung_frisch_schreiben_test.dart` (Abenteuer auf dem
  gespeicherten Stand, kein Doppelabschluss, Vertrauten-Steigerung,
  abgewiesener Ausgangsstand).
- Gegenproben: Ohne Warteschlange scheitern sechs Ablauf- und
  `HeroActions`-Proben. Mit dem alten Oberflächencode scheitern 8 von 9
  Spielansichtsproben, alle 9 Übersichtsproben und 9 von 10 Inventar-,
  Abenteuer- und Begleiterproben; die jeweils bestehende prüft Verhalten,
  das schon vorher stimmte.
- `flutter analyze --no-pub` ohne Befund, Zeilenbudget eingehalten, volle
  Suite grün (2993 bestanden, 3 übersprungen). Die Hash-Pins der
  Bestandshelden sind unverändert. Eine manuelle Bedienprüfung auf Geräten
  steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Inventareditor und Kampf-Sofortspeichern (Waffenwahl, Geschosse ±,
   Slots) schreiben weiter Snapshots, ebenso alle Editorentwürfe. Sie sind
   jetzt eingereiht, überholen also keine frische Änderung, aber der zuletzt
   ausgelöste Schreibvorgang gewinnt. Nächster Schritt: Inventareditor
   (Einträge ohne ID, ARCH-03) und Kampf. *Kampf erledigt im Teilstand (7);
   der Inventareditor bleibt.*
2. Der Bogen wartet weiter auf seinen Upload; mit Konto laufen schnelle
   Klicks auf „GS +“ je Netzweg nach, gehen aber nicht verloren. Eine
   Bündelung wie beim Zustand (`GebuendelteLaeufe`) wäre ein eigener
   Sync-Auftrag.
3. Die Warteschlange hält auch während der Normalisierung, die bis zu 20 s
   auf den Katalog warten kann, wenn er fehlt und Parser-Restfragmente da
   sind.
4. Keine Transaktion gegen Schreibwege an der Warteschlange vorbei:
   ~~`setShowInapplicableSpecialAbilities` (direkt über das Repository),~~
   der Startimport und Sync-Übernahmen (ARCH-06). *Die SF-Anzeige ist seit
   Teilstand (10) eingereiht.*
5. Eine Änderung, die selbst `saveHero` oder `updateHero` aufruft, wartete
   auf sich selbst. Kein Weg tut das; es steht in CLAUDE.md.
6. Das Abschließen eines Abenteuers verwirft wie bisher einen offenen
   Notizentwurf (`_syncDraftFromHero(force: true)`); der Knopf steht nur
   außerhalb des Bearbeitens.

**Folgeauftrag „Zonenwunden nach WdS“ (per dsa-rules-MCP geprüft,
29.09.2026).** Randbefund 3 aus Teilstand (4) ist bestätigt. Die Hausregeln
kennen kein eigenes Wundsystem; „Schmerzlos“ (Erweiterung und Überarbeitung
des Regelwerks, S. 8: „alle ersten bzw. auch alle zweiten Wunden in einer
Zone ignorieren“) setzt Zonenwunden voraus.

| Befund | Quelle |
| --- | --- |
| Nicht lokalisierte Wunde: AT, PA, FK, INI-Basis und GE je −2, GS −1 | WdS S. 58; BRW S. 194 |
| „Die folgenden Regelungen **ersetzen** die Angaben zu nicht-lokalisierten Wunden“ | WdS S. 109 |
| Wundbedingte Eigenschaftsverluste wirken nicht auf AT-, PA-, FK- und INI-Basiswerte; GS nie unter 1 | WdS S. 111 |
| Kopf: MU, KL, IN, INI-Basis −2, INI −2W6; dritte: +2W6 SP, bewusstlos | WdS S. 108 f. |
| Brust (auch Rücken): AT, PA, KO, KK −1, +1W6 SP; dritte: bewusstlos | WdS S. 108 f. |
| Arm: AT, PA, KK, FF −2 **mit diesem Arm**; dritte: Arm handlungsunfähig | WdS S. 108 f. |
| Bauch: AT, PA, KO, KK, GS, INI-Basis −1, +1W6 SP; dritte: bewusstlos | WdS S. 108 f. |
| Bein: AT, PA, GE, INI-Basis −2, GS −1; dritte: Sturz, kein Nahkampf | WdS S. 108 f. |
| Pauschal −3 auf Talent- und Zauberproben je Wunde | keine Quelle (Regelwerk und Hausregeln) |

`computeWundEffekte` addiert heute die pauschalen −2 **und** eigene
Zonenwerte, die zu keiner Zone der Tabelle passen (etwa Arm: AT/PA −4 und
FK −6 insgesamt, Kopf AT/PA/FK −1 und Zauber −3). Offene Entscheidungen vor
der Umsetzung: Gilt immer das Zonensystem (das Modell kennt keine
unlokalisierten Wunden)? Wie werden FK (in der Tabelle nicht genannt) und
der Armbezug („mit diesem Arm“, Schwert- oder Schildarm) behandelt? Werden
Eigenschaftsverluste (MU, KL, IN, KO, KK, GE, FF) als Modifikatoren
modelliert, ohne auf die Basiswerte zu wirken? Entfällt die pauschale
Probenerschwernis, und was bedeutet dann die epische KO-Halbierung? Die
Regelwerte der Bestandshelden mit Wunden (f01, f04) ändern sich dabei.
*Per dsa-rules-MCP geklärt und umgesetzt in Teilstand (6).* Die Annahme
oben, die Hausregeln kennten kein eigenes Wundsystem, war falsch: Sie
verlangen die kombinierte Wirkung beider Systeme.

**Teilstand 30.09.2026 (6) — Zonenwunden nach WdS.** Der Folgeauftrag ist
umgesetzt. Der Hauptpunkt von ARCH-05 bleibt offen (Inventareditor, Kampf,
Editorentwürfe).

*Nachprüfung per dsa-rules-MCP.* Die offenen Fragen des Folgeauftrags sind
gegen Regelwerk und Hausregeln geprüft:

| Frage | Befund | Quelle |
| --- | --- | --- |
| Zonensystem statt Gesamtsystem? | **beides:** „Wunden haben die kombinierte Wirkung einer Wunde nach Zonensystem und nach Gesamtsystem“ | Hausregel „Erweiterung und Überarbeitung des Regelwerks“ S. 3 |
| Gesamtsystem je Wunde | AT, PA, FK, INI-Basis, GE −2; GS −1; die GE-Änderung wirkt auf keinen Basiswert | WdS S. 58; BRW S. 194 |
| Zonentabelle | wie im Folgeauftrag; Brust gilt auch für den Rücken | WdS S. 108 f. |
| FK bei Armwunden | in der Zonentabelle nicht genannt; FK sinkt nur allgemein | WdS S. 108 f. |
| Armbezug | „wenn er diesen Arm benutzt“; Schwert- und Schildarm werden unterschieden | WdS S. 108 f. |
| Eigenschaftsverluste | wirken nicht auf AT-, PA-, FK- und INI-Basis; GS durch Wunden nie unter 1 | WdS S. 111 |
| Pauschal −3 auf Proben je Wunde | keine Quelle | Regelwerk und Hausregeln |
| Epische KO | „Die Erschwernis und die resultierende Erschöpfung durch das Unterdrücken von Wunden sind halbiert“ | Epische Stufen S. 4 |
| Unterdrücken | SB +4 je Gesamtwunde, +8/+12 für mehrere aus einem Treffer; nach dem Kampf 1W6 Erschöpfung | WdS S. 83 |
| Kopf-INI 2W6 | Verlust des **aktuellen** Initiativewerts | WdS S. 109 |

*Entscheidungen (mit dem Nutzer abgestimmt).*

- **Kombiniert und additiv:** allgemeine Abzüge plus Zonenabzüge,
  gerechnet in `wund_zonen_rules.dart` als Daten
  (`kWundAllgemein`, `wundZonenWirkung`).
- **Keine pauschale Proben-Erschwernis mehr.** Wunden senken die
  Eigenschaften nur für Proben (`HeroComputedSnapshot.probenEigenschaften`,
  `wendeWundVerlusteAn`). Abgeleitete Werte (AT/PA/FK/INI-Basis, LeP,
  AuP, AsP, MR, Wundschwelle, TP/KK) rechnen mit den effektiven Werten.
- **Armwunden armgebunden:** rechter Arm = Schwertarm (AT/PA der
  Hauptwaffe im Nahkampf), linker Arm = Schildarm (Nebenhandwaffe,
  Schild-PA). Mit dem Vorteil Linkshänder umgekehrt, über den neuen
  Katalogschalter `linkshaender` (ARCH-02-Muster wie Flink). KK/FF −2
  wirken auf Proben mit Hinweis „nur mit diesem Arm“. Kein FK-Armanteil.
- **Kopf-2W6 nur als Hinweis:** `kopfIniMalus` bleibt gespeichert
  (Format unverändert), senkt aber nicht mehr die INI-Basis.
- **Epische KO** halbiert die SB-Erschwernis beim Unterdrücken, die
  Erschöpfung erscheint halbiert als Hinweis. Die frühere Halbierung der
  Probenabzüge entfällt; ihr Text in `epic_main_attribute_rules.dart` ist
  korrigiert.
- **Dritte Wunde:** nur Kopf, Brust, Rücken und Bauch machen kampfunfähig;
  Arm aktionsunfähig, Bein Sturz und kein Nahkampf, jeweils als Hinweis.
- **Annahmen:** Eine Parierwaffe hat keinen eigenen PA-Wert; die Haupt-PA
  trägt nur den Schwertarm. Beidhändige Helden gelten wie Rechtshänder.
  Die SB-Probe zählt die neuen Wunden bereits mit. Rast-Proben bleiben ohne
  Wundverluste, weil die Rast Wunden im selben Schritt heilt.

Commits:

- `c517f0e` — Linkshänder als Katalogschalter (`adv_linkshaender`,
  `hasLinkshaenderFromVorteile`, Äquivalenztest).
- `7477b8f` — Regeln: `wund_zonen_rules.dart`, `WundEffekte` neu,
  Probenwerte, Armmalus in der Kampfvorschau, GS-Grenze, epische KO,
  Trefferzonen mit Linkshänder, alle Probenaufrufer; Bestandshelden-Werte.
- `786317b` — Oberfläche: Zusammenfassung über
  `wund_anzeige_rules.dart`, Armrollen, Wundmarkierung an Eigenschaftswerten,
  Schritt „Wunden Schwertarm“ in der Waffenrechnung, W20 im Schadensdialog.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests: `wund_zonen_rules_test.dart` (je Zone, Linkshänder, dritte
  Wunde, Unterdrückung und Erschöpfung, SB-Halbierung, Probenwerte,
  GS-Grenze, Anzeige), `wund_arm_kampf_test.dart` (Schwert-/Schildarm,
  Linkshänder, Nebenhand, Fernkampf, Parierwaffe, Ersatzpfad gleich
  Snapshot, keine Wirkung auf abgeleitete Werte, GS ≥ 1),
  `epic_main_attribute_rules_test.dart`, `trefferzonen_rules_test.dart`,
  Äquivalenz- und Parsertests für Linkshänder.
- Bestandshelden (`bestandshelden_regelwerte_test.dart`), von Hand
  hergeleitet: f01 (Armwunde links + Holzschild) AT-/PA-Basis 4 → 6,
  FK-Basis 1 → 5, Kampf-AT/PA 9/8 → 11/10, Ausweichen 0 → 2, Schild-PA 7
  unverändert; neu „f01 mit Linkshänder“ (Kampf-AT/PA 9/8, Schild-PA 9);
  f04 mit Brustwunde FK-Basis 6 → 7, SB-Erschwernis episch 2, sonst 4.
  Neu projiziert: `wundEigenschaften`, `sbErschwernis`, `kampf.schildPa`.
  Fixtures und Hash-Pins sind unverändert.
- Widgettests: `test/ui/workspace/wunden_dialog_test.dart`
  (Zusammenfassung, Armrollen, Linkshänder, SB-Probe gegen Probenwerte ohne
  Startabzug, epische Halbierung, Schnellsuche), Linkshänder-W20 und
  epische Unterdrückung in `schaden_dialog_test.dart`, Wundmarkierung der
  Eigenschaftskarte in `karto_spiel_bruecke_test.dart`.
- Gegenproben: Armanteil pauschal in `atMalus` → 9 Proben scheitern;
  Linkshänder ignoriert → 2; Verluste in `effectiveAttributes` → 12;
  2W6 in der INI-Basis → Kopfprobe; ohne GS-Grenze → 2; ohne Halbierung →
  SB-Regel, f04 und die epische Unterdrückung im Dialog; Textweg ohne Token
  → Äquivalenztest `adv_linkshaender`; SB-Probe bzw. Schnellsuche mit
  effektiven Werten, W20 ohne Linkshänder, Karte ohne Grundwerte → je der
  zugehörige Widgettest.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten, volle Suite grün (3009 bestanden,
  3 übersprungen). Ein Zwischenlauf scheiterte einmal an
  `rules_index_search_io_test.dart`, weil der laufende dsa-rules-MCP-Server
  `index_remote.sqlite` offen hielt; unabhängig von dieser Änderung, der
  nächste Lauf war grün. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und Folgeaufträge.*

1. ~~Die Vorschau des Kampf-Tabs (`hero_combat_tab.dart`,
   `combat_weapons_section.dart`, `combat_weapons_overview_table.dart`)
   rechnet ohne `derivedStats` und damit ohne jede Wunde (Rest von B7).
   `computeCombatPreviewStats` nimmt jetzt `wunden`; die Aufrufer reichen
   sie noch nicht durch. Eigener Folgeauftrag.~~ *Erledigt im Teilstand (7).*
2. Paraden mit einer Parierwaffe werden nicht gesondert gerechnet; ein
   Schildarm-Abzug trifft sie nicht.
3. KK/FF −2 einer Armwunde gelten für alle Proben; ob der Arm beteiligt
   ist, entscheidet der Tisch (Hinweis im Wundendialog).
4. Talent- und Magie-Tab bauen ihre Probenwerte aus eigenen effektiven
   Eigenschaften, die Inventar-, benannte und temporäre Modifikatoren nicht
   kennen (vorbestehend); die Wundverluste kommen jetzt hinzu.
5. Hausregel „mehr als KO×2 TP(A) → 3 Wunden in der Zone“ (S. 3) und der
   Vorteil Schmerzlos (S. 8) sind nicht modelliert; der Wundvorschlag bleibt
   änderbar. Die Obergrenze „Wunden ≤ KO/2, darüber handlungsunfähig“ (BRW
   S. 194) steht nicht im Modell.
6. Der Kopf-INI-Wurf gilt nur im laufenden Kampf; wer die Kampf-INI der
   App nutzt, zieht ihn selbst ab (Hinweis im Wundendialog).

*Nachtrag 30.09.2026 — SB-Erschwernis beim Unterdrücken.* Eine Rückmeldung
hielt es für falsch, dass beim Unterdrücken alle Wunden zählen und nicht nur
die des aktuellen Angriffs. Erneut per dsa-rules-MCP geprüft (keine Errata,
keine Hausregel dazu): WdS S. 83 erschwert die Probe „pro insgesamt
erlittener Wunde um 4 Punkte“, mehrere Wunden aus einem Treffer pauschal
um +8/+12; WdS S. 111 zählt ausdrücklich alle bisherigen Wunden („zwei
Wunden in der Brust … dann eine Wunde im Kopf … Selbstbeherrschungs-Probe
+12“); vor Kampfbeginn gilt „die vierfache Anzahl der Wunden“. **Mit dem
Nutzer entschieden: nach WdS.** Unterdrückte Wunden zählen also mit
(Kampfverlauf: eine Wunde +4, die nächste einzelne +8, zwei aus einem
Treffer +8). Die Rechnung war richtig; geändert ist nur die Anzeige
(`4 × 3 Wunden insgesamt = 12`, Hinweis im Wundendialog) samt Regeltest
für den Kampfverlauf.

**Teilstand 30.09.2026 (7) — Kampf-Tab frisch, Kampfvorschau mit Wunden.**
Das Kampf-Sofortspeichern (Risiko 1 aus Teilstand 5) und Folgeauftrag 1 aus
Teilstand (6) sind umgesetzt. Der Hauptpunkt von ARCH-05 bleibt offen
(Inventareditor, Editorentwürfe).

*Befund.* Im Lesemodus schrieb der Kampf-Tab bei jeder Bedienung den beim
Rendern erfassten Helden samt ganzer Kampfkonfiguration zurück
(`_persistCombatConfigIfReadonly`). Betroffen waren Waffen- und
Nebenhandwahl, Entfernung, Geschosswahl und -bestand, Editorergebnisse,
Entfernen, Talent und BF in der Waffentabelle sowie Rüstungs- und
Nebenhandteile. Folgen:

- Was ein anderer Weg zwischendurch speicherte, ging verloren.
- Schnelle Klicks auf „Geschosse ±“ konnten verloren gehen. Nach dem ersten
  Speichern setzte der Rebuild den Entwurf zurück, obwohl der zweite Klick
  noch ausstand.
- Die Bedienung traf Slots über ihre Position.

Außerdem verschob das Entfernen einer Waffe bzw. eines Nebenhandteils die
Nebenhandzuordnung nicht. Die Nebenhand fiel dann weg oder zeigte auf ein
anderes Teil; das war vorbestehend, nicht erst durch Nebenläufigkeit.
Die Vorschau im Kampf-Tab (Kampfwerte, Waffentabelle, Waffeneditor)
rechnete ohne Basiswerte und damit ohne Wunden.

*Entscheidungen.*

- **Muster aus Teilstand (5):** Die Bedienung läuft über einen Einstieg
  `_aendereKampf`. Im Lesemodus schreibt er frisch über
  `aendereHeldMitMeldung`, im Bearbeitungsmodus ändert er wie bisher nur den
  Entwurf. Die Anzeige folgt dem gespeicherten Wert, der Entwurf wird nicht
  vorab gesetzt. Fehler erscheinen als Snackbar „… nicht gespeichert“, und
  die Auswahlfelder springen auf den gespeicherten Stand zurück.
- **Identität statt Position:** Die Regeln in `kampf_aenderung_rules.dart`
  finden Waffen, Geschosse, Rüstungs- und Nebenhandteile über ihre stabile
  ID (ARCH-03 B2/B3). Ohne ID zählt der Inhalt ohne IDs, weil das Speichern
  benannten Slots erst dabei eine vergibt. Die Sektionen melden dafür den
  angezeigten Slot statt nur seiner Position.
- **Editorergebnisse:** Hat sich der gespeicherte Slot seit dem Öffnen des
  Editors geändert (etwa sein Geschossbestand), wird das Ergebnis
  abgewiesen statt überschrieben, wie bei der Vertrauten-Steigerung. Der
  breite Editor bleibt dann offen.
- **Schritt statt Wert:** Geschossbestände zählen vom gespeicherten Bestand
  (0 bis 9999). Getroffen wird das angezeigte Geschoss, nicht das
  inzwischen gewählte.
- **Nebenbei behoben:** Beim Entfernen rücken aktive Waffe und Nebenhand
  nach. Die toten Controller `combat-main-*` werden nicht mehr nachgeführt.
- **Vorschau:** Der Helfer `kampfvorschau` reicht Modifikatoren, effektive
  Eigenschaften, Basiswerte und Wunden aus `heroComputedProvider` durch.
  Kampf-Tab, Inspector und Spielansicht rechnen damit dieselben Werte. Die
  Sektionen bekommen auch die Hausregel für epische Vorteile, die dort
  bisher immer als aktiv galt.

Commits:

- `923f869` — Regeln `kampf_aenderung_rules.dart` mit Tests.
- `5c8d551` — Kampf-Tab schreibt Sofortänderungen frisch, Widgettests.
- `c15d0a2` — Kampfvorschau mit Wunden.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests (`test/rules/kampf_aenderung_rules_test.dart`, 40 Proben):
  - Suche über ID bzw. Inhalt samt Positionshilfe; nachträglich vergebene
    IDs; geänderte oder entfernte Slots werden gemeldet.
  - Gleicher Held bei „nichts geändert“.
  - Geschossschritt vom gespeicherten Bestand mit Grenzen, getroffen wird
    das angezeigte Geschoss.
  - Ersetzen wird bei geändertem Ausgang abgewiesen.
  - Entfernen verschiebt aktive Waffe und Nebenhand (Waffe und Teil); die
    letzte Waffe bleibt.
  - Unbekannte Felder bleiben erhalten.
- Widgettests (`test/ui/combat/kampf_frisch_schreiben_test.dart`) mit
  `BogenTestRepository`:
  - Waffenwahl nach einer Einfügung davor, die fremde Änderung bleibt.
  - Drei schnelle „Geschosse +“ ab einem fremd gesetzten Bestand.
  - Nebenhandwahl.
  - Speicherfehler samt Zurückspringen der Auswahl.
  - Bearbeitungsmodus schreibt erst mit Speichern.
  - Entfernen mit Nebenhand.
  - BF in der Tabelle.
  - Editorergebnis auf eine geänderte Waffe.
  - Rüstungs- und Nebenhandteil entfernen.
- `test/ui/combat/kampfvorschau_wunden_test.dart`: Kampfwerte (AT, PA,
  Kampf-INI) und Waffentabelle (INI) gleichen mit Bauchwunde dem Snapshot,
  der ohne Wunde höher liegt.
- Gegenproben:
  - Mit dem alten Oberflächencode scheitern 9 von 10 Widgettests; es besteht
    nur der Bearbeitungsmodus, dessen Verhalten gleich bleibt.
  - Ohne Nachrücken der Verweise scheitern drei Regelproben.
  - Ohne Zurücksetzen der Auswahlfelder scheitert der Fehlertest.
  - Mit der alten Vorschau scheitern beide Vorschau-Widgettests.
- Die bestehenden Kampf-Tab- und Rebuild-Tests laufen unverändert.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten. Volle Suite grün (3063 bestanden, 3 übersprungen). Die Hash-Pins der
  Bestandshelden sind unverändert. Eine manuelle Bedienprüfung auf Geräten
  steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. ~~Inventareditor (`_saveEntries`) und alle Editorentwürfe schreiben weiter
   Snapshots, eingereiht. Der Inventareditor ist der nächste Schritt; seine
   Einträge haben keine ID (ARCH-03).~~ *Inventareditor erledigt im
   Teilstand (8); die Editorentwürfe bleiben.*
2. Der Bogen wartet weiter auf seinen Upload. Mit Konto laufen schnelle
   Geschossklicks je Netzweg nach, gehen aber nicht verloren (wie „GS +“).
3. Entfernungsstufen haben keine ID und werden über die Position gewählt.
   Es sind immer genau fünf.
4. Ein Geschoss ohne ID (unbenannt) wird über seinen Inhalt samt Bestand
   gefunden. Ändert ein anderer Weg den Bestand zwischendurch, meldet der
   nächste Klick „inzwischen geändert“, statt falsch zu zählen.
5. ~~Die Slotprüfung (`_validateWeaponSlotsForConfig`) liegt weiter im Widget
   und läuft bei jeder Sofortänderung auf der ganzen Konfiguration. Eine
   bereits gespeicherte ungültige Konfiguration sperrt deshalb alle
   Sofortänderungen, wie bisher.~~ *Erledigt im Teilstand (11).*

**Teilstand 05.10.2026 (8) — Inventareditor frisch.** Risiko 1 aus
Teilstand (7) ist für den Inventareditor umgesetzt. Der Hauptpunkt von
ARCH-05 bleibt offen (Editorentwürfe).

*Befund.* `_saveEntries` schrieb beim Anlegen und Bearbeiten den beim Rendern
erfassten Helden per `saveHero` zurück. Dazu leitete es die ganze
Kampfkonfiguration neu ab. Folgen:

- Was ein anderer Weg zwischendurch speicherte, ging verloren. Besonders
  betroffen waren Geschossbestände aus dem Kampf-Tab:
  `_applyInventoryChangesToCombat` schrieb **alle** Geschossmengen des alten
  Inventars zurück.
- Bearbeiten traf den Eintrag über seine Position. Der breite Editor blieb
  an seiner Position stehen, auch wenn sich die Liste darunter verschob. Sein
  Entwurf landete dann auf einem anderen Gegenstand.
- Ein Editorergebnis auf einen inzwischen geänderten Gegenstand überschrieb
  diesen, statt abgewiesen zu werden.

*Entscheidungen.*

- **Muster aus Teilstand (7):** Ein Eintrag wird über seinen Inhalt
  gefunden, weil Inventareinträge keine ID haben (ARCH-03). Ein
  Editorergebnis auf einen geänderten oder entfernten Gegenstand wird
  abgewiesen (`mitGeaendertemInventarEintrag`). Der Tab merkt sich den
  geöffneten Gegenstand (`_bearbeiteterEintrag`), nicht nur seine Position.
- **Fehler im Editor:** Der neue Einstieg `aendereHeldImEditor`
  (`zustand_aendern.dart`) prüft die Planung wie `aendereHeldMitMeldung`,
  reicht Fehler aber an den Aufrufer weiter. `InventoryItemEditor` zeigt sie
  wie bisher selbst, ohne „Bad state:“, und bleibt offen.
  `aendereHeldMitMeldung` nutzt denselben Einstieg.
- **Kampfabgleich als Regel:** Ein verknüpfter Eintrag gibt seine
  Markierungen an den Slot weiter. Eine im Editor geänderte Geschossmenge
  geht nur an das eigene Geschoss (`slotRef ?? sourceRef`). Ein manueller
  Eintrag lässt den Kampf unberührt. Der Abgleich liegt damit nicht mehr im
  Widget (Befund 6 des Schreibpfad-Inventars, teilweise).
- **Auswahl nach dem Speichern:** über den Inhalt im gespeicherten Helden,
  neue Einträge von hinten (gleiche Gegenstände), verknüpfte notfalls über
  `slotRef`.

Commits:

- `0d692cb` — Regeln `mitNeuemInventarEintrag` und
  `mitGeaendertemInventarEintrag` mit Tests.
- `55bdcc6` — Inventareditor schreibt frisch, Widgettests.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests (`test/rules/inventar_aenderung_rules_test.dart`):
  - Anhängen lässt den Kampf stehen; ein neuer Eintrag ist bei Gleichheit der
    hintere.
  - Ersetzen trifft den Eintrag nach einer Verschiebung; ein geänderter oder
    entfernter Eintrag wird abgewiesen; „nichts geändert“ liefert denselben
    Helden.
  - Ein manueller Eintrag lässt den Kampf unverändert.
  - Die Geschossmenge erreicht nur den eigenen von zwei gleichnamigen Bögen,
    eine abweichende fremde Menge bleibt, eine unveränderte Menge schreibt
    nicht.
  - Markierungen gehen an den Slot; unbekannte Felder bleiben.
- Widgettests (`test/ui/inventory/inventar_frisch_schreiben_test.dart`) mit
  `BogenTestRepository`, schmal und breit:
  - Ein neuer Gegenstand nach einer fremden Kampfänderung lässt diese stehen.
  - Bearbeiten nach einer Einfügung davor trifft den geöffneten Gegenstand.
  - Ein fremd geänderter Gegenstand wird abgewiesen; die Meldung steht im
    breiten Editor, der Entwurf bleibt.
  - Der breite Editor bleibt beim geöffneten Gegenstand, wenn sich die Liste
    sichtbar verschiebt.
  - Eine Geschossmenge erreicht nur ihren eigenen Bogen, fremde Bestände
    bleiben.
  - Ein Speicherfehler bleibt im Editor.
- `test/ui/shared/held_frisch_schreiben_test.dart`: `aendereHeldImEditor`
  reicht die Planungssperre an den Aufrufer weiter und schreibt nichts.
- Gegenprobe: Mit dem alten Oberflächenstand des Inventars scheitern alle
  sechs neuen Editortests; die bestehenden Lösch- und Dukatentests bestehen.
- Die bestehenden Inventar-, Abgleichs- und Frisch-Schreib-Tests laufen
  unverändert.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten. Volle Suite grün (3400 bestanden,
  3 übersprungen). Die Hash-Pins der Bestandshelden sind
  unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. ~~Die Editorentwürfe (Übersicht, Talente, Magie, Begleiter, Notizen,
   Reisebericht, Kampf-Editor) schreiben weiter Snapshots, eingereiht. Sie
   sind der nächste Schritt von ARCH-05.~~ *Erledigt im Teilstand (9).*
2. Zwei inhaltlich gleiche Einträge sind nicht unterscheidbar. Bearbeitet
   wird dann der erste; das Ergebnis ist dasselbe wie beim Löschen.
3. Ein verknüpfter Eintrag, dessen Slot ein anderer Weg zwischendurch
   geändert hat (etwa Geschossbestand), wird abgewiesen. Der Nutzer muss den
   Editor schließen und neu öffnen.
4. Eine nicht als Zahl lesbare Geschossmenge setzt den Bestand wie bisher auf
   0.

**Teilstand 05.10.2026 (9) — Editorentwürfe frisch.** Risiko 1 aus
Teilstand (8) ist umgesetzt: Alle sieben Editorentwürfe speichern frisch.
Damit schreibt kein Bogenschreibweg mehr einen Snapshot. Der Hauptpunkt von
ARCH-05 bleibt offen (benannte Abläufe, Slotprüfung im Widget). Gearbeitet
wurde direkt auf `test`.

*Befund.* Übersicht, Talente, Magie, Begleiter, Notizen, Reisebericht und
Kampf-Editor speicherten `_latestHero.copyWith(<ganze Entwurfsbereiche>)`
per `saveHero`. Folgen:

- Felder außerhalb des Entwurfs kamen aus dem zuletzt gerenderten Helden.
  Was ein anderer Weg gerade gespeichert hatte, ging verloren.
- Entwurfsbereiche wurden immer ganz geschrieben, auch unverändert. Ein
  anderes Gerät, das UI2-Abenteuerblatt oder eine Sofortaktion verloren
  ihre Änderung. Der Notizen-Tab konnte so ein inzwischen abgeschlossenes
  Abenteuer zurücksetzen; ein erneuter Abschluss hätte doppelt gebucht.
- Der Reisebericht rechnete seine Belohnungen gegen die angewendeten
  Belohnungen vom Bearbeitungsbeginn. Was anderswo schon gebucht war, wurde
  noch einmal gebucht.
- Die Übersicht schrieb zusätzlich per `saveHeroState` LeP, AuP, AsP und KaP
  vom Bearbeitungsbeginn zurück. Diese Felder wurden nie angezeigt; es ging
  also nur der Zwischenstand verloren. Wegen der Untergrenze 0 wurden
  negative LeP dabei zu 0.

*Entscheidungen (Konfliktverhalten und Push mit dem Nutzer abgestimmt).*

- **Drei-Wege-Abgleich je JSON-Schlüssel:** `uebernimmEditorEntwurf`
  (`lib/rules/derived/editor_entwurf_rules.dart`) vergleicht drei Stände je
  oberstem Schlüssel von `HeroSheet.toJson()`: die Basis (der Held, aus dem
  der Entwurf gefüllt wurde), den Entwurf und den frisch geladenen Helden.
  - Unverändert im Entwurf: der gespeicherte Wert.
  - Nur im Entwurf geändert (oder beidseitig gleich): der Entwurf.
  - Beidseitig verschieden: Konflikt.

  Appearance und Background liegen dort flach, das ist fein genug. Ein
  fehlender Schlüssel ist ein eigener Wert.
- **Zähler:** AP-Gesamt und ausgegebene AP addieren die Differenz des
  Entwurfs zum gespeicherten Wert. Das deckt die AP-Deltas der
  Erwerbsdialoge und die absoluten AP-Felder der Übersicht ab. Stufe, freie
  AP und Restfragmente rechnet `saveHero` neu.
- **Bisheriges Speichern bleibt:** Hat sich seit der Basis nichts geändert,
  wird der Entwurf unverändert gespeichert, auch ohne eigene Änderung (samt
  Merkmalsmigration). Sonst entsteht der Held über JSON; neue Kampf-Slots
  bekommen vorher eine UUID, weil `fromJson` sonst deterministische IDs
  vergäbe.
- **Konflikt:** `speichereEditorEntwurf`
  (`lib/ui/screens/shared/editor_entwurf_speichern.dart`) fragt nach.
  - „Weiter bearbeiten“ speichert nichts und lässt den Entwurf offen.
  - „Meine Fassung speichern“ gleicht erneut frisch ab und lässt den
    Entwurf nur in den bestätigten Bereichen gewinnen; neue
    Überschneidungen werden erneut erfragt.

  Gespeichert wird über `aendereHeldImEditor`: eingereiht und bei offener
  Planung gesperrt.
- **Buchungen sind nie erzwingbar:** Bei zwei Konflikten bleibt nur „Weiter
  bearbeiten“:
  - auf den Abenteuern, wenn inzwischen eines abgeschlossen oder wieder
    geöffnet wurde;
  - wenn sich die angewendeten Reisebericht-Belohnungen geändert haben.

  Der Reisebericht bucht über `bucheReiseberichtEntwurf` auf den
  gespeicherten Helden; gleichzeitige Talent- und AP-Änderungen bleiben.
- **Basis:** Jeder Tab setzt `_entwurfBasis` dort, wo er seinen Entwurf
  tatsächlich füllt. Nach einer Vertrauten-Steigerung (nur ohne offene
  Änderungen möglich) werden Entwurf und Basis aus dem gespeicherten Helden
  neu gefüllt.
- **Übersicht ohne Laufzeitzustand:** Sie schreibt nur noch den Bogen
  (Befund 3 des Schreibpfad-Inventars entfällt). LeP & Co. pflegen Inspector
  und Ressourcenblatt.
- **Notizen:** Unberührte Listen (dieselben Einträge wie in der Basis)
  bleiben, wie sie gespeichert sind. Die Bereinigung leerer Einträge allein
  ist keine Änderung und überschreibt keine fremde.
- **Nebenbei behoben (Wechselwirkung auf `test`):** Seit ARCH-03 vergibt
  `saveHero` Instanz-IDs an Inventareinträge, der Inventareditor aus
  Teilstand (8) suchte über den vollständigen Inhalt. Nach dem
  Zusammenführen auf `test` hatte das zwei Folgen:
  - Der breite Editor verlor nach dem Speichern seine Auswahl; der
    Widgettest scheiterte schon auf `20eafb1`.
  - Ein vor einem Zwischenspeichern ohne ID angezeigter Eintrag galt beim
    Bearbeiten oder Löschen als „inzwischen geändert“.

  Trägt der gesuchte Eintrag keine ID, zählt sie jetzt auch bei den
  Kandidaten nicht; ein bearbeiteter Eintrag behält seine gespeicherte ID.

Commits:

- `7bc8085` — Regeln `uebernimmEditorEntwurf` und `bucheReiseberichtEntwurf`
  mit Tests.
- `3594bea` — Einstieg `speichereEditorEntwurf` mit Rückfrage; Talente,
  Magie, Begleiter und Kampf-Editor; Widgettests.
- `43b9c81` — Übersicht, Notizen und Reisebericht; Widgettests.
- `33d4406` — Inventarsuche übersieht beim Speichern vergebene Instanz-IDs.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- Regeltests (`test/rules/editor_entwurf_rules_test.dart`, 18 Proben):
  - schneller Weg, getrennte Änderungen, Konflikt samt Schlüssel, gleiche
    Änderung beidseitig;
  - Erzwingen nur bestätigter Schlüssel, neue Konflikte, AP-Zähler;
  - nur bei Belegung geschriebene und geleerte Felder, UUID für neue
    Kampf-Slots, unbekannte Felder beider Seiten;
  - Abenteuerbuchung nicht erzwingbar, Reisebericht auf den frischen Helden
    und nie doppelt.
- `test/ui/shared/editor_entwurf_speichern_test.dart`: fremde Änderung
  bleibt, „Weiter bearbeiten“, „Meine Fassung speichern“, nicht erzwingbare
  Buchung, Planungssperre.
- `test/ui/shared/editor_entwurf_frisch_test.dart` mit
  `BogenTestRepository`:
  - Alle sieben Tabs lassen eine fremde Änderung stehen, auch im eigenen
    Bereich (Notizen: das abgeschlossene Abenteuer bleibt abgeschlossen).
  - Talente mit eigener Änderung: daneben bleibt alles, AP zählen dazu;
    Rückfrage mit beiden Antworten.
  - Die Übersicht lässt negative LeP stehen.
  - Der Reisebericht bucht auf den gespeicherten Helden und Gebuchtes nie
    doppelt; ohne Änderung wird nichts überschrieben.
- Gegenproben: Mit dem alten Oberflächencode scheitern alle 13
  Tab-Widgettests.
- Die bestehenden Tab-, Verwaltungs-, Workspace- und Frisch-Schreib-Tests
  laufen unverändert.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten. Volle Suite grün (3472 bestanden,
  3 übersprungen). Die Hash-Pins der Bestandshelden
  sind unverändert. Eine manuelle Bedienprüfung auf Geräten steht aus.

*Verbleibende Risiken und nächste Schritte.*

1. Ein Abgleich je oberstem Schlüssel ist grob. Ändern Entwurf und ein
   anderer Weg verschiedene Einträge derselben Liste (zwei Abenteuer, zwei
   Waffen), entsteht eine Rückfrage statt einer Zusammenführung. Ein
   Abgleich je Eintrags-ID wäre der nächste Schritt, sobald er gebraucht
   wird.
2. Normalisierungen beim Speichern zählen als Entwurfsänderung, wenn sie
   etwas ändern: fehlende Startwerte eines Vertrauten, die alte
   Vertrautenmagie am Helden. Eine Rückfrage folgt daraus nur, wenn ein
   anderer Weg denselben Bereich gleichzeitig ändert.
3. „Meine Fassung speichern“ kann eine fremde Vertrauten-Steigerung
   zurücknehmen; die AP bleiben dann ausgegeben. Nur Abenteuer und
   Reisebericht sind als Buchungen geschützt.
4. Wählt der Nutzer beim Verlassen „Speichern“ und dann „Weiter
   bearbeiten“, meldet die Verwaltung wie bisher „weiterhin als
   ungespeichert markiert“.
5. ~~Randbefund, nicht behoben: Das Zurücknehmen eines Reisebericht-Hakens
   entfernt nur die Kennung aus den angewendeten Belohnungen.
   `revokeReiseberichtRewards` wird nirgends aufgerufen; AP und Boni
   bleiben also. Vor einer Behebung fachlich klären.~~ *Mit dem Nutzer
   geklärt und behoben im Nachtrag unten: Enthaken nimmt die Belohnungen
   zurück.*
6. Talente- und Kampf-Editor warten beim Speichern weiter mit
   `rulesCatalogProvider.future` (Befund 2 des Schreibpfad-Inventars).

*Nachtrag 05.10.2026 — Reisebericht: Enthaken nimmt zurück.* Vom Nutzer
entschieden: Wer einen Haken entfernt, verliert die daraus gebuchten
Belohnungen wieder.

*Befund.* Die Rücknahme entfernte nur die Kennung aus den angewendeten
Belohnungen; AP, SE, Talent- und Eigenschaftsboni blieben gebucht.
`computeRevocationRewards` kannte nur Checkpoints, Mehrfach-Anforderungen
und Gruppenstufen. Teilanforderungen und Sammlungseinträge ließen sich
nach dem Buchen gar nicht enthaken; der Dialog fand ihren Katalogeintrag
nicht. Gelöschte offene Einträge wurden ebenfalls nie zurückgebucht.

*Umsetzung.*

- **Eine Quelle für Buchen und Zurücknehmen:** `reisebericht_rules.dart`
  zählt alle buchbaren Posten des Katalogs auf: ID, Inhalt (AP, SE,
  Talent- und Eigenschaftsboni) und ob ihre Bedingung erfüllt ist.
  `computePendingRewards` bucht wie bisher erfüllte, noch nicht angewendete
  Posten; die bestehenden Tests laufen unverändert.
- **Abgleich:** `berechneReiseberichtBuchung` vergleicht den Entwurf mit dem
  gebuchten Stand.
  - Zurückgenommen wird jeder angewendete Posten, der dort erfüllt war und
    im Entwurf nicht mehr ist. Das gilt auch für abhängige Belohnungen:
    Sammlungsschwelle und -bonus, Gruppenbonus, Meta-Eintrag samt
    Eigenschaftsbonus.
  - Ändert sich der Inhalt eines angewendeten Postens (gewählte SE, AP
    eines offenen Eintrags nach dem Löschen eines davor), wird
    umgebucht.
  - Was schon vorher angewendet und nicht mehr erfüllt war (Altdaten aus
    der bisherigen Rücknahme), bleibt unangetastet. Unbekannte angewendete
    IDs bleiben ebenso.
- **Buchen:** `bucheReisebericht` nimmt erst zurück und bucht dann neu;
  `bucheReiseberichtEntwurf` tut das auf dem frisch geladenen Helden.
  `computeRevocationRewards` entfällt.
- **Tab:** Entfernt das Enthaken oder das Löschen eines offenen Eintrags
  Gebuchtes, fragt „Belohnungen zurücknehmen?“ nach und zeigt Rücknahmen
  und Umbuchungen (`reiseberichtBuchungsaenderung`). Gebucht wird erst
  beim Speichern; die Meldung nennt Zu- und Abgänge.

*Prüfungen.*

- Regeltests (`test/rules/reisebericht_rules_test.dart`):
  - Checkpoint, Schwelle samt Talentbonus, Teilanforderung,
    Gruppenbonus, Meta mit Eigenschaftsbonus;
  - Umbuchung beim Löschen eines offenen Eintrags;
  - Altdaten bleiben, erneutes Abhaken hebt die Rücknahme auf;
  - nur die zusätzliche Wirkung einer Änderung;
  - Rücknehmen und Buchen am Helden mit fremder ID.
- `test/rules/editor_entwurf_rules_test.dart`: Enthaken auf dem
  gespeicherten Helden.
- `test/ui/shared/editor_entwurf_frisch_test.dart`: Rückfrage,
  Zurücknehmen samt Speichern, Abbrechen.
- Gegenprobe: Mit dem bisherigen Code scheitert der Rücknahmetest im Tab.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Zeilenbudget eingehalten. Volle Suite grün (3483 bestanden,
  3 übersprungen).

*Risiken.*

1. Zurückgenommen wird mit dem heutigen Katalog. Hat sich der Wert eines
   Postens seit dem Buchen geändert, wird der neue abgezogen.
2. Eine zurückgenommene SE wird abgezogen, auch wenn sie schon für eine
   Steigerung verwendet wurde (nicht unter 0). AP gesamt fallen nicht unter
   0, freie AP können negativ werden.

**Teilstand 05.10.2026 (10) — Steigerungsrunde übernehmen als Ablauf.**
Der erste benannte Ablauf am Bogen. Der Hauptpunkt von ARCH-05 bleibt
offen („Held importieren“, Slotprüfung im Widget). Gearbeitet wurde direkt
auf `test`.

*Befund.* `AdvancementSessionController` (`state/advancement_providers.dart`)
lud, prüfte und speicherte selbst; prüfbar war das nur mit einem
`ProviderContainer`. Die Anzeige nicht passender SF
(`setShowInapplicableSpecialAbilities`) schrieb als einziger Bogenweg des
Controllers direkt ins Repository und an der Bogen-Warteschlange vorbei. Sie
konnte so eine laufende frische Änderung überholen; eine der beiden ging
verloren (Restrisiko 4 aus Teilstand (5)).

*Umsetzung.*

- **Ablauf:** `SteigerungsrundeUebernehmen`
  (`lib/ablaeufe/steigerungsrunde_uebernehmen.dart`), ohne Riverpod und
  Flutter, Abhängigkeiten per Konstruktor: `HeroRepository` und
  `SteigerungSpeichern`, das genau dem Tear-off `HeroActions.saveHero`
  entspricht. Die Normalisierung bleibt damit in `HeroActions`; dort ändert
  sich nichts. Provider: `steigerungsrundeUebernehmenProvider` in
  `lib/state/ablauf_providers.dart`.
- **`uebernehmeRunde`:** dieselbe Logik wie bisher `commit()` — frisch
  laden, geschlossene Runde melden, Hash gegen die Sitzungsbasis,
  `commitAdvancements`, speichern mit `expectedContentHash` und dem Katalog
  der Runde. Die zweite Prüfung in `saveHero` bleibt nötig: Der Konto-Sync
  schreibt Online-Stände an der Warteschlange vorbei. Weil `speichere` sich
  selbst einreiht, ruft der Ablauf es nie aus einem eingereihten Vorgang auf.
  Meldungen sind unverändert.
- **`speichereSfAnzeige`:** wie bisher frisch, ohne Normalisierung und bei
  offener Runde nur auf unveränderter Basis — **neu eingereiht**
  (`reiheBogenvorgangEin`). Das ist die einzige Verhaltensänderung.
- **Controller:** behält Planung, `canCommit`, `isSaving`, Wiederherstellen
  bei Fehler und das Leeren nach Erfolg. Ob die Runde inzwischen geschlossen
  wurde, meldet er dem Ablauf über `istGeschlossen`.

Commits:

- `b3eef18` — Ablauf, Provider, Controller und Tests.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- `test/ablaeufe/steigerungsrunde_uebernehmen_test.dart` (10 Proben, ohne
  Riverpod): gemeinsame Buchung samt Hash und Katalog an `speichere`,
  Zwischenänderung, fehlender Held, geschlossene Runde, ungültiger Eintrag,
  durchgereichter Speicherfehler; SF-Anzeige nur als Präferenz auf dem
  frischen Helden, Basisprüfung, fehlender Held und geschlossene Runde,
  Einreihung hinter eine laufende Bogenänderung.
- Gegenprobe: Ohne Warteschlange scheitert der Einreihungstest (die
  Anzeige überholt die laufende Änderung).
- `test/state/advancement_session_test.dart` (13 Fälle) läuft unverändert,
  ebenso `test/ablaeufe/` samt Abhängigkeitswächter, die UI2-Entwicklung, die
  Workspace-Journey und `bestandsheld_ablauf_test.dart`.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung
  (1018 Dateien). Volle Suite grün (3497 bestanden,
  3 übersprungen). Kein Modell geändert, die
  Hash-Pins der Bestandshelden sind unverändert.

*Risiken und nächster Schritt.*

1. Die erste Prüfung läuft wie bisher außerhalb der Warteschlange. Ist
   beim Übernehmen noch eine Bogenänderung eingereiht, scheitert die Runde
   erst an der zweiten Prüfung, mit der Meldung aus `saveHero`.
2. ~~Nächster Schritt: „Held importieren“ (`importHeroBundle`: eigener
   Katalog, bis zu drei `saveHero`, Zustand, Galeriedateien) als Ablauf;
   danach die Slotprüfung des Kampf-Tabs aus dem Widget.~~ *Erledigt im
   Teilstand (11).*

**Teilstand 07.10.2026 (11) — „Held importieren“ als Ablauf, Slotprüfung
als Regel.** Beide offenen Punkte aus Teilstand (10) sind umgesetzt.
Gearbeitet wurde direkt auf `test`.

*Entscheidungen (Dennis, 7.10.2026).*

- Bilder, die sich beim Import nicht speichern lassen, brechen den Import
  nicht ab. Der Held wird ohne sie importiert, die Oberfläche nennt ihre
  Zahl.
- Sofortänderungen im Kampf-Tab weisen nur Fehler ab, die sie neu
  einführen. „Speichern“ im Editor prüft weiter alles.

*Befunde im bisherigen Import* (`HeroActions.importHeroBundle`). Keiner war
eigens getestet, es gab überhaupt keinen Bildtest beim Import.

1. **Falsche Dateinamen.** Die Ablage legt Galeriebilder als
   `{heroId}_{entryId}.png` ab. Der Import verwarf den zurückgegebenen Namen
   und behielt den aus dem Export. Bei „Als neu erstellen“ zeigte die Kopie
   damit auf die Datei des Originals; Löschen des Bildes in der Kopie
   entfernte es beim Original. Legacy-Einträge (`{id}_legacy` →
   `{id}.png`) zeigten auf eine nie geschriebene Datei.
2. Ein leerer Dateiname (Web ohne Anmeldung) wurde nicht geprüft.
3. Das aktive Bild steht im Export doppelt (Galerie und `avatarBase64` für
   alte Importer). Der Import legte es zusätzlich als Legacy-Hauptbild ab,
   obwohl `avatarFileName` nicht mehr gelesen wird. Das ergab eine
   verwaiste Datei und einen zweiten Upload.
4. Das Heldenlimit galt nur für „Als neu erstellen“. Ein Held mit noch
   unbekannter ID kommt als `overwriteExisting` an und umging es.
5. Bis zu drei `saveHero`. Scheiterte ein Bild, war der Held schon
   gespeichert, und der Import brach mit einer Fehlermeldung ab.

*Umsetzung.*

- **Ablauf** `HeldImportieren` (`lib/ablaeufe/held_importieren.dart`),
  ohne Riverpod. Katalog und Bildablage kommen als Funktionen herein, denn
  der Wächter erlaubt aus `data/` nur `HeroRepository`. Reihenfolge:
  1. Limit für jede unbekannte Ziel-ID,
  2. Katalog,
  3. Bilder mit dem Namen aus der Ablage,
  4. **ein** `saveHero`,
  5. Zustand über `aendereGespeichertenZustand` (eingereiht und
     gestempelt, bisher ein Snapshot über `saveHeroState`).
- **Bilder ohne Ablage.** Unter derselben ID bleibt der bisherige Verweis
  stehen; seine Datei liegt womöglich schon im Speicher bzw. in der Cloud
  des Kontos. Unter einer neuen ID fällt der Eintrag weg und wird gezählt.
  Verweise auf entfallene Einträge (aktiv, primär, Schnappschuss) werden
  bereinigt, wie bei `removeGalleryImage`.
- **Anbindung.** `HeroActions.importiereHeld` baut den Ablauf inline wie
  `updateHero`. Ein Provider in `ablauf_providers.dart` hätte einen
  Importzyklus über `heroActionsProvider` erzeugt. `importHeroBundle`
  bleibt Kompatibilitätseinstieg. Die Startseite meldet fehlende Bilder
  über `importMeldung`.
- **Slotprüfung.** `pruefeKampfSlots`
  (`lib/rules/derived/kampf_slot_pruefung_rules.dart`) liefert alle Befunde
  mit Slotbezug (ID, ersatzweise Position, `nebenhand`) und Art.
  `neuerKampfSlotFehler` vergleicht über beides, nicht über den Text, damit
  Umsortieren keinen Scheinfehler erzeugt. Die Talent- und
  Waffenartauflösung zieht mit; `combat_helpers.dart` re-exportiert sie.

Commits:

- `2513698` — Ablauf, Anbindung, Meldung, Tests.
- `23844d3` — Slotprüfung als Regel, Kampf-Tab, Tests.
- Abschluss-Commit mit Dokumentation.

*Prüfungen.*

- `test/ablaeufe/held_importieren_test.dart` (12 Proben, ohne Riverpod):
  - ID behalten bzw. neu vergeben;
  - Limit für beide Auflösungen, kein Limit beim Überschreiben;
  - Katalog vor dem Helden;
  - genau ein Speichern;
  - Dateinamen aus der Ablage, doppeltes Hauptbild nicht abgelegt;
  - scheiterndes Bild und leerer Name unter neuer und gleicher ID;
  - Einträge ohne Bilddaten;
  - alter Export mit Legacy-Eintrag;
  - Speicherfehler ohne Zustand.

  Gegenprobe mit dem Namen aus dem Export: Die Probe für die neue ID
  scheitert.
- `test/rules/kampf_slot_pruefung_rules_test.dart` (17 Proben):
  - jede bisherige Meldung;
  - mehrere Befunde in Reihenfolge;
  - bestehender Fehler erlaubt, neuer Fehler und neue Art gemeldet;
  - Umsortieren erzeugt keinen Fehler.
- `kampf_frisch_schreiben_test.dart`: Eine gespeicherte ungültige Waffe
  sperrt die Waffenwahl nicht mehr. Eine Parierwaffe ohne Linkhand wird mit
  „Nebenhand nicht gespeichert: …“ abgewiesen. Gegenprobe mit der alten
  Gesamtprüfung: Beide Proben scheitern.
- `test/ui/workspace/import_meldung_test.dart` prüft den Meldungstext.
- `bestandsheld_ablauf_test.dart`: Die Kopie eines Exports ohne Bilddaten
  trägt keinen Galerieeintrag und keinen Schnappschuss mehr. Ihre
  Zukunftsfelder an diesen Stellen sind deshalb von der Prüfung
  ausgenommen, alle übrigen bleiben erhalten. Die Hash-Pins sind
  unverändert, kein Modell geändert.
- `flutter analyze --no-pub` ohne Befund, `dart format` ohne Änderung,
  Screen-LOC-Prüfung besteht. Vollständige Suite
  (`--concurrency=1`, eigener `DSA_MCP_DATA_DIR`): 3.807 bestanden,
  3 bestehende übersprungen.

*Verbleibende Risiken.*

1. ~~Scheitert das Speichern des Helden nach dem Ablegen der Bilder, bleiben
   die Bilddateien verwaist (auch in der Cloud). Ein Aufräumen gehört zu
   ARCH-06 (Wiederanlauf).~~ *Behoben in ARCH-06 Teilstand 1:*
   Vorgangsjournal und Wiederanlauf löschen sie.
2. Beim Überschreiben bleiben Dateien des vorigen Stands liegen, die der
   Import nicht mehr referenziert (wie bisher).
3. Der Katalog wird vor dem Helden übernommen. Die Merkmalsmigration beim
   Speichern sieht den neu geladenen Katalog nicht immer (ARCH-02,
   Risiko 2, unverändert).

**Abschluss 07.10.2026 — Abnahme ARCH-05.** Geprüft gegen die
Abnahmekriterien:

- *Abläufe ohne gerenderte Oberfläche prüfbar:* Rast, Schaden,
  Steigerungsrunde, Held importieren und die Bausteine zum frischen
  Schreiben von Bogen und Zustand laufen unter `test/ablaeufe/` ohne
  Widget und ohne Riverpod; der Wächter hält die Abhängigkeiten fest.
- *Normalisierung und Validierung mit klarer Zuständigkeit:* Normalisiert
  wird nur in `HeroActions._speichereNormalisiert`, das `saveHero`,
  `updateHero` und die Abläufe als `speichere` nutzen. Geprüft wird in
  `rules/derived/` (Kampfslots, Talentverteilung, Steigerungen,
  Editorabgleich).
- *Keine neu duplizierten Regelberechnungen in Widgets und Providern:* Die
  letzte Prüfung im Widget (Kampfslots) ist eine Regel.
- *Fehler erreichen die aufrufende Oberfläche:* Abläufe fangen nichts. Die
  Oberfläche zeigt Fehler im Blatt, Dialog oder `ZustandFehlerBereich`.
  Teilfehler beim Import (Bilder) werden ausdrücklich gemeldet.

*Abgrenzung.*

- „Ausrüstung wechseln“ aus dem Ziel ist keine eigene Klasse geworden. Es
  läuft als frische Kampfänderung über `aendereHeldMitMeldung` und
  `kampf_aenderung_rules.dart`; eine weitere Schicht brächte keinen
  Nutzen.
- Avatar- und Gruppenoperationen bleiben schmale Methoden in
  `HeroActions`.
- Die Aufteilung von `SyncingHeroRepository` gehört zu ARCH-06.
