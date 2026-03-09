// Re-Exporte aller Teilmodelle fuer Rueckwaertskompatibilitaet.
// Importeure dieser Datei erhalten automatisch Zugriff auf alle Typen.
export 'package:dsa_heldenverwaltung/domain/combat_config/offhand_mode.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/ranged_distance_band.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/ranged_weapon_profile.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/weapon_combat_type.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/offhand_assignment.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_entry.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_type.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/offhand_slot.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/armor_config.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/combat_special_rules.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/combat_manual_mods.dart';
export 'package:dsa_heldenverwaltung/domain/combat_config/shield_size.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config/armor_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/combat_manual_mods.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/combat_special_rules.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_assignment.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_entry.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_type.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_mode.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_slot.dart';

/// Aggregiert alle Kampfkonfigurationsdaten eines Helden.
///
/// Enthaelt die Waffenliste, den aktiven Waffen-Slot, Nebenhand, Ruestung,
/// Sonderfertigkeiten und manuelle Modifikatoren.
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
///
/// Der aktive Waffenslot wird durch [selectedWeaponIndex] bestimmt.
/// -1 bedeutet "kein Slot gewaehlt" (Fallback auf Legacy-[mainWeapon]).
class CombatConfig {
  const CombatConfig({
    this.mainWeapon = const MainWeaponSlot(),
    this.weapons = const <MainWeaponSlot>[],
    this.selectedWeaponIndex = 0,
    this.offhandAssignment = const OffhandAssignment(),
    this.offhandEquipment = const <OffhandEquipmentEntry>[],
    this.armor = const ArmorConfig(),
    this.specialRules = const CombatSpecialRules(),
    this.manualMods = const CombatManualMods(),
  });

  /// Legacy-Hauptwaffe (wird bei [weapons.isEmpty] als einziger Slot verwendet).
  final MainWeaponSlot mainWeapon;

  /// Alle konfigurierten Waffenslots des Helden.
  final List<MainWeaponSlot> weapons;

  /// Index des aktuell aktiven Waffenslots; -1 = kein Slot.
  final int selectedWeaponIndex;

  /// Referenz auf den aktiven Nebenhand-Eintrag.
  final OffhandAssignment offhandAssignment;

  /// Alle Schild-/Parierwaffen-Eintraege des Kampf-Inventars.
  final List<OffhandEquipmentEntry> offhandEquipment;

  /// Ruestungskonfiguration mit allen angelegten Stuecken.
  final ArmorConfig armor;

  /// Aktivierungszustaende aller Kampfsonderfertigkeiten.
  final CombatSpecialRules specialRules;

  /// Manuell eingegebene Kampfmodifikatoren (AT, PA, Ini, Ausweichen, IniWurf).
  final CombatManualMods manualMods;

  /// Gibt die normalisierte Waffenliste zurueck.
  ///
  /// Ist [weapons] leer, wird [mainWeapon] als einziger Slot zurueckgegeben.
  List<MainWeaponSlot> get weaponSlots {
    if (weapons.isEmpty) {
      return <MainWeaponSlot>[mainWeapon];
    }
    return List<MainWeaponSlot>.from(weapons, growable: false);
  }

  /// Gibt an, ob [selectedWeaponIndex] auf einen gueltigen Slot zeigt.
  bool get hasSelectedWeapon {
    final slots = weaponSlots;
    final index = selectedWeaponIndex;
    return index >= 0 && index < slots.length;
  }

  /// Gibt den aktuell ausgewaehlten Waffenslot zurueck, oder `null` wenn keiner.
  MainWeaponSlot? get selectedWeaponOrNull {
    if (!hasSelectedWeapon) {
      return null;
    }
    return weaponSlots[selectedWeaponIndex];
  }

  /// Gibt den aktuell ausgewaehlten Waffenslot zurueck.
  ///
  /// Faellt auf einen leeren [MainWeaponSlot] zurueck, wenn kein Slot gewaehlt.
  MainWeaponSlot get selectedWeapon {
    return selectedWeaponOrNull ?? const MainWeaponSlot();
  }

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ///
  /// Normalisiert [selectedWeaponIndex] automatisch auf den gueltigen Bereich.
  /// Synchronisiert [mainWeapon] mit dem aktiven Slot.
  CombatConfig copyWith({
    MainWeaponSlot? mainWeapon,
    List<MainWeaponSlot>? weapons,
    int? selectedWeaponIndex,
    OffhandAssignment? offhandAssignment,
    List<OffhandEquipmentEntry>? offhandEquipment,
    ArmorConfig? armor,
    CombatSpecialRules? specialRules,
    CombatManualMods? manualMods,
  }) {
    final nextWeapons = List<MainWeaponSlot>.from(
      weapons ?? weaponSlots,
      growable: false,
    );
    final nextSelectedIndex = _normalizeSelectedWeaponIndex(
      selectedWeaponIndex ?? this.selectedWeaponIndex,
      nextWeapons.length,
    );
    final nextMain =
        mainWeapon ??
        (nextSelectedIndex < 0
            ? this.mainWeapon
            : nextWeapons[nextSelectedIndex]);
    final normalizedWeapons = List<MainWeaponSlot>.from(nextWeapons);
    if (nextSelectedIndex >= 0) {
      normalizedWeapons[nextSelectedIndex] = nextMain;
    }

    return CombatConfig(
      mainWeapon: nextMain,
      weapons: List<MainWeaponSlot>.unmodifiable(normalizedWeapons),
      selectedWeaponIndex: nextSelectedIndex,
      offhandAssignment: _normalizeOffhandAssignment(
        offhandAssignment ?? this.offhandAssignment,
        normalizedWeapons.length,
        (offhandEquipment ?? this.offhandEquipment).length,
        nextSelectedIndex,
      ),
      offhandEquipment: List<OffhandEquipmentEntry>.unmodifiable(
        offhandEquipment ?? this.offhandEquipment,
      ),
      armor: armor ?? this.armor,
      specialRules: specialRules ?? this.specialRules,
      manualMods: manualMods ?? this.manualMods,
    );
  }

  /// Serialisiert die Kampfkonfiguration zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    final slots = weaponSlots;
    final index = _normalizeSelectedWeaponIndex(
      selectedWeaponIndex,
      slots.length,
    );
    final activeWeapon = index < 0 ? mainWeapon : slots[index];
    return {
      'mainWeapon': activeWeapon.toJson(),
      'weapons': slots.map((entry) => entry.toJson()).toList(growable: false),
      'selectedWeaponIndex': index,
      'offhandAssignment': _normalizeOffhandAssignment(
        offhandAssignment,
        slots.length,
        offhandEquipment.length,
        index,
      ).toJson(),
      'offhandEquipment': offhandEquipment
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'armor': armor.toJson(),
      'specialRules': specialRules.toJson(),
      'manualMods': manualMods.toJson(),
    };
  }

  /// Deserialisiert eine [CombatConfig] aus einem JSON-Map.
  ///
  /// Unterstuetzt Legacy-Schema (nur `mainWeapon`, keine `weapons`-Liste).
  /// Tolerant bei fehlenden Feldern (Standardobjekte werden eingesetzt).
  static CombatConfig fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> readMap(String key) {
      final raw = json[key];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return raw.cast<String, dynamic>();
      }
      return const <String, dynamic>{};
    }

    final legacyMain = MainWeaponSlot.fromJson(readMap('mainWeapon'));
    final rawWeapons = (json['weapons'] as List?) ?? const <dynamic>[];
    final parsedWeapons = rawWeapons
        .whereType<Map>()
        .map((entry) => MainWeaponSlot.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
    final slots = parsedWeapons.isEmpty
        ? <MainWeaponSlot>[legacyMain]
        : parsedWeapons;
    final selectedIndex = _normalizeSelectedWeaponIndex(
      (json['selectedWeaponIndex'] as num?)?.toInt() ?? 0,
      slots.length,
    );
    final selectedMain = selectedIndex < 0 ? legacyMain : slots[selectedIndex];
    final rawOffhandEquipment =
        (json['offhandEquipment'] as List?) ?? const <dynamic>[];
    final parsedOffhandEquipment = rawOffhandEquipment
        .whereType<Map>()
        .map(
          (entry) => OffhandEquipmentEntry.fromJson(
            entry.cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
    final legacyOffhand = OffhandSlot.fromJson(readMap('offhand'));
    final migrated = _migrateLegacyOffhand(
      legacy: legacyOffhand,
      selectedWeaponIndex: selectedIndex,
      weaponCount: slots.length,
      existingEntries: parsedOffhandEquipment,
    );
    final assignment = json.containsKey('offhandAssignment')
        ? OffhandAssignment.fromJson(readMap('offhandAssignment'))
        : migrated.assignment;
    final equipment = parsedOffhandEquipment.isEmpty
        ? migrated.equipment
        : parsedOffhandEquipment;

    return CombatConfig(
      mainWeapon: selectedMain,
      weapons: slots,
      selectedWeaponIndex: selectedIndex,
      offhandAssignment: _normalizeOffhandAssignment(
        assignment,
        slots.length,
        equipment.length,
        selectedIndex,
      ),
      offhandEquipment: equipment,
      armor: ArmorConfig.fromJson(readMap('armor')),
      specialRules: CombatSpecialRules.fromJson(readMap('specialRules')),
      manualMods: CombatManualMods.fromJson(readMap('manualMods')),
    );
  }
}

/// Normalisiert einen Waffenslot-Index auf den gueltigen Bereich.
///
/// Gibt -1 zurueck fuer explizit ungueltige Werte oder leere Listen.
/// Klemmt positive Ueberschreitungen auf den letzten gueltigen Index.
int _normalizeSelectedWeaponIndex(int value, int length) {
  if (value == -1) {
    return -1;
  }
  if (value < 0) {
    return -1;
  }
  if (length <= 0) {
    return -1;
  }
  if (value >= length) {
    return length - 1;
  }
  return value;
}

OffhandAssignment _normalizeOffhandAssignment(
  OffhandAssignment value,
  int weaponCount,
  int equipmentCount,
  int selectedWeaponIndex,
) {
  final normalizedWeaponIndex =
      value.weaponIndex >= 0 && value.weaponIndex < weaponCount
      ? value.weaponIndex
      : -1;
  final normalizedEquipmentIndex =
      value.equipmentIndex >= 0 && value.equipmentIndex < equipmentCount
      ? value.equipmentIndex
      : -1;
  if (normalizedWeaponIndex == selectedWeaponIndex) {
    return const OffhandAssignment();
  }
  if (normalizedWeaponIndex >= 0) {
    return OffhandAssignment(weaponIndex: normalizedWeaponIndex);
  }
  if (normalizedEquipmentIndex >= 0) {
    return OffhandAssignment(equipmentIndex: normalizedEquipmentIndex);
  }
  return const OffhandAssignment();
}

({OffhandAssignment assignment, List<OffhandEquipmentEntry> equipment})
_migrateLegacyOffhand({
  required OffhandSlot legacy,
  required int selectedWeaponIndex,
  required int weaponCount,
  required List<OffhandEquipmentEntry> existingEntries,
}) {
  if (legacy.mode == OffhandMode.none || legacy.mode == OffhandMode.linkhand) {
    return (
      assignment: const OffhandAssignment(),
      equipment: existingEntries,
    );
  }
  final migratedEntry = OffhandEquipmentEntry(
    name: legacy.name,
    type: legacy.mode == OffhandMode.shield
        ? OffhandEquipmentType.shield
        : OffhandEquipmentType.parryWeapon,
    breakFactor: 0,
    iniMod: legacy.iniMod,
    atMod: legacy.atMod,
    paMod: legacy.paMod,
  );
  final nextEquipment = List<OffhandEquipmentEntry>.from(existingEntries)
    ..add(migratedEntry);
  return (
    assignment: OffhandAssignment(
      equipmentIndex: nextEquipment.isEmpty ? -1 : nextEquipment.length - 1,
    ),
    equipment: List<OffhandEquipmentEntry>.unmodifiable(nextEquipment),
  );
}
