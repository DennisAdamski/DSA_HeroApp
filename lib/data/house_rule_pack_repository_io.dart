import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';

/// Laedt importierte Hausregel-Pakete aus dem aktiven Heldenspeicher.
class HouseRulePackRepository {
  /// Erstellt das Repository fuer den aktuellen Heldenspeicher.
  const HouseRulePackRepository({required this.heroStoragePath});

  static const String houseRulePackRootDirectory = 'house_rule_packs';

  /// Absoluter Pfad des aktiven Heldenspeichers.
  final String heroStoragePath;

  /// Laedt alle Paket-Manifeste einer Katalogversion.
  Future<HouseRulePackSourceSnapshot> load({
    required String catalogVersion,
  }) async {
    if (heroStoragePath.trim().isEmpty) {
      return const HouseRulePackSourceSnapshot();
    }

    final rootDirectory = Directory(
      path.join(heroStoragePath, houseRulePackRootDirectory, catalogVersion),
    );
    if (!await rootDirectory.exists()) {
      return const HouseRulePackSourceSnapshot();
    }

    final packs = <HouseRulePackManifest>[];
    final issues = <HouseRulePackIssue>[];
    final seenIds = <String>{};
    final childDirectories =
        await rootDirectory
              .list()
              .where((entity) => entity is Directory)
              .cast<Directory>()
              .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final directory in childDirectories) {
      final manifestFile = File(path.join(directory.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        continue;
      }

      try {
        final raw = await manifestFile.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException(
            'Hausregel-Manifest muss ein JSON-Objekt sein.',
          );
        }
        final manifest = HouseRulePackManifest.fromJson(
          decoded.cast<String, dynamic>(),
          filePath: manifestFile.path,
          isBuiltIn: false,
        );
        if (!seenIds.add(manifest.id)) {
          issues.add(
            HouseRulePackIssue(
              packId: manifest.id,
              packTitle: manifest.title,
              filePath: manifestFile.path,
              message:
                  'Doppelte importierte Paket-ID; das spaetere Manifest wird ignoriert.',
            ),
          );
          continue;
        }
        packs.add(manifest);
      } on FormatException catch (error) {
        issues.add(
          HouseRulePackIssue(
            filePath: manifestFile.path,
            message: error.message,
          ),
        );
      } on FileSystemException catch (error) {
        issues.add(
          HouseRulePackIssue(
            filePath: manifestFile.path,
            message: 'Manifest konnte nicht gelesen werden: ${error.message}',
          ),
        );
      }
    }

    return HouseRulePackSourceSnapshot(
      packs: List<HouseRulePackManifest>.unmodifiable(packs),
      issues: List<HouseRulePackIssue>.unmodifiable(issues),
    );
  }

  /// Laedt ein einzelnes importiertes Paket gezielt aus dem Heldenspeicher.
  Future<HouseRulePackManifest?> loadSinglePack({
    required String catalogVersion,
    required String packId,
  }) async {
    final manifestFile = _manifestFile(
      catalogVersion: catalogVersion,
      packId: packId,
    );
    if (!await manifestFile.exists()) {
      return null;
    }

    final raw = await manifestFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException(
        'Hausregel-Manifest muss ein JSON-Objekt sein.',
      );
    }
    return HouseRulePackManifest.fromJson(
      decoded.cast<String, dynamic>(),
      filePath: manifestFile.path,
      isBuiltIn: false,
    );
  }

  /// Speichert ein importiertes Paket im Heldenspeicher.
  ///
  /// Wenn [previousPackId] gesetzt ist und sich die ID geaendert hat, wird der
  /// alte Paketordner nach erfolgreichem Speichern entfernt.
  Future<void> saveManifest({
    required String catalogVersion,
    required Map<String, dynamic> manifestJson,
    String previousPackId = '',
  }) async {
    _ensureWritableStorage();
    final manifest = HouseRulePackManifest.fromJson(
      manifestJson,
      isBuiltIn: false,
    );
    final targetDirectory = _packDirectory(
      catalogVersion: catalogVersion,
      packId: manifest.id,
    );
    await targetDirectory.create(recursive: true);
    final manifestFile = File(path.join(targetDirectory.path, 'manifest.json'));
    final encoder = const JsonEncoder.withIndent('  ');
    final payload = '${encoder.convert(manifest.toJson())}\n';
    await manifestFile.writeAsString(payload);

    final normalizedPreviousId = previousPackId.trim();
    if (normalizedPreviousId.isNotEmpty &&
        normalizedPreviousId != manifest.id) {
      final previousDirectory = _packDirectory(
        catalogVersion: catalogVersion,
        packId: normalizedPreviousId,
      );
      if (await previousDirectory.exists()) {
        await previousDirectory.delete(recursive: true);
      }
    }
  }

  /// Entfernt ein importiertes Paket vollstaendig aus dem Heldenspeicher.
  Future<void> deletePack({
    required String catalogVersion,
    required String packId,
  }) async {
    _ensureWritableStorage();
    final targetDirectory = _packDirectory(
      catalogVersion: catalogVersion,
      packId: packId,
    );
    if (await targetDirectory.exists()) {
      await targetDirectory.delete(recursive: true);
    }
  }

  Directory _versionRootDirectory({required String catalogVersion}) {
    return Directory(
      path.join(heroStoragePath, houseRulePackRootDirectory, catalogVersion),
    );
  }

  Directory _packDirectory({
    required String catalogVersion,
    required String packId,
  }) {
    return Directory(
      path.join(
        _versionRootDirectory(catalogVersion: catalogVersion).path,
        packId,
      ),
    );
  }

  File _manifestFile({required String catalogVersion, required String packId}) {
    return File(
      path.join(
        _packDirectory(catalogVersion: catalogVersion, packId: packId).path,
        'manifest.json',
      ),
    );
  }

  void _ensureWritableStorage() {
    if (heroStoragePath.trim().isEmpty) {
      throw const FileSystemException(
        'Hausregel-Pakete koennen ohne aktiven Heldenspeicher nicht gespeichert werden.',
      );
    }
  }
}
