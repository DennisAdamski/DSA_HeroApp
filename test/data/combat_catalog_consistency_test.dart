import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

void main() {
  final maneuvers = _loadManeuvers();
  final combatSpecialAbilities = _loadCombatSpecialAbilities();

  test('combat special abilities do not duplicate maneuver-backed entries', () {
    final maneuverTokens = maneuvers
        .map((entry) => normalizeCombatToken(entry.name))
        .where((entry) => entry.isNotEmpty)
        .toSet();
    final combatSpecialAbilityTokens = combatSpecialAbilities
        .map((entry) => normalizeCombatToken(entry.name))
        .where((entry) => entry.isNotEmpty)
        .toSet();

    expect(combatSpecialAbilityTokens.intersection(maneuverTokens), isEmpty);
  });

  test(
    'catalog keeps genuine combat special abilities for WdS pages 74-76 and 95',
    () {
      final names = combatSpecialAbilities.map((entry) => entry.name).toSet();

      expect(names, contains('Berittener Schütze'));
      expect(names, contains('Eisenhagel'));
      expect(names, contains('Scharfschütze'));
      expect(names, contains('Meisterschütze'));
      expect(names, contains('Schnellladen (Bogen)'));
      expect(names, contains('Schnellladen (Armbrust)'));
      expect(names, contains('Meisterliches Entwaffnen'));

      expect(names, isNot(contains('Finte')));
      expect(names, isNot(contains('Klingensturm')));
      expect(names, isNot(contains('Befreiungsschlag')));
    },
  );
}

List<ManeuverDef> _loadManeuvers() {
  final raw = _readRepoFile('assets/catalogs/house_rules_v1/manoever.json');
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .cast<Map<String, dynamic>>()
      .map(ManeuverDef.fromJson)
      .toList(growable: false);
}

List<CombatSpecialAbilityDef> _loadCombatSpecialAbilities() {
  final raw = _readRepoFile(
    'assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json',
  );
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .cast<Map<String, dynamic>>()
      .map(CombatSpecialAbilityDef.fromJson)
      .toList(growable: false);
}

String _readRepoFile(String relativePath) {
  final raw = File(relativePath).readAsStringSync();
  return raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
}
