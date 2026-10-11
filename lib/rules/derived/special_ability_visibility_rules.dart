import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';

import 'resource_activation_rules.dart';
import 'advancement_options.dart';
import 'requirement_evaluation_rules.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';

/// Filtert ausschließlich unpassende Bereiche, niemals offene Erwerbsziele.
/// Bestand und geplante Erwerbe bleiben unabhängig von der Befähigung sichtbar.
bool isSpecialAbilityVisible({
  required String group,
  required HeroResourceActivation activation,
  bool showInapplicable = false,
  bool isOwned = false,
  bool isPlanned = false,
}) {
  if (showInapplicable || isOwned || isPlanned) return true;
  return switch (group.trim().toLowerCase()) {
    'magisch' => activation.magic.isEnabled,
    'karmal' => activation.divine.isEnabled,
    _ => true,
  };
}

/// Bedingungen, die festlegen, ob eine Sonderfertigkeit zur Tradition bzw.
/// Gottheit des Helden passt. Ist eine davon nicht erfüllt, gehört der Eintrag
/// zu einer anderen Repräsentation, Rasse oder Kirche und bleibt verborgen —
/// anders als offene Werte (Eigenschaften, ZfW), die man noch steigern kann.
const Set<RequirementArt> _passungsArten = <RequirementArt>{
  RequirementArt.tradition,
  RequirementArt.spruchzauberer,
  RequirementArt.rasse,
  RequirementArt.rasseVerboten,
  RequirementArt.gottheit,
};

/// Ob die Voraussetzungen einer Option sie einer fremden Tradition, Rasse
/// oder Gottheit zuordnen.
///
/// Gilt nur für magische und karmale Sonderfertigkeiten: Dort entscheidet die
/// gelernte Repräsentation bzw. die Gottheit, was überhaupt erlernbar ist.
bool passtNichtZumHelden(AdvancementOption option) {
  if (option.kind != AdvancementKind.magicAbility &&
      option.kind != AdvancementKind.karmalAbility) {
    return false;
  }
  return option.requirements.any(
    (befund) =>
        _passungsArten.contains(befund.requirement.art) &&
        befund.status == RequirementStatus.nichtErfuellt,
  );
}

/// Wählt sichtbare Erwerbsoptionen; der Graph erhält fehlende Referenzen als
/// Voraussetzungsknoten, sodass sichtbare Ziele weiterhin erklärbar bleiben.
///
/// Ausgeblendet werden ohne [showInapplicable]: magische bzw. karmale
/// Einträge ohne passende Befähigung, Einträge einer fremden Tradition, Rasse
/// oder Gottheit ([passtNichtZumHelden]) sowie reine Informationseinträge
/// und Merkmalskenntnisse, die eigene Bereiche haben.
List<AdvancementOption> visibleAdvancementAbilityOptions({
  required List<AdvancementOption> options,
  required HeroResourceActivation activation,
  required bool showInapplicable,
  required Set<String> plannedTargets,
}) => options
    .where((option) {
      if (option.isMerkmalskenntnis) return false;
      final ability = option.ability;
      if (ability is SpecialAbilityDef &&
          ability.nurInformation &&
          !option.isOwned) {
        return false;
      }
      final group = switch (option.kind) {
        AdvancementKind.magicAbility => 'magisch',
        AdvancementKind.karmalAbility => 'karmal',
        _ => '',
      };
      final target = '${option.kind.name}:${option.targetId}';
      final planned = plannedTargets.contains(target);
      if (!showInapplicable &&
          !option.isOwned &&
          !planned &&
          passtNichtZumHelden(option)) {
        return false;
      }
      return isSpecialAbilityVisible(
        group: group,
        activation: activation,
        showInapplicable: showInapplicable,
        isOwned: option.isOwned,
        isPlanned: planned,
      );
    })
    .toList(growable: false);
