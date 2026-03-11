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
      "targetObject": "Lebewesen",
      "aspCost": "1 AsP pro LeP",
      "range": "Beruehrung",
      "duration": "augenblicklich",
      "wirkung": "Heilt LeP.",
      "source": "Liber Cantiones S. 12",
      "variants": ["Selbst", "Fremdheilung"],
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
    expect(catalog.spells.first.targetObject, 'Lebewesen');
    expect(catalog.spells.first.source, 'Liber Cantiones S. 12');
    expect(catalog.spells.first.variants, ['Selbst', 'Fremdheilung']);

    final roundtrip = RulesCatalog.fromJson(catalog.toJson());
    expect(roundtrip.talents.first.id, 'tal_klettern');
    expect(roundtrip.spells.first.wirkung, 'Heilt LeP.');
    expect(roundtrip.spells.first.targetObject, 'Lebewesen');
    expect(roundtrip.spells.first.source, 'Liber Cantiones S. 12');
    expect(roundtrip.spells.first.variants, ['Selbst', 'Fremdheilung']);
  });

  test('maneuver fields typ and erklarung_lang roundtrip correctly', () {
    const raw = '''
{
  "id": "man_finte",
  "name": "Finte",
  "gruppe": "bewaffnet",
  "typ": "Angriffsmanöver",
  "erschwernis": "Attacke +1",
  "seite": "62",
  "erklarung": "Erschwert die gegnerische Parade.",
  "erklarung_lang": "Lange Regelerklärung."
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final maneuver = ManeuverDef.fromJson(map);

    expect(maneuver.typ, 'Angriffsmanöver');
    expect(maneuver.erklarungLang, 'Lange Regelerklärung.');

    final roundtrip = ManeuverDef.fromJson(maneuver.toJson());
    expect(roundtrip.typ, 'Angriffsmanöver');
    expect(roundtrip.erklarungLang, 'Lange Regelerklärung.');
  });
}
