import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_decrypt_runner.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_loader.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_catalog_resolver.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_provenance.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

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

/// Dateibasiertes Repository fuer importierte Hausregel-Pakete.
final houseRulePackRepositoryProvider = Provider<HouseRulePackRepository>((
  ref,
) {
  throw UnimplementedError(
    'HouseRulePackRepository muss beim App-Start uebersteuert werden.',
  );
});

/// Manuelle Reload-Zaehlung fuer Basis- und Custom-Katalogdaten.
final catalogReloadRevisionProvider = StateProvider<int>((ref) => 0);

/// Unveraenderte Basisdaten aus den offiziellen Katalog-Assets.
final baseCatalogSourceDataProvider = FutureProvider<CatalogSourceData>((
  ref,
) async {
  ref.watch(catalogReloadRevisionProvider);
  final loader = ref.watch(catalogLoaderProvider);
  return loader.loadDefaultSourceData();
});

/// Basisdaten nach optionalem Bulk-Decrypt aller `enc:`-Werte.
///
/// Sobald ein Inhalts-Passwort gespeichert ist, wird der Katalog einmal
/// komplett entschluesselt (Web: im Web Worker via `compute`). v3-Werte
/// nutzen den globalen Salt aus dem Manifest und benoetigen nur eine
/// PBKDF2-Ableitung pro Passwort. Nachgelagerte Provider (Runtime, Rules)
/// sehen ab dieser Stelle Klartext-Strings statt `enc:`-Praefixen.
///
/// Ohne Passwort wird die Quelle unveraendert durchgereicht — geschuetzte
/// Werte bleiben dann mit `enc:`-Praefix bestehen und werden in der UI als
/// "gesperrt" angezeigt.
final decryptedCatalogSourceDataProvider = FutureProvider<CatalogSourceData>((
  ref,
) async {
  final baseData = await ref.watch(baseCatalogSourceDataProvider.future);
  final password =
      ref.watch(appSettingsProvider).valueOrNull?.catalogContentPassword;
  if (password == null || password.isEmpty) {
    return baseData;
  }
  return decryptAllCatalogValues(
    encrypted: baseData,
    password: password,
    globalSaltV3: baseData.catalogSaltV3,
  );
});

/// Zusammengefuehrte Hausregel-Pakete aus Assets und Heldenspeicher.
final houseRulePackCatalogProvider = FutureProvider<HouseRulePackCatalog>((
  ref,
) async {
  final baseData = await ref.watch(baseCatalogSourceDataProvider.future);
  final loader = ref.watch(catalogLoaderProvider);
  final repository = ref.watch(houseRulePackRepositoryProvider);
  final builtIn = await loader.loadBuiltInHouseRulePacks(
    catalogVersion: baseData.version,
  );
  final imported = await repository.load(catalogVersion: baseData.version);
  return HouseRulePackCatalog.merge(builtIn: builtIn, imported: imported);
});

/// Feld-Provenienz fuer Hausregel-Overrides im wirksamen Katalog.
final catalogRuleResolverProvider = FutureProvider<CatalogRuleResolver>((
  ref,
) async {
  final runtimeData = await ref.watch(catalogRuntimeDataProvider.future);
  return CatalogRuleResolver(
    provenanceIndex: runtimeData.houseRuleProvenanceIndex,
  );
});

/// Aufgeloeste Laufzeitdaten aus Basis-Assets und konfliktfreien Customs.
final catalogRuntimeDataProvider = FutureProvider<CatalogRuntimeData>((
  ref,
) async {
  final baseData = await ref.watch(decryptedCatalogSourceDataProvider.future);
  final packCatalog = await ref.watch(houseRulePackCatalogProvider.future);
  final repository = ref.watch(customCatalogRepositoryProvider);
  final customSnapshot = await repository.load(
    catalogVersion: baseData.version,
  );
  final disabledPackIds =
      ref.watch(appSettingsProvider).valueOrNull?.disabledHouseRulePackIds ??
      const <String>{};
  final activePackIds = packCatalog.resolveActivePackIds(disabledPackIds);
  final houseRuleResult = HouseRuleCatalogResolver.resolve(
    baseData: baseData,
    packCatalog: packCatalog,
    activePackIds: activePackIds,
  );
  return CatalogRuntimeData.resolve(
    baseData: baseData,
    resolvedBaseData: houseRuleResult.resolvedBaseData,
    customSnapshot: customSnapshot,
    packCatalog: packCatalog,
    activeHouseRulePackIds: activePackIds,
    houseRuleProvenanceIndex: houseRuleResult.provenanceIndex,
    houseRuleIssues: houseRuleResult.issues,
  );
});

/// Effektiver, fuer die App genutzter Regelkatalog.
final rulesCatalogProvider = FutureProvider<RulesCatalog>((ref) async {
  final runtimeData = await ref.watch(catalogRuntimeDataProvider.future);
  final loader = ref.watch(catalogLoaderProvider);
  return loader.buildCatalogFromSourceData(
    runtimeData.effectiveData,
    ruleResolver: CatalogRuleResolver(
      provenanceIndex: runtimeData.houseRuleProvenanceIndex,
    ),
  );
});

/// Alle bekannten Hausregel-Probleme aus Paketquellen und Resolver.
final houseRuleIssueSnapshotProvider = FutureProvider<List<HouseRulePackIssue>>(
  (ref) async {
    final packCatalog = await ref.watch(houseRulePackCatalogProvider.future);
    final runtimeData = await ref.watch(catalogRuntimeDataProvider.future);
    return List<HouseRulePackIssue>.unmodifiable(<HouseRulePackIssue>[
      ...packCatalog.issues,
      ...runtimeData.houseRuleIssues,
    ]);
  },
);

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
