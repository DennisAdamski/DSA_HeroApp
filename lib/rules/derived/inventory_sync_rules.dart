import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

// ---------------------------------------------------------------------------
// sourceRef-Schluessel
// ---------------------------------------------------------------------------

/// Erzeugt den sourceRef-Schluessel fuer einen Waffenslot.
String weaponRef(String weaponName) => 'w:${weaponName.trim()}';

/// Erzeugt den sourceRef-Schluessel fuer ein Ruestungsstueck.
String armorRef(String pieceName) => 'a:${pieceName.trim()}';

/// Erzeugt den sourceRef-Schluessel fuer ein Geschoss.
String projectileRef(String weaponName, String projName) =>
    'w:${weaponName.trim()}|p:${projName.trim()}';

/// Erzeugt den sourceRef-Schluessel fuer ein Nebenhands-Ausruestungsteil.
String offhandRef(String equipmentName) => 'oh:${equipmentName.trim()}';

// ---------------------------------------------------------------------------
// Erwartete verlinkte Eintraege aus CombatConfig ableiten
// ---------------------------------------------------------------------------

/// Erstellt die Menge erwarteter verlinkter Inventar-Eintraege aus [config].
///
/// Items ohne Namen (nach trim) werden uebersprungen.
/// Die Reihenfolge ist stabil: Waffen → deren Geschosse → Ruestung → Nebenhand.
List<HeroInventoryEntry> buildExpectedLinkedEntries(CombatConfig config) {
  final result = <HeroInventoryEntry>[];

  for (final slot in config.weaponSlots) {
    final name = slot.name.trim();
    if (name.isEmpty) continue;

    result.add(
      HeroInventoryEntry(
        gegenstand: name,
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.waffe,
        sourceRef: weaponRef(name),
        istAusgeruestet: true,
      ),
    );

    if (slot.isRanged) {
      for (final proj in slot.rangedProfile.projectiles) {
        final projName = proj.name.trim();
        if (projName.isEmpty) continue;
        result.add(
          HeroInventoryEntry(
            gegenstand: projName,
            anzahl: proj.count.toString(),
            itemType: InventoryItemType.verbrauchsgegenstand,
            source: InventoryItemSource.geschoss,
            sourceRef: projectileRef(name, projName),
            istAusgeruestet: false,
          ),
        );
      }
    }
  }

  for (final piece in config.armor.pieces) {
    final name = piece.name.trim();
    if (name.isEmpty) continue;
    result.add(
      HeroInventoryEntry(
        gegenstand: name,
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.ruestung,
        sourceRef: armorRef(name),
        istAusgeruestet: piece.isActive,
      ),
    );
  }

  for (final equipment in config.offhandEquipment) {
    final name = equipment.name.trim();
    if (name.isEmpty) continue;
    result.add(
      HeroInventoryEntry(
        gegenstand: name,
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.nebenhand,
        sourceRef: offhandRef(name),
        istAusgeruestet: true,
      ),
    );
  }

  return result;
}

// ---------------------------------------------------------------------------
// Reconcile
// ---------------------------------------------------------------------------

/// Synchronisiert das Inventar mit den Kampf-Tab-Eintraegen.
///
/// Algorithmus:
/// 1. Manuell angelegte Eintraege (`sourceRef == null`) werden unveraendert
///    uebernommen.
/// 2. Verlinkte Eintraege werden mit den erwarteten aus [config] abgeglichen:
///    - Vorhandener Eintrag gefunden → merge: Editierfelder beibehalten,
///      Identitaetsfelder aus CombatConfig aktualisieren.
///    - Nicht gefunden → neuer Eintrag aus CombatConfig wird eingefuegt.
///    - Eintrag nicht mehr erwartet → wird entfernt.
/// 3. Reihenfolge: manuelle Eintraege zuerst, dann verlinkte in Slot-Reihenfolge.
///
/// Namens-Kollisionen (z. B. zwei Waffen gleichen Namens) werden sicher behandelt,
/// da List-basiertes Matching statt Map-Lookup verwendet wird.
List<HeroInventoryEntry> reconcileInventoryWithCombat(
  List<HeroInventoryEntry> existing,
  CombatConfig config,
) {
  final preservedEntries = existing
      .where((entry) => !_isCombatLinkedInventoryEntry(entry))
      .toList(growable: false);

  // Kopie der verlinkten Eintraege, aus der gefundene Matches entfernt werden
  final unmatched = existing
      .where(_isCombatLinkedInventoryEntry)
      .toList();

  final expected = buildExpectedLinkedEntries(config);
  final merged = <HeroInventoryEntry>[];

  for (final expectedEntry in expected) {
    final ref = expectedEntry.sourceRef!;

    // List-basiertes Matching: ersten Treffer nehmen und aus Pool entfernen
    final matchIdx = unmatched.indexWhere((e) => e.sourceRef == ref);

    if (matchIdx >= 0) {
      final existing_ = unmatched.removeAt(matchIdx);
      merged.add(_mergeEntry(base: expectedEntry, existing: existing_));
    } else {
      merged.add(expectedEntry);
    }
  }

  // Verlinkte Eintraege, die nicht mehr erwartet werden, fallen weg (kein append)
  return <HeroInventoryEntry>[...preservedEntries, ...merged];
}

/// Uebernimmt die editierbaren Felder aus [existing] in [base].
///
/// Identitaetsfelder ([gegenstand], [source], [sourceRef], [itemType]) stammen
/// immer aus [base] (CombatConfig ist die Quelle der Wahrheit fuer den Namen).
/// Fuer Geschoss-Eintraege wird [anzahl] ebenfalls aus [base] uebernommen.
HeroInventoryEntry _mergeEntry({
  required HeroInventoryEntry base,
  required HeroInventoryEntry existing,
}) {
  final isProjectile = base.source == InventoryItemSource.geschoss;

  return base.copyWith(
    // Editierbare Felder aus dem bestehenden Eintrag beibehalten
    woGetragen: existing.woGetragen,
    welchesAbenteuer: existing.welchesAbenteuer,
    gewicht: existing.gewicht,
    wert: existing.wert,
    artefakt: existing.artefakt,
    amKoerper: existing.amKoerper,
    woDann: existing.woDann,
    gruppe: existing.gruppe,
    beschreibung: existing.beschreibung,
    modifiers: existing.modifiers,
    gewichtGramm: existing.gewichtGramm,
    wertSilber: existing.wertSilber,
    herkunft: existing.herkunft,
    // istAusgeruestet: bei Ausruestung aus Kampf-Config; bei Geschoss beibehalten
    istAusgeruestet:
        isProjectile ? existing.istAusgeruestet : base.istAusgeruestet,
    // anzahl: bei Geschossen immer aus CombatConfig (bidirektionaler Sync)
    anzahl: isProjectile ? base.anzahl : existing.anzahl,
  );
}

bool _isCombatLinkedInventoryEntry(HeroInventoryEntry entry) {
  return entry.sourceRef != null && isCombatLinkedInventorySource(entry.source);
}

// ---------------------------------------------------------------------------
// Bidirektionaler Geschoss-Sync: Inventar → CombatConfig
// ---------------------------------------------------------------------------

/// Aktualisiert die Geschossanzahl im [CombatConfig] anhand des Inventar-Eintrags.
///
/// Parst [projectileRef_] als `'w:{weaponName}|p:{projName}'`, sucht die
/// passende Waffe und das Geschoss per Name und gibt eine aktualisierte
/// [CombatConfig] zurueck.
///
/// Bei unbekanntem Ref oder keinem Treffer wird [config] unveraendert
/// zurueckgegeben.
CombatConfig applyAmmoCountChangeToConfig(
  CombatConfig config,
  String projectileRef_,
  int newCount,
) {
  // Format: 'w:{weaponName}|p:{projName}'
  final sepIdx = projectileRef_.indexOf('|p:');
  if (sepIdx < 0) return config;

  final weaponName = projectileRef_.substring(2, sepIdx); // nach 'w:'
  final projName = projectileRef_.substring(sepIdx + 3); // nach '|p:'

  if (weaponName.isEmpty || projName.isEmpty) return config;

  final useWeaponsList = config.weapons.isNotEmpty;
  final slots = config.weaponSlots;

  final slotIdx = slots.indexWhere((w) => w.name.trim() == weaponName);
  if (slotIdx < 0) return config;

  final slot = slots[slotIdx];
  if (!slot.isRanged) return config;

  final profile = slot.rangedProfile;
  final projIdx =
      profile.projectiles.indexWhere((p) => p.name.trim() == projName);
  if (projIdx < 0) return config;

  final updatedProjectiles = List<RangedProjectile>.from(profile.projectiles);
  updatedProjectiles[projIdx] =
      profile.projectiles[projIdx].copyWith(count: newCount.clamp(0, 9999));

  final updatedProfile = profile.copyWith(projectiles: updatedProjectiles);
  final updatedSlot = slot.copyWith(rangedProfile: updatedProfile);

  if (useWeaponsList) {
    final updatedWeapons = List<MainWeaponSlot>.from(config.weapons);
    updatedWeapons[slotIdx] = updatedSlot;
    return config.copyWith(weapons: updatedWeapons);
  } else {
    return config.copyWith(mainWeapon: updatedSlot);
  }
}
