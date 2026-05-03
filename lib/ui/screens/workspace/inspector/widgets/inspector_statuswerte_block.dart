import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_value_row.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Kompakte Statuswerte-Karte fuer den Vitals-Tab.
///
/// Bedienbar: Ini, GS, AW, PA, AT, RS, BE. MR ist read-only.
class InspectorStatuswerteBlock extends ConsumerWidget {
  const InspectorStatuswerteBlock({
    super.key,
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
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final activeTalentBe = talentBeOverride ?? combat.beKampf;
    final manualBeModifier = activeTalentBe - combat.beKampf;
    return CodexSectionCard(
      title: 'Statuswerte',
      subtitle: 'Schnellzugriff',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InspectorValueRow(
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
          InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-GS'),
            label: 'GS',
            modifier: mods.gs,
            result: derived.gs,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(gs: mods.gs - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(gs: mods.gs + 1)),
            onReset:
                mods.gs != 0 ? () => _saveMods(ref, mods.copyWith(gs: 0)) : null,
          ),
          const SizedBox(height: 6),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-AW'),
            label: 'AW',
            modifier: mods.ausweichen,
            result: combat.ausweichen,
            onDecrement: () => _saveMods(
                ref, mods.copyWith(ausweichen: mods.ausweichen - 1)),
            onIncrement: () => _saveMods(
                ref, mods.copyWith(ausweichen: mods.ausweichen + 1)),
            onReset: mods.ausweichen != 0
                ? () => _saveMods(ref, mods.copyWith(ausweichen: 0))
                : null,
          ),
          const SizedBox(height: 6),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-PA'),
            label: 'PA',
            modifier: mods.pa,
            result: combat.pa,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(pa: mods.pa - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(pa: mods.pa + 1)),
            onReset:
                mods.pa != 0 ? () => _saveMods(ref, mods.copyWith(pa: 0)) : null,
          ),
          const SizedBox(height: 6),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-AT'),
            label: 'AT',
            modifier: mods.at,
            result: combat.at,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(at: mods.at - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(at: mods.at + 1)),
            onReset:
                mods.at != 0 ? () => _saveMods(ref, mods.copyWith(at: 0)) : null,
          ),
          const SizedBox(height: 6),
          InspectorReadOnlyValueRow(
            key: const ValueKey<String>('workspace-status-row-MR'),
            label: 'MR',
            value: derived.mr,
          ),
          const SizedBox(height: 6),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-RS'),
            label: 'RS',
            modifier: mods.rs,
            result: combat.rsTotal,
            onDecrement: () =>
                _saveMods(ref, mods.copyWith(rs: mods.rs - 1)),
            onIncrement: () =>
                _saveMods(ref, mods.copyWith(rs: mods.rs + 1)),
            onReset:
                mods.rs != 0 ? () => _saveMods(ref, mods.copyWith(rs: 0)) : null,
          ),
          const SizedBox(height: 6),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-status-row-be'),
            label: 'BE',
            modifier: manualBeModifier,
            result: activeTalentBe,
            onDecrement: () {
              final nextBe = activeTalentBe > 0 ? activeTalentBe - 1 : 0;
              ref.read(talentBeOverrideProvider(heroId).notifier).state =
                  nextBe == combat.beKampf ? null : nextBe;
            },
            onIncrement: () {
              final nextBe = activeTalentBe + 1;
              ref.read(talentBeOverrideProvider(heroId).notifier).state =
                  nextBe == combat.beKampf ? null : nextBe;
            },
            onReset: talentBeOverride != null
                ? () {
                    ref.read(talentBeOverrideProvider(heroId).notifier).state =
                        null;
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
