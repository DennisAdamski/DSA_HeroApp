import 'package:dsa_heldenverwaltung/data/storage_exceptions.dart';

/// Stub: Nicht-IO-Plattformen laufen nie als MSIX-Paket.
bool isMsixPackage() => false;

/// Stub fuer Pfadvalidierung ausserhalb von IO-Plattformen.
Future<void> validateExistingWritableDirectory(String path) async {
  throw const HeroStoragePathException(
    'Benutzerdefinierte Heldenspeicherorte werden auf dieser Plattform '
    'nicht unterstuetzt.',
  );
}

/// Stub fuer Verzeichniserzeugung ausserhalb von IO-Plattformen.
Future<void> ensureDirectoryExists(String path) async {
  throw const HeroStoragePathException(
    'Lokale Verzeichnisse koennen auf dieser Plattform nicht erstellt werden.',
  );
}
