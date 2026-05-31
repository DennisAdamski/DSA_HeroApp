import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/state/sync_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

void main() {
  testWidgets('settings expose account sync status and manual sync', (
    tester,
  ) async {
    final settings = _FakeSettingsRepository();
    final sync = _FakeSyncController(
      const SyncStatusSnapshot(
        accountId: 'user-1',
        email: 'alrik@example.test',
        isSyncing: false,
        openConflicts: <SyncConflict>[],
      ),
    );
    addTearDown(settings.close);
    addTearDown(sync.close);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(settings: settings, sync: sync));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('settings-menu-accountSync')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Konto & Sync'), findsWidgets);
    expect(find.text('alrik@example.test'), findsOneWidget);
    expect(find.text('Letzter Sync: Noch nie'), findsOneWidget);

    await tester.tap(find.text('Jetzt synchronisieren'));
    await tester.pumpAndSettle();

    expect(sync.syncCalls, 1);
  });
}

Widget _buildApp({
  required _FakeSettingsRepository settings,
  required _FakeSyncController sync,
}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      syncControllerProvider.overrideWithValue(sync),
      authServiceProvider.overrideWithValue(null),
      authUserProvider.overrideWith((ref) => const Stream.empty()),
      heroStorageLocationProvider.overrideWith(
        (ref) async => const HeroStorageLocation(
          defaultPath: '/default',
          effectivePath: '/heroes',
          customPathSupported: true,
          usesCustomPath: false,
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

class _FakeSyncController implements AppSyncController {
  _FakeSyncController(SyncStatusSnapshot initial) : _current = initial;

  final StreamController<SyncStatusSnapshot> _controller =
      StreamController<SyncStatusSnapshot>.broadcast();
  SyncStatusSnapshot _current;
  int syncCalls = 0;

  @override
  SyncStatusSnapshot get currentStatus => _current;

  @override
  Stream<SyncStatusSnapshot> watchStatus() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> syncNow() async {
    syncCalls++;
    _current = _current.copyWith(lastSuccessfulSync: DateTime.utc(2026));
    _controller.add(_current);
  }

  @override
  Future<void> resolveConflict(
    String conflictId,
    SyncResolutionChoice resolution,
  ) async {}

  Future<void> close() => _controller.close();
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

  @override
  Future<void> attachUser(String uid, {Object? remote, Object? cipher}) async {}

  @override
  Future<void> detachUser() async {}

  @override
  bool get isAttached => false;

  @override
  String? get attachedUid => null;
}
