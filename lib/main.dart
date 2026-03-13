import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_picker_impl.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_startup_gate.dart';

/// Startet die Anwendung und initialisiert die persistenten Heldendaten.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storagePaths = AppStoragePaths();
  final settingsPath = await storagePaths.resolveSettingsStoragePath();
  final settingsRepo = await HiveSettingsRepository.create(
    storagePath: settingsPath,
  );

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        storageDirectoryPickerProvider.overrideWithValue(
          createStorageDirectoryPicker(),
        ),
      ],
      child: const AppStartupGate(),
    ),
  );
}

/// Rueckwaertskompatibler App-Einstieg fuer Tests und lokale Widget-Starts.
class DsaApp extends StatelessWidget {
  /// Erstellt die startfaehige App mit Bootstrap-Flow.
  const DsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppStartupGate();
  }
}
