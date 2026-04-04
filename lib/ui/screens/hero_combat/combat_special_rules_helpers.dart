part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Gemeinsame UI-Helfer fuer die Sonderfertigkeiten im Kampfregeln-Tab.
extension _CombatSpecialRulesHelpers on _HeroCombatTabState {
  /// Liefert den Aktivzustand einer SF anhand ihrer Katalog-ID.
  /// Liest sowohl dedizierte boolean-Felder als auch [activeCombatSpecialAbilityIds].
  bool _isCatalogSfActive(String id) {
    final rules = _draftCombatConfig.specialRules;
    final armor = _draftCombatConfig.armor;
    return switch (id) {
      'ksf_kampfreflexe' => rules.kampfreflexe,
      'ksf_kampfgespuer' => rules.kampfgespuer,
      'ksf_schnellziehen' => rules.schnellziehen,
      'ksf_ausweichen_i' => rules.ausweichenI,
      'ksf_ausweichen_ii' => rules.ausweichenII,
      'ksf_ausweichen_iii' => rules.ausweichenIII,
      'ksf_linkhand' => rules.linkhandActive,
      'ksf_schildkampf_i' => rules.schildkampfI,
      'ksf_schildkampf_ii' => rules.schildkampfII,
      'ksf_parierwaffen_i' => rules.parierwaffenI,
      'ksf_parierwaffen_ii' => rules.parierwaffenII,
      'ksf_klingentaenzer' => rules.klingentaenzer,
      'ksf_aufmerksamkeit' => rules.aufmerksamkeit,
      'ksf_ruestungsgewoehnung_i' => armor.globalArmorTrainingLevel >= 1,
      'ksf_ruestungsgewoehnung_ii' => armor.globalArmorTrainingLevel >= 2,
      'ksf_ruestungsgewoehnung_iii' => armor.globalArmorTrainingLevel >= 3,
      _ => rules.activeCombatSpecialAbilityIds.contains(id),
    };
  }

  /// Schaltet eine SF anhand ihrer Katalog-ID — dispatcht auf das richtige Feld.
  void _toggleCombatSfById(String id, bool value) {
    final rules = _draftCombatConfig.specialRules;
    final armor = _draftCombatConfig.armor;
    switch (id) {
      case 'ksf_kampfreflexe':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(kampfreflexe: value));
      case 'ksf_kampfgespuer':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(kampfgespuer: value));
      case 'ksf_schnellziehen':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(schnellziehen: value));
      case 'ksf_ausweichen_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(ausweichenI: value));
      case 'ksf_ausweichen_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(ausweichenII: value));
      case 'ksf_ausweichen_iii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(ausweichenIII: value));
      case 'ksf_linkhand':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(linkhandActive: value));
      case 'ksf_schildkampf_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(schildkampfI: value));
      case 'ksf_schildkampf_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(schildkampfII: value));
      case 'ksf_parierwaffen_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(parierwaffenI: value));
      case 'ksf_parierwaffen_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(parierwaffenII: value));
      case 'ksf_klingentaenzer':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(klingentaenzer: value));
      case 'ksf_aufmerksamkeit':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(aufmerksamkeit: value));
      case 'ksf_ruestungsgewoehnung_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
          armor: armor.copyWith(
            globalArmorTrainingLevel: value
                ? (armor.globalArmorTrainingLevel < 1
                    ? 1
                    : armor.globalArmorTrainingLevel)
                : 0,
          ),
        );
      case 'ksf_ruestungsgewoehnung_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
          armor: armor.copyWith(
            globalArmorTrainingLevel: value
                ? (armor.globalArmorTrainingLevel < 2
                    ? 2
                    : armor.globalArmorTrainingLevel)
                : (armor.globalArmorTrainingLevel > 1 ? 1 : armor.globalArmorTrainingLevel),
          ),
        );
      case 'ksf_ruestungsgewoehnung_iii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
          armor: armor.copyWith(
            globalArmorTrainingLevel: value
                ? 3
                : (armor.globalArmorTrainingLevel > 2
                    ? 2
                    : armor.globalArmorTrainingLevel),
          ),
        );
      default:
        _toggleCatalogCombatSpecialAbility(
            rules: rules, abilityId: id, isActive: value);
        return; // _toggleCatalogCombatSpecialAbility already calls _markFieldChanged
    }
    _markFieldChanged();
  }

  /// Rendert alle SF einer Gruppe als Chip-Wrap.
  /// [abilities] sind bereits gefiltert (z. B. nur waffenlose Stile).
  Widget _buildSfChipWrap({
    required List<CombatSpecialAbilityDef> abilities,
    required RulesCatalog catalog,
    required CombatSpecialRules rules,
    required bool isEditing,
  }) {
    if (abilities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Keine Einträge vorhanden.'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: abilities.map((ability) {
        final isActive = _isCatalogSfActive(ability.id);
        final String beschreibung;
        if (ability.isUnarmedCombatStyle) {
          beschreibung = '${ability.aktiviertManoeverIds.length} Manöver';
        } else if (ability.beschreibung.trim().isNotEmpty) {
          beschreibung = ability.beschreibung.trim();
        } else {
          beschreibung = 'Kampf-Sonderfertigkeit';
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
          child: _CombatRuleChip(
            name: ability.name,
            beschreibung: beschreibung,
            isActive: isActive,
            isEditing: isEditing,
            onToggle: (value) => _toggleCombatSfById(ability.id, value),
            onNameTap: () => _showCombatSpecialAbilityDetailsDialog(
              context: context,
              ability: ability,
              catalogManeuvers: catalog.maneuvers,
              onGladiatorStyleChanged:
                  ability.id == 'ksf_gladiatorenstil' && isEditing
                      ? (String? value) {
                          _draftCombatConfig = _draftCombatConfig.copyWith(
                            specialRules: rules.copyWith(
                              gladiatorStyleTalent: value ?? '',
                            ),
                          );
                          _markFieldChanged();
                        }
                      : null,
              gladiatorStyleTalent: rules.gladiatorStyleTalent,
            ),
          ),
        );
      }).toList(),
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
/// [onGladiatorStyleChanged] und [gladiatorStyleTalent] werden nur fuer
/// ksf_gladiatorenstil im Edit-Modus benoetigt.
Future<void> _showCombatSpecialAbilityDetailsDialog({
  required BuildContext context,
  required CombatSpecialAbilityDef ability,
  List<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
  void Function(String?)? onGladiatorStyleChanged,
  String gladiatorStyleTalent = '',
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _CombatSpecialAbilityDetailsDialog(
      ability: ability,
      catalogManeuvers: catalogManeuvers,
      onGladiatorStyleChanged: onGladiatorStyleChanged,
      gladiatorStyleTalent: gladiatorStyleTalent,
    ),
  );
}

/// Detaildialog fuer katalogbasierte Kampf-Sonderfertigkeiten.
class _CombatSpecialAbilityDetailsDialog extends StatelessWidget {
  const _CombatSpecialAbilityDetailsDialog({
    required this.ability,
    this.catalogManeuvers = const <ManeuverDef>[],
    this.onGladiatorStyleChanged,
    this.gladiatorStyleTalent = '',
  });

  final CombatSpecialAbilityDef ability;
  final List<ManeuverDef> catalogManeuvers;
  final void Function(String?)? onGladiatorStyleChanged;
  final String gladiatorStyleTalent;

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
              // Gladiatorenstil: Bonus-Talent-Auswahl im Edit-Modus
              if (ability.id == 'ksf_gladiatorenstil' &&
                  onGladiatorStyleChanged != null) ...[
                const SizedBox(height: 16),
                Text('Bonus-Talent', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: gladiatorStyleTalent.trim().isEmpty
                      ? null
                      : gladiatorStyleTalent,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'raufen', child: Text('Raufen')),
                    DropdownMenuItem(value: 'ringen', child: Text('Ringen')),
                  ],
                  onChanged: onGladiatorStyleChanged,
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

/// Kompaktes Chip-Widget fuer eine Kampf-SF oder ein Manoever.
/// Name ist tappbar und oeffnet einen Detail-Dialog.
/// Toggle-Switch rechts schaltet aktiv/inaktiv (nur im Edit-Modus).
class _CombatRuleChip extends StatelessWidget {
  const _CombatRuleChip({
    required this.name,
    required this.beschreibung,
    required this.isActive,
    required this.isEditing,
    required this.onToggle,
    required this.onNameTap,
  });

  final String name;
  final String beschreibung;
  final bool isActive;
  final bool isEditing;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onNameTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: isActive ? colorScheme.primary : theme.dividerColor,
          width: isActive ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onNameTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isActive ? colorScheme.primary : null,
                      decoration: TextDecoration.underline,
                      decorationColor:
                          isActive ? colorScheme.primary : theme.hintColor,
                    ),
                  ),
                ),
                if (beschreibung.trim().isNotEmpty)
                  Text(
                    beschreibung.trim(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: isEditing ? onToggle : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
