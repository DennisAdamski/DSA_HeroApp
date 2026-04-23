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
    'house rule management stays reachable even without discovered packs',
    (tester) async {
      final repository = _FakeSettingsRepository();
      addTearDown(repository.close);

      await tester.pumpWidget(
        ProviderScope(
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
            settingsStoragePathProvider.overrideWith(
              (ref) async => '/settings',
            ),
            houseRulePackCatalogProvider.overrideWith(
              (ref) async => const HouseRulePackCatalog(),
            ),
            houseRuleIssueSnapshotProvider.overrideWith(
              (ref) async => const <HouseRulePackIssue>[],
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Hausregelverwaltung öffnen'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Keine Hausregel-Pakete gefunden.'), findsOneWidget);
      expect(find.text('Hausregelverwaltung öffnen'), findsOneWidget);
    },
  );
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
