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

  /// Sucht eine beliebige Waffe im Katalog (generalisiert fuer HH und NH).
  WeaponDef? _findMatchedCatalogWeaponForSlot(
    RulesCatalog catalog,
    MainWeaponSlot slot,
  ) {
    final weaponTypeToken = _normalizeToken(
      slot.weaponType.trim().isEmpty ? slot.name : slot.weaponType,
    );
    final talentId = slot.talentId.trim();
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

  /// Sammelt die Manoever-IDs fuer einen einzelnen Waffen-Slot.
  Set<String> _maneuverIdsForSlot(
    RulesCatalog catalog,
    MainWeaponSlot slot,
  ) {
    final weapon = _findMatchedCatalogWeaponForSlot(catalog, slot);
    final talentDef = _talentDefForSlot(catalog, slot);
    final talentName = talentDef?.name ?? '';
    final isUnarmed = weapon == null || _isUnarmedTalentName(talentName);
    final ids = <String>{};

    if (isUnarmed) {
      final styleEffects = computeActiveUnarmedStyleEffects(
        specialRules: _draftCombatConfig.specialRules,
        catalogCombatSpecialAbilities: catalog.combatSpecialAbilities,
        catalogManeuvers: catalog.maneuvers,
        activeTalentName: talentName,
      );
      ids.addAll(styleEffects.activatedManeuverIds);
      if (weapon == null) {
        return ids;
      }
    }

    final resolvedWeapon = weapon;
    final supportedIds = <String>{};
    for (final raw in resolvedWeapon.possibleManeuvers) {
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

    final wmEffects = computeWaffenmeisterEffects(
      waffenmeisterschaften: _draftCombatConfig.waffenmeisterschaften,
      activeWeaponType: slot.weaponType.trim().isEmpty
          ? slot.name
          : slot.weaponType,
      activeTalentId: slot.talentId,
    );
    for (final raw in wmEffects.additionalManeuvers) {
      final id = canonicalManeuverIdFromName(
        raw,
        catalogManeuvers: catalog.maneuvers,
      );
      if (id.isNotEmpty) {
        supportedIds.add(id);
        ids.add(id);
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
      ids.add(id);
    }
    return ids;
  }

  TalentDef? _talentDefForSlot(RulesCatalog catalog, MainWeaponSlot slot) {
    final talentId = slot.talentId.trim();
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

  /// Ermittelt Manoever mit Hand-Zuordnung (HH, NH, HH+NH).
  List<PreviewManeuverEntry> _activePreviewManeuverEntries(
    RulesCatalog catalog,
    CombatPreviewStats preview,
  ) {
    final mainIds = _maneuverIdsForSlot(
      catalog,
      _draftCombatConfig.selectedWeapon,
    );

    final offhandWeapon = _offhandWeaponOrNull();
    final offhandIds = offhandWeapon != null
        ? _maneuverIdsForSlot(catalog, offhandWeapon)
        : <String>{};

    final allIds = <String>{...mainIds, ...offhandIds};
    final entries = <PreviewManeuverEntry>[];
    for (final id in allIds) {
      final inMain = mainIds.contains(id);
      final inOff = offhandIds.contains(id);
      final availability = inMain && inOff
          ? ManeuverHandAvailability.both
          : inMain
              ? ManeuverHandAvailability.mainOnly
              : ManeuverHandAvailability.offhandOnly;
      entries.add(PreviewManeuverEntry(
        maneuverId: id,
        availableHands: availability,
      ));
    }
    entries.sort((a, b) {
      final left = displayNameForManeuverId(
        a.maneuverId,
        catalogManeuvers: catalog.maneuvers,
      );
      final right = displayNameForManeuverId(
        b.maneuverId,
        catalogManeuvers: catalog.maneuvers,
      );
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    return entries;
  }
}

/// Hand-Zuordnung eines Manoevers.
enum ManeuverHandAvailability { mainOnly, offhandOnly, both }

/// Manoever mit Zuordnung zu Haupt- und/oder Nebenhand.
class PreviewManeuverEntry {
  const PreviewManeuverEntry({
    required this.maneuverId,
    required this.availableHands,
  });

  final String maneuverId;
  final ManeuverHandAvailability availableHands;
}
