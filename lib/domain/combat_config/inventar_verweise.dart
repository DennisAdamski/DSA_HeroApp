/// Verweisformat zwischen Kampfkonfiguration und Inventar.
///
/// Ein verknuepfter Inventareintrag traegt in `sourceRef` den Verweis auf
/// seinen Slot. Aktuell verweist er ueber die stabile Slot-ID (`w#<id>`,
/// `a#<id>`, `oh#<id>`, Geschosse `w#<waffe>|p#<geschoss>`). Bis September
/// 2026 verwies er ueber den Namen (`w:<Name>` …); gleichnamige Exemplare
/// liessen sich so nur ueber ihre Reihenfolge unterscheiden, Entfernen und
/// Umbenennen vertauschten oder verloren Inventardaten (Befunde
/// ARCH-07-B2/B3). Namensverweise werden beim Laden einmalig umgestellt
/// ([migriereInventarVerweise]).
library;

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Namensverweis (Altformat) auf einen Waffenslot.
String weaponRef(String weaponName) => 'w:${weaponName.trim()}';

/// Namensverweis (Altformat) auf ein Ruestungsstueck.
String armorRef(String pieceName) => 'a:${pieceName.trim()}';

/// Namensverweis (Altformat) auf ein Geschoss einer Waffe.
String projectileRef(String weaponName, String projName) =>
    'w:${weaponName.trim()}|p:${projName.trim()}';

/// Namensverweis (Altformat) auf ein Nebenhand-Teil.
String offhandRef(String equipmentName) => 'oh:${equipmentName.trim()}';

/// ID-Verweis auf einen Waffenslot.
String weaponIdRef(String id) => 'w#$id';

/// ID-Verweis auf ein Ruestungsstueck.
String armorIdRef(String id) => 'a#$id';

/// ID-Verweis auf ein Geschoss innerhalb seiner Waffe.
String projectileIdRef(String weaponId, String projectileId) =>
    'w#$weaponId|p#$projectileId';

/// ID-Verweis auf ein Nebenhand-Teil.
String offhandIdRef(String id) => 'oh#$id';

/// Verweis eines Slots samt seinem Namensverweis aus dem Altformat.
///
/// [ref] ist der ID-Verweis; fehlt dem Slot (noch) eine ID, faellt er auf
/// den Namensverweis zurueck. [altRef] findet Eintraege aus Altbestaenden.
typedef SlotVerweis = ({String ref, String altRef});

/// Verweis fuer einen Waffenslot.
SlotVerweis verweisFuerWaffe(MainWeaponSlot slot) {
  final alt = weaponRef(slot.name);
  return (ref: slot.id.isEmpty ? alt : weaponIdRef(slot.id), altRef: alt);
}

/// Verweis fuer ein Geschoss eines Waffenslots.
SlotVerweis verweisFuerGeschoss(
  MainWeaponSlot slot,
  RangedProjectile geschoss,
) {
  final alt = projectileRef(slot.name, geschoss.name);
  final hatIds = slot.id.isNotEmpty && geschoss.id.isNotEmpty;
  return (
    ref: hatIds ? projectileIdRef(slot.id, geschoss.id) : alt,
    altRef: alt,
  );
}

/// Verweis fuer ein Ruestungsstueck.
SlotVerweis verweisFuerRuestung(ArmorPiece piece) {
  final alt = armorRef(piece.name);
  return (ref: piece.id.isEmpty ? alt : armorIdRef(piece.id), altRef: alt);
}

/// Verweis fuer ein Nebenhand-Teil.
SlotVerweis verweisFuerNebenhand(OffhandEquipmentEntry equipment) {
  final alt = offhandRef(equipment.name);
  return (
    ref: equipment.id.isEmpty ? alt : offhandIdRef(equipment.id),
    altRef: alt,
  );
}

/// Alle Verweise benannter Slots in kanonischer Reihenfolge.
///
/// Waffen mit ihren Geschossen, dann Ruestung, dann Nebenhand — dieselbe
/// Reihenfolge, in der das Inventar verknuepfte Eintraege fuehrt.
List<SlotVerweis> erwarteteVerweise(CombatConfig config) {
  final verweise = <SlotVerweis>[];
  for (final slot in config.weaponSlots) {
    if (slot.name.trim().isEmpty) continue;
    verweise.add(verweisFuerWaffe(slot));
    if (!slot.isRanged) continue;
    for (final geschoss in slot.rangedProfile.projectiles) {
      if (geschoss.name.trim().isEmpty) continue;
      verweise.add(verweisFuerGeschoss(slot, geschoss));
    }
  }
  for (final piece in config.armor.pieces) {
    if (piece.name.trim().isEmpty) continue;
    verweise.add(verweisFuerRuestung(piece));
  }
  for (final equipment in config.offhandEquipment) {
    if (equipment.name.trim().isEmpty) continue;
    verweise.add(verweisFuerNebenhand(equipment));
  }
  return verweise;
}

/// Stellt Namensverweise auf ID-Verweise um, ohne sonst etwas zu aendern.
///
/// Zuordnung wie bisher beim Abgleich: der erste noch freie Eintrag mit dem
/// passenden Namensverweis, in Slot-Reihenfolge. Deterministisch, damit alle
/// Geraete aus denselben Altdaten dasselbe errechnen. Eintraege ohne Partner
/// behalten ihren Verweis; der naechste Abgleich raeumt sie auf.
List<HeroInventoryEntry> migriereInventarVerweise(
  List<HeroInventoryEntry> entries,
  CombatConfig config,
) {
  final offen = <int>[
    for (var i = 0; i < entries.length; i++)
      if (_istNamensverweis(entries[i])) i,
  ];
  if (offen.isEmpty) {
    return entries;
  }
  final belegteVerweise = <String>{
    for (final entry in entries)
      if (entry.sourceRef != null &&
          isCombatLinkedInventorySource(entry.source) &&
          !_istNamensverweis(entry))
        entry.sourceRef!,
  };
  final ergebnis = List<HeroInventoryEntry>.of(entries);
  for (final verweis in erwarteteVerweise(config)) {
    if (verweis.ref == verweis.altRef ||
        belegteVerweise.contains(verweis.ref)) {
      continue;
    }
    final treffer = offen.indexWhere(
      (index) => entries[index].sourceRef == verweis.altRef,
    );
    if (treffer < 0) continue;
    final index = offen.removeAt(treffer);
    ergebnis[index] = entries[index].copyWith(sourceRef: verweis.ref);
    belegteVerweise.add(verweis.ref);
  }
  return List<HeroInventoryEntry>.unmodifiable(ergebnis);
}

// Migriert nur einen Verweis, dessen Altformat zur fachlichen Quelle passt.
bool _istNamensverweis(HeroInventoryEntry entry) {
  final ref = entry.sourceRef;
  if (ref == null) return false;
  return switch (entry.source) {
    InventoryItemSource.waffe => ref.startsWith('w:') && !ref.contains('|p:'),
    InventoryItemSource.geschoss => ref.startsWith('w:') && ref.contains('|p:'),
    InventoryItemSource.ruestung => ref.startsWith('a:'),
    InventoryItemSource.nebenhand => ref.startsWith('oh:'),
    InventoryItemSource.manuell || InventoryItemSource.abenteuer => false,
  };
}
