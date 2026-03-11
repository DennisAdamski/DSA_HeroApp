import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Bonus-Verteilungs-Sektion des Waffenmeister-Editors.
///
/// Zeigt den 15-Punkte-Baukasten mit allen Bonus-Typen und erlaubt
/// das Hinzufuegen, Bearbeiten und Entfernen einzelner Boni.
class WaffenmeisterBonusSection extends StatelessWidget {
  const WaffenmeisterBonusSection({
    super.key,
    required this.draft,
    required this.catalog,
    required this.combatTalents,
    required this.autoCost,
    required this.allocated,
    required this.remaining,
    required this.onAddBonus,
    required this.onUpdateBonus,
    required this.onRemoveBonus,
  });

  final WaffenmeisterConfig draft;
  final RulesCatalog catalog;
  final List<TalentDef> combatTalents;
  final int autoCost;
  final int allocated;
  final int remaining;
  final void Function(WaffenmeisterBonus bonus) onAddBonus;
  final void Function(int index, WaffenmeisterBonus bonus) onUpdateBonus;
  final void Function(int index) onRemoveBonus;

  @override
  Widget build(BuildContext context) {
    return WeaponEditorSectionCard(
      title: 'Bonus-Verteilung',
      subtitle: 'Verteile Punkte auf Kampfvorteile.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bestehende Boni
          ...List.generate(draft.bonuses.length, (index) {
            final bonus = draft.bonuses[index];
            return _buildBonusCard(context, index, bonus);
          }),
          const SizedBox(height: 8),
          // Hinzufuegen-Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _addBonusChip(
                context,
                label: 'Manöver -1',
                type: WaffenmeisterBonusType.maneuverReduction,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'INI +1',
                type: WaffenmeisterBonusType.iniBonus,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'AT-WM +1',
                type: WaffenmeisterBonusType.atWmBonus,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'PA-WM +1',
                type: WaffenmeisterBonusType.paWmBonus,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'TP/KK -1/-1',
                type: WaffenmeisterBonusType.tpKkReduction,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'Ausfall ohne Malus',
                type: WaffenmeisterBonusType.ausfallPenaltyRemoval,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'Zusatz-Manöver',
                type: WaffenmeisterBonusType.additionalManeuver,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'Reichweite +10%',
                type: WaffenmeisterBonusType.rangeIncrease,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'Gez. Schuss -1',
                type: WaffenmeisterBonusType.gezielterSchussReduction,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'Ladezeit ½',
                type: WaffenmeisterBonusType.reloadTimeHalved,
                defaultValue: 1,
              ),
              _addBonusChip(
                context,
                label: 'Sonderbonus',
                type: WaffenmeisterBonusType.customAdvantage,
                defaultValue: 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addBonusChip(
    BuildContext context, {
    required String label,
    required WaffenmeisterBonusType type,
    required int defaultValue,
  }) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 16),
      label: Text(label),
      onPressed: () {
        onAddBonus(WaffenmeisterBonus(
          type: type,
          value: defaultValue,
        ));
      },
    );
  }

  Widget _buildBonusCard(
    BuildContext context,
    int index,
    WaffenmeisterBonus bonus,
  ) {
    final label = _bonusLabel(bonus);
    final cost = _displayPointCost(bonus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ),
                Chip(
                  label: Text('$cost Pkt'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onRemoveBonus(index),
                ),
              ],
            ),
            // Wert-Steuerung fuer skalierbare Boni
            if (_isScalable(bonus.type)) _buildValueStepper(index, bonus),
            // Manoever-Auswahl
            if (_needsManeuverTarget(bonus.type))
              _buildManeuverSelector(context, index, bonus),
            // Freitext fuer customAdvantage
            if (bonus.type == WaffenmeisterBonusType.customAdvantage)
              _buildCustomAdvantageFields(index, bonus),
          ],
        ),
      ),
    );
  }

  Widget _buildValueStepper(int index, WaffenmeisterBonus bonus) {
    final maxValue = _maxValueForType(bonus.type);
    return Row(
      children: [
        const Text('Wert: '),
        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: bonus.value > 1
              ? () => onUpdateBonus(index, bonus.copyWith(value: bonus.value - 1))
              : null,
        ),
        Text('${bonus.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: bonus.value < maxValue
              ? () => onUpdateBonus(index, bonus.copyWith(value: bonus.value + 1))
              : null,
        ),
      ],
    );
  }

  Widget _buildManeuverSelector(
    BuildContext context,
    int index,
    WaffenmeisterBonus bonus,
  ) {
    // Manoever aus Katalog sammeln
    final maneuvers = catalog.maneuvers
        .where((m) => m.gruppe == 'bewaffnet')
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DropdownButtonFormField<String>(
        initialValue: bonus.targetManeuver.isNotEmpty ? bonus.targetManeuver : null,
        decoration: const InputDecoration(
          labelText: 'Manöver',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: maneuvers.map((m) {
          final erschwernis = m.erschwernis.isNotEmpty
              ? ' (${m.erschwernis})'
              : '';
          return DropdownMenuItem(value: m.name, child: Text('${m.name}$erschwernis'));
        }).toList(growable: false),
        onChanged: (value) {
          onUpdateBonus(index, bonus.copyWith(targetManeuver: value ?? ''));
        },
      ),
    );
  }

  Widget _buildCustomAdvantageFields(int index, WaffenmeisterBonus bonus) {
    return Column(
      children: [
        const SizedBox(height: 4),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Beschreibung',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          controller: TextEditingController(text: bonus.description),
          onChanged: (value) {
            onUpdateBonus(index, bonus.copyWith(description: value));
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Punktekosten: '),
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: bonus.customPointCost > 2
                  ? () => onUpdateBonus(
                      index,
                      bonus.copyWith(customPointCost: bonus.customPointCost - 1),
                    )
                  : null,
            ),
            Text(
              '${bonus.customPointCost}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: bonus.customPointCost < 5
                  ? () => onUpdateBonus(
                      index,
                      bonus.copyWith(customPointCost: bonus.customPointCost + 1),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helfer
  // ---------------------------------------------------------------------------

  String _bonusLabel(WaffenmeisterBonus bonus) {
    switch (bonus.type) {
      case WaffenmeisterBonusType.maneuverReduction:
        final target = bonus.targetManeuver.isNotEmpty
            ? bonus.targetManeuver
            : 'Manöver';
        return '$target -${bonus.value}';
      case WaffenmeisterBonusType.iniBonus:
        return 'INI +${bonus.value}';
      case WaffenmeisterBonusType.tpKkReduction:
        return 'TP/KK -1/-1';
      case WaffenmeisterBonusType.atWmBonus:
        return 'AT-WM +${bonus.value}';
      case WaffenmeisterBonusType.paWmBonus:
        return 'PA-WM +${bonus.value}';
      case WaffenmeisterBonusType.ausfallPenaltyRemoval:
        return 'Ausfall: Erstangriff ohne Malus';
      case WaffenmeisterBonusType.additionalManeuver:
        final target = bonus.targetManeuver.isNotEmpty
            ? bonus.targetManeuver
            : 'Manöver';
        return 'Zusätzliches Manöver: $target';
      case WaffenmeisterBonusType.rangeIncrease:
        return 'Reichweite +${bonus.value * 10}%';
      case WaffenmeisterBonusType.gezielterSchussReduction:
        return 'Gezielter Schuss -1';
      case WaffenmeisterBonusType.reloadTimeHalved:
        return 'Ladezeit halbiert';
      case WaffenmeisterBonusType.customAdvantage:
        return bonus.description.isNotEmpty
            ? bonus.description
            : 'Sonderbonus';
    }
  }

  int _displayPointCost(WaffenmeisterBonus bonus) {
    switch (bonus.type) {
      case WaffenmeisterBonusType.maneuverReduction:
        return bonus.value.abs();
      case WaffenmeisterBonusType.iniBonus:
        return bonus.value * 3;
      case WaffenmeisterBonusType.tpKkReduction:
        return 2;
      case WaffenmeisterBonusType.atWmBonus:
        return bonus.value * 5;
      case WaffenmeisterBonusType.paWmBonus:
        return bonus.value * 5;
      case WaffenmeisterBonusType.ausfallPenaltyRemoval:
        return 2;
      case WaffenmeisterBonusType.additionalManeuver:
        return 5;
      case WaffenmeisterBonusType.rangeIncrease:
        return bonus.value;
      case WaffenmeisterBonusType.gezielterSchussReduction:
        return 2;
      case WaffenmeisterBonusType.reloadTimeHalved:
        return 5;
      case WaffenmeisterBonusType.customAdvantage:
        return bonus.customPointCost.clamp(2, 5);
    }
  }

  bool _isScalable(WaffenmeisterBonusType type) {
    return type == WaffenmeisterBonusType.maneuverReduction ||
        type == WaffenmeisterBonusType.iniBonus ||
        type == WaffenmeisterBonusType.atWmBonus ||
        type == WaffenmeisterBonusType.paWmBonus ||
        type == WaffenmeisterBonusType.rangeIncrease;
  }

  bool _needsManeuverTarget(WaffenmeisterBonusType type) {
    return type == WaffenmeisterBonusType.maneuverReduction ||
        type == WaffenmeisterBonusType.additionalManeuver;
  }

  int _maxValueForType(WaffenmeisterBonusType type) {
    switch (type) {
      case WaffenmeisterBonusType.maneuverReduction:
        return 4; // Eines darf -4 haben
      case WaffenmeisterBonusType.iniBonus:
        return 2;
      case WaffenmeisterBonusType.atWmBonus:
        return 2;
      case WaffenmeisterBonusType.paWmBonus:
        return 2;
      case WaffenmeisterBonusType.rangeIncrease:
        return 2;
      default:
        return 1;
    }
  }
}
