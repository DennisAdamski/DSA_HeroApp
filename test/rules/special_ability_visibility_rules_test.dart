import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_visibility_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_skill_tree.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';

const _hero = HeroSheet(
  id: 'visibility',
  name: 'Held',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);

void main() {
  test('filtered graph keeps prerequisites and all planned targets', () {
    const magic = AdvancementOption(
      kind: AdvancementKind.magicAbility,
      targetId: 'magic',
      label: 'Magische Grundlage',
      ability: SpecialAbilityDef(id: 'magic', name: 'Magische Grundlage'),
    );
    const owned = AdvancementOption(
      kind: AdvancementKind.karmalAbility,
      targetId: 'owned',
      label: 'Besessen',
      isOwned: true,
      ability: SpecialAbilityDef(id: 'owned', name: 'Besessen'),
    );
    const target = AdvancementOption(
      kind: AdvancementKind.generalAbility,
      targetId: 'target',
      label: 'Ziel',
      ability: SpecialAbilityDef(id: 'target', name: 'Ziel'),
      requirements: [
        RequirementCheckResult(
          requirement: SpecialAbilityRequirement(
            art: RequirementArt.sonderfertigkeit,
            name: 'Magische Grundlage',
          ),
          status: RequirementStatus.nichtErfuellt,
          sollText: 'Magische Grundlage',
        ),
      ],
    );
    final activation = computeHeroResourceActivation(_hero);
    final filtered = visibleAdvancementAbilityOptions(
      options: [magic, target, owned],
      activation: activation,
      showInapplicable: false,
      plannedTargets: {},
    );
    expect(filtered, [target, owned]);
    final tree = buildAdvancementSkillTree(
      options: filtered,
      plannedTargets: {},
      availableAp: 1000,
    );
    expect(
      tree.nodes.values.any(
        (node) => node.option == null && node.label == 'Magische Grundlage',
      ),
      true,
    );
    expect(tree.components(query: 'Ziel'), hasLength(1));
    expect(
      tree.nodes['generalAbility:target']!.status,
      SkillTreeStatus.blocked,
    );
    final planned = visibleAdvancementAbilityOptions(
      options: [magic, target],
      activation: activation,
      showInapplicable: false,
      plannedTargets: {'magicAbility:magic'},
    );
    expect(planned, [magic, target]);
  });
  test(
    'old heroes omit the default; enabled setting survives JSON and copy',
    () {
      expect(
        _hero.toJson().containsKey('showInapplicableSpecialAbilities'),
        false,
      );
      expect(
        HeroSheet.fromJson(_hero.toJson()).showInapplicableSpecialAbilities,
        false,
      );
      final shown = _hero.copyWith(showInapplicableSpecialAbilities: true);
      expect(
        HeroSheet.fromJson(shown.toJson())
            .copyWith(name: 'Neu')
            .showInapplicableSpecialAbilities,
        true,
      );
    },
  );

  test('only inapplicable areas disappear; owned and planned remain', () {
    final activation = computeHeroResourceActivation(_hero);
    bool visible(
      String group, {
      bool owned = false,
      bool planned = false,
      bool show = false,
    }) => isSpecialAbilityVisible(
      group: group,
      activation: activation,
      isOwned: owned,
      isPlanned: planned,
      showInapplicable: show,
    );
    expect(visible('kampf'), true);
    expect(visible('allgemein'), true);
    expect(visible('magisch'), false);
    expect(visible('karmal'), false);
    expect(visible('karmal', owned: true), true);
    expect(visible('magisch', planned: true), true);
    expect(visible('magisch', show: true), true);
  });

  test(
    'effective resource overrides and automatic activation are respected',
    () {
      for (final group in ['magisch', 'karmal']) {
        final automatic = _hero.copyWith(vorteileText: 'AsP+3; KaP+3');
        expect(
          isSpecialAbilityVisible(
            group: group,
            activation: computeHeroResourceActivation(automatic),
          ),
          true,
        );
        final disabled = automatic.copyWith(
          resourceActivationConfig: const HeroResourceActivationConfig(
            magicEnabledOverride: false,
            divineEnabledOverride: false,
          ),
        );
        expect(
          isSpecialAbilityVisible(
            group: group,
            activation: computeHeroResourceActivation(disabled),
          ),
          false,
        );
        final enabled = _hero.copyWith(
          resourceActivationConfig: const HeroResourceActivationConfig(
            magicEnabledOverride: true,
            divineEnabledOverride: true,
          ),
        );
        expect(
          isSpecialAbilityVisible(
            group: group,
            activation: computeHeroResourceActivation(enabled),
          ),
          true,
        );
      }
    },
  );
}
