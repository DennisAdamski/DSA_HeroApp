import 'dart:io';

import 'package:dsa_heldenverwaltung/data/storage_exceptions.dart';

/// Prueft, ob ein existierendes Verzeichnis beschreibbar ist.
Future<void> validateExistingWritableDirectory(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    throw const HeroStoragePathException(
      'Der konfigurierte Heldenspeicherpfad existiert nicht.',
    );
  }

  final stat = await FileSystemEntity.type(path);
  if (stat != FileSystemEntityType.directory) {
    throw const HeroStoragePathException(
      'Der konfigurierte Heldenspeicherpfad ist kein Ordner.',
    );
  }

  await _verifyWritableDirectory(directory);
}

/// Legt ein Verzeichnis rekursiv an und prueft den Schreibzugriff.
Future<void> ensureDirectoryExists(String path) async {
  final directory = Directory(path);
  await directory.create(recursive: true);
  await _verifyWritableDirectory(directory);
}

/// Erstellt temporaer eine Datei, um den Schreibzugriff belastbar zu pruefen.
Future<void> _verifyWritableDirectory(Directory directory) async {
  final probeFile = File(
    '${directory.path}${Platform.pathSeparator}.write_probe',
  );
  try {
    await probeFile.writeAsString('probe', flush: true);
    if (await probeFile.exists()) {
      await probeFile.delete();
    }
  } on FileSystemException {
    throw const HeroStoragePathException(
      'Auf den konfigurierten Heldenspeicherpfad kann nicht geschrieben werden.',
    );
  }
}
