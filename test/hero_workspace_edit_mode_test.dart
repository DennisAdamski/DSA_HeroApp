import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

void main() {
  HeroSheet buildHero() {
    return const HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 13,
      ),
      rasse: 'Mensch',
      kultur: 'Mittelreich',
      profession: 'Kriegerin',
      sozialstatus: 7,
      apTotal: 1000,
      apSpent: 500,
      apAvailable: 500,
    );
  }

  Future<void> openWorkspace(
    WidgetTester tester,
    FakeRepository repo, {
    Size? size,
  }) async {
    if (size != null) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rondra'));
    await tester.pumpAndSettle();
  }

  HeroSheet? findHeroById(List<HeroSheet> heroes, String id) {
    for (final hero in heroes) {
      if (hero.id == id) {
        return hero;
      }
    }
    return null;
  }

  Finder tabText(String label) {
    return find.descendant(of: find.byType(TabBar), matching: find.text(label));
  }

  testWidgets('overview edit/save persists values and derived AP+level', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo);

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();
    expect(find.text('Speichern'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Rondra Neu',
    );

    final verticalScrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final apTotalField = find.byKey(const ValueKey<String>('overview-field-ap_total'));
    final apSpentField = find.byKey(const ValueKey<String>('overview-field-ap_spent'));
    await tester.scrollUntilVisible(
      apTotalField,
      240,
      scrollable: verticalScrollable.first,
    );
    await tester.enterText(apTotalField, '1200');
    await tester.enterText(apSpentField, '50');

    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = findHeroById(heroes, 'demo');
    expect(hero, isNotNull);
    expect(hero!.name, 'Rondra Neu');
    expect(hero.apTotal, 1200);
    expect(hero.apSpent, 50);
    expect(hero.apAvailable, 1150);
    expect(hero.level, 2);
  });

  testWidgets('overview edit/save persists attribute changes and temp mods', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo);

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final muField = find.byKey(const ValueKey<String>('overview-field-mu'));
    final muTempField = find.byKey(const ValueKey<String>('overview-field-mu_temp'));
    await tester.scrollUntilVisible(
      muField,
      240,
      scrollable: verticalScrollable.first,
    );
    await tester.enterText(muField, '16');
    await tester.enterText(muTempField, '2');

    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = findHeroById(heroes, 'demo');
    expect(hero, isNotNull);
    expect(hero!.attributes.mu, 16);
    final state = await repo.loadHeroState('demo');
    expect(state, isNotNull);
    expect(state!.tempAttributeMods.mu, 2);
  });

  testWidgets('overview clamps attribute values to 0..99', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo);

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final muField = find.byKey(const ValueKey<String>('overview-field-mu'));
    final klField = find.byKey(const ValueKey<String>('overview-field-kl'));
    await tester.scrollUntilVisible(
      muField,
      240,
      scrollable: verticalScrollable.first,
    );
    await tester.enterText(muField, '-5');
    await tester.enterText(klField, '120');

    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = findHeroById(heroes, 'demo');
    expect(hero, isNotNull);
    expect(hero!.attributes.mu, 0);
    expect(hero.attributes.kl, 99);
  });

  testWidgets('overview cancel discards local changes', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo);

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();
    expect(find.text('Speichern'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Temp Name',
    );
    await tester.tap(find.text('Abbrechen').first);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = findHeroById(heroes, 'demo');
    expect(hero, isNotNull);
    expect(hero!.name, 'Rondra');

    final nameField =
        tester.widget<TextField>(find.byKey(const ValueKey<String>('overview-field-name')));
    expect(nameField.controller?.text, 'Rondra');
  });

  testWidgets('global action is disabled on non-edit tabs', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo);
    await tester.tap(tabText('Talente'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('In diesem Tab noch nicht verfügbar'), findsOneWidget);
    final disabledButton =
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Bearbeiten'));
    expect(disabledButton.onPressed, isNull);
  });

  testWidgets('dirty tab switch keeps overview values when not discarded', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo);
    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Nicht speichern',
    );

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    if (find.textContaining('Ungespeicherte').evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'Nein'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Basisinformationen'), findsOneWidget);
    final nameField =
        tester.widget<TextField>(find.byKey(const ValueKey<String>('overview-field-name')));
    expect(nameField.controller?.text, 'Nicht speichern');
  });

  testWidgets('dirty guard intercepts back navigation', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo);
    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();
    expect(find.text('Speichern'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Nicht speichern',
    );

    await tester.tap(find.byTooltip('Heldenauswahl'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ungespeicherte'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Nein'));
    await tester.pumpAndSettle();
    expect(find.text('Basisinformationen'), findsOneWidget);

    await tester.tap(find.byTooltip('Heldenauswahl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ja').first);
    await tester.pumpAndSettle();
    expect(find.text('DSA Helden'), findsOneWidget);
  });

  testWidgets('overview switches between two and one column layouts', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo, size: const Size(1024, 1400));

    final nameFinder = find.byKey(const ValueKey<String>('overview-field-name'));
    final rasseFinder = find.byKey(const ValueKey<String>('overview-field-rasse'));
    final rasseModFinder = find.byKey(const ValueKey<String>('overview-field-rasse_mod'));

    final nameWide = tester.getTopLeft(nameFinder).dy;
    final rasseWide = tester.getTopLeft(rasseFinder).dy;
    final rasseModWide = tester.getTopLeft(rasseModFinder);
    expect((nameWide - rasseWide).abs(), greaterThan(4));
    expect((tester.getTopLeft(rasseFinder).dy - rasseModWide.dy).abs(), lessThan(1));

    tester.view.physicalSize = const Size(390, 1400);
    await tester.pumpAndSettle();

    final nameNarrow = tester.getTopLeft(nameFinder).dy;
    final rasseNarrow = tester.getTopLeft(rasseFinder).dy;
    final rasseModNarrow = tester.getTopLeft(rasseModFinder).dy;
    expect((nameNarrow - rasseNarrow).abs(), greaterThan(4));
    expect((rasseNarrow - rasseModNarrow).abs(), greaterThan(4));
  });

  testWidgets('overview shows attributes and derived in responsive section', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openWorkspace(tester, repo, size: const Size(1200, 1400));

    final verticalScrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final attributesHeader = find.text('Eigenschaften');
    final derivedHeader = find.text('Abgeleitete Werte');

    await tester.scrollUntilVisible(
      attributesHeader,
      240,
      scrollable: verticalScrollable.first,
    );
    await tester.scrollUntilVisible(
      derivedHeader,
      240,
      scrollable: verticalScrollable.first,
    );

    final muField = find.byKey(const ValueKey<String>('overview-field-mu'));
    final klField = find.byKey(const ValueKey<String>('overview-field-kl'));
    await tester.scrollUntilVisible(
      muField,
      240,
      scrollable: verticalScrollable.first,
    );
    await tester.scrollUntilVisible(
      klField,
      240,
      scrollable: verticalScrollable.first,
    );
    final muPosWide = tester.getTopLeft(muField);
    final klPosWide = tester.getTopLeft(klField);
    expect(klPosWide.dy, greaterThan(muPosWide.dy));
    expect(klPosWide.dy - muPosWide.dy, lessThan(80));

    final attributesWide = tester.getTopLeft(attributesHeader);
    final derivedWide = tester.getTopLeft(derivedHeader);
    expect((attributesWide.dy - derivedWide.dy).abs(), lessThan(24));
    expect(attributesWide.dx, lessThan(derivedWide.dx));

    tester.view.physicalSize = const Size(390, 1400);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      attributesHeader,
      240,
      scrollable: verticalScrollable.first,
    );
    await tester.scrollUntilVisible(
      derivedHeader,
      240,
      scrollable: verticalScrollable.first,
    );

    final attributesCard = find.ancestor(
      of: attributesHeader,
      matching: find.byType(Card),
    ).first;
    final horizontalScrollInAttributes = find.descendant(
      of: attributesCard,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
    );
    expect(horizontalScrollInAttributes, findsOneWidget);

    final attributesNarrow = tester.getTopLeft(attributesHeader);
    final derivedNarrow = tester.getTopLeft(derivedHeader);
    expect(attributesNarrow.dy, lessThan(derivedNarrow.dy));
    expect((attributesNarrow.dx - derivedNarrow.dx).abs(), lessThan(24));
  });
}
