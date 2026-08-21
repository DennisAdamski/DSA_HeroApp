import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  const catalog = RulesCatalog(
    version: 'test_catalog',
    source: 'test',
    talents: <TalentDef>[],
    spells: <SpellDef>[],
    weapons: <WeaponDef>[],
  );
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
  final secondHero = HeroSheet(
    id: 'alrik',
    name: 'Alrik',
    level: 3,
    attributes: const Attributes(
      mu: 12,
      kl: 14,
      inn: 12,
      ch: 13,
      ff: 11,
      ge: 11,
      ko: 10,
      kk: 10,
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
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
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
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heldenarchiv'), findsOneWidget);
    expect(find.text('Held öffnen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workspace-back-button')),
      findsNothing,
    );
  });

  testWidgets(
    'ipad landscape restores the last selected hero into the preview',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1194, 834);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeRepository(
        heroes: [hero, secondHero],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
          'alrik': const HeroState(
            currentLep: 8,
            currentAsp: 4,
            currentKap: 0,
            currentAu: 7,
          ),
        },
      );
      final settingsRepository = _FakeSettingsRepository(
        initialSettings: const AppSettings(lastSelectedHeroId: 'alrik'),
      );
      addTearDown(settingsRepository.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            rulesCatalogProvider.overrideWith((ref) async => catalog),
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
          ],
          child: const MaterialApp(home: HeroesHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alrik'), findsNWidgets(2));
      expect(find.text('Rondra'), findsOneWidget);
      expect(find.byType(FilledButton), findsWidgets);
    },
  );

  testWidgets('create dialog captures raw start attributes and creates hero', (
    tester,
  ) async {
    final repo = FakeRepository.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
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
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            rulesCatalogProvider.overrideWith((ref) async => catalog),
          ],
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

      final overviewScrollable = find
          .descendant(
            of: find.byKey(const ValueKey<String>('hero-overview-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final muValue = find.byKey(
        const ValueKey<String>('overview-effective-mu'),
      );
      await tester.scrollUntilVisible(
        muValue,
        240,
        scrollable: overviewScrollable,
      );
      expect(find.descendant(of: muValue, matching: find.text('14')), findsOne);
      expect(find.textContaining('10/22'), findsWidgets);
    },
  );

  testWidgets('preloads rules catalog once the hero list is ready', (
    tester,
  ) async {
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
    final catalogCompleter = Completer<RulesCatalog>();
    var loadCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) {
            loadCount++;
            return catalogCompleter.future;
          }),
        ],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(loadCount, 1);

    catalogCompleter.complete(catalog);
    await tester.pump();
  });

  testWidgets('shows preparation dialog while opening waits for catalog', (
    tester,
  ) async {
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
    final catalogCompleter = Completer<RulesCatalog>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) => catalogCompleter.future),
        ],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rondra').first);
    await tester.pump(const Duration(milliseconds: 130));

    expect(find.text('Regelkatalog wird vorbereitet ...'), findsOneWidget);

    catalogCompleter.complete(catalog);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('workspace-back-button')),
      findsOneWidget,
    );
  });

  // Der eigentliche Regressionsfall: `SyncConflictGate` tauscht den Home-Screen
  // unter der Dialog-Route aus, die am Root-Navigator haengt. Frueher schloss
  // niemand mehr den `canPop: false`-Dialog — die App war hart blockiert.
  testWidgets(
    'preparation dialog closes itself when the home screen is swapped out',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(700, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeRepository(heroes: [hero], states: const {});
      final catalogCompleter = Completer<RulesCatalog>();
      final swapped = ValueNotifier<bool>(false);
      addTearDown(swapped.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            rulesCatalogProvider.overrideWith((ref) => catalogCompleter.future),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: swapped,
              builder: (context, isSwapped, _) => isSwapped
                  ? const Scaffold(body: Center(child: Text('Konflikte')))
                  : const HeroesHomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rondra').first);
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.text('Regelkatalog wird vorbereitet ...'), findsOneWidget);

      // Home-Screen unter dem Dialog austauschen, dann Katalog liefern.
      swapped.value = true;
      await tester.pump();
      catalogCompleter.complete(catalog);
      await tester.pumpAndSettle();

      expect(find.text('Regelkatalog wird vorbereitet ...'), findsNothing);
      expect(find.text('Konflikte'), findsOneWidget);
    },
  );

  testWidgets('preparation dialog offers a way out when the catalog hangs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeRepository(heroes: [hero], states: const {});
    final catalogCompleter = Completer<RulesCatalog>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) => catalogCompleter.future),
        ],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rondra').first);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('Regelkatalog wird vorbereitet ...'), findsOneWidget);

    // Timeout abwarten: der Dialog wird bedienbar statt endlos zu drehen.
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();

    expect(find.text('Regelkatalog wird vorbereitet ...'), findsNothing);
    expect(find.text('Regelkatalog nicht bereit'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('catalog-preparation-cancel')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Regelkatalog nicht bereit'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('workspace-back-button')),
      findsNothing,
      reason: 'ohne Katalog darf der Workspace nicht geoeffnet werden',
    );

    catalogCompleter.complete(catalog);
    await tester.pumpAndSettle();
  });

  testWidgets('preparation dialog names the reason when the catalog fails', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeRepository(heroes: [hero], states: const {});
    final catalogCompleter = Completer<RulesCatalog>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) => catalogCompleter.future),
        ],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rondra').first);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('Regelkatalog wird vorbereitet ...'), findsOneWidget);

    catalogCompleter.completeError(
      const FormatException('Katalog kaputt'),
      StackTrace.empty,
    );
    await tester.pumpAndSettle();

    expect(find.text('Regelkatalog nicht bereit'), findsOneWidget);
    expect(find.textContaining('Katalog kaputt'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('catalog-preparation-cancel')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Regelkatalog nicht bereit'), findsNothing);
  });

  testWidgets('preparation dialog can retry a failed catalog load', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeRepository(heroes: [hero], states: const {});
    var attempt = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) {
            attempt++;
            return attempt == 1
                ? Future<RulesCatalog>.error(
                    const FormatException('erster Versuch'),
                    StackTrace.empty,
                  )
                : Future<RulesCatalog>.value(catalog);
          }),
        ],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rondra').first);
    await tester.pumpAndSettle();
    expect(find.text('Regelkatalog nicht bereit'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('catalog-preparation-retry')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Regelkatalog nicht bereit'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('workspace-back-button')),
      findsOneWidget,
      reason: 'nach erfolgreichem Neuversuch muss der Workspace oeffnen',
    );
  });
}

void _noopBool(bool value) {}

void _noopDiscard(WorkspaceAsyncAction action) {}

void _noopEditActions(WorkspaceTabEditActions actions) {}

class _FakeSettingsRepository implements HiveSettingsRepository {
  _FakeSettingsRepository({required AppSettings initialSettings})
    : _settings = initialSettings;

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();
  AppSettings _settings;

  @override
  Future<void> close() async {
    await _controller.close();
  }

  @override
  AppSettings load() {
    return _settings;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
    _controller.add(settings);
  }

  @override
  Stream<AppSettings> watch() {
    return _controller.stream;
  }

  @override
  Future<void> attachUser(String uid, {Object? remote, Object? cipher}) async {}

  @override
  Future<void> detachUser() async {}

  @override
  bool get isAttached => false;

  @override
  String? get attachedUid => null;
}
