part of 'workspace_inspector_panel.dart';

const double _statusLabelWidth = 32;
const double _statusValueWidth = 28;
const double _statusModifierWidth = 28;
const double _statusFinalWidth = 28;

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
          tooltip: 'BE erhöhen',
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
          tooltip: '$label erhöhen',
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
