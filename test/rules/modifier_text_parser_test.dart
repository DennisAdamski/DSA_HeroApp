import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
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

  test('detects Flink and Behaebig from vorteile/nachteile tokens', () {
    final parsed = parseModifierTexts(
      rasseModText: '',
      kulturModText: '',
      professionModText: '',
      vorteileText: 'Flink, KL+1',
      nachteileText: 'behaebig',
    );

    expect(parsed.hasFlinkFromVorteile, isTrue);
    expect(parsed.hasBehaebigFromNachteile, isTrue);
  });

  test('named token detection is case-insensitive and token-based', () {
    final parsed = parseModifierTexts(
      rasseModText: '',
      kulturModText: '',
      professionModText: '',
      vorteileText: 'FLINK',
      nachteileText: 'unbehaebigkeit',
    );

    expect(parsed.hasFlinkFromVorteile, isTrue);
    expect(parsed.hasBehaebigFromNachteile, isFalse);
  });

  test('computes effective attributes from all modifier text fields', () {
    const hero = HeroSheet(
      id: 'h-1',
      name: 'Test',
      level: 1,
      attributes: Attributes(
        mu: 10,
        kl: 10,
        inn: 10,
        ch: 10,
        ff: 10,
        ge: 10,
        ko: 10,
        kk: 10,
      ),
      background: HeroBackground(
        rasseModText: 'MU+1, KL-1',
        kulturModText: 'IN+2',
        professionModText: 'CH+3',
      ),
      vorteileText: 'FF+4',
      nachteileText: 'KO-2, KK+5',
    );

    final effective = computeEffectiveAttributes(hero);

    expect(effective.mu, 11);
    expect(effective.kl, 9);
    expect(effective.inn, 12);
    expect(effective.ch, 13);
    expect(effective.ff, 14);
    expect(effective.ge, 10);
    expect(effective.ko, 8);
    expect(effective.kk, 15);
  });
}
