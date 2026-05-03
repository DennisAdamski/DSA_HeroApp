import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_belastung_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_statuswerte_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_vital_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector_wunden_card.dart';

/// Vitals-Tab: LeP/AuP-Bars, Wunden, Belastung, Statuswerte.
///
/// AsP/KaP werden bewusst auch hier gerendert (zusaetzlich zum Magie-Tab),
/// damit alle Ressourcen auf einen Blick sichtbar bleiben.
class InspectorVitalsTab extends ConsumerWidget {
  const InspectorVitalsTab({
    super.key,
    required this.heroId,
    required this.hero,
    required this.heroState,
    required this.derived,
    required this.combat,
    required this.resourceActivation,
    required this.wundEffekte,
    required this.wundschwelle,
  });

  final String heroId;
  final HeroSheet hero;
  final HeroState heroState;
  final DerivedStats derived;
  final CombatPreviewStats combat;
  final HeroResourceActivation? resourceActivation;
  final WundEffekte wundEffekte;
  final int wundschwelle;

  Future<void> _save(WidgetRef ref, HeroState updated) async {
    await ref.read(heroActionsProvider).saveHeroState(heroId, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMagic = resourceActivation?.magic.isEnabled ?? false;
    final showDivine = resourceActivation?.divine.isEnabled ?? false;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InspectorVitalBlock(
            label: 'LeP',
            subtitle: 'Lebenspunkte',
            current: heroState.currentLep,
            max: derived.maxLep,
            kind: VitalKind.lep,
            onChanged: (next) =>
                _save(ref, heroState.copyWith(currentLep: next)),
          ),
          const SizedBox(height: 8),
          InspectorVitalBlock(
            label: 'AuP',
            subtitle: 'Ausdauer',
            current: heroState.currentAu,
            max: derived.maxAu,
            kind: VitalKind.aup,
            onChanged: (next) =>
                _save(ref, heroState.copyWith(currentAu: next)),
          ),
          if (showMagic) ...[
            const SizedBox(height: 8),
            InspectorVitalBlock(
              label: 'AsP',
              subtitle: 'Astralpunkte',
              current: heroState.currentAsp,
              max: derived.maxAsp,
              kind: VitalKind.asp,
              onChanged: (next) =>
                  _save(ref, heroState.copyWith(currentAsp: next)),
            ),
          ],
          if (showDivine) ...[
            const SizedBox(height: 8),
            InspectorVitalBlock(
              label: 'KaP',
              subtitle: 'Karmapunkte',
              current: heroState.currentKap,
              max: derived.maxKap,
              kind: VitalKind.kap,
              onChanged: (next) =>
                  _save(ref, heroState.copyWith(currentKap: next)),
            ),
          ],
          const SizedBox(height: 14),
          InspectorBelastungSection(heroId: heroId, heroState: heroState),
          const SizedBox(height: 14),
          InspectorWundenSection(
            heroId: heroId,
            heroState: heroState,
            wundEffekte: wundEffekte,
            wundschwelle: wundschwelle,
          ),
          const SizedBox(height: 14),
          InspectorStatuswerteBlock(
            heroId: heroId,
            hero: hero,
            derived: derived,
            combat: combat,
          ),
        ],
      ),
    );
  }
}
