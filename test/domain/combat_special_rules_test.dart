import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/combat_special_rules.dart';

void main() {
  group('CombatSpecialRules.fromJson Migration', () {
    test('migriert schnellladenBogen-Boolean zu activeManeuvers', () {
      final json = <String, dynamic>{
        'schnellladenBogen': true,
        'schnellladenArmbrust': false,
        'activeManeuvers': <dynamic>[],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(rules.activeManeuvers, contains('man_schnellladen_bogen'));
      expect(
        rules.activeManeuvers,
        isNot(contains('man_schnellladen_armbrust')),
      );
    });

    test('migriert schnellladenArmbrust-Boolean zu activeManeuvers', () {
      final json = <String, dynamic>{
        'schnellladenBogen': false,
        'schnellladenArmbrust': true,
        'activeManeuvers': <dynamic>[],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(
        rules.activeManeuvers,
        isNot(contains('man_schnellladen_bogen')),
      );
      expect(rules.activeManeuvers, contains('man_schnellladen_armbrust'));
    });

    test('dupliziert man_schnellladen_bogen nicht wenn bereits vorhanden', () {
      final json = <String, dynamic>{
        'schnellladenBogen': true,
        'activeManeuvers': <dynamic>['man_schnellladen_bogen'],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(
        rules.activeManeuvers
            .where((e) => e == 'man_schnellladen_bogen')
            .length,
        1,
      );
    });

    test('keine Migration wenn beide Booleans false', () {
      final json = <String, dynamic>{
        'schnellladenBogen': false,
        'schnellladenArmbrust': false,
        'activeManeuvers': <dynamic>['man_ausfall'],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(rules.activeManeuvers, equals(['man_ausfall']));
    });

    test('Fehlende Legacy-Felder ergeben keine Migration', () {
      final json = <String, dynamic>{
        'activeManeuvers': <dynamic>['man_ausfall'],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(rules.activeManeuvers, equals(['man_ausfall']));
    });
  });
}
