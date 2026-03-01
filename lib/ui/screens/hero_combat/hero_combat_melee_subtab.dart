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

  Future<void> _openWeaponEditor({
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
    int? slotIndex,
  }) async {
    final slots = _draftCombatConfig.weaponSlots;
    final isNew = slotIndex == null;
    final sourceWeapon = isNew ? const MainWeaponSlot() : slots[slotIndex];
    final nameController = TextEditingController(text: sourceWeapon.name);
    final dkController = TextEditingController(
      text: sourceWeapon.distanceClass,
    );
    final kkBaseController = TextEditingController(
      text: sourceWeapon.kkBase.toString(),
    );
    final kkThresholdController = TextEditingController(
      text: sourceWeapon.kkThreshold.toString(),
    );
    final iniModController = TextEditingController(
      text: sourceWeapon.iniMod.toString(),
    );
    final atModController = TextEditingController(
      text: sourceWeapon.wmAt.toString(),
    );
    final paModController = TextEditingController(
      text: sourceWeapon.wmPa.toString(),
    );
    final diceController = TextEditingController(
      text: sourceWeapon.tpDiceCount.toString(),
    );
    final tpValueController = TextEditingController(
      text: sourceWeapon.tpFlat.toString(),
    );
    final breakFactorController = TextEditingController(
      text: sourceWeapon.breakFactor.toString(),
    );
    var selectedTalentId = sourceWeapon.talentId.trim();
    if (_findTalentById(meleeTalents, selectedTalentId) == null) {
      selectedTalentId = '';
    }
    var selectedWeaponType = sourceWeapon.weaponType.trim();
    var isOneHanded = sourceWeapon.isOneHanded;
    String? validationMessage;

    final result = await showDialog<MainWeaponSlot>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedTalent = _findTalentById(
              meleeTalents,
              selectedTalentId,
            );
            final weaponTypeOptions = _weaponTypeOptionsForTalent(
              talent: selectedTalent,
              catalog: catalog,
            );
            if (selectedWeaponType.isNotEmpty &&
                !weaponTypeOptions.contains(selectedWeaponType)) {
              selectedWeaponType = '';
            }

            return AlertDialog(
              title: Text(isNew ? 'Waffe hinzufuegen' : 'Waffe bearbeiten'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey<String>('combat-weapon-form-name'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: const ValueKey<String>(
                          'combat-weapon-form-talent',
                        ),
                        initialValue: selectedTalentId.isEmpty
                            ? ''
                            : selectedTalentId,
                        decoration: const InputDecoration(
                          labelText: 'Talent',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('- Talent waehlen -'),
                          ),
                          ...meleeTalents.map(
                            (talent) => DropdownMenuItem<String>(
                              value: talent.id,
                              child: Text(talent.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedTalentId = value ?? '';
                            final nextTalent = _findTalentById(
                              meleeTalents,
                              selectedTalentId,
                            );
                            final nextWeaponOptions =
                                _weaponTypeOptionsForTalent(
                                  talent: nextTalent,
                                  catalog: catalog,
                                );
                            if (!nextWeaponOptions.contains(
                              selectedWeaponType,
                            )) {
                              selectedWeaponType = '';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: const ValueKey<String>(
                          'combat-weapon-form-weapon-type',
                        ),
                        initialValue: selectedWeaponType.isEmpty
                            ? ''
                            : selectedWeaponType,
                        decoration: const InputDecoration(
                          labelText: 'Waffenart',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('- Waffenart waehlen -'),
                          ),
                          ...weaponTypeOptions.map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry,
                              child: Text(entry),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            final previous = selectedWeaponType;
                            selectedWeaponType = value ?? '';
                            final currentName = nameController.text.trim();
                            final shouldAutofill =
                                currentName.isEmpty ||
                                _normalizeToken(currentName) ==
                                    _normalizeToken(previous);
                            if (selectedWeaponType.isNotEmpty &&
                                shouldAutofill) {
                              nameController.text = selectedWeaponType;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey<String>('combat-weapon-form-dk'),
                        controller: dkController,
                        decoration: const InputDecoration(
                          labelText: 'DK (Distanzklasse)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _dialogNumberField(
                            controller: kkBaseController,
                            keyName: 'combat-weapon-form-kk-base',
                            label: 'KK Basis',
                          ),
                          _dialogNumberField(
                            controller: kkThresholdController,
                            keyName: 'combat-weapon-form-kk-threshold',
                            label: 'KK-Schwelle',
                          ),
                          _dialogNumberField(
                            controller: iniModController,
                            keyName: 'combat-weapon-form-ini-mod',
                            label: 'INI Mod',
                          ),
                          _dialogNumberField(
                            controller: atModController,
                            keyName: 'combat-weapon-form-at-mod',
                            label: 'AT Mod',
                          ),
                          _dialogNumberField(
                            controller: paModController,
                            keyName: 'combat-weapon-form-pa-mod',
                            label: 'PA Mod',
                          ),
                          _dialogNumberField(
                            controller: diceController,
                            keyName: 'combat-weapon-form-dice',
                            label: 'Wuerfel',
                          ),
                          _dialogNumberField(
                            controller: tpValueController,
                            keyName: 'combat-weapon-form-tp-value',
                            label: 'TP-Wert',
                          ),
                          _dialogNumberField(
                            controller: breakFactorController,
                            keyName: 'combat-weapon-form-bf',
                            label: 'BF',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Einhaendig gefuehrt'),
                        value: isOneHanded,
                        onChanged: (value) {
                          setDialogState(() {
                            isOneHanded = value;
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
                  key: const ValueKey<String>('combat-weapon-form-save'),
                  onPressed: () {
                    int parseInt(String raw, int fallback) {
                      return int.tryParse(raw.trim()) ?? fallback;
                    }

                    final name = nameController.text.trim();
                    final distanceClass = dkController.text.trim();
                    final kkBase = parseInt(kkBaseController.text, 0);
                    final kkThreshold = parseInt(kkThresholdController.text, 1);
                    final iniMod = parseInt(iniModController.text, 0);
                    final atMod = parseInt(atModController.text, 0);
                    final paMod = parseInt(paModController.text, 0);
                    final diceCount = parseInt(diceController.text, 1);
                    final tpValue = parseInt(tpValueController.text, 0);
                    final breakFactor = parseInt(breakFactorController.text, 0);

                    if (name.isEmpty) {
                      setDialogState(() {
                        validationMessage = 'Name ist ein Pflichtfeld.';
                      });
                      return;
                    }
                    if (selectedTalentId.isEmpty) {
                      setDialogState(() {
                        validationMessage = 'Talent ist ein Pflichtfeld.';
                      });
                      return;
                    }
                    if (selectedWeaponType.isEmpty) {
                      setDialogState(() {
                        validationMessage = 'Waffenart ist ein Pflichtfeld.';
                      });
                      return;
                    }
                    if (kkThreshold < 1) {
                      setDialogState(() {
                        validationMessage = 'KK-Schwelle muss > 0 sein.';
                      });
                      return;
                    }
                    if (diceCount < 1) {
                      setDialogState(() {
                        validationMessage = 'Wuerfelanzahl muss >= 1 sein.';
                      });
                      return;
                    }
                    if (breakFactor < 0) {
                      setDialogState(() {
                        validationMessage = 'BF darf nicht negativ sein.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      sourceWeapon.copyWith(
                        name: name,
                        talentId: selectedTalentId,
                        weaponType: selectedWeaponType,
                        distanceClass: distanceClass,
                        kkBase: kkBase,
                        kkThreshold: kkThreshold,
                        breakFactor: breakFactor,
                        iniMod: iniMod,
                        wmAt: atMod,
                        wmPa: paMod,
                        tpDiceCount: diceCount,
                        tpDiceSides: 6,
                        tpFlat: tpValue,
                        isOneHanded: isOneHanded,
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
    final updatedSlots = List<MainWeaponSlot>.from(
      _draftCombatConfig.weaponSlots,
    );
    if (isNew) {
      updatedSlots.add(result);
      _setDraftWeapons(
        updatedSlots,
        selectedIndex: updatedSlots.length - 1,
        markChanged: true,
      );
    } else {
      final existingIndex = slotIndex;
      updatedSlots[existingIndex] = result;
      _setDraftWeapons(
        updatedSlots,
        selectedIndex: existingIndex,
        markChanged: true,
      );
    }
  }

  void _setArmorPieces(List<ArmorPiece> pieces) {
    _draftCombatConfig = _draftCombatConfig.copyWith(
      armor: _draftCombatConfig.armor.copyWith(
        pieces: List<ArmorPiece>.unmodifiable(pieces),
      ),
    );
    _markFieldChanged();
  }

  void _removeArmorPiece(int index) {
    final pieces = List<ArmorPiece>.from(_draftCombatConfig.armor.pieces);
    if (index < 0 || index >= pieces.length) {
      return;
    }
    pieces.removeAt(index);
    _setArmorPieces(pieces);
  }

  Future<void> _openArmorPieceEditor({int? pieceIndex}) async {
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
                    final parsedRs = int.tryParse(rsController.text.trim()) ?? 0;
                    final parsedBe = int.tryParse(beController.text.trim()) ?? 0;
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
    final updatedPieces = List<ArmorPiece>.from(_draftCombatConfig.armor.pieces);
    if (isNew) {
      updatedPieces.add(result);
    } else {
      updatedPieces[pieceIndex] = result;
    }
    _setArmorPieces(updatedPieces);
  }

  Widget _buildMeleeCalculatorSubTab(
    List<TalentDef> combatTalents,
    RulesCatalog catalog,
    CombatPreviewStats preview,
  ) {
    final isEditing = _editController.isEditing;
    final weaponSlots = _draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = _selectedWeaponIndex();
    final mainWeapon = weaponSlots[selectedWeaponIndex];
    final offhand = _draftCombatConfig.offhand;
    final armor = _draftCombatConfig.armor;
    final manual = _draftCombatConfig.manualMods;
    final sortedTalents = _sortedMeleeTalents(combatTalents);
    final selectedTalent = _findTalentById(sortedTalents, mainWeapon.talentId);

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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'combat-main-weapon-select-$selectedWeaponIndex-${weaponSlots.length}',
                        ),
                        initialValue: selectedWeaponIndex,
                        decoration: const InputDecoration(
                          labelText: 'Aktive Waffe',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var i = 0; i < weaponSlots.length; i++)
                            DropdownMenuItem<int>(
                              value: i,
                              child: Text(
                                weaponSlots[i].name.trim().isEmpty
                                    ? 'Waffe ${i + 1}'
                                    : weaponSlots[i].name,
                              ),
                            ),
                        ],
                        onChanged: !isEditing
                            ? null
                            : (value) {
                                _selectWeaponIndex(value ?? 0);
                              },
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('combat-weapon-add'),
                      tooltip: 'Waffe hinzufuegen',
                      onPressed: !isEditing
                          ? null
                          : () => _openWeaponEditor(
                              catalog: catalog,
                              meleeTalents: sortedTalents,
                            ),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      key: const ValueKey<String>('combat-weapon-edit'),
                      tooltip: 'Aktive Waffe bearbeiten',
                      onPressed: !isEditing
                          ? null
                          : () => _openWeaponEditor(
                              catalog: catalog,
                              meleeTalents: sortedTalents,
                              slotIndex: selectedWeaponIndex,
                            ),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      key: const ValueKey<String>('combat-weapon-remove'),
                      tooltip: 'Aktive Waffe entfernen',
                      onPressed: !isEditing || weaponSlots.length <= 1
                          ? null
                          : _removeSelectedWeaponSlot,
                      icon: const Icon(Icons.remove),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Waffenwerte fuer Slot ${selectedWeaponIndex + 1}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Name: ${_fallback(mainWeapon.name)}')),
                    Chip(
                      label: Text(
                        'Talent: ${selectedTalent == null ? '-' : selectedTalent.name}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Waffenart: ${_fallback(mainWeapon.weaponType)}',
                      ),
                    ),
                    Chip(
                      label: Text('DK: ${_fallback(mainWeapon.distanceClass)}'),
                    ),
                    Chip(label: Text('KK Basis: ${mainWeapon.kkBase}')),
                    Chip(label: Text('KK-Schwelle: ${mainWeapon.kkThreshold}')),
                    Chip(label: Text('INI Mod: ${mainWeapon.iniMod}')),
                    Chip(label: Text('AT Mod: ${mainWeapon.wmAt}')),
                    Chip(label: Text('PA Mod: ${mainWeapon.wmPa}')),
                    Chip(label: Text('Wuerfel: ${mainWeapon.tpDiceCount}')),
                    Chip(label: Text('TP-Wert: ${mainWeapon.tpFlat}')),
                    Chip(label: Text('BF: ${mainWeapon.breakFactor}')),
                    Chip(
                      label: Text(
                        mainWeapon.isOneHanded ? 'Einhaendig' : 'Zweihand',
                      ),
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
                  'Nebenhand',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!mainWeapon.isOneHanded)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      'Nebenhand-Boni werden nur bei einhaendig gefuehrter Hauptwaffe angewendet.',
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
                  onChanged: !isEditing
                      ? null
                      : (value) {
                          _draftCombatConfig = _draftCombatConfig.copyWith(
                            offhand: offhand.copyWith(
                              mode: value ?? OffhandMode.none,
                            ),
                          );
                          _markFieldChanged();
                        },
                ),
                const SizedBox(height: 10),
                _textInput(
                  label: 'Name',
                  keyName: 'combat-offhand-name',
                  isEditing: isEditing,
                  onChanged: (value) {
                    _draftCombatConfig = _draftCombatConfig.copyWith(
                      offhand: offhand.copyWith(name: value),
                    );
                    _markFieldChanged();
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
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          offhand: offhand.copyWith(atMod: parsed),
                        );
                        _markFieldChanged();
                      },
                    ),
                    _numberInput(
                      label: 'PA Mod',
                      keyName: 'combat-offhand-pa-mod',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          offhand: offhand.copyWith(paMod: parsed),
                        );
                        _markFieldChanged();
                      },
                    ),
                    _numberInput(
                      label: 'INI Mod',
                      keyName: 'combat-offhand-ini-mod',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          offhand: offhand.copyWith(iniMod: parsed),
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
                        onChanged: !isEditing
                            ? null
                            : (value) {
                                _draftCombatConfig = _draftCombatConfig.copyWith(
                                  armor: armor.copyWith(
                                    globalArmorTrainingLevel: value ?? 0,
                                  ),
                                );
                                _markFieldChanged();
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
                      onPressed: !isEditing ? null : () => _openArmorPieceEditor(),
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
                                  onPressed: !isEditing
                                      ? null
                                      : () => _openArmorPieceEditor(
                                            pieceIndex: i,
                                          ),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  key: ValueKey<String>(
                                    'combat-armor-remove-$i',
                                  ),
                                  tooltip: 'Ruestung entfernen',
                                  onPressed: !isEditing
                                      ? null
                                      : () => _removeArmorPiece(i),
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
}
