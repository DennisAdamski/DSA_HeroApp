import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
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

const double _inspectorControlGap = 0;
const double _inspectorColumnGap = 2;
const double _inspectorModifierWidth = 20;
const double _inspectorResultWidth = 40;

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
    this.onToggleExpanded,
  });

  final String heroId;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

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

    final codex = context.codexTheme;
    final dragBar = onToggleExpanded == null
        ? const SizedBox(height: 10)
        : GestureDetector(
            key: const ValueKey<String>('workspace-details-toggle'),
            onTap: onToggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Tooltip(
                  message: toggleTooltip,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(codex.sectionRadius),
        bottomLeft: Radius.circular(codex.sectionRadius),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: codex.heroGradientSoft),
        child: SafeArea(
          child: isExpanded
              ? Column(
                  children: [
                    dragBar,
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                    computedAsync.valueOrNull?.wundschwelle ??
                                    0,
                              ),
                            const SizedBox(height: 10),
                            if (resourceActivation?.magic.isEnabled ??
                                false) ...[
                              _ZauberAktivierenCard(heroId: heroId),
                              const SizedBox(height: 10),
                            ],
                            if (hero != null &&
                                derived != null &&
                                combat != null)
                              _StatuswerteCard(
                                heroId: heroId,
                                hero: hero,
                                derived: derived,
                                combat: combat,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : dragBar,
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
          _InspectorValueRow(
            label: 'LeP',
            modifier: heroState.currentLep - derived.maxLep,
            result: heroState.currentLep,
            maxValue: derived.maxLep,
            resultColor: _vitalColor(
              context,
              heroState.currentLep,
              derived.maxLep,
            ),
            onDecrement: () => _save(
              ref,
              heroState.copyWith(currentLep: heroState.currentLep - 1),
            ),
            onIncrement: () => _save(
              ref,
              heroState.copyWith(currentLep: heroState.currentLep + 1),
            ),
            onReset: heroState.currentLep != derived.maxLep
                ? () =>
                      _save(ref, heroState.copyWith(currentLep: derived.maxLep))
                : null,
          ),
          const SizedBox(height: 6),
          _InspectorValueRow(
            label: 'AuP',
            modifier: heroState.currentAu - derived.maxAu,
            result: heroState.currentAu,
            maxValue: derived.maxAu,
            resultColor: _vitalColor(
              context,
              heroState.currentAu,
              derived.maxAu,
            ),
            onDecrement: () => _save(
              ref,
              heroState.copyWith(currentAu: heroState.currentAu - 1),
            ),
            onIncrement: () => _save(
              ref,
              heroState.copyWith(currentAu: heroState.currentAu + 1),
            ),
            onReset: heroState.currentAu != derived.maxAu
                ? () => _save(ref, heroState.copyWith(currentAu: derived.maxAu))
                : null,
          ),
          if (showMagicResources) ...[
            const SizedBox(height: 6),
            _InspectorValueRow(
              label: 'AsP',
              modifier: heroState.currentAsp - derived.maxAsp,
              result: heroState.currentAsp,
              maxValue: derived.maxAsp,
              resultColor: _vitalColor(
                context,
                heroState.currentAsp,
                derived.maxAsp,
              ),
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentAsp: heroState.currentAsp - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentAsp: heroState.currentAsp + 1),
              ),
              onReset: heroState.currentAsp != derived.maxAsp
                  ? () => _save(
                      ref,
                      heroState.copyWith(currentAsp: derived.maxAsp),
                    )
                  : null,
            ),
          ],
          if (showDivineResources) ...[
            const SizedBox(height: 6),
            _InspectorValueRow(
              label: 'KaP',
              modifier: heroState.currentKap - derived.maxKap,
              result: heroState.currentKap,
              maxValue: derived.maxKap,
              resultColor: _vitalColor(
                context,
                heroState.currentKap,
                derived.maxKap,
              ),
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentKap: heroState.currentKap - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentKap: heroState.currentKap + 1),
              ),
              onReset: heroState.currentKap != derived.maxKap
                  ? () => _save(
                      ref,
                      heroState.copyWith(currentKap: derived.maxKap),
                    )
                  : null,
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
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-vital-row-ueberanstrengung'),
            label: 'Überanstrengung',
            modifier: heroState.ueberanstrengung,
            result: heroState.ueberanstrengung,
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
            onReset: heroState.ueberanstrengung != 0
                ? () => _save(ref, heroState.copyWith(ueberanstrengung: 0))
                : null,
          ),
          const SizedBox(height: 6),
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-vital-row-erschoepfung'),
            label: 'Erschöpfung',
            modifier: heroState.erschoepfung,
            result: heroState.erschoepfung,
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
            onReset: heroState.erschoepfung != 0
                ? () => _save(ref, heroState.copyWith(erschoepfung: 0))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Einheitliche editierbare Zeile fuer Inspector-Werte.
///
/// Layout: {Name} [-] {Modifier} [+] [↺] … {Ergebnis} {/ Max}
class _InspectorValueRow extends StatelessWidget {
  const _InspectorValueRow({
    super.key,
    required this.label,
    required this.modifier,
    required this.onDecrement,
    required this.onIncrement,
    this.onReset,
    required this.result,
    this.maxValue,
    this.resultColor,
  });

  final String label;
  final int modifier;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onReset;
  final int result;
  final int? maxValue;
  final Color? resultColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonSize = adaptiveMinTouchTarget(context);
    final resultText = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$result',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: resultColor,
            ),
          ),
          if (maxValue != null)
            TextSpan(
              text: ' / $maxValue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      maxLines: 1,
      textAlign: TextAlign.right,
    );
    final sign = modifier > 0 ? '+' : '';
    final modColor = modifier > 0
        ? theme.colorScheme.primary
        : modifier < 0
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        const SizedBox(width: _inspectorColumnGap),
        _StepButton(
          icon: Icons.remove,
          tooltip: '$label verringern',
          onPressed: onDecrement,
        ),
        const SizedBox(width: _inspectorControlGap),
        SizedBox(
          width: _inspectorModifierWidth,
          child: Align(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$sign$modifier',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: modColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: _inspectorControlGap),
        _StepButton(
          icon: Icons.add,
          tooltip: '$label erhöhen',
          onPressed: onIncrement,
        ),
        const SizedBox(width: _inspectorColumnGap),
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: onReset == null
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: '$label zurücksetzen',
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  onPressed: onReset,
                  icon: const Icon(Icons.replay),
                ),
        ),
        const SizedBox(width: _inspectorColumnGap),
        SizedBox(
          width: _inspectorResultWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: resultText),
          ),
        ),
      ],
    );
  }
}

/// Nur-Lese-Zeile fuer MR und BE, ausgerichtet an _InspectorValueRow.
class _ReadOnlyValueRow extends StatelessWidget {
  const _ReadOnlyValueRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final buttonSize = adaptiveMinTouchTarget(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: _inspectorColumnGap),
        SizedBox(
          width:
              buttonSize * 2 +
              _inspectorModifierWidth +
              (_inspectorControlGap * 2) +
              _inspectorColumnGap +
              buttonSize,
        ),
        const SizedBox(width: _inspectorColumnGap),
        SizedBox(
          width: _inspectorResultWidth,
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

/// Farbgebung fuer Vitalwerte: rot bei niedrig, amber bei ueber Maximum.
Color? _vitalColor(BuildContext context, int current, int max) {
  if (current > max) return Colors.amber;
  if (max > 0 && current <= (max / 3).ceil()) {
    return Theme.of(context).colorScheme.error;
  }
  return null;
}

class _ZauberAktivierenCard extends ConsumerWidget {
  const _ZauberAktivierenCard({required this.heroId});

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
      title: 'Arkane Effekte',
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
              label: Text(chips.isEmpty ? 'Zauber aktivieren' : 'Verwalten'),
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
