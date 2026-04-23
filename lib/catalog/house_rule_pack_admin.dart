import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';

/// UI-tauglicher Eintrag fuer ein bekanntes Hausregel-Paket.
class HouseRulePackAdminEntry {
  /// Erstellt einen Verwaltungsdatensatz fuer ein Hausregel-Paket.
  const HouseRulePackAdminEntry({
    required this.manifest,
    required this.isBuiltIn,
    required this.isActive,
    required this.issues,
  });

  /// Vollstaendiges Manifest des Pakets.
  final HouseRulePackManifest manifest;

  /// Ob das Paket aus den App-Assets stammt.
  final bool isBuiltIn;

  /// Ob das Paket aktuell wirksam ist.
  final bool isActive;

  /// Paketbezogene Warnungen oder Fehler.
  final List<HouseRulePackIssue> issues;

  /// Stabile Paket-ID.
  String get id => manifest.id;

  /// Anzeigename des Pakets.
  String get title => manifest.title;

  /// Kurzbeschreibung des Pakets.
  String get description => manifest.description;

  /// Parent-ID oder leer.
  String get parentPackId => manifest.parentPackId;

  /// Herkunftspfad fuer importierte Pakete.
  String get filePath => manifest.filePath;
}

/// Verwaltungs-Snapshot fuer eingebaute und importierte Hausregel-Pakete.
class HouseRulePackAdminSnapshot {
  /// Erstellt den Verwaltungs-Snapshot fuer Hausregel-Pakete.
  const HouseRulePackAdminSnapshot({
    required this.catalogVersion,
    required this.builtInPacks,
    required this.importedPacks,
    required this.issues,
  });

  /// Katalogversion des aktuell geladenen Basiskatalogs.
  final String catalogVersion;

  /// Eingebaute, schreibgeschuetzte Pakete.
  final List<HouseRulePackAdminEntry> builtInPacks;

  /// Importierte, bearbeitbare Pakete.
  final List<HouseRulePackAdminEntry> importedPacks;

  /// Alle bekannten globalen und paketbezogenen Probleme.
  final List<HouseRulePackIssue> issues;

  /// Alle sichtbaren Pakete in einer Liste.
  List<HouseRulePackAdminEntry> get allPacks => <HouseRulePackAdminEntry>[
    ...builtInPacks,
    ...importedPacks,
  ];

  /// Sucht ein Paket im Verwaltungs-Snapshot per ID.
  HouseRulePackAdminEntry? find(String packId) {
    final normalizedPackId = packId.trim();
    for (final entry in allPacks) {
      if (entry.id == normalizedPackId) {
        return entry;
      }
    }
    return null;
  }

  /// Baut den Verwaltungs-Snapshot aus den aktuellen Laufzeitdaten.
  factory HouseRulePackAdminSnapshot.fromRuntimeData(
    CatalogRuntimeData runtimeData,
  ) {
    final issuesByPackId = <String, List<HouseRulePackIssue>>{};
    for (final issue in <HouseRulePackIssue>[
      ...runtimeData.packCatalog.issues,
      ...runtimeData.houseRuleIssues,
    ]) {
      final packId = issue.packId.trim();
      if (packId.isEmpty) {
        continue;
      }
      issuesByPackId
          .putIfAbsent(packId, () => <HouseRulePackIssue>[])
          .add(issue);
    }

    HouseRulePackAdminEntry buildEntry(HouseRulePackManifest manifest) {
      final packIssues =
          issuesByPackId[manifest.id] ?? const <HouseRulePackIssue>[];
      return HouseRulePackAdminEntry(
        manifest: manifest,
        isBuiltIn: manifest.isBuiltIn,
        isActive: runtimeData.activeHouseRulePackIds.contains(manifest.id),
        issues: List<HouseRulePackIssue>.unmodifiable(packIssues),
      );
    }

    final builtInPacks =
        runtimeData.packCatalog.packs
            .where((manifest) => manifest.isBuiltIn)
            .map(buildEntry)
            .toList(growable: false)
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );

    final importedPacks =
        runtimeData.packCatalog.packs
            .where((manifest) => !manifest.isBuiltIn)
            .map(buildEntry)
            .toList(growable: false)
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );

    return HouseRulePackAdminSnapshot(
      catalogVersion: runtimeData.baseData.version,
      builtInPacks: List<HouseRulePackAdminEntry>.unmodifiable(builtInPacks),
      importedPacks: List<HouseRulePackAdminEntry>.unmodifiable(importedPacks),
      issues: List<HouseRulePackIssue>.unmodifiable(<HouseRulePackIssue>[
        ...runtimeData.packCatalog.issues,
        ...runtimeData.houseRuleIssues,
      ]),
    );
  }
}
