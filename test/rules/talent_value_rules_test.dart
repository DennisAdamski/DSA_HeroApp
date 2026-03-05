import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_value_rules.dart';

void main() {
  test('non-combat talents use BE (Kampf) for eBE and computed TaW', () {
    final ebe = computeTalentEbe(baseBe: 4, talentBeRule: 'x2');
    final computed = computeTalentComputedTaw(
      talentValue: 7,
      modifier: 1,
      ebe: ebe,
    );

    expect(ebe, -8);
    expect(computed, 0);
  });

  test('temporary BE override updates eBE and computed TaW', () {
    final ebe = computeTalentEbe(baseBe: 1, talentBeRule: 'x2');
    final computed = computeTalentComputedTaw(
      talentValue: 7,
      modifier: 1,
      ebe: ebe,
    );

    expect(ebe, -2);
    expect(computed, 6);
  });

  test('clearing temporary BE override falls back to BE (Kampf)', () {
    final overrideEbe = computeTalentEbe(baseBe: 1, talentBeRule: 'x2');
    final fallbackEbe = computeTalentEbe(baseBe: 4, talentBeRule: 'x2');

    final overrideComputed = computeTalentComputedTaw(
      talentValue: 7,
      modifier: 1,
      ebe: overrideEbe,
    );
    final fallbackComputed = computeTalentComputedTaw(
      talentValue: 7,
      modifier: 1,
      ebe: fallbackEbe,
    );

    expect(overrideEbe, -2);
    expect(fallbackEbe, -8);
    expect(overrideComputed, 6);
    expect(fallbackComputed, 0);
  });
}
