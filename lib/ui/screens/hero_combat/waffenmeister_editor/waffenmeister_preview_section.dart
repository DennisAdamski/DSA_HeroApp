import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Zusammenfassungs-Sektion des Waffenmeister-Editors.
///
/// Zeigt eine kompakte Uebersicht aller verteilten Boni
/// und Hinweistexte zu Voraussetzungen.
class WaffenmeisterPreviewSection extends StatelessWidget {
  const WaffenmeisterPreviewSection({
    super.key,
    required this.draft,
    required this.autoCost,
    required this.allocated,
    required this.pointCostForBonus,
  });

  final WaffenmeisterConfig draft;
  final int autoCost;
  final int allocated;
  final int Function(WaffenmeisterBonus bonus) pointCostForBonus;

  @override
  Widget build(BuildContext context) {
    final totalUsed = autoCost + allocated;
    final theme = Theme.of(context);

    return WeaponEditorSectionCard(
      title: 'Zusammenfassung',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Waffenmeister-Bezeichnung
          if (draft.weaponType.isNotEmpty)
            Text(
              'Waffenmeister (${draft.weaponType})',
              style: theme.textTheme.titleSmall,
            ),
          if (draft.styleName.isNotEmpty)
            Text(
              'Stil: ${draft.styleName}',
              style: theme.textTheme.bodySmall,
            ),
          if (draft.masterName.isNotEmpty)
            Text(
              'Lehrmeister: ${draft.masterName}',
              style: theme.textTheme.bodySmall,
            ),
          if (draft.additionalWeaponTypes.isNotEmpty)
            Text(
              'Weitere Waffen: ${draft.additionalWeaponTypes.join(", ")}',
              style: theme.textTheme.bodySmall,
            ),
          const Divider(height: 16),

          // Punkteverteilung
          Text(
            'Punkte: $totalUsed / 15 (Grundkosten: $autoCost, Boni: $allocated)',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),

          // Bonus-Liste
          if (draft.bonuses.isEmpty)
            Text(
              'Noch keine Boni verteilt.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...draft.bonuses.map((bonus) {
              final cost = pointCostForBonus(bonus);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_bonusDescription(bonus))),
                    Text('$cost Pkt', style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            }),
          const Divider(height: 16),

          // Eigenschafts-Anforderungen
          Text(
            'Voraussetzungen:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${draft.requiredAttribute1} ${draft.requiredAttribute1Value}, '
            '${draft.requiredAttribute2} ${draft.requiredAttribute2Value} '
            '(Summe: ${draft.requiredAttribute1Value + draft.requiredAttribute2Value})',
          ),
          const SizedBox(height: 4),
          Text(
            'TaW 18 im Kampftalent, Waffenspezialisierung, '
            '2.500 AP in Kampf-SF, 400 AP Kosten.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _bonusDescription(WaffenmeisterBonus bonus) {
    switch (bonus.type) {
      case WaffenmeisterBonusType.maneuverReduction:
        final target = bonus.targetManeuver.isNotEmpty
            ? bonus.targetManeuver
            : 'Manöver';
        return '$target: Erschwernis -${bonus.value}';
      case WaffenmeisterBonusType.iniBonus:
        return 'INI +${bonus.value}';
      case WaffenmeisterBonusType.tpKkReduction:
        return 'TP/KK -1/-1';
      case WaffenmeisterBonusType.atWmBonus:
        return 'AT-WM +${bonus.value}';
      case WaffenmeisterBonusType.paWmBonus:
        return 'PA-WM +${bonus.value}';
      case WaffenmeisterBonusType.ausfallPenaltyRemoval:
        return 'Ausfall: Erstangriff ohne Erschwernis';
      case WaffenmeisterBonusType.additionalManeuver:
        final target = bonus.targetManeuver.isNotEmpty
            ? bonus.targetManeuver
            : 'Manöver';
        return 'Zusätzliches Manöver: $target';
      case WaffenmeisterBonusType.rangeIncrease:
        return 'Reichweite +${bonus.value * 10}%';
      case WaffenmeisterBonusType.gezielterSchussReduction:
        return 'Gezielter Schuss: Erschwernis -1';
      case WaffenmeisterBonusType.reloadTimeHalved:
        return 'Ladezeit halbiert (Armbrust)';
      case WaffenmeisterBonusType.customAdvantage:
        return bonus.description.isNotEmpty
            ? bonus.description
            : 'Sonderbonus';
    }
  }
}
