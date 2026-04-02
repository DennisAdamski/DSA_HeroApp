import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_se_pools.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

void main() {
  HeroSheet buildHero({
    StatModifiers persistentMods = const StatModifiers(),
    HeroBackground? background,
    String vorteileText = '',
    List<HeroAdventureEntry> adventures = const <HeroAdventureEntry>[],
    HeroAttributeSePool attributeSePool = const HeroAttributeSePool(),
    HeroStatSePool statSePool = const HeroStatSePool(),
  }) {
    return HeroSheet(
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
      background:
          background ??
          HeroBackground(
            rasse: 'Mensch',
            kultur: 'Mittelreich',
            profession: 'Kriegerin',
            sozialstatus: 7,
          ),
      apTotal: 1000,
      apSpent: 500,
      apAvailable: 500,
      persistentMods: persistentMods,
      vorteileText: vorteileText,
      adventures: adventures,
      attributeSePool: attributeSePool,
      statSePool: statSePool,
    );
  }

  Future<void> openWorkspace(
    WidgetTester tester,
    FakeRepository repo, {
    Size? size,
    RulesCatalog? catalog,
  }) async {
    final resolvedSize = size ?? const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = resolvedSize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    final heroTile = find.widgetWithText(ListTile, 'Rondra');
    if (heroTile.evaluate().isNotEmpty) {
      await tester.tap(heroTile.first);
    } else {
      await tester.tap(find.text('Rondra').first);
    }
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

  Finder activeTabVerticalScrollable() {
    return find
        .descendant(
          of: find.byKey(const ValueKey<String>('hero-overview-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
  }

  Future<void> selectWorkspaceTab(WidgetTester tester, String label) async {
    final tab = tabText(label).first;
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  Future<void> tapWorkspaceEditAction(WidgetTester tester) async {
    final appBar = find.byType(AppBar);
    final textButton = find.descendant(
      of: appBar,
      matching: find.text('Bearbeiten'),
    );
    if (textButton.evaluate().isNotEmpty) {
      await tester.tap(textButton.first);
      await tester.pumpAndSettle();
      return;
    }

    final iconButton = find.descendant(
      of: appBar,
      matching: find.byTooltip('Bearbeiten'),
    );
    await tester.tap(iconButton.first);
    await tester.pumpAndSettle();
  }

  Future<void> tapWorkspaceSaveAction(WidgetTester tester) async {
    final appBar = find.byType(AppBar);
    final textButton = find.descendant(
      of: appBar,
      matching: find.text('Speichern'),
    );
    if (textButton.evaluate().isNotEmpty) {
      await tester.tap(textButton.first);
      await tester.pumpAndSettle();
      return;
    }

    final iconButton = find.descendant(
      of: appBar,
      matching: find.byTooltip('Speichern'),
    );
    await tester.tap(iconButton.first);
    await tester.pumpAndSettle();
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

    await openWorkspace(tester, repo, size: const Size(740, 844));

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();
    expect(find.text('Speichern'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Rondra Neu',
    );

    final verticalScrollable = activeTabVerticalScrollable();
    final apTotalField = find.byKey(
      const ValueKey<String>('overview-field-ap_total'),
    );
    final apSpentField = find.byKey(
      const ValueKey<String>('overview-field-ap_spent'),
    );
    await tester.scrollUntilVisible(
      apTotalField,
      240,
      scrollable: verticalScrollable,
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

  testWidgets(
    'talents tab shows BE action in header and catalog actions in the tab body while editing',
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

      await openWorkspace(
        tester,
        repo,
        size: const Size(740, 844),
        catalog: buildCatalog(),
      );
      await selectWorkspaceTab(tester, 'Talente');

      await tapWorkspaceEditAction(tester);

      expect(
        find.byKey(const ValueKey<String>('talents-be-screen-open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('talents-catalog-open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('meta-talents-manage-open')),
        findsOneWidget,
      );
    },
  );

  testWidgets('overview edit/save persists attribute changes', (tester) async {
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

    final verticalScrollable = activeTabVerticalScrollable();
    final muField = find.byKey(const ValueKey<String>('overview-field-mu'));
    await tester.scrollUntilVisible(
      muField,
      240,
      scrollable: verticalScrollable,
    );
    await tester.enterText(muField, '16');

    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = findHeroById(heroes, 'demo');
    expect(hero, isNotNull);
    expect(hero!.attributes.mu, 16);
  });

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

      await openWorkspace(tester, repo, size: const Size(740, 844));

      final verticalScrollable = activeTabVerticalScrollable();
      final startKl = find.byKey(
        const ValueKey<String>('overview-effective-kl_start'),
      );
      final maxKl = find.byKey(
        const ValueKey<String>('overview-effective-kl_max'),
      );
      await tester.scrollUntilVisible(
        startKl,
        240,
        scrollable: verticalScrollable,
      );

      expect(find.descendant(of: startKl, matching: find.text('12')), findsOne);
      expect(find.descendant(of: maxKl, matching: find.text('18')), findsOne);

      await tester.tap(find.text('Bearbeiten').first);
      await tester.pumpAndSettle();
      await tester.drag(verticalScrollable, const Offset(0, 1200));
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
        scrollable: verticalScrollable,
      );
      expect(find.descendant(of: startKl, matching: find.text('13')), findsOne);
      expect(find.descendant(of: maxKl, matching: find.text('20')), findsOne);
    },
  );

  testWidgets('overview edit/save persists bought values', (tester) async {
    final repo = FakeRepository(
      heroes: [buildHero(vorteileText: 'KE+1')],
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

    final verticalScrollable = activeTabVerticalScrollable();
    final boughtLepField = find.byKey(
      const ValueKey<String>('overview-derived-bought-b_lep'),
    );

    await tester.scrollUntilVisible(
      boughtLepField,
      240,
      scrollable: verticalScrollable,
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
  });

  testWidgets('header resources stay visible after overview save', (
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
    expect(find.textContaining('10/22'), findsWidgets);
    expect(find.textContaining('BE'), findsWidgets);

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();

    final verticalScrollable = activeTabVerticalScrollable();
    final boughtLepField = find.byKey(
      const ValueKey<String>('overview-derived-bought-b_lep'),
    );
    await tester.scrollUntilVisible(
      boughtLepField,
      240,
      scrollable: verticalScrollable,
    );
    await tester.enterText(boughtLepField, '2');

    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('10/'), findsWidgets);
  });

  testWidgets(
    'workspace hides magical and divine resources when auto activation is off',
    (tester) async {
      final repo = FakeRepository(
        heroes: [buildHero()],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 4,
            currentAu: 10,
          ),
        },
      );

      await openWorkspace(tester, repo, size: const Size(740, 1100));

      expect(tabText('Magie'), findsNothing);
      expect(find.textContaining('AsP'), findsNothing);
      expect(find.textContaining('KaP:'), findsNothing);

      expect(
        find.byKey(const ValueKey<String>('overview-field-cur_asp')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('overview-field-cur_kap')),
        findsNothing,
      );
      expect(find.text('Aktuelle Ressourcen'), findsNothing);
    },
  );

  testWidgets(
    'resource settings dialog saves magic override without edit mode',
    (tester) async {
      final repo = FakeRepository(
        heroes: [buildHero(vorteileText: 'AE+3')],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );

      await openWorkspace(tester, repo, size: const Size(740, 1100));

      expect(tabText('Magie'), findsOneWidget);
      expect(find.textContaining('AsP'), findsWidgets);

      final verticalScrollable = activeTabVerticalScrollable();
      final settingsButton = find.byKey(
        const ValueKey<String>('overview-resource-settings-open'),
      );
      await tester.scrollUntilVisible(
        settingsButton,
        240,
        scrollable: verticalScrollable,
      );
      final settingsOpenButton = tester.widget<IconButton>(settingsButton);
      settingsOpenButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Speichern'), findsOneWidget);
      final magicToggle = find.byKey(
        const ValueKey<String>('overview-resource-toggle-magic'),
      );
      expect(
        find.byKey(const ValueKey<String>('overview-resource-settings-dialog')),
        findsOneWidget,
      );
      final magicSwitch = tester.widget<Switch>(magicToggle);
      magicSwitch.onChanged?.call(false);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('overview-resource-settings-save')),
      );
      await tester.pumpAndSettle();

      expect(tabText('Magie'), findsNothing);
      expect(find.textContaining('AsP'), findsNothing);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        settingsButton,
        240,
        scrollable: verticalScrollable,
      );
      final settingsReopenButton = tester.widget<IconButton>(settingsButton);
      settingsReopenButton.onPressed!.call();
      await tester.pumpAndSettle();

      final resetButton = find.byKey(
        const ValueKey<String>('overview-resource-reset-magic'),
      );
      final resetWidget = tester.widget<TextButton>(resetButton);
      resetWidget.onPressed?.call();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('overview-resource-settings-save')),
      );
      await tester.pumpAndSettle();

      expect(tabText('Magie'), findsOneWidget);
      expect(find.textContaining('AsP'), findsWidgets);
    },
  );

  testWidgets(
    'wide workspace inspector opens active spell popup and saves Axxeleratus outside edit mode',
    (tester) async {
      final repo = FakeRepository(
        heroes: [buildHero(vorteileText: 'AE+1')],
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

      final openButton = find.byKey(
        const ValueKey<String>('workspace-active-spells-open'),
      );
      await tester.ensureVisible(openButton);
      await tester.pumpAndSettle();

      await tester.tap(openButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('active-spell-effects-dialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'active-spell-toggle-effect_spell_axxeleratus',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.activeSpellEffects.activeEffectIds, <String>[
        activeSpellEffectAxxeleratus,
      ]);
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

    final verticalScrollable = activeTabVerticalScrollable();
    final muField = find.byKey(const ValueKey<String>('overview-field-mu'));
    final klField = find.byKey(const ValueKey<String>('overview-field-kl'));
    await tester.scrollUntilVisible(
      muField,
      240,
      scrollable: verticalScrollable,
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

    // Nach dem Abbrechen zeigt EditAwareField im View-Modus Plain Text.
    final nameFieldArea = find.byKey(
      const ValueKey<String>('overview-field-name'),
    );
    expect(
      find.descendant(of: nameFieldArea, matching: find.text('Rondra')),
      findsOneWidget,
    );
  });

  testWidgets('notes tab can enter edit mode via global action', (
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
    await selectWorkspaceTab(tester, 'Chroniken, Kontakte & Abenteuer');

    await tester.tap(find.text('Bearbeiten').first);
    await tester.pumpAndSettle();

    expect(find.text('Speichern'), findsOneWidget);
  });

  testWidgets('inventory tab shows add action and no global edit action', (
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
    await selectWorkspaceTab(tester, 'Inventar');

    expect(
      find.byKey(const ValueKey<String>('inventory-header-add')),
      findsOneWidget,
    );
    expect(find.text('Bearbeiten'), findsNothing);
  });

  testWidgets(
    'notes tab saves notes, contacts and adventures and reveals chronicle titles',
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

      await openWorkspace(tester, repo, size: const Size(740, 1100));
      await selectWorkspaceTab(tester, 'Chroniken, Kontakte & Abenteuer');
      expect(
        find.byKey(const ValueKey<String>('notes-add-note')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('notes-add-note')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-note-title-0')),
        'Offene Schuld',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-note-description-0')),
        'Noch 20 Dukaten offen.',
      );

      await tester.tap(find.text('Abenteuer'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('notes-add-adventure')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-adventure-title-0')),
        'Die Höhlen von Tairach',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-adventure-summary-0')),
        'Ein gefährlicher Vorstoß in orkisches Gebiet.',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-adventure-ap-0')),
        '45',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('notes-adventure-add-note-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notes-adventure-add-note-0')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-adventure-note-title-0-0')),
        'Schlüsselstelle',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('notes-adventure-note-description-0-0'),
        ),
        'Der Eingang wurde mit einem Runenkreis gesichert.',
      );

      await tester.tap(find.text('Kontakte'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('notes-add-connection')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notes-add-connection')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-connection-name-0')),
        'Jucho',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-connection-ort-0')),
        'Punin',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-connection-sozialstatus-0')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-connection-loyalitaet-0')),
        'schwankend',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('notes-connection-description-0')),
        'Informant aus dem Hafenviertel.',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('notes-connection-adventure-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notes-connection-adventure-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Die Höhlen von Tairach').last);
      await tester.pumpAndSettle();

      await tapWorkspaceSaveAction(tester);

      final heroes = await repo.listHeroes();
      final hero = findHeroById(heroes, 'demo');
      expect(hero, isNotNull);
      expect(hero!.notes, hasLength(1));
      expect(hero.notes.single.title, 'Offene Schuld');
      expect(hero.notes.single.description, 'Noch 20 Dukaten offen.');
      expect(hero.connections, hasLength(1));
      expect(hero.connections.single.name, 'Jucho');
      expect(hero.connections.single.ort, 'Punin');
      expect(hero.connections.single.sozialstatus, '5');
      expect(hero.connections.single.loyalitaet, 'schwankend');
      expect(
        hero.connections.single.beschreibung,
        'Informant aus dem Hafenviertel.',
      );
      expect(hero.connections.single.adventureId, isNotEmpty);
      expect(hero.adventures, hasLength(1));
      expect(hero.adventures.single.title, 'Die Höhlen von Tairach');
      expect(
        hero.adventures.single.summary,
        'Ein gefährlicher Vorstoß in orkisches Gebiet.',
      );
      expect(hero.adventures.single.apReward, 45);
      expect(hero.adventures.single.notes.single.title, 'Schlüsselstelle');

      await openWorkspace(tester, repo);
      await selectWorkspaceTab(tester, 'Chroniken, Kontakte & Abenteuer');
      await tester.tap(find.text('Chroniken'));
      await tester.pumpAndSettle();

      expect(find.text('Noch 20 Dukaten offen.'), findsNothing);
      expect(find.text('Offene Schuld'), findsOneWidget);
    },
  );

  testWidgets(
    'adventure rewards can be applied and overview raises consume SE pools',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            adventures: const <HeroAdventureEntry>[
              HeroAdventureEntry(
                id: 'adv_1',
                title: 'Feuer im Nebel',
                apReward: 40,
                seRewards: <HeroAdventureSeReward>[
                  HeroAdventureSeReward(
                    targetType: HeroAdventureSeTargetType.eigenschaft,
                    targetId: 'mu',
                    targetLabel: 'Mut',
                    count: 1,
                  ),
                  HeroAdventureSeReward(
                    targetType: HeroAdventureSeTargetType.grundwert,
                    targetId: 'lep',
                    targetLabel: 'LeP',
                    count: 1,
                  ),
                ],
              ),
            ],
          ),
        ],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );

      await openWorkspace(tester, repo, size: const Size(740, 1100));
      await selectWorkspaceTab(tester, 'Chroniken, Kontakte & Abenteuer');
      await tester.tap(find.text('Abenteuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feuer im Nebel').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('notes-adventure-apply-adv_1')),
      );
      await tester.pumpAndSettle();

      var heroes = await repo.listHeroes();
      var hero = findHeroById(heroes, 'demo');
      expect(hero, isNotNull);
      expect(hero!.apTotal, 1040);
      expect(hero.attributeSePool.mu, 1);
      expect(hero.statSePool.lep, 1);
      expect(hero.adventures.single.rewardsApplied, isTrue);

      await selectWorkspaceTab(tester, 'Übersicht');
      await tapWorkspaceEditAction(tester);

      final verticalScrollable = activeTabVerticalScrollable();
      final muRaiseButton = find.byKey(
        const ValueKey<String>('overview-raise-mu'),
      );
      final lepRaiseButton = find.byKey(
        const ValueKey<String>('overview-derived-raise-b_lep'),
      );
      await tester.scrollUntilVisible(
        muRaiseButton,
        240,
        scrollable: verticalScrollable,
      );
      await tester.tap(muRaiseButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Mit 1 SE: 1 Schritt als G'), findsOneWidget);
      await tester.tap(find.text('Steigern'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        lepRaiseButton,
        240,
        scrollable: verticalScrollable,
      );
      await tester.tap(lepRaiseButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Mit 1 SE: 1 Schritt als G'), findsOneWidget);
      await tester.tap(find.text('Steigern'));
      await tester.pumpAndSettle();

      heroes = await repo.listHeroes();
      hero = findHeroById(heroes, 'demo');
      expect(hero, isNotNull);
      expect(hero!.attributeSePool.mu, 0);
      expect(hero.statSePool.lep, 0);
    },
  );

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
      // Letztes Element ist jetzt das Settings-Icon; der rechte Spacer
      // liegt direkt davor.
      expect(actions.last, isA<IconButton>());
      expect((actions.last as IconButton).tooltip, 'Einstellungen');
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

    await tester.tap(tabText('Talente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 220));

    if (find.textContaining('Ungespeicherte').evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'Nein'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    final overviewTab = tabText('Übersicht');
    await tester.ensureVisible(overviewTab);
    await tester.tap(overviewTab, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey<String>('overview-field-name')),
      findsOneWidget,
    );
    final nameFieldInner = find.byKey(
      const ValueKey<String>('overview-field-name'),
    );
    expect(
      tester.widget<TextField>(nameFieldInner).controller?.text,
      'Nicht speichern',
    );
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

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Nein'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Nein'));
    await tester.pumpAndSettle();
    expect(find.text('Basisinformationen'), findsOneWidget);

    await tester.binding.handlePopRoute();
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

  testWidgets('wide workspace shows collapsed Helden Deck instead of TabBar', (
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

    expect(find.text('Helden Deck'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Inspector'), findsNothing);
    expect(find.text('Vitalwerte'), findsOneWidget);
    expect(heroDeckToggleButton(), findsOneWidget);
    expect(find.byTooltip('Helden-Deck einblenden'), findsOneWidget);
    expect(find.text('Übersicht'), findsNothing);
    expect(workspaceDetailsToggleButton(), findsOneWidget);
  });

  testWidgets('wide workspace inspector opens rest dialog and saves changes', (
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
          ueberanstrengung: 2,
        ),
      },
    );

    await openWorkspace(tester, repo, size: const Size(1600, 1200));

    expect(
      find.byKey(
        const ValueKey<String>('workspace-vital-row-ueberanstrengung'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('workspace-rest-open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('rest-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('rest-au-enabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuell').at(0));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('rest-au-roll-manual')),
      '9',
    );
    await tester.tap(find.text('Manuell').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('rest-au-ko-manual')),
      '1',
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('rest-conditions-enabled')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('rest-dialog-apply')));
    await tester.pumpAndSettle();

    final state = await repo.loadHeroState('demo');
    expect(state, isNotNull);
    expect(state!.currentAu, 22);
    expect(state.ueberanstrengung, 1);
  });

  testWidgets(
    'wide workspace vital values can edit ueberanstrengung and erschoepfung',
    (tester) async {
      final repo = FakeRepository(
        heroes: [buildHero()],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
            erschoepfung: 1,
            ueberanstrengung: 2,
          ),
        },
      );

      await openWorkspace(tester, repo, size: const Size(1600, 1200));

      expect(
        find.byKey(
          const ValueKey<String>('workspace-vital-row-ueberanstrengung'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('workspace-vital-row-erschoepfung')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Überanstrengung erhöhen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Erschöpfung verringern'));
      await tester.pumpAndSettle();

      final state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.ueberanstrengung, 3);
      expect(state.erschoepfung, 0);
    },
  );

  testWidgets(
    'wide workspace rest dialog can full restore resources and wounds',
    (tester) async {
      final repo = FakeRepository(
        heroes: [buildHero(vorteileText: 'AE+3, KE+1')],
        states: {
          'demo': const HeroState(
            currentLep: 5,
            currentAsp: 2,
            currentKap: 0,
            currentAu: 1,
            erschoepfung: 4,
            ueberanstrengung: 2,
            wpiZustand: WundZustand(
              wundenProZone: <WundZone, int>{WundZone.kopf: 2},
              kopfIniMalus: 8,
              kampfunfaehigIgnoriert: true,
            ),
          ),
        },
      );

      await openWorkspace(tester, repo, size: const Size(1600, 1200));

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-rest-open')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('rest-dialog-full-restore')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anwenden'));
      await tester.pumpAndSettle();

      final state = await repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.currentLep, 22);
      expect(state.currentAu, 22);
      expect(state.currentAsp, 24);
      expect(state.currentKap, 1);
      expect(state.erschoepfung, 0);
      expect(state.ueberanstrengung, 0);
      expect(state.wpiZustand.gesamtWunden, 0);
      expect(state.wpiZustand.kopfIniMalus, 0);
      expect(state.wpiZustand.kampfunfaehigIgnoriert, isFalse);
    },
  );

  testWidgets('wide workspace can expand and collapse Helden Deck', (
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

    expect(find.text('Helden Deck'), findsNothing);
    expect(find.text('Übersicht'), findsNothing);
    expect(find.text('Vitalwerte'), findsOneWidget);

    await tester.tap(heroDeckToggleButton());
    await tester.pumpAndSettle();

    expect(find.text('Helden Deck'), findsOneWidget);
    expect(find.byTooltip('Helden-Deck ausblenden'), findsOneWidget);
    expect(find.text('Übersicht'), findsWidgets);
    expect(find.text('Vitalwerte'), findsOneWidget);
    expect(find.text('Basisinformationen'), findsOneWidget);

    await tester.tap(heroDeckToggleButton());
    await tester.pumpAndSettle();

    expect(find.text('Helden Deck'), findsNothing);
    expect(find.byTooltip('Helden-Deck einblenden'), findsOneWidget);
    expect(find.text('Übersicht'), findsNothing);
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
    expect(find.text('Vitalwerte'), findsOneWidget);
    expect(workspaceDetailsToggleButton(), findsOneWidget);

    await tester.tap(workspaceDetailsToggleButton());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Details einblenden'), findsOneWidget);
    expect(find.text('Vitalwerte'), findsNothing);
    expect(find.text('Statuswerte'), findsNothing);
    expect(find.text('Basisinformationen'), findsOneWidget);
    expect(find.text('Helden Deck'), findsNothing);

    await tester.tap(workspaceDetailsToggleButton());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Details ausblenden'), findsOneWidget);
    expect(find.text('Vitalwerte'), findsOneWidget);
    expect(find.text('Statuswerte'), findsOneWidget);
  });

  testWidgets('wide workspace shows merged status rows with BE and MR', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          persistentMods: const StatModifiers(
            iniBase: 1,
            gs: 2,
            ausweichen: -1,
            pa: 1,
            at: -2,
            rs: 1,
          ),
        ),
      ],
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

    expect(find.text('Statuswerte'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-Ini')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-GS')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-AW')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-PA')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-AT')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-RS')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-MR')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-status-row-be')),
      findsOneWidget,
    );
    expect(find.text('AP verfuegbar: 500'), findsNothing);
    expect(find.text('Ruestung'), findsNothing);
    expect(find.text('Kampfwerte'), findsNothing);
    expect(find.text('Manueller BE'), findsNothing);
    expect(find.text('Entfernen'), findsNothing);
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

    final verticalScrollable = activeTabVerticalScrollable();
    final attributesHeader = find.text('Eigenschaften');
    final derivedHeader = find.text('Basiswerte');

    await tester.scrollUntilVisible(
      attributesHeader,
      240,
      scrollable: verticalScrollable,
    );
    await tester.scrollUntilVisible(
      derivedHeader,
      240,
      scrollable: verticalScrollable,
    );

    final muField = find.byKey(const ValueKey<String>('overview-field-mu'));
    final klField = find.byKey(const ValueKey<String>('overview-field-kl'));
    await tester.scrollUntilVisible(
      muField,
      240,
      scrollable: verticalScrollable,
    );
    await tester.scrollUntilVisible(
      klField,
      240,
      scrollable: verticalScrollable,
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
      scrollable: verticalScrollable,
    );
    await tester.scrollUntilVisible(
      derivedHeader,
      240,
      scrollable: verticalScrollable,
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
