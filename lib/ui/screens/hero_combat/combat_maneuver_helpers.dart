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
    final selectedWeapon = _draftCombatConfig.selectedWeapon;
    final selectedTalent = _selectedCombatTalentDef(catalog);
    final selectedTalentName = selectedTalent?.name ?? '';
    final isUnarmedContext =
        weapon == null || _isUnarmedTalentName(selectedTalentName);
    final wmEffects = computeWaffenmeisterEffects(
      waffenmeisterschaften: _draftCombatConfig.waffenmeisterschaften,
      activeWeaponType: selectedWeapon.weaponType.trim().isEmpty
          ? selectedWeapon.name
          : selectedWeapon.weaponType,
      activeTalentId: selectedWeapon.talentId,
    );
    final styleEffects = computeActiveUnarmedStyleEffects(
      specialRules: _draftCombatConfig.specialRules,
      catalogCombatSpecialAbilities: catalog.combatSpecialAbilities,
      catalogManeuvers: catalog.maneuvers,
      activeTalentName: selectedTalentName,
    );
    if (isUnarmedContext) {
      for (final maneuverId in styleEffects.activatedManeuverIds) {
        if (seen.add(maneuverId)) {
          ids.add(maneuverId);
        }
      }
    }
    if (weapon == null) {
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

    final supportedIds = <String>{};
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
    for (final raw in wmEffects.additionalManeuvers) {
      final id = canonicalManeuverIdFromName(
        raw,
        catalogManeuvers: catalog.maneuvers,
      );
      if (id.isNotEmpty) {
        supportedIds.add(id);
        if (seen.add(id)) {
          ids.add(id);
        }
      }
    }
    for (final raw in _draftCombatConfig.specialRules.activeManeuvers) {
      final id = canonicalManeuverIdFromName(
        raw,
        catalogManeuvers: catalog.maneuvers,
      );
      if (id.isEmpty || !supportedIds.contains(id)) {
        continue;
      }
      if (seen.add(id)) {
        ids.add(id);
      }
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

  /// Liefert alle effektiv aktiven Manöver aus manueller Auswahl und Stil-SF.
  Set<String> _effectiveActiveManeuverIds(RulesCatalog catalog) {
    final ids = <String>{
      ...normalizeManeuverIds(
        _draftCombatConfig.specialRules.activeManeuvers,
        catalogManeuvers: catalog.maneuvers,
      ),
    };
    final selectedTalentName = _selectedCombatTalentDef(catalog)?.name ?? '';
    final styleEffects = computeActiveUnarmedStyleEffects(
      specialRules: _draftCombatConfig.specialRules,
      catalogCombatSpecialAbilities: catalog.combatSpecialAbilities,
      catalogManeuvers: catalog.maneuvers,
      activeTalentName: selectedTalentName,
    );
    ids.addAll(styleEffects.activatedManeuverIds);
    return ids;
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

  /// Liefert das aktuell ausgewaehlte Kampftalent aus dem Katalog.
  TalentDef? _selectedCombatTalentDef(RulesCatalog catalog) {
    final talentId = _draftCombatConfig.selectedWeapon.talentId.trim();
    if (talentId.isEmpty) {
      return null;
    }
    for (final entry in catalog.talents) {
      if (entry.id == talentId) {
        return entry;
      }
    }
    return null;
  }

  /// Baut eine kompakte Zusammenfassung fuer die Kampfwert-Vorschau.
  String _buildPreviewManeuverSummary({
    required CombatPreviewStats preview,
    required String maneuverId,
    required ManeuverDef? maneuverDef,
  }) {
    final parts = <String>[];
    if (maneuverDef != null && maneuverDef.typ.trim().isNotEmpty) {
      parts.add('Typ: ${maneuverDef.typ.trim()}');
    }
    if (maneuverDef != null && maneuverDef.erschwernis.trim().isNotEmpty) {
      parts.add('Erschwernis: ${maneuverDef.erschwernis.trim()}');
    }
    final reduction = preview.waffenmeisterManeuverReductions[maneuverId] ?? 0;
    if (reduction > 0) {
      parts.add('Waffenmeister: -$reduction');
    }
    if (preview.waffenmeisterAdditionalManeuvers.contains(maneuverId)) {
      parts.add('Waffenmeister: freigeschaltet');
    }
    return parts.join(' • ');
  }

  bool _isUnarmedTalentName(String raw) {
    final normalized = _normalizeToken(raw);
    return normalized == 'raufen' || normalized == 'ringen';
  }
}
