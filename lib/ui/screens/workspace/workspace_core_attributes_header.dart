import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
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

    final debugModus = ref.watch(debugModusProvider);
    final items = <CodexSummaryRailItem>[
      CodexSummaryRailItem(
        label: debugModus ? 'mu' : 'MU',
        value: effectiveAttributes.mu.toString(),
        icon: Icons.bolt_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'kl' : 'KL',
        value: effectiveAttributes.kl.toString(),
        icon: Icons.menu_book_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'inn' : 'IN',
        value: effectiveAttributes.inn.toString(),
        icon: Icons.visibility_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ch' : 'CH',
        value: effectiveAttributes.ch.toString(),
        icon: Icons.record_voice_over_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ff' : 'FF',
        value: effectiveAttributes.ff.toString(),
        icon: Icons.back_hand_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ge' : 'GE',
        value: effectiveAttributes.ge.toString(),
        icon: Icons.directions_run_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'ko' : 'KO',
        value: effectiveAttributes.ko.toString(),
        icon: Icons.health_and_safety_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'kk' : 'KK',
        value: effectiveAttributes.kk.toString(),
        icon: Icons.sports_martial_arts_outlined,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'currentLep/maxLep' : 'LeP',
        value: resourceText(state?.currentLep, derived?.maxLep),
        icon: Icons.favorite_outline,
        highlight: true,
      ),
      CodexSummaryRailItem(
        label: debugModus ? 'currentAu/maxAu' : 'Au',
        value: resourceText(state?.currentAu, derived?.maxAu),
        icon: Icons.battery_charging_full_outlined,
      ),
      if (showMagicResources)
        CodexSummaryRailItem(
          label: debugModus ? 'currentAsp/maxAsp' : 'AsP',
          value: resourceText(state?.currentAsp, derived?.maxAsp),
          icon: Icons.auto_awesome_outlined,
        ),
      if (showDivineResources)
        CodexSummaryRailItem(
          label: debugModus ? 'currentKap/maxKap' : 'KaP',
          value: resourceText(state?.currentKap, derived?.maxKap),
          icon: Icons.self_improvement_outlined,
        ),
      CodexSummaryRailItem(
        label: debugModus ? 'beKampf' : 'BE',
        value: activeTalentBe?.toString() ?? '-',
        icon: Icons.shield_outlined,
      ),
      CodexSummaryRailItem(
        label: 'Wunden',
        value: activeWounds.toString(),
        icon: Icons.healing_outlined,
        helper: activeWounds > 0
            ? 'Aktive Mali moeglich'
            : 'Keine aktiven Wunden',
        highlight: activeWounds > 0,
      ),
    ];

    return CodexSummaryRail(items: items);
  }
}
