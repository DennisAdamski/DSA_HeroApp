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
}
