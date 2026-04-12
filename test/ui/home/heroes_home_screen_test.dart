import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  final hero = HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: const Attributes(
      mu: 14,
      kl: 12,
      inn: 13,
      ch: 11,
      ff: 10,
      ge: 12,
      ko: 14,
      kk: 13,
    ),
  );

  List<String> expectedWorkspaceTabLabels() {
    return visibleWorkspaceTabsForHero(
      hero: hero,
      tabs: buildWorkspaceTabs(
        heroId: 'demo',
        callbacksForTab: (_) => const WorkspaceTabCallbacks(
          onDirtyChanged: _noopBool,
          onEditingChanged: _noopBool,
          onRegisterDiscard: _noopDiscard,
          onRegisterEditActions: _noopEditActions,
        ),
      ),
    ).map((tab) => tab.label).toList(growable: false);
  }

  testWidgets('shows hero picker with create action', (tester) async {
    final repo = FakeRepository(
      heroes: [hero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DSA Helden'), findsOneWidget);
    expect(find.text('Rondra'), findsOneWidget);
    expect(find.text('Neuer Held'), findsOneWidget);
  });

  testWidgets('ipad landscape shows hero preview beside the archive', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1194, 834);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeRepository(
      heroes: [hero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heldenarchiv'), findsOneWidget);
    expect(find.text('Held öffnen'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace-back-button')), findsNothing);
  });

  testWidgets('create dialog captures raw start attributes and creates hero', (
    tester,
  ) async {
    final repo = FakeRepository.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ersten Helden anlegen'));
    await tester.pumpAndSettle();

    expect(find.text('Neuen Helden anlegen'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('create-hero-kl')))
          .controller
          ?.text,
      '11',
    );

    await tester.enterText(
      find.byKey(const ValueKey('create-hero-name')),
      'Alrik',
    );
    await tester.enterText(find.byKey(const ValueKey('create-hero-kl')), '13');
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Anlegen'))
        .onPressed!
        .call();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    expect(heroes, hasLength(1));
    expect(heroes.single.name, 'Alrik');
    expect(heroes.single.rawStartAttributes.kl, 13);
    expect(heroes.single.startAttributes.kl, 13);
    expect(find.text('Alrik'), findsWidgets);
  });

  testWidgets(
    'opens hero workspace with tabs and read-only core attributes header',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(700, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeRepository(
        heroes: [hero],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [heroRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: HeroesHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rondra').first);
      await tester.pumpAndSettle();

      final tabLabels = tester
          .widgetList<Tab>(find.byType(Tab))
          .map((tab) => (tab.text ?? '').trim())
          .toList(growable: false);
      expect(tabLabels, expectedWorkspaceTabLabels());
      expect(find.textContaining('MU'), findsWidgets);
      expect(find.textContaining('14'), findsWidgets);
      expect(find.textContaining('LeP'), findsWidgets);
      expect(find.textContaining('10/22'), findsWidgets);
    },
  );
}

void _noopBool(bool value) {}

void _noopDiscard(WorkspaceAsyncAction action) {}

void _noopEditActions(WorkspaceTabEditActions actions) {}
