import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Bearbeitet Waffenmodifikatoren und Haltbarkeit.
class WeaponModifiersSection extends StatelessWidget {
  /// Erstellt die Modifikatoren-Sektion des Waffen-Editors.
  const WeaponModifiersSection({
    super.key,
    required this.combatType,
    required this.breakFactorController,
    required this.iniModController,
    required this.wmAtController,
    required this.wmPaController,
    required this.beTalentModController,
    required this.onBreakFactorChanged,
    required this.onIniModChanged,
    required this.onWmAtChanged,
    required this.onWmPaChanged,
    required this.onBeTalentModChanged,
  });

  final WeaponCombatType combatType;
  final TextEditingController breakFactorController;
  final TextEditingController iniModController;
  final TextEditingController wmAtController;
  final TextEditingController wmPaController;
  final TextEditingController beTalentModController;
  final ValueChanged<int> onBreakFactorChanged;
  final ValueChanged<int> onIniModChanged;
  final ValueChanged<int> onWmAtChanged;
  final ValueChanged<int> onWmPaChanged;
  final ValueChanged<int> onBeTalentModChanged;

  @override
  Widget build(BuildContext context) {
    return WeaponEditorSectionCard(
      title: 'Modifikatoren',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _numberField(
            keyName: 'combat-weapon-form-bf',
            label: 'BF',
            controller: breakFactorController,
            onChanged: onBreakFactorChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-wm-at',
            label: 'WM AT',
            controller: wmAtController,
            onChanged: onWmAtChanged,
          ),
          if (combatType == WeaponCombatType.melee)
            _numberField(
              keyName: 'combat-weapon-form-wm-pa',
              label: 'WM PA',
              controller: wmPaController,
              onChanged: onWmPaChanged,
            ),
          _numberField(
            keyName: 'combat-weapon-form-ini-mod',
            label: 'WM Ini',
            controller: iniModController,
            onChanged: onIniModChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-be-talent-mod',
            label: 'BE',
            controller: beTalentModController,
            onChanged: onBeTalentModChanged,
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
