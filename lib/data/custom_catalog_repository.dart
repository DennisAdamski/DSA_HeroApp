import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

import 'custom_catalog_file_ops_stub.dart'
    if (dart.library.io) 'custom_catalog_file_ops_io.dart' as file_ops;

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
    return file_ops.loadCustomCatalogFromDisk(
      heroStoragePath: heroStoragePath,
      catalogVersion: catalogVersion,
      resolveSectionDirectory: resolveSectionDirectory,
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
    await file_ops.saveCustomCatalogEntryToDisk(
      directoryPath: resolveSectionDirectory(
        catalogVersion: catalogVersion,
        section: section,
      ),
      fileName: _fileNameForId(entryId),
      data: canonical,
    );
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
    await file_ops.deleteCustomCatalogEntryFromDisk(
      filePath: path.join(
        resolveSectionDirectory(
          catalogVersion: catalogVersion,
          section: section,
        ),
        _fileNameForId(entryId),
      ),
    );
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
