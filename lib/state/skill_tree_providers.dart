import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_graph_builder.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_evaluation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Helden-unabhaengiger Kampf-Skilltree aus dem wirksamen Regelkatalog.
final combatSkillGraphProvider = FutureProvider<SkillGraph>((ref) async {
  final catalog = await ref.watch(rulesCatalogProvider.future);
  return buildCombatSkillGraph(catalog);
});

/// Helden-unabhaengiger Magie-Skilltree aus dem wirksamen Regelkatalog.
final magicSkillGraphProvider = FutureProvider<SkillGraph>((ref) async {
  final catalog = await ref.watch(rulesCatalogProvider.future);
  return buildMagicSkillGraph(catalog);
});

/// Argument fuer den bewerteten Skilltree (Held + Kategorie).
typedef SkillTreeViewArgs = ({String heroId, SkillTreeCategory category});

/// Bewerteter Skilltree fuer einen konkreten Helden und eine Kategorie.
final skillTreeViewProvider =
    FutureProvider.family<SkillTreeView, SkillTreeViewArgs>((ref, args) async {
      final graph = await ref.watch(
        args.category == SkillTreeCategory.combat
            ? combatSkillGraphProvider.future
            : magicSkillGraphProvider.future,
      );
      final hero = ref.watch(heroByIdProvider(args.heroId));
      if (hero == null) {
        throw StateError('Held mit ID "${args.heroId}" wurde nicht gefunden.');
      }
      final effectiveAttributes =
          ref.watch(effectiveAttributesProvider(args.heroId)).valueOrNull ??
          computeEffectiveAttributes(hero);
      return evaluateSkillTree(
        graph: graph,
        category: args.category,
        hero: hero,
        effectiveAttributes: effectiveAttributes,
      );
    });

/// Schreibende Aktionen des Skilltrees (Lernen einer Sonderfertigkeit).
class SkillTreeActions {
  SkillTreeActions(this._ref);

  final Ref _ref;

  /// Lernt eine Sonderfertigkeit und bucht die AP-Kosten ab.
  ///
  /// Kampf-SF werden ueber `activeCombatSpecialAbilityIds` aktiviert; magische
  /// SF werden der namensbasierten Liste hinzugefuegt. Anschliessend wird der
  /// Held ueber [HeroActions.saveHero] persistiert (normalisiert Level/AP).
  Future<void> learn({
    required String heroId,
    required SkillNode node,
    required SkillTreeCategory category,
  }) async {
    final hero = _ref.read(heroByIdProvider(heroId));
    if (hero == null) {
      throw StateError('Held mit ID "$heroId" wurde nicht gefunden.');
    }
    final cost = node.apCost ?? 0;

    final HeroSheet updated;
    if (category == SkillTreeCategory.combat) {
      final ids = List<String>.from(
        hero.combatConfig.specialRules.activeCombatSpecialAbilityIds,
      );
      if (ids.contains(node.id)) {
        return; // bereits aktiv
      }
      ids.add(node.id);
      updated = hero.copyWith(
        combatConfig: hero.combatConfig.copyWith(
          specialRules: hero.combatConfig.specialRules.copyWith(
            activeCombatSpecialAbilityIds: ids,
          ),
        ),
        apSpent: hero.apSpent + cost,
      );
    } else {
      final abilities = List<MagicSpecialAbility>.from(
        hero.magicSpecialAbilities,
      );
      final exists = abilities.any(
        (ability) =>
            ability.name.trim().toLowerCase() ==
            node.name.trim().toLowerCase(),
      );
      if (exists) {
        return;
      }
      abilities.add(
        MagicSpecialAbility(name: node.name, beschreibung: node.beschreibung),
      );
      updated = hero.copyWith(
        magicSpecialAbilities: abilities,
        apSpent: hero.apSpent + cost,
      );
    }

    await _ref.read(heroActionsProvider).saveHero(updated);
  }
}

/// Provider fuer [SkillTreeActions].
final skillTreeActionsProvider = Provider<SkillTreeActions>(
  (ref) => SkillTreeActions(ref),
);
