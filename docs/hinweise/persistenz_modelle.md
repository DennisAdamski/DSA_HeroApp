# Persistenz, Modelle und Hashes

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Lokale Persistenz laeuft ueber `hive_ce` / `hive_ce_flutter`, den gepflegten
  Fork von Hive 2 (das Original ist seit 2022 ohne Release). Das Box-Format
  auf Platte ist identisch, Bestandsdaten brauchen keine Migration. Es sind
  keine `TypeAdapter` im Einsatz — Boxen halten `Map` bzw. `Uint8List`.
- Die AES-Schicht liegt in `lib/crypto/aes_primitives.dart` direkt auf
  `pointycastle`; `encrypt` ist entfernt. Das Modul ist bewusst blattartig,
  weil `catalog` und `data` es beide brauchen und die Richtung
  `data -> catalog` nicht umgedreht werden darf.
- Das Krypto-Wire-Format ist durch ausgelieferte Daten festgelegt und in
  `test/catalog/catalog_crypto_golden_test.dart` sowie
  `test/data/secrets_cipher_golden_test.dart` mit festen Chiffraten gepinnt.
  Diese Fixtures duerfen **nicht** angepasst werden, wenn sie brechen: dann
  ist die Implementierung inkompatibel geworden und jeder `enc:`-Katalogwert
  sowie jedes Firestore-Geheimnis waere unlesbar. Die uebrigen Krypto-Tests
  pruefen nur Round-Trips und wuerden das nicht bemerken.
- `HeroSheet` und `HeroState` bewahren JSON-Felder, die sie nicht kennen, in
  `unbekannteFelder` und schreiben sie zurueck; Verlaufseintraege unbekannter
  Steigerungsart bleiben als `UnbekannterVerlaufseintrag` erhalten. Bekannt ist,
  was in `jsonSchluessel` steht (bei `HeroSheet` einschliesslich der flach
  eingebetteten Schluessel von `HeroAppearance`/`HeroBackground`). **Jedes neue
  Feld dort eintragen** — sonst kaeme ein bewusst weggelassener Wert als
  „unbekannt“ zurueck. Dasselbe gilt fuer **jedes verschachtelte Modell**
  von Held und Zustand (Liste in `docs/technical_overview.md` Abschnitt 2.1;
  einzige Ausnahme `OffhandSlot`, nur gelesen). Jedes hat eigene
  `unbekannteFelder` und ein eigenes `jsonSchluessel`, das auch gelesene
  Altschluessel (`offhand`, `wmFk`, `fkMod`, `schnellladenBogen`, `eigenAp`,
  `vorNachteile`, Alias `note`) enthaelt. Bestehende Objekte **nur per
  `copyWith`** aendern — auch in Dialogen, die Zeilen oder Formulare neu
  zusammensetzen; neu errechnete Eigenschaften uebernimmt
  `Attributes.uebernimmWerte`. Ein Neuaufbau per Konstruktor verliert die
  Felder. Neue Modelle faengt der Vollstaendigkeitswaechter in
  `test/domain/unbekannte_verschachtelte_felder_test.dart` ab. Unbekannte
  Enum-Werte haelt jedes Modell roh in `unbekannteEnumWerte` (Regeln sehen
  den Ersatz, `toJson` schreibt den Rohwert); ein `copyWith` mit **anderem**
  Wert ueberschreibt ihn, derselbe Wert laesst ihn stehen. Neue
  Enum-Felder ueber `leseEnumWert` lesen und in die `_enumFelder`-Tabelle
  desselben Tests eintragen. Unbekannte Wundzonen: `WundZustand.unbekannteZonen`.
  Formatregel: nur additiv, eine neue Bedeutung bekommt einen neuen
  Schluessel.
- Die Bestandshelden unter `test/fixtures/heroes/` (ARCH-07) sind genauso
  festgeschrieben: nie anpassen, ein neues Format bekommt eine neue Datei.
  `test/domain/bestandshelden_kompatibilitaet_test.dart` pinnt ihre
  Inhalts-Hashes — bricht einer, bekaeme jeder gleich gespeicherte Held einen
  neuen Hash und der Konto-Sync meldete Konflikte. Die Regelwerte je Fixture
  rechnet `buildHeroComputedSnapshot` (reine Funktion hinter
  `heroComputedProvider`) gegen den echten Katalog
  (`test/test_support/real_catalog.dart`). Aufgedeckte, bewusst nicht
  behobene Fehler tragen im Test den Kommentar `Befund ARCH-07-Bx` und stehen
  mit Folgeauftrag in `docs/architecture_roadmap.md`. Details in
  `docs/test_strategy.md`.
- Objekte, die `AppStartupGate._buildScope` per `overrideWithValue` in den
  `ProviderScope` reicht, brauchen Wertgleichheit **und** eine stabile Instanz
  ueber Rebuilds hinweg (`CustomCatalogRepository`, `HouseRulePackRepository`
  liegen dafuer im Bootstrap-Ergebnis). Eine neue Instanz gilt sonst als
  geaenderter Override, invalidiert die Katalogkette und laesst die App
  sichtbar neu laden. Aus demselben Grund reagiert der Settings-Listener des
  Gates nur auf `heroStoragePath` — jede andere Einstellung (etwa eine
  gespeicherte Spaltenbreite) darf dort kein `setState` ausloesen.
