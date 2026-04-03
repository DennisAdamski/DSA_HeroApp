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
      "tp": "1W6+4",
      "tpkk": "11/4",
      "atMod": 1,
      "paMod": 0,
      "iniMod": -1,
      "weight": "80",
      "length": "95",
      "breakFactor": "1",
      "price": "180",
      "remarks": "-",
      "reach": "N",
      "active": true
    },
    {
      "id": "wpn_kurzbogen",
      "name": "Kurzbogen",
      "type": "Fernkampf",
      "combatSkill": "Bogen",
      "tp": "1W6+4*",
      "weight": "20 + 2",
      "price": "45 S / 25 K",
      "reloadTime": 2,
      "reloadTimeText": "2",
      "rangedDistanceBands": [
        {"label": "5", "tpMod": 1},
        {"label": "15", "tpMod": 1},
        {"label": "25", "tpMod": 0},
        {"label": "40", "tpMod": 0},
        {"label": "60", "tpMod": -1}
      ],
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
      "stil_typ": "waffenloser_kampfstil",
      "seite": "73",
      "beschreibung": "Beschleunigt Orientierung und verbessert Reaktionen.",
      "erklarung_lang": "Lange Sonderfertigkeitsbeschreibung.",
      "voraussetzungen": "IN 12",
      "verbreitung": "4, durch Praxis",
      "kosten": "200 AP",
      "aktiviert_manoever_ids": ["man_finte"],
      "kampfwert_boni": [
        {
          "gilt_fuer_talent": "raufen",
          "at_bonus": 1,
          "pa_bonus": 1,
          "ini_mod": 0
        }
      ]
    }
  ]
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = RulesCatalog.fromJson(map);

    expect(catalog.version, 'house_rules_v1');
    expect(catalog.talents.length, 1);
    expect(catalog.spells.length, 1);
    expect(catalog.weapons.length, 2);
    expect(catalog.maneuvers.length, 1);
    expect(catalog.combatSpecialAbilities.length, 1);
    expect(catalog.talents.first.name, 'Klettern');
    expect(catalog.spells.first.targetObject, 'Lebewesen');
    expect(catalog.weapons.first.breakFactor, '1');
    expect(catalog.weapons.first.weight, '80');
    expect(catalog.weapons.first.length, '95');
    expect(catalog.weapons.first.price, '180');
    expect(catalog.weapons.first.remarks, '-');
    expect(catalog.weapons.first.reach, 'N');
    expect(catalog.weapons[1].reloadTime, 2);
    expect(catalog.weapons[1].reloadTimeText, '2');
    expect(catalog.weapons[1].rangedDistanceBands.length, 5);
    expect(catalog.weapons[1].rangedDistanceBands[4].tpMod, -1);
    expect(catalog.spells.first.source, 'Liber Cantiones S. 12');
    expect(catalog.spells.first.variants, ['Selbst', 'Fremdheilung']);
    expect(catalog.maneuvers.first.kosten, '200 AP');
    expect(catalog.combatSpecialAbilities.first.name, 'Aufmerksamkeit');
    expect(
      catalog.combatSpecialAbilities.first.stilTyp,
      'waffenloser_kampfstil',
    );
    expect(catalog.combatSpecialAbilities.first.aktiviertManoeverIds, [
      'man_finte',
    ]);
    expect(catalog.combatSpecialAbilities.first.kampfwertBoni.first.atBonus, 1);

    final roundtrip = RulesCatalog.fromJson(catalog.toJson());
    expect(roundtrip.talents.first.id, 'tal_klettern');
    expect(roundtrip.weapons.first.breakFactor, '1');
    expect(roundtrip.weapons.first.weight, '80');
    expect(roundtrip.weapons.first.length, '95');
    expect(roundtrip.weapons.first.price, '180');
    expect(roundtrip.weapons.first.remarks, '-');
    expect(roundtrip.weapons[1].reloadTimeText, '2');
    expect(roundtrip.weapons[1].rangedDistanceBands[0].label, '5');
    expect(roundtrip.spells.first.wirkung, 'Heilt LeP.');
    expect(roundtrip.spells.first.targetObject, 'Lebewesen');
    expect(roundtrip.spells.first.source, 'Liber Cantiones S. 12');
    expect(roundtrip.spells.first.variants, ['Selbst', 'Fremdheilung']);
    expect(roundtrip.maneuvers.first.verbreitung, '6, fast ueberall');
    expect(roundtrip.combatSpecialAbilities.first.kosten, '200 AP');
  });

  test('weapon parsing keeps backwards compatibility for legacy entries', () {
    const raw = '''
{
  "id": "wpn_alt",
  "name": "Altwaffe",
  "type": "Nahkampf",
  "combatSkill": "Hiebwaffen",
  "tp": "1W6+2",
  "tpkk": "11/4",
  "atMod": 0,
  "paMod": -1,
  "iniMod": 0,
  "reach": "N",
  "active": true
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final weapon = WeaponDef.fromJson(map);

    expect(weapon.weight, '');
    expect(weapon.length, '');
    expect(weapon.breakFactor, '');
    expect(weapon.price, '');
    expect(weapon.remarks, '');
    expect(weapon.reloadTime, 0);
    expect(weapon.reloadTimeText, '');
    expect(weapon.rangedDistanceBands, isEmpty);
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

  test('maneuver neue Felder: Rueckwaertskompatibilitaet — Defaults bei fehlendem JSON', () {
    const raw = '''
{
  "id": "man_alt",
  "name": "Altmanoever"
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final maneuver = ManeuverDef.fromJson(map);

    expect(maneuver.nurFuerTalente, isEmpty);
    expect(maneuver.mussSeparatErlerntWerden, false);
    expect(maneuver.giltFuerTalentTyp, '');
  });

  test('maneuver neue Felder: Lesen aus JSON', () {
    const raw = '''
{
  "id": "man_fk",
  "name": "Fernkampf-Manoever",
  "nur_fuer_talente": ["tal_bogen", "tal_armbrust"],
  "muss_separat_erlernt_werden": true,
  "gilt_fuer_talent_typ": "fernkampf"
}
''';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final maneuver = ManeuverDef.fromJson(map);

    expect(maneuver.nurFuerTalente, ['tal_bogen', 'tal_armbrust']);
    expect(maneuver.mussSeparatErlerntWerden, true);
    expect(maneuver.giltFuerTalentTyp, 'fernkampf');
  });

  test('maneuver neue Felder: toJson schreibt nur Nicht-Default-Werte', () {
    const defaultManeuver = ManeuverDef(id: 'man_x', name: 'X');
    final defaultJson = defaultManeuver.toJson();

    expect(defaultJson.containsKey('nur_fuer_talente'), false);
    expect(defaultJson.containsKey('muss_separat_erlernt_werden'), false);
    expect(defaultJson.containsKey('gilt_fuer_talent_typ'), false);

    const nichtDefaultManeuver = ManeuverDef(
      id: 'man_y',
      name: 'Y',
      nurFuerTalente: ['tal_bogen'],
      mussSeparatErlerntWerden: true,
      giltFuerTalentTyp: 'fernkampf',
    );
    final nichtDefaultJson = nichtDefaultManeuver.toJson();

    expect(nichtDefaultJson['nur_fuer_talente'], ['tal_bogen']);
    expect(nichtDefaultJson['muss_separat_erlernt_werden'], true);
    expect(nichtDefaultJson['gilt_fuer_talent_typ'], 'fernkampf');
  });

  test('combat special ability fields roundtrip correctly', () {
    const raw = '''
{
  "id": "ksf_aufmerksamkeit",
  "name": "Aufmerksamkeit",
  "gruppe": "kampf",
  "typ": "sonderfertigkeit",
  "stil_typ": "waffenloser_kampfstil",
  "seite": "73",
  "beschreibung": "Beschleunigt Orientierung und verbessert Reaktionen.",
  "erklarung_lang": "Lange Sonderfertigkeitsbeschreibung.",
  "voraussetzungen": "IN 12",
  "verbreitung": "4, durch Praxis",
  "kosten": "200 AP",
  "aktiviert_manoever_ids": ["man_finte"],
  "kampfwert_boni": [
    {
      "gilt_fuer_talent": "raufen",
      "at_bonus": 1,
      "pa_bonus": 1,
      "ini_mod": 0
    }
  ]
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
    expect(ability.stilTyp, 'waffenloser_kampfstil');
    expect(ability.aktiviertManoeverIds, ['man_finte']);
    expect(ability.kampfwertBoni.single.giltFuerTalent, 'raufen');
    expect(ability.kampfwertBoni.single.paBonus, 1);

    final roundtrip = CombatSpecialAbilityDef.fromJson(ability.toJson());
    expect(roundtrip.id, 'ksf_aufmerksamkeit');
    expect(
      roundtrip.beschreibung,
      'Beschleunigt Orientierung und verbessert Reaktionen.',
    );
  });
}
