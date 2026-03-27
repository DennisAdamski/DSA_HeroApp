part of 'workspace_inspector_panel.dart';

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
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-Ini'),
            label: 'Ini',
            modifier: mods.iniBase,
            result: combat.initiative,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(iniBase: mods.iniBase - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(iniBase: mods.iniBase + 1)),
            onReset: mods.iniBase != 0
                ? () => _saveMods(ref, mods.copyWith(iniBase: 0))
                : null,
          ),
          const SizedBox(height: 6),
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-GS'),
            label: 'GS',
            modifier: mods.gs,
            result: derived.gs,
            onDecrement: () => _saveMods(ref, mods.copyWith(gs: mods.gs - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(gs: mods.gs + 1)),
            onReset: mods.gs != 0
                ? () => _saveMods(ref, mods.copyWith(gs: 0))
                : null,
          ),
          const SizedBox(height: 6),
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-AW'),
            label: 'AW',
            modifier: mods.ausweichen,
            result: combat.ausweichen,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(ausweichen: mods.ausweichen - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(ausweichen: mods.ausweichen + 1)),
            onReset: mods.ausweichen != 0
                ? () => _saveMods(ref, mods.copyWith(ausweichen: 0))
                : null,
          ),
          const SizedBox(height: 6),
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-PA'),
            label: 'PA',
            modifier: mods.pa,
            result: combat.pa,
            onDecrement: () => _saveMods(ref, mods.copyWith(pa: mods.pa - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(pa: mods.pa + 1)),
            onReset: mods.pa != 0
                ? () => _saveMods(ref, mods.copyWith(pa: 0))
                : null,
          ),
          const SizedBox(height: 6),
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-AT'),
            label: 'AT',
            modifier: mods.at,
            result: combat.at,
            onDecrement: () => _saveMods(ref, mods.copyWith(at: mods.at - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(at: mods.at + 1)),
            onReset: mods.at != 0
                ? () => _saveMods(ref, mods.copyWith(at: 0))
                : null,
          ),
          const SizedBox(height: 6),
          _ReadOnlyValueRow(
            key: const ValueKey<String>('workspace-status-row-MR'),
            label: 'MR',
            value: derived.mr,
          ),
          const SizedBox(height: 6),
          _InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-RS'),
            label: 'RS',
            modifier: mods.rs,
            result: combat.rsTotal,
            onDecrement: () => _saveMods(ref, mods.copyWith(rs: mods.rs - 1)),
            onIncrement: () => _saveMods(ref, mods.copyWith(rs: mods.rs + 1)),
            onReset: mods.rs != 0
                ? () => _saveMods(ref, mods.copyWith(rs: 0))
                : null,
          ),
          const SizedBox(height: 6),
          _ReadOnlyValueRow(
            key: const ValueKey<String>('workspace-status-row-be'),
            label: 'BE',
            value: combat.beKampf,
          ),
        ],
      ),
    );
  }
}
