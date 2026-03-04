import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';

void main() {
  test('x-rule multiplies BE and applies negative eBE', () {
    final result = computeTalentEbe(baseBe: 3, talentBeRule: 'x2');
    expect(result, -6);
  });

  test('minus-rule subtracts offset from BE before penalty', () {
    final result = computeTalentEbe(baseBe: 5, talentBeRule: '-3');
    expect(result, -2);
  });

  test('minus-rule never increases TaW when offset exceeds BE', () {
    final result = computeTalentEbe(baseBe: 2, talentBeRule: '-3');
    expect(result, 0);
  });

  test('unknown and legacy tokens map to zero', () {
    expect(computeTalentEbe(baseBe: 4, talentBeRule: 'spez.'), 0);
    expect(computeTalentEbe(baseBe: 4, talentBeRule: '-'), 0);
    expect(computeTalentEbe(baseBe: 4, talentBeRule: ''), 0);
  });

  test('parser is robust for case and whitespace', () {
    expect(computeTalentEbe(baseBe: 3, talentBeRule: 'X 2'), -6);
    expect(computeTalentEbe(baseBe: 5, talentBeRule: ' - 3 '), -2);
  });
}
