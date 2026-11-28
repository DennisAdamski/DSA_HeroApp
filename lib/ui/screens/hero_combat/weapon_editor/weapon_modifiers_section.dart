import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Bearbeitet Waffenmodifikatoren und Haltbarkeit.
///
/// BF und die WM-Felder sind die Grundwerte der unveränderten Waffe; die
/// Mod-Felder daneben nehmen Verbesserungen der Waffe selbst auf (z. B.
/// meisterlich geschmiedet BF −1, WM AT +1).
class WeaponModifiersSection extends StatelessWidget {
  /// Erstellt die Modifikatoren-Sektion des Waffen-Editors.
  const WeaponModifiersSection({
    super.key,
    required this.combatType,
    required this.breakFactorController,
    required this.breakFactorModController,
    required this.iniModController,
    required this.iniModModController,
    required this.wmAtController,
    required this.wmAtModController,
    required this.wmPaController,
    required this.wmPaModController,
    required this.beTalentModController,
    required this.onBreakFactorChanged,
    required this.onBreakFactorModChanged,
    required this.onIniModChanged,
    required this.onIniModModChanged,
    required this.onWmAtChanged,
    required this.onWmAtModChanged,
    required this.onWmPaChanged,
    required this.onWmPaModChanged,
    required this.onBeTalentModChanged,
  });

  final WeaponCombatType combatType;
  final TextEditingController breakFactorController;

  /// Verbesserung des Bruchfaktors durch die Waffe selbst.
  final TextEditingController breakFactorModController;
  final TextEditingController iniModController;

  /// Verbesserung des INI-Modifikators durch die Waffe selbst.
  final TextEditingController iniModModController;
  final TextEditingController wmAtController;

  /// Verbesserung des AT-Modifikators durch die Waffe selbst.
  final TextEditingController wmAtModController;
  final TextEditingController wmPaController;

  /// Verbesserung des PA-Modifikators durch die Waffe selbst.
  final TextEditingController wmPaModController;
  final TextEditingController beTalentModController;
  final ValueChanged<int> onBreakFactorChanged;
  final ValueChanged<int> onBreakFactorModChanged;
  final ValueChanged<int> onIniModChanged;
  final ValueChanged<int> onIniModModChanged;
  final ValueChanged<int> onWmAtChanged;
  final ValueChanged<int> onWmAtModChanged;
  final ValueChanged<int> onWmPaChanged;
  final ValueChanged<int> onWmPaModChanged;
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
            keyName: 'combat-weapon-form-bf-mod',
            label: 'BF Mod',
            controller: breakFactorModController,
            onChanged: onBreakFactorModChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-wm-at',
            label: 'WM AT',
            controller: wmAtController,
            onChanged: onWmAtChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-wm-at-mod',
            label: 'WM AT Mod',
            controller: wmAtModController,
            onChanged: onWmAtModChanged,
          ),
          if (combatType == WeaponCombatType.melee) ...[
            _numberField(
              keyName: 'combat-weapon-form-wm-pa',
              label: 'WM PA',
              controller: wmPaController,
              onChanged: onWmPaChanged,
            ),
            _numberField(
              keyName: 'combat-weapon-form-wm-pa-mod',
              label: 'WM PA Mod',
              controller: wmPaModController,
              onChanged: onWmPaModChanged,
            ),
          ],
          _numberField(
            keyName: 'combat-weapon-form-ini-mod',
            label: 'WM Ini',
            controller: iniModController,
            onChanged: onIniModChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-ini-mod-mod',
            label: 'WM Ini Mod',
            controller: iniModModController,
            onChanged: onIniModModChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-be-talent-mod',
            label: 'BE',
            controller: beTalentModController,
            onChanged: onBeTalentModChanged,
          ),
          Text(
            'BF und WM sind die Werte der unveränderten Waffe. '
            'Verbesserungen der Waffe, z. B. meisterlich geschmiedet '
            '(BF −1, WM AT +1), als Mod eintragen.',
            key: const ValueKey<String>('combat-weapon-form-wm-mod-hint'),
            style: Theme.of(context).textTheme.bodySmall,
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
