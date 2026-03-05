import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';

void main() {
  test('computeLevelFromSpentAp handles boundaries and negatives', () {
    expect(computeLevelFromSpentAp(-1), 1);
    expect(computeLevelFromSpentAp(0), 1);
    expect(computeLevelFromSpentAp(50), 1);
    expect(computeLevelFromSpentAp(99), 1);
    expect(computeLevelFromSpentAp(100), 2);
    expect(computeLevelFromSpentAp(150), 2);
    expect(computeLevelFromSpentAp(2571), 7);
    expect(computeLevelFromSpentAp(2799), 7);
    expect(computeLevelFromSpentAp(2800), 8);
    expect(computeLevelFromSpentAp(5000), greaterThan(1));
  });

  test('computeAvailableAp handles normal and overspent values', () {
    expect(computeAvailableAp(100, 20), 80);
    expect(computeAvailableAp(100, 200), 0);
    expect(computeAvailableAp(-5, 10), 0);
  });
}
