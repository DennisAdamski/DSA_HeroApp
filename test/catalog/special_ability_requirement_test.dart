import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';

void main() {
  group('SpecialAbilityRequirement.fromJson', () {
    test('liest eine Eigenschaftsbedingung', () {
      final requirement = SpecialAbilityRequirement.fromJson(<String, dynamic>{
        'art': 'eigenschaft',
        'code': 'MU',
        'min': 15,
      });

      expect(requirement.art, RequirementArt.eigenschaft);
      expect(requirement.code, 'MU');
      expect(requirement.min, 15);
    });

    test('liest eine Sonderfertigkeit mit Stufe', () {
      final requirement = SpecialAbilityRequirement.fromJson(<String, dynamic>{
        'art': 'sonderfertigkeit',
        'name': 'Eiserner Wille',
        'stufe': 1,
      });

      expect(requirement.art, RequirementArt.sonderfertigkeit);
      expect(requirement.name, 'Eiserner Wille');
      expect(requirement.stufe, 1);
    });

    test('liest eine Oder-Gruppe rekursiv', () {
      final requirement = SpecialAbilityRequirement.fromJson(<String, dynamic>{
        'art': 'oder',
        'bedingungen': [
          {'art': 'eigenschaft', 'code': 'KL', 'min': 20},
          {'art': 'eigenschaft', 'code': 'IN', 'min': 20},
        ],
      });

      expect(requirement.art, RequirementArt.oderGruppe);
      expect(requirement.bedingungen, hasLength(2));
      expect(requirement.bedingungen.first.code, 'KL');
      expect(requirement.bedingungen.last.code, 'IN');
    });

    test('liest eine Traditionsbedingung mit mehreren Namen', () {
      final requirement = SpecialAbilityRequirement.fromJson(<String, dynamic>{
        'art': 'tradition',
        'namen': ['Druide', 'Geode'],
      });

      expect(requirement.art, RequirementArt.tradition);
      expect(requirement.namen, ['Druide', 'Geode']);
    });

    test('unbekannte Arten werden als solche markiert statt zu werfen', () {
      final requirement = SpecialAbilityRequirement.fromJson(<String, dynamic>{
        'art': 'kompletter_unsinn',
        'text': 'Irgendetwas',
      });

      expect(requirement.art, RequirementArt.unbekannt);
      expect(requirement.text, 'Irgendetwas');
    });

    test('serialisiert verlustfrei zurueck nach JSON', () {
      const original = SpecialAbilityRequirement(
        art: RequirementArt.oderGruppe,
        bedingungen: [
          SpecialAbilityRequirement(
            art: RequirementArt.zauber,
            name: 'ARCANOVI',
            min: 14,
          ),
          SpecialAbilityRequirement(
            art: RequirementArt.hinweis,
            text: 'Zugang zu den genannten Buechern',
          ),
        ],
      );

      final roundTrip = SpecialAbilityRequirement.fromJson(original.toJson());

      expect(roundTrip.art, RequirementArt.oderGruppe);
      expect(roundTrip.bedingungen.first.name, 'ARCANOVI');
      expect(roundTrip.bedingungen.first.min, 14);
      expect(
        roundTrip.bedingungen.last.text,
        'Zugang zu den genannten Buechern',
      );
    });
  });

  group('SpecialAbilityChainRef', () {
    test('liest Kette aus JSON', () {
      final kette = SpecialAbilityChainRef.fromJson(<String, dynamic>{
        'id': 'eiserner_wille',
        'stufe': 2,
        'label': 'Eiserner Wille',
      });

      expect(kette.id, 'eiserner_wille');
      expect(kette.stufe, 2);
      expect(kette.label, 'Eiserner Wille');
    });

    test('faellt ohne Stufe auf 1 zurueck', () {
      final kette = SpecialAbilityChainRef.fromJson(<String, dynamic>{
        'id': 'eiserner_wille',
      });

      expect(kette.stufe, 1);
    });
  });

  group('SpecialAbilityDef mit Voraussetzungen und Kette', () {
    test('liest die neuen Felder aus JSON', () {
      final def = SpecialAbilityDef.fromJson(<String, dynamic>{
        'id': 'magsf_eiserner_wille_ii',
        'name': 'Eiserner Wille II',
        'voraussetzungen': 'MU 13, IN 12; SF Eiserner Wille I',
        'voraussetzungen_struktur': [
          {'art': 'eigenschaft', 'code': 'MU', 'min': 13},
          {'art': 'sonderfertigkeit', 'name': 'Eiserner Wille', 'stufe': 1},
        ],
        'kette': {'id': 'eiserner_wille', 'stufe': 2},
        'alias_namen': ['Eiserner Wille I / II'],
      });

      expect(def.voraussetzungenStruktur, hasLength(2));
      expect(def.voraussetzungenStruktur.first.code, 'MU');
      expect(def.kette?.id, 'eiserner_wille');
      expect(def.kette?.stufe, 2);
      expect(def.aliasNamen, ['Eiserner Wille I / II']);
      expect(def.nurInformation, isFalse);
    });

    test('bleibt ohne die neuen Felder unveraendert lesbar', () {
      final def = SpecialAbilityDef.fromJson(<String, dynamic>{
        'id': 'magsf_apport',
        'name': 'Apport (OR)*',
      });

      expect(def.voraussetzungenStruktur, isEmpty);
      expect(def.kette, isNull);
      expect(def.aliasNamen, isEmpty);
      expect(def.nurInformation, isFalse);
    });

    test('serialisiert die neuen Felder nur, wenn sie gesetzt sind', () {
      const schlicht = SpecialAbilityDef(id: 'x', name: 'X');

      final json = schlicht.toJson();

      expect(json.containsKey('voraussetzungen_struktur'), isFalse);
      expect(json.containsKey('kette'), isFalse);
      expect(json.containsKey('alias_namen'), isFalse);
      expect(json.containsKey('nur_information'), isFalse);
    });

    test('alleNamen enthaelt Anzeigename und Alias-Namen', () {
      const def = SpecialAbilityDef(
        id: 'magsf_eiserner_wille_i',
        name: 'Eiserner Wille I',
        aliasNamen: ['Eiserner Wille I / II'],
      );

      expect(def.alleNamen, ['Eiserner Wille I', 'Eiserner Wille I / II']);
    });
  });
}
