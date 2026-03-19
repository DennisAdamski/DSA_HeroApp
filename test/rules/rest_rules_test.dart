import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';

void main() {
  HeroSheet buildHero({
    String vorteileText = '',
    String nachteileText = '',
    List<TalentSpecialAbility> talentSpecialAbilities =
        const <TalentSpecialAbility>[],
    List<MagicSpecialAbility> magicSpecialAbilities =
        const <MagicSpecialAbility>[],
    String magicLeadAttribute = '',
  }) {
    return HeroSheet(
      id: 'rest',
      name: 'Rast',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 15,
        inn: 14,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 13,
        kk: 12,
      ),
      vorteileText: vorteileText,
      nachteileText: nachteileText,
      talentSpecialAbilities: talentSpecialAbilities,
      magicSpecialAbilities: magicSpecialAbilities,
      magicLeadAttribute: magicLeadAttribute,
    );
  }

  test('collectRestAbilities reads advantages, disadvantages and sf levels', () {
    final hero = buildHero(
      vorteileText: 'Schnelle Heilung II, Astrale Regeneration III',
      nachteileText: 'Schlechte Regeneration, Astraler Block',
      talentSpecialAbilities: const <TalentSpecialAbility>[
        TalentSpecialAbility(name: 'Regeneration II'),
      ],
      magicSpecialAbilities: const <MagicSpecialAbility>[
        MagicSpecialAbility(name: 'Meisterliche Regeneration'),
      ],
    );

    final abilities = collectRestAbilities(hero);

    expect(abilities.fastHealingLevel, 2);
    expect(abilities.astralRegenerationLevel, 3);
    expect(abilities.hasPoorRegeneration, isTrue);
    expect(abilities.hasAstralBlock, isTrue);
    expect(abilities.talentRegenerationLevel, 2);
    expect(abilities.hasMasterfulRegeneration, isTrue);
  });

  test('computeRestAuRecovery adds KO bonus and clamps to max', () {
    final result = computeRestAuRecovery(
      currentAu: 10,
      maxAu: 20,
      baseRoll: 12,
      koProbeSucceeded: true,
    );

    expect(result.baseRoll, 12);
    expect(result.koBonusApplied, isTrue);
    expect(result.recovered, 10);
  });

  test('condition recovery removes ueberanstrengung before erschöpfung', () {
    final result = computeConditionRecovery(
      currentUeberanstrengung: 3,
      currentErschoepfung: 8,
      hours: 2,
      mode: RestConditionMode.schlaf,
    );

    expect(result.reducedUeberanstrengung, 3);
    expect(result.reducedErschoepfung, 0);
    expect(result.remainingUeberanstrengung, 0);
    expect(result.remainingErschoepfung, 8);
  });

  test(
    'condition recovery only reaches erschÃ¶pfung after ueberanstrengung ends',
    () {
      final result = computeConditionRecovery(
        currentUeberanstrengung: 3,
        currentErschoepfung: 8,
        hours: 3,
        mode: RestConditionMode.schlaf,
      );

      expect(result.reducedUeberanstrengung, 3);
      expect(result.reducedErschoepfung, 4);
      expect(result.remainingUeberanstrengung, 0);
      expect(result.remainingErschoepfung, 4);
    },
  );

  test('recovery phase uses masterful regeneration and lead attribute', () {
    final hero = buildHero(
      vorteileText: 'Astrale Regeneration II, Schnelle Heilung I',
      talentSpecialAbilities: const <TalentSpecialAbility>[
        TalentSpecialAbility(name: 'Regeneration II'),
      ],
      magicSpecialAbilities: const <MagicSpecialAbility>[
        MagicSpecialAbility(name: 'Meisterliche Regeneration'),
      ],
      magicLeadAttribute: 'KL',
    );

    final result = computeRestRecoveryPhase(
      abilities: collectRestAbilities(hero),
      effectiveAttributes: hero.attributes,
      environment: const RestEnvironmentInput(),
      lepRoll: 4,
      aspRoll: 2,
      koProbeSucceeded: true,
      inProbeSucceeded: true,
      magicLeadAttribute: hero.magicLeadAttribute,
      magicEnabled: true,
    );

    expect(result.lepRecovered, 6);
    expect(result.aspBase, 5);
    expect(result.aspBonus, 6);
    expect(result.aspRecovered, 11);
    expect(result.usedMasterfulRegeneration, isTrue);
  });

  test('illness blocks LeP and reduces AsP to fixed 1', () {
    final hero = buildHero(
      vorteileText: 'Astrale Regeneration III, Schnelle Heilung III',
      talentSpecialAbilities: const <TalentSpecialAbility>[
        TalentSpecialAbility(name: 'Regeneration II'),
      ],
    );

    final result = computeRestRecoveryPhase(
      abilities: collectRestAbilities(hero),
      effectiveAttributes: hero.attributes,
      environment: const RestEnvironmentInput(isIll: true),
      lepRoll: 6,
      aspRoll: 6,
      koProbeSucceeded: true,
      inProbeSucceeded: true,
      magicLeadAttribute: '',
      magicEnabled: true,
    );

    expect(result.lepRecovered, 0);
    expect(result.aspRecovered, 1);
  });

  test('environment modifier is clamped to allowed range', () {
    final modifier = computeRestEnvironmentModifier(
      const RestEnvironmentInput(
        weatherModifier: -5,
        sleepSiteModifier: 2,
        hasBadCamp: true,
        hasNightDisturbance: true,
        hasWatchDuty: true,
        extraModifier: -10,
      ),
    );

    expect(modifier, -8);
  });
}
