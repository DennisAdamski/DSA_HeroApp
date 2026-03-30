part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Katalog-SF, die bereits separat über feste UI- oder Regelmodule gepflegt werden.
const Set<String> _hardcodedCatalogCombatSpecialAbilityIds = <String>{
  'ksf_aufmerksamkeit',
  'ksf_ausweichen_i',
  'ksf_ausweichen_ii',
  'ksf_ausweichen_iii',
  'ksf_kampfgespuer',
  'ksf_kampfreflexe',
  'ksf_klingentaenzer',
  'ksf_linkhand',
  'ksf_parierwaffen_i',
  'ksf_parierwaffen_ii',
  'ksf_ruestungsgewoehnung_i',
  'ksf_ruestungsgewoehnung_ii',
  'ksf_ruestungsgewoehnung_iii',
  'ksf_schildkampf_i',
  'ksf_schildkampf_ii',
  'ksf_schnellziehen',
  'ksf_schnellladen_bogen',
  'ksf_schnellladen_armbrust',
  'ksf_waffenmeister',
  'ksf_waffenspezialisierung',
};

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
    final maneuverIds = catalog.maneuvers
        .map((entry) => entry.id.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
    final styleAbilities = <CombatSpecialAbilityDef>[];
    final genericAbilities = <CombatSpecialAbilityDef>[];

    for (final ability in catalog.combatSpecialAbilities) {
      if (ability.isUnarmedCombatStyle) {
        styleAbilities.add(ability);
        continue;
      }

      final duplicateManeuverId = canonicalManeuverIdFromName(
        ability.name,
        catalogManeuvers: catalog.maneuvers,
      );
      final isManeuverDuplicate = maneuverIds.contains(duplicateManeuverId);
      final isHardcoded = _hardcodedCatalogCombatSpecialAbilityIds.contains(
        ability.id,
      );
      if (!isHardcoded && !isManeuverDuplicate) {
        genericAbilities.add(ability);
      }
    }

    if (genericAbilities.isEmpty && styleAbilities.isEmpty) {
      return const <Widget>[];
    }

    final widgets = <Widget>[];
    widgets.addAll(
      _buildCatalogCombatSpecialAbilitySection(
        title: 'Weitere Kampf-Sonderfertigkeiten',
        abilities: genericAbilities,
        rules: rules,
        catalog: catalog,
        isEditing: isEditing,
      ),
    );
    widgets.addAll(
      _buildCatalogCombatSpecialAbilitySection(
        title: 'Waffenlose Kampftechniken',
        abilities: styleAbilities,
        rules: rules,
        catalog: catalog,
        isEditing: isEditing,
      ),
    );
    return widgets;
  }

  /// Baut einen Abschnitt fuer eine Gruppe katalogbasierter Kampf-SF.
  List<Widget> _buildCatalogCombatSpecialAbilitySection({
    required String title,
    required List<CombatSpecialAbilityDef> abilities,
    required CombatSpecialRules rules,
    required RulesCatalog catalog,
    required bool isEditing,
  }) {
    if (abilities.isEmpty) {
      return const <Widget>[];
    }

    final widgets = <Widget>[
      const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
    ];
    for (final ability in abilities) {
      widgets.add(
        _buildCatalogCombatSpecialAbilityCard(
          ability: ability,
          rules: rules,
          catalog: catalog,
          isEditing: isEditing,
        ),
      );
    }
    return widgets;
  }

  /// Rendert eine einzelne katalogbasierte Kampf-SF.
  Widget _buildCatalogCombatSpecialAbilityCard({
    required CombatSpecialAbilityDef ability,
    required CombatSpecialRules rules,
    required RulesCatalog catalog,
    required bool isEditing,
  }) {
    final isActive = rules.activeCombatSpecialAbilityIds.contains(ability.id);
    return Card(
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
                : (value) => _toggleCatalogCombatSpecialAbility(
                    rules: rules,
                    abilityId: ability.id,
                    isActive: value,
                  ),
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
                  Chip(label: Text('Boni: ${ability.kampfwertBoni.length}')),
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
                catalogManeuvers: catalog.maneuvers,
              ),
              icon: const Icon(Icons.info_outline),
            ),
          ),
          if (ability.id == 'ksf_gladiatorenstil')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DropdownButtonFormField<String>(
                key: const ValueKey<String>('combat-gladiator-style-talent'),
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
    );
  }

  /// Aktualisiert den Aktivzustand einer katalogbasierten Kampf-SF.
  void _toggleCatalogCombatSpecialAbility({
    required CombatSpecialRules rules,
    required String abilityId,
    required bool isActive,
  }) {
    final active = List<String>.from(rules.activeCombatSpecialAbilityIds);
    if (isActive) {
      if (!active.contains(abilityId)) {
        active.add(abilityId);
      }
    } else {
      active.removeWhere((entry) => entry == abilityId);
    }
    _draftCombatConfig = _draftCombatConfig.copyWith(
      specialRules: rules.copyWith(activeCombatSpecialAbilityIds: active),
    );
    _markFieldChanged();
  }
}

/// Oeffnet einen adaptiven Detaildialog fuer eine Kampf-Sonderfertigkeit.
Future<void> _showCombatSpecialAbilityDetailsDialog({
  required BuildContext context,
  required CombatSpecialAbilityDef ability,
  List<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _CombatSpecialAbilityDetailsDialog(
      ability: ability,
      catalogManeuvers: catalogManeuvers,
    ),
  );
}

/// Detaildialog fuer katalogbasierte Kampf-Sonderfertigkeiten.
class _CombatSpecialAbilityDetailsDialog extends StatelessWidget {
  const _CombatSpecialAbilityDetailsDialog({
    required this.ability,
    this.catalogManeuvers = const <ManeuverDef>[],
  });

  final CombatSpecialAbilityDef ability;
  final List<ManeuverDef> catalogManeuvers;

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
                Text(
                  ability.aktiviertManoeverIds
                      .map(
                        (entry) => displayNameForManeuverId(
                          entry,
                          catalogManeuvers: catalogManeuvers,
                        ),
                      )
                      .join(', '),
                ),
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
