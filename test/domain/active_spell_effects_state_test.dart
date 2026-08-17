import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';

void main() {
  final duration = SpellDuration(
    amount: 4,
    remaining: 2,
    unit: SpellDurationUnit.spielrunden,
  );

  group('ActiveSpellEffectsState mit Zusatzdaten', () {
    test('withDetail speichert Wert und Wirkungsdauer eines aktiven Effekts', () {
      final state = const ActiveSpellEffectsState()
          .withToggled('effect_a', true)
          .withDetail(
            'effect_a',
            ActiveSpellEffectDetail(amount: 3, duration: duration),
          );

      expect(state.detailFor('effect_a').amount, 3);
      expect(state.detailFor('effect_a').duration, duration);
    });

    test('Zusatzdaten inaktiver Effekte werden verworfen', () {
      final state = const ActiveSpellEffectsState().withDetail(
        'effect_a',
        const ActiveSpellEffectDetail(amount: 3),
      );

      expect(state.effectDetails, isEmpty);
    });

    test('Deaktivieren entfernt auch die Zusatzdaten', () {
      final active = const ActiveSpellEffectsState()
          .withToggled('effect_a', true)
          .withDetail('effect_a', const ActiveSpellEffectDetail(amount: 3));

      final inactive = active.withToggled('effect_a', false);

      expect(inactive.effectDetails, isEmpty);
      expect(inactive.detailFor('effect_a').amount, 0);
    });

    test('leere Zusatzdaten werden nicht gespeichert', () {
      final state = const ActiveSpellEffectsState()
          .withToggled('effect_a', true)
          .withDetail('effect_a', const ActiveSpellEffectDetail());

      expect(state.effectDetails, isEmpty);
    });

    test('JSON-Roundtrip erhaelt Zusatzdaten', () {
      final state = const ActiveSpellEffectsState()
          .withToggled('effect_a', true)
          .withDetail(
            'effect_a',
            ActiveSpellEffectDetail(amount: 3, duration: duration),
          );

      final restored = ActiveSpellEffectsState.fromJson(state.toJson());

      expect(restored.activeEffectIds, <String>['effect_a']);
      expect(restored.detailFor('effect_a').amount, 3);
      expect(restored.detailFor('effect_a').duration, duration);
    });

    test('alte Staende ohne effectDetails bleiben lesbar', () {
      final restored = ActiveSpellEffectsState.fromJson(<String, dynamic>{
        'activeEffectIds': <String>['effect_a'],
      });

      expect(restored.activeEffectIds, <String>['effect_a']);
      expect(restored.detailFor('effect_a').isEmpty, isTrue);
    });
  });
}
