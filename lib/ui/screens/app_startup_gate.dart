import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/startup_hero_importer.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_shell.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

/// Initialisiert das Helden-Repository anhand der aktuellen Einstellungen.
class AppStartupGate extends ConsumerStatefulWidget {
  /// Erstellt das Startup-Gate fuer den App-Start.
  const AppStartupGate({super.key});

  @override
  ConsumerState<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends ConsumerState<AppStartupGate> {
  Future<_HeroRepositoryBootstrapResult>? _bootstrapFuture;
  HiveHeroRepository? _activeRepository;
  String? _currentConfiguredPath;
  int _loadGeneration = 0;

  @override
  void dispose() {
    final repository = _activeRepository;
    if (repository != null) {
      // Die Boxen muessen beim Pfadwechsel sauber geschlossen werden.
      unawaited(repository.close());
    }
    super.dispose();
  }

  void _ensureBootstrap(AppSettings settings) {
    final configuredPath = settings.heroStoragePath;
    if (_bootstrapFuture != null && configuredPath == _currentConfiguredPath) {
      return;
    }

    _currentConfiguredPath = configuredPath;
    _bootstrapFuture = _bootstrapHeroRepository(configuredPath);
  }

  Future<_HeroRepositoryBootstrapResult> _bootstrapHeroRepository(
    String? configuredPath,
  ) async {
    final int generation = ++_loadGeneration;
    final previousRepository = _activeRepository;
    _activeRepository = null;
    if (previousRepository != null) {
      await previousRepository.close();
    }

    final storagePaths = ref.read(appStoragePathsProvider);
    final heroStoragePath = await storagePaths.prepareHeroStoragePath(
      configuredPath: configuredPath,
    );
    final repository = await HiveHeroRepository.create(
      storagePath: heroStoragePath,
    );
    await const StartupHeroImporter().importFromAssets(repository);

    if (generation != _loadGeneration) {
      await repository.close();
      throw StateError('Veralteter Initialisierungslauf fuer Heldendaten.');
    }

    _activeRepository = repository;
    return _HeroRepositoryBootstrapResult(repository: repository);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    if (settingsAsync.isLoading && !settingsAsync.hasValue) {
      return const DsaAppShell(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (settingsAsync.hasError) {
      return DsaAppShell(
        home: _HeroStorageErrorScreen(error: settingsAsync.error!),
      );
    }

    final settings = settingsAsync.valueOrNull ?? const AppSettings();
    _ensureBootstrap(settings);

    final future = _bootstrapFuture;
    if (future == null) {
      return const DsaAppShell(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return FutureBuilder<_HeroRepositoryBootstrapResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const DsaAppShell(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return DsaAppShell(
            home: _HeroStorageErrorScreen(error: snapshot.error!),
          );
        }

        final result = snapshot.requireData;
        return ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(result.repository),
          ],
          child: const DsaAppShell(home: HeroesHomeScreen()),
        );
      },
    );
  }
}

class _HeroRepositoryBootstrapResult {
  const _HeroRepositoryBootstrapResult({required this.repository});

  final HiveHeroRepository repository;
}

/// Fehleransicht fuer ungueltige oder nicht verfuegbare Heldenspeicherpfade.
class _HeroStorageErrorScreen extends StatelessWidget {
  const _HeroStorageErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heldenspeicher nicht verfuegbar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Die Heldendaten konnten nicht geladen werden.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pruefe den konfigurierten Heldenspeicher in den '
                  'Einstellungen. App-Einstellungen bleiben lokal verfuegbar.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Einstellungen oeffnen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
