import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/inventar_verweise.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

// Das Verweisformat liegt in der Domain, weil `HeroSheet.fromJson` Altdaten
// schon beim Laden umstellt; Aufrufer erreichen es weiterhin ueber diese Datei.
export 'package:dsa_heldenverwaltung/domain/combat_config/inventar_verweise.dart'
    show
        weaponRef,
        armorRef,
        projectileRef,
        offhandRef,
        weaponIdRef,
        armorIdRef,
        projectileIdRef,
        offhandIdRef;

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
        sourceRef: verweisFuerWaffe(slot).ref,
        istAusgeruestet: true,
        isMagisch: slot.isArtifact,
        magischDescription: slot.artifactDescription,
        isGeweiht: slot.isGeweiht,
        geweihtDescription: slot.geweihtDescription,
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
            sourceRef: verweisFuerGeschoss(slot, proj).ref,
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
        sourceRef: verweisFuerRuestung(piece).ref,
        istAusgeruestet: piece.isActive,
        isMagisch: piece.isArtifact,
        magischDescription: piece.artifactDescription,
        isGeweiht: piece.isGeweiht,
        geweihtDescription: piece.geweihtDescription,
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
        sourceRef: verweisFuerNebenhand(equipment).ref,
        istAusgeruestet: true,
        isMagisch: equipment.isArtifact,
        magischDescription: equipment.artifactDescription,
        isGeweiht: equipment.isGeweiht,
        geweihtDescription: equipment.geweihtDescription,
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
/// Zugeordnet wird ueber die Slot-ID (`inventar_verweise.dart`), sodass
/// gleichnamige Exemplare unabhaengig bleiben und Umbenennen nichts verliert.
/// Eintraege mit Namensverweis aus Altdaten finden ihren Slot ueber den
/// Namen, in Listenreihenfolge, und tragen danach den ID-Verweis.
List<HeroInventoryEntry> reconcileInventoryWithCombat(
  List<HeroInventoryEntry> existing,
  CombatConfig config,
) {
  final preservedEntries = existing
      .where((entry) => !_isCombatLinkedInventoryEntry(entry))
      .toList(growable: false);

  // Kopie der verlinkten Eintraege, aus der gefundene Matches entfernt werden
  final unmatched = existing.where(_isCombatLinkedInventoryEntry).toList();

  final expected = buildExpectedLinkedEntries(config);
  final verweise = erwarteteVerweise(config);
  final merged = <HeroInventoryEntry>[];

  for (var i = 0; i < expected.length; i++) {
    final expectedEntry = expected[i];
    final ref = expectedEntry.sourceRef!;
    final altRef = verweise[i].altRef;

    // List-basiertes Matching: ersten Treffer nehmen und aus Pool entfernen;
    // ohne ID-Treffer gilt noch ein Namensverweis aus Altdaten.
    var matchIdx = unmatched.indexWhere((e) => e.sourceRef == ref);
    if (matchIdx < 0 && altRef != ref) {
      matchIdx = unmatched.indexWhere((e) => e.sourceRef == altRef);
    }

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
/// Unbekannte Felder einer neueren App-Version kommen aus [existing]; [base]
/// ist frisch gebaut und kennt keine.
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
    istAusgeruestet: isProjectile
        ? existing.istAusgeruestet
        : base.istAusgeruestet,
    // anzahl: bei Geschossen immer aus CombatConfig (bidirektionaler Sync)
    anzahl: isProjectile ? base.anzahl : existing.anzahl,
    unbekannteFelder: existing.unbekannteFelder,
  );
}

bool _isCombatLinkedInventoryEntry(HeroInventoryEntry entry) {
  return entry.sourceRef != null && isCombatLinkedInventorySource(entry.source);
}

/// Uebernimmt magische und geweihte Markierungen aus verlinkten Inventar-Eintraegen.
///
/// Verarbeitet nur Eintraege mit [HeroInventoryEntry.sourceRef], deren Quelle
/// mit dem Kampf-Tab verknuepft ist. Bei mehrfach gleichen Namen erfolgt das
/// Matching stabil in Listenreihenfolge.
CombatConfig applyLinkedInventoryDetailsToConfig(
  CombatConfig config,
  List<HeroInventoryEntry> entries,
) {
  final weaponEntries = _groupLinkedEntries(entries, InventoryItemSource.waffe);
  final armorEntries = _groupLinkedEntries(
    entries,
    InventoryItemSource.ruestung,
  );
  final offhandEntries = _groupLinkedEntries(
    entries,
    InventoryItemSource.nebenhand,
  );

  final updatedWeaponSlots = config.weaponSlots
      .map((slot) {
        final entry = _takeLinkedEntry(weaponEntries, verweisFuerWaffe(slot));
        return _applyInventoryDetailsToWeapon(slot, entry);
      })
      .toList(growable: false);
  final updatedArmorPieces = config.armor.pieces
      .map((piece) {
        final entry = _takeLinkedEntry(
          armorEntries,
          verweisFuerRuestung(piece),
        );
        return _applyInventoryDetailsToArmor(piece, entry);
      })
      .toList(growable: false);
  final updatedOffhandEntries = config.offhandEquipment
      .map((equipment) {
        final entry = _takeLinkedEntry(
          offhandEntries,
          verweisFuerNebenhand(equipment),
        );
        return _applyInventoryDetailsToOffhand(equipment, entry);
      })
      .toList(growable: false);

  final updatedArmor = config.armor.copyWith(pieces: updatedArmorPieces);
  if (config.weapons.isNotEmpty) {
    return config.copyWith(
      weapons: updatedWeaponSlots,
      armor: updatedArmor,
      offhandEquipment: updatedOffhandEntries,
    );
  }
  return config.copyWith(
    mainWeapon: updatedWeaponSlots.firstOrNull ?? const MainWeaponSlot(),
    armor: updatedArmor,
    offhandEquipment: updatedOffhandEntries,
  );
}

Map<String, List<HeroInventoryEntry>> _groupLinkedEntries(
  List<HeroInventoryEntry> entries,
  InventoryItemSource source,
) {
  final groupedEntries = <String, List<HeroInventoryEntry>>{};
  for (final entry in entries) {
    final ref = entry.sourceRef;
    if (entry.source != source || ref == null) {
      continue;
    }
    groupedEntries.putIfAbsent(ref, () => <HeroInventoryEntry>[]).add(entry);
  }
  return groupedEntries;
}

// Nimmt den Eintrag zum ID-Verweis, sonst zum Namensverweis aus Altdaten.
HeroInventoryEntry? _takeLinkedEntry(
  Map<String, List<HeroInventoryEntry>> groupedEntries,
  SlotVerweis verweis,
) {
  return _takeNextLinkedEntry(groupedEntries, verweis.ref) ??
      _takeNextLinkedEntry(groupedEntries, verweis.altRef);
}

HeroInventoryEntry? _takeNextLinkedEntry(
  Map<String, List<HeroInventoryEntry>> groupedEntries,
  String ref,
) {
  final entries = groupedEntries[ref];
  if (entries == null || entries.isEmpty) {
    return null;
  }
  final nextEntry = entries.removeAt(0);
  if (entries.isEmpty) {
    groupedEntries.remove(ref);
  }
  return nextEntry;
}

MainWeaponSlot _applyInventoryDetailsToWeapon(
  MainWeaponSlot slot,
  HeroInventoryEntry? entry,
) {
  if (entry == null) {
    return slot;
  }
  return slot.copyWith(
    isArtifact: entry.isMagisch,
    artifactDescription: entry.magischDescription,
    isGeweiht: entry.isGeweiht,
    geweihtDescription: entry.geweihtDescription,
  );
}

ArmorPiece _applyInventoryDetailsToArmor(
  ArmorPiece piece,
  HeroInventoryEntry? entry,
) {
  if (entry == null) {
    return piece;
  }
  return piece.copyWith(
    isArtifact: entry.isMagisch,
    artifactDescription: entry.magischDescription,
    isGeweiht: entry.isGeweiht,
    geweihtDescription: entry.geweihtDescription,
  );
}

OffhandEquipmentEntry _applyInventoryDetailsToOffhand(
  OffhandEquipmentEntry equipment,
  HeroInventoryEntry? entry,
) {
  if (entry == null) {
    return equipment;
  }
  return equipment.copyWith(
    isArtifact: entry.isMagisch,
    artifactDescription: entry.magischDescription,
    isGeweiht: entry.isGeweiht,
    geweihtDescription: entry.geweihtDescription,
  );
}

// ---------------------------------------------------------------------------
// Bidirektionaler Geschoss-Sync: Inventar → CombatConfig
// ---------------------------------------------------------------------------

/// Aktualisiert die Geschossanzahl im [CombatConfig] anhand des Inventar-Eintrags.
///
/// [projectileRef_] ist ein ID-Verweis (`w#{waffenId}|p#{geschossId}`) oder
/// ein Namensverweis aus Altdaten (`w:{Waffe}|p:{Geschoss}`). Nur der
/// ID-Verweis unterscheidet gleichnamige Waffen; der Namensverweis traf
/// immer die erste (Befund ARCH-07-B2).
///
/// Bei unbekanntem Ref oder keinem Treffer wird [config] unveraendert
/// zurueckgegeben.
CombatConfig applyAmmoCountChangeToConfig(
  CombatConfig config,
  String projectileRef_,
  int newCount,
) {
  final treffer = _findeGeschoss(config.weaponSlots, projectileRef_);
  if (treffer == null) return config;
  final (slotIdx, projIdx) = treffer;

  final useWeaponsList = config.weapons.isNotEmpty;
  final slot = config.weaponSlots[slotIdx];
  final profile = slot.rangedProfile;
  final updatedProjectiles = List<RangedProjectile>.from(profile.projectiles);
  updatedProjectiles[projIdx] = profile.projectiles[projIdx].copyWith(
    count: newCount.clamp(0, 9999),
  );

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

/// Sucht Waffen- und Geschossindex zu einem Geschossverweis.
(int, int)? _findeGeschoss(List<MainWeaponSlot> slots, String ref) {
  final idTrennung = ref.indexOf('|p#');
  final istIdVerweis = ref.startsWith('w#') && idTrennung > 2;
  final trennung = istIdVerweis ? idTrennung : ref.indexOf('|p:');
  if (trennung < 2) return null;
  final waffe = ref.substring(2, trennung);
  final geschoss = ref.substring(trennung + 3);
  if (waffe.isEmpty || geschoss.isEmpty) return null;

  final slotIdx = slots.indexWhere(
    (slot) => istIdVerweis ? slot.id == waffe : slot.name.trim() == waffe,
  );
  if (slotIdx < 0 || !slots[slotIdx].isRanged) return null;
  final projIdx = slots[slotIdx].rangedProfile.projectiles.indexWhere(
    (proj) => istIdVerweis ? proj.id == geschoss : proj.name.trim() == geschoss,
  );
  if (projIdx < 0) return null;
  return (slotIdx, projIdx);
}
