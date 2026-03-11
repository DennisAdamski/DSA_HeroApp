part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Entkoppelt Draft-State, Persistenz und Validierung vom Tab-Root.
extension _CombatStateHelpers on _HeroCombatTabState {
  void _setControllerText(String key, String value) {
    final controller = _controllerFor(key, value);
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncSelectedWeaponControllers(MainWeaponSlot weapon) {
    _setControllerText('combat-main-name', weapon.name);
    _setControllerText('combat-main-talent', weapon.talentId);
    _setControllerText('combat-main-dice-count', weapon.tpDiceCount.toString());
    _setControllerText('combat-main-dice-sides', weapon.tpDiceSides.toString());
    _setControllerText('combat-main-tp-flat', weapon.tpFlat.toString());
    _setControllerText('combat-main-wm-at', weapon.wmAt.toString());
    _setControllerText('combat-main-wm-pa', weapon.wmPa.toString());
    _setControllerText('combat-main-ini-mod', weapon.iniMod.toString());
    _setControllerText('combat-main-be-mod', weapon.beTalentMod.toString());
  }

  void _setDraftWeapons(
    List<MainWeaponSlot> slots, {
    required int selectedIndex,
    bool markChanged = true,
  }) {
    if (slots.isEmpty) {
      return;
    }
    final normalizedIndex = selectedIndex < 0
        ? -1
        : (selectedIndex >= slots.length ? slots.length - 1 : selectedIndex);
    final selectedMainWeapon = normalizedIndex < 0
        ? _draftCombatConfig.mainWeapon
        : slots[normalizedIndex];
    _draftCombatConfig = _draftCombatConfig.copyWith(
      weapons: slots,
      selectedWeaponIndex: normalizedIndex,
      mainWeapon: selectedMainWeapon,
    );
    if (normalizedIndex >= 0) {
      _syncSelectedWeaponControllers(slots[normalizedIndex]);
    }
    if (markChanged) {
      _markFieldChanged();
    }
  }

  Future<void> _selectWeaponIndex(
    int? nextIndex, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    final slots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    _setDraftWeapons(slots, selectedIndex: nextIndex ?? -1, markChanged: true);
    await _persistCombatConfigIfReadonly(
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _persistCombatConfigIfReadonly({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    if (_editController.isEditing) {
      return;
    }
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    final weaponValidation = _validateWeaponSlotsForConfig(
      config: _draftCombatConfig,
      catalog: catalog,
      combatTalents: combatTalents,
    );
    if (weaponValidation != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(weaponValidation)));
      }
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
      return;
    }
    try {
      final updatedHero = hero.copyWith(combatConfig: _draftCombatConfig);
      await ref.read(heroActionsProvider).saveHero(updatedHero);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $error')),
        );
      }
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
  }

  Future<void> _applyCombatConfigChange({
    required CombatConfig nextConfig,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    _draftCombatConfig = nextConfig;
    _markFieldChanged();
    await _persistCombatConfigIfReadonly(
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _invalidCombatTalentIds = <String>{};
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final catalog = await ref.read(rulesCatalogProvider.future);
    final combatTalents = sortedCombatTalents(
      catalog.talents.where(isCombatTalentDef).toList(growable: false),
    );
    final weaponValidation = _validateWeaponSlots(
      catalog: catalog,
      combatTalents: combatTalents,
    );
    if (weaponValidation != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(weaponValidation)));
      }
      return;
    }
    final issues = validateCombatTalentDistribution(
      talents: catalog.talents,
      talentEntries: _draftTalents,
      filter: isCombatTalentDef,
    );
    if (issues.isNotEmpty) {
      if (mounted) {
        _setInvalidCombatTalentIds(
          issues.map((entry) => entry.talentId).toSet(),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(issues.first.message)));
      }
      return;
    }

    final updatedHero = hero.copyWith(
      talents: Map<String, HeroTalentEntry>.from(_draftTalents),
      combatConfig: _draftCombatConfig,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }
    _invalidCombatTalentIds = <String>{};
    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kampfwerte gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    _temporaryIniRoll = null;
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
    _invalidCombatTalentIds = <String>{};
    _editController.markDiscarded();
  }

  HeroTalentEntry _entryForTalent(String talentId) {
    return _draftTalents[talentId] ?? const HeroTalentEntry();
  }

  TextEditingController _controllerFor(String key, String initialValue) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  int _maxIniRollForConfig(CombatConfig config) {
    return config.specialRules.klingentaenzer ? 12 : 6;
  }

  int _effectiveIniRollForConfig(CombatConfig config) {
    final maxRoll = _maxIniRollForConfig(config);
    if (config.specialRules.aufmerksamkeit) {
      return maxRoll;
    }
    final raw = _temporaryIniRoll ?? 0;
    if (raw < 0) {
      return 0;
    }
    if (raw > maxRoll) {
      return maxRoll;
    }
    return raw;
  }

  void _setTemporaryIniRoll(int value) {
    final maxRoll = _maxIniRollForConfig(_draftCombatConfig);
    final clamped = value < 0 ? 0 : (value > maxRoll ? maxRoll : value);
    _temporaryIniRoll = clamped;
    if (mounted) {
      _viewRevision.value++;
    }
  }

  void _updateIntField(String talentId, String field, String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    final current = _entryForTalent(talentId);
    final updated = switch (field) {
      'talentValue' => current.copyWith(talentValue: parsed),
      'atValue' => current.copyWith(atValue: parsed),
      'paValue' => current.copyWith(paValue: parsed),
      _ => current,
    };
    _draftTalents[talentId] = updated;
    _invalidCombatTalentIds.remove(talentId);
    _markFieldChanged();
  }

  void _updateGifted(String talentId, bool value) {
    final current = _entryForTalent(talentId);
    _draftTalents[talentId] = current.copyWith(gifted: value);
    _markFieldChanged();
  }

  void _updateCombatSpecializations(String talentId, List<String> values) {
    final current = _entryForTalent(talentId);
    final normalized = _normalizeStringList(values);
    _draftTalents[talentId] = current.copyWith(
      combatSpecializations: normalized,
      specializations: normalized.join(', '),
    );
    _markFieldChanged();
  }

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    _viewRevision.value++;
    _editController.markFieldChanged();
  }

  String? _validateWeaponSlotsForConfig({
    required CombatConfig config,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) {
    final talentById = <String, TalentDef>{
      for (final talent in combatTalents) talent.id: talent,
    };
    final slots = config.weaponSlots;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final slotLabel = 'Waffe ${i + 1}';
      final hasAnyData =
          slot.name.trim().isNotEmpty ||
          slot.talentId.trim().isNotEmpty ||
          slot.weaponType.trim().isNotEmpty;
      if (!hasAnyData) {
        continue;
      }
      final talentId = slot.talentId.trim();
      final talent = talentId.isEmpty ? null : talentById[talentId];
      if (talentId.isNotEmpty && talent == null) {
        return '$slotLabel: Das gewählte Talent ist kein gültiges Kampftalent.';
      }
      if (talent != null && combatTypeFromTalent(talent) != slot.combatType) {
        return '$slotLabel: Talent "${talent.name}" passt nicht zum Waffenkampftyp.';
      }
      final weaponType = slot.weaponType.trim();
      if (weaponType.isNotEmpty && talent != null) {
        final allowedTypes = weaponTypeOptionsForTalent(
          talent: talent,
          catalog: catalog,
          combatType: slot.combatType,
        );
        if (!allowedTypes.contains(weaponType)) {
          return '$slotLabel: Waffenart "$weaponType" passt nicht zum Talent "${talent.name}".';
        }
      }
      if (weaponType.isNotEmpty && talent == null) {
        return '$slotLabel: Waffenart "$weaponType" benötigt ein gültiges Talent.';
      }
      if (slot.kkThreshold < 1) {
        return '$slotLabel: KK-Schwelle muss > 0 sein.';
      }
      if (slot.tpDiceCount < 1) {
        return '$slotLabel: Würfelanzahl muss >= 1 sein.';
      }
      if (slot.breakFactor < 0) {
        return '$slotLabel: BF darf nicht negativ sein.';
      }
      if (slot.isRanged && slot.rangedProfile.reloadTime < 0) {
        return '$slotLabel: Ladezeit darf nicht negativ sein.';
      }
      if (slot.isRanged) {
        for (final projectile in slot.rangedProfile.projectiles) {
          if (projectile.count < 0) {
            return '$slotLabel: Geschossbestände dürfen nicht negativ sein.';
          }
        }
      }
    }
    final assignment = config.offhandAssignment;
    if (assignment.weaponIndex >= 0 &&
        assignment.weaponIndex == config.selectedWeaponIndex) {
      return 'Nebenhand: Haupthand und Nebenhand dürfen nicht dieselbe Waffe nutzen.';
    }
    if (assignment.usesEquipment &&
        assignment.equipmentIndex >= 0 &&
        assignment.equipmentIndex < config.offhandEquipment.length) {
      final offhandEntry = config.offhandEquipment[assignment.equipmentIndex];
      if (offhandEntry.type == OffhandEquipmentType.parryWeapon &&
          !config.specialRules.linkhandActive) {
        return 'Nebenhand: Parierwaffen erfordern die Sonderfertigkeit Linkhand.';
      }
      if (offhandEntry.breakFactor < 0) {
        return 'Nebenhand: BF darf nicht negativ sein.';
      }
    }
    return null;
  }

  String? _validateWeaponSlots({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) {
    return _validateWeaponSlotsForConfig(
      config: _draftCombatConfig,
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _removeWeaponSlotAt(
    int slotIndex, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    final slots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    if (slotIndex < 0 || slotIndex >= slots.length || slots.length <= 1) {
      return;
    }
    final selectedIndex = _selectedWeaponIndex();
    slots.removeAt(slotIndex);
    final nextSelectedIndex = selectedIndex < 0
        ? -1
        : (selectedIndex == slotIndex
              ? -1
              : (selectedIndex > slotIndex
                    ? selectedIndex - 1
                    : selectedIndex));
    _setDraftWeapons(
      slots,
      selectedIndex: nextSelectedIndex,
      markChanged: true,
    );
    await _persistCombatConfigIfReadonly(
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _updateWeaponSlot(
    int slotIndex,
    MainWeaponSlot Function(MainWeaponSlot current) update, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    final slots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    if (slotIndex < 0 || slotIndex >= slots.length) {
      return;
    }
    slots[slotIndex] = update(slots[slotIndex]);
    _setDraftWeapons(
      slots,
      selectedIndex: _selectedWeaponIndex(),
      markChanged: true,
    );
    await _persistCombatConfigIfReadonly(
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _updateSelectedRangedDistance(
    int nextDistanceIndex, {
    required RulesCatalog catalog,
  }) async {
    final selectedIndex = _selectedWeaponIndex();
    final combatTalents = sortedCombatTalents(
      catalog.talents.where(isCombatTalentDef).toList(growable: false),
    );
    await _updateWeaponSlot(
      selectedIndex,
      (current) => current.copyWith(
        rangedProfile: current.rangedProfile.copyWith(
          selectedDistanceIndex: nextDistanceIndex,
        ),
      ),
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _updateSelectedRangedProjectile(
    int nextProjectileIndex, {
    required RulesCatalog catalog,
  }) async {
    final selectedIndex = _selectedWeaponIndex();
    final combatTalents = sortedCombatTalents(
      catalog.talents.where(isCombatTalentDef).toList(growable: false),
    );
    await _updateWeaponSlot(
      selectedIndex,
      (current) => current.copyWith(
        rangedProfile: current.rangedProfile.copyWith(
          selectedProjectileIndex: nextProjectileIndex,
        ),
      ),
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _adjustSelectedProjectileCount(
    int delta, {
    required RulesCatalog catalog,
  }) async {
    final selectedIndex = _selectedWeaponIndex();
    final activeWeapon = _draftCombatConfig.selectedWeaponOrNull;
    if (selectedIndex < 0 || activeWeapon == null) {
      return;
    }
    final projectileIndex = activeWeapon.rangedProfile.selectedProjectileIndex;
    if (projectileIndex < 0 ||
        projectileIndex >= activeWeapon.rangedProfile.projectiles.length) {
      return;
    }
    final combatTalents = sortedCombatTalents(
      catalog.talents.where(isCombatTalentDef).toList(growable: false),
    );
    await _updateWeaponSlot(
      selectedIndex,
      (current) {
        final updatedProjectiles = List<RangedProjectile>.from(
          current.rangedProfile.projectiles,
        );
        final currentProjectile = updatedProjectiles[projectileIndex];
        final nextCount = (currentProjectile.count + delta).clamp(0, 9999);
        updatedProjectiles[projectileIndex] = currentProjectile.copyWith(
          count: nextCount,
        );
        return current.copyWith(
          rangedProfile: current.rangedProfile.copyWith(
            projectiles: updatedProjectiles,
          ),
        );
      },
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _saveWeaponSlot({
    required MainWeaponSlot slot,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    int? slotIndex,
  }) async {
    final slots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    if (slotIndex == null) {
      slots.add(slot);
    } else if (slotIndex >= 0 && slotIndex < slots.length) {
      slots[slotIndex] = slot;
    } else {
      return;
    }
    _setDraftWeapons(
      slots,
      selectedIndex: _selectedWeaponIndex(),
      markChanged: true,
    );
    await _persistCombatConfigIfReadonly(
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _setOffhandEquipmentEntries(
    List<OffhandEquipmentEntry> entries, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    await _applyCombatConfigChange(
      nextConfig: _draftCombatConfig.copyWith(
        offhandEquipment: List<OffhandEquipmentEntry>.unmodifiable(entries),
      ),
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _setArmorConfig(
    ArmorConfig armor, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    await _applyCombatConfigChange(
      nextConfig: _draftCombatConfig.copyWith(armor: armor),
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  String _fallback(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    return trimmed;
  }

  List<String> _splitSpecializationTokens(String raw) {
    return _normalizeStringList(raw.split(RegExp(r'[\n,;]+')));
  }

  List<String> _weaponCategoryOptions(TalentDef talent) {
    return _normalizeStringList(
      talent.weaponCategory.split(RegExp(r'[\n,;]+')),
    );
  }

  List<String> _normalizeStringList(Iterable<dynamic> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.toString().trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      normalized.add(trimmed);
    }
    return List<String>.unmodifiable(normalized);
  }

  String _normalizeToken(String raw) {
    var value = raw.trim().toLowerCase();
    value = value
        .replaceAll(String.fromCharCode(228), 'ae')
        .replaceAll(String.fromCharCode(246), 'oe')
        .replaceAll(String.fromCharCode(252), 'ue')
        .replaceAll(String.fromCharCode(223), 'ss');
    return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
