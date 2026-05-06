import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

/// Verwaltet benutzerdefinierte Katalogeintraege als Einzeldateien.
class CustomCatalogRepository {
  /// Erstellt das Repository fuer den aktiven Heldenspeicher.
  const CustomCatalogRepository({required this.heroStoragePath});

  static const String customCatalogRootDirectory = 'custom_catalogs';

  final String heroStoragePath;

  /// Laedt alle gueltigen Katalogdateien fuer eine Katalogversion.
  Future<CustomCatalogSnapshot> load({required String catalogVersion}) async {
    if (heroStoragePath.trim().isEmpty) {
      return const CustomCatalogSnapshot();
    }
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

  /// Speichert einen Custom-Eintrag als einzelne JSON-Datei.
  Future<void> saveEntry({
    required String catalogVersion,
    required CatalogSectionId section,
    required Map<String, dynamic> entry,
  }) async {
    _ensureHeroStoragePath();
    validateCatalogEntryStructure(section, entry);
    final canonical = canonicalizeCatalogEntry(section, entry);
    final entryId = _readRequiredId(canonical);
    final targetDirectory = Directory(
      resolveSectionDirectory(catalogVersion: catalogVersion, section: section),
    );
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    final targetFile = File(
      path.join(targetDirectory.path, _fileNameForId(entryId)),
    );
    const encoder = JsonEncoder.withIndent('  ');
    await targetFile.writeAsString(encoder.convert(canonical), flush: true);
  }

  /// Loescht einen vorhandenen Custom-Eintrag.
  Future<void> deleteEntry({
    required String catalogVersion,
    required CatalogSectionId section,
    required String entryId,
  }) async {
    if (heroStoragePath.trim().isEmpty) {
      return;
    }
    final file = File(
      path.join(
        resolveSectionDirectory(
          catalogVersion: catalogVersion,
          section: section,
        ),
        _fileNameForId(entryId),
      ),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Importiert eingebettete Transfer-Eintraege in den Heldenspeicher.
  Future<void> importTransferEntries({
    required String catalogVersion,
    required Iterable<CustomCatalogEntryRecord> entries,
  }) async {
    _ensureHeroStoragePath();
    for (final entry in entries) {
      await saveEntry(
        catalogVersion: catalogVersion,
        section: entry.section,
        entry: entry.data,
      );
    }
  }

  /// Laedt eine gezielte Menge vorhandener Custom-Eintraege fuer den Export.
  Future<List<CustomCatalogEntryRecord>> loadEntriesByIds({
    required String catalogVersion,
    required Map<CatalogSectionId, Set<String>> idsBySection,
  }) async {
    final snapshot = await load(catalogVersion: catalogVersion);
    return snapshot.entries
        .where((entry) {
          final ids = idsBySection[entry.section];
          return ids != null && ids.contains(entry.id);
        })
        .toList(growable: false);
  }

  /// Liefert den absoluten Speicherpfad einer Katalogsektion.
  String resolveSectionDirectory({
    required String catalogVersion,
    required CatalogSectionId section,
  }) {
    return path.join(
      heroStoragePath,
      customCatalogRootDirectory,
      catalogVersion,
      section.directoryName,
    );
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
    return CustomCatalogEntryRecord(
      section: section,
      id: _readRequiredId(canonical),
      filePath: file.path,
      data: canonical,
    );
  }

  String _readRequiredId(Map<String, dynamic> entry) {
    final entryId = (entry['id'] as String? ?? '').trim();
    if (entryId.isEmpty) {
      throw const FormatException(
        'Katalogeintrag benötigt eine nicht-leere ID.',
      );
    }
    return entryId;
  }

  String _fileNameForId(String entryId) {
    return '${Uri.encodeComponent(entryId)}.json';
  }

  void _ensureHeroStoragePath() {
    if (heroStoragePath.trim().isEmpty) {
      throw StateError('Der Heldenspeicherpfad ist noch nicht verfügbar.');
    }
  }
}
