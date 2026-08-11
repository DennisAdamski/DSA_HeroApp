import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_constants.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';

/// Sichert die katalogisierten Auswahlmoeglichkeiten der mehrfach erwerbbaren
/// magischen Sonderfertigkeiten ab (Wege der Helden S. 286-293).
void main() {
  final abilities = _readMagicSpecialAbilities();

  SpecialAbilityDef byId(String id) =>
      abilities.firstWhere((entry) => entry.id == id);

  /// Alle Ritualgruppen mit Einzelpreisen und ihrer erwarteten Ritualzahl.
  const ritualGruppen = <String, int>{
    'magsf_hexenfluesche': 16,
    'magsf_zaubertaenze': 15,
    'magsf_zibilja_rituale': 14,
    'magsf_kugelzauber': 13,
    'magsf_druidische_dolchrituale': 12,
    'magsf_keulenrituale': 11,
    'magsf_schlangenring_zauber': 11,
    'magsf_stabzauber': 11,
    'magsf_elfenlieder': 10,
    'magsf_bann_und_schutzkreise': 8,
    'magsf_kristallomantische_rituale': 6,
    'magsf_schalenzauber': 6,
    'magsf_druidische_herrschaftsrituale': 5,
    'magsf_oduen_gaben': 5,
    'magsf_trommelzauber': 5,
    'magsf_schuppenbeutel': 3,
    'magsf_geodenrituale': 1,
  };

  test('alle erwarteten magischen SF sind mehrfach waehlbar', () {
    final multi = abilities
        .where((entry) => entry.mehrfachwaehlbar)
        .map((entry) => entry.id)
        .toSet();

    expect(multi, {
      'emsf_merkmalsgrossmeister',
      'emsf_arkane_meisterschaft',
      'emsf_elementaraspekt',
      ...ritualGruppen.keys,
    });
  });

  group('Merkmalsbasierte Sonderfertigkeiten', () {
    test('Merkmalsgroßmeister staffelt 600 / 800 / 1000 AP', () {
      final ability = byId('emsf_merkmalsgrossmeister');

      expect(ability.variantenLabel, 'Merkmal');
      expect(
        ability.variantenGruppen.map((gruppe) => gruppe.ap),
        [600, 800, 1000],
      );
      expect(
        ability.variantenGruppen.map((gruppe) => gruppe.label),
        ['Stufe I', 'Stufe II', 'Stufe III'],
      );
      expect(ability.variantenFreitext, isFalse);
    });

    test('Arkane Meisterschaft staffelt 400 / 550 / 700 AP', () {
      final ability = byId('emsf_arkane_meisterschaft');

      expect(
        ability.variantenGruppen.map((gruppe) => gruppe.ap),
        [400, 550, 700],
      );
    });

    test('beide decken exakt die 34 Katalog-Merkmale ab', () {
      for (final id in ['emsf_merkmalsgrossmeister', 'emsf_arkane_meisterschaft']) {
        final ability = byId(id);
        expect(ability.alleVarianten, hasLength(34), reason: id);
        expect(ability.alleVarianten.toSet(), kMerkmale.toSet(), reason: id);
        expect(
          ability.variantenGruppen.map((gruppe) => gruppe.varianten.length),
          [19, 10, 5],
          reason: id,
        );
      }
    });
  });

  test('Elementaraspekt bietet die sechs Elemente zu je 250 AP', () {
    final ability = byId('emsf_elementaraspekt');

    expect(ability.variantenLabel, 'Element');
    expect(ability.varianten, ['Eis', 'Erz', 'Feuer', 'Humus', 'Luft', 'Wasser']);
    expect(ability.variantenGruppen, isEmpty);
    expect(ability.apErstwerb, 250);
    expect(ability.apFolgeerwerb, 250);
    expect(ability.variantenFreitext, isFalse);
  });

  group('Ritualgruppen mit Einzelpreisen', () {
    test('tragen die erwartete Zahl an Einzelritualen', () {
      for (final entry in ritualGruppen.entries) {
        expect(
          byId(entry.key).alleVarianten,
          hasLength(entry.value),
          reason: entry.key,
        );
      }
    });

    test('jedes Ritual liegt in genau einer Preisgruppe', () {
      for (final id in ritualGruppen.keys) {
        final ability = byId(id);
        expect(ability.varianten, isEmpty, reason: '$id: keine flache Liste');
        expect(ability.variantenGruppen, isNotEmpty, reason: id);

        final alle = <String>[];
        for (final gruppe in ability.variantenGruppen) {
          expect(gruppe.ap, greaterThan(0), reason: '$id / ${gruppe.label}');
          expect(gruppe.varianten, isNotEmpty, reason: '$id / ${gruppe.label}');
          alle.addAll(gruppe.varianten);
        }
        expect(alle.toSet(), hasLength(alle.length), reason: '$id: Duplikate');
      }
    });

    test('Preisgruppen sind aufsteigend sortiert und korrekt benannt', () {
      for (final id in ritualGruppen.keys) {
        final gruppen = byId(id).variantenGruppen;
        final preise = gruppen.map((gruppe) => gruppe.ap).toList();
        final sortiert = List<int>.from(preise)..sort();
        expect(preise, sortiert, reason: id);
        for (final gruppe in gruppen) {
          expect(gruppe.label, '${gruppe.ap} AP', reason: id);
        }
      }
    });

    test('Hexenflüche tragen die Preise aus WdH S. 287', () {
      final ability = byId('magsf_hexenfluesche');
      final preisFuer = <String, int>{
        for (final gruppe in ability.variantenGruppen)
          for (final name in gruppe.varianten) name: gruppe.ap,
      };

      expect(preisFuer['Warzen sprießen'], 50);
      expect(preisFuer['Hexenschuss'], 75);
      expect(preisFuer['Todesfluch'], 100);
      expect(preisFuer['Kornfäule'], 125);
      expect(preisFuer['Hagelschlag'], 150);
    });

    test('Bann- und Schutzkreise unterscheiden Bann- und Schutzform', () {
      final ability = byId('magsf_bann_und_schutzkreise');
      final preisFuer = <String, int>{
        for (final gruppe in ability.variantenGruppen)
          for (final name in gruppe.varianten) name: gruppe.ap,
      };

      expect(preisFuer['Bann- und Schutzkreis gegen Geisterwesen'], 25);
      expect(preisFuer['Bann- und Schutzkreis gegen Niedere Dämonen'], 50);
      expect(preisFuer['Bannkreis gegen Chimären'], 75);
      expect(preisFuer['Schutzkreis gegen Ungeziefer'], 25);
      expect(preisFuer['Schutzkreis gegen Traumgänger'], 50);
    });
  });

  test('Sonderfertigkeiten ohne Auswahl bleiben unveraendert', () {
    for (final id in [
      'magsf_lockeres_zaubern',
      'magsf_kraftlinienmagie_i',
      'magsf_kraftlinienmagie_ii',
      'magsf_vertrautenbindung',
      'magsf_repraesentation',
      'magsf_schamanistische_rituale',
      'magsf_ottagaldr',
    ]) {
      final ability = byId(id);
      expect(ability.mehrfachwaehlbar, isFalse, reason: id);
      expect(ability.alleVarianten, isEmpty, reason: id);
    }
  });
}

List<SpecialAbilityDef> _readMagicSpecialAbilities() {
  final raw = File(
    'assets/catalogs/house_rules_v1/magische_sonderfertigkeiten.json',
  ).readAsStringSync();
  final content = raw.startsWith('﻿') ? raw.substring(1) : raw;
  return (jsonDecode(content) as List)
      .cast<Map>()
      .map((entry) => SpecialAbilityDef.fromJson(entry.cast<String, dynamic>()))
      .toList(growable: false);
}
