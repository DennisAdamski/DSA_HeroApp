import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

import '../../test_support/fake_repository.dart';

import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';

import '../../ui2/shell/karto_test_support.dart';

const _nebel = HeroAdventureEntry(
  id: 'nebel',
  title: 'Die Spuren im Nebel',
  currentAventurianDate: HeroAdventureDateValue(
    day: '7',
    month: 'boron',
    year: '1043',
  ),
);

void main() {
  const adapter = KartoBestandsAdapterImpl();

  late BuildContext kontext;
  late WidgetRef widgetRef;

  Future<
    (
      FakeRepository,
      ProviderContainer,
      void Function(String, {String ortId, double? x, double? y}),
    )
  >
  baue(
    WidgetTester tester, {
    String standort = 'Gareth',
    String standortOrtId = '',
    List<HeroReiseStation> stationen = const <HeroReiseStation>[],
    List<OrtEintrag>? orte,
    bool planOffen = false,
  }) async {
    final held = testHero().copyWith(
      adventures: const [_nebel],
      reiseStationen: stationen,
    );
    final repo = FakeRepository(
      heroes: [held],
      states: {
        'rondra': const HeroState.empty().copyWith(
          standort: standort,
          standortOrtId: standortOrtId,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        if (orte != null) ortsverzeichnisProvider.overrideWithValue(orte),
      ],
    );
    addTearDown(container.dispose);
    if (planOffen) {
      container
          .read(advancementSessionProvider('rondra').notifier)
          .start(hero: held, catalog: testCatalog);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                kontext = context;
                widgetRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    void setze(String neu, {String ortId = '', double? x, double? y}) {
      adapter.standortSetzen(
        context: kontext,
        ref: widgetRef,
        heroId: 'rondra',
        standort: neu,
        ortId: ortId,
        kartenX: x,
        kartenY: y,
      );
    }

    return (repo, container, setze);
  }

  testWidgets('ein Ortswechsel legt eine Station der Reiseroute an', (
    tester,
  ) async {
    final (repo, _, setze) = await baue(tester);

    setze('Havena');
    await tester.pumpAndSettle();

    final zustand = await repo.loadHeroState('rondra');
    expect(zustand!.standort, 'Havena');
    final held = await repo.loadHeroById('rondra');
    final station = held!.reiseStationen.single;
    expect(station.ort, 'Havena');
    expect(station.adventureId, 'nebel');
    expect(station.datum.year, '1043');
  });

  testWidgets('derselbe Ort und das Entfernen legen keine Station an', (
    tester,
  ) async {
    final (repo, _, setze) = await baue(tester);

    setze('Gareth');
    await tester.pumpAndSettle();
    setze('');
    await tester.pumpAndSettle();

    final held = await repo.loadHeroById('rondra');
    expect(held!.reiseStationen, isEmpty);
    expect((await repo.loadHeroState('rondra'))!.standort, isEmpty);
  });

  testWidgets('zweimal derselbe neue Ort ergibt eine Station', (tester) async {
    final (repo, _, setze) = await baue(tester);

    setze('Havena');
    await tester.pumpAndSettle();
    setze('Gareth');
    await tester.pumpAndSettle();
    setze('Gareth');
    await tester.pumpAndSettle();

    final held = await repo.loadHeroById('rondra');
    expect([for (final s in held!.reiseStationen) s.ort], ['Havena', 'Gareth']);
  });

  testWidgets('während einer Planung bleibt der Standort, die Station fehlt', (
    tester,
  ) async {
    final (repo, _, setze) = await baue(tester, planOffen: true);

    setze('Havena');
    await tester.pumpAndSettle();

    expect((await repo.loadHeroState('rondra'))!.standort, 'Havena');
    expect((await repo.loadHeroById('rondra'))!.reiseStationen, isEmpty);
    expect(
      find.textContaining('Standort gespeichert, Reiseroute nicht ergänzt'),
      findsOneWidget,
    );
  });

  group('Verweis am Standort', () {
    OrtEintrag ort(String name, String id, double x) => OrtEintrag(
      name: name,
      art: OrtArt.siedlung,
      ortId: id,
      kartenX: x,
      kartenY: 1,
    );
    final orte = <OrtEintrag>[
      ort('Gareth', 'g', 1),
      ort('Kronling', 'k1', 2),
      ort('Kronling', 'k2', 3),
    ];

    testWidgets('die gewählte Kennung landet am Standort und an der Station', (
      tester,
    ) async {
      final (repo, _, setze) = await baue(tester, orte: orte);

      setze('Kronling', ortId: 'k2');
      await tester.pumpAndSettle();

      final zustand = (await repo.loadHeroState('rondra'))!;
      expect(zustand.standort, 'Kronling');
      expect(zustand.standortOrtId, 'k2');
      final station = (await repo.loadHeroById('rondra'))!
          .reiseStationen
          .single;
      expect(station.ortId, 'k2');
      expect(station.kartenX, 3);
    });

    testWidgets('ein eindeutiger Name verknüpft ohne Auswahl', (tester) async {
      final (repo, _, setze) = await baue(
        tester,
        standort: 'Kronling',
        standortOrtId: 'k1',
        orte: orte,
      );

      setze('Gareth');
      await tester.pumpAndSettle();
      expect((await repo.loadHeroState('rondra'))!.standortOrtId, 'g');

      // Mehrdeutig und ohne Auswahl: kein Verweis.
      setze('Kronling');
      await tester.pumpAndSettle();
      expect((await repo.loadHeroState('rondra'))!.standortOrtId, isEmpty);
    });

    testWidgets('gleicher Name ohne Verzeichnis behält den Verweis', (
      tester,
    ) async {
      final (repo, _, setze) = await baue(
        tester,
        standort: 'Kronling',
        standortOrtId: 'k2',
        orte: const <OrtEintrag>[],
      );

      setze(' Kronling ');
      await tester.pumpAndSettle();
      expect((await repo.loadHeroState('rondra'))!.standortOrtId, 'k2');

      setze('Havena');
      await tester.pumpAndSettle();
      final zustand = (await repo.loadHeroState('rondra'))!;
      expect(zustand.standort, 'Havena');
      expect(zustand.standortOrtId, isEmpty);
    });

    testWidgets('unverändertes Speichern behält den gewählten Ort', (
      tester,
    ) async {
      // „Gareth“ ist im Verzeichnis eindeutig (g); gespeichert ist aber ein
      // gewählter Ort, den das Verzeichnis nicht kennt.
      final (repo, _, setze) = await baue(
        tester,
        standort: 'Gareth',
        standortOrtId: 'online-g',
        orte: orte,
      );

      setze('Gareth');
      await tester.pumpAndSettle();
      expect((await repo.loadHeroState('rondra'))!.standortOrtId, 'online-g');
    });

    testWidgets('eine Wahl außerhalb des Verzeichnisses trägt ihre Position '
        'in die Station', (tester) async {
      final (repo, _, setze) = await baue(tester, orte: orte);

      // Gleichnamig mit k1/k2, aber ein dritter Ort (etwa aus der
      // Online-Suche).
      setze('Kronling', ortId: 'k3', x: 9, y: 8);
      await tester.pumpAndSettle();

      expect((await repo.loadHeroState('rondra'))!.standortOrtId, 'k3');
      final station = (await repo.loadHeroById('rondra'))!
          .reiseStationen
          .single;
      expect(station.ortId, 'k3');
      expect(station.kartenX, 9);
      expect(station.kartenY, 8);
    });

    testWidgets(
      'ein Wechsel zwischen gleichnamigen Orten legt eine Station an',
      (tester) async {
        final (repo, _, setze) = await baue(
          tester,
          standort: 'Kronling',
          standortOrtId: 'k1',
          orte: orte,
        );

        setze('Kronling', ortId: 'k2');
        await tester.pumpAndSettle();

        expect((await repo.loadHeroState('rondra'))!.standortOrtId, 'k2');
        final station = (await repo.loadHeroById('rondra'))!
            .reiseStationen
            .single;
        expect(station.ortId, 'k2');
      },
    );

    testWidgets('eine Kennung gilt auch ohne geladenes Verzeichnis', (
      tester,
    ) async {
      // Etwa ein gewählter Treffer der Online-Suche.
      final (repo, _, setze) = await baue(tester, orte: const <OrtEintrag>[]);

      setze('Havena', ortId: 'h');
      await tester.pumpAndSettle();
      expect((await repo.loadHeroState('rondra'))!.standortOrtId, 'h');

      setze('');
      await tester.pumpAndSettle();
      final zustand = (await repo.loadHeroState('rondra'))!;
      expect(zustand.standort, isEmpty);
      expect(zustand.standortOrtId, isEmpty);
    });

    testWidgets('eine Reise schreibt den Verweis des Ziels mit', (
      tester,
    ) async {
      final (repo, _, _) = await baue(
        tester,
        standort: 'Gareth',
        standortOrtId: 'g',
        orte: orte,
      );

      // Aufbrechen: Standort und Verweis bleiben.
      await adapter.reiseZustandSetzen(
        context: kontext,
        ref: widgetRef,
        heroId: 'rondra',
        unterwegs: const HeroUnterwegs(ziel: 'Kronling'),
      );
      await tester.pumpAndSettle();
      var zustand = (await repo.loadHeroState('rondra'))!;
      expect(zustand.standortOrtId, 'g');

      // Ankommen: neuer Standort mit dem Verweis des Ziels.
      await adapter.reiseZustandSetzen(
        context: kontext,
        ref: widgetRef,
        heroId: 'rondra',
        unterwegs: null,
        standort: 'Kronling',
        standortOrtId: 'k2',
      );
      await tester.pumpAndSettle();
      zustand = (await repo.loadHeroState('rondra'))!;
      expect(zustand.standort, 'Kronling');
      expect(zustand.standortOrtId, 'k2');

      // Anhalten an einer Rast: kein Verweis.
      await adapter.reiseZustandSetzen(
        context: kontext,
        ref: widgetRef,
        heroId: 'rondra',
        unterwegs: null,
        standort: 'Rast bei Kronling',
      );
      await tester.pumpAndSettle();
      zustand = (await repo.loadHeroState('rondra'))!;
      expect(zustand.standortOrtId, isEmpty);
    });
  });
}
