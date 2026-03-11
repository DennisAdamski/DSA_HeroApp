import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const manifestPath = 'assets/catalogs/house_rules_v1/manifest.json';
  const basePath = 'assets/catalogs/house_rules_v1';

  late Map<String, String> assets;

  Future<ByteData?> assetHandler(ByteData? message) async {
    final key = const StringCodec().decodeMessage(message);
    if (key == null) {
      return null;
    }
    final content = assets[key];
    if (content == null) {
      return null;
    }
    final bytes = Uint8List.fromList(utf8.encode(content));
    return ByteData.sublistView(bytes);
  }

  setUp(() {
    assets = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', assetHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  Map<String, String> buildValidAssets() {
    return <String, String>{
      manifestPath: jsonEncode({
        'version': 'house_rules_v1',
        'source': 'tests',
        'metadata': {'generatedBy': 'test'},
        'files': {
          'talente': 'talente.json',
          'waffentalente': 'waffentalente.json',
          'waffen': 'waffen.json',
          'magie': 'magie.json',
          'manoever': 'manoever.json',
        },
      }),
      '$basePath/talente.json': jsonEncode([
        {
          'id': 'tal_klettern',
          'name': 'Klettern',
          'group': 'Koerperliche Talente',
          'steigerung': 'B',
          'attributes': ['MU', 'GE', 'KK'],
          'active': true,
        },
      ]),
      '$basePath/waffentalente.json': jsonEncode([
        {
          'id': 'tal_dolche',
          'name': 'Dolche',
          'group': 'Kampftalent',
          'type': 'Nahkampf',
          'steigerung': 'D',
          'attributes': [],
          'active': true,
        },
      ]),
      '$basePath/waffen.json': jsonEncode([
        {
          'id': 'wpn_dolch',
          'name': 'Dolch',
          'type': 'Nahkampf',
          'combatSkill': 'Dolche',
          'tp': '1W+2',
          'active': true,
        },
      ]),
      '$basePath/magie.json': jsonEncode([
        {
          'id': 'spell_balsam',
          'name': 'Balsam',
          'tradition': 'Gildenmagie',
          'steigerung': 'C',
          'attributes': ['KL', 'IN', 'CH'],
          'targetObject': 'Lebewesen',
          'wirkung': 'Heilt LeP.',
          'variants': ['Selbst'],
          'active': true,
        },
      ]),
      '$basePath/manoever.json': jsonEncode([
        {
          'id': 'man_finte',
          'name': 'Finte',
          'gruppe': 'bewaffnet',
          'typ': 'Angriffsmanöver',
          'erschwernis': 'Attacke +1',
          'seite': '62',
          'erklarung': 'Kurze Erklärung',
          'erklarung_lang': 'Lange Erklärung',
        },
      ]),
    };
  }

  test('loads manifest and merges talente + waffentalente in order', () async {
    assets = buildValidAssets();

    final loader = const CatalogLoader();
    final catalog = await loader.loadFromAsset(manifestPath);

    expect(catalog.version, 'house_rules_v1');
    expect(catalog.source, 'tests');
    expect(catalog.talents.map((e) => e.id).toList(), [
      'tal_klettern',
      'tal_dolche',
    ]);
    expect(catalog.spells.map((e) => e.id).toList(), ['spell_balsam']);
    expect(catalog.spells.first.targetObject, 'Lebewesen');
    expect(catalog.spells.first.wirkung, 'Heilt LeP.');
    expect(catalog.spells.first.variants, ['Selbst']);
    expect(catalog.weapons.map((e) => e.id).toList(), ['wpn_dolch']);
    expect(catalog.maneuvers.map((e) => e.id).toList(), ['man_finte']);
    expect(catalog.maneuvers.first.typ, 'Angriffsmanöver');
    expect(catalog.maneuvers.first.erklarungLang, 'Lange Erklärung');
  });

  test('throws when section JSON top-level is not a list', () async {
    assets = buildValidAssets();
    assets['$basePath/talente.json'] = jsonEncode({'invalid': true});

    final loader = const CatalogLoader();
    await expectLater(
      loader.loadFromAsset(manifestPath),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must be a JSON array'),
        ),
      ),
    );
  });

  test('throws when talente contains group Kampftalent', () async {
    assets = buildValidAssets();
    assets['$basePath/talente.json'] = jsonEncode([
      {
        'id': 'tal_invalid',
        'name': 'Invalid',
        'group': 'Kampftalent',
        'steigerung': 'D',
        'attributes': [],
        'active': true,
      },
    ]);

    final loader = const CatalogLoader();
    await expectLater(
      loader.loadFromAsset(manifestPath),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must not use group "Kampftalent"'),
        ),
      ),
    );
  });

  test('throws when waffentalente contains non-Kampftalent', () async {
    assets = buildValidAssets();
    assets['$basePath/waffentalente.json'] = jsonEncode([
      {
        'id': 'tal_invalid',
        'name': 'Invalid',
        'group': 'Wissenstalente',
        'steigerung': 'B',
        'attributes': [],
        'active': true,
      },
    ]);

    final loader = const CatalogLoader();
    await expectLater(
      loader.loadFromAsset(manifestPath),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('is not group "Kampftalent"'),
        ),
      ),
    );
  });

  test('throws on duplicate talent ids across split talent files', () async {
    assets = buildValidAssets();
    assets['$basePath/waffentalente.json'] = jsonEncode([
      {
        'id': 'tal_klettern',
        'name': 'Dolche',
        'group': 'Kampftalent',
        'steigerung': 'D',
        'attributes': [],
        'active': true,
      },
    ]);

    final loader = const CatalogLoader();
    await expectLater(
      loader.loadFromAsset(manifestPath),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate talents id'),
        ),
      ),
    );
  });

  test('throws on duplicate spell ids', () async {
    assets = buildValidAssets();
    assets['$basePath/magie.json'] = jsonEncode([
      {
        'id': 'spell_balsam',
        'name': 'Balsam',
        'tradition': '',
        'steigerung': 'C',
        'attributes': [],
        'active': true,
      },
      {
        'id': 'spell_balsam',
        'name': 'Flim Flam',
        'tradition': '',
        'steigerung': 'B',
        'attributes': [],
        'active': true,
      },
    ]);

    final loader = const CatalogLoader();
    await expectLater(
      loader.loadFromAsset(manifestPath),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate spells id'),
        ),
      ),
    );
  });

  test('throws on duplicate weapon ids', () async {
    assets = buildValidAssets();
    assets['$basePath/waffen.json'] = jsonEncode([
      {
        'id': 'wpn_dolch',
        'name': 'Dolch',
        'type': 'Nahkampf',
        'combatSkill': 'Dolche',
        'tp': '1W+2',
        'active': true,
      },
      {
        'id': 'wpn_dolch',
        'name': 'Kurzschwert',
        'type': 'Nahkampf',
        'combatSkill': 'Schwerter',
        'tp': '1W+3',
        'active': true,
      },
    ]);

    final loader = const CatalogLoader();
    await expectLater(
      loader.loadFromAsset(manifestPath),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate weapons id'),
        ),
      ),
    );
  });
}
