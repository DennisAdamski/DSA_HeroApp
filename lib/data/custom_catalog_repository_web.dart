import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

/// Web-Stub fuer [CustomCatalogRepository].
///
/// Im Web v1 sind Custom-Kataloge nicht verfuegbar (kein lokales
/// Dateisystem). [load] liefert ein leeres Snapshot, Schreibvorgaenge
/// werfen einen [UnsupportedError]. Die UI muss Custom-Katalog-Aktionen
/// im Web ausblenden.
class CustomCatalogRepository {
  const CustomCatalogRepository({required this.heroStoragePath});

  static const String customCatalogRootDirectory = 'custom_catalogs';

  final String heroStoragePath;

  Future<CustomCatalogSnapshot> load({required String catalogVersion}) async {
    return const CustomCatalogSnapshot();
  }

  Future<void> saveEntry({
    required String catalogVersion,
    required CatalogSectionId section,
    required Map<String, dynamic> entry,
  }) async {
    throw UnsupportedError(
      'Custom-Kataloge stehen im Web v1 nicht zur Verfuegung.',
    );
  }

  Future<void> deleteEntry({
    required String catalogVersion,
    required CatalogSectionId section,
    required String entryId,
  }) async {
    // No-Op: Es gibt keine Custom-Eintraege im Web.
  }

  Future<void> importTransferEntries({
    required String catalogVersion,
    required Iterable<CustomCatalogEntryRecord> entries,
  }) async {
    throw UnsupportedError(
      'Custom-Kataloge stehen im Web v1 nicht zur Verfuegung.',
    );
  }

  Future<List<CustomCatalogEntryRecord>> loadEntriesByIds({
    required String catalogVersion,
    required Map<CatalogSectionId, Set<String>> idsBySection,
  }) async {
    return const <CustomCatalogEntryRecord>[];
  }

  String resolveSectionDirectory({
    required String catalogVersion,
    required CatalogSectionId section,
  }) {
    return '';
  }
}
