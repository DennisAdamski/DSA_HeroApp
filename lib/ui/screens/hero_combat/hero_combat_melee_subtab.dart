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

  Future<void> _addWeaponSlot({
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
  }) async {
    final slots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    slots.add(const MainWeaponSlot());
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Waffe', style: Theme.of(context).textTheme.titleMedium),
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
                      meleeTalents: sortedTalents,
                    );
                  },
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
        Card(
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
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey<String>(
                          'combat-armor-global-training-level',
                        ),
                        initialValue: armor.globalArmorTrainingLevel,
                        decoration: const InputDecoration(
                          labelText: 'Globale Ruestungsgewoehnung',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('0')),
                          DropdownMenuItem(value: 2, child: Text('II')),
                          DropdownMenuItem(value: 3, child: Text('III')),
                        ],
                        onChanged: (value) {
                          _applyCombatConfigChange(
                            nextConfig: _draftCombatConfig.copyWith(
                              armor: _draftCombatConfig.armor.copyWith(
                                globalArmorTrainingLevel: value ?? 0,
                              ),
                            ),
                            catalog: catalog,
                            meleeTalents: sortedTalents,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                          child: ListTile(
                            title: Text(armor.pieces[i].name),
                            subtitle: Text(
                              'RS ${armor.pieces[i].rs} | BE ${armor.pieces[i].be} | '
                              'Aktiv ${armor.pieces[i].isActive ? 'Ja' : 'Nein'} | '
                              'RG I ${armor.pieces[i].rg1Active ? 'Ja' : 'Nein'}',
                            ),
                            trailing: Wrap(
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
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                const Text(
                  'RG I ist global effektiv auf -1 BE begrenzt. '
                  'RG II/III ersetzen RG I und werden nicht kombiniert.',
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
                    _resultChip('RS', preview.rsTotal),
                    _resultChip('BE Roh', preview.beTotalRaw),
                    _resultChip('RG Reduktion', preview.rgReduction),
                    _resultChip('BE (Kampf)', preview.beKampf),
                    _resultChip('BE Mod', preview.beMod),
                    _resultChip('TP/KK', preview.tpKk),
                    _resultChip('GE-Basis', preview.geBase),
                    _resultChip('GE-Schwelle', preview.geThreshold),
                    _resultChip('INI/GE', preview.iniGe),
                    _resultChip('Ini Parade Mod', preview.iniParadeMod),
                    _resultChip('TK-Kalk', preview.tpCalc),
                    Chip(
                      label: Text(
                        'Spezialisierung: ${preview.specApplies ? 'Ja' : 'Nein'}',
                      ),
                    ),
                    _resultChip('INI', preview.initiative),
                    _resultChip('Ausweichen', preview.ausweichen),
                    _resultChip('AT', preview.at),
                    _resultChip('PA', preview.pa),
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
    'KK-Basis',
    'KK-Schwelle',
    'INI Mod',
    'WM AT',
    'WM PA',
    'Wuerfel',
    'TP Wert',
    'BE Mod',
    'eBE',
    'TP/KK',
    'GE Basis',
    'GE-Schwelle',
    'INI/GE',
    'INI PA Mod',
    'TP Kalk',
    'Spezialisierung',
    'Aktion',
  ];

  List<Widget> _weaponOverviewHeaderCells({
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
  }) {
    final cells = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Name'),
          IconButton(
            key: const ValueKey<String>('combat-weapon-add'),
            tooltip: 'Waffe hinzufuegen',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: () =>
                _addWeaponSlot(catalog: catalog, meleeTalents: meleeTalents),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
      for (final header in _weaponOverviewHeaders.skip(1)) Text(header),
    ];
    return cells;
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
          final selectedTalent = _findTalentById(sortedTalents, slot.talentId);
          final preview = computeCombatPreviewStats(
            hero,
            heroState,
            overrideConfig: _draftCombatConfig.copyWith(
              selectedWeaponIndex: entry.index,
              mainWeapon: slot,
            ),
            overrideTalents: _draftTalents,
            catalogTalents: catalog.talents,
          );
          final weaponTypeOptions = _weaponTypeOptionsForTalent(
            talent: selectedTalent,
            catalog: catalog,
          ).toList(growable: true);
          final currentWeaponType = slot.weaponType.trim();
          if (currentWeaponType.isNotEmpty &&
              !weaponTypeOptions.contains(currentWeaponType)) {
            weaponTypeOptions.add(currentWeaponType);
            weaponTypeOptions.sort(
              (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
            );
          }

          final cells = <Widget>[
            FlexibleTableCommitField(
              key: ValueKey<String>('combat-weapon-cell-name-${entry.index}'),
              value: slot.name,
              onCommit: (raw) {
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(name: raw.trim()),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
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
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'combat-weapon-cell-weapon-type-${entry.index}',
              ),
              initialValue: weaponTypeOptions.contains(currentWeaponType)
                  ? currentWeaponType
                  : '',
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('-')),
                ...weaponTypeOptions.map(
                  (weaponType) => DropdownMenuItem<String>(
                    value: weaponType,
                    child: Text(weaponType),
                  ),
                ),
              ],
              onChanged: (value) {
                final nextWeaponType = value ?? '';
                final nextName =
                    slot.name.trim().isEmpty && nextWeaponType.isNotEmpty
                    ? nextWeaponType
                    : slot.name;
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(
                    weaponType: nextWeaponType,
                    name: nextName,
                  ),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>('combat-weapon-cell-dk-${entry.index}'),
              value: slot.distanceClass,
              onCommit: (raw) {
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(distanceClass: raw.trim()),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            Text(preview.at.toString()),
            Text(preview.pa.toString()),
            Text(preview.tpExpression),
            Text(preview.initiative.toString()),
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
            FlexibleTableCommitField(
              key: ValueKey<String>(
                'combat-weapon-cell-kk-base-${entry.index}',
              ),
              value: slot.kkBase.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.kkBase;
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(kkBase: parsed),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>(
                'combat-weapon-cell-kk-threshold-${entry.index}',
              ),
              value: slot.kkThreshold.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.kkThreshold;
                _updateWeaponSlot(
                  entry.index,
                  (current) =>
                      current.copyWith(kkThreshold: parsed < 1 ? 1 : parsed),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>(
                'combat-weapon-cell-ini-mod-${entry.index}',
              ),
              value: slot.iniMod.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.iniMod;
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(iniMod: parsed),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>('combat-weapon-cell-wm-at-${entry.index}'),
              value: slot.wmAt.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.wmAt;
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(wmAt: parsed),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>('combat-weapon-cell-wm-pa-${entry.index}'),
              value: slot.wmPa.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.wmPa;
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(wmPa: parsed),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>('combat-weapon-cell-dice-${entry.index}'),
              value: slot.tpDiceCount.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.tpDiceCount;
                _updateWeaponSlot(
                  entry.index,
                  (current) =>
                      current.copyWith(tpDiceCount: parsed < 1 ? 1 : parsed),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            FlexibleTableCommitField(
              key: ValueKey<String>(
                'combat-weapon-cell-tp-value-${entry.index}',
              ),
              value: slot.tpFlat.toString(),
              keyboardType: TextInputType.number,
              onCommit: (raw) {
                final parsed = int.tryParse(raw.trim()) ?? slot.tpFlat;
                _updateWeaponSlot(
                  entry.index,
                  (current) => current.copyWith(tpFlat: parsed),
                  catalog: catalog,
                  meleeTalents: sortedTalents,
                );
              },
            ),
            Text(preview.beMod.toString()),
            Text(preview.ebe.toString()),
            Text(preview.tpKk.toString()),
            Text(preview.geBase.toString()),
            Text(preview.geThreshold.toString()),
            Text(preview.iniGe.toString()),
            Text(preview.iniParadeMod.toString()),
            Text(preview.tpCalc.toString()),
            Text(preview.specApplies ? 'Ja' : 'Nein'),
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
