# Anwendungsabläufe und frisches Schreiben (ARCH-05/06)

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Fachlich benannte Anwendungsablaeufe (ARCH-05) liegen in `lib/ablaeufe/`:
  ohne Riverpod und Flutter, Abhaengigkeiten per Konstruktor, aus `data/`
  nur die `HeroRepository`-Schnittstelle — der Waechter
  `test/ablaeufe/abhaengigkeiten_test.dart` prueft das. Provider dazu stehen
  in `lib/state/ablauf_providers.dart`. Muster: frisch laden → Regel aus
  `rules/derived/` → stempeln → speichern (`aendereGespeichertenZustand`,
  an das auch `HeroActions.updateHeroState` delegiert). Ablaeufe fangen
  Fehler nicht, die aufrufende Oberflaeche zeigt sie. Bestandsaufnahme aller
  Schreibwege: `docs/schreibpfade_inventar.md`.
- Speichervertrag (ARCH-06, `docs/schreibpfade_inventar.md`): Jeder Ablauf
  schreibt genau ein Dokument, ausser dem Import. Der Import vermerkt sich im
  `Vorgangsjournal` (`lib/data/vorgangsjournal.dart`, Box `vorgaenge_v1`,
  `vorgangsjournalProvider`). `VorgaengeWiederaufnehmen` fuehrt ihn beim Start
  vor `syncNow` zu Ende oder gleicht ihn aus; dasselbe passiert sofort, wenn
  ein Importschritt scheitert. Ein neuer Ablauf mit mehreren Schreibvorgaengen
  braucht dasselbe. Der Sync bleibt dokumentbasiert: ausstehend ist, was vom
  gemerkten Hash abweicht; es gibt keine Operations-Warteschlange.
- `aendereGespeichertenZustand` reiht Aenderungen je Speicher und Held ein
  (Warteschlange per `Expando` am Repository); zwei nicht abgewartete Aufrufe
  ueberschreiben einander so nicht. Laufzeitwerte werden in der Oberflaeche
  **nie** als beim Rendern erfasster Gesamtzustand geschrieben
  (`saveHeroState` bleibt Editor, Anlegen und Import vorbehalten), sondern
  ueber `aendereZustandMitMeldung` (`lib/ui/screens/shared/zustand_aendern.dart`):
  frisch laden, nur die eigenen Felder ersetzen. Fehler erscheinen im
  naechsten `ZustandFehlerBereich` an der `ZustandFehlerAnzeige` (Blatt,
  Dialog, Inspector-Tab, UI2-Zustandsblock) — eine Snackbar laege hinter dem
  Blatt, auf iOS/macOS verdeckt; sie ist nur Rueckfall. Wunden laufen
  darueber in `wund_zustand_speichern.dart`, Zaubereffekte ueber
  `rules/derived/active_spell_state_rules.dart`. Bedienung zaehlt **immer**
  vom gespeicherten Wert, damit jeder schnelle Klick zaehlt: Ressourcenknoepfe
  melden eine `RessourcenAenderung` (`rules/derived/ressourcen_aenderung_rules.dart`,
  Schritt mit Grenzen nur in Schrittrichtung oder Setzen), nie einen
  fertigen Wert. `test/ui/shared/zustand_frisch_schreiben_test.dart` prueft
  jeden Weg gegen eine Zwischenaenderung und schnelle Klicks.
- Fuer den **Bogen** gilt dasselbe: `aendereGespeichertenHelden`
  (`lib/ablaeufe/held_schreiben.dart`) laedt frisch, aendert und speichert
  ueber die injizierte Normalisierung; `HeroActions.updateHero` delegiert
  daran und liefert den gespeicherten Helden. Auch `saveHero` reiht sich
  (`reiheBogenvorgangEin`, eigene Warteschlange neben der des Zustands,
  Baustein `reihenfolge_je_held.dart`) ein und liefert den normalisierten
  Helden; so landet ein Editorentwurf nie zwischen Laden und Schreiben einer
  frischen Aenderung, und die Hash-Pruefung der Steigerungsrunde sieht jede
  eingereihte Aenderung. Eine Aenderung darf **nie** selbst `saveHero` oder
  `updateHero` aufrufen — sie wartete auf sich selbst. Gibt sie dasselbe
  Objekt zurueck, wird nichts gespeichert. Sofortaktionen am Bogen
  (Inspector-Statuswerte, Wundschwelle, Uebersicht, Inventar-Loeschen und
  Dukaten, Abenteuerabschluss, Vertrauten-Steigerung) laufen ueber
  `aendereHeldMitMeldung` (neben `aendereZustandMitMeldung`): nur die eigenen
  Felder, Schritte vom gespeicherten Wert, Regeln aus `rules/derived/`
  (u. a. `modifikator_aenderung_rules.dart`, `epic_status_rules.dart`,
  `inventar_aenderung_rules.dart`, `begleiter_aenderung_rules.dart`). Bei
  offener Steigerungsrunde schreibt der Einstieg nicht; Statuswerte und
  Wundschwellen-Zahnrad sind dann sichtbar gesperrt. Das Sofortspeichern
  des Kampf-Tabs laeuft ueber einen Einstieg `_aendereKampf`
  (`hero_combat/combat_state_helpers.dart`, Regeln in
  `kampf_aenderung_rules.dart`): Slots werden ueber ihre ID getroffen, nie
  ueber die Position, und die Sektionen melden den **angezeigten** Slot;
  ein Editorergebnis auf einen inzwischen geaenderten Slot wird abgewiesen.
  Der Inventareditor schreibt ueber `aendereHeldImEditor` (Fehler zeigt
  der Editor selbst) und `inventar_aenderung_rules.dart`: Er trifft den
  geoeffneten Gegenstand ueber seinen Inhalt, nie ueber die Position, und
  schreibt in den Kampf nur dessen eigene Geschossmenge; eine beim Speichern
  vergebene Instanz-ID zaehlt dabei nicht als Aenderung.
  Editorentwuerfe speichern ueber `speichereEditorEntwurf`
  (`shared/editor_entwurf_speichern.dart`): Jeder Tab merkt sich in
  `_entwurfBasis` den Helden, aus dem er den Entwurf gefuellt hat, und baut
  den Entwurf auf dieser Basis. `uebernimmEditorEntwurf`
  (`rules/derived/editor_entwurf_rules.dart`) gleicht Basis, Entwurf und
  frischen Helden je oberstem JSON-Schluessel ab, AP sind Zaehler.
  Beidseitig verschieden Geaendertes fragt nach („Weiter bearbeiten“ /
  „Meine Fassung speichern“); Erzwingen nimmt nie eine fremde Buchung
  (Abenteuerabschluss, Reisebericht-Belohnungen) zurueck. Uebernimmt ein Entwurf
  waehrend der Bearbeitung frisch Gespeichertes, rueckt auch die Basis nach.
  Kein Bogenschreibweg schreibt mehr einen Snapshot. Pruefung:
  `test/ui/shared/held_frisch_schreiben_test.dart`,
  `test/ui/shared/editor_entwurf_frisch_test.dart` und Geschwister mit
  `test/test_support/bogen_test_repository.dart`.
- Mit Konto endet `SyncingHeroRepository.saveHeroState` nach dem **lokalen**
  Speichern; `GebuendelteLaeufe` (`lib/data/sync/gebuendelte_laeufe.dart`)
  laedt je Held im Hintergrund hoch, nie zwei gleichzeitig, immer den
  neuesten Stand. Parallele Uploads auf derselben Basisrevision meldeten
  sonst Konflikte mit sich selbst. Online-Staende, die waehrenddessen
  eintreffen (auch das eigene Echo), werden erst nach dem Upload bewertet;
  `syncNow` wartet vorher auf laufende Uploads. Tests, die danach die Cloud
  pruefen oder die Leitung umschalten, warten mit `warteAufUebertragungen()`
  (`test/data/zustand_schnell_tippen_sync_test.dart`).
