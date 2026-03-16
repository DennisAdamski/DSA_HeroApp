import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  test('heroComputedProvider reuses combined compute pipeline', () async {
    final hero = HeroSheet(
      id: 'h-1',
      name: 'Test',
      level: 3,
      rawStartAttributes: const Attributes(
        mu: 11,
        kl: 13,
        inn: 10,
        ch: 9,
        ff: 8,
        ge: 10,
        ko: 11,
        kk: 12,
      ),
      attributes: const Attributes(
        mu: 12,
        kl: 11,
        inn: 10,
        ch: 9,
        ff: 8,
        ge: 10,
        ko: 11,
        kk: 12,
      ),
      background: HeroBackground(rasseModText: 'MU+1'),
      vorteileText: 'LEP+2',
    );
    const state = HeroState(
      currentLep: 30,
      currentAsp: 12,
      currentKap: 0,
      currentAu: 20,
    );
    final repo = FakeRepository(
      heroes: <HeroSheet>[hero],
      states: <String, HeroState>{'h-1': state},
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async {
          return const RulesCatalog(
            version: 'test',
            source: 'unit',
            talents: <TalentDef>[],
            spells: <SpellDef>[],
            weapons: <WeaponDef>[],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    final heroListSub = container.listen<AsyncValue<List<HeroSheet>>>(
      heroListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final heroStateSub = container.listen<AsyncValue<HeroState>>(
      heroStateProvider('h-1'),
      (_, _) {},
      fireImmediately: true,
    );
    final rulesCatalogSub = container.listen<AsyncValue<RulesCatalog>>(
      rulesCatalogProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final computedSub = container.listen(
      heroComputedProvider('h-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(heroListSub.close);
    addTearDown(heroStateSub.close);
    addTearDown(rulesCatalogSub.close);
    addTearDown(computedSub.close);

    for (var attempt = 0; attempt < 20; attempt++) {
      final allReady =
          heroListSub.read().hasValue &&
          heroStateSub.read().hasValue &&
          rulesCatalogSub.read().hasValue &&
          computedSub.read().hasValue;
      if (allReady) {
        break;
      }
      await container.pump();
    }
    expect(heroListSub.read().hasValue, isTrue);
    expect(heroStateSub.read().hasValue, isTrue);
    expect(rulesCatalogSub.read().hasValue, isTrue);
    expect(computedSub.read().hasValue, isTrue);

    final computed = computedSub.read().requireValue;

    final parsed = parseModifierTextsForHero(hero);
    final effectiveStartAttributes = computeEffectiveStartAttributes(
      hero.rawStartAttributes,
      parseOriginAttributeModifiers(hero),
    );
    final attributeMaximums = computeAttributeMaximums(
      effectiveStartAttributes,
    );
    final effective = applyAttributeModifiers(
      hero.attributes,
      parsed.attributeMods + state.tempAttributeMods,
    );
    final derived = computeDerivedStatsFromInputs(
      sheet: hero,
      state: state,
      parsedModifiers: parsed,
      effectiveAttributes: effective,
    );
    final combat = computeCombatPreviewStats(
      hero,
      state,
      parsedModifiers: parsed,
      effectiveAttributes: effective,
      derivedStats: derived,
    );

    expect(computed.effectiveAttributes.mu, effective.mu);
    expect(computed.effectiveStartAttributes.kl, effectiveStartAttributes.kl);
    expect(computed.attributeMaximums.kl, attributeMaximums.kl);
    expect(computed.derivedStats.maxLep, derived.maxLep);
    expect(computed.combatPreviewStats.at, combat.at);
    expect(computed.modifierParse.unknownFragments, parsed.unknownFragments);
  });
}
