part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatMeleeSubtab on _HeroCombatTabState {
  static const List<AdaptiveTableColumnSpec> _weaponOverviewColumnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 300, flex: 3),
        AdaptiveTableColumnSpec(minWidth: 100, maxWidth: 180, flex: 2),
        AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 260, flex: 2),
        AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 220, flex: 2),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 96),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 110),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 86, maxWidth: 120),
        AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 320, flex: 3),
        AdaptiveTableColumnSpec.fixed(56),
      ];

  static const List<AdaptiveTableColumnSpec> _offhandColumnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2),
        AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 180, flex: 1),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 90, maxWidth: 150, flex: 1),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec.fixed(56),
      ];

  List<AdaptiveTableColumnSpec> _armorColumnSpecs({
    required bool showPieceRg1,
  }) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),
      if (showPieceRg1)
        const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),
      const AdaptiveTableColumnSpec.fixed(56),
    ];
  }

  List<TalentDef> _sortedCombatTalents(List<TalentDef> combatTalents) {
    final talents = List<TalentDef>.from(combatTalents, growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return talents;
  }

  List<TalentDef> _sortedCombatTalentsForType(
    List<TalentDef> combatTalents,
    WeaponCombatType combatType,
  ) {
    return _sortedCombatTalents(combatTalents)
        .where((talent) => _combatTypeFromTalent(talent) == combatType)
        .toList(growable: false);
  }

  WeaponCombatType _combatTypeFromTalent(TalentDef talent) {
    return talent.type.trim().toLowerCase() == 'fernkampf'
        ? WeaponCombatType.ranged
        : WeaponCombatType.melee;
  }

  String _combatTypeLabel(WeaponCombatType combatType) {
    return combatType == WeaponCombatType.ranged ? 'Fernkampf' : 'Nahkampf';
  }

  TalentDef? _findTalentById(List<TalentDef> talents, String talentId) {
    final trimmed = talentId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    for (final talent in talents) {
      if (talent.id == trimmed) {
        return talent;
      }
    }
    return null;
  }

  List<String> _parseWeaponCategoryValues(String raw) {
    final seen = <String>{};
    final values = <String>[];
    for (final token in raw.split(RegExp(r'[\n,;]+'))) {
      final trimmed = token.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      values.add(trimmed);
    }
    return values;
  }

  List<String> _weaponTypeOptionsForTalent({
    required TalentDef? talent,
    required RulesCatalog catalog,
    required WeaponCombatType combatType,
  }) {
    if (talent == null) {
      return const <String>[];
    }
    final seen = <String>{};
    final options = <String>[];
    final talentNameToken = _normalizeToken(talent.name);
    for (final weapon in catalog.weapons) {
      if (weaponCombatTypeFromJson(weapon.type) != combatType) {
        continue;
      }
      if (_normalizeToken(weapon.combatSkill) != talentNameToken) {
        continue;
      }
      final name = weapon.name.trim();
      if (name.isEmpty || seen.contains(name)) {
        continue;
      }
      seen.add(name);
      options.add(name);
    }
    for (final fallback in _parseWeaponCategoryValues(talent.weaponCategory)) {
      if (seen.contains(fallback)) {
        continue;
      }
      seen.add(fallback);
      options.add(fallback);
    }
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  /// Findet die Talent-ID zu einem Kampftalent-Namen aus dem Katalog.
  String _findTalentIdByName(
    String combatSkillName,
    List<TalentDef> combatTalents,
  ) {
    final needle = _normalizeToken(combatSkillName);
    if (needle.isEmpty) {
      return '';
    }
    for (final talent in combatTalents) {
      if (_normalizeToken(talent.name) == needle) {
        return talent.id;
      }
    }
    return '';
  }

  /// Erstellt einen MainWeaponSlot aus einer Katalog-Waffenvorlage.
  MainWeaponSlot _weaponSlotFromCatalog(
    WeaponDef weapon,
    List<TalentDef> combatTalents,
  ) {
    final tpMatch = RegExp(
      r'^\s*(\d+)\s*[wW]\s*6\s*([+-]\s*\d+)?\s*$',
    ).firstMatch(weapon.tp);
    final tpkkMatch = RegExp(
      r'^\s*(\d+)\s*/\s*(\d+)\s*$',
    ).firstMatch(weapon.tpkk);
    final tpDiceCount = tpMatch == null ? 1 : int.parse(tpMatch.group(1)!);
    final tpFlat = tpMatch == null
        ? 0
        : int.parse((tpMatch.group(2) ?? '0').replaceAll(' ', ''));
    final kkBase = tpkkMatch == null ? 0 : int.parse(tpkkMatch.group(1)!);
    final kkThreshold = tpkkMatch == null ? 1 : int.parse(tpkkMatch.group(2)!);
    final combatType = weaponCombatTypeFromJson(weapon.type);
    final rangedProfile = combatType == WeaponCombatType.ranged
        ? RangedWeaponProfile(
            reloadTime: weapon.reloadTime,
            distanceBands: weapon.rangedDistanceBands,
            projectiles: weapon.rangedProjectiles,
          )
        : const RangedWeaponProfile();
    return MainWeaponSlot(
      name: weapon.name,
      talentId: _findTalentIdByName(weapon.combatSkill, combatTalents),
      combatType: combatType,
      weaponType: weapon.name,
      distanceClass: weapon.reach,
      kkBase: kkBase,
      kkThreshold: kkThreshold < 1 ? 1 : kkThreshold,
      tpDiceCount: tpDiceCount < 1 ? 1 : tpDiceCount,
      tpFlat: tpFlat,
      wmAt: weapon.atMod,
      wmPa: weapon.paMod,
      iniMod: weapon.iniMod,
      rangedProfile: rangedProfile,
    );
  }

  void _showWeaponKatalog(
    BuildContext context, {
    required RulesCatalog catalog,
    required HeroSheet hero,
    required HeroState heroState,
    required List<TalentDef> combatTalents,
  }) {
    final catalogWeapons =
        catalog.weapons.where((w) => w.active).toList(growable: false)..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return SizedBox(
          height: screenHeight * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: _WeaponCatalogTable(
                  weapons: catalogWeapons,
                  meleeTalents: combatTalents,
                  onSelectWeapon: (weapon) async {
                    final slot = _weaponSlotFromCatalog(weapon, combatTalents);
                    Navigator.of(ctx).pop();
                    await _openWeaponEditor(
                      catalog: catalog,
                      hero: hero,
                      heroState: heroState,
                      combatTalents: combatTalents,
                      initialSlot: slot,
                      catalogWeaponName: weapon.name,
                    );
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Waffenvorlage "${weapon.name}" geöffnet',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addWeaponSlot({
    required RulesCatalog catalog,
    required HeroSheet hero,
    required HeroState heroState,
    required List<TalentDef> combatTalents,
  }) async {
    await _openWeaponEditor(
      catalog: catalog,
      hero: hero,
      heroState: heroState,
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
    final combatTalents = _sortedCombatTalents(
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
    final combatTalents = _sortedCombatTalents(
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
    final combatTalents = _sortedCombatTalents(
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

  CombatPreviewStats _previewForWeaponSlot({
    required HeroSheet hero,
    required HeroState heroState,
    required RulesCatalog catalog,
    required MainWeaponSlot slot,
    int? slotIndex,
  }) {
    final tempSlots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    final previewIndex = slotIndex ?? tempSlots.length;
    if (slotIndex == null) {
      tempSlots.add(slot);
    } else if (slotIndex >= 0 && slotIndex < tempSlots.length) {
      tempSlots[slotIndex] = slot;
    }
    final previewConfig = _draftCombatConfig.copyWith(
      weapons: tempSlots,
      selectedWeaponIndex: previewIndex,
      mainWeapon: tempSlots[previewIndex],
      manualMods: _draftCombatConfig.manualMods.copyWith(
        iniWurf: _effectiveIniRollForConfig(_draftCombatConfig),
      ),
    );
    return computeCombatPreviewStats(
      hero,
      heroState,
      overrideConfig: previewConfig,
      overrideTalents: _draftTalents,
      catalogTalents: catalog.talents,
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

  Future<void> _openWeaponEditor({
    required RulesCatalog catalog,
    required HeroSheet hero,
    required HeroState heroState,
    required List<TalentDef> combatTalents,
    int? slotIndex,
    MainWeaponSlot? initialSlot,
    String? catalogWeaponName,
  }) async {
    final slots = _draftCombatConfig.weaponSlots;
    final sourceSlot =
        initialSlot ??
        (slotIndex == null || slotIndex < 0 || slotIndex >= slots.length
            ? const MainWeaponSlot()
            : slots[slotIndex]);
    final result = await showDialog<MainWeaponSlot>(
      context: context,
      builder: (context) {
        return _WeaponEditorDialog(
          isNew: slotIndex == null,
          initialSlot: sourceSlot,
          meleeTalents: combatTalents,
          catalog: catalog,
          catalogWeaponName: catalogWeaponName,
          previewBuilder: (slot) => _previewForWeaponSlot(
            hero: hero,
            heroState: heroState,
            catalog: catalog,
            slot: slot,
            slotIndex: slotIndex,
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    await _saveWeaponSlot(
      slot: result,
      catalog: catalog,
      combatTalents: combatTalents,
      slotIndex: slotIndex,
    );
  }

  Future<void> _setArmorPieces(
    List<ArmorPiece> pieces, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    await _applyCombatConfigChange(
      nextConfig: _draftCombatConfig.copyWith(
        armor: _draftCombatConfig.armor.copyWith(
          pieces: List<ArmorPiece>.unmodifiable(pieces),
        ),
      ),
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

  Future<void> _removeOffhandEquipmentEntry(
    int index, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    final entries = List<OffhandEquipmentEntry>.from(
      _draftCombatConfig.offhandEquipment,
    );
    if (index < 0 || index >= entries.length) {
      return;
    }
    entries.removeAt(index);
    final assignment = _draftCombatConfig.offhandAssignment;
    final nextAssignment = assignment.usesEquipment
        ? (assignment.equipmentIndex == index
              ? const OffhandAssignment()
              : (assignment.equipmentIndex > index
                    ? assignment.copyWith(
                        equipmentIndex: assignment.equipmentIndex - 1,
                      )
                    : assignment))
        : assignment;
    await _applyCombatConfigChange(
      nextConfig: _draftCombatConfig.copyWith(
        offhandEquipment: List<OffhandEquipmentEntry>.unmodifiable(entries),
        offhandAssignment: nextAssignment,
      ),
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _openOffhandEquipmentEditor({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    int? entryIndex,
  }) async {
    final entries = _draftCombatConfig.offhandEquipment;
    final isNew = entryIndex == null;
    final source = isNew ? const OffhandEquipmentEntry() : entries[entryIndex];
    final nameController = TextEditingController(text: source.name);
    final bfController = TextEditingController(
      text: source.breakFactor.toString(),
    );
    final iniController = TextEditingController(text: source.iniMod.toString());
    final atController = TextEditingController(text: source.atMod.toString());
    final paController = TextEditingController(text: source.paMod.toString());
    var type = source.type;
    var shieldSize = source.shieldSize;

    final result = await showDialog<OffhandEquipmentEntry>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isNew
                    ? 'Nebenhand-Ausrüstung hinzufügen'
                    : 'Nebenhand-Ausrüstung bearbeiten',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey<String>('combat-offhand-form-name'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ausrüstungsname',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<OffhandEquipmentType>(
                        key: const ValueKey<String>('combat-offhand-form-type'),
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Waffentalent',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: OffhandEquipmentType.parryWeapon,
                            child: Text('Parierwaffe'),
                          ),
                          DropdownMenuItem(
                            value: OffhandEquipmentType.shield,
                            child: Text('Schild'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            type = value ?? OffhandEquipmentType.parryWeapon;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _dialogNumberField(
                            controller: bfController,
                            keyName: 'combat-offhand-form-bf',
                            label: 'BF',
                          ),
                          _dialogNumberField(
                            controller: iniController,
                            keyName: 'combat-offhand-form-ini-mod',
                            label: 'INI Mod',
                          ),
                          _dialogNumberField(
                            controller: atController,
                            keyName: 'combat-offhand-form-at-mod',
                            label: 'AT Mod',
                          ),
                          _dialogNumberField(
                            controller: paController,
                            keyName: 'combat-offhand-form-pa-mod',
                            label: 'PA Mod',
                          ),
                        ],
                      ),
                      if (type == OffhandEquipmentType.shield) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<ShieldSize>(
                          key: const ValueKey<String>(
                            'combat-offhand-form-shield-size',
                          ),
                          initialValue: shieldSize,
                          decoration: const InputDecoration(
                            labelText: 'Größe',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ShieldSize.small,
                              child: Text('Klein'),
                            ),
                            DropdownMenuItem(
                              value: ShieldSize.large,
                              child: Text('Groß'),
                            ),
                            DropdownMenuItem(
                              value: ShieldSize.veryLarge,
                              child: Text('Sehr groß'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              shieldSize = value ?? ShieldSize.small;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  key: const ValueKey<String>('combat-offhand-form-save'),
                  onPressed: () {
                    final parsedBreakFactor =
                        int.tryParse(bfController.text.trim()) ?? 0;
                    final parsedIni =
                        int.tryParse(iniController.text.trim()) ?? 0;
                    final parsedAt =
                        int.tryParse(atController.text.trim()) ?? 0;
                    final parsedPa =
                        int.tryParse(paController.text.trim()) ?? 0;
                    Navigator.of(context).pop(
                      OffhandEquipmentEntry(
                        name: nameController.text.trim(),
                        type: type,
                        breakFactor: parsedBreakFactor < 0
                            ? 0
                            : parsedBreakFactor,
                        shieldSize: shieldSize,
                        iniMod: parsedIni,
                        atMod: parsedAt,
                        paMod: parsedPa,
                      ),
                    );
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) {
      return;
    }
    final nextEntries = List<OffhandEquipmentEntry>.from(entries);
    if (isNew) {
      nextEntries.add(result);
    } else {
      nextEntries[entryIndex] = result;
    }
    await _setOffhandEquipmentEntries(
      nextEntries,
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _removeArmorPiece(
    int index, {
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    final pieces = List<ArmorPiece>.from(_draftCombatConfig.armor.pieces);
    if (index < 0 || index >= pieces.length) {
      return;
    }
    pieces.removeAt(index);
    await _setArmorPieces(
      pieces,
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Future<void> _openArmorPieceEditor({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    int? pieceIndex,
  }) async {
    final pieces = _draftCombatConfig.armor.pieces;
    final isNew = pieceIndex == null;
    final sourcePiece = isNew ? const ArmorPiece() : pieces[pieceIndex];
    final nameController = TextEditingController(text: sourcePiece.name);
    final rsController = TextEditingController(text: sourcePiece.rs.toString());
    final beController = TextEditingController(text: sourcePiece.be.toString());
    var isActive = sourcePiece.isActive;
    var rg1Active = sourcePiece.rg1Active;
    final canSelectPieceRg1 =
        _draftCombatConfig.armor.globalArmorTrainingLevel == 1;
    String? validationMessage;

    final result = await showDialog<ArmorPiece>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? 'Rüstung hinzufügen' : 'Rüstung bearbeiten'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey<String>('combat-armor-form-name'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _dialogNumberField(
                            controller: rsController,
                            keyName: 'combat-armor-form-rs',
                            label: 'RS',
                          ),
                          _dialogNumberField(
                            controller: beController,
                            keyName: 'combat-armor-form-be',
                            label: 'BE',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        key: const ValueKey<String>('combat-armor-form-active'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktiv'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                      ),
                      if (canSelectPieceRg1)
                        SwitchListTile(
                          key: const ValueKey<String>('combat-armor-form-rg1'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('RG I aktiv'),
                          value: rg1Active,
                          onChanged: (value) {
                            setDialogState(() {
                              rg1Active = value;
                            });
                          },
                        ),
                      if (validationMessage != null &&
                          validationMessage!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            validationMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  key: const ValueKey<String>('combat-armor-form-save'),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final parsedRs =
                        int.tryParse(rsController.text.trim()) ?? 0;
                    final parsedBe =
                        int.tryParse(beController.text.trim()) ?? 0;
                    if (name.isEmpty) {
                      setDialogState(() {
                        validationMessage = 'Name ist ein Pflichtfeld.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(
                      sourcePiece.copyWith(
                        name: name,
                        isActive: isActive,
                        rg1Active: rg1Active,
                        rs: parsedRs < 0 ? 0 : parsedRs,
                        be: parsedBe < 0 ? 0 : parsedBe,
                      ),
                    );
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }
    final updatedPieces = List<ArmorPiece>.from(
      _draftCombatConfig.armor.pieces,
    );
    if (isNew) {
      updatedPieces.add(result);
    } else {
      updatedPieces[pieceIndex] = result;
    }
    await _setArmorPieces(
      updatedPieces,
      catalog: catalog,
      combatTalents: combatTalents,
    );
  }

  Widget _buildWeaponsSubTab(
    List<TalentDef> combatTalents,
    RulesCatalog catalog,
    HeroSheet hero,
    HeroState heroState,
    CombatPreviewStats preview,
  ) {
    final weaponSlots = _draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = _selectedWeaponIndex();
    final sortedTalents = _sortedCombatTalents(combatTalents);
    final overviewRows = _weaponOverviewRows(
      hero: hero,
      heroState: heroState,
      catalog: catalog,
      sortedTalents: sortedTalents,
      selectedWeaponIndex: selectedWeaponIndex,
      weaponSlots: weaponSlots,
    );
    final hasVisibleRows = overviewRows.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Waffen', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                FlexibleTable(
                  tableKey: const ValueKey<String>(
                    'combat-weapons-overview-table',
                  ),
                  columnSpecs: _weaponOverviewColumnSpecs,
                  headerCells: _weaponOverviewHeaderCells(
                    catalog: catalog,
                    hero: hero,
                    heroState: heroState,
                    combatTalents: sortedTalents,
                  ),
                  preHeaderRows: [
                    _weaponOverviewFilterRow(
                      sortedTalents: sortedTalents,
                      weaponSlots: weaponSlots,
                    ),
                  ],
                  rows: overviewRows,
                ),
                if (!hasVisibleRows)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Keine Waffen für den aktuellen Filter vorhanden.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildOffhandEquipmentCard(
          catalog: catalog,
          combatTalents: sortedTalents,
        ),
        const SizedBox(height: 12),
        _buildArmorConfigurationCard(
          armor: _draftCombatConfig.armor,
          preview: preview,
          catalog: catalog,
          sortedTalents: sortedTalents,
        ),
      ],
    );
  }

  Widget _buildMeleeCalculatorSubTab(
    List<TalentDef> combatTalents,
    RulesCatalog catalog,
    HeroSheet hero,
    HeroState heroState,
    CombatPreviewStats preview,
  ) {
    final isEditing = _editController.isEditing;
    final weaponSlots = _draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = _selectedWeaponIndex();
    final armor = _draftCombatConfig.armor;
    final manual = _draftCombatConfig.manualMods;
    final sortedTalents = _sortedCombatTalents(combatTalents);
    final offhandWeapon = _offhandWeaponOrNull();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final selectionCard = _buildActiveWeaponSelectionCard(
              catalog: catalog,
              combatTalents: sortedTalents,
              selectedWeaponIndex: selectedWeaponIndex,
              weaponSlots: weaponSlots,
            );
            final infoCard = _buildActiveWeaponInfoCard(
              selectedWeaponIndex: selectedWeaponIndex,
              preview: preview,
              catalog: catalog,
            );
            final offhandCard = _buildOffhandSelectionAndInfoCard(
              catalog: catalog,
              combatTalents: sortedTalents,
              mainPreview: preview,
              hero: hero,
              heroState: heroState,
              offhandWeapon: offhandWeapon,
            );
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  selectionCard,
                  const SizedBox(height: 12),
                  infoCard,
                  const SizedBox(height: 12),
                  offhandCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: selectionCard),
                const SizedBox(width: 12),
                Expanded(child: infoCard),
                const SizedBox(width: 12),
                Expanded(child: offhandCard),
              ],
            );
          },
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final armorCard = _buildArmorConfigurationCard(
              armor: armor,
              preview: preview,
              catalog: catalog,
              sortedTalents: sortedTalents,
            );
            final iniAusweichenCard = _buildIniAusweichenOverviewCard(
              preview: preview,
              manualAusweichenMod: manual.ausweichenMod,
            );
            if (constraints.maxWidth < 1100) {
              return Column(
                children: [
                  armorCard,
                  const SizedBox(height: 12),
                  iniAusweichenCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: armorCard),
                const SizedBox(width: 12),
                Expanded(child: iniAusweichenCard),
              ],
            );
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manuelle Modifikatoren',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _numberInput(
                      label: 'INI Mod',
                      keyName: 'combat-manual-ini-mod',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          manualMods: manual.copyWith(iniMod: parsed),
                        );
                        _markFieldChanged();
                      },
                    ),
                    _numberInput(
                      label: 'Ausweichen Mod',
                      keyName: 'combat-manual-ausw-mod',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          manualMods: manual.copyWith(ausweichenMod: parsed),
                        );
                        _markFieldChanged();
                      },
                    ),
                    _numberInput(
                      label: 'AT Mod',
                      keyName: 'combat-manual-at-mod',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          manualMods: manual.copyWith(atMod: parsed),
                        );
                        _markFieldChanged();
                      },
                    ),
                    _numberInput(
                      label: 'PA Mod',
                      keyName: 'combat-manual-pa-mod',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          manualMods: manual.copyWith(paMod: parsed),
                        );
                        _markFieldChanged();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ergebnis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (preview.isRangedWeapon)
                      _resultChip('AT-Basis (Fernkampf)', preview.rangedAtBase),
                    _resultChip('RS', preview.rsTotal),
                    _resultChip('BE Roh', preview.beTotalRaw),
                    _resultChip('RG Reduktion', preview.rgReduction),
                    _resultChip('BE (Kampf)', preview.beKampf),
                    _resultChip('BE Mod', preview.beMod),
                    _resultChip('TP/KK', preview.tpKk),
                    _resultChip('GE-Basis', preview.geBase),
                    _resultChip('GE-Schwelle', preview.geThreshold),
                    _resultChip('INI/GE', preview.iniGe),
                    _resultChip(
                      'Helden+Waffen INI',
                      preview.kombinierteHeldenWaffenIni,
                    ),
                    _resultChip('TK-Kalk', preview.tpCalc),
                    Chip(
                      label: Text(
                        'Spezialisierung: ${preview.specApplies ? 'Ja' : 'Nein'}',
                      ),
                    ),
                    Chip(label: Text('Kampf INI: ${preview.kampfInitiative}')),
                    _resultChip('Ausweichen', preview.ausweichen),
                    _resultChip('AT', preview.at),
                    if (!preview.isRangedWeapon)
                      _resultChip('PA', preview.paMitIniParadeMod),
                    _resultChip('eBE', preview.ebe),
                    Chip(label: Text('TP: ${preview.tpExpression}')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveWeaponSelectionCard({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    required int selectedWeaponIndex,
    required List<MainWeaponSlot> weaponSlots,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Haupthand', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              key: ValueKey<String>(
                'combat-main-weapon-select-${selectedWeaponIndex < 0 ? 'none' : selectedWeaponIndex}-${weaponSlots.length}',
              ),
              initialValue: selectedWeaponIndex < 0
                  ? null
                  : selectedWeaponIndex,
              decoration: const InputDecoration(
                labelText: 'Aktive Waffe',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Keine Waffe'),
                ),
                for (var i = 0; i < weaponSlots.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(
                      weaponSlots[i].name.trim().isEmpty
                          ? 'Waffe ${i + 1}'
                          : weaponSlots[i].name,
                    ),
                  ),
              ],
              onChanged: (value) {
                _selectWeaponIndex(
                  value,
                  catalog: catalog,
                  combatTalents: combatTalents,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffhandSelectionAndInfoCard({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    required CombatPreviewStats mainPreview,
    required HeroSheet hero,
    required HeroState heroState,
    required MainWeaponSlot? offhandWeapon,
  }) {
    final assignment = _draftCombatConfig.offhandAssignment;
    final offhandEquipment = _offhandEquipmentOrNull();
    final selectedValue = assignment.usesWeapon
        ? 'weapon:${assignment.weaponIndex}'
        : (assignment.usesEquipment
              ? 'equipment:${assignment.equipmentIndex}'
              : 'none');
    final selectedWeaponIndex = _selectedWeaponIndex();
    final offhandWeaponPreview =
        assignment.usesWeapon &&
            assignment.weaponIndex >= 0 &&
            assignment.weaponIndex < _draftCombatConfig.weaponSlots.length
        ? computeCombatPreviewStats(
            hero,
            heroState,
            overrideConfig: _draftCombatConfig.copyWith(
              selectedWeaponIndex: assignment.weaponIndex,
              mainWeapon:
                  _draftCombatConfig.weaponSlots[assignment.weaponIndex],
              offhandAssignment: const OffhandAssignment(),
              manualMods: _draftCombatConfig.manualMods.copyWith(
                iniWurf: _effectiveIniRollForConfig(_draftCombatConfig),
              ),
            ),
            overrideTalents: _draftTalents,
            catalogTalents: catalog.talents,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nebenhand', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('combat-offhand-selection'),
              initialValue: selectedValue,
              decoration: const InputDecoration(
                labelText: 'Nebenhand',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: 'none',
                  child: Text('Keine'),
                ),
                for (var i = 0; i < _draftCombatConfig.weaponSlots.length; i++)
                  if (i != selectedWeaponIndex)
                    DropdownMenuItem<String>(
                      value: 'weapon:$i',
                      child: Text(
                        'Waffe: ${_draftCombatConfig.weaponSlots[i].name.trim().isEmpty ? 'Waffe ${i + 1}' : _draftCombatConfig.weaponSlots[i].name}',
                      ),
                    ),
                for (
                  var i = 0;
                  i < _draftCombatConfig.offhandEquipment.length;
                  i++
                )
                  DropdownMenuItem<String>(
                    value: 'equipment:$i',
                    child: Text(
                      '${_draftCombatConfig.offhandEquipment[i].isShield ? 'Schild' : 'Parierwaffe'}: '
                      '${_draftCombatConfig.offhandEquipment[i].name.trim().isEmpty ? 'Eintrag ${i + 1}' : _draftCombatConfig.offhandEquipment[i].name}',
                    ),
                  ),
              ],
              onChanged: (value) {
                final nextAssignment = switch (value ?? 'none') {
                  'none' => const OffhandAssignment(),
                  final raw when raw.startsWith('weapon:') => OffhandAssignment(
                    weaponIndex:
                        int.tryParse(raw.substring('weapon:'.length)) ?? -1,
                  ),
                  final raw when raw.startsWith('equipment:') =>
                    OffhandAssignment(
                      equipmentIndex:
                          int.tryParse(raw.substring('equipment:'.length)) ??
                          -1,
                    ),
                  _ => const OffhandAssignment(),
                };
                _applyCombatConfigChange(
                  nextConfig: _draftCombatConfig.copyWith(
                    offhandAssignment: nextAssignment,
                  ),
                  catalog: catalog,
                  combatTalents: combatTalents,
                );
              },
            ),
            const SizedBox(height: 12),
            if (offhandWeaponPreview != null && offhandWeapon != null) ...[
              Text(
                'Nebenhand-Waffe',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      offhandWeapon.name.trim().isEmpty
                          ? 'Waffe'
                          : offhandWeapon.name,
                    ),
                  ),
                  Chip(label: Text('AT: ${offhandWeaponPreview.at}')),
                  if (!offhandWeaponPreview.isRangedWeapon)
                    Chip(
                      label: Text(
                        'PA: ${offhandWeaponPreview.paMitIniParadeMod}',
                      ),
                    ),
                  Chip(label: Text('TP: ${offhandWeaponPreview.tpExpression}')),
                  Chip(label: Text('INI: ${mainPreview.kampfInitiative}')),
                ],
              ),
            ] else if (offhandEquipment != null) ...[
              Text(
                offhandEquipment.isShield ? 'Schild' : 'Parierwaffe',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      offhandEquipment.name.trim().isEmpty
                          ? 'Unbenannt'
                          : offhandEquipment.name,
                    ),
                  ),
                  Chip(label: Text('AT Mod: ${offhandEquipment.atMod}')),
                  Chip(label: Text('INI Mod: ${offhandEquipment.iniMod}')),
                  Chip(label: Text('PA Mod: ${offhandEquipment.paMod}')),
                  if (offhandEquipment.isShield)
                    Chip(
                      key: const ValueKey<String>('combat-offhand-shield-pa'),
                      label: Text('Schild-PA: ${mainPreview.shieldPa}'),
                    ),
                  if (mainPreview.offhandRequiresLinkhand)
                    const Chip(label: Text('Linkhand erforderlich')),
                ],
              ),
            ] else
              const Text('Keine Nebenhand belegt.'),
          ],
        ),
      ),
    );
  }

  Widget _buildOffhandEquipmentCard({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) {
    final entries = _draftCombatConfig.offhandEquipment;
    final rows = <FlexibleTableRow>[
      for (var i = 0; i < entries.length; i++)
        FlexibleTableRow(
          cells: [
            _tappableWeaponNameCell(
              entries[i].name.trim().isEmpty
                  ? 'Eintrag ${i + 1}'
                  : entries[i].name,
              onTap: () => _openOffhandEquipmentEditor(
                catalog: catalog,
                combatTalents: combatTalents,
                entryIndex: i,
              ),
            ),
            Text(entries[i].isShield ? 'Schild' : 'Parierwaffe'),
            Text(entries[i].breakFactor.toString()),
            Text(
              entries[i].isShield
                  ? _shieldSizeLabel(entries[i].shieldSize)
                  : '-',
            ),
            Text(entries[i].iniMod.toString()),
            Text(entries[i].atMod.toString()),
            Text(entries[i].paMod.toString()),
            IconButton(
              key: ValueKey<String>('combat-offhand-remove-$i'),
              tooltip: 'Nebenhand-Ausrüstung entfernen',
              onPressed: () => _removeOffhandEquipmentEntry(
                i,
                catalog: catalog,
                combatTalents: combatTalents,
              ),
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parierwaffen & Schilde',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FlexibleTable(
              tableKey: const ValueKey<String>('combat-offhand-table'),
              columnSpecs: _offhandColumnSpecs,
              headerCells: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Name'),
                    IconButton(
                      key: const ValueKey<String>('combat-offhand-add'),
                      tooltip: 'Nebenhand-Ausrüstung hinzufügen',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      onPressed: () => _openOffhandEquipmentEditor(
                        catalog: catalog,
                        combatTalents: combatTalents,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
                const Text('Typ'),
                const Text('BF'),
                const Text('Groesse'),
                const Text('INI Mod'),
                const Text('AT Mod'),
                const Text('PA Mod'),
                const Text('Aktion'),
              ],
              rows: rows,
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Keine Parierwaffen oder Schilde erfasst.'),
              ),
          ],
        ),
      ),
    );
  }

  String _shieldSizeLabel(ShieldSize size) {
    return switch (size) {
      ShieldSize.small => 'Klein',
      ShieldSize.large => 'Groß',
      ShieldSize.veryLarge => 'Sehr groß',
    };
  }

  Widget _buildArmorConfigurationCard({
    required ArmorConfig armor,
    required CombatPreviewStats preview,
    required RulesCatalog catalog,
    required List<TalentDef> sortedTalents,
  }) {
    const armorDetailsBreakpoint = 760.0;
    final showPieceRg1 = armor.globalArmorTrainingLevel == 1;
    final armorRows = <FlexibleTableRow>[
      for (var i = 0; i < armor.pieces.length; i++)
        FlexibleTableRow(
          cells: [
            _tappableWeaponNameCell(
              armor.pieces[i].name.trim().isEmpty
                  ? 'Rüstung ${i + 1}'
                  : armor.pieces[i].name,
              onTap: () => _openArmorPieceEditor(
                catalog: catalog,
                combatTalents: sortedTalents,
                pieceIndex: i,
              ),
            ),
            Text(armor.pieces[i].rs.toString()),
            Text(armor.pieces[i].be.toString()),
            Text(armor.pieces[i].isActive ? 'Ja' : 'Nein'),
            if (showPieceRg1) Text(armor.pieces[i].rg1Active ? 'Ja' : 'Nein'),
            IconButton(
              key: ValueKey<String>('combat-armor-remove-$i'),
              tooltip: 'Rüstung entfernen',
              onPressed: () => _removeArmorPiece(
                i,
                catalog: catalog,
                combatTalents: sortedTalents,
              ),
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rüstung', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final armorTableSection = Column(
                  key: const ValueKey<String>('combat-armor-table-section'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FlexibleTable(
                      tableKey: const ValueKey<String>('combat-armor-table'),
                      columnSpecs: _armorColumnSpecs(
                        showPieceRg1: showPieceRg1,
                      ),
                      headerCells: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Name'),
                            IconButton(
                              key: const ValueKey<String>('combat-armor-add'),
                              tooltip: 'Rüstung hinzufügen',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 30,
                                height: 30,
                              ),
                              onPressed: () => _openArmorPieceEditor(
                                catalog: catalog,
                                combatTalents: sortedTalents,
                              ),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                        const Text('RS'),
                        const Text('BE'),
                        const Text('Aktiv'),
                        if (showPieceRg1) const Text('RG I'),
                        const Text('Aktion'),
                      ],
                      rows: armorRows,
                    ),
                    if (armorRows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Keine Rüstungsstücke erfasst.'),
                      ),
                  ],
                );
                final armorCalculationSection = Column(
                  key: const ValueKey<String>(
                    'combat-armor-calculation-section',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RS gesamt = Summe aktiver RS = ${preview.rsTotal}'),
                    Text(
                      'BE (Kampf) = BE Roh (${preview.beTotalRaw}) - RG (${preview.rgReduction}) = ${preview.beKampf}',
                    ),
                    Text(
                      'eBE = min(0, -BE(Kampf) (${preview.beKampf}) - BE Mod (${preview.beMod})) = ${preview.ebe}',
                    ),
                  ],
                );
                if (constraints.maxWidth < armorDetailsBreakpoint) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      armorTableSection,
                      const SizedBox(height: 8),
                      armorCalculationSection,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: armorTableSection),
                    const SizedBox(width: 16),
                    Expanded(child: armorCalculationSection),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIniAusweichenOverviewCard({
    required CombatPreviewStats preview,
    required int manualAusweichenMod,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ini & Ausweichen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _resultChip('Kampf INI', preview.kampfInitiative),
                _resultChip(
                  'Helden+Waffen INI',
                  preview.kombinierteHeldenWaffenIni,
                ),
                _resultChip('PA inkl. INI-Bonus', preview.paMitIniParadeMod),
              ],
            ),
            const Divider(),
            Text(
              'Ausweichen = ${preview.ausweichen}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'PA Anzeige = Waffen-PA (${preview.pa})'
              ' + INI-Parade-Bonus (${preview.iniParadeMod})'
              ' = ${preview.paMitIniParadeMod}',
            ),
            const SizedBox(height: 4),
            Text(
              'PA-Basis (${preview.paBase})'
              ' [Grundwert + Axx (${preview.axxPaBaseBonus})]'
              ' + SF (${preview.sfAusweichenBonus})'
              ' + Akrobatik (${preview.akrobatikBonus})'
              ' + Axx (${preview.axxAusweichenBonus})'
              ' + INI (${preview.iniAusweichenBonus})'
              ' + Mod ($manualAusweichenMod)'
              ' - BE (${preview.beKampf})',
            ),
            if (preview.axxAttackDefenseHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(preview.axxAttackDefenseHint),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWeaponInfoCard({
    required int selectedWeaponIndex,
    required CombatPreviewStats preview,
    required RulesCatalog catalog,
  }) {
    final hasActiveWeapon =
        selectedWeaponIndex >= 0 &&
        selectedWeaponIndex < _draftCombatConfig.weaponSlots.length;
    final activeWeapon = hasActiveWeapon
        ? _draftCombatConfig.weaponSlots[selectedWeaponIndex]
        : const MainWeaponSlot();
    final activeSupportedManeuvers = hasActiveWeapon
        ? _activeSupportedManeuversForSelectedWeapon(catalog)
        : const <String>[];
    return Card(
      key: const ValueKey<String>('combat-active-weapon-info-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktive Waffe - Übersicht',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (!hasActiveWeapon)
              const Text('Keine aktive Waffe ausgewählt.')
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (preview.isRangedWeapon)
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-at',
                      ),
                      label: Text('AT: ${preview.at}'),
                    )
                  else ...[
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-at',
                      ),
                      label: Text('AT: ${preview.at}'),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-pa',
                      ),
                      label: Text('PA: ${preview.paMitIniParadeMod}'),
                    ),
                  ],
                  Chip(
                    key: const ValueKey<String>('combat-active-weapon-info-tp'),
                    label: Text('TP: ${preview.tpExpression}'),
                  ),
                  if (preview.isRangedWeapon) ...[
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-reload-time',
                      ),
                      label: Text('Ladezeit: ${preview.reloadTimeDisplay}'),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-projectile-count',
                      ),
                      label: Text(
                        'Geschosse: ${preview.activeProjectileCount}',
                      ),
                    ),
                  ] else ...[
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-helden-ini',
                      ),
                      label: Text(_heldenIniLabel(preview)),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-helden-waffen-ini',
                      ),
                      label: Text(_heldenWaffenIniLabel(preview)),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-ini',
                      ),
                      label: Text(_kampfIniLabel(preview)),
                    ),
                  ],
                ],
              ),
              if (preview.isRangedWeapon) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey<String>(
                    'combat-active-weapon-distance-select',
                  ),
                  initialValue:
                      activeWeapon.rangedProfile.selectedDistanceIndex,
                  decoration: const InputDecoration(
                    labelText: 'Entfernung',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (
                      var i = 0;
                      i < activeWeapon.rangedProfile.distanceBands.length;
                      i++
                    )
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          activeWeapon.rangedProfile.distanceBands[i].label
                                  .trim()
                                  .isEmpty
                              ? 'Distanz ${i + 1}'
                              : activeWeapon
                                    .rangedProfile
                                    .distanceBands[i]
                                    .label,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _updateSelectedRangedDistance(value, catalog: catalog);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  key: const ValueKey<String>(
                    'combat-active-weapon-projectile-select',
                  ),
                  initialValue:
                      activeWeapon.rangedProfile.selectedProjectileIndex < 0
                      ? null
                      : activeWeapon.rangedProfile.selectedProjectileIndex,
                  decoration: const InputDecoration(
                    labelText: 'Geschoss',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Kein Geschoss'),
                    ),
                    for (
                      var i = 0;
                      i < activeWeapon.rangedProfile.projectiles.length;
                      i++
                    )
                      DropdownMenuItem<int?>(
                        value: i,
                        child: Text(
                          activeWeapon.rangedProfile.projectiles[i].name
                                  .trim()
                                  .isEmpty
                              ? 'Geschoss ${i + 1}'
                              : activeWeapon.rangedProfile.projectiles[i].name,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    _updateSelectedRangedProjectile(
                      value ?? -1,
                      catalog: catalog,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey<String>(
                        'combat-active-weapon-projectile-count-decrement',
                      ),
                      onPressed: () =>
                          _adjustSelectedProjectileCount(-1, catalog: catalog),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'combat-active-weapon-projectile-count-increment',
                      ),
                      onPressed: () =>
                          _adjustSelectedProjectileCount(1, catalog: catalog),
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preview.activeProjectileDescription.trim().isEmpty
                            ? 'Keine Geschossbeschreibung vorhanden.'
                            : preview.activeProjectileDescription,
                        key: const ValueKey<String>(
                          'combat-active-weapon-info-projectile-description',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                const SizedBox(height: 8),
                _activeWeaponIniRollEditor(preview),
                const SizedBox(height: 12),
              ],
              buildWeaponCalculationDetails(
                preview: preview,
                isEditing: _editController.isEditing,
              ),
              if (!preview.isRangedWeapon) ...[
                const SizedBox(height: 8),
                Text('Manoever', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                if (activeSupportedManeuvers.isEmpty)
                  const Text(
                    'Keine erlernten, waffenkompatiblen Manöver.',
                    key: ValueKey<String>(
                      'combat-active-weapon-info-maneuvers',
                    ),
                  )
                else
                  Wrap(
                    key: const ValueKey<String>(
                      'combat-active-weapon-info-maneuvers',
                    ),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final maneuver in activeSupportedManeuvers)
                        Chip(label: Text(maneuver)),
                    ],
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<String> _activeSupportedManeuversForSelectedWeapon(
    RulesCatalog catalog,
  ) {
    final activeManeuvers = _draftCombatConfig.specialRules.activeManeuvers;
    if (activeManeuvers.isEmpty) {
      return const <String>[];
    }
    final allCatalogManeuvers = _collectCatalogManeuvers(catalog.weapons);
    if (allCatalogManeuvers.isEmpty) {
      return const <String>[];
    }
    final supportByManeuver = _buildManeuverSupportMap(
      catalog,
      allCatalogManeuvers,
    );
    final supportedTokens = supportByManeuver.entries
        .where((entry) => entry.value == _ManeuverSupportStatus.supported)
        .map((entry) => _normalizeToken(entry.key))
        .where((entry) => entry.isNotEmpty)
        .toSet();
    final filtered = <String>[];
    final seen = <String>{};
    for (final raw in activeManeuvers) {
      final trimmed = raw.trim();
      final token = _normalizeToken(trimmed);
      if (trimmed.isEmpty ||
          token.isEmpty ||
          seen.contains(token) ||
          !supportedTokens.contains(token)) {
        continue;
      }
      seen.add(token);
      filtered.add(trimmed);
    }
    return filtered;
  }

  String _heldenIniLabel(CombatPreviewStats preview) {
    final specialRules = _draftCombatConfig.specialRules;
    final rollToken = specialRules.aufmerksamkeit
        ? '${preview.iniDiceCount}W6'
        : preview.iniWurfEffective.toString();
    final heldenBaseWithoutRoll =
        preview.heldenInitiative - preview.iniWurfEffective;
    final eigenschaftsIni = preview.eigenschaftsIni;
    final axxIni = preview.axxIniBonus;
    final sonstigeIni = heldenBaseWithoutRoll - eigenschaftsIni - axxIni;
    if (axxIni > 0) {
      return 'Helden INI: Ini-Basis $eigenschaftsIni + Axx $axxIni + '
          'sonstige Modifikatoren $sonstigeIni + $rollToken = '
          '${preview.heldenInitiative}';
    }
    return 'Helden INI: $heldenBaseWithoutRoll + $rollToken = '
        '${preview.heldenInitiative}';
  }

  String _kampfIniLabel(CombatPreviewStats preview) {
    final diff = preview.kampfInitiative - preview.kombinierteHeldenWaffenIni;
    final sign = diff < 0 ? '-' : '+';
    return 'Kampf INI: ${preview.kombinierteHeldenWaffenIni} $sign ${diff.abs()} = ${preview.kampfInitiative}';
  }

  String _heldenWaffenIniLabel(CombatPreviewStats preview) {
    final diff = preview.kombinierteHeldenWaffenIni - preview.heldenInitiative;
    final sign = diff < 0 ? '-' : '+';
    return 'Helden+Waffen INI: ${preview.heldenInitiative} $sign ${diff.abs()} = ${preview.kombinierteHeldenWaffenIni}';
  }

  Widget _activeWeaponIniRollEditor(CombatPreviewStats preview) {
    final maxRoll = preview.iniDiceCount * 6;
    final isAuto = _draftCombatConfig.specialRules.aufmerksamkeit;
    final effectiveRoll = _effectiveIniRollForConfig(_draftCombatConfig);
    final controller = _controllerFor(
      'combat-active-weapon-info-ini-roll',
      effectiveRoll.toString(),
    );
    final desiredText = effectiveRoll.toString();
    if (controller.text != desiredText) {
      controller.value = TextEditingValue(
        text: desiredText,
        selection: TextSelection.collapsed(offset: desiredText.length),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: TextField(
            key: const ValueKey<String>('combat-active-weapon-info-ini-roll'),
            controller: controller,
            readOnly: isAuto,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'INI-Wurf (0-$maxRoll)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: isAuto
                ? null
                : (raw) {
                    final parsed = int.tryParse(raw.trim()) ?? 0;
                    _setTemporaryIniRoll(parsed);
                  },
          ),
        ),
        if (isAuto)
          Chip(label: Text('Aufmerksamkeit aktiv: automatisch $maxRoll')),
      ],
    );
  }

  static const List<String> _weaponOverviewHeaders = <String>[
    'Name',
    'Typ',
    'Waffentalent',
    'Waffenart',
    'DK',
    'AT',
    'PA',
    'TP',
    'INI',
    'BF',
    'eBE',
    'Artefakt',
    'Artefaktbeschreibung',
    'Aktion',
  ];

  List<Widget> _weaponOverviewHeaderCells({
    required RulesCatalog catalog,
    required HeroSheet hero,
    required HeroState heroState,
    required List<TalentDef> combatTalents,
  }) {
    final cells = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Name'),
          IconButton(
            key: const ValueKey<String>('combat-weapon-add'),
            tooltip: 'Leere Waffe hinzufuegen',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: () => _addWeaponSlot(
              catalog: catalog,
              hero: hero,
              heroState: heroState,
              combatTalents: combatTalents,
            ),
            icon: const Icon(Icons.add, size: 18),
          ),
          IconButton(
            key: const ValueKey<String>('combat-weapon-from-catalog'),
            tooltip: 'Waffe aus Katalog hinzufuegen',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: () => _showWeaponKatalog(
              context,
              catalog: catalog,
              hero: hero,
              heroState: heroState,
              combatTalents: combatTalents,
            ),
            icon: const Icon(Icons.library_add, size: 18),
          ),
        ],
      ),
      for (final header in _weaponOverviewHeaders.skip(1)) Text(header),
    ];
    return cells;
  }

  Widget _tappableWeaponNameCell(String text, {required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final display = text.trim().isEmpty ? '-' : text.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        display,
        style: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  List<Widget> _weaponOverviewFilterRow({
    required List<TalentDef> sortedTalents,
    required List<MainWeaponSlot> weaponSlots,
  }) {
    final combatTypeValues = weaponSlots
        .map((slot) => slot.combatType)
        .toSet()
        .toList(growable: false);
    final weaponTypeValues =
        weaponSlots
            .map((slot) => slot.weaponType.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final distanceClassValues =
        weaponSlots
            .map((slot) => slot.distanceClass.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final filteredTalentValue =
        sortedTalents.any((talent) => talent.id == _weaponFilterTalentId)
        ? _weaponFilterTalentId
        : '';
    final filteredCombatTypeValue =
        combatTypeValues.any(
          (value) => weaponCombatTypeToJson(value) == _weaponFilterCombatType,
        )
        ? _weaponFilterCombatType
        : '';
    final filteredTypeValue = weaponTypeValues.contains(_weaponFilterType)
        ? _weaponFilterType
        : '';
    final filteredDkValue =
        distanceClassValues.contains(_weaponFilterDistanceClass)
        ? _weaponFilterDistanceClass
        : '';
    final cells = List<Widget>.filled(
      _weaponOverviewHeaders.length,
      const SizedBox.shrink(),
      growable: false,
    );
    cells[1] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-combat-type'),
      initialValue: filteredCombatTypeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter Typ',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...combatTypeValues.map(
          (combatType) => DropdownMenuItem<String>(
            value: weaponCombatTypeToJson(combatType),
            child: Text(_combatTypeLabel(combatType)),
          ),
        ),
      ],
      onChanged: (value) {
        _weaponFilterCombatType = value ?? '';
        if (mounted) {
          _viewRevision.value++;
        }
      },
    );
    cells[2] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-talent'),
      initialValue: filteredTalentValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter Talent',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...sortedTalents.map(
          (talent) => DropdownMenuItem<String>(
            value: talent.id,
            child: Text(
              talent.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        _weaponFilterTalentId = value ?? '';
        if (mounted) {
          _viewRevision.value++;
        }
      },
    );
    cells[3] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-weapon-type'),
      initialValue: filteredTypeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter Waffenart',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...weaponTypeValues.map(
          (weaponType) => DropdownMenuItem<String>(
            value: weaponType,
            child: Text(
              weaponType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        _weaponFilterType = value ?? '';
        if (mounted) {
          _viewRevision.value++;
        }
      },
    );
    cells[4] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-dk'),
      initialValue: filteredDkValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter DK',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...distanceClassValues.map(
          (distanceClass) => DropdownMenuItem<String>(
            value: distanceClass,
            child: Text(
              distanceClass,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        _weaponFilterDistanceClass = value ?? '';
        if (mounted) {
          _viewRevision.value++;
        }
      },
    );
    return cells;
  }

  List<FlexibleTableRow> _weaponOverviewRows({
    required HeroSheet hero,
    required HeroState heroState,
    required RulesCatalog catalog,
    required List<TalentDef> sortedTalents,
    required int selectedWeaponIndex,
    required List<MainWeaponSlot> weaponSlots,
  }) {
    final talentById = <String, TalentDef>{
      for (final talent in sortedTalents) talent.id: talent,
    };
    final availableTypes = weaponSlots
        .map((slot) => slot.weaponType.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final availableCombatTypes = weaponSlots
        .map((slot) => weaponCombatTypeToJson(slot.combatType))
        .toSet();
    final availableDistanceClasses = weaponSlots
        .map((slot) => slot.distanceClass.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final activeTalentFilter =
        sortedTalents.any((talent) => talent.id == _weaponFilterTalentId)
        ? _weaponFilterTalentId
        : '';
    final activeCombatTypeFilter =
        availableCombatTypes.contains(_weaponFilterCombatType)
        ? _weaponFilterCombatType
        : '';
    final activeTypeFilter = availableTypes.contains(_weaponFilterType)
        ? _weaponFilterType
        : '';
    final activeDistanceClassFilter =
        availableDistanceClasses.contains(_weaponFilterDistanceClass)
        ? _weaponFilterDistanceClass
        : '';
    final indexed = <({int index, MainWeaponSlot slot})>[
      for (var i = 0; i < weaponSlots.length; i++)
        (index: i, slot: weaponSlots[i]),
    ];
    final ordered = <({int index, MainWeaponSlot slot})>[
      ...indexed.where((entry) => entry.index == selectedWeaponIndex),
      ...indexed.where((entry) => entry.index != selectedWeaponIndex),
    ];
    final filtered = ordered
        .where((entry) {
          final slot = entry.slot;
          if (activeCombatTypeFilter.isNotEmpty &&
              weaponCombatTypeToJson(slot.combatType) !=
                  activeCombatTypeFilter) {
            return false;
          }
          if (activeTalentFilter.isNotEmpty &&
              slot.talentId.trim() != activeTalentFilter) {
            return false;
          }
          if (activeTypeFilter.isNotEmpty &&
              slot.weaponType.trim() != activeTypeFilter) {
            return false;
          }
          if (activeDistanceClassFilter.isNotEmpty &&
              slot.distanceClass.trim() != activeDistanceClassFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return filtered
        .map((entry) {
          final slot = entry.slot;
          final talentOptions = _sortedCombatTalentsForType(
            sortedTalents,
            slot.combatType,
          );
          final preview = computeCombatPreviewStats(
            hero,
            heroState,
            overrideConfig: _draftCombatConfig.copyWith(
              selectedWeaponIndex: entry.index,
              mainWeapon: slot,
              manualMods: _draftCombatConfig.manualMods.copyWith(
                iniWurf: _effectiveIniRollForConfig(_draftCombatConfig),
              ),
            ),
            overrideTalents: _draftTalents,
            catalogTalents: catalog.talents,
          );
          final artifactDescription = slot.isArtifact
              ? (slot.artifactDescription.trim().isEmpty
                    ? '-'
                    : slot.artifactDescription.trim())
              : '-';
          final cells = <Widget>[
            _tappableWeaponNameCell(
              slot.name,
              onTap: () => _openWeaponEditor(
                catalog: catalog,
                hero: hero,
                heroState: heroState,
                combatTalents: sortedTalents,
                slotIndex: entry.index,
              ),
            ),
            Text(_combatTypeLabel(slot.combatType)),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('combat-weapon-cell-talent-${entry.index}'),
              initialValue:
                  talentById.containsKey(slot.talentId.trim()) &&
                      talentOptions.any(
                        (talent) => talent.id == slot.talentId.trim(),
                      )
                  ? slot.talentId.trim()
                  : '',
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('-')),
                ...talentOptions.map(
                  (talent) => DropdownMenuItem<String>(
                    value: talent.id,
                    child: Text(
                      talent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                final nextTalentId = value ?? '';
                final nextTalent = _findTalentById(talentOptions, nextTalentId);
                final allowedWeaponTypes = _weaponTypeOptionsForTalent(
                  talent: nextTalent,
                  catalog: catalog,
                  combatType: slot.combatType,
                );
                final nextWeaponType =
                    allowedWeaponTypes.contains(slot.weaponType.trim())
                    ? slot.weaponType.trim()
                    : '';
                final nextName =
                    slot.name.trim().isEmpty && nextWeaponType.isNotEmpty
                    ? nextWeaponType
                    : slot.name;
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(
                    talentId: nextTalentId,
                    weaponType: nextWeaponType,
                    name: nextName,
                  ),
                  catalog: catalog,
                  combatTalents: sortedTalents,
                );
              },
            ),
            Text(slot.weaponType.trim().isEmpty ? '-' : slot.weaponType.trim()),
            Text(
              slot.isRanged
                  ? (slot.rangedProfile.selectedDistanceBand.label
                            .trim()
                            .isEmpty
                        ? '-'
                        : slot.rangedProfile.selectedDistanceBand.label.trim())
                  : (slot.distanceClass.trim().isEmpty
                        ? '-'
                        : slot.distanceClass.trim()),
            ),
            Text(preview.at.toString()),
            Text(slot.isRanged ? '-' : preview.pa.toString()),
            Text(preview.tpExpression),
            Text(
              preview.kombinierteHeldenWaffenIni.toString(),
              key: ValueKey<String>('combat-weapon-cell-ini-${entry.index}'),
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>('combat-weapon-cell-bf-${entry.index}'),
              value: slot.breakFactor.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.breakFactor;
                _updateWeaponSlot(
                  entry.index,
                  (current) =>
                      current.copyWith(breakFactor: parsed < 0 ? 0 : parsed),
                  catalog: catalog,
                  combatTalents: sortedTalents,
                );
              },
            ),
            Text(preview.ebe.toString()),
            Text(slot.isArtifact ? 'Ja' : 'Nein'),
            Text(
              artifactDescription,
              key: ValueKey<String>(
                'combat-weapon-cell-artifact-description-${entry.index}',
              ),
            ),
            IconButton(
              key: ValueKey<String>('combat-weapon-remove-${entry.index}'),
              tooltip: 'Waffe entfernen',
              onPressed: weaponSlots.length <= 1
                  ? null
                  : () => _removeWeaponSlotAt(
                      entry.index,
                      catalog: catalog,
                      combatTalents: sortedTalents,
                    ),
              icon: const Icon(Icons.delete),
            ),
          ];

          final isSelected =
              selectedWeaponIndex >= 0 && entry.index == selectedWeaponIndex;
          return FlexibleTableRow(
            key: ValueKey<String>('combat-weapons-row-${entry.index}'),
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            cells: cells,
          );
        })
        .toList(growable: false);
  }
}
