import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

void main() {
  test('catalog parses and serializes expected sections', () {
    const raw = '''
{
  "version": "house_rules_v1",
  "source": "source.xlsx",
  "talents": [
    {
      "id": "tal_klettern",
      "name": "Klettern",
      "group": "Koerper",
      "steigerung": "B",
      "attributes": ["MU", "GE", "KK"],
      "active": true
    }
  ],
  "spells": [
    {
      "id": "spell_balsam",
      "name": "Balsam",
      "tradition": "Gildenmagie",
      "steigerung": "C",
      "attributes": ["KL", "IN", "CH"],
      "active": true
    }
  ],
  "weapons": [
    {
      "id": "wpn_langschwert",
      "name": "Langschwert",
      "type": "Nahkampf",
      "combatSkill": "Schwerter",
      "tp": "1W+4",
      "active": true
    }
  ]
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = RulesCatalog.fromJson(map);

    expect(catalog.version, 'house_rules_v1');
    expect(catalog.talents.length, 1);
    expect(catalog.spells.length, 1);
    expect(catalog.weapons.length, 1);
    expect(catalog.talents.first.name, 'Klettern');

    final roundtrip = RulesCatalog.fromJson(catalog.toJson());
    expect(roundtrip.talents.first.id, 'tal_klettern');
  });
}
