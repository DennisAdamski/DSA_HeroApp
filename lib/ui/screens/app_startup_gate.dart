import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/data/hive_externe_helden_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_gruppen_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_picker.dart';
import 'package:dsa_heldenverwaltung/data/startup_hero_importer.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/gruppen_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_shell.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

/// Initialisiert das Helden-Repository anhand der aktuellen Einstellungen.
class AppStartupGate extends StatefulWidget {
  /// Erstellt das Startup-Gate fuer den App-Start.
  const AppStartupGate({
    super.key,
    required this.settingsRepository,
    required this.storagePaths,
    required this.storageDirectoryPicker,
    required this.firebaseBootstrap,
  });

  /// Persistenz fuer lokale App-Einstellungen.
  final HiveSettingsRepository settingsRepository;

  /// Zentrale Pfadlogik fuer Einstellungen und Heldendaten.
  final AppStoragePaths storagePaths;

  /// Native Ordnerauswahl fuer Desktop-Speicherpfade.
  final StorageDirectoryPicker storageDirectoryPicker;

  /// Ergebnis der optionalen Firebase-Initialisierung beim App-Start.
  final FirebaseBootstrapResult firebaseBootstrap;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  Future<_HeroRepositoryBootstrapResult>? _bootstrapFuture;
  HiveHeroRepository? _activeRepository;
  HiveGruppenRepository? _activeGruppenRepository;
  HiveExterneHeldenRepository? _activeExterneHeldenRepository;
  late AppSettings _settings;
  StreamSubscription<AppSettings>? _settingsSubscription;
  String? _currentConfiguredPath;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsRepository.load();
    _settingsSubscription = widget.settingsRepository.watch().listen((
      settings,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _ensureBootstrap();
      });
    });
    _ensureBootstrap();
  }

  @override
  void dispose() {
    unawaited(_settingsSubscription?.cancel());
    final repository = _activeRepository;
    if (repository != null) {
      // Die Boxen muessen beim Pfadwechsel sauber geschlossen werden.
      unawaited(repository.close());
    }
    final gruppenRepository = _activeGruppenRepository;
    if (gruppenRepository != null) {
      unawaited(gruppenRepository.close());
    }
    final externeHeldenRepository = _activeExterneHeldenRepository;
    if (externeHeldenRepository != null) {
      unawaited(externeHeldenRepository.close());
    }
    super.dispose();
  }

  void _ensureBootstrap() {
    final configuredPath = _settings.heroStoragePath;
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

    final heroStoragePath = await widget.storagePaths.prepareHeroStoragePath(
      configuredPath: configuredPath,
    );
    final repository = await HiveHeroRepository.create(
      storagePath: heroStoragePath,
    );
    await const StartupHeroImporter().importFromAssets(repository);

    // Gruppen-Repository im Settings-Pfad oeffnen.
    final settingsPath = await widget.storagePaths.resolveSettingsStoragePath();
    final gruppenRepository = await HiveGruppenRepository.create(
      storagePath: settingsPath,
    );

    // Externe-Helden-Repository im Heldenspeicher oeffnen.
    final externeHeldenRepository = await HiveExterneHeldenRepository.create(
      storagePath: heroStoragePath,
    );

    if (generation != _loadGeneration) {
      await repository.close();
      await gruppenRepository.close();
      await externeHeldenRepository.close();
      throw StateError('Veralteter Initialisierungslauf fuer Heldendaten.');
    }

    // Alte Repositories schliessen, falls vorhanden.
    final previousGruppen = _activeGruppenRepository;
    if (previousGruppen != null) {
      await previousGruppen.close();
    }
    final previousExterneHelden = _activeExterneHeldenRepository;
    if (previousExterneHelden != null) {
      await previousExterneHelden.close();
    }

    _activeRepository = repository;
    _activeGruppenRepository = gruppenRepository;
    _activeExterneHeldenRepository = externeHeldenRepository;
    return _HeroRepositoryBootstrapResult(
      repository: repository,
      gruppenRepository: gruppenRepository,
      externeHeldenRepository: externeHeldenRepository,
      heroStoragePath: heroStoragePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _bootstrapFuture;
    if (future == null) {
      return _buildScope(
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return FutureBuilder<_HeroRepositoryBootstrapResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildScope(
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return _buildScope(
            home: _HeroStorageErrorScreen(error: snapshot.error!),
          );
        }

        final result = snapshot.requireData;
        return _buildScope(
          repository: result.repository,
          gruppenRepository: result.gruppenRepository,
          externeHeldenRepository: result.externeHeldenRepository,
          customCatalogRepository: CustomCatalogRepository(
            heroStoragePath: result.heroStoragePath,
          ),
          home: const HeroesHomeScreen(),
        );
      },
    );
  }

  Widget _buildScope({
    required Widget home,
    HiveHeroRepository? repository,
    HiveGruppenRepository? gruppenRepository,
    HiveExterneHeldenRepository? externeHeldenRepository,
    CustomCatalogRepository? customCatalogRepository,
  }) {
    final scopeKey = ValueKey<String>(
      '${repository?.hashCode ?? 'none'}|${_currentConfiguredPath ?? 'default'}',
    );
    final overrides = [
      settingsRepositoryProvider.overrideWithValue(widget.settingsRepository),
      storageDirectoryPickerProvider.overrideWithValue(
        widget.storageDirectoryPicker,
      ),
      appStoragePathsProvider.overrideWithValue(widget.storagePaths),
      firebaseBootstrapProvider.overrideWithValue(widget.firebaseBootstrap),
      customCatalogRepositoryProvider.overrideWithValue(
        customCatalogRepository ??
            const CustomCatalogRepository(heroStoragePath: ''),
      ),
    ];
    if (repository != null) {
      overrides.add(heroRepositoryProvider.overrideWithValue(repository));
    }
    if (gruppenRepository != null) {
      overrides.add(
        gruppenRepositoryProvider.overrideWithValue(gruppenRepository),
      );
    }
    if (externeHeldenRepository != null) {
      overrides.add(
        externeHeldenRepositoryProvider.overrideWithValue(
          externeHeldenRepository,
        ),
      );
    }

    return ProviderScope(
      key: scopeKey,
      overrides: overrides,
      child: DsaAppShell(home: home),
    );
  }
}

class _HeroRepositoryBootstrapResult {
  const _HeroRepositoryBootstrapResult({
    required this.repository,
    required this.gruppenRepository,
    required this.externeHeldenRepository,
    required this.heroStoragePath,
  });

  final HiveHeroRepository repository;
  final HiveGruppenRepository gruppenRepository;
  final HiveExterneHeldenRepository externeHeldenRepository;
  final String heroStoragePath;
}

/// Fehleransicht fuer ungueltige oder nicht verfuegbare Heldenspeicherpfade.
class _HeroStorageErrorScreen extends StatelessWidget {
  const _HeroStorageErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heldenspeicher nicht verfügbar')),
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
                Text('$error', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                const Text(
                  'Prüfe den konfigurierten Heldenspeicher in den '
                  'Einstellungen. App-Einstellungen bleiben lokal verfügbar.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Einstellungen öffnen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
