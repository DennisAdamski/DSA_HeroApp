import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

/// Web-Stub: Custom-Kataloge sind ohne Dateisystem nicht verfuegbar.
Future<CustomCatalogSnapshot> loadCustomCatalogFromDisk({
  required String heroStoragePath,
  required String catalogVersion,
  required String Function({
    required String catalogVersion,
    required CatalogSectionId section,
  }) resolveSectionDirectory,
}) async {
  return const CustomCatalogSnapshot();
}

/// Web-Stub: Schreiben ist ohne Dateisystem nicht moeglich.
Future<void> saveCustomCatalogEntryToDisk({
  required String directoryPath,
  required String fileName,
  required Map<String, dynamic> data,
}) async {}

/// Web-Stub: Loeschen ist ohne Dateisystem nicht moeglich.
Future<void> deleteCustomCatalogEntryFromDisk({
  required String filePath,
}) async {}
