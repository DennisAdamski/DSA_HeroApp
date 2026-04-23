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
}
