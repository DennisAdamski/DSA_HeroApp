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
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_armor_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_helpers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_offhand_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_weapons_section.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/combat_quick_stats.dart';

part 'hero_combat/hero_combat_talents_subtab.dart';
part 'hero_combat/combat_talent_catalog_table.dart';
part 'hero_combat/hero_combat_calculator_subtab.dart';
part 'hero_combat/hero_combat_form_fields.dart';
part 'hero_combat/weapon_detail_expansion.dart';
part 'hero_combat/combat_preview_subtab.dart';
part 'hero_combat/combat_rules_subtab.dart';
part 'hero_combat/combat_special_rules_helpers.dart';
part 'hero_combat/combat_maneuver_helpers.dart';
part 'hero_combat/combat_state_helpers.dart';

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

  void _setInvalidCombatTalentIds(Set<String> invalidIds) {
    setState(() {
      _invalidCombatTalentIds = invalidIds;
    });
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
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Kampfwerte'),
                      Tab(text: 'Waffen'),
                      Tab(text: 'Rüstung & Verteidigung'),
                      Tab(text: 'Kampftechniken'),
                      Tab(text: 'Kampfregeln'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _subTabController,
                      children: [
                        // Tab 0: Kampfwerte (Spieltisch-Schnellansicht)
                        _buildCombatPreviewSubTab(
                          combatTalents: combatTalents,
                          catalog: catalog,
                          hero: hero,
                          heroState: state,
                          preview: preview,
                        ),
                        // Tab 1: Waffen (Tabelle + responsiver Editor)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: CombatWeaponsSection(
                            weapons: _draftCombatConfig.weaponSlots,
                            selectedWeaponIndex:
                                _draftCombatConfig.selectedWeaponIndex,
                            combatTalents: combatTalents,
                            catalog: catalog,
                            catalogWeapons:
                                catalog.weapons
                                    .where((weapon) => weapon.active)
                                    .toList(growable: false)
                                  ..sort(
                                    (a, b) => a.name.toLowerCase().compareTo(
                                      b.name.toLowerCase(),
                                    ),
                                  ),
                            effectiveAttributes: effectiveAttributes,
                            hero: hero,
                            heroState: state,
                            draftCombatConfig: _draftCombatConfig,
                            draftTalents: _draftTalents,
                            weaponFilterTalentId: _weaponFilterTalentId,
                            weaponFilterCombatType: _weaponFilterCombatType,
                            weaponFilterType: _weaponFilterType,
                            weaponFilterDistanceClass:
                                _weaponFilterDistanceClass,
                            onWeaponSave: (slot, {slotIndex}) =>
                                _saveWeaponSlot(
                                  slot: slot,
                                  catalog: catalog,
                                  combatTalents: sortedCombatTalents(
                                    combatTalents,
                                  ),
                                  slotIndex: slotIndex,
                                ),
                            onWeaponRemove: (index) => _removeWeaponSlotAt(
                              index,
                              catalog: catalog,
                              combatTalents: sortedCombatTalents(combatTalents),
                            ),
                            onWeaponSlotUpdate: (index, update) =>
                                _updateWeaponSlot(
                                  index,
                                  update,
                                  catalog: catalog,
                                  combatTalents: sortedCombatTalents(
                                    combatTalents,
                                  ),
                                ),
                            onFilterChanged:
                                ({
                                  String? talentId,
                                  String? combatType,
                                  String? weaponType,
                                  String? distanceClass,
                                }) {
                                  if (talentId != null) {
                                    _weaponFilterTalentId = talentId;
                                  }
                                  if (combatType != null) {
                                    _weaponFilterCombatType = combatType;
                                  }
                                  if (weaponType != null) {
                                    _weaponFilterType = weaponType;
                                  }
                                  if (distanceClass != null) {
                                    _weaponFilterDistanceClass = distanceClass;
                                  }
                                  if (mounted) {
                                    _viewRevision.value++;
                                  }
                                },
                          ),
                        ),
                        // Tab 2: Ruestung & Verteidigung
                        ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            CombatArmorSection(
                              armor: _draftCombatConfig.armor,
                              onArmorChanged: (armor) => _setArmorConfig(
                                armor,
                                catalog: catalog,
                                combatTalents: sortedCombatTalents(
                                  combatTalents,
                                ),
                              ),
                              previewRsTotal: preview.rsTotal,
                              previewBeTotalRaw: preview.beTotalRaw,
                              previewRgReduction: preview.rgReduction,
                              previewBeKampf: preview.beKampf,
                              previewBeMod: preview.beMod,
                              previewEbe: preview.ebe,
                            ),
                            const SizedBox(height: 12),
                            CombatOffhandSection(
                              offhandEquipment:
                                  _draftCombatConfig.offhandEquipment,
                              onOffhandEquipmentChanged: (entries) =>
                                  _setOffhandEquipmentEntries(
                                    entries,
                                    catalog: catalog,
                                    combatTalents: sortedCombatTalents(
                                      combatTalents,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        // Tab 3: Kampftechniken
                        _buildCombatTalentsSubTab(
                          combatTalents,
                          effectiveAttributes: effectiveAttributes,
                        ),
                        // Tab 4: Kampfregeln (SF + Manoever)
                        _buildCombatRulesSubTab(
                          hero: hero,
                          heroState: state,
                          catalog: catalog,
                        ),
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

  @override
  bool get wantKeepAlive => true;
}
