part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatSpecialRulesSubtab on _HeroCombatTabState {
  Widget _buildSpecialRulesSubTab(HeroSheet hero, HeroState state) {
    final rules = _draftCombatConfig.specialRules;
    final armor = _draftCombatConfig.armor;
    final parsed = parseModifierTextsForHero(hero);
    final axxeleratusActive = isAxxeleratusEffectActive(
      sheet: hero,
      state: state,
    );
    final hasFlinkFromVorteile = parsed.hasFlinkFromVorteile;
    final hasBehaebigFromNachteile = parsed.hasBehaebigFromNachteile;
    final isEditing = _editController.isEditing;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ruleToggle(
          label: 'Kampfreflexe',
          value: rules.kampfreflexe,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(kampfreflexe: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Kampfgespuer',
          value: rules.kampfgespuer,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(kampfgespuer: value),
            );
            _markFieldChanged();
          },
        ),
        _specialAbilityCard(
          title: 'Schnellziehen',
          value: rules.schnellziehen,
          isEditing: isEditing,
          isActive: rules.schnellziehen || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellziehen,
          keyName: 'combat-special-rule-schnellziehen',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellziehen: value),
            );
            _markFieldChanged();
          },
        ),
        _specialAbilityCard(
          title: 'Schnellladen (Bogen)',
          value: rules.schnellladenBogen,
          isEditing: isEditing,
          isActive: rules.schnellladenBogen || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellladenBogen,
          keyName: 'combat-special-rule-schnellladen-bogen',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellladenBogen: value),
            );
            _markFieldChanged();
          },
        ),
        _specialAbilityCard(
          title: 'Schnellladen (Armbrust)',
          value: rules.schnellladenArmbrust,
          isEditing: isEditing,
          isActive: rules.schnellladenArmbrust || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellladenArmbrust,
          keyName: 'combat-special-rule-schnellladen-armbrust',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellladenArmbrust: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen I',
          value: rules.ausweichenI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen II',
          value: rules.ausweichenII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen III',
          value: rules.ausweichenIII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenIII: value),
            );
            _markFieldChanged();
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<int>(
              key: const ValueKey<String>('combat-armor-global-training-level'),
              initialValue: armor.globalArmorTrainingLevel,
              decoration: const InputDecoration(
                labelText: 'Ruestungsgewoehnung',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: SizedBox.shrink()),
                DropdownMenuItem(value: 1, child: Text('I')),
                DropdownMenuItem(value: 2, child: Text('II')),
                DropdownMenuItem(value: 3, child: Text('III')),
              ],
              onChanged: !isEditing
                  ? null
                  : (value) {
                      _draftCombatConfig = _draftCombatConfig.copyWith(
                        armor: _draftCombatConfig.armor.copyWith(
                          globalArmorTrainingLevel: value ?? 0,
                        ),
                      );
                      _markFieldChanged();
                    },
            ),
          ),
        ),
        _ruleToggle(
          label: 'Linkhand',
          value: rules.linkhandActive,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(linkhandActive: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Schildkampf I',
          value: rules.schildkampfI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schildkampfI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Schildkampf II',
          value: rules.schildkampfII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schildkampfII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Parierwaffen I',
          value: rules.parierwaffenI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(parierwaffenI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Parierwaffen II',
          value: rules.parierwaffenII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(parierwaffenII: value),
            );
            _markFieldChanged();
          },
        ),
        Card(
          child: ListTile(
            title: const Text('Flink'),
            subtitle: Text(
              hasFlinkFromVorteile ? 'Aus Vorteile erkannt' : 'Nicht erkannt',
            ),
            trailing: Chip(
              label: Text(hasFlinkFromVorteile ? 'Aktiv' : 'Inaktiv'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Behaebig'),
            subtitle: Text(
              hasBehaebigFromNachteile
                  ? 'Aus Nachteile erkannt'
                  : 'Nicht erkannt',
            ),
            trailing: Chip(
              label: Text(hasBehaebigFromNachteile ? 'Aktiv' : 'Inaktiv'),
            ),
          ),
        ),
        _ruleToggle(
          label: 'Klingentaenzer (2W6 auf Ini)',
          value: rules.klingentaenzer,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(klingentaenzer: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Aufmerksamkeit (fester INI-Zusatz)',
          value: rules.aufmerksamkeit,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(aufmerksamkeit: value),
            );
            _markFieldChanged();
          },
        ),
      ],
    );
  }

  Widget _resultChip(String label, int value) {
    return Chip(label: Text('$label: $value'));
  }

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
