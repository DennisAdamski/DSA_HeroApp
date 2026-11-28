import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Bearbeitet Schadensprofil und KK-Skalierung einer Waffe.
///
/// KK-Basis und KK-Schwelle sind die Grundwerte der unveränderten Waffe; sie
/// bestimmen auch INI/GE. Verbesserungen der Waffe (z. B. meisterlich
/// geschmiedet) werden getrennt als Mod erfasst und wirken nur auf TP/KK.
class WeaponDamageSection extends StatelessWidget {
  /// Erstellt die Schadens-Sektion des Waffen-Editors.
  const WeaponDamageSection({
    super.key,
    required this.tpDiceCountController,
    required this.tpFlatController,
    required this.kkBaseController,
    required this.kkThresholdController,
    required this.kkBaseModController,
    required this.kkThresholdModController,
    required this.onTpDiceCountChanged,
    required this.onTpFlatChanged,
    required this.onKkBaseChanged,
    required this.onKkThresholdChanged,
    required this.onKkBaseModChanged,
    required this.onKkThresholdModChanged,
  });

  final TextEditingController tpDiceCountController;
  final TextEditingController tpFlatController;
  final TextEditingController kkBaseController;
  final TextEditingController kkThresholdController;

  /// Verbesserung der KK-Basis durch die Waffe selbst.
  final TextEditingController kkBaseModController;

  /// Verbesserung der KK-Schwelle durch die Waffe selbst.
  final TextEditingController kkThresholdModController;
  final ValueChanged<int> onTpDiceCountChanged;
  final ValueChanged<int> onTpFlatChanged;
  final ValueChanged<int> onKkBaseChanged;
  final ValueChanged<int> onKkThresholdChanged;

  /// Meldet eine geänderte Verbesserung der KK-Basis.
  final ValueChanged<int> onKkBaseModChanged;

  /// Meldet eine geänderte Verbesserung der KK-Schwelle.
  final ValueChanged<int> onKkThresholdModChanged;

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
          _numberField(
            keyName: 'combat-weapon-form-kk-base-mod',
            label: 'KK-Basis Mod',
            controller: kkBaseModController,
            onChanged: onKkBaseModChanged,
          ),
          _numberField(
            keyName: 'combat-weapon-form-kk-threshold-mod',
            label: 'KK-Schwelle Mod',
            controller: kkThresholdModController,
            onChanged: onKkThresholdModChanged,
          ),
          Text(
            'KK-Basis und -Schwelle sind die Grundwerte der Waffe und '
            'bestimmen auch INI/GE. Verbesserungen der Waffe, z. B. '
            'meisterlich geschmiedet (−1/−1), als Mod eintragen; sie wirken '
            'nur auf TP/KK.',
            key: const ValueKey<String>('combat-weapon-form-kk-mod-hint'),
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
