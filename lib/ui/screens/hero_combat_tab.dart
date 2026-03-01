import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/validation/combat_talent_validation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_area_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

part 'hero_combat/hero_combat_talents_subtab.dart';
part 'hero_combat/hero_combat_melee_subtab.dart';
part 'hero_combat/hero_combat_special_rules_subtab.dart';
part 'hero_combat/hero_combat_form_fields.dart';

enum _ManeuverSupportStatus { supported, notSupported, unverifiable }

class HeroCombatTab extends ConsumerStatefulWidget {
  const HeroCombatTab({
    super.key,
    required this.heroId,
    this.showInlineCombatTalentsActions = true,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final bool showInlineCombatTalentsActions;
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
  final ValueNotifier<int> _viewRevision = ValueNotifier<int>(0);

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
    _viewRevision.dispose();
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
    _controllerFor(
      'combat-armor-global-training-level',
      armor.globalArmorTrainingLevel.toString(),
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

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _setCombatTalentsVisibilityMode(false);
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
    _setCombatTalentsVisibilityMode(false);
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
    _setCombatTalentsVisibilityMode(false);
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

  void _setHiddenForGroup(List<TalentDef> talents, {required bool hidden}) {
    for (final talent in talents) {
      if (hidden) {
        _draftHiddenTalentIds.add(talent.id);
      } else {
        _draftHiddenTalentIds.remove(talent.id);
      }
    }
    _markFieldChanged();
  }

  void _setCombatTalentsVisibilityMode(bool enabled) {
    final notifier = ref.read(
      combatTechniquesVisibilityModeProvider(widget.heroId).notifier,
    );
    if (notifier.state == enabled) {
      return;
    }
    notifier.state = enabled;
  }

  void _updateGifted(String talentId, bool value) {
    final current = _entryForTalent(talentId);
    _draftTalents[talentId] = current.copyWith(gifted: value);
    _markFieldChanged();
  }

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    _viewRevision.value++;
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
    assert(() {
      final techniquesMeta = workspaceAreaMetaById(
        WorkspaceAreaId.combatTechniquesList,
      );
      return techniquesMeta.kind == WorkspaceAreaKind.listView &&
          techniquesMeta.supportsVisibilityMode &&
          techniquesMeta.supportsGroupVisibility;
    }());
    UiRebuildObserver.bump('hero_combat_tab');
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
          return ValueListenableBuilder<int>(
            valueListenable: _viewRevision,
            builder: (context, revision, child) {
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
              final effectiveAttributes = computeEffectiveAttributes(
                hero,
                tempAttributeMods: state.tempAttributeMods,
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
                        _buildCombatTalentsSubTab(
                          combatTalents,
                          effectiveAttributes: effectiveAttributes,
                        ),
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
          );
        },
      ),
    );
  }

  String _fallback(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    return trimmed;
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
