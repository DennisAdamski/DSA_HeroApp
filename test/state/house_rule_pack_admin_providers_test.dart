import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rule_pack_admin_providers.dart';

void main() {
  test('savePack rejects collisions with built-in pack ids', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'house_rule_pack_admin_collision_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
    final container = ProviderContainer(
      overrides: [
        houseRulePackRepositoryProvider.overrideWithValue(repository),
        catalogRuntimeDataProvider.overrideWith(
          (ref) async => _buildRuntimeData(
            packCatalog: const HouseRulePackCatalog(
              packs: <HouseRulePackManifest>[
                HouseRulePackManifest(
                  id: 'built_in_pack',
                  title: 'Built-In',
                  description: 'Protected id',
                  patches: <HouseRulePatch>[],
                  isBuiltIn: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final actions = container.read(houseRulePackAdminActionsProvider);

    await expectLater(
      actions.savePack(
        manifestJson: const <String, dynamic>{
          'id': 'built_in_pack',
          'title': 'Imported',
          'description': 'Should fail',
          'patches': <Map<String, dynamic>>[],
        },
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('exportPackJson returns formatted json for imported packs', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'house_rule_pack_admin_export_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
    final container = ProviderContainer(
      overrides: [
        houseRulePackRepositoryProvider.overrideWithValue(repository),
        catalogRuntimeDataProvider.overrideWith(
          (ref) async => _buildRuntimeData(
            packCatalog: const HouseRulePackCatalog(
              packs: <HouseRulePackManifest>[
                HouseRulePackManifest(
                  id: 'imported_pack',
                  title: 'Imported Pack',
                  description: 'Exportable pack',
                  patches: <HouseRulePatch>[],
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final payload = await container
        .read(houseRulePackAdminActionsProvider)
        .exportPackJson('imported_pack');

    expect(payload, contains('"id": "imported_pack"'));
    expect(payload, contains('"title": "Imported Pack"'));
  });

  test(
    'validateManifest reports resolver issues for unmatched selectors',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'house_rule_pack_admin_validate_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
      final baseData = CatalogSourceData(
        version: 'house_rules_v1',
        source: 'tests',
        metadata: const <String, dynamic>{},
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          for (final section in editableCatalogSections)
            section: section == CatalogSectionId.talents
                ? const <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'tal_klettern',
                      'name': 'Klettern',
                      'group': 'Körperlich',
                      'steigerung': 'D',
                      'attributes': <String>['MU', 'GE', 'KK'],
                      'active': true,
                    },
                  ]
                : const <Map<String, dynamic>>[],
        },
        reisebericht: const <Map<String, dynamic>>[],
      );

      final container = ProviderContainer(
        overrides: [
          houseRulePackRepositoryProvider.overrideWithValue(repository),
          catalogRuntimeDataProvider.overrideWith(
            (ref) async => CatalogRuntimeData.resolve(
              baseData: baseData,
              customSnapshot: const CustomCatalogSnapshot(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final issues = await container
          .read(houseRulePackAdminActionsProvider)
          .validateManifest(
            manifestJson: const <String, dynamic>{
              'id': 'validate_pack',
              'title': 'Validate Pack',
              'description': 'Has an unmatched selector',
              'patches': <Map<String, dynamic>>[
                <String, dynamic>{
                  'section': 'talents',
                  'selector': <String, dynamic>{'entryId': 'tal_unknown'},
                  'setFields': <String, dynamic>{'steigerung': 'C'},
                },
              ],
            },
          );

      expect(issues, isNotEmpty);
      expect(
        issues.any((issue) => issue.message.contains('trifft keine Eintraege')),
        isTrue,
      );
    },
  );

  test('suggestCopyPackId appends numeric suffixes for occupied ids', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'house_rule_pack_admin_copy_id_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
    final container = ProviderContainer(
      overrides: [
        houseRulePackRepositoryProvider.overrideWithValue(repository),
        catalogRuntimeDataProvider.overrideWith(
          (ref) async => _buildRuntimeData(
            packCatalog: const HouseRulePackCatalog(
              packs: <HouseRulePackManifest>[
                HouseRulePackManifest(
                  id: 'copy_me',
                  title: 'Original',
                  description: 'Built-In',
                  patches: <HouseRulePatch>[],
                  isBuiltIn: true,
                ),
                HouseRulePackManifest(
                  id: 'copy_me_copy',
                  title: 'Copy',
                  description: 'Imported',
                  patches: <HouseRulePatch>[],
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final suggestion = await container
        .read(houseRulePackAdminActionsProvider)
        .suggestCopyPackId('copy_me');

    expect(suggestion, 'copy_me_copy_2');
  });
}

CatalogRuntimeData _buildRuntimeData({
  HouseRulePackCatalog packCatalog = const HouseRulePackCatalog(),
}) {
  final baseData = CatalogSourceData(
    version: 'house_rules_v1',
    source: 'tests',
    metadata: const <String, dynamic>{},
    sections: <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final section in editableCatalogSections)
        section: const <Map<String, dynamic>>[],
    },
    reisebericht: const <Map<String, dynamic>>[],
  );
  return CatalogRuntimeData.resolve(
    baseData: baseData,
    customSnapshot: const CustomCatalogSnapshot(),
    packCatalog: packCatalog,
    activeHouseRulePackIds: packCatalog.resolveActivePackIds(const <String>{}),
  );
}
