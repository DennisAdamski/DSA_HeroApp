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
  ],
  "maneuvers": [
    {
      "id": "man_finte",
      "name": "Finte",
      "gruppe": "bewaffnet",
      "typ": "Angriffsmanoever",
      "erschwernis": "Angriff +Ansage",
      "seite": "63",
      "erklarung": "Erschwert die gegnerische Parade.",
      "erklarung_lang": "Lange Regelerklaerung.",
      "voraussetzungen": "GE 12",
      "verbreitung": "6, fast ueberall",
      "kosten": "200 AP"
    }
  ],
  "combatSpecialAbilities": [
    {
      "id": "ksf_aufmerksamkeit",
      "name": "Aufmerksamkeit",
      "gruppe": "kampf",
      "typ": "sonderfertigkeit",
      "seite": "73",
      "beschreibung": "Beschleunigt Orientierung und verbessert Reaktionen.",
      "erklarung_lang": "Lange Sonderfertigkeitsbeschreibung.",
      "voraussetzungen": "IN 12",
      "verbreitung": "4, durch Praxis",
      "kosten": "200 AP"
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
    expect(catalog.maneuvers.length, 1);
    expect(catalog.combatSpecialAbilities.length, 1);
    expect(catalog.talents.first.name, 'Klettern');
    expect(catalog.spells.first.targetObject, 'Lebewesen');
    expect(catalog.spells.first.source, 'Liber Cantiones S. 12');
    expect(catalog.spells.first.variants, ['Selbst', 'Fremdheilung']);
    expect(catalog.maneuvers.first.kosten, '200 AP');
    expect(catalog.combatSpecialAbilities.first.name, 'Aufmerksamkeit');

    final roundtrip = RulesCatalog.fromJson(catalog.toJson());
    expect(roundtrip.talents.first.id, 'tal_klettern');
    expect(roundtrip.spells.first.wirkung, 'Heilt LeP.');
    expect(roundtrip.spells.first.targetObject, 'Lebewesen');
    expect(roundtrip.spells.first.source, 'Liber Cantiones S. 12');
    expect(roundtrip.spells.first.variants, ['Selbst', 'Fremdheilung']);
    expect(roundtrip.maneuvers.first.verbreitung, '6, fast ueberall');
    expect(roundtrip.combatSpecialAbilities.first.kosten, '200 AP');
  });

  test('maneuver fields roundtrip correctly', () {
    const raw = '''
{
  "id": "man_finte",
  "name": "Finte",
  "gruppe": "bewaffnet",
  "typ": "Angriffsmanoever",
  "erschwernis": "Angriff +Ansage",
  "seite": "63",
  "erklarung": "Erschwert die gegnerische Parade.",
  "erklarung_lang": "Lange Regelerklaerung.",
  "voraussetzungen": "GE 12",
  "verbreitung": "6, fast ueberall",
  "kosten": "200 AP"
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final maneuver = ManeuverDef.fromJson(map);

    expect(maneuver.typ, 'Angriffsmanoever');
    expect(maneuver.erklarungLang, 'Lange Regelerklaerung.');
    expect(maneuver.voraussetzungen, 'GE 12');
    expect(maneuver.verbreitung, '6, fast ueberall');
    expect(maneuver.kosten, '200 AP');

    final roundtrip = ManeuverDef.fromJson(maneuver.toJson());
    expect(roundtrip.typ, 'Angriffsmanoever');
    expect(roundtrip.erklarungLang, 'Lange Regelerklaerung.');
    expect(roundtrip.voraussetzungen, 'GE 12');
    expect(roundtrip.verbreitung, '6, fast ueberall');
    expect(roundtrip.kosten, '200 AP');
  });

  test('combat special ability fields roundtrip correctly', () {
    const raw = '''
{
  "id": "ksf_aufmerksamkeit",
  "name": "Aufmerksamkeit",
  "gruppe": "kampf",
  "typ": "sonderfertigkeit",
  "seite": "73",
  "beschreibung": "Beschleunigt Orientierung und verbessert Reaktionen.",
  "erklarung_lang": "Lange Sonderfertigkeitsbeschreibung.",
  "voraussetzungen": "IN 12",
  "verbreitung": "4, durch Praxis",
  "kosten": "200 AP"
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final ability = CombatSpecialAbilityDef.fromJson(map);

    expect(ability.name, 'Aufmerksamkeit');
    expect(
      ability.beschreibung,
      'Beschleunigt Orientierung und verbessert Reaktionen.',
    );
    expect(ability.erklarungLang, 'Lange Sonderfertigkeitsbeschreibung.');
    expect(ability.voraussetzungen, 'IN 12');
    expect(ability.verbreitung, '4, durch Praxis');
    expect(ability.kosten, '200 AP');

    final roundtrip = CombatSpecialAbilityDef.fromJson(ability.toJson());
    expect(roundtrip.id, 'ksf_aufmerksamkeit');
    expect(
      roundtrip.beschreibung,
      'Beschleunigt Orientierung und verbessert Reaktionen.',
    );
  });
}
