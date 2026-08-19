import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_duration_rules.dart';

void main() {
  group('Wirkungsdauer-Beschreibung', () {
    test('ohne Wirkungsdauer bleibt der Hinweis neutral', () {
      expect(describeSpellDuration(null), 'Wirkungsdauer offen');
      expect(describeSpellDurationCompact(null), isNull);
    });

    test('laufende Wirkungsdauer nennt Rest und Gesamtdauer', () {
      final duration = SpellDuration(
        amount: 5,
        remaining: 3,
        unit: SpellDurationUnit.kampfrunden,
      );

      expect(describeSpellDuration(duration), 'noch 3 von 5 Kampfrunden');
      expect(describeSpellDurationCompact(duration), 'noch 3 KR');
    });

    test('Singular wird korrekt gebildet', () {
      final duration = SpellDuration(
        amount: 1,
        unit: SpellDurationUnit.spielrunden,
      );

      expect(describeSpellDuration(duration), 'noch 1 von 1 Spielrunde');
    });

    test('abgelaufene Wirkungsdauer wird als solche gemeldet', () {
      final duration = SpellDuration(
        amount: 2,
        remaining: 0,
        unit: SpellDurationUnit.spielrunden,
      );

      expect(describeSpellDuration(duration), 'abgelaufen (2 Spielrunden)');
      expect(describeSpellDurationCompact(duration), 'abgelaufen');
    });

    test('permanente Wirkungsdauer kennt keinen Rest', () {
      final duration = SpellDuration(
        amount: 1,
        unit: SpellDurationUnit.permanent,
      );

      expect(describeSpellDuration(duration), 'Wirkungsdauer permanent');
      expect(describeSpellDurationCompact(duration), 'permanent');
    });
  });

  group('Countdown', () {
    test('advance zieht eine Einheit ab und stoppt bei null', () {
      var duration = SpellDuration(
        amount: 2,
        unit: SpellDurationUnit.kampfrunden,
      );

      duration = advanceSpellDuration(duration);
      expect(duration.remaining, 1);

      duration = advanceSpellDuration(duration, steps: 5);
      expect(duration.remaining, 0);
      expect(duration.isExpired, isTrue);
    });

    test('permanente Wirkungsdauer bleibt unveraendert', () {
      final duration = SpellDuration(
        amount: 3,
        unit: SpellDurationUnit.permanent,
      );

      expect(advanceSpellDuration(duration), duration);
    });

    test('reset stellt die volle Wirkungsdauer wieder her', () {
      final duration = SpellDuration(
        amount: 4,
        remaining: 1,
        unit: SpellDurationUnit.minuten,
      );

      expect(resetSpellDuration(duration).remaining, 4);
    });
  });
}
