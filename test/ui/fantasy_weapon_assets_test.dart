import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sichert Katalogabdeckung, eindeutige Zuordnung und nutzbare PNG-Assets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const directory = 'assets/ui/fantasy_weapons_v1';
  late List<Map<String, dynamic>> assets;

  setUpAll(() async {
    final text = await rootBundle.loadString('$directory/manifest.json');
    final manifest = jsonDecode(text) as Map<String, dynamic>;
    final entries = manifest['assets'] as List<dynamic>;
    assets = entries.cast<Map<String, dynamic>>();
  });

  test('Waffensymbole decken alle Kataloggruppen und Waffenarten ab', () async {
    final weaponsText = await rootBundle.loadString(
      'assets/catalogs/house_rules_v1/waffen.json',
    );
    final talentsText = await rootBundle.loadString(
      'assets/catalogs/house_rules_v1/waffentalente.json',
    );
    final weaponEntries = jsonDecode(weaponsText) as List<dynamic>;
    final talentEntries = jsonDecode(talentsText) as List<dynamic>;
    final weapons = weaponEntries.cast<Map<String, dynamic>>();
    final talents = talentEntries.cast<Map<String, dynamic>>();
    final types = weapons.map((weapon) => weapon['type']).toSet();
    final skills = weapons.map((weapon) => weapon['combatSkill']).toSet();
    final typeAssets = assets
        .where((asset) => asset['kind'] == 'type')
        .toList();
    final skillAssets = assets
        .where((asset) => asset['kind'] == 'combatSkill')
        .toList();

    expect(typeAssets.map((asset) => asset['catalogValue']).toSet(), types);
    expect(skillAssets.map((asset) => asset['catalogValue']).toSet(), skills);
    expect(typeAssets.length, types.length);
    expect(skillAssets.length, skills.length);
    final talentIds = talents.map((talent) => talent['id']).toSet();
    final assetTalentIds = skillAssets
        .map((asset) => asset['catalogId'])
        .toSet();
    expect(assetTalentIds, talentIds);
    for (final talent in talents) {
      final asset = skillAssets.singleWhere(
        (entry) => entry['catalogId'] == talent['id'],
      );
      expect(asset['catalogValue'], talent['name']);
    }
    expect(assets.map((asset) => asset['path']).toSet().length, assets.length);
    expect(assets.map((asset) => asset['id']).toSet().length, assets.length);
  });

  test(
    'Alle 29 Waffensymbole sind gebündelt, sichtbar und transparent',
    () async {
      expect(assets, hasLength(29));
      for (final asset in assets) {
        final path = asset['path'] as String;
        expect(path, startsWith('$directory/'));
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          expect(image.width, greaterThanOrEqualTo(256), reason: path);
          expect(image.height, greaterThanOrEqualTo(256), reason: path);
          final pixels = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(pixels, isNotNull, reason: path);
          final rgba = pixels!.buffer.asUint8List(
            pixels.offsetInBytes,
            pixels.lengthInBytes,
          );
          var transparent = 0;
          var visible = 0;
          for (var offset = 3; offset < rgba.length; offset += 4) {
            if (rgba[offset] == 0) transparent++;
            if (rgba[offset] > 0) visible++;
          }
          expect(transparent, greaterThan(rgba.length ~/ 40), reason: path);
          expect(visible, greaterThan(rgba.length ~/ 400), reason: path);
        } finally {
          image.dispose();
          codec.dispose();
        }
      }
    },
  );
}
