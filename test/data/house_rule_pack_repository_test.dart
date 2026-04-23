import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';

void main() {
  test('loads imported house rule manifests from hero storage', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'house_rule_pack_repository_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final manifestDirectory = Directory(
      path.join(
        tempDir.path,
        HouseRulePackRepository.houseRulePackRootDirectory,
        'house_rules_v1',
        'sample_pack',
      ),
    );
    await manifestDirectory.create(recursive: true);
    final manifestFile = File(
      path.join(manifestDirectory.path, 'manifest.json'),
    );
    await manifestFile.writeAsString('''
{
  "id": "sample_pack",
  "title": "Sample Pack",
  "description": "Imported override",
  "patches": [
    {
      "section": "talents",
      "selector": {"entryId": "tal_klettern"},
      "setFields": {"steigerung": "C"}
    }
  ]
}
''');

    final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
    final snapshot = await repository.load(catalogVersion: 'house_rules_v1');

    expect(snapshot.issues, isEmpty);
    expect(snapshot.packs, hasLength(1));
    expect(snapshot.packs.single.id, 'sample_pack');
    expect(snapshot.packs.single.filePath, manifestFile.path);
  });

  test(
    'saveManifest persists a manifest and loadSinglePack reads it back',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'house_rule_pack_repository_save_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
      await repository.saveManifest(
        catalogVersion: 'house_rules_v1',
        manifestJson: const <String, dynamic>{
          'id': 'saved_pack',
          'title': 'Saved Pack',
          'description': 'Persisted pack',
          'patches': <Map<String, dynamic>>[
            <String, dynamic>{
              'section': 'talents',
              'selector': <String, dynamic>{'entryId': 'tal_klettern'},
              'setFields': <String, dynamic>{'steigerung': 'C'},
            },
          ],
        },
      );

      final manifest = await repository.loadSinglePack(
        catalogVersion: 'house_rules_v1',
        packId: 'saved_pack',
      );

      expect(manifest, isNotNull);
      expect(manifest!.id, 'saved_pack');
      expect(manifest.title, 'Saved Pack');
      expect(manifest.patches, hasLength(1));
    },
  );

  test(
    'saveManifest removes previous pack directory after id rename',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'house_rule_pack_repository_rename_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
      await repository.saveManifest(
        catalogVersion: 'house_rules_v1',
        manifestJson: const <String, dynamic>{
          'id': 'old_pack',
          'title': 'Old Pack',
          'description': 'Original id',
          'patches': <Map<String, dynamic>>[],
        },
      );
      await repository.saveManifest(
        catalogVersion: 'house_rules_v1',
        previousPackId: 'old_pack',
        manifestJson: const <String, dynamic>{
          'id': 'renamed_pack',
          'title': 'Renamed Pack',
          'description': 'New id',
          'patches': <Map<String, dynamic>>[],
        },
      );

      final oldManifest = File(
        path.join(
          tempDir.path,
          HouseRulePackRepository.houseRulePackRootDirectory,
          'house_rules_v1',
          'old_pack',
          'manifest.json',
        ),
      );
      final renamedManifest = await repository.loadSinglePack(
        catalogVersion: 'house_rules_v1',
        packId: 'renamed_pack',
      );

      expect(await oldManifest.exists(), isFalse);
      expect(renamedManifest, isNotNull);
      expect(renamedManifest!.id, 'renamed_pack');
    },
  );

  test('deletePack removes the imported pack directory', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'house_rule_pack_repository_delete_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final repository = HouseRulePackRepository(heroStoragePath: tempDir.path);
    await repository.saveManifest(
      catalogVersion: 'house_rules_v1',
      manifestJson: const <String, dynamic>{
        'id': 'delete_pack',
        'title': 'Delete Pack',
        'description': 'Delete me',
        'patches': <Map<String, dynamic>>[],
      },
    );

    await repository.deletePack(
      catalogVersion: 'house_rules_v1',
      packId: 'delete_pack',
    );

    final deletedManifest = await repository.loadSinglePack(
      catalogVersion: 'house_rules_v1',
      packId: 'delete_pack',
    );
    expect(deletedManifest, isNull);
  });
}
