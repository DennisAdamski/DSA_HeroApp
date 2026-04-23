import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_provenance.dart';

/// Ergebnis des Hausregel-Resolvers vor dem Merge mit Custom-Katalogen.
class HouseRuleCatalogResolverResult {
  /// Erstellt das Resolver-Ergebnis fuer den wirksamen Basiskatalog.
  const HouseRuleCatalogResolverResult({
    required this.resolvedBaseData,
    required this.provenanceIndex,
    required this.issues,
  });

  /// Basisdaten nach Anwendung aller aktiven Hausregel-Pakete.
  final CatalogSourceData resolvedBaseData;

  /// Feld-Provenienz fuer UIs und Regellogik.
  final HouseRuleProvenanceIndex provenanceIndex;

  /// Alle beim Aufloesen entdeckten Probleme.
  final List<HouseRulePackIssue> issues;
}

/// Wendet aktive Hausregel-Pakete auf rohe Katalogdaten an.
class HouseRuleCatalogResolver {
  /// Erstellt einen Resolver fuer Hausregel-Patches.
  const HouseRuleCatalogResolver._();

  /// Baut den wirksamen Basiskatalog aus offiziellen Daten und aktiven Packs.
  static HouseRuleCatalogResolverResult resolve({
    required CatalogSourceData baseData,
    required HouseRulePackCatalog packCatalog,
    required Set<String> activePackIds,
  }) {
    final issues = <HouseRulePackIssue>[];
    final resolvedSections = <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final section in editableCatalogSections)
        section: baseData
            .entriesFor(section)
            .map(_deepCloneEntry)
            .where(
              (entry) => !_isEntryGatedByInactivePack(
                entry: entry,
                packCatalog: packCatalog,
                activePackIds: activePackIds,
              ),
            )
            .toList(growable: true),
    };
    final appliedFields = <String, _AppliedFieldChange>{};

    final activePacks =
        packCatalog.packs
            .where((pack) => activePackIds.contains(pack.id))
            .toList(growable: false)
          ..sort((a, b) {
            final priorityCompare = a.priority.compareTo(b.priority);
            return priorityCompare;
          });

    for (final pack in activePacks) {
      for (final patch in pack.patches) {
        final sectionEntries = resolvedSections[patch.section]!;
        final selector = patch.selector;
        final patchPriority = patch.effectivePriority(pack.priority);

        if (patch.setFields.isNotEmpty) {
          final matches = _selectEntries(
            entries: sectionEntries,
            section: patch.section,
            selector: selector!,
          );
          if (matches.isEmpty) {
            issues.add(
              HouseRulePackIssue(
                packId: pack.id,
                packTitle: pack.title,
                filePath: pack.filePath,
                section: patch.section,
                message:
                    'Patch mit setFields trifft keine Eintraege und bleibt wirkungslos.',
              ),
            );
          }
          for (final entry in matches) {
            final entryId = (entry['id'] as String? ?? '').trim();
            for (final field in patch.setFields.entries) {
              final fieldPath = field.key.trim();
              if (fieldPath.isEmpty) {
                continue;
              }
              if (fieldPath == 'id') {
                issues.add(
                  HouseRulePackIssue(
                    packId: pack.id,
                    packTitle: pack.title,
                    filePath: pack.filePath,
                    section: patch.section,
                    entryId: entryId,
                    fieldPath: fieldPath,
                    message:
                        'Die stabile Eintrags-ID darf von Hausregeln nicht geaendert werden.',
                  ),
                );
                continue;
              }

              final key = HouseRuleProvenanceIndex.fieldKey(
                section: patch.section,
                entryId: entryId,
                fieldPath: fieldPath,
              );
              final existing = appliedFields[key];
              if (existing != null) {
                if (patchPriority < existing.priority) {
                  continue;
                }
                if (patchPriority == existing.priority &&
                    existing.packId != pack.id) {
                  issues.add(
                    HouseRulePackIssue(
                      packId: pack.id,
                      packTitle: pack.title,
                      filePath: pack.filePath,
                      section: patch.section,
                      entryId: entryId,
                      fieldPath: fieldPath,
                      message:
                          'Feldkonflikt mit gleich hoher Prioritaet; die spaetere Aenderung wird ignoriert.',
                    ),
                  );
                  continue;
                }
              }

              final baseValue =
                  existing?.baseValue ??
                  readHouseRuleFieldValue(entry, fieldPath);
              writeHouseRuleFieldValue(
                entry: entry,
                fieldPath: fieldPath,
                value: _deepCloneValue(field.value),
              );
              appliedFields[key] = _AppliedFieldChange(
                priority: patchPriority,
                packId: pack.id,
                packTitle: pack.title,
                baseValue: baseValue,
                effectiveValue: readHouseRuleFieldValue(entry, fieldPath),
                section: patch.section,
                entryId: entryId,
                fieldPath: fieldPath,
              );
            }
          }
        }

        if (patch.deactivateEntries) {
          final removedIds = <String>[];
          sectionEntries.removeWhere((entry) {
            final matches = selector!.matches(
              section: patch.section,
              entry: entry,
            );
            if (matches) {
              removedIds.add((entry['id'] as String? ?? '').trim());
            }
            return matches;
          });
          if (removedIds.isEmpty) {
            issues.add(
              HouseRulePackIssue(
                packId: pack.id,
                packTitle: pack.title,
                filePath: pack.filePath,
                section: patch.section,
                message:
                    'Patch mit deactivateEntries trifft keine Eintraege und bleibt wirkungslos.',
              ),
            );
          }
        }

        if (patch.addEntries.isNotEmpty) {
          for (final rawEntry in patch.addEntries) {
            try {
              final canonical = canonicalizeCatalogEntry(
                patch.section,
                _deepCloneEntry(rawEntry),
              );
              validateCatalogEntryStructure(patch.section, canonical);
              final entryId = (canonical['id'] as String? ?? '').trim();
              final exists = sectionEntries.any(
                (entry) => (entry['id'] as String? ?? '').trim() == entryId,
              );
              if (exists) {
                issues.add(
                  HouseRulePackIssue(
                    packId: pack.id,
                    packTitle: pack.title,
                    filePath: pack.filePath,
                    section: patch.section,
                    entryId: entryId,
                    message:
                        'addEntries kollidiert mit einer bestehenden ID und wird ignoriert.',
                  ),
                );
                continue;
              }
              sectionEntries.add(canonical);
            } on FormatException catch (error) {
              issues.add(
                HouseRulePackIssue(
                  packId: pack.id,
                  packTitle: pack.title,
                  filePath: pack.filePath,
                  section: patch.section,
                  message: error.message,
                ),
              );
            }
          }
        }
      }
    }

    final provenanceEntries = <String, HouseRuleFieldProvenance>{
      for (final entry in appliedFields.entries)
        entry.key: HouseRuleFieldProvenance(
          section: entry.value.section,
          entryId: entry.value.entryId,
          fieldPath: entry.value.fieldPath,
          baseValue: entry.value.baseValue,
          effectiveValue: entry.value.effectiveValue,
          packId: entry.value.packId,
          packTitle: entry.value.packTitle,
        ),
    };

    return HouseRuleCatalogResolverResult(
      resolvedBaseData: CatalogSourceData(
        version: baseData.version,
        source: baseData.source,
        metadata: baseData.metadata,
        sections: resolvedSections.map(
          (section, entries) => MapEntry(
            section,
            List<Map<String, dynamic>>.unmodifiable(entries),
          ),
        ),
        reisebericht: baseData.reisebericht
            .map(_deepCloneEntry)
            .toList(growable: false),
      ),
      provenanceIndex: HouseRuleProvenanceIndex(entries: provenanceEntries),
      issues: List<HouseRulePackIssue>.unmodifiable(issues),
    );
  }
}

class _AppliedFieldChange {
  const _AppliedFieldChange({
    required this.priority,
    required this.packId,
    required this.packTitle,
    required this.baseValue,
    required this.effectiveValue,
    required this.section,
    required this.entryId,
    required this.fieldPath,
  });

  final int priority;
  final String packId;
  final String packTitle;
  final Object? baseValue;
  final Object? effectiveValue;
  final CatalogSectionId section;
  final String entryId;
  final String fieldPath;
}

List<Map<String, dynamic>> _selectEntries({
  required List<Map<String, dynamic>> entries,
  required CatalogSectionId section,
  required HouseRuleSelector selector,
}) {
  return entries
      .where((entry) => selector.matches(section: section, entry: entry))
      .toList(growable: false);
}

bool _isEntryGatedByInactivePack({
  required Map<String, dynamic> entry,
  required HouseRulePackCatalog packCatalog,
  required Set<String> activePackIds,
}) {
  final sourceKey = _readEntrySourceKey(entry);
  if (sourceKey.isEmpty || !packCatalog.contains(sourceKey)) {
    return false;
  }
  return !activePackIds.contains(sourceKey);
}

String _readEntrySourceKey(Map<String, dynamic> entry) {
  final ruleMeta = entry['ruleMeta'];
  if (ruleMeta is Map<String, dynamic>) {
    return (ruleMeta['sourceKey'] as String? ?? '').trim();
  }
  if (ruleMeta is Map) {
    return (ruleMeta['sourceKey'] as String? ?? '').trim();
  }
  return '';
}

Map<String, dynamic> _deepCloneEntry(Map<String, dynamic> entry) {
  return entry.map<String, dynamic>(
    (key, value) => MapEntry(key, _deepCloneValue(value)),
  );
}

dynamic _deepCloneValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value.map<String, dynamic>(
      (key, nestedValue) => MapEntry(key, _deepCloneValue(nestedValue)),
    );
  }
  if (value is Map) {
    return value.cast<String, dynamic>().map<String, dynamic>(
      (key, nestedValue) => MapEntry(key, _deepCloneValue(nestedValue)),
    );
  }
  if (value is List) {
    return value.map(_deepCloneValue).toList(growable: true);
  }
  return value;
}

/// Schreibt einen verschachtelten Feldwert in einen rohen Katalogeintrag.
void writeHouseRuleFieldValue({
  required Map<String, dynamic> entry,
  required String fieldPath,
  required Object? value,
}) {
  final segments = fieldPath
      .split('.')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return;
  }

  Map<String, dynamic> current = entry;
  for (var index = 0; index < segments.length - 1; index++) {
    final segment = segments[index];
    final nested = current[segment];
    if (nested is Map<String, dynamic>) {
      current = nested;
      continue;
    }
    if (nested is Map) {
      final casted = nested.cast<String, dynamic>();
      current[segment] = casted;
      current = casted;
      continue;
    }
    final created = <String, dynamic>{};
    current[segment] = created;
    current = created;
  }
  current[segments.last] = value;
}
