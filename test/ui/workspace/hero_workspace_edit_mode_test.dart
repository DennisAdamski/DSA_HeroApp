import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

void main() {
  HeroSheet buildHero() {
    return const HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      rawStartAttributes: Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 13,
      ),
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
    RulesCatalog? catalog,
  }) async {
    if (size != null) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          if (catalog != null)
            rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
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

  Finder heroDeckToggleButton() {
    return find.byKey(const ValueKey<String>('hero-deck-toggle'));
  }

  Finder workspaceDetailsToggleButton() {
    return find.byKey(const ValueKey<String>('workspace-details-toggle'));
  }

  RulesCatalog buildCatalog() {
    return const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[
        TalentDef(
          id: 'tal_a',
          name: 'Athletik',
          group: 'Koerper',
          steigerung: 'C',
          attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
        ),
      ],
      spells: <SpellDef>[],
      weapons: <WeaponDef>[],
    );
  }

  testWidgets('overview edit/save persists AP fields and name', (tester) async {
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
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final apTotalField = find.byKey(
      const ValueKey<String>('overview-field-ap_total'),
    );
    final apSpentField = find.byKey(
      const ValueKey<String>('overview-field-ap_spent'),
    );
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
  });

  testWidgets('overview AP add actions update editable AP fields', (
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

    await openWorkspace(tester, repo);

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final apTotalField = find.byKey(
      const ValueKey<String>('overview-field-ap_total'),
    );
    final apTotalAddField = find.byKey(
      const ValueKey<String>('overview-field-ap_total_add'),
    );
    final apSpentAddField = find.byKey(
      const ValueKey<String>('overview-field-ap_spent_add'),
    );
    await tester.scrollUntilVisible(
      apTotalField,
      240,
      scrollable: verticalScrollable.first,
    );

    final totalAddWidget = tester.widget<TextField>(apTotalAddField);
    final spentAddWidget = tester.widget<TextField>(apSpentAddField);
    expect(totalAddWidget.controller?.text, isEmpty);
    expect(spentAddWidget.controller?.text, isEmpty);
    expect(
      totalAddWidget.inputFormatters?.any(
        (formatter) => formatter is FilteringTextInputFormatter,
      ),
      isTrue,
    );
    expect(
      spentAddWidget.inputFormatters?.any(
        (formatter) => formatter is FilteringTextInputFormatter,
      ),
      isTrue,
    );

    await tester.enterText(apTotalAddField, '200');
    final apTotalAddAction = find.byKey(
      const ValueKey<String>('overview-action-ap_total_add'),
    );
    final apTotalAddButton = tester.widget<IconButton>(apTotalAddAction);
    expect(apTotalAddButton.onPressed, isNotNull);
    apTotalAddButton.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.enterText(apSpentAddField, '300');
    final apSpentAddAction = find.byKey(
      const ValueKey<String>('overview-action-ap_spent_add'),
    );
    final apSpentAddButton = tester.widget<IconButton>(apSpentAddAction);
    expect(apSpentAddButton.onPressed, isNotNull);
    apSpentAddButton.onPressed!.call();
    await tester.pumpAndSettle();

    final apTotalAfter = tester.widget<TextField>(apTotalField);
    final apSpentAfter = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('overview-field-ap_spent')),
    );
    expect(apTotalAfter.controller?.text, '1200');
    expect(apSpentAfter.controller?.text, '800');
    expect(tester.widget<TextField>(apTotalAddField).controller?.text, isEmpty);
    expect(tester.widget<TextField>(apSpentAddField).controller?.text, isEmpty);

    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = findHeroById(heroes, 'demo');
    expect(hero, isNotNull);
    expect(hero!.apTotal, 1200);
    expect(hero.apSpent, 800);
  });

  testWidgets(
    'talents tab shows catalog actions in upper workspace bar while editing',
    (tester) async {
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

      await openWorkspace(tester, repo, catalog: buildCatalog());
      await tester.tap(tabText('Talente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bearbeiten').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('talents-catalog-open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('meta-talents-manage-open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('talents-be-screen-open')),
        findsOneWidget,
      );
    },
  );

  testWidgets('overview edit/save persists attribute changes and temp mods', (
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

    await openWorkspace(tester, repo);

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final muField = find.byKey(const ValueKey<String>('overview-field-mu'));
    final muTempField = find.byKey(
      const ValueKey<String>('overview-field-mu_temp'),
    );
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

  testWidgets(
    'overview temp attribute mod is editable and saved on submit without edit mode',
    (tester) async {
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

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final muTempField = find.byKey(
        const ValueKey<String>('overview-field-mu_temp'),
      );
      final muEffective = find.byKey(
        const ValueKey<String>('overview-effective-mu'),
      );
      await tester.scrollUntilVisible(
        muTempField,
        240,
        scrollable: verticalScrollable.first,
      );

      final before = tester.widget<TextField>(muTempField);
      expect(before.readOnly, isFalse);
      expect(find.text('Bearbeiten'), findsOneWidget);
      expect(find.text('Speichern'), findsNothing);
      expect(find.text('Abbrechen'), findsNothing);

      await tester.tap(muTempField);
      await tester.pump();
      await tester.enterText(muTempField, '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.tempAttributeMods.mu, 3);
      expect(tester.widget<TextField>(muTempField).controller?.text, '3');
      expect(
        find.descendant(of: muEffective, matching: find.text('17')),
        findsOne,
      );
      expect(find.text('Bearbeiten'), findsOneWidget);
      expect(find.text('Speichern'), findsNothing);
      expect(find.text('Abbrechen'), findsNothing);
    },
  );

  testWidgets(
    'overview temp attribute mod saves on focus loss and clamps invalid values',
    (tester) async {
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

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final muTempField = find.byKey(
        const ValueKey<String>('overview-field-mu_temp'),
      );
      final muEffective = find.byKey(
        const ValueKey<String>('overview-effective-mu'),
      );
      await tester.scrollUntilVisible(
        muTempField,
        240,
        scrollable: verticalScrollable.first,
      );

      await tester.tap(muTempField);
      await tester.pump();
      await tester.enterText(muTempField, '150');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      var state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.tempAttributeMods.mu, 99);
      expect(tester.widget<TextField>(muTempField).controller?.text, '99');
      expect(
        find.descendant(of: muEffective, matching: find.text('113')),
        findsOne,
      );
      expect(find.text('Speichern'), findsNothing);

      await tester.tap(muTempField);
      await tester.pump();
      await tester.enterText(muTempField, '-150');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.tempAttributeMods.mu, -99);
      expect(tester.widget<TextField>(muTempField).controller?.text, '-99');
      expect(
        find.descendant(of: muEffective, matching: find.text('-85')),
        findsOne,
      );

      await tester.tap(muTempField);
      await tester.pump();
      await tester.enterText(muTempField, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.tempAttributeMods.mu, 0);
      expect(tester.widget<TextField>(muTempField).controller?.text, '0');
      expect(
        find.descendant(of: muEffective, matching: find.text('14')),
        findsOne,
      );
      expect(find.text('Speichern'), findsNothing);
      expect(find.text('Abbrechen'), findsNothing);
    },
  );

  testWidgets(
    'overview shows start and max values and recomputes them from origin mods',
    (tester) async {
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

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final startKl = find.byKey(
        const ValueKey<String>('overview-effective-kl_start'),
      );
      final maxKl = find.byKey(
        const ValueKey<String>('overview-effective-kl_max'),
      );
      await tester.scrollUntilVisible(
        startKl,
        240,
        scrollable: verticalScrollable.first,
      );

      expect(find.descendant(of: startKl, matching: find.text('12')), findsOne);
      expect(find.descendant(of: maxKl, matching: find.text('18')), findsOne);

      await tester.tap(find.text('Bearbeiten').first);
      await tester.pumpAndSettle();
      await tester.drag(verticalScrollable.first, const Offset(0, 1200));
      await tester.pumpAndSettle();

      final rasseModField = find.byKey(
        const ValueKey<String>('overview-field-rasse_mod'),
      );
      expect(rasseModField, findsOneWidget);
      await tester.enterText(rasseModField, 'KL+1');
      await tester.tap(find.text('Speichern').first);
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = findHeroById(heroes, 'demo');
      expect(hero, isNotNull);
      expect(hero!.attributes.kl, 12);
      expect(hero.startAttributes.kl, 13);

      await tester.scrollUntilVisible(
        startKl,
        240,
        scrollable: verticalScrollable.first,
      );
      expect(find.descendant(of: startKl, matching: find.text('13')), findsOne);
      expect(find.descendant(of: maxKl, matching: find.text('20')), findsOne);
    },
  );

  testWidgets(
    'overview edit/save persists bought values and current resources',
    (tester) async {
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
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final boughtLepField = find.byKey(
        const ValueKey<String>('overview-derived-bought-b_lep'),
      );
      final currentKapField = find.byKey(
        const ValueKey<String>('overview-field-cur_kap'),
      );

      await tester.scrollUntilVisible(
        currentKapField,
        240,
        scrollable: verticalScrollable.first,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('overview-field-cur_lep')),
        '17',
      );
      await tester.enterText(currentKapField, '4');

      await tester.scrollUntilVisible(
        boughtLepField,
        240,
        scrollable: verticalScrollable.first,
      );
      await tester.enterText(boughtLepField, '3');
      await tester.enterText(
        find.byKey(const ValueKey<String>('overview-derived-bought-b_mr')),
        '2',
      );

      await tester.tap(find.text('Speichern').first);
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = findHeroById(heroes, 'demo');
      expect(hero, isNotNull);
      expect(hero!.bought.lep, 3);
      expect(hero.bought.mr, 2);

      final state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.currentLep, 17);
      expect(state.currentKap, 4);
    },
  );

  testWidgets(
    'header resources show current and max values after overview save',
    (tester) async {
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
      expect(find.text('LEP: 10/22'), findsOneWidget);
      expect(find.text('BE: 0'), findsOneWidget);

      await tester.tap(find.text('Bearbeiten').first);
      await tester.pumpAndSettle();

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final boughtLepField = find.byKey(
        const ValueKey<String>('overview-derived-bought-b_lep'),
      );
      final currentLepField = find.byKey(
        const ValueKey<String>('overview-field-cur_lep'),
      );
      await tester.scrollUntilVisible(
        currentLepField,
        240,
        scrollable: verticalScrollable.first,
      );
      await tester.enterText(currentLepField, '15');
      await tester.scrollUntilVisible(
        boughtLepField,
        240,
        scrollable: verticalScrollable.first,
      );
      await tester.enterText(boughtLepField, '2');

      await tester.tap(find.text('Speichern').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('LEP: 15/'), findsOneWidget);
    },
  );

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
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
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

    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('overview-field-name')),
    );
    expect(nameField.controller?.text, 'Rondra');
  });

  testWidgets('global action is disabled on non-edit tabs (Notizen)', (
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

    await openWorkspace(tester, repo);
    await tester.tap(tabText('Notizen'));
    await tester.pump(const Duration(milliseconds: 1200));

    final disabledButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Bearbeiten'),
    );
    expect(disabledButton.onPressed, isNull);
  });

  testWidgets(
    'workspace appbar actions keep right spacing and edit action on the right',
    (tester) async {
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

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final actions = appBar.actions ?? const <Widget>[];
      expect(actions.first, isA<SizedBox>());
      expect((actions.first as SizedBox).width, 8);
      expect(actions.last, isA<SizedBox>());
      expect((actions.last as SizedBox).width, 12);
      expect(find.text('Bearbeiten'), findsOneWidget);
    },
  );

  testWidgets('dirty tab switch keeps overview values when not discarded', (
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

    await openWorkspace(tester, repo);
    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Nicht speichern',
    );

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 220));

    if (find.textContaining('Ungespeicherte').evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'Nein'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Basisinformationen'), findsOneWidget);
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('overview-field-name')),
    );
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

  testWidgets('overview switches between two and one column layouts', (
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

    await openWorkspace(tester, repo, size: const Size(1024, 1400));

    final nameFinder = find.byKey(
      const ValueKey<String>('overview-field-name'),
    );
    final rasseFinder = find.byKey(
      const ValueKey<String>('overview-field-rasse'),
    );
    final rasseModFinder = find.byKey(
      const ValueKey<String>('overview-field-rasse_mod'),
    );

    final nameWide = tester.getTopLeft(nameFinder).dy;
    final rasseWide = tester.getTopLeft(rasseFinder).dy;
    final rasseModWide = tester.getTopLeft(rasseModFinder);
    expect((nameWide - rasseWide).abs(), greaterThan(4));
    expect(
      (tester.getTopLeft(rasseFinder).dy - rasseModWide.dy).abs(),
      lessThan(1),
    );

    tester.view.physicalSize = const Size(390, 1400);
    await tester.pumpAndSettle();

    final nameNarrow = tester.getTopLeft(nameFinder).dy;
    final rasseNarrow = tester.getTopLeft(rasseFinder).dy;
    final rasseModNarrow = tester.getTopLeft(rasseModFinder).dy;
    expect((nameNarrow - rasseNarrow).abs(), greaterThan(4));
    expect((rasseNarrow - rasseModNarrow).abs(), greaterThan(4));
  });

  testWidgets('wide workspace shows Helden Deck instead of TabBar', (
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

    await openWorkspace(tester, repo, size: const Size(1600, 1200));

    expect(find.text('Helden Deck'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Inspector'), findsNothing);
    expect(find.text('Ressourcen'), findsOneWidget);
    expect(heroDeckToggleButton(), findsOneWidget);
    expect(workspaceDetailsToggleButton(), findsOneWidget);
  });

  testWidgets('wide workspace can collapse and expand Helden Deck', (
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

    await openWorkspace(tester, repo, size: const Size(1600, 1200));

    expect(find.text('Helden Deck'), findsOneWidget);
    expect(find.text('Uebersicht'), findsWidgets);
    expect(find.text('Ressourcen'), findsOneWidget);

    await tester.tap(heroDeckToggleButton());
    await tester.pumpAndSettle();

    expect(find.text('Helden Deck'), findsNothing);
    expect(find.byTooltip('Helden-Deck einblenden'), findsOneWidget);
    expect(find.text('Uebersicht'), findsNothing);
    expect(find.text('Ressourcen'), findsOneWidget);
    expect(find.text('Basisinformationen'), findsOneWidget);

    await tester.tap(heroDeckToggleButton());
    await tester.pumpAndSettle();

    expect(find.text('Helden Deck'), findsOneWidget);
    expect(find.byTooltip('Helden-Deck ausblenden'), findsOneWidget);
    expect(find.text('Uebersicht'), findsWidgets);
  });

  testWidgets('wide workspace can collapse and expand right details panel', (
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

    await openWorkspace(tester, repo, size: const Size(1600, 1200));

    expect(find.text('Inspector'), findsNothing);
    expect(find.text('Ressourcen'), findsOneWidget);
    expect(workspaceDetailsToggleButton(), findsOneWidget);

    await tester.tap(workspaceDetailsToggleButton());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Details einblenden'), findsOneWidget);
    expect(find.text('Ressourcen'), findsNothing);
    expect(find.text('Kampfwerte'), findsNothing);
    expect(find.text('Basisinformationen'), findsOneWidget);
    expect(find.text('Helden Deck'), findsOneWidget);

    await tester.tap(workspaceDetailsToggleButton());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Details ausblenden'), findsOneWidget);
    expect(find.text('Ressourcen'), findsOneWidget);
    expect(find.text('Kampfwerte'), findsOneWidget);
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
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final attributesHeader = find.text('Eigenschaften');
    final derivedHeader = find.text('Basiswerte');

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

    final attributesCard = find
        .ancestor(of: attributesHeader, matching: find.byType(Card))
        .first;
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
