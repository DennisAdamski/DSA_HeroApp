part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatMeleeSubtab on _HeroCombatTabState {
  List<TalentDef> _sortedMeleeTalents(List<TalentDef> combatTalents) {
    final talents =
        combatTalents
            .where((talent) => talent.type.trim().toLowerCase() == 'nahkampf')
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return talents;
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
  }) {
    if (talent == null) {
      return const <String>[];
    }
    final seen = <String>{};
    final options = <String>[];
    final talentNameToken = _normalizeToken(talent.name);
    for (final weapon in catalog.weapons) {
      if (weapon.type.trim().toLowerCase() != 'nahkampf') {
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
    List<TalentDef> meleeTalents,
  ) {
    final needle = _normalizeToken(combatSkillName);
    if (needle.isEmpty) {
      return '';
    }
    for (final talent in meleeTalents) {
      if (_normalizeToken(talent.name) == needle) {
        return talent.id;
      }
    }
    return '';
  }

  /// Erstellt einen MainWeaponSlot aus einer Katalog-Waffenvorlage.
  MainWeaponSlot _weaponSlotFromCatalog(
    WeaponDef weapon,
    List<TalentDef> meleeTalents,
  ) {
    final tpMatch = RegExp(
      r'^\s*(\d+)\s*[wW]\s*6\s*([+-]\s*\d+)?\s*$',
    ).firstMatch(weapon.tp);
    final tpkkMatch = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(
      weapon.tpkk,
    );
    final tpDiceCount = tpMatch == null ? 1 : int.parse(tpMatch.group(1)!);
    final tpFlat = tpMatch == null
        ? 0
        : int.parse((tpMatch.group(2) ?? '0').replaceAll(' ', ''));
    final kkBase = tpkkMatch == null ? 0 : int.parse(tpkkMatch.group(1)!);
    final kkThreshold = tpkkMatch == null
        ? 1
        : int.parse(tpkkMatch.group(2)!);
    return MainWeaponSlot(
      name: weapon.name,
      talentId: _findTalentIdByName(weapon.combatSkill, meleeTalents),
      weaponType: weapon.name,
      distanceClass: weapon.reach,
      kkBase: kkBase,
      kkThreshold: kkThreshold < 1 ? 1 : kkThreshold,
      tpDiceCount: tpDiceCount < 1 ? 1 : tpDiceCount,
      tpFlat: tpFlat,
      wmAt: weapon.atMod,
      wmPa: weapon.paMod,
      iniMod: weapon.iniMod,
    );
  }

  void _showWeaponKatalog(
    BuildContext context, {
    required RulesCatalog catalog,
    required HeroSheet hero,
    required HeroState heroState,
    required List<TalentDef> meleeTalents,
  }) {
    final meleeWeapons = catalog.weapons
        .where((w) => w.active && w.type.trim().toLowerCase() == 'nahkampf')
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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
                  weapons: meleeWeapons,
                  meleeTalents: meleeTalents,
                  onSelectWeapon: (weapon) async {
                    final slot = _weaponSlotFromCatalog(weapon, meleeTalents);
                    Navigator.of(ctx).pop();
                    await _openWeaponEditor(
                      catalog: catalog,
                      hero: hero,
                      heroState: heroState,
                      meleeTalents: meleeTalents,
                      initialSlot: slot,
                      catalogWeaponName: weapon.name,
                    );
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Waffenvorlage "${weapon.name}" geoeffnet',
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
    required List<TalentDef> meleeTalents,
  }) async {
    await _openWeaponEditor(
      catalog: catalog,
      hero: hero,
      heroState: heroState,
      meleeTalents: meleeTalents,
    );
  }

  Future<void> _removeWeaponSlotAt(
    int slotIndex, {
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
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
      meleeTalents: meleeTalents,
    );
  }

  Future<void> _updateWeaponSlot(
    int slotIndex,
    MainWeaponSlot Function(MainWeaponSlot current) update, {
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
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
      meleeTalents: meleeTalents,
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
    required List<TalentDef> meleeTalents,
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
      meleeTalents: meleeTalents,
    );
  }

  Future<void> _openWeaponEditor({
    required RulesCatalog catalog,
    required HeroSheet hero,
    required HeroState heroState,
    required List<TalentDef> meleeTalents,
    int? slotIndex,
    MainWeaponSlot? initialSlot,
    String? catalogWeaponName,
  }) async {
    final slots = _draftCombatConfig.weaponSlots;
    final sourceSlot = initialSlot ??
        (slotIndex == null || slotIndex < 0 || slotIndex >= slots.length
            ? const MainWeaponSlot()
            : slots[slotIndex]);
    final result = await showDialog<MainWeaponSlot>(
      context: context,
      builder: (context) {
        return _WeaponEditorDialog(
          isNew: slotIndex == null,
          initialSlot: sourceSlot,
          meleeTalents: meleeTalents,
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
      meleeTalents: meleeTalents,
      slotIndex: slotIndex,
    );
  }

  Future<void> _setArmorPieces(
    List<ArmorPiece> pieces, {
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
  }) async {
    await _applyCombatConfigChange(
      nextConfig: _draftCombatConfig.copyWith(
        armor: _draftCombatConfig.armor.copyWith(
          pieces: List<ArmorPiece>.unmodifiable(pieces),
        ),
      ),
      catalog: catalog,
      meleeTalents: meleeTalents,
    );
  }

  Future<void> _removeArmorPiece(
    int index, {
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
  }) async {
    final pieces = List<ArmorPiece>.from(_draftCombatConfig.armor.pieces);
    if (index < 0 || index >= pieces.length) {
      return;
    }
    pieces.removeAt(index);
    await _setArmorPieces(pieces, catalog: catalog, meleeTalents: meleeTalents);
  }

  Future<void> _openArmorPieceEditor({
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
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
              title: Text(
                isNew ? 'Ruestung hinzufuegen' : 'Ruestung bearbeiten',
              ),
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
      meleeTalents: meleeTalents,
    );
  }

  Widget _buildWeaponsSubTab(
    List<TalentDef> combatTalents,
    RulesCatalog catalog,
    HeroSheet hero,
    HeroState heroState,
  ) {
    final weaponSlots = _draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = _selectedWeaponIndex();
    final sortedTalents = _sortedMeleeTalents(combatTalents);
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
                  headerCells: _weaponOverviewHeaderCells(
                    catalog: catalog,
                    hero: hero,
                    heroState: heroState,
                    meleeTalents: sortedTalents,
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
                      'Keine Waffen fuer den aktuellen Filter vorhanden.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeleeCalculatorSubTab(
    List<TalentDef> combatTalents,
    RulesCatalog catalog,
    CombatPreviewStats preview,
  ) {
    final isEditing = _editController.isEditing;
    final weaponSlots = _draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = _selectedWeaponIndex();
    final offhand = _draftCombatConfig.offhand;
    final armor = _draftCombatConfig.armor;
    final manual = _draftCombatConfig.manualMods;
    final sortedTalents = _sortedMeleeTalents(combatTalents);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final selectionCard = _buildActiveWeaponSelectionCard(
              catalog: catalog,
              meleeTalents: sortedTalents,
              selectedWeaponIndex: selectedWeaponIndex,
              weaponSlots: weaponSlots,
            );
            final infoCard = _buildActiveWeaponInfoCard(
              selectedWeaponIndex: selectedWeaponIndex,
              preview: preview,
              catalog: catalog,
            );
            if (constraints.maxWidth < 900) {
              return Column(
                children: [selectionCard, const SizedBox(height: 12), infoCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: selectionCard),
                const SizedBox(width: 12),
                Expanded(child: infoCard),
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
                  'Nebenhand',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(
                    'Nebenhand-Boni greifen nur bei aktivem Nebenhand-Modus (nicht "Keine").',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<OffhandMode>(
                  key: const ValueKey<String>('combat-offhand-mode'),
                  initialValue: offhand.mode,
                  decoration: const InputDecoration(
                    labelText: 'Modus',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: OffhandMode.none,
                      child: Text('Keine'),
                    ),
                    DropdownMenuItem(
                      value: OffhandMode.shield,
                      child: Text('Schild'),
                    ),
                    DropdownMenuItem(
                      value: OffhandMode.parryWeapon,
                      child: Text('Parierwaffe'),
                    ),
                    DropdownMenuItem(
                      value: OffhandMode.linkhand,
                      child: Text('Linkhand'),
                    ),
                  ],
                  onChanged: (value) {
                    _applyCombatConfigChange(
                      nextConfig: _draftCombatConfig.copyWith(
                        offhand: _draftCombatConfig.offhand.copyWith(
                          mode: value ?? OffhandMode.none,
                        ),
                      ),
                      catalog: catalog,
                      meleeTalents: sortedTalents,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _textInput(
                  label: 'Name',
                  keyName: 'combat-offhand-name',
                  isEditing: true,
                  onChanged: (value) {
                    _applyCombatConfigChange(
                      nextConfig: _draftCombatConfig.copyWith(
                        offhand: _draftCombatConfig.offhand.copyWith(
                          name: value,
                        ),
                      ),
                      catalog: catalog,
                      meleeTalents: sortedTalents,
                    );
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _numberInput(
                      label: 'AT Mod',
                      keyName: 'combat-offhand-at-mod',
                      isEditing: true,
                      onChanged: (parsed) {
                        _applyCombatConfigChange(
                          nextConfig: _draftCombatConfig.copyWith(
                            offhand: _draftCombatConfig.offhand.copyWith(
                              atMod: parsed,
                            ),
                          ),
                          catalog: catalog,
                          meleeTalents: sortedTalents,
                        );
                      },
                    ),
                    _numberInput(
                      label: 'PA Mod',
                      keyName: 'combat-offhand-pa-mod',
                      isEditing: true,
                      onChanged: (parsed) {
                        _applyCombatConfigChange(
                          nextConfig: _draftCombatConfig.copyWith(
                            offhand: _draftCombatConfig.offhand.copyWith(
                              paMod: parsed,
                            ),
                          ),
                          catalog: catalog,
                          meleeTalents: sortedTalents,
                        );
                      },
                    ),
                    _numberInput(
                      label: 'INI Mod',
                      keyName: 'combat-offhand-ini-mod',
                      isEditing: true,
                      onChanged: (parsed) {
                        _applyCombatConfigChange(
                          nextConfig: _draftCombatConfig.copyWith(
                            offhand: _draftCombatConfig.offhand.copyWith(
                              iniMod: parsed,
                            ),
                          ),
                          catalog: catalog,
                          meleeTalents: sortedTalents,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            if (constraints.maxWidth < 900) {
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
                    _resultChip('FK-Basis', preview.fkBase),
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
    required List<TalentDef> meleeTalents,
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
                  meleeTalents: meleeTalents,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArmorConfigurationCard({
    required ArmorConfig armor,
    required CombatPreviewStats preview,
    required RulesCatalog catalog,
    required List<TalentDef> sortedTalents,
  }) {
    final showPieceRg1 = armor.globalArmorTrainingLevel == 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ruestung & BE',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  key: const ValueKey<String>('combat-armor-add'),
                  onPressed: () => _openArmorPieceEditor(
                    catalog: catalog,
                    meleeTalents: sortedTalents,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Ruestung hinzufuegen'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (armor.pieces.isEmpty)
              const Text('Keine Ruestungsstuecke erfasst.')
            else
              Column(
                children: [
                  for (var i = 0; i < armor.pieces.length; i++)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text(armor.pieces[i].name)),
                                  Chip(label: Text('RS ${armor.pieces[i].rs}')),
                                  Chip(label: Text('BE ${armor.pieces[i].be}')),
                                  Chip(
                                    label: Text(
                                      'Aktiv ${armor.pieces[i].isActive ? 'Ja' : 'Nein'}',
                                    ),
                                  ),
                                  if (showPieceRg1)
                                    Chip(
                                      label: Text(
                                        'RG I ${armor.pieces[i].rg1Active ? 'Ja' : 'Nein'}',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  key: ValueKey<String>('combat-armor-edit-$i'),
                                  tooltip: 'Ruestung bearbeiten',
                                  onPressed: () => _openArmorPieceEditor(
                                    catalog: catalog,
                                    meleeTalents: sortedTalents,
                                    pieceIndex: i,
                                  ),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  key: ValueKey<String>(
                                    'combat-armor-remove-$i',
                                  ),
                                  tooltip: 'Ruestung entfernen',
                                  onPressed: () => _removeArmorPiece(
                                    i,
                                    catalog: catalog,
                                    meleeTalents: sortedTalents,
                                  ),
                                  icon: const Icon(Icons.delete),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text('RS gesamt = Summe aktiver RS = ${preview.rsTotal}'),
            Text(
              'BE (Kampf) = BE Roh (${preview.beTotalRaw}) - RG (${preview.rgReduction}) = ${preview.beKampf}',
            ),
            Text(
              'eBE = min(0, -BE(Kampf) (${preview.beKampf}) - BE Mod (${preview.beMod})) = ${preview.ebe}',
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
              'Aktive Waffe - Uebersicht',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (!hasActiveWeapon)
              const Text('Keine aktive Waffe ausgewaehlt.')
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    key: const ValueKey<String>('combat-active-weapon-info-at'),
                    label: Text('AT: ${preview.at}'),
                  ),
                  Chip(
                    key: const ValueKey<String>('combat-active-weapon-info-pa'),
                    label: Text('PA: ${preview.paMitIniParadeMod}'),
                  ),
                  Chip(
                    key: const ValueKey<String>('combat-active-weapon-info-tp'),
                    label: Text('TP: ${preview.tpExpression}'),
                  ),
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
              ),
              const SizedBox(height: 8),
              _activeWeaponIniRollEditor(preview),
              const SizedBox(height: 12),
              buildWeaponCalculationDetails(
                preview: preview,
                isEditing: _editController.isEditing,
              ),
              const SizedBox(height: 8),
              Text('Manoever', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              if (activeSupportedManeuvers.isEmpty)
                const Text(
                  'Keine erlernten, waffenkompatiblen Manoever.',
                  key: ValueKey<String>('combat-active-weapon-info-maneuvers'),
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
    required List<TalentDef> meleeTalents,
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
              meleeTalents: meleeTalents,
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
              meleeTalents: meleeTalents,
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
      key: const ValueKey<String>('combat-weapons-filter-talent'),
      initialValue: filteredTalentValue,
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
            child: Text(talent.name),
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
    cells[2] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-weapon-type'),
      initialValue: filteredTypeValue,
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
            child: Text(weaponType),
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
    cells[3] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-dk'),
      initialValue: filteredDkValue,
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
            child: Text(distanceClass),
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
    final availableDistanceClasses = weaponSlots
        .map((slot) => slot.distanceClass.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final activeTalentFilter =
        sortedTalents.any((talent) => talent.id == _weaponFilterTalentId)
        ? _weaponFilterTalentId
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
                meleeTalents: sortedTalents,
                slotIndex: entry.index,
              ),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('combat-weapon-cell-talent-${entry.index}'),
              initialValue: talentById.containsKey(slot.talentId.trim())
                  ? slot.talentId.trim()
                  : '',
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('-')),
                ...sortedTalents.map(
                  (talent) => DropdownMenuItem<String>(
                    value: talent.id,
                    child: Text(talent.name),
                  ),
                ),
              ],
              onChanged: (value) {
                final nextTalentId = value ?? '';
                final nextTalent = _findTalentById(sortedTalents, nextTalentId);
                final allowedWeaponTypes = _weaponTypeOptionsForTalent(
                  talent: nextTalent,
                  catalog: catalog,
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
                  meleeTalents: sortedTalents,
                );
              },
            ),
            Text(slot.weaponType.trim().isEmpty ? '-' : slot.weaponType.trim()),
            Text(
              slot.distanceClass.trim().isEmpty ? '-' : slot.distanceClass.trim(),
            ),
            Text(preview.at.toString()),
            Text(preview.pa.toString()),
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
                  meleeTalents: sortedTalents,
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
                      meleeTalents: sortedTalents,
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
