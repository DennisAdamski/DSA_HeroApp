import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_combat_quick_chip.dart';

/// Kampf-Schnellproben fuer Haupthand, Nebenhand und Schild.
///
/// Aus dem Probe-Tab herausgeloest, damit die neue Spielansicht dieselben
/// Chips benutzt. Welche Zeilen erscheinen, entscheidet ausschliesslich die
/// vorhandene Kampfvorschau [CombatPreviewStats] — es gibt hier keine eigene
/// Waffen-Namenszuordnung und keine Wuerfelmathematik.
class InspectorCombatProbes extends ConsumerWidget {
  /// Erstellt die Kampfproben fuer die uebergebene Vorschau.
  const InspectorCombatProbes({
    super.key,
    required this.heroId,
    required this.combat,
  });

  /// ID fuer das Protokollieren des Ergebnisses.
  final String heroId;

  /// Bereits berechnete Kampfvorschau.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offhand = combat.offhandPreview;
    final offhandAt = offhand?.at;
    final offhandPa = offhand?.paMitIniParadeMod ?? offhand?.pa;
    final showShield = combat.offhandIsShield && combat.shieldPa > 0;

    return Column(
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
            ((offhandAt != null && offhandAt > 0) || offhandPa != null)) ...[
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
                      title: 'Schnellprobe: AT (Nh) – ${combat.offhandName}',
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
                      title: 'Schnellprobe: PA (Nh) – ${combat.offhandName}',
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
                    title: 'Schnellprobe: PA (Schild) – ${combat.offhandName}',
                    targetValue: combat.shieldPa,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// Stellt der Chipreihe eine gleich breite Beschriftung voran.
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
