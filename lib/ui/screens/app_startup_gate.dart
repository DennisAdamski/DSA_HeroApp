import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/data/firestore_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_externe_helden_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/data/hybrid_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_picker.dart';
import 'package:dsa_heldenverwaltung/data/startup_hero_importer.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
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
    this.authUser,
  });

  /// Persistenz fuer lokale App-Einstellungen.
  final HiveSettingsRepository settingsRepository;

  /// Zentrale Pfadlogik fuer Einstellungen und Heldendaten.
  final AppStoragePaths storagePaths;

  /// Native Ordnerauswahl fuer Desktop-Speicherpfade.
  final StorageDirectoryPicker storageDirectoryPicker;

  /// Ergebnis der optionalen Firebase-Initialisierung beim App-Start.
  final FirebaseBootstrapResult firebaseBootstrap;

  /// Eingeloggter Benutzer (falls vorhanden) — aktiviert Firestore-Sync.
  final AuthUser? authUser;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  Future<_HeroRepositoryBootstrapResult>? _bootstrapFuture;
  HiveHeroRepository? _activeHive;
  HybridHeroRepository? _activeHybrid;
  HiveExterneHeldenRepository? _activeExterneHeldenRepository;
  late AppSettings _settings;
  StreamSubscription<AppSettings>? _settingsSubscription;
  String? _currentConfiguredPath;
  String? _currentAuthUid;
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
  void didUpdateWidget(covariant AppStartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authUser?.uid != _currentAuthUid) {
      _ensureBootstrap();
    }
  }

  @override
  void dispose() {
    unawaited(_settingsSubscription?.cancel());
    final hybrid = _activeHybrid;
    if (hybrid != null) {
      unawaited(hybrid.close());
    }
    final hive = _activeHive;
    if (hive != null) {
      // Die Boxen muessen beim Pfadwechsel sauber geschlossen werden.
      unawaited(hive.close());
    }
    final externeHeldenRepository = _activeExterneHeldenRepository;
    if (externeHeldenRepository != null) {
      unawaited(externeHeldenRepository.close());
    }
    super.dispose();
  }

  void _ensureBootstrap() {
    final configuredPath = _settings.heroStoragePath;
    final targetUid = widget.authUser?.uid;
    if (_bootstrapFuture != null &&
        configuredPath == _currentConfiguredPath &&
        targetUid == _currentAuthUid) {
      return;
    }

    _currentConfiguredPath = configuredPath;
    _currentAuthUid = targetUid;
    _bootstrapFuture = _bootstrapHeroRepository(configuredPath, targetUid);
  }

  Future<_HeroRepositoryBootstrapResult> _bootstrapHeroRepository(
    String? configuredPath,
    String? authUid,
  ) async {
    debugPrint('[startup] enter uid=${authUid ?? "null"}');
    try {
      final int generation = ++_loadGeneration;

      // Vorheriges Hybrid-Repo (Subscription) zuerst schliessen, dann Hive.
      final previousHybrid = _activeHybrid;
      _activeHybrid = null;
      if (previousHybrid != null) {
        await previousHybrid.close();
      }
      final previousHive = _activeHive;
      _activeHive = null;
      if (previousHive != null) {
        await previousHive.close();
      }

      debugPrint('[startup] prepareHeroStoragePath…');
      final heroStoragePath = await widget.storagePaths.prepareHeroStoragePath(
        configuredPath: configuredPath,
      );
      debugPrint('[startup] hive.create path=$heroStoragePath');
      final hive = await HiveHeroRepository.create(
        storagePath: heroStoragePath,
      );
      debugPrint('[startup] importFromAssets…');
      await const StartupHeroImporter().importFromAssets(hive);

      debugPrint('[startup] externe helden…');
      // Externe-Helden-Repository im Heldenspeicher oeffnen.
      final externeHeldenRepository = await HiveExterneHeldenRepository.create(
        storagePath: heroStoragePath,
      );

      // Bei Login + verfuegbarem Firebase: Hybrid-Repo mit Firestore-Sync.
      HybridHeroRepository? hybrid;
      HeroRepository heroRepository = hive;
      if (authUid != null && widget.firebaseBootstrap.isAvailable) {
        debugPrint('[startup] hybrid.create for uid=$authUid');
        final firestoreRepo = FirestoreHeroRepository(userId: authUid);
        hybrid = await HybridHeroRepository.create(
          local: hive,
          remote: firestoreRepo,
        );
        heroRepository = hybrid;
      }

      if (generation != _loadGeneration) {
        if (hybrid != null) {
          await hybrid.close();
        }
        await hive.close();
        await externeHeldenRepository.close();
        throw StateError('Veralteter Initialisierungslauf fuer Heldendaten.');
      }

      // Altes externes Repo schliessen, falls vorhanden.
      final previousExterneHelden = _activeExterneHeldenRepository;
      if (previousExterneHelden != null) {
        await previousExterneHelden.close();
      }

      _activeHive = hive;
      _activeHybrid = hybrid;
      _activeExterneHeldenRepository = externeHeldenRepository;
      debugPrint('[startup] done');
      return _HeroRepositoryBootstrapResult(
        heroRepository: heroRepository,
        externeHeldenRepository: externeHeldenRepository,
        heroStoragePath: heroStoragePath,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('[startup] FAILED: $error\n$stackTrace');
      rethrow;
    }
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
          repository: result.heroRepository,
          externeHeldenRepository: result.externeHeldenRepository,
          customCatalogRepository: CustomCatalogRepository(
            heroStoragePath: result.heroStoragePath,
          ),
          houseRulePackRepository: HouseRulePackRepository(
            heroStoragePath: result.heroStoragePath,
          ),
          home: const HeroesHomeScreen(),
        );
      },
    );
  }

  Widget _buildScope({
    required Widget home,
    HeroRepository? repository,
    HiveExterneHeldenRepository? externeHeldenRepository,
    CustomCatalogRepository? customCatalogRepository,
    HouseRulePackRepository? houseRulePackRepository,
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
      houseRulePackRepositoryProvider.overrideWithValue(
        houseRulePackRepository ??
            const HouseRulePackRepository(heroStoragePath: ''),
      ),
    ];
    if (repository != null) {
      overrides.add(heroRepositoryProvider.overrideWithValue(repository));
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
    required this.heroRepository,
    required this.externeHeldenRepository,
    required this.heroStoragePath,
  });

  final HeroRepository heroRepository;
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
