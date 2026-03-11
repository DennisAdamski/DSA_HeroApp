import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Bearbeitet Schadensprofil und KK-Skalierung einer Waffe.
class WeaponDamageSection extends StatelessWidget {
  /// Erstellt die Schadens-Sektion des Waffen-Editors.
  const WeaponDamageSection({
    super.key,
    required this.tpDiceCountController,
    required this.tpFlatController,
    required this.kkBaseController,
    required this.kkThresholdController,
    required this.onTpDiceCountChanged,
    required this.onTpFlatChanged,
    required this.onKkBaseChanged,
    required this.onKkThresholdChanged,
  });

  final TextEditingController tpDiceCountController;
  final TextEditingController tpFlatController;
  final TextEditingController kkBaseController;
  final TextEditingController kkThresholdController;
  final ValueChanged<int> onTpDiceCountChanged;
  final ValueChanged<int> onTpFlatChanged;
  final ValueChanged<int> onKkBaseChanged;
  final ValueChanged<int> onKkThresholdChanged;

  @override
  Widget build(BuildContext context) {
    return WeaponEditorSectionCard(
      title: 'Schadensprofil',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _numberField(
            keyName: 'combat-weapon-form-dice-count',
            label: 'Wuerfel',
            controller: tpDiceCountController,
            onChanged: onTpDiceCountChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-tp-flat',
            label: 'TP Wert',
            controller: tpFlatController,
            onChanged: onTpFlatChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-kk-base',
            label: 'KK-Basis',
            controller: kkBaseController,
            onChanged: onKkBaseChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-kk-threshold',
            label: 'KK-Schwelle',
            controller: kkThresholdController,
            onChanged: onKkThresholdChanged,
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 132,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (raw) {
          final parsed = int.tryParse(raw.trim());
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      ),
    );
  }
}
