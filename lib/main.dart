import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_picker_impl.dart';
import 'package:dsa_heldenverwaltung/firebase_options.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_startup_gate.dart';

/// Startet die Anwendung und initialisiert die persistenten Heldendaten.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  const storagePaths = AppStoragePaths();
  final settingsPath = await storagePaths.resolveSettingsStoragePath();
  final settingsRepo = await HiveSettingsRepository.create(
    storagePath: settingsPath,
  );

  runApp(
    AppStartupGate(
      settingsRepository: settingsRepo,
      storagePaths: storagePaths,
      storageDirectoryPicker: createStorageDirectoryPicker(),
    ),
  );
}

/// Rueckwaertskompatibler App-Einstieg fuer Tests und lokale Widget-Starts.
class DsaApp extends StatelessWidget {
  /// Erstellt die startfaehige App mit Bootstrap-Flow.
  const DsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError(
      'DsaApp benoetigt fuer Tests einen expliziten Bootstrap-Kontext. '
      'Verwende AppStartupGate oder DsaAppShell mit passenden Provider-Overrides.',
    );
  }
}
