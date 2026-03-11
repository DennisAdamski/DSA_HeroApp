// Orchestrator fuer den Ausruestungs-Subtab im Kampf-Tab.
//
// Kombiniert CombatWeaponsSection, CombatOffhandSection und
// CombatArmorSection in einer ListView und leitet Callbacks an den
// Parent weiter.
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_armor_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_offhand_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_weapons_section.dart';

/// Orchestriert die drei Sektionen des Ausruestungs-Subtabs:
/// Waffen, Nebenhand-Ausruestung und Ruestung.
class CombatEquipmentSubtab extends StatelessWidget {
  const CombatEquipmentSubtab({
    super.key,
    required this.combatTalents,
    required this.catalog,
    required this.hero,
    required this.heroState,
    required this.preview,
    required this.draftCombatConfig,
    required this.draftTalents,
    required this.weaponFilterTalentId,
    required this.weaponFilterCombatType,
    required this.weaponFilterType,
    required this.weaponFilterDistanceClass,
    required this.onWeaponEdit,
    required this.onWeaponAdd,
    required this.onWeaponCatalog,
    required this.onWeaponRemove,
    required this.onWeaponSlotUpdate,
    required this.onFilterChanged,
    required this.onOffhandEquipmentChanged,
    required this.onArmorChanged,
  });

  final List<TalentDef> combatTalents;
  final RulesCatalog catalog;
  final HeroSheet hero;
  final HeroState heroState;
  final CombatPreviewStats preview;
  final CombatConfig draftCombatConfig;
  final Map<String, HeroTalentEntry> draftTalents;
  final String weaponFilterTalentId;
  final String weaponFilterCombatType;
  final String weaponFilterType;
  final String weaponFilterDistanceClass;

  final void Function(int index) onWeaponEdit;
  final VoidCallback onWeaponAdd;
  final VoidCallback onWeaponCatalog;
  final void Function(int index) onWeaponRemove;
  final WeaponSlotUpdater onWeaponSlotUpdate;
  final WeaponFilterChanged onFilterChanged;
  final void Function(List<OffhandEquipmentEntry>) onOffhandEquipmentChanged;
  final void Function(ArmorConfig) onArmorChanged;

  @override
  Widget build(BuildContext context) {
    final weapons = draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = draftCombatConfig.selectedWeaponIndex;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CombatWeaponsSection(
          weapons: weapons,
          selectedWeaponIndex: selectedWeaponIndex,
          combatTalents: combatTalents,
          catalog: catalog,
          hero: hero,
          heroState: heroState,
          draftCombatConfig: draftCombatConfig,
          draftTalents: draftTalents,
          weaponFilterTalentId: weaponFilterTalentId,
          weaponFilterCombatType: weaponFilterCombatType,
          weaponFilterType: weaponFilterType,
          weaponFilterDistanceClass: weaponFilterDistanceClass,
          onWeaponEdit: onWeaponEdit,
          onWeaponAdd: onWeaponAdd,
          onWeaponCatalog: onWeaponCatalog,
          onWeaponRemove: onWeaponRemove,
          onWeaponSlotUpdate: onWeaponSlotUpdate,
          onFilterChanged: onFilterChanged,
        ),
        const SizedBox(height: 12),
        CombatOffhandSection(
          offhandEquipment: draftCombatConfig.offhandEquipment,
          onOffhandEquipmentChanged: onOffhandEquipmentChanged,
        ),
        const SizedBox(height: 12),
        CombatArmorSection(
          armor: draftCombatConfig.armor,
          onArmorChanged: onArmorChanged,
          previewRsTotal: preview.rsTotal,
          previewBeTotalRaw: preview.beTotalRaw,
          previewRgReduction: preview.rgReduction,
          previewBeKampf: preview.beKampf,
          previewBeMod: preview.beMod,
          previewEbe: preview.ebe,
        ),
      ],
    );
  }
}
