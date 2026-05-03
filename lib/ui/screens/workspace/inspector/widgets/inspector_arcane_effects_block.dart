import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Block fuer aktive arkane Effekte (eigene oder fremde Zauber/Liturgien).
///
/// Wird im Magie-Tab eingebettet. Effekte werden ueber den
/// `showActiveSpellEffectsDialog` verwaltet – sowohl bei Magiern als auch
/// bei nicht-magischen Helden, die durch Fremdzauber betroffen sind.
class InspectorArcaneEffectsBlock extends ConsumerWidget {
  const InspectorArcaneEffectsBlock({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroSheet = ref.watch(heroByIdProvider(heroId));
    final heroStateAsync = ref.watch(heroStateProvider(heroId));
    final computedAsync = ref.watch(heroComputedProvider(heroId));
    final heroState = heroStateAsync.valueOrNull;
    final combat = computedAsync.valueOrNull?.combatPreviewStats;

    final axxActive = heroSheet != null && heroState != null
        ? isAxxeleratusEffectActive(sheet: heroSheet, state: heroState)
        : false;
    final chips = combat != null
        ? describeActiveSpellEffects(
            axxeleratusActive: axxActive,
            axxIniBonus: combat.axxIniBonus,
            axxPaBaseBonus: combat.axxPaBaseBonus,
            axxAusweichenBonus: combat.axxAusweichenBonus,
            axxTpBonus: computeAxxeleratusTpBonus(axxeleratusActive: axxActive),
          )
        : <ActiveSpellEffectChip>[];

    return CodexSectionCard(
      title: 'Aktive Effekte',
      subtitle: chips.isEmpty
          ? 'Keine aktiven Effekte – Fremdzauber können hier hinzugefügt werden.'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('workspace-active-spells-open'),
              onPressed: () {
                showActiveSpellEffectsDialog(context: context, heroId: heroId);
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(chips.isEmpty ? 'Effekte hinzufügen' : 'Verwalten'),
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final chip in chips)
                  Chip(
                    avatar: const Icon(Icons.bolt, size: 16),
                    label: Text(
                      '${chip.label}: ${chip.bonusText}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
