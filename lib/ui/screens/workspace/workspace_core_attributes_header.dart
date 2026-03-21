import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wunden_detail_dialog.dart';

/// Persistente Statusleiste ueber dem eigentlichen Workspace-Inhalt.
///
/// Sie priorisiert spielrelevante Werte: Ressourcen mit Schnellanpassung,
/// Kampfstatus, Wunden, aktive Zauber und effektive Eigenschaften.
class WorkspaceCoreAttributesHeader extends ConsumerWidget {
  /// Erstellt die Statusleiste fuer den aktuellen Helden.
  const WorkspaceCoreAttributesHeader({
    super.key,
    required this.heroId,
    required this.hero,
  });

  /// ID des darzustellenden Helden.
  final String heroId;

  /// Helddaten als Fallback fuer Provider-Ladephasen.
  final HeroSheet hero;

  Future<void> _saveHeroState(WidgetRef ref, HeroState updated) async {
    await ref.read(heroActionsProvider).saveHeroState(heroId, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computedAsync = ref.watch(heroComputedProvider(heroId));
    final effectiveAttributes =
        computedAsync.valueOrNull?.effectiveAttributes ??
        computeEffectiveAttributes(hero);
    final state = computedAsync.valueOrNull?.state;
    final derived = computedAsync.valueOrNull?.derivedStats;
    final combat = computedAsync.valueOrNull?.combatPreviewStats;
    final resourceActivation =
        computedAsync.valueOrNull?.resourceActivation ??
        computeHeroResourceActivation(hero);
    final wundEffekte = computedAsync.valueOrNull?.wundEffekte;
    final activeWounds = state?.wpiZustand.gesamtWunden ?? 0;
    final activeSpells = state?.activeSpellEffects.activeEffectIds.length ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surface;

    Widget buildResourceCard({
      required String label,
      required int current,
      required int max,
      required VoidCallback onDecrease,
      required VoidCallback? onIncrease,
      required Color backgroundColor,
      required Color foregroundColor,
    }) {
      final isCritical = max > 0 && current <= (max / 3).ceil();
      return _StatusMetricCard(
        label: label,
        value: '$current / $max',
        caption: '$label: $current/$max',
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        emphasize: isCritical,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniStepButton(
              tooltip: '$label senken',
              icon: Icons.remove,
              onPressed: onDecrease,
            ),
            const SizedBox(width: 6),
            _MiniStepButton(
              tooltip: '$label steigern',
              icon: Icons.add,
              onPressed: onIncrease,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (state != null && derived != null)
                    buildResourceCard(
                      label: 'LeP',
                      current: state.currentLep,
                      max: derived.maxLep,
                      onDecrease: () => _saveHeroState(
                        ref,
                        state.copyWith(currentLep: state.currentLep - 1),
                      ),
                      onIncrease: state.currentLep < derived.maxLep
                          ? () => _saveHeroState(
                              ref,
                              state.copyWith(currentLep: state.currentLep + 1),
                            )
                          : null,
                      backgroundColor: colorScheme.errorContainer.withValues(
                        alpha: 0.82,
                      ),
                      foregroundColor: colorScheme.onErrorContainer,
                    ),
                  if (state != null && derived != null) ...[
                    const SizedBox(width: 10),
                    buildResourceCard(
                      label: 'Au',
                      current: state.currentAu,
                      max: derived.maxAu,
                      onDecrease: () => _saveHeroState(
                        ref,
                        state.copyWith(currentAu: state.currentAu - 1),
                      ),
                      onIncrease: state.currentAu < derived.maxAu
                          ? () => _saveHeroState(
                              ref,
                              state.copyWith(currentAu: state.currentAu + 1),
                            )
                          : null,
                      backgroundColor: colorScheme.tertiaryContainer.withValues(
                        alpha: 0.82,
                      ),
                      foregroundColor: colorScheme.onTertiaryContainer,
                    ),
                  ],
                  if (state != null &&
                      derived != null &&
                      resourceActivation.magic.isEnabled) ...[
                    const SizedBox(width: 10),
                    buildResourceCard(
                      label: 'AsP',
                      current: state.currentAsp,
                      max: derived.maxAsp,
                      onDecrease: () => _saveHeroState(
                        ref,
                        state.copyWith(currentAsp: state.currentAsp - 1),
                      ),
                      onIncrease: state.currentAsp < derived.maxAsp
                          ? () => _saveHeroState(
                              ref,
                              state.copyWith(currentAsp: state.currentAsp + 1),
                            )
                          : null,
                      backgroundColor: colorScheme.primaryContainer.withValues(
                        alpha: 0.82,
                      ),
                      foregroundColor: colorScheme.onPrimaryContainer,
                    ),
                  ],
                  if (state != null &&
                      derived != null &&
                      resourceActivation.divine.isEnabled) ...[
                    const SizedBox(width: 10),
                    buildResourceCard(
                      label: 'KaP',
                      current: state.currentKap,
                      max: derived.maxKap,
                      onDecrease: () => _saveHeroState(
                        ref,
                        state.copyWith(currentKap: state.currentKap - 1),
                      ),
                      onIncrease: state.currentKap < derived.maxKap
                          ? () => _saveHeroState(
                              ref,
                              state.copyWith(currentKap: state.currentKap + 1),
                            )
                          : null,
                      backgroundColor: colorScheme.secondaryContainer
                          .withValues(alpha: 0.82),
                      foregroundColor: colorScheme.onSecondaryContainer,
                    ),
                  ],
                  if (combat != null) ...[
                    const SizedBox(width: 10),
                    _StatusMetricCard(
                      label: 'Kampf',
                      value: 'AT ${combat.at}  PA ${combat.pa}',
                      caption: 'INI ${combat.initiative}  BE ${combat.beKampf}',
                      backgroundColor: colorScheme.surfaceContainer,
                      foregroundColor: colorScheme.onSurface,
                    ),
                  ],
                  const SizedBox(width: 10),
                  _InteractiveStatusCard(
                    label: 'Wunden',
                    value: '$activeWounds',
                    caption: wundEffekte == null
                        ? 'Noch keine Details'
                        : 'AT ${wundEffekte.atMalus}  PA ${wundEffekte.paMalus}',
                    backgroundColor: activeWounds > 0
                        ? colorScheme.errorContainer.withValues(alpha: 0.68)
                        : colorScheme.surfaceContainerLow,
                    foregroundColor: activeWounds > 0
                        ? colorScheme.onErrorContainer
                        : colorScheme.onSurface,
                    onTap: () => showWundenDetailDialog(
                      context: context,
                      heroId: heroId,
                    ),
                  ),
                  if (resourceActivation.magic.isEnabled) ...[
                    const SizedBox(width: 10),
                    _InteractiveStatusCard(
                      label: 'Aktive Zauber',
                      value: '$activeSpells',
                      caption: activeSpells == 1
                          ? '1 Effekt aktiv'
                          : '$activeSpells Effekte aktiv',
                      backgroundColor: colorScheme.primaryContainer.withValues(
                        alpha: 0.68,
                      ),
                      foregroundColor: colorScheme.onPrimaryContainer,
                      onTap: () => showActiveSpellEffectsDialog(
                        context: context,
                        heroId: heroId,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _AttributePill(label: 'MU', value: effectiveAttributes.mu),
                  const SizedBox(width: 8),
                  _AttributePill(label: 'KL', value: effectiveAttributes.kl),
                  const SizedBox(width: 8),
                  _AttributePill(label: 'IN', value: effectiveAttributes.inn),
                  const SizedBox(width: 8),
                  _AttributePill(label: 'CH', value: effectiveAttributes.ch),
                  const SizedBox(width: 8),
                  _AttributePill(label: 'FF', value: effectiveAttributes.ff),
                  const SizedBox(width: 8),
                  _AttributePill(label: 'GE', value: effectiveAttributes.ge),
                  const SizedBox(width: 8),
                  _AttributePill(label: 'KO', value: effectiveAttributes.ko),
                  const SizedBox(width: 8),
                  _AttributePill(label: 'KK', value: effectiveAttributes.kk),
                  if (derived != null) ...[
                    const SizedBox(width: 14),
                    _InlineStatusText(label: 'MR:', value: '${derived.mr}'),
                    const SizedBox(width: 12),
                    _InlineStatusText(label: 'GS:', value: '${derived.gs}'),
                  ],
                  if (combat != null) ...[
                    const SizedBox(width: 12),
                    _InlineStatusText(label: 'BE:', value: '${combat.beKampf}'),
                    const SizedBox(width: 12),
                    _InlineStatusText(
                      label: 'FK:',
                      value: '${combat.rangedAtBase}',
                    ),
                    const SizedBox(width: 12),
                    _InlineStatusText(
                      label: 'Ausweichen:',
                      value: '${combat.ausweichen}',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMetricCard extends StatelessWidget {
  const _StatusMetricCard({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
    this.caption,
    this.leading,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String? caption;
  final Widget? leading;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 158),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.86),
                    letterSpacing: 0.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (leading case final Widget action) action,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: foregroundColor,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foregroundColor.withValues(alpha: 0.82),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InteractiveStatusCard extends StatelessWidget {
  const _InteractiveStatusCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: _StatusMetricCard(
        label: label,
        value: value,
        caption: caption,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        leading: Icon(
          Icons.open_in_new,
          size: 16,
          color: foregroundColor.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}

class _MiniStepButton extends StatelessWidget {
  const _MiniStepButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        iconSize: 14,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _AttributePill extends StatelessWidget {
  const _AttributePill({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _InlineStatusText extends StatelessWidget {
  const _InlineStatusText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
