import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';

void main() {
  test('computes effective start attributes from origin modifiers only', () {
    const hero = HeroSheet(
      id: 'h1',
      name: 'Test',
      level: 1,
      rawStartAttributes: Attributes(
        mu: 12,
        kl: 13,
        inn: 11,
        ch: 10,
        ff: 9,
        ge: 8,
        ko: 7,
        kk: 6,
      ),
      attributes: Attributes(
        mu: 12,
        kl: 13,
        inn: 11,
        ch: 10,
        ff: 9,
        ge: 8,
        ko: 7,
        kk: 6,
      ),
      rasseModText: 'KL+1, MU+1',
      kulturModText: 'IN+2',
      professionModText: 'CH+3',
      vorteileText: 'KK+5',
      nachteileText: 'GE-3',
    );

    final originMods = parseOriginAttributeModifiers(hero);
    final effectiveStart = computeEffectiveStartAttributes(
      hero.rawStartAttributes,
      originMods,
    );

    expect(effectiveStart.mu, 13);
    expect(effectiveStart.kl, 14);
    expect(effectiveStart.inn, 13);
    expect(effectiveStart.ch, 13);
    expect(effectiveStart.kk, 6);
    expect(effectiveStart.ge, 8);
  });

  test('computes attribute maximums with ceiling rounding', () {
    const effectiveStart = Attributes(
      mu: 14,
      kl: 13,
      inn: 12,
      ch: 11,
      ff: 10,
      ge: 9,
      ko: 8,
      kk: 7,
    );

    final maximums = computeAttributeMaximums(effectiveStart);

    expect(maximums.mu, 21);
    expect(maximums.kl, 20);
    expect(maximums.inn, 18);
    expect(maximums.ch, 17);
  });
}
