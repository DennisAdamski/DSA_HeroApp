import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
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
      background: HeroBackground(
        rasseModText: 'KL+1, MU+1',
        kulturModText: 'IN+2',
        professionModText: 'CH+3',
      ),
      vorteileText: 'KK+5',
      nachteileText: 'GE-3',
    );

    final effectiveStart = computeHeroEffectiveStartAttributes(hero);

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

  test('Herausragende Eigenschaft hebt Startwert und Maximum', () {
    const hero = HeroSheet(
      id: 'h2',
      name: 'Test',
      level: 1,
      rawStartAttributes: Attributes(
        mu: 11,
        kl: 11,
        inn: 11,
        ch: 11,
        ff: 11,
        ge: 11,
        ko: 11,
        kk: 14,
      ),
      attributes: Attributes(
        mu: 11,
        kl: 11,
        inn: 11,
        ch: 11,
        ff: 11,
        ge: 11,
        ko: 11,
        kk: 14,
      ),
      vorteileText: 'Herausragende Eigenschaft KK 2',
    );

    expect(computeHeroEffectiveStartAttributes(hero).kk, 16);
    expect(computeHeroAttributeMaximums(hero).kk, 24);
  });

  test('Rassenbonus addiert sich nach dem Vorteil zum selben Startwert', () {
    // Buchbeispiel Wege der Helden S. 253: Thorwaler mit KK 16 plus
    // Rassenbonus KK +1 startet mit 17 und darf bis 26 steigern.
    const hero = HeroSheet(
      id: 'h3',
      name: 'Thorwaler',
      level: 1,
      rawStartAttributes: Attributes(
        mu: 11,
        kl: 11,
        inn: 11,
        ch: 11,
        ff: 11,
        ge: 11,
        ko: 11,
        kk: 14,
      ),
      attributes: Attributes(
        mu: 11,
        kl: 11,
        inn: 11,
        ch: 11,
        ff: 11,
        ge: 11,
        ko: 11,
        kk: 14,
      ),
      background: HeroBackground(rasseModText: 'KK+1'),
      vorteileText: 'Herausragende Eigenschaft KK 2',
    );

    expect(computeHeroEffectiveStartAttributes(hero).kk, 17);
    expect(computeHeroAttributeMaximums(hero).kk, 26);
  });

  test('computeHeroEffectiveStartAttributes ignoriert startAttributes', () {
    // Regressionsschutz: startAttributes traegt bereits das Ergebnis der
    // Rechnung. Wer es als Basis nimmt, addiert die Herkunftsmods doppelt.
    const base = Attributes(
      mu: 11,
      kl: 11,
      inn: 11,
      ch: 11,
      ff: 11,
      ge: 11,
      ko: 11,
      kk: 14,
    );
    const hero = HeroSheet(
      id: 'h4',
      name: 'Test',
      level: 1,
      rawStartAttributes: base,
      startAttributes: Attributes(
        mu: 11,
        kl: 11,
        inn: 11,
        ch: 11,
        ff: 11,
        ge: 11,
        ko: 11,
        kk: 15,
      ),
      attributes: base,
      background: HeroBackground(rasseModText: 'KK+1'),
    );

    expect(computeHeroEffectiveStartAttributes(hero).kk, 15);
    expect(computeHeroAttributeMaximums(hero).kk, 23);
  });

  test('computeHeroAttributeMaximums beruecksichtigt den epischen Bonus', () {
    const base = Attributes(
      mu: 14,
      kl: 11,
      inn: 11,
      ch: 11,
      ff: 11,
      ge: 11,
      ko: 11,
      kk: 11,
    );
    const hero = HeroSheet(
      id: 'h5',
      name: 'Test',
      level: 25,
      rawStartAttributes: base,
      attributes: base,
      epicAttributeMaxBonus: Attributes(
        mu: 2,
        kl: 0,
        inn: 0,
        ch: 0,
        ff: 0,
        ge: 0,
        ko: 0,
        kk: 0,
      ),
    );

    expect(computeHeroAttributeMaximums(hero).mu, 23);
  });

  group('pendingAttributeTraitNotices', () {
    const base = Attributes(
      mu: 11,
      kl: 11,
      inn: 11,
      ch: 11,
      ff: 11,
      ge: 11,
      ko: 11,
      kk: 14,
    );

    test('meldet den neu wirksamen Bonus fuer Bestandshelden', () {
      const hero = HeroSheet(
        id: 'alt',
        name: 'Bestand',
        level: 1,
        schemaVersion: 27,
        rawStartAttributes: base,
        attributes: base,
        vorteileText: 'Herausragende Eigenschaft KK 2',
      );

      expect(pendingAttributeTraitNotices(hero), <String>['KK +2']);
    });

    test('schweigt nach der Quittierung', () {
      const hero = HeroSheet(
        id: 'neu',
        name: 'Quittiert',
        level: 1,
        schemaVersion: kAttributeTraitEffectSchemaVersion,
        rawStartAttributes: base,
        attributes: base,
        vorteileText: 'Herausragende Eigenschaft KK 2',
      );

      expect(pendingAttributeTraitNotices(hero), isEmpty);
    });

    test('schweigt ohne betroffenen Vorteil', () {
      const hero = HeroSheet(
        id: 'ohne',
        name: 'Ohne',
        level: 1,
        schemaVersion: 27,
        rawStartAttributes: base,
        attributes: base,
        background: HeroBackground(rasseModText: 'KK+1'),
        vorteileText: 'Flink',
      );

      expect(pendingAttributeTraitNotices(hero), isEmpty);
    });
  });
}
