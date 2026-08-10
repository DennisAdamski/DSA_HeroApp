import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';

/// Sichert die katalogisierten Auswahlmoeglichkeiten der mehrfach erwerbbaren
/// allgemeinen Sonderfertigkeiten ab (Quellen: Wege der Helden S. 276-278,
/// Wege des Schwerts S. 42-43).
void main() {
  final abilities = _readGeneralSpecialAbilities();

  SpecialAbilityDef byId(String id) =>
      abilities.firstWhere((entry) => entry.id == id);

  test('exactly the five choice-based abilities are marked multi-select', () {
    final multi = abilities
        .where((entry) => entry.mehrfachwaehlbar)
        .map((entry) => entry.id)
        .toSet();

    expect(multi, {
      'asf_akklimatisierung',
      'asf_berufsgeheimnis',
      'asf_kulturkunde',
      'asf_gelaendekunde',
      'asf_ortskenntnis',
    });
  });

  test('Kulturkunde lists the 41 selectable cultures', () {
    final ability = byId('asf_kulturkunde');

    expect(ability.variantenLabel, 'Kultur');
    expect(ability.varianten, hasLength(41));
    expect(ability.varianten, contains('Novadi'));
    expect(ability.varianten, contains('Grolme'));
    // Neue Kulturen koennen entdeckt werden (WdS S. 43).
    expect(ability.variantenFreitext, isTrue);
    expect(ability.apErstwerb, 150);
    expect(ability.apFolgeerwerb, 150);
  });

  test('Geländekunde lists the ten terrain types with staggered costs', () {
    final ability = byId('asf_gelaendekunde');

    expect(ability.variantenLabel, 'Gelände');
    expect(ability.varianten, hasLength(10));
    expect(ability.varianten.first, 'Dschungelkundig');
    expect(ability.varianten.last, 'Wüstenkundig');
    // Die Liste ist im Regelwerk abschliessend.
    expect(ability.variantenFreitext, isFalse);
    expect(ability.apErstwerb, 150);
    expect(ability.apFolgeerwerb, 100);
  });

  test('Ortskenntnis has no fixed list and stays free text', () {
    final ability = byId('asf_ortskenntnis');

    expect(ability.variantenLabel, 'Ort / Strecke');
    expect(ability.varianten, isEmpty);
    expect(ability.variantenFreitext, isTrue);
    expect(ability.apErstwerb, 150);
    expect(ability.apFolgeerwerb, 100);
  });

  test('Akklimatisierung offers exactly heat and cold', () {
    final ability = byId('asf_akklimatisierung');

    expect(ability.variantenLabel, 'Klima');
    expect(ability.varianten, ['Hitze', 'Kälte']);
    expect(ability.variantenFreitext, isFalse);
    expect(ability.apErstwerb, 150);
    expect(ability.apFolgeerwerb, 150);
  });

  test('Berufsgeheimnis lists the 16 documented secrets and allows more', () {
    final ability = byId('asf_berufsgeheimnis');

    expect(ability.variantenLabel, 'Geheimwissen');
    expect(ability.varianten, hasLength(16));
    expect(ability.varianten, contains('Zwergenspan'));
    expect(ability.varianten, contains('Hylailer Feuer'));
    // Die Regelwerksliste ist ausdruecklich unvollstaendig.
    expect(ability.variantenFreitext, isTrue);
    expect(ability.apErstwerb, 100);
    expect(ability.apFolgeerwerb, 100);
  });

  test('single-choice abilities remain untouched', () {
    final ability = byId('asf_standfest');

    expect(ability.mehrfachwaehlbar, isFalse);
    expect(ability.varianten, isEmpty);
    expect(ability.apErstwerb, isNull);
  });
}

List<SpecialAbilityDef> _readGeneralSpecialAbilities() {
  final raw = File(
    'assets/catalogs/house_rules_v1/allgemeine_sonderfertigkeiten.json',
  ).readAsStringSync();
  final content = raw.startsWith('﻿') ? raw.substring(1) : raw;
  return (jsonDecode(content) as List)
      .cast<Map>()
      .map((entry) => SpecialAbilityDef.fromJson(entry.cast<String, dynamic>()))
      .toList(growable: false);
}
