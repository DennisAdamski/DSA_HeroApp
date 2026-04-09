part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Gemeinsame Helfer fuer den Kampf-Preview (INI-Wurf-Editor).
extension _HeroCombatCalculatorHelpers on _HeroCombatTabState {
  /// Baut den globalen Editor fuer den aktuellen INI-Wurf.
  Widget _initiativeRollEditor(CombatPreviewStats preview) {
    final maxRoll = preview.iniDiceCount * 6;
    final isAuto = _draftCombatConfig.specialRules.aufmerksamkeit;
    final effectiveRoll = _effectiveIniRollForConfig(_draftCombatConfig);
    final controller = _controllerFor(
      'combat-active-weapon-info-ini-roll',
      effectiveRoll.toString(),
    );
    final desiredText = effectiveRoll.toString();
    if (controller.text != desiredText) {
      controller.value = TextEditingValue(
        text: desiredText,
        selection: TextSelection.collapsed(offset: desiredText.length),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: TextField(
            key: const ValueKey<String>('combat-active-weapon-info-ini-roll'),
            controller: controller,
            readOnly: isAuto,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'INI-Wurf (0-$maxRoll)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: isAuto
                ? null
                : (raw) {
                    final parsed = int.tryParse(raw.trim()) ?? 0;
                    _setTemporaryIniRoll(parsed);
                  },
          ),
        ),
        if (isAuto)
          Chip(label: Text('Aufmerksamkeit aktiv: automatisch $maxRoll')),
      ],
    );
  }
}
