import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/resource_stepper_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wunden_detail_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_summary_rail.dart';

/// Persistenter Attribut-Header ueber dem Tab-Inhalt im Workspace.
///
/// Zeigt Kurzwerte fuer alle 8 Eigenschaften, Ressourcen (LeP/Au/AsP/KaP),
/// die aktuelle BE sowie den Wundstatus als persistente Summary-Rail an.
/// Wird bei jedem Providerwechsel reaktiv neu gebaut.
class WorkspaceCoreAttributesHeader extends ConsumerWidget {
  const WorkspaceCoreAttributesHeader({
    super.key,
    required this.heroId,
    required this.hero,
  });

  /// ID des darzustellenden Helden.
  final String heroId;

  /// Helddaten als Fallback fuer die Berechnung effektiver Attribute.
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computedAsync = ref.watch(heroComputedProvider(heroId));
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final collapsed = ref.watch(summaryRailCollapsedProvider);
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
    final activeWounds = state?.wpiZustand.gesamtEffektiveWunden ?? 0;

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

    final debugModus = ref.watch(debugModusProvider);
    final items = <CodexSummaryRailItem>[
      CodexSummaryRailItem(
        label: debugModus ? 'mu' : 'MU',
        value: effectiveAttributes.mu.toString(),
        icon: Icons.bolt_outlined,
        onTap: attributeTap('MU', effectiveAttributes.mu),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'kl' : 'KL',
        value: effectiveAttributes.kl.toString(),
        icon: Icons.menu_book_outlined,
        onTap: attributeTap('KL', effectiveAttributes.kl),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'inn' : 'IN',
        value: effectiveAttributes.inn.toString(),
        icon: Icons.visibility_outlined,
        onTap: attributeTap('IN', effectiveAttributes.inn),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ch' : 'CH',
        value: effectiveAttributes.ch.toString(),
        icon: Icons.record_voice_over_outlined,
        onTap: attributeTap('CH', effectiveAttributes.ch),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ff' : 'FF',
        value: effectiveAttributes.ff.toString(),
        icon: Icons.back_hand_outlined,
        onTap: attributeTap('FF', effectiveAttributes.ff),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ge' : 'GE',
        value: effectiveAttributes.ge.toString(),
        icon: Icons.directions_run_outlined,
        onTap: attributeTap('GE', effectiveAttributes.ge),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ko' : 'KO',
        value: effectiveAttributes.ko.toString(),
        icon: Icons.health_and_safety_outlined,
        onTap: attributeTap('KO', effectiveAttributes.ko),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'kk' : 'KK',
        value: effectiveAttributes.kk.toString(),
        icon: Icons.sports_martial_arts_outlined,
        onTap: attributeTap('KK', effectiveAttributes.kk),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'currentLep/maxLep' : 'LeP',
        value: resourceText(state?.currentLep, derived?.maxLep),
        icon: Icons.favorite_outline,
        highlight: true,
        onTap: resourceTap(ResourceType.lep),
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'currentAu/maxAu' : 'Au',
        value: resourceText(state?.currentAu, derived?.maxAu),
        icon: Icons.battery_charging_full_outlined,
        onTap: resourceTap(ResourceType.au),
      ),
      if (showMagicResources)
        CodexSummaryRailItem(
          label: debugModus ? 'currentAsp/maxAsp' : 'AsP',
          value: resourceText(state?.currentAsp, derived?.maxAsp),
          icon: Icons.auto_awesome_outlined,
          onTap: resourceTap(ResourceType.asp),
        ),
      if (showDivineResources)
        CodexSummaryRailItem(
          label: debugModus ? 'currentKap/maxKap' : 'KaP',
          value: resourceText(state?.currentKap, derived?.maxKap),
          icon: Icons.self_improvement_outlined,
          onTap: resourceTap(ResourceType.kap),
        ),
      CodexSummaryRailItem(
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
      CodexSummaryRailItem(
        label: 'Wunden',
        value: activeWounds.toString(),
        icon: Icons.healing_outlined,
        helper: activeWounds > 0
            ? 'Aktive Mali moeglich'
            : 'Keine aktiven Wunden',
        highlight: activeWounds > 0,
        onTap: () => showWundenDetailDialog(
          context: context,
          heroId: heroId,
        ),
      ),
    ];

    return CodexSummaryRail(
      items: items,
      collapsed: collapsed,
      onToggleCollapsed: () {
        ref.read(settingsActionsProvider).toggleSummaryRailCollapsed();
      },
    );
  }
}

void _showBeStepperDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required int currentBe,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _BeStepperDialog(
      heroId: heroId,
      initialBe: currentBe,
    ),
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
            Text(
              'BE-Override',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _value > 0
                      ? () => setState(() => _value--)
                      : null,
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
                        .read(talentBeOverrideProvider(widget.heroId).notifier)
                        .state = null;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Zuruecksetzen'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(talentBeOverrideProvider(widget.heroId).notifier)
                        .state = _value;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Uebernehmen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
