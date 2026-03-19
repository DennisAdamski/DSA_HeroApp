import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';

void main() {
  HeroSheet buildHero({
    String rasseModText = '',
    String kulturModText = '',
    String professionModText = '',
    String vorteileText = '',
    String nachteileText = '',
  }) {
    return HeroSheet(
      id: 'hero',
      name: 'Test',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      background: HeroBackground(
        rasseModText: rasseModText,
        kulturModText: kulturModText,
        professionModText: professionModText,
      ),
      vorteileText: vorteileText,
      nachteileText: nachteileText,
    );
  }

  test('auto activation enables magic for AE and AsP modifiers', () {
    final heroAe = buildHero(vorteileText: 'AE+3');
    final heroAsp = buildHero(professionModText: 'AsP-1');

    expect(computeHeroResourceActivation(heroAe).magic.autoEnabled, isTrue);
    expect(computeHeroResourceActivation(heroAsp).magic.autoEnabled, isTrue);
  });

  test('auto activation enables divine for KE and KaP modifiers', () {
    final heroKe = buildHero(rasseModText: 'KE+2');
    final heroKap = buildHero(kulturModText: 'KaP-1');

    expect(computeHeroResourceActivation(heroKe).divine.autoEnabled, isTrue);
    expect(computeHeroResourceActivation(heroKap).divine.autoEnabled, isTrue);
  });

  test('auto activation ignores missing modifiers and Nachteile', () {
    final mundaneHero = buildHero();
    final heroWithDisadvantage = buildHero(nachteileText: 'AE+4, KE+3');

    final mundaneActivation = computeHeroResourceActivation(mundaneHero);
    final disadvantageActivation = computeHeroResourceActivation(
      heroWithDisadvantage,
    );

    expect(mundaneActivation.magic.autoEnabled, isFalse);
    expect(mundaneActivation.divine.autoEnabled, isFalse);
    expect(disadvantageActivation.magic.autoEnabled, isFalse);
    expect(disadvantageActivation.divine.autoEnabled, isFalse);
  });

  test('manual overrides win over automatic activation', () {
    final hero = buildHero(vorteileText: 'AE+3').copyWith(
      resourceActivationConfig: const HeroResourceActivationConfig(
        magicEnabledOverride: false,
        divineEnabledOverride: true,
      ),
    );

    final activation = computeHeroResourceActivation(hero);

    expect(activation.magic.autoEnabled, isTrue);
    expect(activation.magic.isEnabled, isFalse);
    expect(activation.magic.hasManualOverride, isTrue);
    expect(activation.divine.autoEnabled, isFalse);
    expect(activation.divine.isEnabled, isTrue);
    expect(activation.divine.hasManualOverride, isTrue);
  });
}
