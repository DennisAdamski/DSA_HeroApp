import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector_wunden_card.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

part 'inspector_statuswerte_section.dart';

/// Inspector-Seitenleiste fuer den Desktop-Helden-Deck-Modus.
///
/// Zeigt den Heldenkopf, bearbeitbare Vitalwerte sowie eine kompakte
/// Statusliste fuer Kampf- und Abwehrwerte. Wird nur im breiten Layout
/// (>= 1280dp) neben dem Tab-Inhalt angezeigt.
class WorkspaceInspectorPanel extends ConsumerWidget {
  const WorkspaceInspectorPanel({
    super.key,
    required this.heroId,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final String heroId;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroByIdProvider(heroId));
    final heroStateAsync = ref.watch(heroStateProvider(heroId));
    final computedAsync = ref.watch(heroComputedProvider(heroId));

    final heroState = heroStateAsync.valueOrNull;
    final derived = computedAsync.valueOrNull?.derivedStats;
    final combat = computedAsync.valueOrNull?.combatPreviewStats;
    final resourceActivation = computedAsync.valueOrNull?.resourceActivation;
    final toggleTooltip = isExpanded
        ? 'Details ausblenden'
        : 'Details einblenden';
    final toggleIcon = isExpanded
        ? Icons.keyboard_double_arrow_right
        : Icons.keyboard_double_arrow_left;

    final codex = context.codexTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: codex.heroGradientSoft,
        border: Border(left: BorderSide(color: codex.rule)),
      ),
      child: SafeArea(
        child: isExpanded
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        key: const ValueKey<String>('workspace-details-toggle'),
                        tooltip: toggleTooltip,
                        onPressed: onToggleExpanded,
                        icon: Icon(toggleIcon),
                      ),
                    ),
                    if (heroState != null && derived != null)
                      _VitalwerteCard(
                        heroId: heroId,
                        heroState: heroState,
                        derived: derived,
                        resourceActivation: resourceActivation,
                        wundEffekte:
                            computedAsync.valueOrNull?.wundEffekte ??
                            const WundEffekte(),
                        wundschwelle:
                            computedAsync.valueOrNull?.wundschwelle ?? 0,
                      ),
                    const SizedBox(height: 10),
                    if (resourceActivation?.magic.isEnabled ?? false) ...[
                      _ZauberAktivierenCard(heroId: heroId),
                      const SizedBox(height: 10),
                    ],
                    if (hero != null && derived != null && combat != null)
                      _StatuswerteCard(
                        heroId: heroId,
                        hero: hero,
                        derived: derived,
                        combat: combat,
                      ),
                  ],
                ),
              )
            : Center(
                child: IconButton(
                  key: const ValueKey<String>('workspace-details-toggle'),
                  tooltip: toggleTooltip,
                  onPressed: onToggleExpanded,
                  icon: Icon(toggleIcon),
                ),
              ),
      ),
    );
  }
}

class _VitalwerteCard extends ConsumerWidget {
  const _VitalwerteCard({
    required this.heroId,
    required this.heroState,
    required this.derived,
    required this.resourceActivation,
    required this.wundEffekte,
    required this.wundschwelle,
  });

  final String heroId;
  final HeroState heroState;
  final DerivedStats derived;
  final HeroResourceActivation? resourceActivation;
  final WundEffekte wundEffekte;
  final int wundschwelle;

  Future<void> _save(WidgetRef ref, HeroState updated) async {
    await ref.read(heroActionsProvider).saveHeroState(heroId, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMagicResources = resourceActivation?.magic.isEnabled ?? false;
    final showDivineResources = resourceActivation?.divine.isEnabled ?? false;
    return CodexSectionCard(
      title: 'Vitalwerte',
      trailing: IconButton(
        key: const ValueKey<String>('workspace-rest-open'),
        tooltip: 'Rast öffnen',
        onPressed: () {
          showRestDialog(context: context, heroId: heroId);
        },
        icon: const Icon(Icons.local_fire_department_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResourceRow(
            label: 'LeP',
            current: heroState.currentLep,
            max: derived.maxLep,
            onDecrement: () => _save(
              ref,
              heroState.copyWith(currentLep: heroState.currentLep - 1),
            ),
            onIncrement: () => _save(
              ref,
              heroState.copyWith(currentLep: heroState.currentLep + 1),
            ),
          ),
          const SizedBox(height: 6),
          _ResourceRow(
            label: 'AuP',
            current: heroState.currentAu,
            max: derived.maxAu,
            onDecrement: () => _save(
              ref,
              heroState.copyWith(currentAu: heroState.currentAu - 1),
            ),
            onIncrement: () => _save(
              ref,
              heroState.copyWith(currentAu: heroState.currentAu + 1),
            ),
          ),
          if (showMagicResources) ...[
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'AsP',
              current: heroState.currentAsp,
              max: derived.maxAsp,
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentAsp: heroState.currentAsp - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentAsp: heroState.currentAsp + 1),
              ),
            ),
          ],
          if (showDivineResources) ...[
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'KaP',
              current: heroState.currentKap,
              max: derived.maxKap,
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentKap: heroState.currentKap - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentKap: heroState.currentKap + 1),
              ),
            ),
          ],
          const SizedBox(height: 6),
          InspectorWundenSection(
            heroId: heroId,
            heroState: heroState,
            wundEffekte: wundEffekte,
            wundschwelle: wundschwelle,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _StateCounterRow(
            rowKey: const ValueKey<String>(
              'workspace-vital-row-ueberanstrengung',
            ),
            label: 'Überanstrengung',
            value: heroState.ueberanstrengung,
            decrementTooltip: 'Überanstrengung verringern',
            incrementTooltip: 'Überanstrengung erhöhen',
            onDecrement: () => _save(
              ref,
              heroState.copyWith(
                ueberanstrengung: heroState.ueberanstrengung > 0
                    ? heroState.ueberanstrengung - 1
                    : 0,
              ),
            ),
            onIncrement: () => _save(
              ref,
              heroState.copyWith(
                ueberanstrengung: heroState.ueberanstrengung + 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _StateCounterRow(
            rowKey: const ValueKey<String>('workspace-vital-row-erschoepfung'),
            label: 'Erschöpfung',
            value: heroState.erschoepfung,
            decrementTooltip: 'Erschöpfung verringern',
            incrementTooltip: 'Erschöpfung erhöhen',
            onDecrement: () => _save(
              ref,
              heroState.copyWith(
                erschoepfung: heroState.erschoepfung > 0
                    ? heroState.erschoepfung - 1
                    : 0,
              ),
            ),
            onIncrement: () => _save(
              ref,
              heroState.copyWith(erschoepfung: heroState.erschoepfung + 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ressourcenzeile: Label | – | Wert / Max | +
class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.label,
    required this.current,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int current;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final isLow = max > 0 && current <= (max / 3).ceil();
    final isOverMax = current > max;
    final valueColor = isOverMax
        ? Colors.amber
        : isLow
            ? Theme.of(context).colorScheme.error
            : null;
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _StepButton(
          icon: Icons.remove,
          tooltip: '$label verringern',
          onPressed: onDecrement,
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: Icons.add,
          tooltip: '$label erhöhen',
          onPressed: onIncrement,
        ),
        const Spacer(),
        Text(
          '$current',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '/ $max',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Zustandszeile ohne Maximum fuer Erschoepfung und Ueberanstrengung.
class _StateCounterRow extends StatelessWidget {
  const _StateCounterRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.decrementTooltip,
    required this.incrementTooltip,
    required this.onDecrement,
    required this.onIncrement,
  });

  final Key rowKey;
  final String label;
  final int value;
  final String decrementTooltip;
  final String incrementTooltip;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: rowKey,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _StepButton(
          icon: Icons.remove,
          tooltip: decrementTooltip,
          onPressed: onDecrement,
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: Icons.add,
          tooltip: incrementTooltip,
          onPressed: onIncrement,
        ),
        const Spacer(),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ZauberAktivierenCard extends StatelessWidget {
  const _ZauberAktivierenCard({required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context) {
    return CodexSectionCard(
      title: 'Arkane Effekte',
      subtitle: 'Aktive Zaubereffekte und Zustandsmodifikatoren',
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const ValueKey<String>('workspace-active-spells-open'),
          onPressed: () {
            showActiveSpellEffectsDialog(context: context, heroId: heroId);
          },
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Zauber aktivieren'),
        ),
      ),
    );
  }
}

/// Kompakter Schaltknopf fuer Stepper-Interaktionen.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final size = adaptiveMinTouchTarget(context);
    return SizedBox(
      width: size,
      height: size,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        iconSize: 14,
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
