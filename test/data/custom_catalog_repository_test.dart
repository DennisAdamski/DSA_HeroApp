import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';

void main() {
  Future<Directory> createTempDir() async {
    final dir = await Directory.systemTemp.createTemp(
      'custom_catalog_repository_test',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    return dir;
  }

  test('saveEntry and load roundtrip custom entries as per-file JSON', () async {
    final tempDir = await createTempDir();
    final repository = CustomCatalogRepository(heroStoragePath: tempDir.path);

    await repository.saveEntry(
      catalogVersion: 'house_rules_v1',
      section: CatalogSectionId.talents,
      entry: const <String, dynamic>{
        'id': 'tal_custom',
        'name': 'Hauswissen',
        'group': 'Wissen',
        'steigerung': 'B',
        'attributes': <String>['KL', 'KL', 'IN'],
        'active': true,
      },
    );

    final snapshot = await repository.load(catalogVersion: 'house_rules_v1');

    expect(snapshot.issues, isEmpty);
    expect(snapshot.entries, hasLength(1));
    expect(snapshot.entries.single.id, 'tal_custom');
    expect(snapshot.entries.single.section, CatalogSectionId.talents);
    expect(snapshot.entries.single.data['name'], 'Hauswissen');
  });

  test('load reports invalid files and duplicate custom ids', () async {
    final tempDir = await createTempDir();
    final repository = CustomCatalogRepository(heroStoragePath: tempDir.path);
    final sectionPath = repository.resolveSectionDirectory(
      catalogVersion: 'house_rules_v1',
      section: CatalogSectionId.talents,
    );
    await Directory(sectionPath).create(recursive: true);

    await File('$sectionPath${Platform.pathSeparator}invalid.json')
        .writeAsString('[]');
    await File('$sectionPath${Platform.pathSeparator}one.json').writeAsString(
      '{"id":"tal_dup","name":"A","group":"Wissen","steigerung":"B","attributes":["KL","KL","IN"],"active":true}',
    );
    await File('$sectionPath${Platform.pathSeparator}two.json').writeAsString(
      '{"id":"tal_dup","name":"B","group":"Wissen","steigerung":"B","attributes":["KL","KL","IN"],"active":true}',
    );

    final snapshot = await repository.load(catalogVersion: 'house_rules_v1');

    expect(snapshot.entries, hasLength(1));
    expect(snapshot.issues, hasLength(2));
    expect(
      snapshot.issues.any((issue) => issue.message.contains('Doppelte Custom-ID')),
      isTrue,
    );
  });

  test('runtime resolve ignores custom ids that collide with base ids', () {
    final baseData = CatalogSourceData(
      version: 'house_rules_v1',
      source: 'tests',
      metadata: const <String, dynamic>{},
      sections: <CatalogSectionId, List<Map<String, dynamic>>>{
        for (final section in editableCatalogSections)
          section: section == CatalogSectionId.talents
              ? const <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'tal_base',
                    'name': 'Basiswissen',
                    'group': 'Wissen',
                    'steigerung': 'B',
                    'attributes': <String>['KL', 'KL', 'IN'],
                    'active': true,
                  },
                ]
              : const <Map<String, dynamic>>[],
      },
      reisebericht: const <Map<String, dynamic>>[],
    );

    final runtimeData = CatalogRuntimeData.resolve(
      baseData: baseData,
      customSnapshot: const CustomCatalogSnapshot(
        entries: <CustomCatalogEntryRecord>[
          CustomCatalogEntryRecord(
            section: CatalogSectionId.talents,
            id: 'tal_base',
            filePath: '/tmp/tal_base.json',
            data: <String, dynamic>{
              'id': 'tal_base',
              'name': 'Konflikt',
              'group': 'Wissen',
              'steigerung': 'B',
              'attributes': <String>['KL', 'KL', 'IN'],
              'active': true,
            },
          ),
          CustomCatalogEntryRecord(
            section: CatalogSectionId.talents,
            id: 'tal_custom',
            filePath: '/tmp/tal_custom.json',
            data: <String, dynamic>{
              'id': 'tal_custom',
              'name': 'Hauswissen',
              'group': 'Wissen',
              'steigerung': 'B',
              'attributes': <String>['KL', 'KL', 'IN'],
              'active': true,
            },
          ),
        ],
      ),
    );

    final effectiveIds = runtimeData.effectiveData
        .entriesFor(CatalogSectionId.talents)
        .map((entry) => entry['id'])
        .toList();

    expect(effectiveIds, containsAll(<String>['tal_base', 'tal_custom']));
    expect(runtimeData.issues, hasLength(1));
    expect(
      runtimeData.issues.single.message,
      contains('kollidiert mit einem Basis-Eintrag'),
    );
  });
}
