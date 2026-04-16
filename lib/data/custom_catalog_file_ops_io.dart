import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

/// Laedt alle Custom-Katalogdateien aus einem Verzeichnis.
Future<CustomCatalogSnapshot> loadCustomCatalogFromDisk({
  required String heroStoragePath,
  required String catalogVersion,
  required String Function({
    required String catalogVersion,
    required CatalogSectionId section,
  }) resolveSectionDirectory,
}) async {
  final entries = <CustomCatalogEntryRecord>[];
  final issues = <CatalogIssue>[];
  final seenIds = <CatalogSectionId, Set<String>>{
    for (final section in editableCatalogSections) section: <String>{},
  };

  for (final section in editableCatalogSections) {
    final sectionDirectory = Directory(
      resolveSectionDirectory(
        catalogVersion: catalogVersion,
        section: section,
      ),
    );
    if (!await sectionDirectory.exists()) {
      continue;
    }

    final files = await sectionDirectory
        .list()
        .where(
          (entity) =>
              entity is File && path.extension(entity.path) == '.json',
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      try {
        final entry = await _loadEntryFile(section: section, file: file);
        final alreadySeen = seenIds[section]!;
        if (!alreadySeen.add(entry.id)) {
          issues.add(
            CatalogIssue(
              section: section,
              entryId: entry.id,
              filePath: file.path,
              message:
                  'Doppelte Custom-ID innerhalb derselben Sektion; Datei wird ignoriert.',
            ),
          );
          continue;
        }
        entries.add(entry);
      } on FormatException catch (error) {
        issues.add(
          CatalogIssue(
            section: section,
            filePath: file.path,
            message: error.message,
          ),
        );
      } on FileSystemException catch (error) {
        issues.add(
          CatalogIssue(
            section: section,
            filePath: file.path,
            message: 'Datei konnte nicht gelesen werden: ${error.message}',
          ),
        );
      }
    }
  }

  return CustomCatalogSnapshot(
    entries: List<CustomCatalogEntryRecord>.unmodifiable(entries),
    issues: List<CatalogIssue>.unmodifiable(issues),
  );
}

/// Speichert einen Custom-Eintrag als JSON-Datei auf der Festplatte.
Future<void> saveCustomCatalogEntryToDisk({
  required String directoryPath,
  required String fileName,
  required Map<String, dynamic> data,
}) async {
  final targetDirectory = Directory(directoryPath);
  if (!await targetDirectory.exists()) {
    await targetDirectory.create(recursive: true);
  }
  final targetFile = File(path.join(targetDirectory.path, fileName));
  const encoder = JsonEncoder.withIndent('  ');
  await targetFile.writeAsString(encoder.convert(data), flush: true);
}

/// Loescht eine Custom-Katalogdatei von der Festplatte.
Future<void> deleteCustomCatalogEntryFromDisk({
  required String filePath,
}) async {
  final file = File(filePath);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<CustomCatalogEntryRecord> _loadEntryFile({
  required CatalogSectionId section,
  required File file,
}) async {
  final raw = await file.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException(
      'Custom-Katalogdatei muss ein JSON-Objekt enthalten.',
    );
  }
  final canonical = canonicalizeCatalogEntry(
    section,
    decoded.cast<String, dynamic>(),
  );
  validateCatalogEntryStructure(section, canonical);
  final entryId = (canonical['id'] as String? ?? '').trim();
  if (entryId.isEmpty) {
    throw const FormatException(
      'Katalogeintrag benötigt eine nicht-leere ID.',
    );
  }
  return CustomCatalogEntryRecord(
    section: section,
    id: entryId,
    filePath: file.path,
    data: canonical,
  );
}
