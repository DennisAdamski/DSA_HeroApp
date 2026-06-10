import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_assignment.dart';
import 'package:dsa_heldenverwaltung/domain/json_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('readJsonInt', () {
    test('liest int-Werte direkt', () {
      expect(readJsonInt(<String, dynamic>{'a': 7}, 'a'), 7);
    });

    test('konvertiert double-Werte mit toInt', () {
      expect(readJsonInt(<String, dynamic>{'a': 3.7}, 'a'), 3);
    });

    test('liefert Fallback 0 fuer fehlende Schluessel und null', () {
      expect(readJsonInt(<String, dynamic>{}, 'a'), 0);
      expect(readJsonInt(<String, dynamic>{'a': null}, 'a'), 0);
    });

    test('liefert expliziten Fallback', () {
      expect(readJsonInt(<String, dynamic>{}, 'a', fallback: -1), -1);
    });

    test('wirft bei Nicht-num-Werten', () {
      expect(
        () => readJsonInt(<String, dynamic>{'a': 'x'}, 'a'),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('readJsonString', () {
    test('liest String-Werte direkt', () {
      expect(readJsonString(<String, dynamic>{'a': 'hi'}, 'a'), 'hi');
    });

    test('liefert Fallback fuer fehlende Schluessel und null', () {
      expect(readJsonString(<String, dynamic>{}, 'a'), '');
      expect(
        readJsonString(<String, dynamic>{'a': null}, 'a', fallback: 'x'),
        'x',
      );
    });

    test('wirft bei Nicht-String-Werten', () {
      expect(
        () => readJsonString(<String, dynamic>{'a': 5}, 'a'),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('readJsonBool', () {
    test('liest bool-Werte direkt', () {
      expect(readJsonBool(<String, dynamic>{'a': true}, 'a'), isTrue);
    });

    test('liefert Fallback fuer fehlende Schluessel und null', () {
      expect(readJsonBool(<String, dynamic>{}, 'a'), isFalse);
      expect(
        readJsonBool(<String, dynamic>{'a': null}, 'a', fallback: true),
        isTrue,
      );
    });

    test('wirft bei Nicht-bool-Werten', () {
      expect(
        () => readJsonBool(<String, dynamic>{'a': 1}, 'a'),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('OffhandAssignment.fromJson', () {
    test('leeres Map ergibt isNone (Fallback -1 bleibt erhalten)', () {
      final assignment = OffhandAssignment.fromJson(<String, dynamic>{});
      expect(assignment.weaponIndex, -1);
      expect(assignment.equipmentIndex, -1);
      expect(assignment.isNone, isTrue);
      expect(assignment.usesWeapon, isFalse);
      expect(assignment.usesEquipment, isFalse);
    });
  });
}
