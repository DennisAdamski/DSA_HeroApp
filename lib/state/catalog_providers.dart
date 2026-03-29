import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_loader.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';

/// Laedt die Basis-Assets und typisiert daraus Laufzeitkataloge.
final catalogLoaderProvider = Provider<CatalogLoader>((ref) {
  return const CatalogLoader();
});

/// Dateibasiertes Repository fuer benutzerdefinierte Katalogeintraege.
final customCatalogRepositoryProvider = Provider<CustomCatalogRepository>((
  ref,
) {
  throw UnimplementedError(
    'CustomCatalogRepository muss beim App-Start uebersteuert werden.',
  );
});

/// Manuelle Reload-Zaehlung fuer Basis- und Custom-Katalogdaten.
final catalogReloadRevisionProvider = StateProvider<int>((ref) => 0);

/// Aufgeloeste Laufzeitdaten aus Basis-Assets und konfliktfreien Customs.
final catalogRuntimeDataProvider = FutureProvider<CatalogRuntimeData>((
  ref,
) async {
  ref.watch(catalogReloadRevisionProvider);
  final loader = ref.watch(catalogLoaderProvider);
  final repository = ref.watch(customCatalogRepositoryProvider);
  final baseData = await loader.loadDefaultSourceData();
  final customSnapshot = await repository.load(
    catalogVersion: baseData.version,
  );
  return CatalogRuntimeData.resolve(
    baseData: baseData,
    customSnapshot: customSnapshot,
  );
});

/// Effektiver, fuer die App genutzter Regelkatalog.
final rulesCatalogProvider = FutureProvider<RulesCatalog>((ref) async {
  final runtimeData = await ref.watch(catalogRuntimeDataProvider.future);
  final loader = ref.watch(catalogLoaderProvider);
  return loader.buildCatalogFromSourceData(runtimeData.effectiveData);
});

/// UI-tauglicher Snapshot fuer die Katalogverwaltung in den Einstellungen.
final catalogAdminSnapshotProvider = FutureProvider<CatalogAdminSnapshot>((
  ref,
) async {
  final runtimeData = await ref.watch(catalogRuntimeDataProvider.future);
  return CatalogAdminSnapshot.fromRuntimeData(runtimeData);
});

/// Kapselt manuelle Refreshes des wirksamen Laufzeitkatalogs.
class CatalogActions {
  CatalogActions(this._ref);

  final Ref _ref;

  /// Erzwingt einen Neu-Ladevorgang des Basis- und Custom-Katalogs.
  void reloadCatalog() {
    _ref.read(catalogReloadRevisionProvider.notifier).state++;
  }

  /// Speichert einen benutzerdefinierten Katalogeintrag im Heldenspeicher.
  Future<void> saveCustomEntry({
    required CatalogSectionId section,
    required Map<String, dynamic> entry,
    String previousId = '',
  }) async {
    validateCatalogEntryStructure(section, entry);
    final canonical = canonicalizeCatalogEntry(section, entry);
    final nextId = (canonical['id'] as String? ?? '').trim();
    if (nextId.isEmpty) {
      throw const FormatException(
        'Katalogeintrag benötigt eine nicht-leere ID.',
      );
    }

    final adminSnapshot = await _ref.read(catalogAdminSnapshotProvider.future);
    final baseConflict = adminSnapshot
        .section(section)
        .baseEntries
        .any((baseEntry) => baseEntry.id == nextId);
    if (baseConflict) {
      throw FormatException(
        'Die ID "$nextId" existiert bereits im Basis-Katalog.',
      );
    }

    final normalizedPreviousId = previousId.trim();
    final customConflict = adminSnapshot
        .section(section)
        .customEntries
        .any(
          (customEntry) =>
              customEntry.id == nextId &&
              customEntry.id != normalizedPreviousId,
        );
    if (customConflict) {
      throw FormatException(
        'Die ID "$nextId" existiert bereits als Custom-Eintrag.',
      );
    }

    final repository = _ref.read(customCatalogRepositoryProvider);
    await repository.saveEntry(
      catalogVersion: adminSnapshot.catalogVersion,
      section: section,
      entry: canonical,
    );
    if (normalizedPreviousId.isNotEmpty && normalizedPreviousId != nextId) {
      await repository.deleteEntry(
        catalogVersion: adminSnapshot.catalogVersion,
        section: section,
        entryId: normalizedPreviousId,
      );
    }
    reloadCatalog();
  }

  /// Entfernt einen benutzerdefinierten Eintrag aus dem Heldenspeicher.
  Future<void> deleteCustomEntry({
    required CatalogSectionId section,
    required String entryId,
  }) async {
    final adminSnapshot = await _ref.read(catalogAdminSnapshotProvider.future);
    final repository = _ref.read(customCatalogRepositoryProvider);
    await repository.deleteEntry(
      catalogVersion: adminSnapshot.catalogVersion,
      section: section,
      entryId: entryId.trim(),
    );
    reloadCatalog();
  }
}

/// Schreib- und Reload-Aktionen fuer die Katalogverwaltung.
final catalogActionsProvider = Provider<CatalogActions>((ref) {
  return CatalogActions(ref);
});
