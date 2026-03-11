import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_weapons_overview_table.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_catalog_table.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/helpers_catalog_slot.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor_screen.dart';

/// Callback-Typ fuer Inline-Aenderungen an einem Waffen-Slot.
typedef WeaponSlotUpdater =
    void Function(
      int index,
      MainWeaponSlot Function(MainWeaponSlot current) update,
    );

/// Callback-Typ fuer Filter-Aenderungen.
typedef WeaponFilterChanged =
    void Function({
      String? talentId,
      String? combatType,
      String? weaponType,
      String? distanceClass,
    });

/// Persistiert einen Waffen-Draft als neuen oder bestehenden Slot.
typedef WeaponSaveCallback =
    Future<void> Function(MainWeaponSlot slot, {int? slotIndex});

/// Verwaltet Waffenliste und responsiven Waffen-Editor.
class CombatWeaponsSection extends StatefulWidget {
  /// Erstellt die Waffen-Sektion fuer den Kampf-Tab.
  const CombatWeaponsSection({
    super.key,
    required this.weapons,
    required this.selectedWeaponIndex,
    required this.combatTalents,
    required this.catalog,
    required this.catalogWeapons,
    required this.effectiveAttributes,
    required this.hero,
    required this.heroState,
    required this.draftCombatConfig,
    required this.draftTalents,
    required this.weaponFilterTalentId,
    required this.weaponFilterCombatType,
    required this.weaponFilterType,
    required this.weaponFilterDistanceClass,
    required this.onWeaponSave,
    required this.onWeaponRemove,
    required this.onWeaponSlotUpdate,
    required this.onFilterChanged,
  });

  final List<MainWeaponSlot> weapons;
  final int selectedWeaponIndex;
  final List<TalentDef> combatTalents;
  final RulesCatalog catalog;
  final List<WeaponDef> catalogWeapons;
  final Attributes effectiveAttributes;
  final HeroSheet hero;
  final HeroState heroState;
  final CombatConfig draftCombatConfig;
  final Map<String, HeroTalentEntry> draftTalents;
  final String weaponFilterTalentId;
  final String weaponFilterCombatType;
  final String weaponFilterType;
  final String weaponFilterDistanceClass;
  final WeaponSaveCallback onWeaponSave;
  final void Function(int index) onWeaponRemove;
  final WeaponSlotUpdater onWeaponSlotUpdate;
  final WeaponFilterChanged onFilterChanged;

  @override
  State<CombatWeaponsSection> createState() => _CombatWeaponsSectionState();
}

class _CombatWeaponsSectionState extends State<CombatWeaponsSection> {
  final GlobalKey<WeaponEditorScreenState> _editorKey =
      GlobalKey<WeaponEditorScreenState>();
  int? _editingSlotIndex;
  MainWeaponSlot? _editorSeedWeapon;
  String? _catalogWeaponName;

  bool get _isWideLayout => MediaQuery.sizeOf(context).width >= 1280;

  CombatPreviewStats _previewForWeaponSlot(
    MainWeaponSlot slot, {
    int? slotIndex,
  }) {
    final tempSlots = List<MainWeaponSlot>.from(
      widget.draftCombatConfig.weaponSlots,
    );
    final previewIndex = slotIndex ?? tempSlots.length;
    if (slotIndex == null) {
      tempSlots.add(slot);
    } else if (slotIndex >= 0 && slotIndex < tempSlots.length) {
      tempSlots[slotIndex] = slot;
    }

    final maxRoll = widget.draftCombatConfig.specialRules.klingentaenzer
        ? 12
        : 6;
    final rawIni = widget.draftCombatConfig.manualMods.iniWurf;
    final effectiveIni = widget.draftCombatConfig.specialRules.aufmerksamkeit
        ? maxRoll
        : rawIni.clamp(0, maxRoll);
    final previewConfig = widget.draftCombatConfig.copyWith(
      weapons: tempSlots,
      selectedWeaponIndex: previewIndex,
      mainWeapon: tempSlots[previewIndex],
      manualMods: widget.draftCombatConfig.manualMods.copyWith(
        iniWurf: effectiveIni,
      ),
    );
    return computeCombatPreviewStats(
      widget.hero,
      widget.heroState,
      overrideConfig: previewConfig,
      overrideTalents: widget.draftTalents,
      catalogTalents: widget.catalog.talents,
    );
  }

  MainWeaponSlot _sourceSlotFor(int? slotIndex, MainWeaponSlot? initialWeapon) {
    if (initialWeapon != null) {
      return initialWeapon;
    }
    if (slotIndex == null ||
        slotIndex < 0 ||
        slotIndex >= widget.weapons.length) {
      return const MainWeaponSlot();
    }
    return widget.weapons[slotIndex];
  }

  Future<void> _openCatalogSheet() async {
    final selectedWeapon = await showModalBottomSheet<WeaponDef>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SizedBox(
          height: screenHeight * 0.8,
          child: WeaponCatalogTable(
            weapons: widget.catalogWeapons,
            onSelectWeapon: (weapon) => Navigator.of(context).pop(weapon),
          ),
        );
      },
    );
    if (selectedWeapon == null || !mounted) {
      return;
    }
    final slot = weaponSlotFromCatalog(selectedWeapon, widget.combatTalents);
    await _openEditor(
      initialWeapon: slot,
      catalogWeaponName: selectedWeapon.name,
    );
  }

  Future<bool> _closeWideEditorIfNeeded() async {
    final state = _editorKey.currentState;
    if (state == null) {
      return true;
    }
    return state.requestClose();
  }

  Future<void> _openEditor({
    int? slotIndex,
    MainWeaponSlot? initialWeapon,
    String? catalogWeaponName,
  }) async {
    final sourceSlot = _sourceSlotFor(slotIndex, initialWeapon);
    if (_isWideLayout) {
      final mayReplace = await _closeWideEditorIfNeeded();
      if (!mayReplace || !mounted) {
        return;
      }
      setState(() {
        _editingSlotIndex = slotIndex;
        _editorSeedWeapon = sourceSlot;
        _catalogWeaponName = catalogWeaponName;
      });
      return;
    }

    final result = await Navigator.of(context).push<MainWeaponSlot>(
      MaterialPageRoute(
        builder: (context) => WeaponEditorScreen(
          isNew: slotIndex == null,
          initialWeapon: slotIndex == null ? initialWeapon : sourceSlot,
          combatTalents: widget.combatTalents,
          effectiveAttributes: widget.effectiveAttributes,
          catalogWeapons: widget.catalogWeapons,
          previewBuilder: (slot) =>
              _previewForWeaponSlot(slot, slotIndex: slotIndex),
          catalogWeaponName: catalogWeaponName,
        ),
      ),
    );
    if (result == null) {
      return;
    }
    await widget.onWeaponSave(result, slotIndex: slotIndex);
  }

  void _closeWideEditor() {
    setState(() {
      _editingSlotIndex = null;
      _editorSeedWeapon = null;
      _catalogWeaponName = null;
    });
  }

  Future<void> _saveWideEditor(MainWeaponSlot slot) async {
    await widget.onWeaponSave(slot, slotIndex: _editingSlotIndex);
    if (!mounted) {
      return;
    }
    _closeWideEditor();
  }

  @override
  Widget build(BuildContext context) {
    UiRebuildObserver.bump('combat_weapons_section');
    final table = CombatWeaponsOverviewTable(
      weapons: widget.weapons,
      selectedWeaponIndex: widget.selectedWeaponIndex,
      combatTalents: widget.combatTalents,
      catalog: widget.catalog,
      hero: widget.hero,
      heroState: widget.heroState,
      draftCombatConfig: widget.draftCombatConfig,
      draftTalents: widget.draftTalents,
      weaponFilterTalentId: widget.weaponFilterTalentId,
      weaponFilterCombatType: widget.weaponFilterCombatType,
      weaponFilterType: widget.weaponFilterType,
      weaponFilterDistanceClass: widget.weaponFilterDistanceClass,
      onWeaponEdit: (index) => _openEditor(slotIndex: index),
      onWeaponAdd: () => _openEditor(),
      onWeaponCatalog: _openCatalogSheet,
      onWeaponRemove: widget.onWeaponRemove,
      onWeaponSlotUpdate: widget.onWeaponSlotUpdate,
      onFilterChanged: widget.onFilterChanged,
    );
    if (!_isWideLayout) {
      return table;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: table),
        const SizedBox(width: 12),
        SizedBox(
          width: 420,
          child: _editorSeedWeapon == null
              ? const SizedBox.shrink()
              : Card(
                  child: WeaponEditorScreen(
                    key: _editorKey,
                    isNew: _editingSlotIndex == null,
                    initialWeapon: _editingSlotIndex == null
                        ? _editorSeedWeapon
                        : _sourceSlotFor(_editingSlotIndex, null),
                    combatTalents: widget.combatTalents,
                    effectiveAttributes: widget.effectiveAttributes,
                    catalogWeapons: widget.catalogWeapons,
                    previewBuilder: (slot) => _previewForWeaponSlot(
                      slot,
                      slotIndex: _editingSlotIndex,
                    ),
                    catalogWeaponName: _catalogWeaponName,
                    showAppBar: false,
                    onSaved: (slot) {
                      _saveWideEditor(slot);
                    },
                    onCancel: _closeWideEditor,
                  ),
                ),
        ),
      ],
    );
  }
}
