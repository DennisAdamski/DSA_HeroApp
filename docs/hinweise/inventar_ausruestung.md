# Inventar, Ausrüstung, Artefakte und Tränke

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Verknuepfte Kampf-/Inventareintraege tragen stabile Slot-IDs in
  `lib/domain/combat_config/`; das Verweisformat und die Migration liegen in
  `inventar_verweise.dart`. `HeroSheet.fromJson` vergibt fuer Altdaten
  deterministische IDs, `HeroActions.saveHero` fuer neue Slots UUIDs.
  Ein Inventareintrag traegt **zwei** Verweise: `sourceRef` bleibt der
  Namensverweis (`w:Name` …), weil die bereits veroeffentlichte App nur ihn
  versteht. Mit einem ID-Verweis dort verwarf ihr Abgleich alle verknuepften
  Inventardaten. Den ID-Verweis (`w#id` …) traegt `slotRef`. Zugeordnet wird
  ueber Instanz und `slotRef`; ueber den Namen ordnet nur noch das Laden
  Altdaten zu (`migriereInventarVerweise`), und die Reihenfolge „manuell,
  dann Slot-Reihenfolge“ bleibt. Geschossmengen
  immer mit `slotRef ?? sourceRef` zurueckschreiben. `inventory_sync_rules.dart`
  gleicht weiterhin beide Darstellungen ab. Das ist der B2/B3-Teilfix, noch
  nicht das gemeinsame Gegenstandsmodell aus ARCH-03. Menge und Stapel
  (`inventar_menge_rules.dart`, `inventar_stapel_rules.dart`): `menge` führt,
  `anzahl` ist ihr Text, beide nur über `mitInventarMenge` schreiben.
  Weicht ein ganzzahliges `anzahl` ab, gilt es; das wird nie still
  aufgelöst. `saveHero` überführt reine Zahlen, der Abgleich vergibt keine
  Menge (Fixpunkt). Inventarwege treffen Einträge über `instanzId`
  (`findeInventarEintragZurAenderung`). Slots verweisen zurueck: Waffe,
  Geschoss, Ruestungs- und Nebenhandteil tragen `inventarInstanzId`, nur in
  `saveHero` gesetzt (`bindeSlotsAnInstanzen`); der Abgleich paart zuerst
  ueber sie. Der Verweis ist abgeleitet: Inhaltsvergleiche und
  Gefechts-Fingerabdruecke lassen ihn weg (`ohneInstanzverweise`).
  Entfernen im Kampf-Tab fragt „Nur ablegen“/„Ganz entfernen“
  (`kampfgegenstand_ablegen_rules.dart`): abgelegt bleibt das Exemplar als
  manueller Eintrag mit `abgelegt` (gemerkte Kampfwerte), „In Kampfbereich
  übernehmen“ holt es zurück; Geschosse gehen nie still verloren.
  Zusammenführen gleicher Stapel liegt in `inventar_stapel_rules.dart`,
  Verkaufen (Erlös auf den Geldstand) in `inventar_verkauf_rules.dart`;
  `gewichtGramm`/`wertSilber` gelten pro Stück (`inventar_summen_rules.dart`).
  Verknüpfte Waffen/Nebenhandteile gelten nur in der Hand als ausgerüstet
  (Abgleich setzt `istAusgeruestet`), nur dann wirken ihre Modifikatoren. Formataenderungen
  aendern Inhalts-Hashes; Bestandsfixtures und Hash-Pins nur gemeinsam mit
  ihnen aktualisieren. Den Mischbetrieb bildet
  `test/test_support/veroeffentlichte_app.dart` nach.
- **Artefakte im Inventar** (Matrixgeber und Spruchspeicher, Stand 11. Oktober 2026): `HeroInventoryEntry.artefaktDaten` (`lib/domain/artefakt_daten.dart`, nur bei Belegung im JSON) haelt Stabilitaet, Regelfassung und die eingesprochenen Zauber samt Repraesentation, ZfW und ZfP* des Sprechers — nie vom Traeger. Ein Matrixgeber hat **keine Zauberprobe**: `MatrixAusloesen` (`lib/ablaeufe/matrix_ausloesen.dart`) bucht nur die AsP des Traegers und einen Protokolleintrag (ein Dokument); der Stabilitaetswurf liegt in `rules/derived/artefakt_matrix_rules.dart` (WdA 2012 oder Staebe/Ringe 2011, einstellbar am Gegenstand). Die Beschaedigung vermerkt der Nutzer ausdruecklich am Bogen. Das Gefechtsinventar oeffnet den Dialog ueber `KartoGefechtsAdapter.gefechtsMatrixAusloesen`, der Wirkdialog mit Repraesentationspflicht bleibt Zauberern vorbehalten. Die Zauber eines Matrixgebers stehen im Magie-Tab als Abschnitt „Zauber aus Artefakten“ (der Tab erscheint auch ohne Zauberkunde, sobald ein Artefakt im Inventar liegt) und, sofern der Gegenstand ausgeruestet ist, als eigener Punkt „Artefakte“ direkt unter „Geführte Ausrüstung“ im Gefecht (`artefakt_zauber_liste_rules.dart`, `gefecht_ansicht_teile.dart`). **Spruchspeicher** (einmalig/aufladbar) tragen `ladungen` (`ArtefaktLadung`, stabile `id`, gemeinsam ausgeloeste Zauber, `verbraucht`), `aufladungen` und `gesamtAspErschaffung`: Sie kosten keine AsP und haben keine Probe, die Sofortaktion (Ladung verbrauchen, aufladen, Defekt) ist **ein** Bogendokument ueber `aendereHeldImEditor` und `artefakt_ladung_aenderung_rules.dart`; das Protokoll folgt als eigene Buchung (`ArtefaktProtokollieren`). Der Schadenswurf beim Aufladen haengt von der Regelfassung ab (WdA 2012: nur die 20, jede Aufladung +1; 2011: 19–20). Der Dispatcher `zeigeArtefaktAnwenden` waehlt den Dialog nach Art; `KartoGefechtsAdapter.gefechtsMatrixAusloesen` behaelt Namen und Signatur. **Semipermanente** Speicher fuehren die flache `zauber`-Liste, `intervall`, `anwendungenProIntervall` und die vermerkten `anwendungen` (aventurische Daten); `artefakt_intervall_rules.dart` rechnet gegen `resolveCurrentAdventureDate` des gespeicherten Helden (Tag 1, Woche 7, Monat 30, Jahr 365 Tage), zeigt nur an und sperrt nie; ohne Datum wird eine Anwendung ohne Datum vermerkt, die nur „Matrizen regeneriert“ loescht. Der **Zaubertalisman** (Auxiliator) laeuft nicht ueber den Wirkdialog: Der Anwender spricht den Zauber ueber den unveraenderten Standardweg (Gefecht-Wirkdialog, Magie-Tab-Probe); danach bietet der Wirkabschluss („Auxiliator einsetzen“, `KartoGefechtsAdapter.gefechtsAuxiliator`) bzw. der Magie-Tab einen eigenen Schritt. `AuxiliatorEinsetzen` bucht AsP (Zauberkosten + 1W3, im Gefecht nur die 1W3, weil der Abschluss die Zauberkosten bucht) und Protokoll in **einem** Zustandsdokument; Bonus und Ausfallwurf rechnet `artefakt_auxiliator_rules.dart`, die Beschaedigung vermerkt der Nutzer ausdruecklich. Ein **permanenter Spruchspeicher** (`spruchspeicherPermanent`, Aeternom, INFINITUM; Staebe/Ringe S. 8) wirkt staendig: flache `zauber`-Liste, keine Ladungen, kein Intervall, keine AsP; `artefaktAusloesbar` ist fuer ihn immer `false` (kein Ausloesen im Inventar, kein Punkt im Gefecht), der Magie-Tab zeigt „dauerhaft wirksam“. Die pAsP traegt der Nutzer ein (WdA S. 87 nennt dafuer keinen Teiler); eine Wirkung auf Heldenwerte wird nicht gerechnet. APPLICATUS (entlaedt sich am naechsten Sonnenaufgang automatisch auf den Ausloeser), Kraftspeicher und magische Waffen sind noch nicht modelliert.
- **Tränke und Heilmittel aus dem Katalog** (TRANK, Teilstand 1,
  15. Oktober 2026): `alchimika.json` (Manifest-Schlüssel `alchimika`,
  `AlchimikumDef`, `RulesCatalog.alchimika`, unverschlüsselt, jedes Mittel mit
  Beleg) füllt über „Aus Katalog: Tränke & Heilmittel“ im Inventareditor
  (`mitAlchimikum`, `rules/derived/alchimika_rules.dart`) einen Eintrag samt
  `Vitalwirkung` vor. Deren Würfelausdrücke (`lepWurf` …) und `lepProWunde`
  sind **nur Hinweise** im Dialog „Anwenden“; die Zahlenfelder bleiben leer,
  gewürfelt und gebucht wird nie automatisch. Stufe M ist Meisterentscheid und
  nicht wählbar. **Teilstand 2** (16. Oktober 2026): Elixiere der Tugenden
  tragen je Stufe `eigenschaften` (`AlchimikumEigenschaft`: Kürzel, Zahl, Dauer,
  Einheit – nur ausdrücklich belegte Werte, Rest bleibt Text „nicht berechnet“);
  `HeroInventoryEntry.alchimikum` (`AlchimikumBezug`) merkt ID und Stufe,
  „Anwenden“ wird dort zu „Einnehmen“ (`alchimika_elixier_rules.dart`, Ablauf
  `ElixierEinnehmen`): je Eigenschaftsänderung eine `SpellEffectInstance`
  (`effectId` = Mittel-ID) mit eigener Dauer. Sie rechnen **nur** über
  `effektiveTempAttributeMods`, Elixiere **addieren sich** (kein
  Attributo-Höchstwert). Stand und offene Punkte: Roadmap (TRANK).
