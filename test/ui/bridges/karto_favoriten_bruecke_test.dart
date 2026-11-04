import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_proben_favorit.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/proben_favoriten_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/probe_quick_search.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';

// Häufige Proben (ARCH-01): Stern in der Probensuche, Liste im Spielbereich.
const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

const _katalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[
    TalentDef(
      id: 'tal_menschenkenntnis',
      name: 'Menschenkenntnis',
      group: 'Gesellschaft',
      steigerung: 'C',
      attributes: <String>['KL', 'IN', 'CH'],
    ),
    TalentDef(
      id: 'tal_selbstbeherrschung',
      name: 'Selbstbeherrschung',
      group: 'Körperlich',
      steigerung: 'D',
      attributes: <String>['MU', 'KO', 'KK'],
    ),
  ],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

HeroSheet _held([List<HeroProbenFavorit> favoriten = const []]) => HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: _attribute,
  talents: const <String, HeroTalentEntry>{
    'tal_selbstbeherrschung': HeroTalentEntry(talentValue: 7),
    'tal_menschenkenntnis': HeroTalentEntry(talentValue: 5),
  },
  probenFavoriten: favoriten,
);

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

List<String> _ids(HeroSheet? held) =>
    held!.probenFavoriten.map((f) => f.id).toList();

void main() {
  const adapter = KartoBestandsAdapterImpl();

  Future<FakeRepository> zeige(
    WidgetTester tester, {
    List<HeroProbenFavorit> favoriten = const [],
    bool mitSuche = false,
    bool klassischeSuche = false,
    KartoKachelGroesse? groesse,
    double breite = 1200,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(breite, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: [_held(favoriten)],
      states: {'demo': const HeroState.empty()},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
        ],
        child: MaterialApp(
          builder: (context, kind) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: kind!,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  TextButton(
                    onPressed: () => klassischeSuche
                        ? showProbeQuickSearch(
                            context: context,
                            ref: ref,
                            heroId: 'demo',
                          )
                        : adapter.probeSuchen(
                            context: context,
                            ref: ref,
                            heroId: 'demo',
                          ),
                    child: const Text('suchen'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: groesse == null
                          ? adapter.spielFavoritenproben(heroId: 'demo')
                          : KartoKachelSteuerung(
                              kennung: 'proben',
                              groesse: groesse,
                              child: adapter.spielFavoritenproben(
                                heroId: 'demo',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (mitSuche) {
      await tester.tap(find.text('suchen'));
      await tester.pumpAndSettle();
    }
    return repo;
  }

  group('Probensuche', () {
    testWidgets('der Stern merkt eine Probe und nimmt sie wieder heraus', (
      tester,
    ) async {
      final repo = await zeige(tester, mitSuche: true);
      await tester.enterText(_key('probe-quick-search-field'), 'Menschen');
      await tester.pumpAndSettle();

      await tester.tap(
        _key('probe-quick-search-stern-talent:tal_menschenkenntnis'),
      );
      await tester.pumpAndSettle();
      expect(_ids(await repo.loadHeroById('demo')), [
        'talent:tal_menschenkenntnis',
      ]);
      expect(find.byIcon(Icons.star), findsOneWidget);

      await tester.tap(
        _key('probe-quick-search-stern-talent:tal_menschenkenntnis'),
      );
      await tester.pumpAndSettle();
      expect((await repo.loadHeroById('demo'))!.probenFavoriten, isEmpty);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('Eigenschaften und Kampfwerte haben ebenfalls einen Stern', (
      tester,
    ) async {
      final repo = await zeige(tester, mitSuche: true);
      await tester.tap(_key('probe-quick-search-stern-eigenschaft:MU'));
      await tester.pumpAndSettle();
      // Die Kampfzeilen liegen unterhalb der acht Eigenschaften.
      await tester.enterText(_key('probe-quick-search-field'), 'Attacke');
      await tester.pumpAndSettle();
      await tester.tap(_key('probe-quick-search-stern-kampf:attacke'));
      await tester.pumpAndSettle();
      expect(_ids(await repo.loadHeroById('demo')), [
        'eigenschaft:MU',
        'kampf:attacke',
      ]);
    });

    testWidgets('die klassische Suche ohne Schalter hat keinen Stern', (
      tester,
    ) async {
      await zeige(tester, klassischeSuche: true);
      await tester.tap(find.text('suchen'));
      await tester.pumpAndSettle();
      expect(_key('probe-quick-search-eigenschaft-MU'), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(_key('probe-quick-search-attribute-MU'), findsOneWidget);
    });

    testWidgets('bei voller Liste nennt eine Meldung den Grund', (
      tester,
    ) async {
      final voll = [
        for (var i = 0; i < kProbenFavoritenMax; i++)
          HeroProbenFavorit.von(ProbenFavoritArt.talent, 'tal_x$i'),
      ];
      final repo = await zeige(tester, favoriten: voll, mitSuche: true);
      await tester.tap(_key('probe-quick-search-stern-eigenschaft:MU'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('höchstens $kProbenFavoritenMax'),
        findsOneWidget,
      );
      expect(
        (await repo.loadHeroById('demo'))!.probenFavoriten,
        hasLength(kProbenFavoritenMax),
      );
    });
  });

  group('Liste der häufigen Proben', () {
    final beide = [
      HeroProbenFavorit.von(ProbenFavoritArt.talent, 'tal_menschenkenntnis'),
      HeroProbenFavorit.von(ProbenFavoritArt.talent, 'tal_selbstbeherrschung'),
    ];

    testWidgets('ohne Favoriten erscheint ein Hinweis', (tester) async {
      await zeige(tester);
      expect(find.textContaining('als häufige Probe bereit'), findsOneWidget);
    });

    testWidgets('zeigt Name und Wert aus dem aktuellen Helden', (tester) async {
      await zeige(tester, favoriten: beide);
      expect(find.text('Menschenkenntnis'), findsOneWidget);
      expect(find.text('KL/IN/CH · TaW* 5'), findsOneWidget);
      expect(find.text('Selbstbeherrschung'), findsOneWidget);
    });

    group('weite Stufe (SPIEL-07)', () {
      final vier = [
        ...beide,
        HeroProbenFavorit.von(ProbenFavoritArt.eigenschaft, 'MU'),
        HeroProbenFavorit.von(ProbenFavoritArt.eigenschaft, 'KL'),
      ];

      testWidgets('stehen die Proben nebeneinander', (tester) async {
        await zeige(tester, favoriten: vier, groesse: KartoKachelGroesse.weit);
        Offset ort(String id) => tester.getTopLeft(_key('proben-favorit-$id'));
        // Vier Proben bei Platz für drei ergeben 2×2, von links nach rechts.
        expect(_key('proben-favoriten-spalten-2'), findsOneWidget);
        final erste = ort('talent:tal_menschenkenntnis');
        final zweite = ort('talent:tal_selbstbeherrschung');
        final dritte = ort('eigenschaft:MU');
        expect(zweite.dy, erste.dy);
        expect(zweite.dx, greaterThan(erste.dx + 200));
        expect(dritte.dy, greaterThan(erste.dy));
        expect(dritte.dx, erste.dx);
      });

      testWidgets('bleiben sie in den schmaleren Stufen untereinander', (
        tester,
      ) async {
        for (final groesse in [
          null,
          KartoKachelGroesse.kompakt,
          KartoKachelGroesse.normal,
        ]) {
          await zeige(tester, favoriten: vier, groesse: groesse);
          final erste = tester.getTopLeft(
            _key('proben-favorit-talent:tal_menschenkenntnis'),
          );
          final zweite = tester.getTopLeft(
            _key('proben-favorit-talent:tal_selbstbeherrschung'),
          );
          expect(zweite.dx, erste.dx, reason: '$groesse');
          expect(zweite.dy, greaterThan(erste.dy), reason: '$groesse');
        }
      });

      testWidgets('Bedienung bleibt: Tipp würfelt, Menü ordnet um', (
        tester,
      ) async {
        final repo = await zeige(
          tester,
          favoriten: vier,
          groesse: KartoKachelGroesse.weit,
        );
        await tester.tap(
          _key('proben-favorit-menue-talent:tal_menschenkenntnis'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nach hinten'));
        await tester.pumpAndSettle();
        expect(_ids(await repo.loadHeroById('demo')).take(2), [
          'talent:tal_selbstbeherrschung',
          'talent:tal_menschenkenntnis',
        ]);
        await tester.tap(_key('proben-favorit-eigenschaft:MU'));
        await tester.pumpAndSettle();
        expect(find.text('Würfeln'), findsWidgets);
      });

      for (final breite in [600.0, 744.0, 1024.0, 1920.0]) {
        for (final skalierung in [1.0, 2.0]) {
          testWidgets('ohne Überlauf bei $breite dp und Schrift $skalierung', (
            tester,
          ) async {
            await zeige(
              tester,
              favoriten: vier,
              groesse: KartoKachelGroesse.weit,
              breite: breite,
              skalierung: skalierung,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    });

    testWidgets('ein Tipp öffnet den Probendialog', (tester) async {
      await zeige(tester, favoriten: beide);
      await tester.tap(_key('proben-favorit-talent:tal_menschenkenntnis'));
      await tester.pumpAndSettle();
      expect(find.text('Würfeln'), findsWidgets);
    });

    testWidgets('Reihenfolge ändern schreibt nur die Favoriten', (
      tester,
    ) async {
      final repo = await zeige(tester, favoriten: beide);
      await tester.tap(
        _key('proben-favorit-menue-talent:tal_menschenkenntnis'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nach hinten'));
      await tester.pumpAndSettle();
      final held = await repo.loadHeroById('demo');
      expect(_ids(held), [
        'talent:tal_selbstbeherrschung',
        'talent:tal_menschenkenntnis',
      ]);
      expect(held!.talents.keys, contains('tal_menschenkenntnis'));
    });

    testWidgets('am Rand ist die Verschiebung gesperrt', (tester) async {
      final repo = await zeige(tester, favoriten: beide);
      await tester.tap(
        _key('proben-favorit-menue-talent:tal_menschenkenntnis'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nach vorn'));
      await tester.pumpAndSettle();
      // Der gesperrte Eintrag schließt das Menü nicht und ändert nichts.
      expect(find.text('Nach hinten'), findsOneWidget);
      expect(_ids(await repo.loadHeroById('demo')), [
        'talent:tal_menschenkenntnis',
        'talent:tal_selbstbeherrschung',
      ]);
    });

    testWidgets('Entfernen nimmt die Probe aus der Liste', (tester) async {
      final repo = await zeige(tester, favoriten: beide);
      await tester.tap(
        _key('proben-favorit-menue-talent:tal_menschenkenntnis'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entfernen'));
      await tester.pumpAndSettle();
      expect(_ids(await repo.loadHeroById('demo')), [
        'talent:tal_selbstbeherrschung',
      ]);
      expect(find.text('Menschenkenntnis'), findsNothing);
    });

    testWidgets('nicht auflösbare Favoriten bleiben, bis man sie entfernt', (
      tester,
    ) async {
      final repo = await zeige(
        tester,
        favoriten: [
          ...beide,
          HeroProbenFavorit.von(ProbenFavoritArt.zauber, 'spl_verlernt'),
        ],
      );
      expect(
        find.text('Eine häufige Probe ist derzeit nicht verfügbar.'),
        findsOneWidget,
      );
      expect(find.text('Menschenkenntnis'), findsOneWidget);
      expect(_ids(await repo.loadHeroById('demo')), hasLength(3));

      await tester.tap(_key('proben-favoriten-aufraeumen'));
      await tester.pumpAndSettle();
      expect(_ids(await repo.loadHeroById('demo')), [
        'talent:tal_menschenkenntnis',
        'talent:tal_selbstbeherrschung',
      ]);
      expect(find.textContaining('nicht verfügbar'), findsNothing);
    });
  });
}
