import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';

void main() {
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
  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [],
    spells: [],
    weapons: [],
  );

  Future<ProviderContainer> open(
    WidgetTester tester,
    FakeRepository repo,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: const MaterialApp(home: HeroWorkspaceScreen(heroId: 'hero')),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HeroWorkspaceScreen));
    return ProviderScope.containerOf(context);
  }

  void plan(ProviderContainer container) {
    final session = container.read(advancementSessionProvider('hero'))!;
    container
        .read(advancementSessionProvider('hero').notifier)
        .add(
          HeroAdvancementEntry(
            id: 'new',
            sessionId: session.sessionId,
            createdAt: DateTime.utc(2026, 9, 5),
            kind: AdvancementKind.attribute,
            targetId: 'mu',
            label: 'Mut',
            fromValue: 12,
            toValue: 13,
            apCost: 100,
          ),
        );
  }

  testWidgets(
    'workspace separates planning, commits once and locks old history',
    (tester) async {
      final repo = FakeRepository(heroes: [hero]);
      final container = await open(tester, repo, const Size(1500, 1100));
      await tester.tap(
        find.byKey(const ValueKey('workspace-start-advancement')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Laufende Runde'), findsOneWidget);
      expect(find.byTooltip('Bearbeiten'), findsNothing);
      expect(find.text('Bearbeiten'), findsNothing);
      plan(container);
      await tester.pumpAndSettle();
      expect((await repo.loadHeroById('hero'))!.attributes.mu, 12);
      await tester.tap(
        find.byKey(const ValueKey('workspace-commit-advancement')),
      );
      await tester.pumpAndSettle();
      final saved = (await repo.loadHeroById('hero'))!;
      expect(saved.attributes.mu, 13);
      expect(saved.advancementHistory.single.id, 'new');
      await tester.tap(find.widgetWithText(FilledButton, 'Bearbeiten'));
      await tester.pumpAndSettle();
      final muField = find.byKey(const ValueKey('overview-field-mu'));
      // Die Uebersicht baut ihre Abschnitte lazy: erst scrollen, dann tippen.
      await tester.scrollUntilVisible(
        muField,
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('hero-overview-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(muField, '14');
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();
      final corrected = (await repo.loadHeroById('hero'))!;
      expect(corrected.attributes.mu, 14);
      expect(corrected.apSpent, saved.apSpent);
      expect(corrected.advancementHistory.single.id, 'new');
      await tester.tap(
        find.byKey(const ValueKey('workspace-start-advancement')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('advancement-remove-new')),
        findsNothing,
      );
      expect(find.byTooltip('Bereits übernommen'), findsWidgets);
    },
  );

  testWidgets(
    'compact workspace exposes inspector and discards without saving',
    (tester) async {
      final repo = FakeRepository(heroes: [hero]);
      final container = await open(tester, repo, const Size(390, 844));
      await tester.tap(
        find.byKey(const ValueKey('workspace-start-advancement')),
      );
      await tester.pumpAndSettle();
      plan(container);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Detailpanel'));
      await tester.pumpAndSettle();
      expect(find.text('Laufende Runde'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-details-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('workspace-cancel-advancement')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verwerfen'));
      await tester.pumpAndSettle();
      final saved = (await repo.loadHeroById('hero'))!;
      expect(saved.attributes.mu, 12);
      expect(saved.advancementHistory, isEmpty);
    },
  );
}
