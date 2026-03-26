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

const double _statusLabelWidth = 32;
const double _statusValueWidth = 28;
const double _statusModifierWidth = 28;
const double _statusFinalWidth = 28;

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
                      ),
                    const SizedBox(height: 10),
                    if (heroState != null)
                      InspectorWundenCard(
                        heroId: heroId,
                        heroState: heroState,
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
  });

  final String heroId;
  final HeroState heroState;
  final DerivedStats derived;
  final HeroResourceActivation? resourceActivation;

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
            label: 'Au',
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
    return Row(
      children: [
        SizedBox(
          width: 36,
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
        SizedBox(
          width: 44,
          child: Text(
            '$current',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isLow ? Theme.of(context).colorScheme.error : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '/ $max',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: Icons.add,
          tooltip: '$label erhoehen',
          onPressed: current < max ? onIncrement : null,
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
        Expanded(
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
        const SizedBox(width: 6),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 6),
        _StepButton(
          icon: Icons.add,
          tooltip: incrementTooltip,
          onPressed: onIncrement,
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

class _StatuswerteCard extends ConsumerWidget {
  const _StatuswerteCard({
    required this.heroId,
    required this.hero,
    required this.derived,
    required this.combat,
  });

  final String heroId;
  final HeroSheet hero;
  final DerivedStats derived;
  final CombatPreviewStats combat;

  Future<void> _saveMods(WidgetRef ref, StatModifiers mods) async {
    await ref
        .read(heroActionsProvider)
        .saveHero(hero.copyWith(persistentMods: mods));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mods = hero.persistentMods;
    return CodexSectionCard(
      title: 'Statuswerte',
      subtitle: 'Kampf-, Abwehr- und Bewegungswerte im Schnellzugriff',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditableStatusRow(
            label: 'Ini',
            baseValue: combat.initiative - mods.iniBase,
            modifierValue: mods.iniBase,
            finalValue: combat.initiative,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(iniBase: mods.iniBase - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(iniBase: mods.iniBase + 1)),
          ),
          const SizedBox(height: 6),
          _EditableStatusRow(
            label: 'GS',
            baseValue: derived.gs - mods.gs,
            modifierValue: mods.gs,
            finalValue: derived.gs,
            onDecrement: () => _saveMods(ref, mods.copyWith(gs: mods.gs - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(gs: mods.gs + 1)),
          ),
          const SizedBox(height: 6),
          _EditableStatusRow(
            label: 'AW',
            baseValue: combat.ausweichen - mods.ausweichen,
            modifierValue: mods.ausweichen,
            finalValue: combat.ausweichen,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(ausweichen: mods.ausweichen - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(ausweichen: mods.ausweichen + 1)),
          ),
          const SizedBox(height: 6),
          _EditableStatusRow(
            label: 'PA',
            baseValue: combat.pa - mods.pa,
            modifierValue: mods.pa,
            finalValue: combat.pa,
            onDecrement: () => _saveMods(ref, mods.copyWith(pa: mods.pa - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(pa: mods.pa + 1)),
          ),
          const SizedBox(height: 6),
          _EditableStatusRow(
            label: 'AT',
            baseValue: combat.at - mods.at,
            modifierValue: mods.at,
            finalValue: combat.at,
            onDecrement: () => _saveMods(ref, mods.copyWith(at: mods.at - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(at: mods.at + 1)),
          ),
          const SizedBox(height: 6),
          _ReadOnlyStatusRow(label: 'MR', finalValue: derived.mr),
          const SizedBox(height: 6),
          _EditableStatusRow(
            label: 'RS',
            baseValue: combat.rsTotal - mods.rs,
            modifierValue: mods.rs,
            finalValue: combat.rsTotal,
            onDecrement: () => _saveMods(ref, mods.copyWith(rs: mods.rs - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(rs: mods.rs + 1)),
          ),
          const SizedBox(height: 6),
          _BeStatusRow(heroId: heroId, combat: combat),
        ],
      ),
    );
  }
}

/// Spezielle BE-Zeile mit temporaerem Override fuer Talentproben.
class _BeStatusRow extends ConsumerWidget {
  const _BeStatusRow({required this.heroId, required this.combat});

  final String heroId;
  final CombatPreviewStats combat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(talentBeOverrideProvider(heroId));
    final displayed = override ?? combat.beKampf;
    final isManual = override != null;
    final stateText = isManual ? '(manuell)' : '(berechnet)';

    return Row(
      key: const ValueKey<String>('workspace-status-row-be'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _statusLabelWidth,
          child: Text(
            'BE',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          width: _statusValueWidth,
          child: Text(
            '${combat.beKampf}',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _StepButton(
          icon: Icons.remove,
          tooltip: 'BE verringern',
          onPressed: () {
            ref.read(talentBeOverrideProvider(heroId).notifier).state =
                displayed - 1;
          },
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: _statusModifierWidth,
          child: Text(
            '$displayed',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: Icons.add,
          tooltip: 'BE erhoehen',
          onPressed: () {
            ref.read(talentBeOverrideProvider(heroId).notifier).state =
                displayed + 1;
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: _statusFinalWidth,
          child: Text(
            '$displayed',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    stateText,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              if (isManual) ...[
                const SizedBox(width: 2),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    key: const ValueKey<String>('workspace-status-be-clear'),
                    tooltip: 'BE auf berechnet zurücksetzen',
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    onPressed: () {
                      ref
                              .read(talentBeOverrideProvider(heroId).notifier)
                              .state =
                          null;
                    },
                    icon: const Icon(Icons.replay),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Einheitliche Zeile fuer bearbeitbare Statuswerte mit Basis, Modifikator
/// und Endwert.
class _EditableStatusRow extends StatelessWidget {
  const _EditableStatusRow({
    required this.label,
    required this.baseValue,
    required this.modifierValue,
    required this.finalValue,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int baseValue;
  final int modifierValue;
  final int finalValue;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final sign = modifierValue > 0 ? '+' : '';
    final color = modifierValue > 0
        ? Theme.of(context).colorScheme.primary
        : modifierValue < 0
        ? Theme.of(context).colorScheme.error
        : null;
    return Row(
      key: ValueKey<String>('workspace-status-row-$label'),
      children: [
        SizedBox(
          width: _statusLabelWidth,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          width: _statusValueWidth,
          child: Text(
            '$baseValue',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _StepButton(
          icon: Icons.remove,
          tooltip: '$label verringern',
          onPressed: onDecrement,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: _statusModifierWidth,
          child: Text(
            '$sign$modifierValue',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: Icons.add,
          tooltip: '$label erhoehen',
          onPressed: onIncrement,
        ),
        const SizedBox(width: 12),
        const Spacer(),
        SizedBox(
          width: _statusFinalWidth,
          child: Text(
            '$finalValue',
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

class _ReadOnlyStatusRow extends StatelessWidget {
  const _ReadOnlyStatusRow({required this.label, required this.finalValue});

  final String label;
  final int finalValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey<String>('workspace-status-row-$label'),
      children: [
        SizedBox(
          width: _statusLabelWidth,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: _statusFinalWidth,
          child: Text(
            '$finalValue',
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
