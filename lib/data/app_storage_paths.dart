import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/data/storage_directory_tools.dart';
import 'package:dsa_heldenverwaltung/data/storage_exceptions.dart';

import 'app_support_path_loader_stub.dart'
    if (dart.library.io) 'app_support_path_loader_io.dart'
    as app_support_path;
import 'storage_path_access_stub.dart'
    if (dart.library.io) 'storage_path_access_io.dart' as storage_access;

typedef AppSupportPathLoader = Future<String> Function();
typedef DirectoryValidator = Future<void> Function(String path);
typedef DirectoryCreator = Future<void> Function(String path);
typedef StorageCapabilityChecker = bool Function();

/// Beschreibt den effektiven Speicherort der Heldendaten.
class HeroStorageLocation {
  /// Erstellt eine Beschreibung des aktuell wirksamen Heldenspeicherpfads.
  const HeroStorageLocation({
    required this.defaultPath,
    required this.effectivePath,
    required this.customPathSupported,
    required this.usesCustomPath,
    this.configuredPath,
    this.validationError,
  });

  /// Standardordner fuer Heldendaten ohne Nutzer-Override.
  final String defaultPath;

  /// Tatsaechlich verwendeter oder angezeigter Pfad.
  final String effectivePath;

  /// Optional konfigurierter Nutzerpfad.
  final String? configuredPath;

  /// Gibt an, ob die Plattform einen benutzerdefinierten Heldenspeicher erlaubt.
  final bool customPathSupported;

  /// Gibt an, ob aktuell ein benutzerdefinierter Pfad aktiv ist.
  final bool usesCustomPath;

  /// Validierungsfehler fuer einen konfigurierten Pfad.
  final String? validationError;

  /// Ob der effektive Pfad ohne Fehler nutzbar ist.
  bool get isAccessible => validationError == null;
}

/// Kapselt Standard- und Override-Pfade fuer App-Daten.
class AppStoragePaths {
  /// Erstellt die Pfadlogik mit optionalen Test-Hooks.
  const AppStoragePaths({
    this.appSupportPathLoader = _loadAppSupportPath,
    this.directoryValidator = storage_access.validateExistingWritableDirectory,
    this.directoryCreator = storage_access.ensureDirectoryExists,
    this.customHeroStorageSupport = _supportsCustomHeroStoragePath,
    this.localDirectorySupport = _supportsLocalDirectoryAccess,
  });

  static const String settingsDirectoryName = 'Einstellungen';
  static const String heroesDirectoryName = 'Helden';

  final AppSupportPathLoader appSupportPathLoader;
  final DirectoryValidator directoryValidator;
  final DirectoryCreator directoryCreator;
  final StorageCapabilityChecker customHeroStorageSupport;
  final StorageCapabilityChecker localDirectorySupport;

  /// Gibt zurueck, ob Desktop-Plattformen einen benutzerdefinierten
  /// Heldenspeicherpfad unterstuetzen.
  bool supportsCustomHeroStoragePath() {
    return customHeroStorageSupport();
  }

  /// Loest den lokalen Einstellungsordner auf und legt ihn bei Bedarf an.
  Future<String> resolveSettingsStoragePath() async {
    final supportPath = await appSupportPathLoader();
    final targetPath = path.join(supportPath, settingsDirectoryName);
    if (_supportsLocalDirectories()) {
      await directoryCreator(targetPath);
    }
    return targetPath;
  }

  /// Loest den Standardordner fuer Heldendaten auf.
  Future<String> resolveDefaultHeroStoragePath() async {
    final supportPath = await appSupportPathLoader();
    return path.join(supportPath, heroesDirectoryName);
  }

  /// Beschreibt den aktuell wirksamen Heldenspeicherpfad samt Validierung.
  Future<HeroStorageLocation> describeHeroStorageLocation({
    String? configuredPath,
  }) async {
    final defaultPath = await resolveDefaultHeroStoragePath();
    final trimmedPath = configuredPath?.trim();
    final hasConfiguredPath = trimmedPath != null && trimmedPath.isNotEmpty;
    final customPathSupported = supportsCustomHeroStoragePath();

    if (!hasConfiguredPath || !customPathSupported) {
      return HeroStorageLocation(
        defaultPath: defaultPath,
        effectivePath: defaultPath,
        configuredPath: hasConfiguredPath ? trimmedPath : null,
        customPathSupported: customPathSupported,
        usesCustomPath: false,
      );
    }

    try {
      await directoryValidator(trimmedPath);
      return HeroStorageLocation(
        defaultPath: defaultPath,
        effectivePath: trimmedPath,
        configuredPath: trimmedPath,
        customPathSupported: true,
        usesCustomPath: true,
      );
    } on HeroStoragePathException catch (error) {
      return HeroStorageLocation(
        defaultPath: defaultPath,
        effectivePath: trimmedPath,
        configuredPath: trimmedPath,
        customPathSupported: true,
        usesCustomPath: true,
        validationError: error.message,
      );
    }
  }

  /// Bereitet den aktiven Heldenspeicherpfad fuer Repository-Zugriffe vor.
  Future<String> prepareHeroStoragePath({String? configuredPath}) async {
    final location = await describeHeroStorageLocation(
      configuredPath: configuredPath,
    );

    if (location.usesCustomPath) {
      if (location.validationError != null) {
        throw HeroStoragePathException(location.validationError!);
      }
      return location.effectivePath;
    }

    if (_supportsLocalDirectories()) {
      await directoryCreator(location.effectivePath);
    }
    return location.effectivePath;
  }

  /// Gibt zurueck, ob das Oeffnen eines Speicherordners moeglich ist.
  bool canOpenDirectories() {
    return canOpenStorageDirectory();
  }

  /// Gibt zurueck, ob diese Plattform reale lokale Verzeichnisse anbietet.
  bool _supportsLocalDirectories() {
    return localDirectorySupport();
  }
}

Future<String> _loadAppSupportPath() async {
  return app_support_path.loadApplicationSupportPath();
}

bool _supportsCustomHeroStoragePath() {
  if (kIsWeb) return false;
  // MSIX-Sandbox: Custom Paths werden nicht unterstuetzt.
  if (storage_access.isMsixPackage()) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

bool _supportsLocalDirectoryAccess() {
  return !kIsWeb;
}
