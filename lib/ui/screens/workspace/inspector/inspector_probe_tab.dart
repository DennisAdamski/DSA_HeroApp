import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_card.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_combat_quick_chip.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Tupel aus Eigenschaftslabel und effektivem Wert.
typedef _AttributeEntry = ({String label, int value});

/// Probe-Tab: Eigenschafts-Schnellproben, Kampfproben und Wuerfelprotokoll.
class InspectorProbeTab extends ConsumerWidget {
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

  Future<void> _runProbe(
    BuildContext context,
    WidgetRef ref,
    ResolvedProbeRequest request,
  ) {
    return showLoggedProbeDialog(
      context: context,
      ref: ref,
      heroId: heroId,
      request: request,
    );
  }

  List<_AttributeEntry> get _attributeEntries => <_AttributeEntry>[
    (label: 'MU', value: effectiveAttributes.mu),
    (label: 'KL', value: effectiveAttributes.kl),
    (label: 'IN', value: effectiveAttributes.inn),
    (label: 'CH', value: effectiveAttributes.ch),
    (label: 'FF', value: effectiveAttributes.ff),
    (label: 'GE', value: effectiveAttributes.ge),
    (label: 'KO', value: effectiveAttributes.ko),
    (label: 'KK', value: effectiveAttributes.kk),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = _attributeEntries;
    final offhand = combat.offhandPreview;
    final offhandAt = offhand?.at;
    final offhandPa = offhand?.paMitIniParadeMod ?? offhand?.pa;
    final showShield = combat.offhandIsShield && combat.shieldPa > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodexSectionCard(
            title: 'Schnellprobe',
            subtitle: 'Eigenschaft',
            child: _AttributeGrid(
              entries: entries,
              itemBuilder: (entry) => InspectorAttributeCard(
                key: ValueKey('inspector-probe-attr-${entry.label}'),
                label: entry.label,
                value: entry.value,
                onTap: () => _runProbe(
                  context,
                  ref,
                  buildAttributeProbeRequest(
                    label: entry.label,
                    effectiveValue: entry.value,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CodexSectionCard(
            title: 'Kampf',
            subtitle: 'Schnellprobe',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChipRow(
                  label: 'Haupthand',
                  chips: [
                    InspectorCombatQuickChip(
                      key: const ValueKey('inspector-probe-at'),
                      label: 'AT',
                      value: combat.at,
                      onTap: () => _runProbe(
                        context,
                        ref,
                        buildCombatCheckProbeRequest(
                          type: ProbeType.combatAttack,
                          title: 'Schnellprobe: AT',
                          targetValue: combat.at,
                        ),
                      ),
                    ),
                    InspectorCombatQuickChip(
                      key: const ValueKey('inspector-probe-pa'),
                      label: 'PA',
                      value: combat.pa,
                      onTap: () => _runProbe(
                        context,
                        ref,
                        buildCombatCheckProbeRequest(
                          type: ProbeType.combatParry,
                          title: 'Schnellprobe: PA',
                          targetValue: combat.pa,
                        ),
                      ),
                    ),
                    InspectorCombatQuickChip(
                      key: const ValueKey('inspector-probe-aw'),
                      label: 'AW',
                      value: combat.ausweichen,
                      onTap: () => _runProbe(
                        context,
                        ref,
                        buildCombatCheckProbeRequest(
                          type: ProbeType.dodge,
                          title: 'Schnellprobe: AW',
                          targetValue: combat.ausweichen,
                        ),
                      ),
                    ),
                  ],
                ),
                if (offhand != null &&
                    ((offhandAt != null && offhandAt > 0) ||
                        offhandPa != null)) ...[
                  const SizedBox(height: 8),
                  _ChipRow(
                    label: 'Nebenhand',
                    chips: [
                      if (offhandAt != null && offhandAt > 0)
                        InspectorCombatQuickChip(
                          key: const ValueKey('inspector-probe-at-nh'),
                          label: 'AT (Nh)',
                          value: offhandAt,
                          tooltip: combat.offhandName,
                          onTap: () => _runProbe(
                            context,
                            ref,
                            buildCombatCheckProbeRequest(
                              type: ProbeType.combatAttack,
                              title:
                                  'Schnellprobe: AT (Nh) – ${combat.offhandName}',
                              targetValue: offhandAt,
                            ),
                          ),
                        ),
                      if (offhandPa != null)
                        InspectorCombatQuickChip(
                          key: const ValueKey('inspector-probe-pa-nh'),
                          label: 'PA (Nh)',
                          value: offhandPa,
                          tooltip: combat.offhandName,
                          onTap: () => _runProbe(
                            context,
                            ref,
                            buildCombatCheckProbeRequest(
                              type: ProbeType.combatParry,
                              title:
                                  'Schnellprobe: PA (Nh) – ${combat.offhandName}',
                              targetValue: offhandPa,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (showShield) ...[
                  const SizedBox(height: 8),
                  _ChipRow(
                    label: 'Schild',
                    chips: [
                      InspectorCombatQuickChip(
                        key: const ValueKey('inspector-probe-pa-shield'),
                        label: 'PA (Schild)',
                        value: combat.shieldPa,
                        tooltip: combat.offhandName,
                        onTap: () => _runProbe(
                          context,
                          ref,
                          buildCombatCheckProbeRequest(
                            type: ProbeType.combatParry,
                            title:
                                'Schnellprobe: PA (Schild) – ${combat.offhandName}',
                            targetValue: combat.shieldPa,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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

// Haelt die Eigenschaftskarten auch im schmalen Inspector lesbar.
class _AttributeGrid extends StatelessWidget {
  const _AttributeGrid({required this.entries, required this.itemBuilder});

  static const double _spacing = 6;
  static const double _minTileWidth = 48;
  static const double _tileHeight = 58;
  static const int _maxColumns = 4;

  final List<_AttributeEntry> entries;
  final Widget Function(_AttributeEntry entry) itemBuilder;

  int _columnCount(double availableWidth) {
    final rawCount = ((availableWidth + _spacing) / (_minTileWidth + _spacing))
        .floor();
    return rawCount.clamp(1, _maxColumns).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = _maxColumns * (_minTileWidth + _spacing);
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fallbackWidth;
        final crossAxisCount = _columnCount(availableWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: _tileHeight,
          ),
          itemBuilder: (context, index) => itemBuilder(entries[index]),
        );
      },
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.chips});

  final String label;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: chips)),
      ],
    );
  }
}
