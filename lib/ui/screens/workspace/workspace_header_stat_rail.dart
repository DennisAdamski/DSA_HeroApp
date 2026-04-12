import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/resource_stepper_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wunden_detail_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_metric_tile.dart';

/// Layoutvarianten fuer die Workspace-Kernwerte-Rail.
enum WorkspaceHeaderStatRailVariant {
  /// Eigenstaendige Rail fuer die kompakte Mobilansicht.
  standalone,

  /// Eingebettete Rail innerhalb des Tablet-/Desktop-Headers.
  embedded,
}

/// Reaktive Rail mit Eigenschaften, Ressourcen und Kurzstatus des Helden.
class WorkspaceHeaderStatRail extends ConsumerWidget {
  /// Erstellt die gemeinsame Kernwerte-Rail des Workspace-Headers.
  const WorkspaceHeaderStatRail({
    super.key,
    required this.heroId,
    required this.hero,
    this.variant = WorkspaceHeaderStatRailVariant.standalone,
  });

  /// ID des darzustellenden Helden.
  final String heroId;

  /// Helddaten als Fallback fuer berechnete Werte.
  final HeroSheet hero;

  /// Dekorationsmodus fuer mobilen Standalone- oder eingebetteten Header.
  final WorkspaceHeaderStatRailVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codex = context.codexTheme;
    final items = _buildItems(context, ref);
    final body = _WorkspaceHeaderStatRailBody(items: items);

    if (variant == WorkspaceHeaderStatRailVariant.embedded) {
      return Container(
        key: const ValueKey<String>('workspace-header-stat-rail'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: codex.rule.withValues(alpha: 0.72)),
          ),
        ),
        child: body,
      );
    }

    return Container(
      key: const ValueKey<String>('workspace-header-stat-rail'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: codex.heroGradientSoft,
        border: Border(
          bottom: BorderSide(color: codex.rule),
          top: BorderSide(color: codex.rule.withValues(alpha: 0.6)),
        ),
      ),
      child: body,
    );
  }

  List<_WorkspaceHeaderStatItem> _buildItems(
    BuildContext context,
    WidgetRef ref,
  ) {
    final computedAsync = ref.watch(heroComputedProvider(heroId));
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final computed = computedAsync.valueOrNull;
    final effectiveAttributes =
        computed?.effectiveAttributes ?? computeEffectiveAttributes(hero);
    final state = computed?.state;
    final derived = computed?.derivedStats;
    final resourceActivation =
        computed?.resourceActivation ?? computeHeroResourceActivation(hero);
    final activeTalentBe =
        talentBeOverride ?? computed?.combatPreviewStats.beKampf;
    final showMagicResources = resourceActivation.magic.isEnabled;
    final showDivineResources = resourceActivation.divine.isEnabled;
    final totalWounds = state?.wpiZustand.gesamtWunden ?? 0;
    final debugModus = ref.watch(debugModusProvider);

    String resourceText(int? current, int? max) {
      final currentText = current?.toString() ?? '-';
      final maxText = max?.toString() ?? '-';
      return '$currentText/$maxText';
    }

    VoidCallback attributeTap(String label, int value) {
      return () => showProbeDialog(
        context: context,
        request: buildAttributeProbeRequest(
          label: label,
          effectiveValue: value,
        ),
      );
    }

    VoidCallback resourceTap(ResourceType type) {
      return () => showResourceStepperDialog(
        context: context,
        heroId: heroId,
        resource: type,
      );
    }

    return <_WorkspaceHeaderStatItem>[
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'mu' : 'MU',
        value: effectiveAttributes.mu.toString(),
        icon: Icons.bolt_outlined,
        onTap: attributeTap('MU', effectiveAttributes.mu),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'kl' : 'KL',
        value: effectiveAttributes.kl.toString(),
        icon: Icons.menu_book_outlined,
        onTap: attributeTap('KL', effectiveAttributes.kl),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'inn' : 'IN',
        value: effectiveAttributes.inn.toString(),
        icon: Icons.visibility_outlined,
        onTap: attributeTap('IN', effectiveAttributes.inn),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'ch' : 'CH',
        value: effectiveAttributes.ch.toString(),
        icon: Icons.record_voice_over_outlined,
        onTap: attributeTap('CH', effectiveAttributes.ch),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'ff' : 'FF',
        value: effectiveAttributes.ff.toString(),
        icon: Icons.back_hand_outlined,
        onTap: attributeTap('FF', effectiveAttributes.ff),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'ge' : 'GE',
        value: effectiveAttributes.ge.toString(),
        icon: Icons.directions_run_outlined,
        onTap: attributeTap('GE', effectiveAttributes.ge),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'ko' : 'KO',
        value: effectiveAttributes.ko.toString(),
        icon: Icons.health_and_safety_outlined,
        onTap: attributeTap('KO', effectiveAttributes.ko),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'kk' : 'KK',
        value: effectiveAttributes.kk.toString(),
        icon: Icons.sports_martial_arts_outlined,
        onTap: attributeTap('KK', effectiveAttributes.kk),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'currentLep/maxLep' : 'LeP',
        value: resourceText(state?.currentLep, derived?.maxLep),
        icon: Icons.favorite_outline,
        highlight: true,
        onTap: resourceTap(ResourceType.lep),
      ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'currentAu/maxAu' : 'Au',
        value: resourceText(state?.currentAu, derived?.maxAu),
        icon: Icons.battery_charging_full_outlined,
        onTap: resourceTap(ResourceType.au),
      ),
      if (showMagicResources)
        _WorkspaceHeaderStatItem(
          label: debugModus ? 'currentAsp/maxAsp' : 'AsP',
          value: resourceText(state?.currentAsp, derived?.maxAsp),
          icon: Icons.auto_awesome_outlined,
          onTap: resourceTap(ResourceType.asp),
        ),
      if (showDivineResources)
        _WorkspaceHeaderStatItem(
          label: debugModus ? 'currentKap/maxKap' : 'KaP',
          value: resourceText(state?.currentKap, derived?.maxKap),
          icon: Icons.self_improvement_outlined,
          onTap: resourceTap(ResourceType.kap),
        ),
      _WorkspaceHeaderStatItem(
        label: debugModus ? 'beKampf' : 'BE',
        value: activeTalentBe?.toString() ?? '-',
        icon: Icons.shield_outlined,
        onTap: () => _showBeStepperDialog(
          context: context,
          ref: ref,
          heroId: heroId,
          currentBe: activeTalentBe ?? 0,
        ),
      ),
      _WorkspaceHeaderStatItem(
        label: 'Wunden',
        value: totalWounds.toString(),
        icon: Icons.healing_outlined,
        highlight: totalWounds > 0,
        onTap: () => showWundenDetailDialog(context: context, heroId: heroId),
      ),
    ];
  }
}

/// Scrollbare Zeile aus kompakten Metrik-Karten fuer den Workspace-Header.
class _WorkspaceHeaderStatRailBody extends StatelessWidget {
  const _WorkspaceHeaderStatRailBody({required this.items});

  final List<_WorkspaceHeaderStatItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  CodexMetricTile(
                    label: items[index].label,
                    value: items[index].value,
                    icon: items[index].icon,
                    highlight: items[index].highlight,
                    compact: true,
                    onTap: items[index].onTap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Verdichteter Kernwert fuer die Workspace-Rail.
class _WorkspaceHeaderStatItem {
  const _WorkspaceHeaderStatItem({
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;
  final VoidCallback? onTap;
}

void _showBeStepperDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required int currentBe,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _BeStepperDialog(heroId: heroId, initialBe: currentBe),
  );
}

class _BeStepperDialog extends ConsumerStatefulWidget {
  const _BeStepperDialog({required this.heroId, required this.initialBe});

  final String heroId;
  final int initialBe;

  @override
  ConsumerState<_BeStepperDialog> createState() => _BeStepperDialogState();
}

class _BeStepperDialogState extends ConsumerState<_BeStepperDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialBe;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('BE-Override', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _value > 0 ? () => setState(() => _value--) : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                Text(
                  '$_value',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  onPressed: () => setState(() => _value++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref
                            .read(
                              talentBeOverrideProvider(widget.heroId).notifier,
                            )
                            .state =
                        null;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Zurücksetzen'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    ref
                            .read(
                              talentBeOverrideProvider(widget.heroId).notifier,
                            )
                            .state =
                        _value;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Übernehmen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
