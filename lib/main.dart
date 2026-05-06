import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_picker_impl.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_startup_gate.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/web_auth_gate.dart';

/// Startet die Anwendung und initialisiert die persistenten Heldendaten.
Future<void> main() async {
  await runZonedGuarded(
    _runApp,
    (error, stack) {
      debugPrint('[boot] FATAL UNCAUGHT: $error\n$stack');
    },
  );
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[boot] hive init…');
  await Hive.initFlutter();
  debugPrint('[boot] firebase…');
  final firebaseBootstrap = await bootstrapFirebase();
  debugPrint('[boot] settings path…');
  const storagePaths = AppStoragePaths();
  final settingsPath = await storagePaths.resolveSettingsStoragePath();
  debugPrint('[boot] settings repo…');
  final settingsRepo = await HiveSettingsRepository.create(
    storagePath: settingsPath,
  );
  debugPrint('[boot] runApp');

  runApp(
    WebAuthGate(
      firebaseBootstrap: firebaseBootstrap,
      builder: (context, user) => AppStartupGate(
        settingsRepository: settingsRepo,
        storagePaths: storagePaths,
        storageDirectoryPicker: createStorageDirectoryPicker(),
        firebaseBootstrap: firebaseBootstrap,
        authUser: user,
      ),
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
