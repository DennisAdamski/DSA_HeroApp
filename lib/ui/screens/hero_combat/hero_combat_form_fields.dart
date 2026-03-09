part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatFormFields on _HeroCombatTabState {
  Widget _numberInput({
    required String label,
    required String keyName,
    required bool isEditing,
    required void Function(int value) onChanged,
  }) {
    final controller = _controllerFor(keyName, '0');
    return SizedBox(
      width: 140,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        readOnly: !isEditing,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: !isEditing
            ? null
            : (raw) {
                final parsed = int.tryParse(raw.trim()) ?? 0;
                onChanged(parsed);
              },
      ),
    );
  }

  Widget _dialogNumberField({
    required TextEditingController controller,
    required String keyName,
    required String label,
  }) {
    return SizedBox(
      width: 130,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
