part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatSpecialRulesSubtab on _HeroCombatTabState {
  Widget _buildSpecialRulesSubTab(RulesCatalog catalog) {
    final rules = _draftCombatConfig.specialRules;
    final isEditing = _editController.isEditing;
    final allManeuvers = _collectCatalogManeuvers(catalog.weapons);
    final supportByManeuver = _buildManeuverSupportMap(catalog, allManeuvers);
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
        _ruleToggle(
          label: 'Linkhand aktiv',
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
          label: 'Flink',
          value: rules.flink,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(flink: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Behaebig',
          value: rules.behaebig,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(behaebig: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Axxeleratus aktiv',
          value: rules.axxeleratusActive,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(axxeleratusActive: value),
            );
            _markFieldChanged();
          },
        ),
        const SizedBox(height: 12),
        Text('Manoever', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (allManeuvers.isEmpty)
          const Card(
            child: ListTile(title: Text('Keine Manoever im Katalog gefunden.')),
          ),
        ...allManeuvers.map((maneuver) {
          final isActive = rules.activeManeuvers.contains(maneuver);
          final support =
              supportByManeuver[maneuver] ??
              _ManeuverSupportStatus.unverifiable;
          return Card(
            child: SwitchListTile(
              title: Text(maneuver),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(isActive ? 'Aktiv' : 'Inaktiv')),
                    Chip(
                      label: Text(switch (support) {
                        _ManeuverSupportStatus.supported =>
                          'Von aktiver Waffe unterstuetzt',
                        _ManeuverSupportStatus.notSupported =>
                          'Nicht unterstuetzt',
                        _ManeuverSupportStatus.unverifiable =>
                          'Nicht verifizierbar',
                      }),
                    ),
                    if (support == _ManeuverSupportStatus.unverifiable)
                      const Text(
                        'Waffenabgleich nicht verifizierbar.',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              value: isActive,
              onChanged: !isEditing
                  ? null
                  : (value) {
                      final active = List<String>.from(rules.activeManeuvers);
                      if (value) {
                        active.add(maneuver);
                      } else {
                        active.removeWhere((entry) => entry == maneuver);
                      }
                      _draftCombatConfig = _draftCombatConfig.copyWith(
                        specialRules: rules.copyWith(activeManeuvers: active),
                      );
                      _markFieldChanged();
                    },
            ),
          );
        }),
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

  List<String> _collectCatalogManeuvers(List<WeaponDef> weapons) {
    final seen = <String>{};
    final maneuvers = <String>[];
    for (final weapon in weapons) {
      for (final raw in weapon.possibleManeuvers) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty || seen.contains(trimmed)) {
          continue;
        }
        seen.add(trimmed);
        maneuvers.add(trimmed);
      }
    }
    maneuvers.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return maneuvers;
  }

  Map<String, _ManeuverSupportStatus> _buildManeuverSupportMap(
    RulesCatalog catalog,
    List<String> maneuvers,
  ) {
    final support = <String, _ManeuverSupportStatus>{};
    final selectedWeapon = _draftCombatConfig.selectedWeapon;
    final weaponTypeToken = _normalizeToken(
      selectedWeapon.weaponType.trim().isEmpty
          ? selectedWeapon.name
          : selectedWeapon.weaponType,
    );
    final talentId = selectedWeapon.talentId.trim();
    if (weaponTypeToken.isEmpty || talentId.isEmpty) {
      for (final maneuver in maneuvers) {
        support[maneuver] = _ManeuverSupportStatus.unverifiable;
      }
      return support;
    }

    TalentDef? talent;
    for (final entry in catalog.talents) {
      if (entry.id == talentId) {
        talent = entry;
        break;
      }
    }
    if (talent == null) {
      for (final maneuver in maneuvers) {
        support[maneuver] = _ManeuverSupportStatus.unverifiable;
      }
      return support;
    }

    final talentToken = _normalizeToken(talent.name);
    final candidates = catalog.weapons
        .where((weapon) {
          return _normalizeToken(weapon.combatSkill) == talentToken;
        })
        .toList(growable: false);
    if (candidates.isEmpty) {
      for (final maneuver in maneuvers) {
        support[maneuver] = _ManeuverSupportStatus.unverifiable;
      }
      return support;
    }

    final matched = candidates
        .where((weapon) {
          return _normalizeToken(weapon.name) == weaponTypeToken;
        })
        .toList(growable: false);
    if (matched.length != 1) {
      for (final maneuver in maneuvers) {
        support[maneuver] = _ManeuverSupportStatus.unverifiable;
      }
      return support;
    }

    final weapon = matched.first;
    final supportedTokens = weapon.possibleManeuvers
        .map(_normalizeToken)
        .where((entry) => entry.isNotEmpty)
        .toSet();
    for (final maneuver in maneuvers) {
      final token = _normalizeToken(maneuver);
      support[maneuver] = supportedTokens.contains(token)
          ? _ManeuverSupportStatus.supported
          : _ManeuverSupportStatus.notSupported;
    }
    return support;
  }
}
