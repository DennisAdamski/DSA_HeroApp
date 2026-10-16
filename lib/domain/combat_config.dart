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
export 'package:dsa_heldenverwaltung/domain/combat_config/waffenmeister_config.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config/armor_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/combat_manual_mods.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/combat_special_rules.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_assignment.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_entry.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_type.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_mode.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/waffenmeister_config.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

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
    this.waffenmeisterschaften = const <WaffenmeisterConfig>[],
    this.unbekannteFelder = const <String, Object?>{},
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

  /// Konfigurierte Waffenmeisterschaften (eine pro Waffenart).
  final List<WaffenmeisterConfig> waffenmeisterschaften;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  ///
  /// Gilt nur fuer diese Ebene; jedes Teilmodell darunter (Waffen samt
  /// Fernkampfprofil, Ruestung, Nebenhand, [offhandAssignment],
  /// [specialRules], [manualMods], [waffenmeisterschaften]) traegt einen
  /// eigenen Satz.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich des
  /// Altschluessels `offhand`, der beim Laden in [offhandEquipment]
  /// aufgeht. Als unbekannt zurueckgeschrieben, kaeme ein geloeschter
  /// migrierter Schild beim naechsten Laden wieder.
  static const Set<String> jsonSchluessel = <String>{
    'mainWeapon',
    'weapons',
    'selectedWeaponIndex',
    'offhandAssignment',
    'offhandEquipment',
    'armor',
    'specialRules',
    'manualMods',
    'waffenmeisterschaften',
    'offhand',
  };

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
    List<WaffenmeisterConfig>? waffenmeisterschaften,
    Map<String, Object?>? unbekannteFelder,
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
      waffenmeisterschaften: waffenmeisterschaften != null
          ? List<WaffenmeisterConfig>.unmodifiable(waffenmeisterschaften)
          : this.waffenmeisterschaften,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
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
    return mitUnbekanntenFeldern(<String, dynamic>{
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
      'waffenmeisterschaften': waffenmeisterschaften
          .map((entry) => entry.toJson())
          .toList(growable: false),
    }, unbekannteFelder);
  }

  /// Vergibt stabile IDs an benannte Slots, die noch keine eindeutige haben.
  ///
  /// Betrifft Waffen, ihre Geschosse, Ruestungsstuecke und Nebenhand-Teile;
  /// ueber die ID verweist das Inventar auf sie (`inventar_verweise.dart`).
  /// Ohne [neueId] entstehen deterministische IDs (`w1`, `a1`, `oh1`, je Waffe
  /// `p1`, jeweils die kleinste freie Nummer in Listenreihenfolge). Das nutzt
  /// das Laden: alle Geraete errechnen aus denselben Altdaten dieselben IDs.
  /// Beim Speichern uebergibt `HeroActions` einen UUID-Erzeuger, damit ein
  /// neuer Slot nie die ID eines gerade entfernten erbt. Bestehende IDs
  /// bleiben; bei Doppelungen (etwa nach dem Kopieren eines Slots) behaelt nur
  /// das erste Vorkommen seine. Unbenannte Slots bleiben ohne ID, sie haben
  /// keinen Inventareintrag.
  CombatConfig withStableIds({String Function()? neueId}) {
    var geaendert = false;
    final waffen = _mitStabilenIds<MainWeaponSlot>(
      weaponSlots,
      praefix: 'w',
      idVon: (slot) => slot.id,
      nameVon: (slot) => slot.name,
      setzeId: (slot, id) => slot.copyWith(id: id),
      neueId: neueId,
    );
    geaendert |= waffen != null;
    final waffenMitGeschossen = <MainWeaponSlot>[];
    for (final slot in waffen ?? weaponSlots) {
      final geschosse = _mitStabilenIds<RangedProjectile>(
        slot.rangedProfile.projectiles,
        praefix: 'p',
        idVon: (geschoss) => geschoss.id,
        nameVon: (geschoss) => geschoss.name,
        setzeId: (geschoss, id) => geschoss.copyWith(id: id),
        neueId: neueId,
      );
      if (geschosse == null) {
        waffenMitGeschossen.add(slot);
        continue;
      }
      geaendert = true;
      waffenMitGeschossen.add(
        slot.copyWith(
          rangedProfile: slot.rangedProfile.copyWith(projectiles: geschosse),
        ),
      );
    }
    final ruestung = _mitStabilenIds<ArmorPiece>(
      armor.pieces,
      praefix: 'a',
      idVon: (piece) => piece.id,
      nameVon: (piece) => piece.name,
      setzeId: (piece, id) => piece.copyWith(id: id),
      neueId: neueId,
    );
    geaendert |= ruestung != null;
    final nebenhand = _mitStabilenIds<OffhandEquipmentEntry>(
      offhandEquipment,
      praefix: 'oh',
      idVon: (entry) => entry.id,
      nameVon: (entry) => entry.name,
      setzeId: (entry, id) => entry.copyWith(id: id),
      neueId: neueId,
    );
    geaendert |= nebenhand != null;
    if (!geaendert) {
      return this;
    }
    return copyWith(
      weapons: waffenMitGeschossen,
      armor: ruestung == null ? armor : armor.copyWith(pieces: ruestung),
      offhandEquipment: nebenhand,
    );
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
          (entry) =>
              OffhandEquipmentEntry.fromJson(entry.cast<String, dynamic>()),
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

    final config = CombatConfig(
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
      waffenmeisterschaften: _parseWaffenmeisterschaften(json),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
    // Altdaten ohne Slot-IDs bekommen sie hier deterministisch.
    return config.withStableIds();
  }
}

/// Ergaenzt fehlende oder doppelte IDs in [eintraege].
///
/// Liefert `null`, wenn nichts zu tun war, damit unveraenderte Listen ihre
/// Instanz behalten.
List<T>? _mitStabilenIds<T>(
  List<T> eintraege, {
  required String praefix,
  required String Function(T) idVon,
  required String Function(T) nameVon,
  required T Function(T, String) setzeId,
  String Function()? neueId,
}) {
  final vergeben = <String>{};
  final behaelt = <bool>[
    for (final eintrag in eintraege)
      idVon(eintrag).isNotEmpty && vergeben.add(idVon(eintrag)),
  ];
  var naechsteNummer = 1;
  String erzeuge() {
    if (neueId != null) {
      return neueId();
    }
    while (vergeben.contains('$praefix$naechsteNummer')) {
      naechsteNummer++;
    }
    final id = '$praefix$naechsteNummer';
    vergeben.add(id);
    return id;
  }

  var geaendert = false;
  final ergebnis = <T>[];
  for (var i = 0; i < eintraege.length; i++) {
    final eintrag = eintraege[i];
    if (behaelt[i] || nameVon(eintrag).trim().isEmpty) {
      ergebnis.add(eintrag);
      continue;
    }
    geaendert = true;
    ergebnis.add(setzeId(eintrag, erzeuge()));
  }
  return geaendert ? List<T>.unmodifiable(ergebnis) : null;
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
  // Per `copyWith`, damit unbekannte Felder der Auswahl erhalten bleiben.
  // Nur eine echte Doppelbelegung leert die Nebenhand; ohne Hauptwaffe
  // (beide -1) bleibt ein Schild oder eine Parierwaffe in der Hand.
  if (normalizedWeaponIndex >= 0 &&
      normalizedWeaponIndex == selectedWeaponIndex) {
    return value.copyWith(weaponIndex: -1, equipmentIndex: -1);
  }
  if (normalizedWeaponIndex >= 0) {
    return value.copyWith(
      weaponIndex: normalizedWeaponIndex,
      equipmentIndex: -1,
    );
  }
  if (normalizedEquipmentIndex >= 0) {
    return value.copyWith(
      weaponIndex: -1,
      equipmentIndex: normalizedEquipmentIndex,
    );
  }
  return value.copyWith(weaponIndex: -1, equipmentIndex: -1);
}

({OffhandAssignment assignment, List<OffhandEquipmentEntry> equipment})
_migrateLegacyOffhand({
  required OffhandSlot legacy,
  required int selectedWeaponIndex,
  required int weaponCount,
  required List<OffhandEquipmentEntry> existingEntries,
}) {
  if (legacy.mode == OffhandMode.none || legacy.mode == OffhandMode.linkhand) {
    return (assignment: const OffhandAssignment(), equipment: existingEntries);
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

/// Parst die Waffenmeisterschaften aus einem JSON-Map.
List<WaffenmeisterConfig> _parseWaffenmeisterschaften(
  Map<String, dynamic> json,
) {
  final raw = (json['waffenmeisterschaften'] as List?) ?? const <dynamic>[];
  final parsed = raw
      .whereType<Map>()
      .map(
        (entry) => WaffenmeisterConfig.fromJson(entry.cast<String, dynamic>()),
      )
      .toList(growable: false);
  return List<WaffenmeisterConfig>.unmodifiable(parsed);
}
