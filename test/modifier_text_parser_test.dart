import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';

void main() {
  test('parses known tokens and aliases', () {
    final parsed = parseModifierTexts(
      rasseModText: 'AE+2, MU-1',
      kulturModText: 'LE+1',
      professionModText: 'GS+1; AW+2',
      vorteileText: 'KL+1',
      nachteileText: '',
    );

    expect(parsed.statMods.asp, 2);
    expect(parsed.statMods.lep, 1);
    expect(parsed.statMods.gs, 1);
    expect(parsed.statMods.ausweichen, 2);
    expect(parsed.attributeMods.mu, -1);
    expect(parsed.attributeMods.kl, 1);
    expect(parsed.unknownFragments, isEmpty);
  });

  test('collects unknown tokens', () {
    final parsed = parseModifierTexts(
      rasseModText: 'ABC+2',
      kulturModText: 'invalid text',
      professionModText: '',
      vorteileText: 'MU+1',
      nachteileText: 'XYZ-4',
    );

    expect(parsed.attributeMods.mu, 1);
    expect(parsed.unknownFragments, contains('ABC+2'));
    expect(parsed.unknownFragments, contains('invalid text'));
    expect(parsed.unknownFragments, contains('XYZ-4'));
  });
}
