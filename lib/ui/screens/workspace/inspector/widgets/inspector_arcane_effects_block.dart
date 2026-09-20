import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_display_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Darstellende Chips laufender Zaubereffekte.
///
/// Bekommt alle Werte als Parameter, damit die Spielansicht sie aus ihrem
/// bereits gelesenen Snapshot befuellen kann, statt Held, Zustand und
/// Kampfvorschau ein zweites Mal zu beobachten. Die Zusammenstellung der
/// Chips selbst liegt in `active_spell_display_rules.dart`.
class InspectorArcaneEffectsView extends StatelessWidget {
  /// Erstellt die Chipliste fuer die uebergebenen Werte.
  const InspectorArcaneEffectsView({
    super.key,
    required this.sheet,
    required this.state,
    required this.combat,
    this.onVerwalten,
    this.zeigeLeerhinweis = true,
  });

  /// Heldenbogen; `null` waehrend des Ladens.
  final HeroSheet? sheet;

  /// Laufzeitzustand; `null` waehrend des Ladens.
  final HeroState? state;

  /// Kampfvorschau; `null` waehrend des Ladens.
  final CombatPreviewStats? combat;

  /// Oeffnet die Verwaltung. `null` laesst die Schaltflaeche weg — die
  /// Spielansicht traegt ihre Aktion im Abschnittskopf.
  final VoidCallback? onVerwalten;

  /// Ob der Leerzustand hier erklaert wird. Der Magie-Tab setzt `false`,
  /// weil seine Karte denselben Satz bereits als Unterzeile traegt.
  final bool zeigeLeerhinweis;

  @override
  Widget build(BuildContext context) {
    final chips = buildActiveSpellEffectChips(
      sheet: sheet,
      state: state,
      combat: combat,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onVerwalten != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('workspace-active-spells-open'),
              onPressed: onVerwalten,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(chips.isEmpty ? 'Effekte hinzufügen' : 'Verwalten'),
            ),
          ),
        if (chips.isEmpty && zeigeLeerhinweis)
          Text(
            'Keine aktiven Effekte – Fremdzauber können hier hinzugefügt '
            'werden.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          if (onVerwalten != null) const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final chip in chips)
                Chip(
                  key: ValueKey<String>('arcane-effect-chip-${chip.effectId}'),
                  avatar: Icon(
                    chip.isExpired ? Icons.timer_off_outlined : Icons.bolt,
                    size: 16,
                  ),
                  label: Text(
                    describeActiveSpellEffectChip(chip),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Block fuer aktive arkane Effekte (eigene oder fremde Zauber/Liturgien).
///
/// Wird im Magie-Tab eingebettet und bleibt der Consumer-Wrapper um
/// [InspectorArcaneEffectsView]. Effekte werden ueber den
/// `showActiveSpellEffectsDialog` verwaltet – sowohl bei Magiern als auch
/// bei nicht-magischen Helden, die durch Fremdzauber betroffen sind.
class InspectorArcaneEffectsBlock extends ConsumerWidget {
  const InspectorArcaneEffectsBlock({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroSheet = ref.watch(heroByIdProvider(heroId));
    final heroState = ref.watch(heroStateProvider(heroId)).valueOrNull;
    final combat = ref
        .watch(heroComputedProvider(heroId))
        .valueOrNull
        ?.combatPreviewStats;
    final chips = buildActiveSpellEffectChips(
      sheet: heroSheet,
      state: heroState,
      combat: combat,
    );

    return CodexSectionCard(
      title: 'Aktive Effekte',
      subtitle: chips.isEmpty
          ? 'Keine aktiven Effekte – Fremdzauber können hier hinzugefügt werden.'
          : null,
      child: InspectorArcaneEffectsView(
        sheet: heroSheet,
        state: heroState,
        combat: combat,
        zeigeLeerhinweis: false,
        onVerwalten: () =>
            showActiveSpellEffectsDialog(context: context, heroId: heroId),
      ),
    );
  }
}
