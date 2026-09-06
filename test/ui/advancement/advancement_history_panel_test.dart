import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_history_panel.dart';

void main() {
  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [],
    spells: [],
    weapons: [],
  );
  const hero = HeroSheet(
    id: 'hero',
    name: 'Rondra',
    level: 1,
    attributes: Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    apTotal: 2000,
    apAvailable: 2000,
  );

  HeroAdvancementEntry entry(String id, String sessionId) =>
      HeroAdvancementEntry(
        id: id,
        sessionId: sessionId,
        createdAt: DateTime.utc(2026, 9, 5),
        kind: AdvancementKind.attribute,
        targetId: 'mu',
        label: 'Mut',
        fromValue: 12,
        toValue: 13,
        apCost: 100,
      );

  Future<void> pumpPanel(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: AdvancementHistoryPanel(heroId: 'hero'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'only current history rows offer removal at narrow inspector width',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        advancementSessionProvider('hero').notifier,
      );
      controller.start(
        hero: hero.copyWith(advancementHistory: [entry('fixed', 'old')]),
        catalog: catalog,
      );
      final sessionId = container
          .read(advancementSessionProvider('hero'))!
          .sessionId;
      controller.add(entry('pending', sessionId));
      await pumpPanel(tester, container);
      expect(
        find.byKey(const ValueKey('advancement-remove-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('advancement-remove-fixed')),
        findsNothing,
      );
      expect(find.text('Reserviert'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('advancement-remove-pending')),
      );
      await tester.pumpAndSettle();
      final session = container.read(advancementSessionProvider('hero'))!;
      expect(session.entries, isEmpty);
      expect(session.base.advancementHistory.single.id, 'fixed');
    },
  );

  testWidgets('empty pending history explains that values are not saved yet', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(advancementSessionProvider('hero').notifier)
        .start(hero: hero, catalog: catalog);
    await pumpPanel(tester, container);
    expect(find.text('Noch keine Steigerungen geplant.'), findsOneWidget);
    expect(find.textContaining('Erst beim Übernehmen'), findsOneWidget);
  });
}
