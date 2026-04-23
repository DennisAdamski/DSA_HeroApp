import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_provenance.dart';

/// Beschreibt ein Problem in einer benutzerdefinierten Katalogdatei.
class CatalogIssue {
  /// Erstellt einen strukturierten Kataloghinweis.
  const CatalogIssue({
    required this.section,
    required this.message,
    this.entryId = '',
    this.filePath = '',
  });

  /// Betroffene Katalogsektion.
  final CatalogSectionId section;

  /// Menschlich lesbare Fehlermeldung.
  final String message;

  /// Optional betroffene Eintrags-ID.
  final String entryId;

  /// Optional absoluter Dateipfad.
  final String filePath;
}

/// Rohdaten des Split-Katalogs vor der Typisierung in [RulesCatalog].
class CatalogSourceData {
  /// Erstellt einen unveraenderlichen Satz von Katalog-Rohdaten.
  const CatalogSourceData({
    required this.version,
    required this.source,
    required this.metadata,
    required this.sections,
    required this.reisebericht,
  });

  /// Version des geladenen Katalogs.
  final String version;

  /// Ursprungsangabe aus dem Manifest.
  final String source;

  /// Sonstige Manifest-Metadaten.
  final Map<String, dynamic> metadata;

  /// Rohdaten der bearbeitbaren Split-Sektionen.
  final Map<CatalogSectionId, List<Map<String, dynamic>>> sections;

  /// Reisebericht-Rohdaten, bewusst ausserhalb der Settings-Verwaltung.
  final List<Map<String, dynamic>> reisebericht;

  /// Liefert die Eintraege einer Katalogsektion.
  List<Map<String, dynamic>> entriesFor(CatalogSectionId section) {
    return sections[section] ?? const <Map<String, dynamic>>[];
  }
}

/// Gueltiger benutzerdefinierter Katalogeintrag aus dem Heldenspeicher.
class CustomCatalogEntryRecord {
  /// Erstellt einen geladenen Custom-Eintrag.
  const CustomCatalogEntryRecord({
    required this.section,
    required this.id,
    required this.filePath,
    required this.data,
  });

  /// Katalogsektion des Eintrags.
  final CatalogSectionId section;

  /// Stabile ID des Eintrags.
  final String id;

  /// Absoluter Dateipfad der Quelldatei.
  final String filePath;

  /// Validierte, kanonisierte JSON-Daten.
  final Map<String, dynamic> data;
}

/// Ergebnis des Dateiscans fuer Custom-Katalogdateien.
class CustomCatalogSnapshot {
  /// Erstellt einen Snapshot aller geladenen Eintraege und Probleme.
  const CustomCatalogSnapshot({
    this.entries = const <CustomCatalogEntryRecord>[],
    this.issues = const <CatalogIssue>[],
  });

  /// Erfolgreich geladene Eintraege.
  final List<CustomCatalogEntryRecord> entries;

  /// Probleme, die beim Scan oder Validieren entdeckt wurden.
  final List<CatalogIssue> issues;

  /// Liefert alle geladenen Custom-Eintraege einer Sektion.
  List<CustomCatalogEntryRecord> entriesFor(CatalogSectionId section) {
    return entries
        .where((entry) => entry.section == section)
        .toList(growable: false);
  }
}

/// Beschreibt den wirksamen Laufzeitkatalog aus Basis + Custom-Dateien.
class CatalogRuntimeData {
  /// Erstellt die aufgeloesten Laufzeitdaten.
  const CatalogRuntimeData({
    required this.baseData,
    required this.resolvedBaseData,
    required this.customSnapshot,
    required this.effectiveData,
    required this.issues,
    required this.packCatalog,
    required this.activeHouseRulePackIds,
    required this.houseRuleProvenanceIndex,
    required this.houseRuleIssues,
  });

  /// Unveraenderte Basisdaten aus den Assets.
  final CatalogSourceData baseData;

  /// Basisdaten nach Anwendung aktiver Hausregel-Pakete.
  final CatalogSourceData resolvedBaseData;

  /// Snapshot aller geladenen benutzerdefinierten Dateien.
  final CustomCatalogSnapshot customSnapshot;

  /// Effektiv fuer die App verwendete Daten (Basis + konfliktfreie Customs).
  final CatalogSourceData effectiveData;

  /// Alle bekannten Probleme inklusive Konflikten gegen Basisdaten.
  final List<CatalogIssue> issues;

  /// Alle bekannten Hausregel-Pakete.
  final HouseRulePackCatalog packCatalog;

  /// Wirksame Paket-IDs fuer diesen Laufzeitkatalog.
  final Set<String> activeHouseRulePackIds;

  /// Feld-Provenienz aus Hausregel-Patches.
  final HouseRuleProvenanceIndex houseRuleProvenanceIndex;

  /// Probleme aus dem Hausregel-Resolver.
  final List<HouseRulePackIssue> houseRuleIssues;

  /// Baut die effektiven Laufzeitdaten aus Basisdaten und Custom-Dateien.
  factory CatalogRuntimeData.resolve({
    required CatalogSourceData baseData,
    CatalogSourceData? resolvedBaseData,
    required CustomCatalogSnapshot customSnapshot,
    HouseRulePackCatalog packCatalog = const HouseRulePackCatalog(),
    Set<String> activeHouseRulePackIds = const <String>{},
    HouseRuleProvenanceIndex houseRuleProvenanceIndex =
        const HouseRuleProvenanceIndex(),
    List<HouseRulePackIssue> houseRuleIssues = const <HouseRulePackIssue>[],
  }) {
    final effectiveBaseData = resolvedBaseData ?? baseData;
    final issues = <CatalogIssue>[...customSnapshot.issues];
    final effectiveSections = <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final section in editableCatalogSections)
        section: List<Map<String, dynamic>>.from(
          effectiveBaseData.entriesFor(section),
        ),
    };

    final baseIds = <CatalogSectionId, Set<String>>{
      for (final section in editableCatalogSections)
        section: effectiveBaseData
            .entriesFor(section)
            .map((entry) => (entry['id'] as String? ?? '').trim())
            .where((id) => id.isNotEmpty)
            .toSet(),
    };

    for (final entry in customSnapshot.entries) {
      if (baseIds[entry.section]!.contains(entry.id)) {
        issues.add(
          CatalogIssue(
            section: entry.section,
            entryId: entry.id,
            filePath: entry.filePath,
            message:
                'Custom-ID kollidiert mit einem Basis-Eintrag und wird ignoriert.',
          ),
        );
        continue;
      }
      effectiveSections[entry.section]!.add(entry.data);
    }

    return CatalogRuntimeData(
      baseData: baseData,
      resolvedBaseData: effectiveBaseData,
      customSnapshot: customSnapshot,
      effectiveData: CatalogSourceData(
        version: baseData.version,
        source: baseData.source,
        metadata: baseData.metadata,
        sections: effectiveSections,
        reisebericht: baseData.reisebericht,
      ),
      issues: List<CatalogIssue>.unmodifiable(issues),
      packCatalog: packCatalog,
      activeHouseRulePackIds: Set<String>.unmodifiable(activeHouseRulePackIds),
      houseRuleProvenanceIndex: houseRuleProvenanceIndex,
      houseRuleIssues: List<HouseRulePackIssue>.unmodifiable(houseRuleIssues),
    );
  }
}

/// Zusammengefasster Eintrag fuer die Katalogverwaltungs-UI.
class CatalogAdminEntry {
  /// Erstellt einen UI-tauglichen Eintrag.
  const CatalogAdminEntry({
    required this.section,
    required this.id,
    required this.name,
    required this.data,
    required this.isCustom,
    this.filePath = '',
  });

  /// Zugehoerige Katalogsektion.
  final CatalogSectionId section;

  /// Stabile ID des Eintrags.
  final String id;

  /// Anzeigename des Eintrags.
  final String name;

  /// Rohdaten fuer Detailanzeige und Bearbeitung.
  final Map<String, dynamic> data;

  /// Ob der Eintrag aus dem Heldenspeicher stammt.
  final bool isCustom;

  /// Optionaler Dateipfad fuer Custom-Eintraege.
  final String filePath;
}

/// Verwalteter Zustand einer einzelnen Katalogsektion.
class CatalogSectionAdminSnapshot {
  /// Erstellt den Snapshot einer einzelnen UI-Sektion.
  const CatalogSectionAdminSnapshot({
    required this.section,
    required this.baseEntries,
    required this.customEntries,
    required this.issues,
  });

  /// Zugehoerige Sektion.
  final CatalogSectionId section;

  /// Read-only Basis-Eintraege aus den Assets.
  final List<CatalogAdminEntry> baseEntries;

  /// Gueltige, bearbeitbare Custom-Eintraege aus dem Heldenspeicher.
  final List<CatalogAdminEntry> customEntries;

  /// Probleme dieser Sektion.
  final List<CatalogIssue> issues;

  /// Gesamtzahl aller sichtbaren Eintraege.
  int get totalCount => baseEntries.length + customEntries.length;
}

/// Gesamter Verwaltungs-Snapshot fuer alle bearbeitbaren Sektionen.
class CatalogAdminSnapshot {
  /// Erstellt die UI-Sicht auf den effektiven Katalog.
  const CatalogAdminSnapshot({
    required this.catalogVersion,
    required this.sections,
    required this.issues,
  });

  /// Katalogversion des geladenen Basis-Manifests.
  final String catalogVersion;

  /// Snapshots aller bearbeitbaren Sektionen.
  final Map<CatalogSectionId, CatalogSectionAdminSnapshot> sections;

  /// Alle bekannten Probleme ueber alle Sektionen hinweg.
  final List<CatalogIssue> issues;

  /// Liefert den Snapshot einer Katalogsektion.
  CatalogSectionAdminSnapshot section(CatalogSectionId section) {
    return sections[section]!;
  }

  /// Baut den Verwaltungs-Snapshot aus den effektiven Laufzeitdaten.
  factory CatalogAdminSnapshot.fromRuntimeData(CatalogRuntimeData runtimeData) {
    final customByKey = <String, CustomCatalogEntryRecord>{
      for (final entry in runtimeData.customSnapshot.entries)
        '${entry.section.name}::${entry.id}': entry,
    };
    final baseIds = <CatalogSectionId, Set<String>>{
      for (final section in editableCatalogSections)
        section: runtimeData.resolvedBaseData
            .entriesFor(section)
            .map((entry) => (entry['id'] as String? ?? '').trim())
            .where((id) => id.isNotEmpty)
            .toSet(),
    };

    final sections = <CatalogSectionId, CatalogSectionAdminSnapshot>{};
    for (final section in editableCatalogSections) {
      final baseEntries =
          runtimeData.resolvedBaseData
              .entriesFor(section)
              .map(
                (entry) => CatalogAdminEntry(
                  section: section,
                  id: (entry['id'] as String? ?? '').trim(),
                  name: catalogEntryDisplayName(entry),
                  data: entry,
                  isCustom: false,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

      final customEntries =
          runtimeData.effectiveData
              .entriesFor(section)
              .where((entry) {
                final id = (entry['id'] as String? ?? '').trim();
                return id.isNotEmpty && !baseIds[section]!.contains(id);
              })
              .map((entry) {
                final id = (entry['id'] as String? ?? '').trim();
                final sourceEntry = customByKey['${section.name}::$id'];
                return CatalogAdminEntry(
                  section: section,
                  id: id,
                  name: catalogEntryDisplayName(entry),
                  data: entry,
                  isCustom: true,
                  filePath: sourceEntry?.filePath ?? '',
                );
              })
              .toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

      final issues = runtimeData.issues
          .where((issue) => issue.section == section)
          .toList(growable: false);
      sections[section] = CatalogSectionAdminSnapshot(
        section: section,
        baseEntries: baseEntries,
        customEntries: customEntries,
        issues: issues,
      );
    }

    return CatalogAdminSnapshot(
      catalogVersion: runtimeData.baseData.version,
      sections: sections,
      issues: runtimeData.issues,
    );
  }
}
