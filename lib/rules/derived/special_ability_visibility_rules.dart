import 'resource_activation_rules.dart';
import 'advancement_options.dart';

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

/// Wählt sichtbare Erwerbsoptionen; der Graph erhält fehlende Referenzen als
/// Voraussetzungsknoten, sodass sichtbare Ziele weiterhin erklärbar bleiben.
List<AdvancementOption> visibleAdvancementAbilityOptions({
  required List<AdvancementOption> options,
  required HeroResourceActivation activation,
  required bool showInapplicable,
  required Set<String> plannedTargets,
}) => options
    .where((option) {
      final group = switch (option.kind) {
        AdvancementKind.magicAbility => 'magisch',
        AdvancementKind.karmalAbility => 'karmal',
        _ => '',
      };
      final target = '${option.kind.name}:${option.targetId}';
      return isSpecialAbilityVisible(
        group: group,
        activation: activation,
        showInapplicable: showInapplicable,
        isOwned: option.isOwned,
        isPlanned: plannedTargets.contains(target),
      );
    })
    .toList(growable: false);
