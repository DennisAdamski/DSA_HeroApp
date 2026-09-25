import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_combat_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Probe-Tab: Eigenschafts-Schnellproben, Kampfproben und Wuerfelprotokoll.
///
/// Die drei Bausteine liegen seit R2 einzeln vor, damit die neue Spielansicht
/// sie in ihrer eigenen Anordnung verwenden kann. Dieser Tab bleibt die
/// gewohnte Zusammenstellung der bestehenden Oberflaeche.
class InspectorProbeTab extends StatelessWidget {
  const InspectorProbeTab({
    super.key,
    required this.heroId,
    required this.heroState,
    required this.effectiveAttributes,
    required this.combat,
  });

  final String heroId;
  final HeroState heroState;
  final Attributes effectiveAttributes;
  final CombatPreviewStats combat;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodexSectionCard(
            title: 'Schnellprobe',
            subtitle: 'Eigenschaft',
            child: InspectorAttributeProbes(
              heroId: heroId,
              effectiveAttributes: effectiveAttributes,
            ),
          ),
          const SizedBox(height: 12),
          CodexSectionCard(
            title: 'Kampf',
            subtitle: 'Schnellprobe',
            child: InspectorCombatProbes(heroId: heroId, combat: combat),
          ),
          const SizedBox(height: 12),
          CodexSectionCard(
            title: 'Würfel-Protokoll',
            subtitle: 'Letzte ${HeroState.diceLogMax}',
            child: InspectorDiceLogSection(entries: heroState.diceLog),
          ),
        ],
      ),
    );
  }
}
