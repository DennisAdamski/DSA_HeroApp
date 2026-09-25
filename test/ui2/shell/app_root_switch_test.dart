import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_app_root.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';

void main() {
  const catalog = RulesCatalog(
    version: 'test_catalog',
    source: 'test',
    talents: <TalentDef>[],
    spells: <SpellDef>[],
    weapons: <WeaponDef>[],
  );

  /// Baut einen Container mit den Overrides, die beide Oberflaechen teilen.
  ///
  /// Der mitgelieferte Zaehler sagt, wie oft der Katalog aufgebaut wurde. Er
  /// ist der Beleg dafuer, dass ein Oberflaechenwechsel den Unterbau nicht
  /// anfasst.
  ({ProviderContainer container, int Function() catalogBuilds})
  buildContainer() {
    var builds = 0;
    final settingsRepository = _FakeSettingsRepository(
      initialSettings: const AppSettings(),
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(FakeRepository.empty()),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        rulesCatalogProvider.overrideWith((ref) async {
          builds++;
          return catalog;
        }),
      ],
    );
    // Reihenfolge ist wichtig: Teardowns laufen rueckwaerts, der Container
    // muss also VOR dem Stream schliessen. Andersherum wartet `close()` auf
    // einen Zuhoerer, den erst `dispose()` abmeldet - und haengt.
    addTearDown(settingsRepository.close);
    addTearDown(container.dispose);
    return (container: container, catalogBuilds: () => builds);
  }

  /// Gibt dem Einstellungs-Stream ein paar Frames, ohne auf Ruhe zu warten.
  ///
  /// `pumpAndSettle` waere hier unpassend: der Startbildschirm zeigt im
  /// Ladezustand einen `CircularProgressIndicator`, und der animiert endlos.
  /// Welcher Bildschirm montiert ist, steht schon nach wenigen Frames fest.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpSwitch(WidgetTester tester, ProviderContainer container) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppRootSwitch()),
      ),
    );
  }

  testWidgets('startet ohne Einstellung in der bestehenden Oberflaeche', (
    tester,
  ) async {
    final setup = buildContainer();
    await pumpSwitch(tester, setup.container);
    await settle(tester);

    expect(find.byType(HeroesHomeScreen), findsOneWidget);
    expect(find.byType(KartoShell), findsNothing);
  });

  testWidgets(
    'Umschalten tauscht den Bildschirm, ohne den Unterbau neu zu bauen',
    (tester) async {
      final setup = buildContainer();
      final container = setup.container;

      // Den Katalog ueber einen Listener am Leben halten. Bewusst nicht ueber
      // `read(rulesCatalogProvider.future)`: dieses Muster ist in CLAUDE.md
      // ausdruecklich verboten, weil die Future in Riverpod 3.2 haengen kann.
      final catalogSubscription = container.listen(
        rulesCatalogProvider,
        (_, _) {},
      );
      addTearDown(catalogSubscription.close);

      await pumpSwitch(tester, container);
      await settle(tester);

      final repositoryBefore = container.read(heroRepositoryProvider);
      final catalogBuildsBefore = setup.catalogBuilds();
      expect(catalogBuildsBefore, 1);
      expect(find.byType(HeroesHomeScreen), findsOneWidget);

      await container
          .read(settingsActionsProvider)
          .setOberflaeche(Oberflaeche.kartograph);
      await settle(tester);

      // Der Bildschirm ist getauscht ...
      expect(find.byType(KartoShell), findsOneWidget);
      expect(find.byType(HeroesHomeScreen), findsNothing);

      // ... der Unterbau steht unveraendert.
      expect(
        identical(container.read(heroRepositoryProvider), repositoryBefore),
        isTrue,
      );
      expect(setup.catalogBuilds(), catalogBuildsBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Rueckweg aus der neuen Oberflaeche fuehrt zurueck', (
    tester,
  ) async {
    final setup = buildContainer();
    final container = setup.container;
    await container
        .read(settingsActionsProvider)
        .setOberflaeche(Oberflaeche.kartograph);
    await pumpSwitch(tester, container);
    await settle(tester);
    expect(find.byType(KartoShell), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('karto-shell-zurueck')));
    await settle(tester);

    expect(find.byType(HeroesHomeScreen), findsOneWidget);
    expect(find.byType(KartoShell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('neue Oberflaeche bleibt auf schmaler Breite bedienbar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final setup = buildContainer();
    await setup.container
        .read(settingsActionsProvider)
        .setOberflaeche(Oberflaeche.kartograph);
    await pumpSwitch(tester, setup.container);
    await settle(tester);

    expect(find.byType(KartoShell), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('karto-shell-zurueck')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('die Einstellung ueberlebt einen Speicher-Umlauf', () {
    const settings = AppSettings(oberflaeche: Oberflaeche.kartograph);
    final wieder = AppSettings.fromJson(settings.toJson());
    expect(wieder.oberflaeche, Oberflaeche.kartograph);

    // Bestandsboxen kennen den Schluessel nicht und muessen bei der
    // bestehenden Oberflaeche bleiben.
    final ohneSchluessel = Map<String, dynamic>.of(settings.toJson())
      ..remove('oberflaeche');
    expect(AppSettings.fromJson(ohneSchluessel).oberflaeche, Oberflaeche.codex);
  });
}

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
  AppSettings load() => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
    _controller.add(settings);
  }

  @override
  Stream<AppSettings> watch() => _controller.stream;

  @override
  Future<void> attachUser(String uid, {Object? remote, Object? cipher}) async {}

  @override
  Future<void> detachUser() async {}

  @override
  bool get isAttached => false;

  @override
  String? get attachedUid => null;
}
