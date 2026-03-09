import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/validation/combat_talent_validation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_area_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

part 'hero_combat/hero_combat_talents_subtab.dart';
part 'hero_combat/combat_talent_catalog_table.dart';
part 'hero_combat/weapon_catalog_table.dart';
part 'hero_combat/hero_combat_melee_subtab.dart';
part 'hero_combat/hero_combat_special_rules_subtab.dart';
part 'hero_combat/hero_combat_maneuvers_subtab.dart';
part 'hero_combat/hero_combat_form_fields.dart';
part 'hero_combat/weapon_detail_expansion.dart';
part 'hero_combat/weapon_editor_dialog.dart';

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
  Set<String> _invalidCombatTalentIds = <String>{};
  CombatConfig _draftCombatConfig = const CombatConfig();
  int? _temporaryIniRoll;
  String _weaponFilterTalentId = '';
  String _weaponFilterCombatType = '';
  String _weaponFilterType = '';
  String _weaponFilterDistanceClass = '';

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
    _subTabController = TabController(length: 5, vsync: this);

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
    _invalidCombatTalentIds = <String>{};
    _draftCombatConfig = hero.combatConfig;
    _temporaryIniRoll = null;
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
    final index = _draftCombatConfig.selectedWeaponIndex;
    if (index < 0 || index >= slots.length) {
      return -1;
    }
    return index;
  }

  MainWeaponSlot? _offhandWeaponOrNull() {
    final assignment = _draftCombatConfig.offhandAssignment;
    if (!assignment.usesWeapon) {
      return null;
    }
    final index = assignment.weaponIndex;
    final slots = _draftCombatConfig.weaponSlots;
    if (index < 0 || index >= slots.length) {
      return null;
    }
    return slots[index];
  }

  OffhandEquipmentEntry? _offhandEquipmentOrNull() {
    final assignment = _draftCombatConfig.offhandAssignment;
    if (!assignment.usesEquipment) {
      return null;
    }
    final index = assignment.equipmentIndex;
    final entries = _draftCombatConfig.offhandEquipment;
    if (index < 0 || index >= entries.length) {
      return null;
    }
    return entries[index];
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
    final combatTalents = _sortedCombatTalents(
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
      if (talent != null && _combatTypeFromTalent(talent) != slot.combatType) {
        return '$slotLabel: Talent "${talent.name}" passt nicht zum Waffenkampftyp.';
      }
      final weaponType = slot.weaponType.trim();
      if (weaponType.isNotEmpty && talent != null) {
        final allowedTypes = _weaponTypeOptionsForTalent(
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    assert(() {
      final techniquesMeta = workspaceAreaMetaById(
        WorkspaceAreaId.combatTechniquesList,
      );
      return techniquesMeta.kind == WorkspaceAreaKind.listView;
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
              final effectiveIniRoll = _effectiveIniRollForConfig(
                _draftCombatConfig,
              );
              final previewConfig = _draftCombatConfig.copyWith(
                manualMods: _draftCombatConfig.manualMods.copyWith(
                  iniWurf: effectiveIniRoll,
                ),
              );
              final preview = computeCombatPreviewStats(
                hero,
                state,
                overrideConfig: previewConfig,
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
                      Tab(text: 'Ausrüstung'),
                      Tab(text: 'Kampf'),
                      Tab(text: 'Sonderfertigkeiten'),
                      Tab(text: 'Manöver'),
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
                        _buildWeaponsSubTab(
                          combatTalents,
                          catalog,
                          hero,
                          state,
                          preview,
                        ),
                        _buildMeleeCalculatorSubTab(
                          combatTalents,
                          catalog,
                          hero,
                          state,
                          preview,
                        ),
                        _buildSpecialRulesSubTab(hero, state),
                        _buildManeuversSubTab(catalog),
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

  @override
  bool get wantKeepAlive => true;
}
