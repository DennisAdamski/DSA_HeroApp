import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_arcane_effects_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_vital_block.dart';

/// Magie-Tab: AsP/KaP-Verwaltung (sofern aktiviert) plus aktive Effekte.
///
/// Der Tab ist immer sichtbar – auch nicht-magische Helden koennen
/// Fremdzauber/Liturgien als aktive Effekte tragen.
class InspectorMagieTab extends ConsumerWidget {
  const InspectorMagieTab({
    super.key,
    required this.heroId,
    required this.heroState,
    required this.derived,
    required this.resourceActivation,
  });

  final String heroId;
  final HeroState heroState;
  final DerivedStats derived;
  final HeroResourceActivation? resourceActivation;

  Future<void> _save(WidgetRef ref, HeroState updated) async {
    await ref.read(heroActionsProvider).saveHeroState(heroId, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showMagic = resourceActivation?.magic.isEnabled ?? false;
    final showDivine = resourceActivation?.divine.isEnabled ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showMagic) ...[
            InspectorVitalBlock(
              label: 'AsP',
              subtitle: 'Astralpunkte',
              current: heroState.currentAsp,
              max: derived.maxAsp,
              kind: VitalKind.asp,
              onChanged: (next) =>
                  _save(ref, heroState.copyWith(currentAsp: next)),
            ),
            const SizedBox(height: 8),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Held verfügt nicht über eigene Astralpunkte.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (showDivine) ...[
            InspectorVitalBlock(
              label: 'KaP',
              subtitle: 'Karmapunkte',
              current: heroState.currentKap,
              max: derived.maxKap,
              kind: VitalKind.kap,
              onChanged: (next) =>
                  _save(ref, heroState.copyWith(currentKap: next)),
            ),
            const SizedBox(height: 12),
          ],
          InspectorArcaneEffectsBlock(heroId: heroId),
        ],
      ),
    );
  }
}
