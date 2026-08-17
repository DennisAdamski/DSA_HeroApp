import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';

void main() {
  group('SpellDuration', () {
    test('ohne Restdauer laeuft die Wirkungsdauer voll', () {
      final duration = SpellDuration(
        amount: 5,
        unit: SpellDurationUnit.kampfrunden,
      );

      expect(duration.remaining, 5);
      expect(duration.isExpired, isFalse);
    });

    test('Restdauer wird auf [0, Gesamtdauer] begrenzt', () {
      final tooHigh = SpellDuration(
        amount: 3,
        remaining: 9,
        unit: SpellDurationUnit.kampfrunden,
      );
      final negative = SpellDuration(
        amount: 3,
        remaining: -4,
        unit: SpellDurationUnit.kampfrunden,
      );

      expect(tooHigh.remaining, 3);
      expect(negative.remaining, 0);
    });

    test('aufgebrauchte Restdauer gilt als abgelaufen', () {
      final duration = SpellDuration(
        amount: 2,
        remaining: 0,
        unit: SpellDurationUnit.spielrunden,
      );

      expect(duration.isExpired, isTrue);
    });

    test('permanente Wirkungsdauern laufen nie ab', () {
      final duration = SpellDuration(
        amount: 1,
        remaining: 0,
        unit: SpellDurationUnit.permanent,
      );

      expect(duration.isPermanent, isTrue);
      expect(duration.isExpired, isFalse);
    });

    test('JSON-Roundtrip erhaelt Menge, Restdauer und Einheit', () {
      final duration = SpellDuration(
        amount: 7,
        remaining: 3,
        unit: SpellDurationUnit.stunden,
      );

      final restored = SpellDuration.fromJson(duration.toJson());

      expect(restored, duration);
      expect(restored.unit, SpellDurationUnit.stunden);
    });

    test('unbekannte Einheit faellt auf Kampfrunden zurueck', () {
      final restored = SpellDuration.fromJson(<String, dynamic>{
        'amount': 2,
        'unit': 'monde',
      });

      expect(restored.unit, SpellDurationUnit.kampfrunden);
      expect(restored.remaining, 2);
    });

    test('copyWith mit neuer Gesamtdauer setzt die Restdauer zurueck', () {
      final duration = SpellDuration(
        amount: 5,
        remaining: 1,
        unit: SpellDurationUnit.kampfrunden,
      );

      final extended = duration.copyWith(amount: 8);

      expect(extended.amount, 8);
      expect(extended.remaining, 8);
    });
  });
}
