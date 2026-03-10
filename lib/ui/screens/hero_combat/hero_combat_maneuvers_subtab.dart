part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatManeuversSubtab on _HeroCombatTabState {
  Widget _buildManeuversSubTab(RulesCatalog catalog) {
    final rules = _draftCombatConfig.specialRules;
    final isEditing = _editController.isEditing;
    final allManeuvers = _collectCatalogManeuvers(catalog.weapons);
    final supportByManeuver = _buildManeuverSupportMap(catalog, allManeuvers);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (allManeuvers.isEmpty)
          const Card(
            child: ListTile(title: Text('Keine Manoever im Katalog gefunden.')),
          ),
        ...allManeuvers.map((maneuver) {
          final isActive = rules.activeManeuvers.contains(maneuver);
          final support =
              supportByManeuver[maneuver] ??
              _ManeuverSupportStatus.unverifiable;
          final maneuverDef = catalog.maneuverByName(maneuver);
          final erschwernis =
              maneuverDef != null && maneuverDef.erschwernis.isNotEmpty
              ? maneuverDef.erschwernis
              : null;
          final seite = maneuverDef != null && maneuverDef.seite.isNotEmpty
              ? maneuverDef.seite
              : null;
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
                          'Von aktiver Waffe unterstützt',
                        _ManeuverSupportStatus.notSupported =>
                          'Nicht unterstützt',
                        _ManeuverSupportStatus.unverifiable =>
                          'Nicht verifizierbar',
                      }),
                    ),
                    if (erschwernis != null)
                      Chip(label: Text('Erschwernis: $erschwernis')),
                    if (seite != null) Chip(label: Text('S. $seite')),
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
