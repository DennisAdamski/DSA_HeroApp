import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

/// Fake-Katalog mit genau einem v3-verschluesselten Probe-Wert, damit
/// [showCatalogUnlockDialog] hermetisch getestet werden kann, ohne die
/// echten (grossen) Katalog-Assets zu laden und zu entschluesseln.
CatalogSourceData _fakeCatalogWithProtectedContent() {
  final salt = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final key = deriveCatalogKey(password: 'korrektes-passwort', salt: salt);
  final encryptedValue = encryptCatalogValueV3(
    plaintext: 'Geheimer Erklaerungstext',
    derivedKey: key,
  );
  return CatalogSourceData(
    version: '1',
    source: 'test-fixture',
    metadata: const {},
    sections: {
      CatalogSectionId.maneuvers: [
        {'id': 'fixture-maneuver', 'erklarung_lang': encryptedValue},
      ],
    },
    reisebericht: const [],
    catalogSaltV3: salt,
  );
}

void main() {
  testWidgets(
    'Server-Sync-Karte ist auf der Katalog-Einstellungsseite sichtbar',
    (tester) async {
      final repository = _FakeSettingsRepository(const AppSettings());
      addTearDown(repository.close);
      _setSurfaceSize(tester);

      await tester.pumpWidget(_buildTestApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-catalog')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Regel-Nachschlag: Server-Sync'), findsOneWidget);
      expect(find.text('Jetzt von Server laden'), findsOneWidget);
      expect(find.text('Noch nie vom Server geladen.'), findsOneWidget);
    },
  );

  testWidgets(
    'ohne gesetztes Katalog-Passwort oeffnet der Sync-Button zuerst den '
    'Unlock-Dialog statt direkt zu synchronisieren',
    (tester) async {
      final repository = _FakeSettingsRepository(const AppSettings());
      addTearDown(repository.close);
      _setSurfaceSize(tester);

      await tester.pumpWidget(
        _buildTestApp(
          repository: repository,
          catalogSourceData: _fakeCatalogWithProtectedContent(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-catalog')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Jetzt von Server laden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jetzt von Server laden'));
      await tester.pumpAndSettle();

      // Das Gate hat den Katalog-Unlock-Dialog geoeffnet statt direkt zu
      // synchronisieren — der Sync-Client wird erst nach erfolgreicher
      // Passworteingabe ueberhaupt aufgerufen.
      expect(find.text('Katalog-Inhalte freischalten'), findsOneWidget);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(repository.load().catalogContentPassword, isNull);
      expect(repository.load().rulesIndexRemoteConfig.lastSyncedAt, isNull);
    },
  );

  testWidgets(
    'nach erfolgreicher Passworteingabe wird das Katalogpasswort uebernommen '
    'und der Sync-Versuch startet (schlaegt ohne echten Server erwartbar fehl)',
    (tester) async {
      final repository = _FakeSettingsRepository(const AppSettings());
      addTearDown(repository.close);
      _setSurfaceSize(tester);

      await tester.pumpWidget(
        _buildTestApp(
          repository: repository,
          catalogSourceData: _fakeCatalogWithProtectedContent(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-menu-catalog')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Jetzt von Server laden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jetzt von Server laden'));
      await tester.pumpAndSettle();

      expect(find.text('Katalog-Inhalte freischalten'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'korrektes-passwort');
      await tester.tap(find.text('Freischalten'));
      await tester.pumpAndSettle();

      expect(repository.load().catalogContentPassword, 'korrektes-passwort');
    },
  );
}

void _setSurfaceSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildTestApp({
  required _FakeSettingsRepository repository,
  CatalogSourceData? catalogSourceData,
}) {
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
      if (catalogSourceData != null)
        baseCatalogSourceDataProvider.overrideWith(
          (ref) async => catalogSourceData,
        ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

class _FakeSettingsRepository implements HiveSettingsRepository {
  _FakeSettingsRepository(this._settings);

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
