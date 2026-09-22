import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_history_panel.dart';
import 'package:dsa_heldenverwaltung/ui2/entwicklung/karto_entwicklungsansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_workspace.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/karto_test_support.dart';

void main() {
  Future<ProviderContainer> pumpPlan(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    bool workspace = false,
    _CountingRepository? repository,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repo = repository ?? _CountingRepository(heroes: [testHero()]);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    if (!workspace) {
      container
          .read(advancementSessionProvider('rondra').notifier)
          .start(hero: testHero(), catalog: testCatalog);
    }
    final child = workspace
        ? KartoWorkspace(heroId: 'rondra', bestand: _PlanBestand())
        : KartoEntwicklungsansicht(heroId: 'rondra', bestand: _PlanBestand());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('zeigt direkte AP-Werte und mobile Planung im Detail-Sheet', (
    tester,
  ) async {
    await pumpPlan(tester, size: const Size(390, 900));

    expect(find.text('Frei zu Beginn: 500 AP'), findsOneWidget);
    expect(find.text('Reserviert: 0 AP'), findsOneWidget);
    expect(find.text('Danach verfügbar: 500 AP'), findsOneWidget);
    expect(find.byType(AdvancementHistoryPanel), findsNothing);

    await tester.tap(find.text('AP und Historie'));
    await tester.pumpAndSettle();

    expect(find.byType(AdvancementHistoryPanel), findsOneWidget);
    expect(find.text('Laufende Runde'), findsOneWidget);
  });

  testWidgets('Katalogaktion bleibt bei großer Schrift erreichbar', (
    tester,
  ) async {
    await pumpPlan(tester, size: const Size(320, 760), textScale: 2);
    final action = find.byKey(const ValueKey('advancement-plan-attribute-mu'));

    await tester.scrollUntilVisible(
      action,
      180,
      scrollable: find
          .descendant(
            of: find.byType(AdvancementCatalog),
            matching: find.byType(Scrollable),
          )
          .last,
    );

    expect(action, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'übernimmt eine vorgemerkte Änderung über den echten Controller',
    (tester) async {
      final repository = _CountingRepository(heroes: [testHero()]);
      final container = await pumpPlan(
        tester,
        size: const Size(1440, 1000),
        workspace: true,
        repository: repository,
      );
      await tester.tap(find.byTooltip('Entwicklung planen').first);
      await tester.pumpAndSettle();
      final provider = advancementSessionProvider('rondra');
      final sessionId = container.read(provider)!.sessionId;
      container
          .read(provider.notifier)
          .add(
            HeroAdvancementEntry(
              id: 'mu-15',
              sessionId: sessionId,
              createdAt: DateTime.utc(2026, 9, 21),
              kind: AdvancementKind.attribute,
              targetId: 'mu',
              label: 'Mut',
              fromValue: 14,
              toValue: 15,
              apCost: 100,
            ),
          );
      await tester.pumpAndSettle();
      expect((await repository.loadHeroById('rondra'))!.attributes.mu, 14);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Änderungen übernehmen'),
      );
      await tester.pumpAndSettle();

      expect(repository.writes, 1);
      expect((await repository.loadHeroById('rondra'))!.attributes.mu, 15);
      expect(container.read(provider), isNull);
      expect(find.text('Entwicklung übernommen.'), findsOneWidget);
    },
  );
}

class _PlanBestand extends TestBestand {
  @override
  Widget planKatalog(String heroId) => AdvancementCatalog(heroId: heroId);

  @override
  Widget planHistorie(String heroId) => AdvancementHistoryPanel(heroId: heroId);
}

class _CountingRepository extends FakeRepository {
  _CountingRepository({required super.heroes});

  int writes = 0;

  @override
  Future<void> saveHero(HeroSheet hero) async {
    await super.saveHero(hero);
    writes++;
  }
}
