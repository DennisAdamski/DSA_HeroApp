import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_picker.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_shell.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    final fakeRepository = FakeRepository.empty();
    final tempDir = await Directory.systemTemp.createTemp(
      'dsa_smoke_settings_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final settingsRepo = await HiveSettingsRepository.create(
      storagePath: tempDir.path,
    );
    addTearDown(settingsRepo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(fakeRepository),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          storageDirectoryPickerProvider.overrideWithValue(
            _FakeStorageDirectoryPicker(),
          ),
        ],
        child: const DsaAppShell(
          home: HeroesHomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('DSA Helden'), findsOneWidget);
  });
}

class _FakeStorageDirectoryPicker implements StorageDirectoryPicker {
  @override
  Future<String?> pickDirectory({required String dialogTitle}) async {
    return null;
  }
}
