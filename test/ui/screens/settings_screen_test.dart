import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

void main() {
  testWidgets(
    'wide layouts keep the navigation list visible and swap the detail pane',
    (tester) async {
      final repository = _FakeSettingsRepository();
      addTearDown(repository.close);
      _setSurfaceSize(tester, const Size(1200, 900));

      await tester.pumpWidget(_buildTestApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Bereiche'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('settings-detail-appearance')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-storage')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('settings-detail-storage')),
        findsOneWidget,
      );
      expect(find.text('Aktiver Heldenspeicher'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-catalog')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('settings-detail-catalog')),
        findsOneWidget,
      );
      expect(find.text('Katalogverwaltung öffnen'), findsOneWidget);
      expect(find.text('Passwortschutz'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-houseRules')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('settings-detail-houseRules')),
        findsOneWidget,
      );
      expect(find.text('Keine Hausregel-Pakete gefunden.'), findsOneWidget);
      expect(find.text('Hausregelverwaltung öffnen'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-imageGeneration')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('settings-detail-imageGeneration')),
        findsOneWidget,
      );
      expect(find.text('API-Schlüssel'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-debugMode')),
      );
      await tester.pumpAndSettle();

      expect(repository.load().debugModus, isTrue);
      expect(
        find.byKey(const ValueKey<String>('settings-detail-imageGeneration')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'narrow layouts drill into pages and keep debug mode as a direct toggle',
    (tester) async {
      final repository = _FakeSettingsRepository();
      addTearDown(repository.close);
      _setSurfaceSize(tester, const Size(390, 844));

      await tester.pumpWidget(_buildTestApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Bereiche'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('settings-detail-appearance')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-storage')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Speicher'), findsOneWidget);
      expect(find.text('Aktiver Heldenspeicher'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Bereiche'), findsOneWidget);
      expect(find.text('Aktiver Heldenspeicher'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-debugMode')),
      );
      await tester.pumpAndSettle();

      expect(repository.load().debugModus, isTrue);
      expect(find.text('Bereiche'), findsOneWidget);
      expect(find.text('Aktiver Heldenspeicher'), findsNothing);
    },
  );
}

Widget _buildTestApp({required _FakeSettingsRepository repository}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repository),
      heroStorageLocationProvider.overrideWith(
        (ref) async => const HeroStorageLocation(
          defaultPath: '/default',
          effectivePath: '/heroes',
          configuredPath: '/heroes',
          customPathSupported: true,
          usesCustomPath: true,
        ),
      ),
      settingsStoragePathProvider.overrideWith((ref) async => '/settings'),
      houseRulePackCatalogProvider.overrideWith(
        (ref) async => const HouseRulePackCatalog(),
      ),
      houseRuleIssueSnapshotProvider.overrideWith(
        (ref) async => const <HouseRulePackIssue>[],
      ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeSettingsRepository implements HiveSettingsRepository {
  _FakeSettingsRepository() : _settings = const AppSettings();

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
}
