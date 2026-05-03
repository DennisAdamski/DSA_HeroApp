import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Rast-Tab: Read-only-Vital-Uebersicht plus eingebettetes Rast-Panel.
///
/// In dieser Iteration startet der Inhalt das bestehende `showRestDialog`,
/// bis das `RestPanel` (Schritt 6) extrahiert ist und direkt eingebettet
/// werden kann.
class InspectorRastTab extends ConsumerWidget {
  const InspectorRastTab({
    super.key,
    required this.heroId,
    required this.heroState,
    required this.derived,
    required this.resourceActivation,
  });

  final String heroId;
  final HeroState heroState;
  final DerivedStats derived;
  final HeroResourceActivation? resourceActivation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMagic = resourceActivation?.magic.isEnabled ?? false;
    final showDivine = resourceActivation?.divine.isEnabled ?? false;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodexSectionCard(
            title: 'Aktuelle Vitalwerte',
            child: Column(
              children: [
                _ReadOnlyVitalRow(
                  label: 'LeP',
                  current: heroState.currentLep,
                  max: derived.maxLep,
                ),
                _ReadOnlyVitalRow(
                  label: 'AuP',
                  current: heroState.currentAu,
                  max: derived.maxAu,
                ),
                if (showMagic)
                  _ReadOnlyVitalRow(
                    label: 'AsP',
                    current: heroState.currentAsp,
                    max: derived.maxAsp,
                  ),
                if (showDivine)
                  _ReadOnlyVitalRow(
                    label: 'KaP',
                    current: heroState.currentKap,
                    max: derived.maxKap,
                  ),
                _ReadOnlyVitalRow(
                  label: 'Erschöpfung',
                  current: heroState.erschoepfung,
                  max: null,
                ),
                _ReadOnlyVitalRow(
                  label: 'Überanstrengung',
                  current: heroState.ueberanstrengung,
                  max: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CodexSectionCard(
            title: 'Rast',
            child: RestPanel(heroId: heroId),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyVitalRow extends StatelessWidget{
  const _ReadOnlyVitalRow({
    required this.label,
    required this.current,
    required this.max,
  });

  final String label;
  final int current;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: codex.brass,
              ),
            ),
          ),
          Text(
            max == null ? '$current' : '$current / $max',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
