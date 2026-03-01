import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/validation/combat_talent_validation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

enum _ManeuverSupportStatus { supported, notSupported, unverifiable }

class HeroCombatTab extends ConsumerStatefulWidget {
  const HeroCombatTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final void Function(bool isDirty) onDirtyChanged;
  final void Function(bool isEditing) onEditingChanged;
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<HeroCombatTab> createState() => _HeroCombatTabState();
}

class _HeroCombatTabState extends ConsumerState<HeroCombatTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final WorkspaceTabEditController _editController;
  late final TabController _subTabController;

  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  HeroSheet? _latestHero;
  Map<String, HeroTalentEntry> _draftTalents = <String, HeroTalentEntry>{};
  Set<String> _draftHiddenTalentIds = <String>{};
  Set<String> _invalidCombatTalentIds = <String>{};
  CombatConfig _draftCombatConfig = const CombatConfig();

  @override
  void initState() {
    super.initState();
    _editController = WorkspaceTabEditController(
      onDirtyChanged: widget.onDirtyChanged,
      onEditingChanged: widget.onEditingChanged,
      requestRebuild: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    _subTabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _subTabController.dispose();
    super.dispose();
  }

  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveChanges,
        cancel: _cancelChanges,
      ),
    );
  }

  void _syncDraftFromHero(HeroSheet hero, {bool force = false}) {
    if (!_editController.shouldSync(hero, force: force)) {
      return;
    }

    _resetControllers();
    _draftTalents = Map<String, HeroTalentEntry>.from(hero.talents);
    _draftHiddenTalentIds = normalizeHiddenTalentIds(hero.hiddenTalentIds);
    _invalidCombatTalentIds = <String>{};
    _draftCombatConfig = hero.combatConfig;
    _seedCombatControllers();
  }

  void _resetControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  void _seedCombatControllers() {
    final main = _draftCombatConfig.selectedWeapon;
    final offhand = _draftCombatConfig.offhand;
    final armor = _draftCombatConfig.armor;
    final manual = _draftCombatConfig.manualMods;

    _controllerFor('combat-main-name', main.name);
    _controllerFor('combat-main-talent', main.talentId);
    _controllerFor('combat-main-dice-count', main.tpDiceCount.toString());
    _controllerFor('combat-main-dice-sides', main.tpDiceSides.toString());
    _controllerFor('combat-main-tp-flat', main.tpFlat.toString());
    _controllerFor('combat-main-wm-at', main.wmAt.toString());
    _controllerFor('combat-main-wm-pa', main.wmPa.toString());
    _controllerFor('combat-main-ini-mod', main.iniMod.toString());
    _controllerFor('combat-main-be-mod', main.beTalentMod.toString());

    _controllerFor('combat-offhand-name', offhand.name);
    _controllerFor('combat-offhand-at-mod', offhand.atMod.toString());
    _controllerFor('combat-offhand-pa-mod', offhand.paMod.toString());
    _controllerFor('combat-offhand-ini-mod', offhand.iniMod.toString());

    _controllerFor('combat-armor-rs', armor.rsTotal.toString());
    _controllerFor('combat-armor-be-raw', armor.beTotalRaw.toString());
    _controllerFor(
      'combat-armor-training-level',
      armor.armorTrainingLevel.toString(),
    );

    _controllerFor('combat-manual-ini-mod', manual.iniMod.toString());
    _controllerFor('combat-manual-ausw-mod', manual.ausweichenMod.toString());
    _controllerFor('combat-manual-at-mod', manual.atMod.toString());
    _controllerFor('combat-manual-pa-mod', manual.paMod.toString());
  }

  int _selectedWeaponIndex() {
    final slots = _draftCombatConfig.weaponSlots;
    if (slots.length <= 1) {
      return 0;
    }
    final index = _draftCombatConfig.selectedWeaponIndex;
    if (index < 0) {
      return 0;
    }
    if (index >= slots.length) {
      return slots.length - 1;
    }
    return index;
  }

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
        ? 0
        : (selectedIndex >= slots.length ? slots.length - 1 : selectedIndex);
    _draftCombatConfig = _draftCombatConfig.copyWith(
      weapons: slots,
      selectedWeaponIndex: normalizedIndex,
      mainWeapon: slots[normalizedIndex],
    );
    _syncSelectedWeaponControllers(slots[normalizedIndex]);
    if (markChanged) {
      _markFieldChanged();
    }
  }

  void _selectWeaponIndex(int nextIndex) {
    final slots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    _setDraftWeapons(slots, selectedIndex: nextIndex, markChanged: true);
  }

  void _removeSelectedWeaponSlot() {
    final slots = List<MainWeaponSlot>.from(_draftCombatConfig.weaponSlots);
    if (slots.length <= 1) {
      return;
    }
    final index = _selectedWeaponIndex();
    slots.removeAt(index);
    final nextIndex = index >= slots.length ? slots.length - 1 : index;
    _setDraftWeapons(slots, selectedIndex: nextIndex, markChanged: true);
  }

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
    final meleeTalents = _sortedMeleeTalents(
      catalog.talents.where(isCombatTalentDef).toList(growable: false),
    );
    final weaponValidation = _validateWeaponSlots(
      catalog: catalog,
      meleeTalents: meleeTalents,
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
        setState(() {
          _invalidCombatTalentIds = issues
              .map((entry) => entry.talentId)
              .toSet();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(issues.first.message)));
      }
      return;
    }

    final updatedHero = hero.copyWith(
      talents: Map<String, HeroTalentEntry>.from(_draftTalents),
      hiddenTalentIds: _draftHiddenTalentIds.toList(growable: false),
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

  void _toggleHidden(String talentId) {
    if (_draftHiddenTalentIds.contains(talentId)) {
      _draftHiddenTalentIds.remove(talentId);
    } else {
      _draftHiddenTalentIds.add(talentId);
    }
    _markFieldChanged();
  }

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _editController.markFieldChanged();
  }

  bool _isHidden(String talentId) => _draftHiddenTalentIds.contains(talentId);

  String? _validateWeaponSlots({
    required RulesCatalog catalog,
    required List<TalentDef> meleeTalents,
  }) {
    final talentById = <String, TalentDef>{
      for (final talent in meleeTalents) talent.id: talent,
    };
    final slots = _draftCombatConfig.weaponSlots;
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
      if (slot.name.trim().isEmpty) {
        return '$slotLabel: Name ist ein Pflichtfeld.';
      }
      final talentId = slot.talentId.trim();
      if (talentId.isEmpty) {
        return '$slotLabel: Talent ist ein Pflichtfeld.';
      }
      final talent = talentById[talentId];
      if (talent == null) {
        return '$slotLabel: Das gewaehlte Talent ist nicht gueltig fuer Nahkampf.';
      }
      final weaponType = slot.weaponType.trim();
      if (weaponType.isEmpty) {
        return '$slotLabel: Waffenart ist ein Pflichtfeld.';
      }
      final allowedTypes = _weaponTypeOptionsForTalent(
        talent: talent,
        catalog: catalog,
      );
      if (!allowedTypes.contains(weaponType)) {
        return '$slotLabel: Waffenart "$weaponType" passt nicht zum Talent "${talent.name}".';
      }
      if (slot.kkThreshold < 1) {
        return '$slotLabel: KK-Schwelle muss > 0 sein.';
      }
      if (slot.tpDiceCount < 1) {
        return '$slotLabel: Wuerfelanzahl muss >= 1 sein.';
      }
      if (slot.breakFactor < 0) {
        return '$slotLabel: BF darf nicht negativ sein.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }
    _latestHero = hero;
    _syncDraftFromHero(hero);

    final stateAsync = ref.watch(heroStateProvider(widget.heroId));
    final catalogAsync = ref.watch(rulesCatalogProvider);

    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      data: (state) => catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Katalog-Fehler: $error')),
        data: (catalog) {
          final combatTalents = catalog.talents
              .where(isCombatTalentDef)
              .toList(growable: false);
          final preview = computeCombatPreviewStats(
            hero,
            state,
            overrideConfig: _draftCombatConfig,
            overrideTalents: _draftTalents,
            catalogTalents: catalog.talents,
          );

          return Column(
            children: [
              TabBar(
                controller: _subTabController,
                tabs: const [
                  Tab(text: 'Kampftechniken'),
                  Tab(text: 'Nahkampf'),
                  Tab(text: 'SF/Manoever'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _subTabController,
                  children: [
                    _buildCombatTalentsSubTab(combatTalents),
                    _buildMeleeCalculatorSubTab(
                      combatTalents,
                      catalog,
                      preview,
                    ),
                    _buildSpecialRulesSubTab(catalog),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCombatTalentsSubTab(List<TalentDef> talents) {
    final grouped = <String, List<TalentDef>>{};
    for (final talent in talents) {
      final group = talent.type.trim().isEmpty
          ? 'Kampf (ohne Typ)'
          : talent.type;
      grouped.putIfAbsent(group, () => <TalentDef>[]).add(talent);
    }
    final groups = grouped.keys.toList(growable: false)..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final entries = List<TalentDef>.from(
          grouped[group]!,
        )..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final visibleEntries = _editController.isEditing
            ? entries
            : entries
                  .where((talent) => !_isHidden(talent.id))
                  .toList(growable: false);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            title: Text(group),
            subtitle: Text(
              '${visibleEntries.length}/${entries.length} sichtbar',
            ),
            children: [_buildCombatTalentsTable(visibleEntries)],
          ),
        );
      },
    );
  }

  Widget _buildCombatTalentsTable(List<TalentDef> talents) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(isEditing: isEditing),
      ...talents.map((talent) => _buildCombatTalentRow(talent, isEditing)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: isEditing ? 1300 : 1210),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FixedColumnWidth(220),
              1: const FixedColumnWidth(300),
              2: const FixedColumnWidth(220),
              3: const FixedColumnWidth(70),
              4: const FixedColumnWidth(60),
              5: const FixedColumnWidth(90),
              6: const FixedColumnWidth(90),
              7: const FixedColumnWidth(90),
              if (isEditing) 8: const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  TableRow _buildCombatHeaderRow({required bool isEditing}) {
    final cells = <Widget>[
      _headerCell('Talent-Name'),
      _headerCell('Waffengattung'),
      _headerCell('Ersatzweise'),
      _headerCell('Kompl.'),
      _headerCell('BE'),
      _headerCell('TaW'),
      _headerCell('AT'),
      _headerCell('PA'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildCombatTalentRow(TalentDef talent, bool isEditing) {
    final entry = _entryForTalent(talent.id);
    final isHidden = _isHidden(talent.id);
    final isInvalid = _invalidCombatTalentIds.contains(talent.id);
    final nameLabel = isEditing && isHidden
        ? '${talent.name} (ausgeblendet)'
        : talent.name;

    final cells = <Widget>[
      _textCell(nameLabel, key: ValueKey<String>('talents-row-${talent.id}')),
      _textCell(_fallback(talent.weaponCategory)),
      _textCell(_fallback(talent.alternatives)),
      _textCell(_fallback(talent.steigerung)),
      _textCell(_fallback(talent.be)),
      _intInputCell(
        talentId: talent.id,
        field: 'talentValue',
        value: entry.talentValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'atValue',
        value: entry.atValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'paValue',
        value: entry.paValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
    ];
    if (isEditing) {
      cells.add(_visibilityCell(talent.id, isHidden));
    }

    final rowColor = isInvalid
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
        : (isHidden && isEditing
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null);

    return TableRow(
      decoration: BoxDecoration(color: rowColor),
      children: cells,
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }

  Widget _textCell(String text, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Align(alignment: Alignment.centerLeft, child: Text(text)),
    );
  }

  Widget _intInputCell({
    required String talentId,
    required String field,
    required int value,
    required bool isEditing,
    bool isError = false,
  }) {
    final controller = _controllerFor(
      'talent::$talentId::$field',
      value.toString(),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: TextField(
        key: ValueKey<String>('talents-field-$talentId-$field'),
        controller: controller,
        readOnly: !isEditing,
        keyboardType: TextInputType.number,
        decoration: _cellInputDecoration(isError: isError),
        onChanged: isEditing
            ? (raw) => _updateIntField(talentId, field, raw)
            : null,
      ),
    );
  }

  Widget _visibilityCell(String talentId, bool isHidden) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: ValueKey<String>('talents-visibility-$talentId'),
        icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
        tooltip: isHidden ? 'Talent einblenden' : 'Talent ausblenden',
        onPressed: () => _toggleHidden(talentId),
      ),
    );
  }

  InputDecoration _cellInputDecoration({bool isError = false}) {
    final theme = Theme.of(context).colorScheme;
    final borderColor = isError ? theme.error : theme.outline;
    return InputDecoration(
      isDense: true,
      border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isError ? theme.error : theme.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _numberInput(
                      label: 'RS Gesamt',
                      keyName: 'combat-armor-rs',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          armor: armor.copyWith(
                            rsTotal: parsed < 0 ? 0 : parsed,
                          ),
                        );
                        _markFieldChanged();
                      },
                    ),
                    _numberInput(
                      label: 'BE Roh',
                      keyName: 'combat-armor-be-raw',
                      isEditing: isEditing,
                      onChanged: (parsed) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          armor: armor.copyWith(
                            beTotalRaw: parsed < 0 ? 0 : parsed,
                          ),
                        );
                        _markFieldChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: const ValueKey<String>('combat-armor-training-level'),
                  initialValue: armor.armorTrainingLevel,
                  decoration: const InputDecoration(
                    labelText: 'Ruestungsgewoehnung (0-4)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('0')),
                    DropdownMenuItem(value: 1, child: Text('I')),
                    DropdownMenuItem(value: 2, child: Text('II')),
                    DropdownMenuItem(value: 3, child: Text('III')),
                    DropdownMenuItem(value: 4, child: Text('IV')),
                  ],
                  onChanged: !isEditing
                      ? null
                      : (value) {
                          _draftCombatConfig = _draftCombatConfig.copyWith(
                            armor: armor.copyWith(
                              armorTrainingLevel: value ?? 0,
                            ),
                          );
                          _markFieldChanged();
                        },
                ),
                SwitchListTile(
                  title: const Text('RG I aktiv'),
                  value: armor.rgIActive,
                  onChanged: !isEditing
                      ? null
                      : (enabled) {
                          _draftCombatConfig = _draftCombatConfig.copyWith(
                            armor: armor.copyWith(rgIActive: enabled),
                          );
                          _markFieldChanged();
                        },
                ),
                const Text(
                  'Hinweis: RG IV nutzt aktuell den RG-III-Fallback. '
                  'TODO fuer die exakte Regelableitung ist gesetzt.',
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

  Widget _buildSpecialRulesSubTab(RulesCatalog catalog) {
    final rules = _draftCombatConfig.specialRules;
    final isEditing = _editController.isEditing;
    final allManeuvers = _collectCatalogManeuvers(catalog.weapons);
    final supportByManeuver = _buildManeuverSupportMap(catalog, allManeuvers);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ruleToggle(
          label: 'Kampfreflexe',
          value: rules.kampfreflexe,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(kampfreflexe: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Kampfgespuer',
          value: rules.kampfgespuer,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(kampfgespuer: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen I',
          value: rules.ausweichenI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen II',
          value: rules.ausweichenII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen III',
          value: rules.ausweichenIII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenIII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Schildkampf I',
          value: rules.schildkampfI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schildkampfI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Schildkampf II',
          value: rules.schildkampfII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schildkampfII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Parierwaffen I',
          value: rules.parierwaffenI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(parierwaffenI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Parierwaffen II',
          value: rules.parierwaffenII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(parierwaffenII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Linkhand aktiv',
          value: rules.linkhandActive,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(linkhandActive: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Flink',
          value: rules.flink,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(flink: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Behaebig',
          value: rules.behaebig,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(behaebig: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Axxeleratus aktiv',
          value: rules.axxeleratusActive,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(axxeleratusActive: value),
            );
            _markFieldChanged();
          },
        ),
        const SizedBox(height: 12),
        Text('Manoever', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (allManeuvers.isEmpty)
          const Card(
            child: ListTile(title: Text('Keine Manoever im Katalog gefunden.')),
          ),
        ...allManeuvers.map((maneuver) {
          final isActive = rules.activeManeuvers.contains(maneuver);
          final support =
              supportByManeuver[maneuver] ??
              _ManeuverSupportStatus.unverifiable;
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
                          'Von aktiver Waffe unterstuetzt',
                        _ManeuverSupportStatus.notSupported =>
                          'Nicht unterstuetzt',
                        _ManeuverSupportStatus.unverifiable =>
                          'Nicht verifizierbar',
                      }),
                    ),
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

  Widget _resultChip(String label, int value) {
    return Chip(label: Text('$label: $value'));
  }

  Widget _ruleToggle({
    required String label,
    required bool value,
    required bool isEditing,
    required void Function(bool value) onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: isEditing ? onChanged : null,
      ),
    );
  }

  Widget _numberInput({
    required String label,
    required String keyName,
    required bool isEditing,
    required void Function(int value) onChanged,
  }) {
    final controller = _controllerFor(keyName, '0');
    return SizedBox(
      width: 140,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        readOnly: !isEditing,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: !isEditing
            ? null
            : (raw) {
                final parsed = int.tryParse(raw.trim()) ?? 0;
                onChanged(parsed);
              },
      ),
    );
  }

  Widget _dialogNumberField({
    required TextEditingController controller,
    required String keyName,
    required String label,
  }) {
    return SizedBox(
      width: 130,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _textInput({
    required String label,
    required String keyName,
    required bool isEditing,
    required void Function(String value) onChanged,
  }) {
    final controller = _controllerFor(keyName, '');
    return TextField(
      key: ValueKey<String>(keyName),
      controller: controller,
      readOnly: !isEditing,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: !isEditing ? null : onChanged,
    );
  }

  String _fallback(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    return trimmed;
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

  String _normalizeToken(String raw) {
    var value = raw.trim().toLowerCase();
    value = value
        .replaceAll(String.fromCharCode(228), 'ae')
        .replaceAll(String.fromCharCode(246), 'oe')
        .replaceAll(String.fromCharCode(252), 'ue')
        .replaceAll(String.fromCharCode(223), 'ss');
    return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  @override
  bool get wantKeepAlive => true;
}
