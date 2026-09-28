/// Verweisformat zwischen Kampfkonfiguration und Inventar.
///
/// Ein verknuepfter Inventareintrag traegt **zwei** Verweise auf seinen Slot:
///
/// - `sourceRef`: den Namensverweis (`w:<Name>`, `a:<Name>`, `oh:<Name>`,
///   Geschosse `w:<Waffe>|p:<Geschoss>`). Nur ihn kennt die bereits
///   veroeffentlichte App; sie ordnet darueber zu und verwirft Eintraege mit
///   anderem Format samt ihrer Inventardaten.
/// - `slotRef`: den stabilen ID-Verweis (`w#<id>`, `a#<id>`, `oh#<id>`,
///   Geschosse `w#<waffe>|p#<geschoss>`). Er unterscheidet gleichnamige
///   Exemplare, auch nach Entfernen oder Umbenennen (Befunde
///   ARCH-07-B2/B3). Die veroeffentlichte App verwirft ihn beim Speichern
///   zusammen mit den Slot-IDs.
///
/// Eine Vorabfassung (nur auf dem Entwicklungszweig, September 2026) trug
/// den ID-Verweis in `sourceRef`. [migriereInventarVerweise] stellt beide
/// Altformate beim Laden um.
library;

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Namensverweis auf einen Waffenslot.
String weaponRef(String weaponName) => 'w:${weaponName.trim()}';

/// Namensverweis auf ein Ruestungsstueck.
String armorRef(String pieceName) => 'a:${pieceName.trim()}';

/// Namensverweis auf ein Geschoss einer Waffe.
String projectileRef(String weaponName, String projName) =>
    'w:${weaponName.trim()}|p:${projName.trim()}';

/// Namensverweis auf ein Nebenhand-Teil.
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

/// Ob [ref] ein ID-Verweis ist (und kein Namensverweis).
bool istIdVerweis(String ref) {
  return ref.startsWith('w#') || ref.startsWith('a#') || ref.startsWith('oh#');
}

/// Beide Verweise eines Slots.
///
/// [slotRef] ist `null`, solange der Slot keine ID hat.
typedef SlotVerweis = ({String sourceRef, String? slotRef});

/// Verweise fuer einen Waffenslot.
SlotVerweis verweisFuerWaffe(MainWeaponSlot slot) {
  return (
    sourceRef: weaponRef(slot.name),
    slotRef: slot.id.isEmpty ? null : weaponIdRef(slot.id),
  );
}

/// Verweise fuer ein Geschoss eines Waffenslots.
SlotVerweis verweisFuerGeschoss(
  MainWeaponSlot slot,
  RangedProjectile geschoss,
) {
  final hatIds = slot.id.isNotEmpty && geschoss.id.isNotEmpty;
  return (
    sourceRef: projectileRef(slot.name, geschoss.name),
    slotRef: hatIds ? projectileIdRef(slot.id, geschoss.id) : null,
  );
}

/// Verweise fuer ein Ruestungsstueck.
SlotVerweis verweisFuerRuestung(ArmorPiece piece) {
  return (
    sourceRef: armorRef(piece.name),
    slotRef: piece.id.isEmpty ? null : armorIdRef(piece.id),
  );
}

/// Verweise fuer ein Nebenhand-Teil.
SlotVerweis verweisFuerNebenhand(OffhandEquipmentEntry equipment) {
  return (
    sourceRef: offhandRef(equipment.name),
    slotRef: equipment.id.isEmpty ? null : offhandIdRef(equipment.id),
  );
}

/// Alle Verweise benannter Slots in kanonischer Reihenfolge.
///
/// Waffen mit ihren Geschossen, dann Ruestung, dann Nebenhand — dieselbe
/// Reihenfolge, in der das Inventar verknuepfte Eintraege fuehrt. Die
/// veroeffentlichte App paart gleichnamige Eintraege ueber genau diese
/// Reihenfolge; sie darf sich nicht aendern.
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

/// Ergaenzt verknuepfte Eintraege beim Laden um ihren ID-Verweis.
///
/// Zwei Schritte, deterministisch, damit alle Geraete aus denselben Daten
/// dasselbe errechnen, und ein Fixpunkt:
///
/// 1. Eintraege der Vorabfassung mit ID-Verweis in `sourceRef` bekommen ihn
///    als `slotRef`, `sourceRef` wird wieder zum Namensverweis. Verweist die
///    ID auf keinen Slot mehr, bleibt `sourceRef` unveraendert; der naechste
///    Abgleich verwirft den Eintrag.
/// 2. Eintraege ohne `slotRef` — Altdaten oder zuletzt von der
///    veroeffentlichten App gespeichert — erhalten ihn ueber den Namen: der
///    erste noch freie gleichnamige Slot in Slot-Reihenfolge, wie beim
///    Abgleich der veroeffentlichten App.
///
/// Eintraege mit `slotRef` bleiben unberuehrt, ebenso Eintraege ohne
/// passenden Slot. Aendert sich nichts, kommt dieselbe Liste zurueck.
List<HeroInventoryEntry> migriereInventarVerweise(
  List<HeroInventoryEntry> entries,
  CombatConfig config,
) {
  final verweise = erwarteteVerweise(config);
  final ergebnis = List<HeroInventoryEntry>.of(entries);
  final vergeben = <String>{
    for (final entry in entries)
      if (entry.slotRef != null && _istVerknuepft(entry)) entry.slotRef!,
  };
  var geaendert = _uebernimmVorabfassung(ergebnis, verweise, vergeben);
  geaendert |= _ordneNamensverweiseZu(ergebnis, verweise, vergeben);
  if (!geaendert) {
    return entries;
  }
  return List<HeroInventoryEntry>.unmodifiable(ergebnis);
}

// Schritt 1: ID-Verweis aus `sourceRef` nach `slotRef` verschieben.
bool _uebernimmVorabfassung(
  List<HeroInventoryEntry> eintraege,
  List<SlotVerweis> verweise,
  Set<String> vergeben,
) {
  var geaendert = false;
  for (var i = 0; i < eintraege.length; i++) {
    final entry = eintraege[i];
    final ref = entry.sourceRef;
    if (entry.slotRef != null ||
        !_istVerknuepft(entry) ||
        !istIdVerweis(ref!)) {
      continue;
    }
    final slot = verweise.where((verweis) => verweis.slotRef == ref);
    eintraege[i] = entry.copyWith(
      slotRef: ref,
      sourceRef: slot.isEmpty ? ref : slot.first.sourceRef,
    );
    vergeben.add(ref);
    geaendert = true;
  }
  return geaendert;
}

// Schritt 2: Namensverweise ohne `slotRef` dem ersten freien Slot zuordnen.
bool _ordneNamensverweiseZu(
  List<HeroInventoryEntry> eintraege,
  List<SlotVerweis> verweise,
  Set<String> vergeben,
) {
  final offen = <int>[
    for (var i = 0; i < eintraege.length; i++)
      if (eintraege[i].slotRef == null && _istNamensverweis(eintraege[i])) i,
  ];
  var geaendert = false;
  for (final verweis in verweise) {
    final slotRef = verweis.slotRef;
    if (offen.isEmpty) break;
    if (slotRef == null || vergeben.contains(slotRef)) continue;
    final treffer = offen.indexWhere(
      (index) => eintraege[index].sourceRef == verweis.sourceRef,
    );
    if (treffer < 0) continue;
    final index = offen.removeAt(treffer);
    eintraege[index] = eintraege[index].copyWith(slotRef: slotRef);
    vergeben.add(slotRef);
    geaendert = true;
  }
  return geaendert;
}

// Mit einem Kampf-Slot verknuepft: Kampfquelle und ein Verweis.
bool _istVerknuepft(HeroInventoryEntry entry) {
  return entry.sourceRef != null && isCombatLinkedInventorySource(entry.source);
}

// Namensverweis, dessen Form zur fachlichen Quelle passt.
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
