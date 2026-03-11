part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatSpecialRulesSubtab on _HeroCombatTabState {
  Widget _ruleToggle({
    required String label,
    required bool value,
    required bool isEditing,
    required void Function(bool value) onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: isEditing ? onChanged : null,
      ),
    );
  }

  Widget _specialAbilityCard({
    required String title,
    required bool value,
    required bool isEditing,
    required bool isActive,
    required bool isTemporaryFromAxx,
    required String keyName,
    required void Function(bool value) onChanged,
  }) {
    final activeLabel = isTemporaryFromAxx
        ? 'Aktiv durch Axxeleratus'
        : 'Aktiv';
    final inactiveLabel = value ? 'Erlernt' : 'Inaktiv';
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            key: ValueKey<String>(keyName),
            title: Text(title),
            subtitle: Text(
              isTemporaryFromAxx ? 'Temporär aktiv' : 'Dauerhaft erlernbar',
            ),
            value: value,
            onChanged: isEditing ? onChanged : null,
          ),
          ListTile(
            dense: true,
            title: const Text('Status'),
            trailing: Chip(label: Text(isActive ? activeLabel : inactiveLabel)),
          ),
        ],
      ),
    );
  }
}
