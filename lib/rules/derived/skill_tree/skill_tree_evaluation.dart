import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';

/// Auswertungsergebnis einer Einzelvoraussetzung.
enum _Sat { satisfied, unmet, unknown }

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Bewertet einen [SkillGraph] fuer einen konkreten Helden.
///
/// Unklare (nicht aufloesbare) Voraussetzungen fuehren bewusst zu
/// [SkillNodeState.unknownRequirements] statt zu „lernbar“ — die Entscheidung
/// liegt dann beim Nutzer.
SkillTreeView evaluateSkillTree({
  required SkillGraph graph,
  required SkillTreeCategory category,
  required HeroSheet hero,
  required Attributes effectiveAttributes,
}) {
  // Namensindizes ueber die Graph-Knoten aufbauen.
  final talentIdByName = <String, String>{};
  final spellIdByName = <String, String>{};
  final sfByName = <String, SkillNode>{};
  for (final node in graph.nodes.values) {
    final norm = _normalize(node.name);
    switch (node.kind) {
      case SkillNodeKind.talent:
        talentIdByName[norm] = node.id;
      case SkillNodeKind.spell:
        spellIdByName[norm] = node.id;
      case SkillNodeKind.combatSf:
      case SkillNodeKind.magicSf:
        sfByName[norm] = node;
    }
  }

  final activeCombatSfIds =
      hero.combatConfig.specialRules.activeCombatSpecialAbilityIds.toSet();
  final learnedCombatSfNames = <String>{
    for (final node in graph.nodes.values)
      if (node.kind == SkillNodeKind.combatSf &&
          activeCombatSfIds.contains(node.id))
        _normalize(node.name),
    for (final ability in hero.talentSpecialAbilities)
      _normalize(ability.name),
  };
  final learnedMagicSfNames = <String>{
    for (final ability in hero.magicSpecialAbilities) _normalize(ability.name),
  };
  final vorteileText = _normalize(hero.vorteileText);
  final rasse = _normalize(hero.background.rasse);

  int attrValue(String key) => switch (key) {
    'mu' => effectiveAttributes.mu,
    'kl' => effectiveAttributes.kl,
    'inn' => effectiveAttributes.inn,
    'ch' => effectiveAttributes.ch,
    'ff' => effectiveAttributes.ff,
    'ge' => effectiveAttributes.ge,
    'ko' => effectiveAttributes.ko,
    'kk' => effectiveAttributes.kk,
    _ => 0,
  };

  bool sfLearned(SkillNode node) {
    final norm = _normalize(node.name);
    if (node.kind == SkillNodeKind.combatSf) {
      return activeCombatSfIds.contains(node.id) ||
          learnedCombatSfNames.contains(norm);
    }
    if (node.kind == SkillNodeKind.magicSf) {
      return learnedMagicSfNames.contains(norm);
    }
    return false;
  }

  _Sat evalReq(SkillRequirement req) {
    switch (req) {
      case AttributeRequirement(:final attribute, :final min):
        return attrValue(attribute) >= min ? _Sat.satisfied : _Sat.unmet;
      case TalentRequirement(:final name, :final minTaW):
        final id = talentIdByName[_normalize(name)];
        if (id == null) return _Sat.unknown;
        final value = hero.talents[id]?.talentValue;
        if (value == null) return _Sat.unmet;
        return value >= minTaW ? _Sat.satisfied : _Sat.unmet;
      case SpellRequirement(:final name, :final minZfW):
        final id = spellIdByName[_normalize(name)];
        if (id == null) return _Sat.unknown;
        final value = hero.spells[id]?.spellValue;
        if (value == null) return _Sat.unmet;
        return value >= minZfW ? _Sat.satisfied : _Sat.unmet;
      case AbilityRequirement(:final name):
        final norm = _normalize(name);
        final node = sfByName[norm];
        if (node != null) {
          return sfLearned(node) ? _Sat.satisfied : _Sat.unmet;
        }
        if (learnedCombatSfNames.contains(norm) ||
            learnedMagicSfNames.contains(norm)) {
          return _Sat.satisfied;
        }
        return _Sat.unknown;
      case TraitRequirement(:final name):
        return vorteileText.contains(_normalize(name))
            ? _Sat.satisfied
            : _Sat.unmet;
      case RaceRequirement(:final name):
        final norm = _normalize(name);
        return rasse == norm || rasse.contains(norm)
            ? _Sat.satisfied
            : _Sat.unmet;
      case OrRequirement(:final options):
        var anyUnknown = false;
        for (final option in options) {
          final result = evalReq(option);
          if (result == _Sat.satisfied) return _Sat.satisfied;
          if (result == _Sat.unknown) anyUnknown = true;
        }
        return anyUnknown ? _Sat.unknown : _Sat.unmet;
      case UnknownRequirement():
        return _Sat.unknown;
    }
  }

  EvaluatedNode evalNode(SkillNode node) {
    final apCost = node.apCost;
    final canAfford = apCost == null || hero.apAvailable >= apCost;

    final bool learned = switch (node.kind) {
      SkillNodeKind.combatSf || SkillNodeKind.magicSf => sfLearned(node),
      SkillNodeKind.talent => hero.talents[node.id]?.talentValue != null,
      SkillNodeKind.spell => hero.spells.containsKey(node.id),
    };
    if (learned) {
      return EvaluatedNode(
        node: node,
        state: SkillNodeState.learned,
        canAfford: canAfford,
      );
    }

    // Talente/Zauber sind ueber den Baum nicht lernbar → gesperrt anzeigen.
    if (!node.isSpecialAbility) {
      return EvaluatedNode(node: node, state: SkillNodeState.locked);
    }

    final unmet = <SkillRequirement>[];
    var anyUnknown = false;
    for (final req in node.requirements) {
      final result = evalReq(req);
      if (result == _Sat.unmet) {
        unmet.add(req);
      } else if (result == _Sat.unknown) {
        anyUnknown = true;
      }
    }

    final SkillNodeState state;
    if (unmet.isNotEmpty) {
      state = SkillNodeState.locked;
    } else if (anyUnknown) {
      state = SkillNodeState.unknownRequirements;
    } else {
      state = SkillNodeState.learnable;
    }
    return EvaluatedNode(
      node: node,
      state: state,
      unmetRequirements: unmet,
      canAfford: canAfford,
    );
  }

  final evaluated = <String, EvaluatedNode>{
    for (final node in graph.nodes.values) node.id: evalNode(node),
  };
  return SkillTreeView(graph: graph, evaluated: evaluated, category: category);
}
