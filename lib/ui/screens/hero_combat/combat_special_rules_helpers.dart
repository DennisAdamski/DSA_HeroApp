part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Gemeinsame UI-Helfer fuer die Sonderfertigkeiten im Kampfregeln-Tab.
extension _CombatSpecialRulesHelpers on _HeroCombatTabState {
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

  /// Baut Karten fuer katalogbasierte Kampf-Sonderfertigkeiten.
  List<Widget> _buildCatalogCombatSpecialAbilityCards({
    required RulesCatalog catalog,
    required CombatSpecialRules rules,
    required bool isEditing,
  }) {
    final styleAbilities = catalog.combatSpecialAbilities
        .where((entry) => entry.isUnarmedCombatStyle)
        .toList(growable: false);
    if (styleAbilities.isEmpty) {
      return const <Widget>[];
    }

    final widgets = <Widget>[
      const SizedBox(height: 12),
      Text(
        'Waffenlose Kampftechniken',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
    ];
    for (final ability in styleAbilities) {
      final isActive = rules.activeCombatSpecialAbilityIds.contains(ability.id);
      widgets.add(
        Card(
          child: Column(
            children: [
              SwitchListTile(
                key: ValueKey<String>('combat-special-ability-${ability.id}'),
                title: Text(ability.name),
                subtitle: Text(
                  ability.beschreibung.trim().isEmpty
                      ? 'Katalog-Sonderfertigkeit'
                      : ability.beschreibung.trim(),
                ),
                value: isActive,
                onChanged: !isEditing
                    ? null
                    : (value) {
                        final active = List<String>.from(
                          rules.activeCombatSpecialAbilityIds,
                        );
                        if (value) {
                          if (!active.contains(ability.id)) {
                            active.add(ability.id);
                          }
                        } else {
                          active.removeWhere((entry) => entry == ability.id);
                        }
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          specialRules: rules.copyWith(
                            activeCombatSpecialAbilityIds: active,
                          ),
                        );
                        _markFieldChanged();
                      },
              ),
              ListTile(
                dense: true,
                title: const Text('Status'),
                subtitle: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(isActive ? 'Aktiv' : 'Inaktiv')),
                    if (ability.kampfwertBoni.isNotEmpty)
                      Chip(
                        label: Text('Boni: ${ability.kampfwertBoni.length}'),
                      ),
                    if (ability.aktiviertManoeverIds.isNotEmpty)
                      Chip(
                        label: Text(
                          'Manöver: ${ability.aktiviertManoeverIds.length}',
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: 'Details',
                  onPressed: () => _showCombatSpecialAbilityDetailsDialog(
                    context: context,
                    ability: ability,
                  ),
                  icon: const Icon(Icons.info_outline),
                ),
              ),
              if (ability.id == 'ksf_gladiatorenstil')
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey<String>(
                      'combat-gladiator-style-talent',
                    ),
                    initialValue: rules.gladiatorStyleTalent.trim().isEmpty
                        ? null
                        : rules.gladiatorStyleTalent,
                    decoration: const InputDecoration(
                      labelText: 'Bonus-Talent',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'raufen', child: Text('Raufen')),
                      DropdownMenuItem(value: 'ringen', child: Text('Ringen')),
                    ],
                    onChanged: !isEditing
                        ? null
                        : (value) {
                            _draftCombatConfig = _draftCombatConfig.copyWith(
                              specialRules: rules.copyWith(
                                gladiatorStyleTalent: value ?? '',
                              ),
                            );
                            _markFieldChanged();
                          },
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

/// Oeffnet einen adaptiven Detaildialog fuer eine Kampf-Sonderfertigkeit.
Future<void> _showCombatSpecialAbilityDetailsDialog({
  required BuildContext context,
  required CombatSpecialAbilityDef ability,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _CombatSpecialAbilityDetailsDialog(ability: ability),
  );
}

/// Detaildialog fuer katalogbasierte Kampf-Sonderfertigkeiten.
class _CombatSpecialAbilityDetailsDialog extends StatelessWidget {
  const _CombatSpecialAbilityDetailsDialog({required this.ability});

  final CombatSpecialAbilityDef ability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(ability.name),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (ability.gruppe.trim().isNotEmpty)
                    Chip(label: Text('Gruppe: ${ability.gruppe.trim()}')),
                  if (ability.stilTyp.trim().isNotEmpty)
                    Chip(label: Text('Stil: ${ability.stilTyp.trim()}')),
                  if (ability.seite.trim().isNotEmpty)
                    Chip(label: Text('S. ${ability.seite.trim()}')),
                ],
              ),
              if (ability.beschreibung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Beschreibung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.beschreibung.trim()),
              ],
              if (ability.erklarungLang.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Lange Erklärung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.erklarungLang.trim()),
              ],
              if (ability.voraussetzungen.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Voraussetzungen', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.voraussetzungen.trim()),
              ],
              if (ability.verbreitung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Verbreitung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.verbreitung.trim()),
              ],
              if (ability.kosten.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Kosten', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.kosten.trim()),
              ],
              if (ability.kampfwertBoni.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Direkte Boni', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                ...ability.kampfwertBoni.map((bonus) {
                  final bonusParts = <String>[];
                  if (bonus.atBonus != 0) {
                    bonusParts.add(
                      'AT ${bonus.atBonus >= 0 ? '+' : ''}${bonus.atBonus}',
                    );
                  }
                  if (bonus.paBonus != 0) {
                    bonusParts.add(
                      'PA ${bonus.paBonus >= 0 ? '+' : ''}${bonus.paBonus}',
                    );
                  }
                  if (bonus.iniMod != 0) {
                    bonusParts.add(
                      'INI ${bonus.iniMod >= 0 ? '+' : ''}${bonus.iniMod}',
                    );
                  }
                  final target = bonus.giltFuerTalent.trim().isEmpty
                      ? 'allgemein'
                      : bonus.giltFuerTalent.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('$target: ${bonusParts.join(', ')}'),
                  );
                }),
              ],
              if (ability.aktiviertManoeverIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Aktivierte Manöver', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.aktiviertManoeverIds.join(', ')),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
