import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_catalog_resolver.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack_admin.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_file_gateway.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

/// Plattformabhaengiger Dateigateway fuer Hausregel-Paketdateien.
final houseRulePackFileGatewayProvider = Provider<HouseRulePackFileGateway>((
  ref,
) {
  return createHouseRulePackFileGateway();
});

/// UI-tauglicher Snapshot fuer die Hausregel-Paketverwaltung.
final houseRulePackAdminSnapshotProvider =
    FutureProvider<HouseRulePackAdminSnapshot>((ref) async {
      final runtimeData = await ref.watch(catalogRuntimeDataProvider.future);
      return HouseRulePackAdminSnapshot.fromRuntimeData(runtimeData);
    });

/// Schreib-, Validierungs- und Export-Aktionen fuer Hausregel-Pakete.
class HouseRulePackAdminActions {
  /// Erstellt die Aktionsklasse fuer die Hausregelverwaltung.
  HouseRulePackAdminActions(this._ref);

  final Ref _ref;

  /// Parst ein Manifest aus einem JSON-String und validiert seine Struktur.
  HouseRulePackManifest parseManifestJson(String rawJson) {
    final normalizedJson = rawJson.trim();
    if (normalizedJson.isEmpty) {
      throw const FormatException('Das Hausregel-JSON darf nicht leer sein.');
    }
    final decoded = jsonDecode(normalizedJson);
    if (decoded is! Map) {
      throw const FormatException(
        'Der Hausregel-Import erwartet ein JSON-Objekt.',
      );
    }
    return HouseRulePackManifest.fromJson(decoded.cast<String, dynamic>());
  }

  /// Validiert einen Pack-Entwurf gegen den aktuellen Basiskatalog.
  Future<List<HouseRulePackIssue>> validateManifest({
    required Map<String, dynamic> manifestJson,
    String previousPackId = '',
  }) async {
    final runtimeData = await _ref.read(catalogRuntimeDataProvider.future);
    final draftManifest = HouseRulePackManifest.fromJson(
      manifestJson,
      isBuiltIn: false,
    );
    final normalizedPreviousPackId = previousPackId.trim();
    final retainedPacks = runtimeData.packCatalog.packs
        .where((existingPack) {
          final existingId = existingPack.id;
          if (normalizedPreviousPackId.isNotEmpty &&
              existingId == normalizedPreviousPackId) {
            return false;
          }
          return existingId != draftManifest.id;
        })
        .toList(growable: false);

    final builtInPacks = retainedPacks
        .where((pack) => pack.isBuiltIn)
        .toList(growable: false);
    final importedPacks =
        retainedPacks.where((pack) => !pack.isBuiltIn).toList(growable: true)
          ..add(draftManifest);

    final draftCatalog = HouseRulePackCatalog.merge(
      builtIn: HouseRulePackSourceSnapshot(packs: builtInPacks),
      imported: HouseRulePackSourceSnapshot(packs: importedPacks),
    );
    final activePackIds = Set<String>.of(runtimeData.activeHouseRulePackIds)
      ..add(draftManifest.id);
    _addParentChainToActiveSet(
      packCatalog: draftCatalog,
      packId: draftManifest.id,
      activePackIds: activePackIds,
    );

    final resolution = HouseRuleCatalogResolver.resolve(
      baseData: runtimeData.baseData,
      packCatalog: draftCatalog,
      activePackIds: Set<String>.unmodifiable(activePackIds),
    );

    return List<HouseRulePackIssue>.unmodifiable(
      <HouseRulePackIssue>[...draftCatalog.issues, ...resolution.issues].where((
        issue,
      ) {
        final issuePackId = issue.packId.trim();
        return issuePackId.isEmpty || issuePackId == draftManifest.id;
      }),
    );
  }

  /// Speichert ein importiertes Hausregel-Paket und laedt den Katalog neu.
  Future<void> savePack({
    required Map<String, dynamic> manifestJson,
    String previousPackId = '',
  }) async {
    final snapshot = await _ref.read(houseRulePackAdminSnapshotProvider.future);
    final normalizedPreviousPackId = previousPackId.trim();
    final manifest = HouseRulePackManifest.fromJson(
      manifestJson,
      isBuiltIn: false,
    );
    final nextId = manifest.id;

    final builtInConflict = snapshot.builtInPacks.any(
      (entry) => entry.id == nextId,
    );
    if (builtInConflict && normalizedPreviousPackId != nextId) {
      throw FormatException(
        'Die ID "$nextId" ist bereits durch ein eingebautes Paket belegt.',
      );
    }

    final importedConflict = snapshot.importedPacks.any(
      (entry) => entry.id == nextId && entry.id != normalizedPreviousPackId,
    );
    if (importedConflict) {
      throw FormatException(
        'Die ID "$nextId" existiert bereits als importiertes Hausregel-Paket.',
      );
    }

    final repository = _ref.read(houseRulePackRepositoryProvider);
    await repository.saveManifest(
      catalogVersion: snapshot.catalogVersion,
      manifestJson: manifest.toJson(),
      previousPackId: normalizedPreviousPackId,
    );
    _reloadCatalog();
  }

  /// Entfernt ein importiertes Hausregel-Paket und laedt den Katalog neu.
  Future<void> deletePack(String packId) async {
    final snapshot = await _ref.read(houseRulePackAdminSnapshotProvider.future);
    final repository = _ref.read(houseRulePackRepositoryProvider);
    await repository.deletePack(
      catalogVersion: snapshot.catalogVersion,
      packId: packId.trim(),
    );
    _reloadCatalog();
  }

  /// Exportiert ein importiertes Paket als kanonisch formatiertes JSON.
  Future<String> exportPackJson(String packId) async {
    final snapshot = await _ref.read(houseRulePackAdminSnapshotProvider.future);
    final entry = snapshot.importedPacks.where(
      (pack) => pack.id == packId.trim(),
    );
    if (entry.isEmpty) {
      throw FormatException(
        'Das Hausregel-Paket "$packId" ist nicht als importiertes Paket vorhanden.',
      );
    }
    final encoder = const JsonEncoder.withIndent('  ');
    return '${encoder.convert(entry.first.manifest.toJson())}\n';
  }

  /// Schlaegt eine neue freie Paket-ID fuer Kopien oder Klone vor.
  Future<String> suggestCopyPackId(String basePackId) async {
    final snapshot = await _ref.read(houseRulePackAdminSnapshotProvider.future);
    final normalizedBaseId = basePackId.trim().isEmpty
        ? 'hausregelpaket'
        : basePackId.trim();
    final knownIds = snapshot.allPacks.map((entry) => entry.id).toSet();
    final baseCandidate = '${normalizedBaseId}_copy';
    if (!knownIds.contains(baseCandidate)) {
      return baseCandidate;
    }

    var suffix = 2;
    while (true) {
      final candidate = '${normalizedBaseId}_copy_$suffix';
      if (!knownIds.contains(candidate)) {
        return candidate;
      }
      suffix++;
    }
  }

  void _reloadCatalog() {
    _ref.read(catalogReloadRevisionProvider.notifier).state++;
  }

  void _addParentChainToActiveSet({
    required HouseRulePackCatalog packCatalog,
    required String packId,
    required Set<String> activePackIds,
  }) {
    var currentPack = packCatalog.find(packId);
    while (currentPack != null) {
      final parentPackId = currentPack.parentPackId.trim();
      if (parentPackId.isEmpty || !activePackIds.add(parentPackId)) {
        return;
      }
      currentPack = packCatalog.find(parentPackId);
    }
  }
}

/// Provider fuer Verwaltungsaktionen rund um Hausregel-Pakete.
final houseRulePackAdminActionsProvider = Provider<HouseRulePackAdminActions>((
  ref,
) {
  return HouseRulePackAdminActions(ref);
});
