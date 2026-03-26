import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Bearbeitet die Stammdaten einer Waffe.
class WeaponBasicInfoSection extends StatelessWidget {
  /// Erstellt die Stammdaten-Sektion des Waffen-Editors.
  const WeaponBasicInfoSection({
    super.key,
    required this.nameController,
    required this.artifactDescriptionController,
    required this.combatType,
    required this.weaponType,
    required this.distanceClassController,
    required this.isOneHanded,
    required this.isArtifact,
    required this.weaponTypeOptions,
    required this.talentOptions,
    required this.selectedTalentId,
    required this.onNameChanged,
    required this.onCombatTypeChanged,
    required this.onWeaponTypeChanged,
    required this.onDistanceClassChanged,
    required this.onTalentChanged,
    required this.onOneHandedChanged,
    required this.onArtifactChanged,
    required this.onArtifactDescriptionChanged,
  });

  final TextEditingController nameController;
  final TextEditingController artifactDescriptionController;
  final TextEditingController distanceClassController;
  final WeaponCombatType combatType;
  final String weaponType;
  final bool isOneHanded;
  final bool isArtifact;
  final List<String> weaponTypeOptions;
  final List<TalentDef> talentOptions;
  final String selectedTalentId;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<WeaponCombatType> onCombatTypeChanged;
  final ValueChanged<String> onWeaponTypeChanged;
  final ValueChanged<String> onDistanceClassChanged;
  final ValueChanged<String> onTalentChanged;
  final ValueChanged<bool> onOneHandedChanged;
  final ValueChanged<bool> onArtifactChanged;
  final ValueChanged<String> onArtifactDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return WeaponEditorSectionCard(
      title: 'Stammdaten',
      subtitle:
          'Waffentalent und Waffenart bleiben nach Kampftyp und Vorlage gefiltert.',
      child: Column(
        children: [
          TextField(
            key: const ValueKey<String>('combat-weapon-form-name'),
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => onNameChanged(value.trim()),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<WeaponCombatType>(
                  key: const ValueKey<String>('combat-weapon-form-combat-type'),
                  initialValue: combatType,
                  decoration: const InputDecoration(
                    labelText: 'Kampftyp',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: WeaponCombatType.melee,
                      child: Text('Nahkampf'),
                    ),
                    DropdownMenuItem(
                      value: WeaponCombatType.ranged,
                      child: Text('Fernkampf'),
                    ),
                  ],
                  onChanged: (value) {
                    onCombatTypeChanged(value ?? WeaponCombatType.melee);
                  },
                ),
              ),
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey<String>('combat-weapon-form-weapon-type'),
                  initialValue: weaponTypeOptions.contains(weaponType)
                      ? weaponType
                      : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Waffenart',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('-')),
                    ...weaponTypeOptions.map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => onWeaponTypeChanged(value ?? ''),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey<String>('combat-weapon-form-talent'),
                  initialValue:
                      talentOptions.any(
                        (talent) => talent.id == selectedTalentId,
                      )
                      ? selectedTalentId
                      : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Waffentalent',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('-')),
                    ...talentOptions.map(
                      (talent) => DropdownMenuItem<String>(
                        value: talent.id,
                        child: Text(
                          talent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => onTalentChanged(value ?? ''),
                ),
              ),
              if (combatType == WeaponCombatType.melee)
                SizedBox(
                  width: 132,
                  child: TextField(
                    key: const ValueKey<String>('combat-weapon-form-dk'),
                    controller: distanceClassController,
                    decoration: const InputDecoration(
                      labelText: 'DK',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => onDistanceClassChanged(value.trim()),
                  ),
                ),
              if (combatType == WeaponCombatType.melee)
                SizedBox(
                  width: 180,
                  child: SwitchListTile(
                    key: const ValueKey<String>(
                      'combat-weapon-form-one-handed',
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Einhändig'),
                    value: isOneHanded,
                    onChanged: onOneHandedChanged,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey<String>('combat-weapon-form-artifact'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Artefakt'),
            value: isArtifact,
            onChanged: onArtifactChanged,
          ),
          TextField(
            key: const ValueKey<String>(
              'combat-weapon-form-artifact-description',
            ),
            controller: artifactDescriptionController,
            enabled: isArtifact,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Artefaktbeschreibung',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => onArtifactDescriptionChanged(value.trim()),
          ),
        ],
      ),
    );
  }
}
