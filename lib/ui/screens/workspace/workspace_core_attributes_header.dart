import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Persistenter Attribut-Header ueber dem Tab-Inhalt im Workspace.
///
/// Im Slim-Bar-Modus (`useSlimBar: true`) kollabiert der Header zu einer
/// kompakten ~48 px hohen Leiste mit Icon-Wert-Chips. Ein Expand-Button
/// oeffnet das vollstaendige Stepper-Panel als BottomSheet.
///
/// Im Standard-Modus zeigt der Header alle 8 Eigenschaften, Ressourcen und BE
/// als Wrap-Chips.
class WorkspaceCoreAttributesHeader extends ConsumerWidget {
  const WorkspaceCoreAttributesHeader({
    super.key,
    required this.heroId,
    required this.hero,
    this.useSlimBar = false,
  });

  /// ID des darzustellenden Helden.
  final String heroId;

  /// Helddaten als Fallback fuer die Berechnung effektiver Attribute.
  final HeroSheet hero;

  /// Wenn `true`, wird eine kompakte Slim-Bar statt des vollen Headers gezeigt.
  final bool useSlimBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveAsync = ref.watch(effectiveAttributesProvider(heroId));
    final stateAsync = ref.watch(heroStateProvider(heroId));
    final derivedAsync = ref.watch(derivedStatsProvider(heroId));
    final combatPreviewAsync = ref.watch(combatPreviewProvider(heroId));
    final resourceActivationAsync = ref.watch(resourceActivationProvider(heroId));
    final computedAsync = ref.watch(heroComputedProvider(heroId));

    final effectiveAttributes =
        effectiveAsync.valueOrNull ?? computeEffectiveAttributes(hero);
    final state = stateAsync.valueOrNull;
    final derived = derivedAsync.valueOrNull;
    final combat = combatPreviewAsync.valueOrNull;
    final resourceActivation =
        resourceActivationAsync.valueOrNull ?? computeHeroResourceActivation(hero);
    final wundEffekte =
        computedAsync.valueOrNull?.wundEffekte ?? const WundEffekte();
    final activeWounds = state?.wpiZustand.gesamtWunden ?? 0;
    final activeSpells =
        state?.activeSpellEffects.activeEffectIds.length ?? 0;

    if (useSlimBar) {
      return _buildSlimBar(
        context,
        ref,
        state,
        derived,
        combat,
        resourceActivation,
        wundEffekte,
        activeWounds,
        activeSpells,
        effectiveAttributes,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surfaceContainerHighest;
    return _buildFullHeader(
      context,
      ref,
      state,
      derived,
      combat,
      resourceActivation,
      wundEffekte,
      activeWounds,
      activeSpells,
      effectiveAttributes,
      colorScheme,
      surfaceColor,
    );
  }

  /// Baut die vollstaendige Header-Ansicht mit Eigenschaften- und Ressourcen-Chips.
  Widget _buildFullHeader(
    BuildContext context,
    WidgetRef ref,
    HeroState? state,
    DerivedStats? derived,
    CombatPreviewStats? combat,
    HeroResourceActivation resourceActivation,
    WundEffekte wundEffekte,
    int activeWounds,
    int activeSpells,
    Attributes effectiveAttributes,
    ColorScheme colorScheme,
    Color surfaceColor,
  ) {
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final debugModus = ref.watch(debugModusProvider);
    final activeTalentBe =
        talentBeOverride ?? combat?.beKampf;
    final showMagicResources = resourceActivation.magic.isEnabled;
    final showDivineResources = resourceActivation.divine.isEnabled;

    // Formatiert Ressourcen als "aktuell/max" oder "-" bei fehlenden Daten.
    String resourceText(int? current, int? max) {
      final currentText = current?.toString() ?? '-';
      final maxText = max?.toString() ?? '-';
      return '$currentText/$maxText';
    }

    final chips = <String>[
      '${debugModus ? 'mu' : 'MU'}: ${effectiveAttributes.mu}',
      '${debugModus ? 'kl' : 'KL'}: ${effectiveAttributes.kl}',
      '${debugModus ? 'inn' : 'IN'}: ${effectiveAttributes.inn}',
      '${debugModus ? 'ch' : 'CH'}: ${effectiveAttributes.ch}',
      '${debugModus ? 'ff' : 'FF'}: ${effectiveAttributes.ff}',
      '${debugModus ? 'ge' : 'GE'}: ${effectiveAttributes.ge}',
      '${debugModus ? 'ko' : 'KO'}: ${effectiveAttributes.ko}',
      '${debugModus ? 'kk' : 'KK'}: ${effectiveAttributes.kk}',
      '${debugModus ? 'currentLep/maxLep' : 'LeP'}: ${resourceText(state?.currentLep, derived?.maxLep)}',
      '${debugModus ? 'currentAu/maxAu' : 'Au'}: ${resourceText(state?.currentAu, derived?.maxAu)}',
      if (showMagicResources)
        '${debugModus ? 'currentAsp/maxAsp' : 'AsP'}: ${resourceText(state?.currentAsp, derived?.maxAsp)}',
      if (showDivineResources)
        '${debugModus ? 'currentKap/maxKap' : 'KaP'}: ${resourceText(state?.currentKap, derived?.maxKap)}',
      '${debugModus ? 'beKampf' : 'BE'}: ${activeTalentBe?.toString() ?? '-'}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: surfaceColor,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: chips
            .map(
              (entry) => Chip(
                label: Text(entry),
                visualDensity: VisualDensity.compact,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  /// Baut die kompakte Slim-Bar mit Icon-Wert-Chips und Expand-Button.
  Widget _buildSlimBar(
    BuildContext context,
    WidgetRef ref,
    HeroState? state,
    DerivedStats? derived,
    CombatPreviewStats? combat,
    HeroResourceActivation resourceActivation,
    WundEffekte wundEffekte,
    int activeWounds,
    int activeSpells,
    Attributes effectiveAttributes,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    void openFullSheet() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (_, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFullHeader(
                context,
                ref,
                state,
                derived,
                combat,
                resourceActivation,
                wundEffekte,
                activeWounds,
                activeSpells,
                effectiveAttributes,
                colorScheme,
                colorScheme.surface,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            if (state != null && derived != null) ...[
              _SlimChip(
                icon: Icons.favorite_outline,
                color: colorScheme.error,
                label: '${state.currentLep}/${derived.maxLep}',
                onTap: openFullSheet,
              ),
              const SizedBox(width: 8),
              _SlimChip(
                icon: Icons.directions_run,
                color: colorScheme.tertiary,
                label: '${state.currentAu}/${derived.maxAu}',
                onTap: openFullSheet,
              ),
            ],
            if (state != null &&
                derived != null &&
                (resourceActivation.magic.isEnabled)) ...[
              const SizedBox(width: 8),
              _SlimChip(
                icon: Icons.auto_awesome_outlined,
                color: colorScheme.primary,
                label: '${state.currentAsp}/${derived.maxAsp}',
                onTap: openFullSheet,
              ),
            ],
            if (state != null &&
                derived != null &&
                (resourceActivation.divine.isEnabled)) ...[
              const SizedBox(width: 8),
              _SlimChip(
                icon: Icons.church_outlined,
                color: colorScheme.secondary,
                label: '${state.currentKap}/${derived.maxKap}',
                onTap: openFullSheet,
              ),
            ],
            if (combat != null) ...[
              const SizedBox(width: 8),
              _SlimChip(
                icon: Icons.sports_martial_arts_outlined,
                color: colorScheme.onSurface,
                label: 'AT ${combat.at}  PA ${combat.pa}',
                onTap: openFullSheet,
              ),
              const SizedBox(width: 8),
              _SlimChip(
                icon: Icons.bolt,
                color: colorScheme.onSurface,
                label: 'INI ${combat.initiative}',
                onTap: openFullSheet,
              ),
            ],
            if (activeWounds > 0) ...[
              const SizedBox(width: 8),
              _SlimChip(
                icon: Icons.healing_outlined,
                color: colorScheme.error,
                label: 'Wunden $activeWounds',
                onTap: openFullSheet,
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Alle Werte anzeigen',
              icon: const Icon(Icons.expand_more),
              onPressed: openFullSheet,
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlimChip extends StatelessWidget {
  const _SlimChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
