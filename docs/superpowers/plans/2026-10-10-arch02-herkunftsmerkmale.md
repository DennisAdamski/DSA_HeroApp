# ARCH-02 Herkunftsmerkmale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Herkunftsmodifikatoren strukturiert speichern, regelgleich migrieren
und bearbeiten; Herkunft an bestehenden Vor-/Nachteilen ergänzen.

**Architecture:** `HeroBackground` trägt einen optionalen versionierten
Herkunftscontainer. Kleine Regelmodule übernehmen direkte Modifikatorcodes,
Migration/Abgleich und Auswertung; Widgets delegieren dorthin. Vor-/Nachteile
bleiben in ihren bestehenden Listen und erhalten ausschließlich Metadaten.

**Tech Stack:** Flutter/Dart, Riverpod, Hive, bestehendes JSON-/Sync-Protokoll,
Flutter Tests. Keine zusätzlichen Paketabhängigkeiten.

**Spec:** [Freigegebene Spezifikation](../specs/2026-10-10-arch02-herkunftsmerkmale-design.md).

Stand 10.10.2026, Basis `427a232b` auf `test`. Spezifikation freigegeben;
dieser Implementierungsplan liegt zur Prüfung vor. Noch kein App-Code geändert.
Empfohlene Ausführung: direkt mit `executing-plans`, in Aufgabenreihenfolge.
Die Repository-Anweisung, einen vorhandenen Nicht-`main`-Branch weiterzuverwenden,
hat Vorrang vor dem Worktree-Standard des Skills; auf `test` weiterarbeiten.

## Global Constraints

- `formatVersion: 1`; unbekannte Versionen unverändert erhalten und Bearbeitung sperren.
- Kein vollständiger Herkunftskatalog, keine automatische Generierung, keine AP-Buchungen.
- Herkunft: `rasse`, `kultur`, `profession`; fehlend bedeutet nicht angegeben.
- Fehlender Herkunftscontainer und ausdrücklich drei leere Listen unterscheiden.
- Laden schreibt nichts; Migration persistiert beim nächsten `saveHero`.
- Wiederholungen bleiben erhalten; kein Deduplizieren von Herkunftsfragmenten.
- `ASP+0`, negative AsP-/KaP-Einträge und eine Summe von null behalten die Aktivierung.
- Herkunftseigenschaften beeinflussen laufende und Startwerte genau einmal.
- Herkunft an `HeroMerkmal` verändert weder AP noch Regelwirkung.
- UI-Strings verwenden Umlaute und ß; Hinzufügen im Header als `+ Herkunftsmodifikator`.
- Abbrechen beim Schutz offener Planungen verhindert alle Folgeaktionen.
- Alle Berechnungen unter `lib/rules/derived/`; öffentliche Dart-APIs dokumentieren.
- Neue Screen-Dateien unter 700 Zeilen; keine weiteren Verantwortlichkeiten in große Dateien schieben.
- Pro abgeschlossener Änderung relevante Tests und `flutter analyze`, dann gezielter Commit.
- Keine Veröffentlichung, kein Push und kein Merge in diesem Plan.

## Review Focus

1. Gleiches Fragment mehrfach und in verschiedenen Herkunftsgruppen: Werte und IDs bleiben getrennt (Aufgabe 2).
2. Letzten Eintrag löschen, dann laden und migrieren: kein Wiederauftauchen aus Alttext (Aufgaben 1, 4, 5).
3. Neuere Version mit unbekannten Arten/Zielen oder beschädigten Teilstücken: Rohdaten bleiben erhalten, Bearbeitung sperrt nur unsichere Bereiche (Aufgaben 1, 3, 5).
4. Anderes Gerät ändert die Herkunft bei geöffnetem Editor: kein stilles Überschreiben oder falsches Normalisieren der Textprojektion (Aufgaben 4, 5).
5. Planung beginnt während eines offenen Merkmalsdialogs: vor dem Schreiben erneut prüfen; Abbruch speichert nichts (Aufgabe 5).

## Struktur und gemeinsame Schnittstellen

Neue Domain-Dateien: `lib/domain/hero_herkunft.dart` für Herkunftsenum und
versionierten Container; `lib/domain/hero_herkunfts_modifikator.dart` für
einzelne direkte/freie Einträge. Diese Aufteilung hält Serialisierung und
Rohdatenwächter übersichtlich. Die Spezifikation erlaubt ausgelagerte Teildateien.

Neue Regeldateien:

- `lib/rules/derived/direkter_modifikator_rules.dart`: ein gemeinsamer Code-/Aliasvertrag.
- `lib/rules/derived/hero_herkunft_migration_rules.dart`: Migration, Projektion, Abgleich.
- `lib/rules/derived/hero_herkunft_rules.dart`: strukturierte Regelauswertung je Herkunft.
- `lib/rules/derived/hero_herkunft_bearbeitung_rules.dart`: gezielte Änderungen und Konfliktprüfung.

UI: `lib/ui/screens/hero_overview/hero_herkunft_section.dart` und
`hero_herkunft_dialog.dart` als eigenständige Widgets; ein kleines
`hero_overview_herkunft_section.dart`-Part bindet den Entwurf an die Übersicht.
Merkmalsherkunft bekommt einen gemeinsamen Dialog unter
`lib/ui/screens/shared/merkmal_herkunft_dialog.dart` für Übersicht und UI2.

Die folgenden Typen und Signaturen sind der gemeinsame Vertrag des Plans:

```dart
enum HeroHerkunft { rasse, kultur, profession }
enum HeroHerkunftsModifikatorArt { eigenschaft, basiswert, frei }
enum HerkunftsAbgleichWahl { textUebernehmen, listeBehalten }

// Domain: Konstruktion, fromJson, toJson, copyWith; keine Berechnungen.
// HeroHerkunftsModifikator: id, art, ziel, betrag, text,
// unbekannteFelder, unbekannteEnumWerte, optional unverstandeneRohdaten.
// HeroHerkunftsModifikatoren: formatVersion, rasse, kultur, profession,
// unbekannteFelder, optional unverstandeneRohdaten.
// istBearbeitbar und brauchtPruefung sind strukturelle Datenwächter.

DirekterModifikator? erkenneDirektenModifikator(String fragment);
ModifierParseResult wendeDirektenModifikatorAn(DirekterModifikator eintrag);
Set<String> normalisierteBasiswertCodes(String text);

List<HeroHerkunftsModifikator> migriereHerkunftsText(
  HeroHerkunft herkunft, String text,
);
String projiziereHerkunftsText(List<HeroHerkunftsModifikator> eintraege);
HeroHerkunftsModifikatoren wirksameHerkunftsModifikatoren(HeroBackground background);
HerkunftsAbgleich gleicheHerkunftAb(HeroBackground background);
HeroBackground herkunftZumSpeichern(HeroBackground background);
HeroBackground loeseHerkunftsAbweichung(
  HeroBackground background, HeroHerkunft herkunft, HerkunftsAbgleichWahl wahl,
);

HerkunftsAuswertung werteHerkunftAus(HeroBackground background);
// HerkunftsAuswertung: jeHerkunft (Map<HeroHerkunft, HerkunftsWirkungen>).
// HerkunftsWirkungen: ModifierParseResult modifikatoren,
// bool aktiviertMagie, bool aktiviertKarma, bool brauchtPruefung.

HeroBackground ersetzeHerkunftsEintraege({
  required HeroBackground basis,
  required HeroBackground aktuell,
  required HeroHerkunft herkunft,
  required List<HeroHerkunftsModifikator> eintraege,
});
// Wirft StateError, wenn diese Herkunft seit basis geändert wurde oder
// unverständliche Daten/eine ungelöste Textabweichung eine Änderung verhindern.
```

`DirekterModifikator` enthält `art`, `ziel`, `betrag`; sein `art` ist nie `frei`.
`HerkunftsAbgleich` enthält `eintraege` (wirksamer Container) und
`abweichungen` (`Map<HeroHerkunft, HerkunftsTextAbweichung>`).
`HerkunftsTextAbweichung` enthält `text` und `listenText`.
Getter `eintraegeFuer(HeroHerkunft)` und `textFuer(HeroHerkunft)` sowie
Container-`copyWith` unterstützen die gruppenweise Änderung ohne doppelte Fallunterscheidungen.
Alle neuen Tests importieren Domain-/Regeldateien über
`package:dsa_heldenverwaltung/…` und `flutter_test`.

### Aufgabe 1: Additiver Datenvertrag und Merkmalsherkunft

**Dateien:** Neue Domain-Dateien oben; ändern `lib/domain/hero_background.dart`,
`lib/domain/hero_merkmal.dart`, `lib/domain/hero_sheet.dart`;
neue Tests `test/domain/hero_herkunft_model_test.dart`.

**Schnittstellen:** Produziert den Domainvertrag oben. Keine Regelfunktionen erforderlich.

- [ ] Rote Tests für fehlenden Container, explizit leeren Container und
  unbekannte Rohdaten schreiben. Insbesondere auch Nicht-Objekte in Listen,
  doppelte/fehlende IDs, nicht-ganzzahlige Beträge und unbekannte Zielcodes erhalten.

```dart
test('leerer Container bleibt vom Bestandsformat unterscheidbar', () {
  final bestand = HeroSheet(id: 'h', name: 'Held');
  expect(bestand.toJson().containsKey('herkunftsModifikatoren'), isFalse);
  final leer = bestand.copyWith(
    background: bestand.background.copyWith(
      herkunftsModifikatoren: const HeroHerkunftsModifikatoren(),
    ),
  );
  final neu = HeroSheet.fromJson(leer.toJson());
  expect(neu.background.herkunftsModifikatoren, isNotNull);
  expect(neu.background.herkunftsModifikatoren!.rasse, isEmpty);
});

test('unbekannte Version und Herkunft bleiben roh erhalten', () {
  final json = HeroSheet(id: 'h', name: 'Held').toJson();
  json['herkunftsModifikatoren'] = {
    'formatVersion': 900, 'zukunft': {'wert': 42},
  };
  final neu = HeroSheet.fromJson(json);
  expect(neu.toJson()['herkunftsModifikatoren'], json['herkunftsModifikatoren']);
  expect(neu.background.herkunftsModifikatoren!.istBearbeitbar, isFalse);
  final merkmal = HeroMerkmal.fromJson({
    'text': 'Flink', 'katalogId': 'adv_flink', 'herkunft': 'zukunft',
  });
  expect(merkmal.copyWith(text: 'Neu').toJson()['herkunft'], 'zukunft');
  expect(merkmal.copyWith(herkunft: HeroHerkunft.rasse).toJson()['herkunft'], 'rasse');
  expect(merkmal.copyWith(herkunft: null).toJson().containsKey('herkunft'), isFalse);
});
```

- [ ] `flutter test --no-pub test/domain/hero_herkunft_model_test.dart`:
  zunächst fehlende Typen/APIs, nach Implementierung grün.
- [ ] Domain implementieren: optionales Containerfeld mit Sentinel-`copyWith`
  (nicht angegeben erhält, `null` entfernt); Root-Schlüssel über
  `HeroBackground.jsonSchluessel` registrieren. Unverstandenes Containerformat
  als kompletten Rohwert zurückschreiben. Unsichere Teilstücke ebenfalls roh
  erhalten und ihre Gruppe für Änderungen sperren. Kein stilles Verwerfen
  durch `whereType<Map>()`. Merkmalsherkunft in Gleichheit/Hash berücksichtigen.

```dart
// Im bestehenden HeroBackground.toJson ergänzen:
if (herkunftsModifikatoren != null)
  'herkunftsModifikatoren': herkunftsModifikatoren!.toJson(),
// HeroMerkmal.toJson ergänzen; unbekannte Werte weiterhin über bestehende Wächter:
if (herkunft != null) 'herkunft': herkunft!.name,
```

- [ ] Regression: `flutter test --no-pub --concurrency=1 test/domain/hero_herkunft_model_test.dart test/domain/hero_sheet_model_test.dart`.
- [ ] CLAUDE.md und `docs/technical_overview.md` um den additiven Datenvertrag
  ergänzen; Bestandsfixtures und Hash-Pins unverändert lassen.
- [ ] `flutter analyze --no-pub`; gezielter Commit
  `domain: Herkunftsmodifikatoren und Merkmalsherkunft modellieren`.

### Aufgabe 2: Gemeinsame Codes, Migration und ausdrücklicher Abgleich

**Dateien:** Neue `direkter_modifikator_rules.dart`, `hero_herkunft_migration_rules.dart`;
ändern `lib/rules/derived/modifier_parser.dart`;
neue `test/rules/hero_herkunft_migration_rules_test.dart`.

**Schnittstellen:** Verwendet Aufgabe 1; produziert die Code-/Migrations-/Abgleich-APIs oben.

- [ ] Tests für doppelte Fragmente, Aliase, IDs, Projektion und Fremdtext anlegen:

```dart
test('Migration erhält Wiederholungen und wird reproduzierbar', () {
  const text = 'MU+1, MU+1; AE-2\nHausnotiz';
  final a = migriereHerkunftsText(HeroHerkunft.rasse, text);
  final b = migriereHerkunftsText(HeroHerkunft.rasse, text);
  expect(a.map((e) => e.id).toSet(), hasLength(4));
  expect(a.map((e) => e.toJson()).toList(), b.map((e) => e.toJson()).toList());
  expect(a[2].ziel, 'ASP');
  expect(a.last.text, 'Hausnotiz');
});

test('anderes Feld speichern löst fremden Herkunftstext nicht auf', () {
  final basis = herkunftZumSpeichern(const HeroBackground(rasseModText: 'MU+1'));
  final fremd = basis.copyWith(rasseModText: 'MU+3');
  final gespeichert = herkunftZumSpeichern(fremd);
  expect(gespeichert.rasseModText, 'MU+3');
  expect(gleicheHerkunftAb(gespeichert).abweichungen.keys, [HeroHerkunft.rasse]);
  final geloest = loeseHerkunftsAbweichung(
    gespeichert, HeroHerkunft.rasse, HerkunftsAbgleichWahl.listeBehalten,
  );
  expect(geloest.rasseModText, 'MU+1');
  expect(gleicheHerkunftAb(geloest).abweichungen, isEmpty);
});
```

- [ ] `flutter test --no-pub test/rules/hero_herkunft_migration_rules_test.dart` rot ausführen.
- [ ] Codeerkennung aus dem Parser auslagern: bisherige Regex
  `^\s*([A-Za-z]+)\s*([+-])\s*(\d+)\s*$`, Aliase AE→ASP, KE→KAP, LE→LEP,
  AW→AUSWEICHEN; bekannte Basiswerte LEP, AU, ASP, KAP, MR, INI, GS,
  AUSWEICHEN; Eigenschaften über `parseAttributeCode`. Die Normalisierung
  auch für `extractNormalizedStatModifierCodes` gemeinsam verwenden.
  `ModifierParseResult` gegebenenfalls in eine kleine eigene Datei auslagern,
  damit direkte Codehilfen keinen Importzyklus zum Heldenparser erzeugen.
- [ ] Migration ohne Katalog implementieren; ID als UUID-v5 aus einer festen
  Herkunftsmigrations-Namespace und JSON-kodiertem Tupel aus Herkunft,
  Fragmentposition und Fragmenttext erzeugen (bestehendes `uuid`-Paket).
  Keine IDs aus `hashCode`, keine Zusammenfassung mehrfacher Fragmente.

```dart
final fragmente = text.split(RegExp(r'[\n,;]+'));
// Je nichtleerem, äußerlich getrimmtem Fragment einen Eintrag erzeugen.
// erkenneDirektenModifikator: bekannt → Ziel/Betrag; sonst art: frei.
// text bleibt das ursprüngliche Fragment. Position vor Filterung verwenden.
```

- [ ] Migration nur bei fehlendem Container; leere Bestandsfelder ebenfalls
  als leere Listen persistieren. Projektion je Gruppe aus erhaltenen Texten.
  Vergleich über geordnete, getrimmte Fragmente; Textänderungen melden und nur
  durch `loeseHerkunftsAbweichung` auflösen. Unbekannte Gesamtversion nicht migrieren.
- [ ] Zusätzliche Tests: gleiche Fragmente in Rasse/Kultur, leere Container,
  Trennerwechsel ohne Abweichung, beide Auflösungen ändern nur eine Gruppe,
  benanntes „Flink“ bleibt freier und bisher wirkungsloser Herkunftstext.
- [ ] `flutter test --no-pub --concurrency=1 test/rules/hero_herkunft_migration_rules_test.dart test/rules/modifier_text_parser_test.dart`.
- [ ] Migration in technischer Übersicht und `docs/test_strategy.md` dokumentieren;
  `flutter analyze --no-pub`, Commit `rules: Herkunftstexte verlustfrei migrieren und abgleichen`.

### Aufgabe 3: Strukturierte Wirkungen in allen Regelverbrauchern

**Dateien:** Neue `hero_herkunft_rules.dart`;
ändern `modifier_parser.dart`, `modifier_source_breakdown.dart`,
`resource_activation_rules.dart` unter `lib/rules/derived/`;
neue `test/rules/hero_herkunft_rules_test.dart`.

**Schnittstellen:** Verwendet Aufgaben 1/2; produziert `werteHerkunftAus`.
Startwert-/Stat-APIs bleiben außen unverändert.

- [ ] Rote Tests erzeugen, bei denen Ziel/Betrag geändert sind, Texte aber
  noch den alten Wert tragen: strukturierte Werte müssen führen.

```dart
test('Liste führt und nullsummierte AsP aktivieren weiterhin', () {
  var background = herkunftZumSpeichern(const HeroBackground(
    rasseModText: 'MU+1', professionModText: 'ASP+1, ASP-1',
  ));
  final container = background.herkunftsModifikatoren!;
  background = background.copyWith(
    herkunftsModifikatoren: container.copyWith(
      rasse: [container.rasse.single.copyWith(betrag: 3)],
    ),
  );
  final hero = HeroSheet(id: 'h', name: 'Held', background: background);
  final mods = parseModifierTextsForHero(hero, catalog: null);
  expect(mods.attributeMods.mu, 3);
  expect(mods.startAttributeMods.mu, 3);
  expect(mods.statMods.asp, 0);
  expect(hasAutomaticMagicActivation(hero, catalog: null), isTrue);
});
```

- [ ] `flutter test --no-pub test/rules/hero_herkunft_rules_test.dart` rot.
- [ ] Je Gruppe strukturierte Einträge über `wendeDirektenModifikatorAn`
  auswerten. Eigenschaftsanteil in laufende und Startwerte übernehmen.
  Für freie/unverstandene Einträge nur ihren Text im Herkunftskontext auswerten;
  bei unbekannter Gesamtversion die drei Kompatibilitätstexte verwenden.
  Aktivierungsflags aus erkannten Codes, nicht aus Summen bestimmen.
- [ ] `parseModifierTextsForHero`: Herkunft aus neuem Modul, Vor-/Nachteile
  weiter über bestehenden Weg; rohe Herkunftstexte dabei leer übergeben,
  damit nichts doppelt zählt. Textcache nur für tatsächlich textbasierte
  Teile verwenden; Herkunftsergebnis außerhalb des alten Textcaches addieren.
- [ ] Quellenaufschlüsselung nimmt dieselbe gruppierte Auswertung;
  Ressourcenaktivierung nimmt dieselben Flags. Kein alternativer Rohtextweg.
- [ ] Tests ergänzen: AsP null/negativ, KaP null/negativ, alle Aliase,
  unbekannter Art-/Ziel-Fallback genau einmal, benannte Vorteile weiter
  nicht neu aktivieren, reine Merkmalsherkunft ändert keine Wirkung.
- [ ] Reale Bestandsfixtures mit geladenem Katalog vergleichen: effektive
  Eigenschaften, Startwerte, Maxima, abgeleitete Stats, Quellenanteile,
  Aktivierung und unbekannte Fragmente vor/nach Migration sind gleich.
- [ ] `flutter test --no-pub --concurrency=1 test/rules/hero_herkunft_rules_test.dart test/rules/modifier_text_parser_test.dart test/rules/attribute_start_rules_test.dart test/rules/resource_activation_rules_test.dart test/rules/hero_merkmal_rules_test.dart`.
- [ ] Regelpfade in CLAUDE.md/technischer Übersicht ergänzen;
  `flutter analyze --no-pub`, Commit `rules: Herkunftsmerkmale gemeinsam und ohne Doppelwirkung auswerten`.

### Aufgabe 4: Speicherung, Import/Export, Sync und frische Änderungen

**Dateien:** Neue `hero_herkunft_bearbeitung_rules.dart`;
ändern `lib/state/hero_actions.dart`, gegebenenfalls
`lib/domain/sync_zusammenfuehrung.dart` und `lib/rules/derived/editor_entwurf_rules.dart`;
neue Tests `test/data/herkunft_migration_test.dart`, `test/data/herkunft_sync_test.dart`,
`test/rules/hero_herkunft_bearbeitung_rules_test.dart`.

**Schnittstellen:** Verwendet Aufgaben 1–3; produziert `ersetzeHerkunftsEintraege`.
Bestehende `saveHero`, `updateHero`, `uebernimmEditorEntwurf` bleiben die Schreibwege.

- [ ] Rote Regelprobe für stale Entwürfe und erhaltene Paralleländerungen:

```dart
test('Änderung einer anderen Herkunft bleibt erhalten', () {
  final basis = herkunftZumSpeichern(const HeroBackground(
    rasseModText: 'MU+1', kulturModText: 'KL+1',
  ));
  final aktuell = basis.copyWith(kultur: 'Neuer Name');
  final neu = ersetzeHerkunftsEintraege(
    basis: basis, aktuell: aktuell, herkunft: HeroHerkunft.rasse,
    eintraege: const [],
  );
  expect(neu.kultur, 'Neuer Name');
  expect(neu.rasseModText, isEmpty);
  expect(neu.herkunftsModifikatoren!.rasse, isEmpty);
});
```

- [ ] `flutter test --no-pub test/rules/hero_herkunft_bearbeitung_rules_test.dart` rot.
- [ ] Regel prüft Containerverständlichkeit, Abweichung und Basis/aktueller
  Gruppeneinträge samt Text; bei gleicher Gruppe und anderem Inhalt StateError.
  Änderungen einer anderen Gruppe erhalten. Bei erfolgreicher Änderung Liste
  und ausschließlich zugehörige Textprojektion gemeinsam setzen.
- [ ] `saveHero`: `herkunftZumSpeichern` vor Regelberechnung und Normalisierung
  anwenden, wie `merkmaleZumSpeichern`; weder Schemawerte absenken noch
  AP-/Laufzeitressourcen buchen. Katalogladen ist keine Voraussetzung.
- [ ] Hive-Tests mit `HiveHeroRepository.create` und `heroActionsProvider`
  nach Muster `test/data/merkmal_migration_test.dart`: Bestandshelden speichern,
  schließen/neuladen, erneut speichern, JSON ohne Stempel vergleichen;
  leerer Container und unbekannte Rohdaten bleiben über Export/Import erhalten.
- [ ] Sync mit `GeteilteCloud`/`SyncTestGeraet` aus bestehenden Testhelfern
  testen: getrennte Herkunftsgruppen und getrennte stabile IDs, Änderung
  derselben ID, Entfernen gegen Bearbeiten, Konfliktwahl lokal/online/beide.
  Struktur und Textprojektionen bilden gemeinsam den fachlichen Zustand.
  Das generische Map-/ID-Merge nur erweitern, wenn eine konkrete Probe
  eine Verletzung dieses Vertrags zeigt; nicht allein für diese Funktion
  den Sync-Transport umbauen. Herkunftskonflikte bleiben entscheidbar.
- [ ] Mischbetrieb separat: Altversion entfernt Container → Textweg und
  erneute Migration; Altversion bewahrt Container und ändert Text → sichtbarer
  Abgleich ohne Rückschrieb; neuere Version liefert unbekannte Teilfelder →
  alle drei Konfliktwahlen erhalten sie. Herkunft an Merkmalen erhalten.
- [ ] Editor-Tests für Paralleländerungen auf demselben Root-Feld: bei
  Überschneidung ausdrücklicher Konflikt ausreichend; kein stilles Ersetzen
  ganzer Container. Unveränderte Gruppen und unbekannte Rohdaten erhalten.
- [ ] `flutter test --no-pub --concurrency=1 test/data/herkunft_migration_test.dart test/data/herkunft_sync_test.dart test/rules/hero_herkunft_bearbeitung_rules_test.dart test/data/merkmal_migration_test.dart test/data/sync_app_versionen_test.dart test/data/hero_actions_import_export_test.dart test/ui/overview/uebersicht_frisch_schreiben_test.dart`.
- [ ] Speicher-/Kompatibilitätsgrenzen dokumentieren;
  `flutter analyze --no-pub`, Commit `data: Herkunftsmerkmale über Speicherung und Sync erhalten`.

### Aufgabe 5: Herkunftslisten und Merkmalsherkunft bearbeiten

**Dateien:** Neue UI-Dateien aus Strukturabschnitt;
ändern `lib/ui/screens/hero_overview_tab.dart`,
`lib/ui/screens/hero_overview/hero_overview_base_info_section.dart`,
`hero_overview_traits_section.dart`, `hero_overview_trait_dialogs.dart`,
`lib/ui2/merkmale/karto_merkmalsblatt.dart`, `karto_merkmal_karten.dart`,
`lib/ui/widgets/sync_conflict_field_labels.dart`;
neue `test/ui/overview/hero_herkunft_section_test.dart` und
`test/ui/overview/hero_herkunft_editor_test.dart`;
ergänzen `test/ui2/merkmale/karto_merkmalsblatt_test.dart`.

**Schnittstellen:** Verwendet Domain, Abgleich und Änderungsregeln aus Aufgaben 1–4.

- [ ] Neue Section mit diesem Widgetvertrag testen:

```dart
testWidgets('Hinzufügen abbrechen verändert keine Einträge', (tester) async {
  final basis = herkunftZumSpeichern(const HeroBackground(rasseModText: 'MU+1'));
  var aenderungen = 0;
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: HeroHerkunftSection(
      herkunft: HeroHerkunft.rasse,
      background: basis,
      bearbeitbar: true,
      onEintraegeChanged: (_) => aenderungen++,
      onAbgleich: (_) => fail('Kein Abgleich erwartet'),
    ),
  )));
  await tester.tap(find.text('+ Herkunftsmodifikator'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abbrechen'));
  await tester.pumpAndSettle();
  expect(aenderungen, 0);
});
```

  Tests verwenden `MaterialApp`/`Scaffold`, prüfen `+ Herkunftsmodifikator`
  im Header, Ziel-/Betragdialog, Abbruch, Entfernen und beide Abgleichbuttons.
  Callbacks müssen bei Abbruch ungerufen bleiben. Bei unbekannter Gruppe
  zeigt die Section einen konkreten Grund statt editierbarer Felder.
- [ ] `flutter test --no-pub test/ui/overview/hero_herkunft_section_test.dart` rot.
- [ ] Section/Dialog implementieren: UUID-v4 bei bestätigtem Hinzufügen,
  bestehende ID bei Bearbeiten erhalten; Ziel/Betrag gemeinsam durch
  Regelhilfen validieren und Text normalisieren. Freie Fragmente mit Textfeld;
  keine Wirkung rechnen oder Aliaslisten in Widgets duplizieren.
- [ ] Übersicht hält `_draftHerkunft`; Befüllen/Verwerfen setzt sie passend
  zurück. Vorschau und Speicherentwurf verwenden dieselbe Containerfassung.
  Alte Modifikator-Textfelder ersetzen, Herkunftsnamen unverändert lassen.
  Abgleich nur betroffene Herkunft ändern lassen. Speicherpfad bleibt
  `speichereEditorEntwurf`; kein direktes Repository-Schreiben aus Widgets.
- [ ] Gemeinsamen Herkunftsdialog für `HeroMerkmal` hinzufügen und in beide
  Bearbeitungsoberflächen anbinden; neue Aktion „Herkunft ändern“, Auswahl
  „Nicht angegeben“, „Rasse“, „Kultur“, „Profession“. Bestehende Katalog-ID,
  Auswahl und Wert erhalten; Karten zeigen Herkunft als Zusatzinformation.
- [ ] Vor Dialogöffnung und vor unmittelbarem Schreiben offene Planung
  über `bestaetigeBearbeitungBeiPlanung` prüfen. Bei `false` sofort zurückkehren.
  Bereits offene Entwürfe bleiben lesbar und nutzen `PlanungsFormularSchutz`.
  Auch spätes Beginnen einer Planung oder ein veralteter Merkmalseintrag
  darf keinen ungeprüften Schreibzugriff ermöglichen.
- [ ] Integrationstests: Änderungen treffen Vorschau und gespeicherten
  Stand; Abbrechen erhält Ursprung; letzten Eintrag löschen über Neustart;
  Textabweichung auflösen; Paralleländerung während Editor/Dialog;
  Planung-Abbrechen erhält Sitzung und Daten, Verwerfen erlaubt Änderung.
- [ ] Schmale Ansicht 360 px und `TextScaler.linear(2)` prüfen, keine
  Overflow-Exceptions; Felder/Buttons bleiben erreichbar. Manuelle Prüfung
  auf tatsächlichen Geräten getrennt als offen dokumentieren.
- [ ] `flutter test --no-pub --concurrency=1 test/ui/overview/hero_herkunft_section_test.dart test/ui/overview/hero_herkunft_editor_test.dart test/ui/overview/hero_overview_tab_test.dart test/ui/overview/uebersicht_frisch_schreiben_test.dart test/ui2/merkmale/karto_merkmalsblatt_test.dart test/ui/shared/planung_bearbeiten_guard_test.dart`.
- [ ] Konfliktfeldlabels ergänzen; Benutzeranleitung/technische Übersicht
  aktualisieren; `flutter analyze --no-pub`, Commit
  `ui: Herkunftsmodifikatoren und Merkmalsherkunft bearbeiten`.

### Aufgabe 6: Abnahme, Dokumentation und Gesamtprüfung

**Dateien:** `CLAUDE.md`, `README.md` (nur wenn Nutzerworkflow geändert),
`docs/architecture_roadmap.md`, `docs/technical_overview.md`, `docs/test_strategy.md`,
Spezifikation und dieser Plan. `AGENTS.md` prüfen, ohne neue Policy zu erfinden.

**Schnittstellen:** Prüft alle acht Abnahmekriterien der Spezifikation anhand
der tatsächlichen Implementierung und Testausgaben.

- [ ] Für jedes Abnahmekriterium Testdatei/Probe und Ergebnis festhalten;
  unbelegte Kriterien als offen belassen. Insbesondere keine automatisierte
  Layoutprüfung als tatsächliche Gerätebedienprüfung ausgeben.
- [ ] Alle neuen Tests und die jeweils aufgeführten Regressionen seriell
  ausführen; danach `flutter analyze --no-pub`,
  `python tool/check_screen_loc_budget.py`, `git diff --check`.
  Vorbestehende LOC-Verletzungen separat vom geänderten Scope bewerten.
- [ ] Gesamtsuite `flutter test --no-pub --concurrency=1` ausführen;
  auf Windows nötigenfalls eigenes `DSA_MCP_DATA_DIR` für den Lauf verwenden.
  Lange Testausgabe in den ignorierten Plan-Arbeitsordner umleiten und
  Exitcode plus Schlussausgabe prüfen. Fehler beheben, bevor Abschluss/Commit.
- [ ] Eigenständige Schlussprüfung: keine Herkunftsrechnung in UI/Providern,
  keine direkten rohen Herkunftsverbraucher mehr, unbekannte Daten nicht
  weggefiltert, Dialogabbruch und stale Schreibschutz geprüft, nur notwendige
  Änderungen und vollständige Dart-Docs. Bei direkter Ausführung erlaubt der
  `executing-plans`-Skill eine unabhängige Schlussprüfung durch einen Reviewer;
  kein paralleles Implementieren gemeinsamer Dateien.
- [ ] Roadmap nur anhand belegter Teilumfänge abhaken. ARCH-02 bleibt offen,
  solange die ausstehende manuelle Bedienprüfung nicht erfolgt ist.
  Spezifikation/Planstatus auf tatsächlichen Stand setzen; neue Architektur
  und Dateiverantwortlichkeiten in CLAUDE.md beschreiben.
- [ ] Nach bestandenen Prüfungen gezielten Abschlusscommit erstellen.
  Mempalace nach Duplikatprüfung mit Commit, Prüfumfang und offenen Grenzen
  ergänzen; final Commitfolge, Testergebnis und offene Geräteprüfung berichten.

## Planprüfung

- Datenvertrag und Rohdatenerhalt: Aufgabe 1.
- Migration, Fixpunkt, IDs, Textprojektion und beide Entscheidungen: Aufgabe 2.
- Gemeinsame Regeln, Startwerte, Aktivierung und Caches: Aufgabe 3.
- Hive, Import/Export, Mischbetrieb, Sync und stale Änderungen: Aufgabe 4.
- Beide Merkmalsoberflächen, Herkunftslisten, Planungsschutz und Layout: Aufgabe 5.
- Dokumentation, Gesamtregression und Abgrenzung manueller Prüfung: Aufgabe 6.

Die fünf Review-Fälle sind in den jeweiligen Aufgaben ausdrücklich getestet.
Aufgaben 2–5 verwenden denselben oben definierten Schnittstellenvertrag;
keine Implementierung setzt einen weiteren, unbenannten Dienst voraus.
