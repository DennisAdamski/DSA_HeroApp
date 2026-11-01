import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

// Block „Dabei“ (SPIEL-02): Geld und Verbrauchsgegenstände in der Spielansicht.
// Jeder Klick schreibt frisch und ändert nur sein eigenes Feld.

HeroInventoryEntry _verbrauch(String name, int menge, {String? id}) =>
    HeroInventoryEntry(
      gegenstand: name,
      anzahl: '$menge',
      menge: menge,
      instanzId: id ?? 'id-$name',
      itemType: InventoryItemType.verbrauchsgegenstand,
    );

HeroSheet _held({
  String dukaten = '12,5',
  List<HeroInventoryEntry>? eintraege,
}) => testHero('praiodan', 'Praiodan').copyWith(
  dukaten: dukaten,
  inventoryEntries:
      eintraege ??
      [
        _verbrauch('Fackel', 3),
        _verbrauch('Proviant', 5),
        const HeroInventoryEntry(
          gegenstand: 'Seil',
          anzahl: '1',
          instanzId: 'seil',
          itemType: InventoryItemType.ausruestung,
        ),
      ],
);

Finder _k(String key) => find.byKey(ValueKey<String>(key));

void main() {
  Future<ProviderContainer> zeigeMit(
    WidgetTester tester,
    FakeRepository repo,
    String heroId, {
    TestBestand? bestand,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: Scaffold(
            body: KartoSpielansicht(
              heroId: heroId,
              bestand: bestand ?? TestBestand(),
              aktion: (auftrag) => auftrag(),
              vorHeldenbearbeitung: () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<({ProviderContainer container, FakeRepository repo})> zeige(
    WidgetTester tester,
    HeroSheet held, {
    TestBestand? bestand,
  }) async {
    final repo = FakeRepository(heroes: [held]);
    final container = await zeigeMit(tester, repo, held.id, bestand: bestand);
    return (container: container, repo: repo);
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.ensureVisible(ziel);
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt Geld und nur die Verbrauchsgegenstände', (tester) async {
    await zeige(tester, _held());
    await tester.ensureVisible(find.text('Dabei'));
    expect(find.text('Dabei'), findsOneWidget);
    expect(tester.widget<Text>(_k('karto-dabei-geld-wert')).data, '12 D / 5 S');
    expect(find.text('Fackel'), findsOneWidget);
    expect(find.text('Proviant'), findsOneWidget);
    expect(find.text('Seil'), findsNothing);
    expect(tester.widget<Text>(_k('karto-dabei-0-menge')).data, '3');
  });

  testWidgets('Münzschritt schreibt frisch und zeigt den neuen Stand', (
    tester,
  ) async {
    final aufbau = await zeige(tester, _held());
    await tippe(tester, _k('karto-dabei-geld-s-plus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '12,6');
    expect(tester.widget<Text>(_k('karto-dabei-geld-wert')).data, '12 D / 6 S');

    await tippe(tester, _k('karto-dabei-geld-d-minus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '11,6');
  });

  testWidgets('Abziehen ist ohne genug Geld gesperrt', (tester) async {
    final aufbau = await zeige(tester, _held(dukaten: '0,05'));
    // 50 Kreuzer: Kreuzer abziehen geht, Silber und Dukaten nicht.
    await tippe(tester, _k('karto-dabei-geld-d-minus'));
    await tippe(tester, _k('karto-dabei-geld-s-minus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '0,05');
    await tippe(tester, _k('karto-dabei-geld-k-minus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '0,049');
  });

  testWidgets('Menge: schnelle Klicks zählen alle', (tester) async {
    final aufbau = await zeige(tester, _held());
    final minus = _k('karto-dabei-0-minus');
    await tester.ensureVisible(minus);
    await tester.tap(minus);
    await tester.tap(minus);
    await tester.pumpAndSettle();
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.inventoryEntries.first.menge, 1);
    expect(gespeichert.inventoryEntries.first.anzahl, '1');
    expect(tester.widget<Text>(_k('karto-dabei-0-menge')).data, '1');
    // Der zweite Eintrag und das Geld blieben unberührt.
    expect(gespeichert.inventoryEntries[1].menge, 5);
    expect(gespeichert.dukaten, '12,5');
  });

  testWidgets('Menge 0 sperrt das Minus, das Plus bleibt', (tester) async {
    final aufbau = await zeige(
      tester,
      _held(eintraege: [_verbrauch('Fackel', 0)]),
    );
    await tippe(tester, _k('karto-dabei-0-minus'));
    expect(
      (await aufbau.repo.loadHeroById('praiodan'))!
          .inventoryEntries
          .single
          .menge,
      0,
    );
    await tippe(tester, _k('karto-dabei-0-plus'));
    expect(
      (await aufbau.repo.loadHeroById('praiodan'))!
          .inventoryEntries
          .single
          .menge,
      1,
    );
  });

  testWidgets('Freitext-Menge hat keine Schritte', (tester) async {
    await zeige(
      tester,
      _held(
        eintraege: [
          const HeroInventoryEntry(
            gegenstand: 'Wein',
            anzahl: 'ein paar',
            instanzId: 'wein',
            itemType: InventoryItemType.verbrauchsgegenstand,
          ),
        ],
      ),
    );
    await tester.ensureVisible(find.text('Wein'));
    expect(find.text('ein paar'), findsOneWidget);
    // Die Knöpfe stehen da, tun aber nichts.
    final plus = tester.widget<InkWell>(
      find.descendant(
        of: _k('karto-dabei-0-plus'),
        matching: find.byType(InkWell),
      ),
    );
    expect(plus.onTap, isNull);
  });

  testWidgets('rechnet vom gespeicherten Stand, nicht vom angezeigten', (
    tester,
  ) async {
    // Die Anzeige zeigt 12,5 D und 3 Fackeln; gespeichert sind 20 D und 7.
    final angezeigt = _held();
    final gespeichert = _held(
      dukaten: '20',
      eintraege: [_verbrauch('Fackel', 7), _verbrauch('Proviant', 5)],
    );
    final repo = _AndererStand(angezeigt, frisch: gespeichert);
    await zeigeMit(tester, repo, angezeigt.id);
    expect(tester.widget<Text>(_k('karto-dabei-0-menge')).data, '3');

    await tippe(tester, _k('karto-dabei-0-minus'));
    expect(repo.zuletztGespeichert!.inventoryEntries.first.menge, 6);
    expect(repo.zuletztGespeichert!.dukaten, '20');

    await tippe(tester, _k('karto-dabei-geld-d-plus'));
    expect(repo.zuletztGespeichert!.dukaten, '21');
  });

  testWidgets('ein inzwischen entfernter Gegenstand meldet den Grund', (
    tester,
  ) async {
    final angezeigt = _held();
    final repo = _AndererStand(
      angezeigt,
      frisch: _held(eintraege: [_verbrauch('Proviant', 5)]),
    );
    await zeigeMit(tester, repo, angezeigt.id);
    await tippe(tester, _k('karto-dabei-0-minus'));
    await tester.ensureVisible(_k('karto-dabei-fehler'));
    expect(
      tester.widget<Text>(_k('karto-dabei-fehler')).data,
      contains('inzwischen geändert oder entfernt'),
    );
    expect(repo.zuletztGespeichert, isNull);

    // Der nächste Schritt räumt die Meldung wieder weg.
    await tippe(tester, _k('karto-dabei-1-plus'));
    expect(_k('karto-dabei-fehler'), findsNothing);
  });

  testWidgets('zwischenzeitlich anderswo Geändertes bleibt erhalten', (
    tester,
  ) async {
    final aufbau = await zeige(tester, _held());
    final aktuell = (await aufbau.repo.loadHeroById('praiodan'))!;
    await aufbau.repo.saveHero(
      aktuell.copyWith(
        dukaten: '20',
        inventoryEntries: [_verbrauch('Fackel', 3), _verbrauch('Proviant', 9)],
      ),
    );
    await tippe(tester, _k('karto-dabei-0-minus'));
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.dukaten, '20');
    expect(gespeichert.inventoryEntries.map((e) => e.menge), [2, 9]);
  });

  testWidgets('Betrag hinzufügen und abziehen über den Dialog', (tester) async {
    final aufbau = await zeige(tester, _held());
    await tippe(tester, _k('karto-dabei-geld'));
    await tester.enterText(_k('karto-dabei-betrag'), '3 D 5 S');
    await tester.tap(_k('karto-dabei-hinzufuegen'));
    await tester.pumpAndSettle();
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '16');

    await tippe(tester, _k('karto-dabei-geld'));
    await tester.enterText(_k('karto-dabei-betrag'), '1,5');
    await tester.tap(_k('karto-dabei-abziehen'));
    await tester.pumpAndSettle();
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '14,5');
  });

  testWidgets('Dialog weist Unlesbares und zu hohen Abzug ab', (tester) async {
    final aufbau = await zeige(tester, _held(dukaten: '1'));
    await tippe(tester, _k('karto-dabei-geld'));

    await tester.enterText(_k('karto-dabei-betrag'), 'viel');
    await tester.tap(_k('karto-dabei-hinzufuegen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bitte einen Betrag'), findsOneWidget);

    await tester.enterText(_k('karto-dabei-betrag'), '2');
    await tester.tap(_k('karto-dabei-abziehen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nicht genug Geld'), findsOneWidget);
    // Der Dialog bleibt offen, nichts wurde geschrieben.
    expect(_k('karto-dabei-betrag'), findsOneWidget);
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '1');

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(_k('karto-dabei-betrag'), findsNothing);
  });

  testWidgets('unlesbarer Geldstand wird gezeigt und sperrt die Schritte', (
    tester,
  ) async {
    final aufbau = await zeige(tester, _held(dukaten: 'ca. viel'));
    await tester.ensureVisible(_k('karto-dabei-geld-unlesbar'));
    expect(tester.widget<Text>(_k('karto-dabei-geld-wert')).data, 'ca. viel');
    await tippe(tester, _k('karto-dabei-geld-d-plus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, 'ca. viel');
  });

  testWidgets('ohne Verbrauchsgegenstände steht ein Hinweis da', (
    tester,
  ) async {
    await zeige(tester, _held(eintraege: const []));
    await tester.ensureVisible(_k('karto-dabei-leer'));
    expect(
      find.text('Keine Verbrauchsgegenstände im Inventar.'),
      findsOneWidget,
    );
  });

  testWidgets('viele Gegenstände klappen mit „Alle zeigen“ auf', (
    tester,
  ) async {
    await zeige(
      tester,
      _held(eintraege: [for (var i = 1; i <= 9; i++) _verbrauch('Ding $i', i)]),
    );
    await tester.ensureVisible(_k('karto-dabei-alle'));
    expect(find.text('Ding 6'), findsOneWidget);
    expect(find.text('Ding 7'), findsNothing);
    expect(find.text('Alle zeigen (3 weitere)'), findsOneWidget);

    await tippe(tester, _k('karto-dabei-alle'));
    expect(find.text('Ding 9'), findsOneWidget);
    expect(find.text('Weniger zeigen'), findsOneWidget);
  });

  testWidgets('Benutzen erscheint nur mit Brücke und Wirkung', (tester) async {
    final held = _held(
      eintraege: [
        _verbrauch('Fackel', 3),
        _verbrauch(
          'Heiltrank',
          2,
        ).copyWith(vitalwirkung: const Vitalwirkung(lep: 5)),
      ],
    );
    // Ohne Gefechtsbrücke bleibt es beim Zählen.
    await zeige(tester, held);
    expect(_k('karto-dabei-1-benutzen'), findsNothing);

    // Mit Brücke nur beim Eintrag mit Wirkung.
    await zeige(tester, held, bestand: _BestandMitGegenstand());
    expect(_k('karto-dabei-0-benutzen'), findsNothing);
    expect(_k('karto-dabei-1-benutzen'), findsOneWidget);
  });

  testWidgets('Benutzen öffnet den Dialog, der Block schreibt nichts', (
    tester,
  ) async {
    final bestand = _BestandMitGegenstand();
    final aufbau = await zeige(
      tester,
      _held(
        eintraege: [
          _verbrauch(
            'Heiltrank',
            2,
          ).copyWith(vitalwirkung: const Vitalwirkung(lep: 5)),
        ],
      ),
      bestand: bestand,
    );
    await tippe(tester, _k('karto-dabei-0-benutzen'));
    expect(bestand.benutzt, ['Heiltrank']);
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.inventoryEntries.first.menge, 2);
  });

  testWidgets('ein aufgebrauchter Trank lässt sich nicht benutzen', (
    tester,
  ) async {
    final bestand = _BestandMitGegenstand();
    await zeige(
      tester,
      _held(
        eintraege: [
          _verbrauch(
            'Heiltrank',
            0,
          ).copyWith(vitalwirkung: const Vitalwirkung(lep: 5)),
        ],
      ),
      bestand: bestand,
    );
    await tester.ensureVisible(_k('karto-dabei-0-benutzen'));
    await tester.tap(_k('karto-dabei-0-benutzen'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(bestand.benutzt, isEmpty);
  });

  testWidgets('eine offene Planung sperrt alle Schritte', (tester) async {
    final held = _held();
    final aufbau = await zeige(tester, held);
    aufbau.container
        .read(advancementSessionProvider('praiodan').notifier)
        .start(hero: held, catalog: testCatalog);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_k('karto-dabei-gesperrt'));
    expect(_k('karto-dabei-gesperrt'), findsOneWidget);

    await tippe(tester, _k('karto-dabei-geld-d-plus'));
    await tippe(tester, _k('karto-dabei-0-minus'));
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.dukaten, '12,5');
    expect(gespeichert.inventoryEntries.first.menge, 3);
  });
}

/// Repository, dessen gespeicherter Bogen vom angezeigten abweicht.
///
/// Der Indexstrom zeigt [angezeigt]; geladen wird [frisch], wie nach einer
/// Änderung auf einem anderen Weg. So lässt sich belegen, dass die Schritte
/// vom gespeicherten Stand ausgehen und nie vom Bild.
class _AndererStand extends FakeRepository {
  _AndererStand(HeroSheet angezeigt, {required this.frisch})
    : super(heroes: [angezeigt]);

  final HeroSheet frisch;

  /// Letzter über [saveHero] gespeicherter Bogen, sonst `null`.
  HeroSheet? zuletztGespeichert;

  @override
  Future<HeroSheet?> loadHeroById(String heroId) async =>
      zuletztGespeichert ?? frisch;

  @override
  Future<void> saveHero(HeroSheet hero) async {
    zuletztGespeichert = hero;
  }
}

/// Bestand mit Gefechtsbrücke, die nur das Benutzen eines Gegenstands vermerkt.
class _BestandMitGegenstand extends TestBestand
    implements KartoGefechtsAdapter {
  /// Namen der Gegenstände, für die der Dialog geöffnet wurde.
  final List<String> benutzt = <String>[];

  @override
  Future<bool> gefechtsVitalwirkung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required HeroInventoryEntry eintrag,
  }) async {
    benutzt.add(eintrag.gegenstand);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
