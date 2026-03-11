part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Kapselt Katalogabgleich und Support-Analyse fuer Kampfmanoever.
extension _CombatManeuverHelpers on _HeroCombatTabState {
  /// Liefert alle Katalogmanöver gruppiert nach ihrer Kampfgruppe.
  Map<String, List<ManeuverDef>> _groupCatalogManeuvers(RulesCatalog catalog) {
    final grouped = <String, List<ManeuverDef>>{};
    for (final maneuver in catalog.maneuvers) {
      final groupKey = maneuver.gruppe.trim().toLowerCase();
      grouped.putIfAbsent(groupKey, () => <ManeuverDef>[]).add(maneuver);
    }
    for (final entry in grouped.values) {
      entry.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    return grouped;
  }

  /// Ermittelt die im Kampf-Preview sichtbaren aktiven Manöver.
  List<String> _activePreviewManeuverIds(
    RulesCatalog catalog,
    CombatPreviewStats preview,
  ) {
    final seen = <String>{};
    final ids = <String>[];
    final weapon = _findMatchedCatalogWeapon(catalog);
    final supportedIds = <String>{};
    if (weapon != null) {
      for (final raw in weapon.possibleManeuvers) {
        final id = canonicalManeuverIdFromName(
          raw,
          catalogManeuvers: catalog.maneuvers,
        );
        if (id.isNotEmpty) {
          supportedIds.add(id);
        }
      }
      for (final raw in weapon.activeManeuvers) {
        final id = canonicalManeuverIdFromName(
          raw,
          catalogManeuvers: catalog.maneuvers,
        );
        if (id.isNotEmpty) {
          supportedIds.add(id);
        }
      }
    }
    for (final raw in _draftCombatConfig.specialRules.activeManeuvers) {
      final id = canonicalManeuverIdFromName(
        raw,
        catalogManeuvers: catalog.maneuvers,
      );
      if (id.isEmpty) {
        continue;
      }
      if (supportedIds.isNotEmpty && !supportedIds.contains(id)) {
        continue;
      }
      if (seen.add(id)) {
        ids.add(id);
      }
    }
    for (final raw in preview.masteryAdditionalManeuverIds) {
      _appendManeuverId(ids, seen, raw, catalog);
    }
    ids.sort((a, b) {
      final left = displayNameForManeuverId(
        a,
        catalogManeuvers: catalog.maneuvers,
      );
      final right = displayNameForManeuverId(
        b,
        catalogManeuvers: catalog.maneuvers,
      );
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    return ids;
  }

  /// Fuegt eine Manöver-ID normalisiert und dedupliziert an.
  void _appendManeuverId(
    List<String> target,
    Set<String> seen,
    String raw,
    RulesCatalog catalog,
  ) {
    final id = canonicalManeuverIdFromName(
      raw,
      catalogManeuvers: catalog.maneuvers,
    );
    if (id.isEmpty || seen.contains(id)) {
      return;
    }
    seen.add(id);
    target.add(id);
  }

  /// Liefert das Manöver aus dem Katalog anhand seiner stabilen ID.
  ManeuverDef? _maneuverById(RulesCatalog catalog, String maneuverId) {
    final trimmed = maneuverId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    for (final maneuver in catalog.maneuvers) {
      if (maneuver.id == trimmed) {
        return maneuver;
      }
    }
    return null;
  }

  /// Löst den Anzeigenamen eines Manövers robust aus ID oder Fallback-Token auf.
  String _maneuverLabel(RulesCatalog catalog, String maneuverId) {
    return displayNameForManeuverId(
      maneuverId,
      catalogManeuvers: catalog.maneuvers,
    );
  }

  /// Sucht die aktive Heldenwaffe im Katalog, sofern sie eindeutig auflösbar ist.
  WeaponDef? _findMatchedCatalogWeapon(RulesCatalog catalog) {
    final selectedWeapon = _draftCombatConfig.selectedWeapon;
    final weaponTypeToken = _normalizeToken(
      selectedWeapon.weaponType.trim().isEmpty
          ? selectedWeapon.name
          : selectedWeapon.weaponType,
    );
    final talentId = selectedWeapon.talentId.trim();
    if (weaponTypeToken.isEmpty || talentId.isEmpty) {
      return null;
    }

    TalentDef? talent;
    for (final entry in catalog.talents) {
      if (entry.id == talentId) {
        talent = entry;
        break;
      }
    }
    if (talent == null) {
      return null;
    }

    final talentToken = _normalizeToken(talent.name);
    final candidates = catalog.weapons
        .where((weapon) => _normalizeToken(weapon.combatSkill) == talentToken)
        .where((weapon) => _normalizeToken(weapon.name) == weaponTypeToken)
        .toList(growable: false);
    if (candidates.length != 1) {
      return null;
    }
    return candidates.first;
  }

  /// Baut die Unterstuetzungszuordnung fuer eine Menge von Manöver-IDs.
  Map<String, _ManeuverSupportStatus> _buildManeuverSupportMap(
    RulesCatalog catalog,
    List<String> maneuverIds,
  ) {
    final support = <String, _ManeuverSupportStatus>{};
    final weapon = _findMatchedCatalogWeapon(catalog);
    if (weapon == null) {
      for (final maneuverId in maneuverIds) {
        support[maneuverId] = _ManeuverSupportStatus.unverifiable;
      }
      return support;
    }
    final supportedIds = <String>{
      ...normalizeManeuverIds(
        weapon.possibleManeuvers,
        catalogManeuvers: catalog.maneuvers,
      ),
      ...normalizeManeuverIds(
        weapon.activeManeuvers,
        catalogManeuvers: catalog.maneuvers,
      ),
    };
    for (final maneuverId in maneuverIds) {
      support[maneuverId] = supportedIds.contains(maneuverId)
          ? _ManeuverSupportStatus.supported
          : _ManeuverSupportStatus.notSupported;
    }
    return support;
  }

  /// Liefert kompakte UI-Chips fuer die Metadaten eines Manövers.
  List<Widget> _buildManeuverMetaChips({
    required ManeuverDef? maneuverDef,
    required bool isActive,
    _ManeuverSupportStatus? support,
  }) {
    final chips = <Widget>[Chip(label: Text(isActive ? 'Aktiv' : 'Inaktiv'))];
    if (support != null) {
      chips.add(
        Chip(
          label: Text(switch (support) {
            _ManeuverSupportStatus.supported => 'Unterstützt',
            _ManeuverSupportStatus.notSupported => 'Nicht unterstützt',
            _ManeuverSupportStatus.unverifiable => 'Nicht verifizierbar',
          }),
        ),
      );
    }
    if (maneuverDef != null && maneuverDef.typ.trim().isNotEmpty) {
      chips.add(Chip(label: Text('Typ: ${maneuverDef.typ.trim()}')));
    }
    if (maneuverDef != null && maneuverDef.erschwernis.trim().isNotEmpty) {
      chips.add(
        Chip(label: Text('Erschwernis: ${maneuverDef.erschwernis.trim()}')),
      );
    }
    if (maneuverDef != null && maneuverDef.seite.trim().isNotEmpty) {
      chips.add(Chip(label: Text('S. ${maneuverDef.seite.trim()}')));
    }
    return chips;
  }
}
