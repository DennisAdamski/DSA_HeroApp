import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

void main() {
  final weapons = _loadWeapons();
  final talents = _loadTalents();

  test('arsenal melee entries expose raw metadata and modifiers', () {
    final langschwert = _weaponBySkillAndName(
      weapons,
      'Schwerter',
      'Langschwert',
    );
    expect(langschwert.tp, '1W6+4');
    expect(langschwert.tpkk, '11/4');
    expect(langschwert.weight, '80');
    expect(langschwert.length, '95');
    expect(langschwert.breakFactor, '1');
    expect(langschwert.price, '180');
    expect(langschwert.remarks, '-');
    expect(langschwert.reach, 'N');
    expect(
      langschwert.source,
      'Aventurisches Arsenal (4. Auflage, 2011) PDF S. 149',
    );

    final baccanaq = _weaponBySkillAndName(
      weapons,
      'Hiebwaffen',
      'Baccanaq / Bakka',
    );
    expect(baccanaq.tp, '1W6+4');
    expect(baccanaq.tpkk, '12/4');
    expect(baccanaq.iniMod, -1);
    expect(baccanaq.atMod, 0);
    expect(baccanaq.paMod, -2);
    expect(baccanaq.weight, '80');
    expect(baccanaq.length, '80');
    expect(baccanaq.breakFactor, '5');
    expect(
      baccanaq.source,
      'Aventurisches Arsenal (4. Auflage, 2011) PDF S. 147',
    );

    final fausthieb = _weaponBySkillAndName(weapons, 'Raufen', 'Fausthieb');
    expect(fausthieb.tp, '1W6(A)*');
    expect(fausthieb.tpkk, '10/3');
    expect(fausthieb.iniMod, -2);
    expect(fausthieb.atMod, -1);
    expect(fausthieb.paMod, -2);
    expect(fausthieb.weight, '-');
    expect(fausthieb.breakFactor, '-');
    expect(fausthieb.price, '-');
    expect(fausthieb.reach, 'H');
    expect(
      fausthieb.source,
      'Aventurisches Arsenal (4. Auflage, 2011) PDF S. 150',
    );
  });

  test('arsenal ranged entries preserve mapped names and special notation', () {
    final schwereArmbrust = _weaponBySkillAndName(
      weapons,
      'Armbrust',
      'Schwere Armbrust',
    );
    expect(schwereArmbrust.tp, '2W6+6*');
    expect(schwereArmbrust.weight, '200 + 4');
    expect(schwereArmbrust.reloadTime, 30);
    expect(schwereArmbrust.reloadTimeText, '30');
    expect(schwereArmbrust.price, '350 S / 20 H');
    expect(schwereArmbrust.rangedDistanceBands.length, 5);
    expect(schwereArmbrust.rangedDistanceBands.first.label, '10');
    expect(schwereArmbrust.rangedDistanceBands.last.tpMod, -3);

    final eisenwalder = _weaponBySkillAndName(
      weapons,
      'Armbrust',
      'Eisenwalder',
    );
    expect(eisenwalder.tp, '1W6+3*');
    expect(eisenwalder.reloadTime, 3);
    expect(eisenwalder.reloadTimeText, '3 (20)');
    expect(eisenwalder.price, '400 S / 15 H');

    final leichtesWurfnetz = _weaponBySkillAndName(
      weapons,
      'Schleuder',
      'Leichtes Wurfnetz',
    );
    expect(leichtesWurfnetz.tp, '1W6+2***');
    expect(leichtesWurfnetz.reloadTime, 1);
    expect(leichtesWurfnetz.reloadTimeText, '1*****');
    expect(leichtesWurfnetz.rangedDistanceBands[3].label, '5');

    final jagddiskus = _weaponBySkillAndName(weapons, 'Diskus', 'Jagddiskus');
    expect(jagddiskus.tp, '2W6+4 (A)');
    expect(jagddiskus.price, '30 S');
    expect(jagddiskus.rangedDistanceBands.last.tpMod, -1);

    final granataepfel = weapons
        .where((weapon) => weapon.name == 'Granatapfel')
        .toList();
    expect(granataepfel.length, 2);
    expect(granataepfel.map((weapon) => weapon.combatSkill).toSet(), {
      'Wurfspeere',
      'Schleuder',
    });
  });

  test('talent categories include the added arsenal weapons', () {
    final diskus = _talentByName(talents, 'Diskus');
    expect(diskus.weaponCategory, contains('Jagddiskus'));

    final schleuder = _talentByName(talents, 'Schleuder');
    expect(schleuder.weaponCategory, contains('Granatapfel'));
    expect(schleuder.weaponCategory, contains('Kettenkugel'));

    final dolche = _talentByName(talents, 'Dolche');
    expect(dolche.weaponCategory, contains('Eberfänger'));
    expect(dolche.weaponCategory, contains('Messer'));

    final raufen = _talentByName(talents, 'Raufen');
    expect(raufen.weaponCategory, contains('Hände'));
    expect(raufen.weaponCategory, contains('Stoß mit Schild'));
  });
}

List<WeaponDef> _loadWeapons() {
  final raw = _readRepoFile('assets/catalogs/house_rules_v1/waffen.json');
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .cast<Map<String, dynamic>>()
      .map(WeaponDef.fromJson)
      .toList(growable: false);
}

List<TalentDef> _loadTalents() {
  final raw = _readRepoFile(
    'assets/catalogs/house_rules_v1/waffentalente.json',
  );
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .cast<Map<String, dynamic>>()
      .map(TalentDef.fromJson)
      .toList(growable: false);
}

String _readRepoFile(String relativePath) {
  final raw = File(relativePath).readAsStringSync();
  return raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
}

WeaponDef _weaponBySkillAndName(
  List<WeaponDef> weapons,
  String combatSkill,
  String name,
) {
  return weapons.singleWhere(
    (weapon) => weapon.combatSkill == combatSkill && weapon.name == name,
  );
}

TalentDef _talentByName(List<TalentDef> talents, String name) {
  return talents.singleWhere((talent) => talent.name == name);
}
