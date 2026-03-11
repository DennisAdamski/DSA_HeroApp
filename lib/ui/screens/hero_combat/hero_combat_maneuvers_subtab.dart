part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatManeuversSubtab on _HeroCombatTabState {
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
