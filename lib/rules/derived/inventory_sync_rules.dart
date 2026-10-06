import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/inventar_verweise.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';

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
        offhandIdRef,
        istIdVerweis;

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

    final waffenVerweis = verweisFuerWaffe(slot);
    result.add(
      HeroInventoryEntry(
        gegenstand: name,
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.waffe,
        sourceRef: waffenVerweis.sourceRef,
        slotRef: waffenVerweis.slotRef,
        istAusgeruestet: true,
        isMagisch: slot.isArtifact,
        magischDescription: slot.artifactDescription,
        isGeweiht: slot.isGeweiht,
        geweihtDescription: slot.geweihtDescription,
      ),
    );

    if (slot.fuehrtGeschosse) {
      for (final proj in slot.rangedProfile.projectiles) {
        final projName = proj.name.trim();
        if (projName.isEmpty) continue;
        final geschossVerweis = verweisFuerGeschoss(slot, proj);
        result.add(
          HeroInventoryEntry(
            gegenstand: projName,
            anzahl: proj.count.toString(),
            itemType: InventoryItemType.verbrauchsgegenstand,
            source: InventoryItemSource.geschoss,
            sourceRef: geschossVerweis.sourceRef,
            slotRef: geschossVerweis.slotRef,
            istAusgeruestet: false,
          ),
        );
      }
    }
  }

  for (final piece in config.armor.pieces) {
    final name = piece.name.trim();
    if (name.isEmpty) continue;
    final ruestungsVerweis = verweisFuerRuestung(piece);
    result.add(
      HeroInventoryEntry(
        gegenstand: name,
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.ruestung,
        sourceRef: ruestungsVerweis.sourceRef,
        slotRef: ruestungsVerweis.slotRef,
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
    final nebenhandVerweis = verweisFuerNebenhand(equipment);
    result.add(
      HeroInventoryEntry(
        gegenstand: name,
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.nebenhand,
        sourceRef: nebenhandVerweis.sourceRef,
        slotRef: nebenhandVerweis.slotRef,
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
/// Zugeordnet wird ueber den ID-Verweis `slotRef` (`inventar_verweise.dart`),
/// sodass gleichnamige Exemplare unabhaengig bleiben und Umbenennen nichts
/// verliert. Jeder Eintrag traegt danach beide Verweise; die Reihenfolge
/// bleibt die, ueber die die veroeffentlichte App gleichnamige Eintraege
/// paart.
List<HeroInventoryEntry> reconcileInventoryWithCombat(
  List<HeroInventoryEntry> existing,
  CombatConfig config,
) {
  final preservedEntries = existing
      .where((entry) => !_isCombatLinkedInventoryEntry(entry))
      .toList(growable: false);

  // Kopie der verlinkten Eintraege, aus der gefundene Matches entfernt werden
  final unmatched = existing.where(_isCombatLinkedInventoryEntry).toList();
  // Eintraege mit Verweis, aber unbekannter Quelle (Befund ARCH-07-B12):
  // Sie bleiben unveraendert stehen und decken ihren Slot ab, damit kein
  // zweiter Eintrag fuer ihn entsteht.
  final fremdVerknuepft = existing.where(_istFremdVerknuepft).toList();

  final expected = buildExpectedLinkedEntries(config);
  final merged = <HeroInventoryEntry>[];

  for (final expectedEntry in expected) {
    // List-basiertes Matching: ersten Treffer nehmen und aus Pool entfernen.
    final matchIdx = _passenderEintrag(unmatched, expectedEntry);

    if (matchIdx >= 0) {
      final existing_ = unmatched.removeAt(matchIdx);
      merged.add(_mergeEntry(base: expectedEntry, existing: existing_));
    } else {
      final fremdIdx = _passenderEintrag(fremdVerknuepft, expectedEntry);
      if (fremdIdx >= 0) {
        fremdVerknuepft.removeAt(fremdIdx);
        continue;
      }
      merged.add(expectedEntry);
    }
  }

  // Verlinkte Eintraege, die nicht mehr erwartet werden, fallen weg (kein append)
  return <HeroInventoryEntry>[...preservedEntries, ...merged];
}

/// Index des Eintrags in [kandidaten], der zu [erwartet] gehoert, oder -1.
///
/// Ein Eintrag mit `slotRef` passt nur ueber diesen. Verweist er auf einen
/// entfernten Slot, faellt er weg, statt ueber den Namen an ein
/// gleichnamiges Exemplar zu wandern (Befund ARCH-07-B2). Ueber den Namen
/// zugeordnet werden nur Eintraege ohne `slotRef`, die zuletzt eine aeltere
/// App-Version gespeichert hat — in Listenreihenfolge wie dort.
int _passenderEintrag(
  List<HeroInventoryEntry> kandidaten,
  HeroInventoryEntry erwartet,
) {
  final slotRef = erwartet.slotRef;
  if (slotRef != null) {
    final perId = kandidaten.indexWhere((entry) => entry.slotRef == slotRef);
    if (perId >= 0) return perId;
  }
  return kandidaten.indexWhere(
    (entry) => entry.slotRef == null && entry.sourceRef == erwartet.sourceRef,
  );
}

/// Aktualisiert [existing] um die Felder, die der Kampf-Slot fuehrt.
///
/// Grundlage ist der bestehende Eintrag, damit jedes Feld, das der Slot
/// nicht kennt, erhalten bleibt — auch Typ und Traeger, die der
/// Inventareditor fuer verknuepfte Eintraege anbietet (Befund ARCH-07-B9),
/// und unbekannte Felder einer neueren App-Version.
///
/// Aus [base] kommen nur die Slot-Felder: Identitaet ([gegenstand],
/// [source], [sourceRef], [slotRef], [itemType]) sowie die Markierungen
/// magisch/geweiht (CombatConfig ist die Quelle der Wahrheit). Bei
/// Ausruestung kommt [istAusgeruestet] aus dem Slot, bei Geschossen
/// [anzahl] (bidirektionaler Sync, der Slot fuehrt). Traegt der Eintrag
/// schon eine `menge`, folgt sie mit; neu vergeben wird sie nur beim
/// Speichern (`ueberfuehreInventarMengen`), damit der Abgleich auf
/// Bestandsdaten ein Fixpunkt bleibt.
HeroInventoryEntry _mergeEntry({
  required HeroInventoryEntry base,
  required HeroInventoryEntry existing,
}) {
  final isProjectile = base.source == InventoryItemSource.geschoss;

  final merged = existing.copyWith(
    gegenstand: base.gegenstand,
    itemType: base.itemType,
    source: base.source,
    sourceRef: base.sourceRef,
    slotRef: base.slotRef,
    isMagisch: base.isMagisch,
    magischDescription: base.magischDescription,
    isGeweiht: base.isGeweiht,
    geweihtDescription: base.geweihtDescription,
    istAusgeruestet: isProjectile ? null : base.istAusgeruestet,
    anzahl: isProjectile ? base.anzahl : null,
  );
  if (!isProjectile || existing.menge == null) {
    return merged;
  }
  return mitInventarMenge(merged, int.parse(base.anzahl));
}

/// Verweist [entry] auf einen Slot, traegt aber eine Quelle, die diese
/// Version nicht kennt (Rohwert in `unbekannteEnumWerte`)?
///
/// Solche Eintraege gelten mit dem Ersatzwert `manuell` als manuell und
/// bleiben unberuehrt; zugleich decken sie ihren Slot ab.
bool _istFremdVerknuepft(HeroInventoryEntry entry) {
  return entry.unbekannteEnumWerte.containsKey('source') &&
      (entry.sourceRef != null || entry.slotRef != null);
}

bool _isCombatLinkedInventoryEntry(HeroInventoryEntry entry) {
  return entry.sourceRef != null && isCombatLinkedInventorySource(entry.source);
}

/// Uebernimmt magische und geweihte Markierungen aus verlinkten Inventar-Eintraegen.
///
/// Verarbeitet nur Eintraege mit [HeroInventoryEntry.sourceRef], deren Quelle
/// mit dem Kampf-Tab verknuepft ist. Zugeordnet wird wie im Abgleich: ueber
/// `slotRef`, sonst — nur fuer Eintraege ohne `slotRef` — ueber den Namen,
/// stabil in Listenreihenfolge.
CombatConfig applyLinkedInventoryDetailsToConfig(
  CombatConfig config,
  List<HeroInventoryEntry> entries,
) {
  final weaponEntries = _VerknuepfteEintraege(
    entries,
    InventoryItemSource.waffe,
  );
  final armorEntries = _VerknuepfteEintraege(
    entries,
    InventoryItemSource.ruestung,
  );
  final offhandEntries = _VerknuepfteEintraege(
    entries,
    InventoryItemSource.nebenhand,
  );

  final updatedWeaponSlots = config.weaponSlots
      .map((slot) {
        final entry = weaponEntries.nimm(verweisFuerWaffe(slot));
        return _applyInventoryDetailsToWeapon(slot, entry);
      })
      .toList(growable: false);
  final updatedArmorPieces = config.armor.pieces
      .map((piece) {
        final entry = armorEntries.nimm(verweisFuerRuestung(piece));
        return _applyInventoryDetailsToArmor(piece, entry);
      })
      .toList(growable: false);
  final updatedOffhandEntries = config.offhandEquipment
      .map((equipment) {
        final entry = offhandEntries.nimm(verweisFuerNebenhand(equipment));
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

/// Verknuepfte Eintraege einer Quelle, zum Nachschlagen je Slot.
///
/// Eintraege mit `slotRef` stehen nur unter diesem, Eintraege ohne unter
/// ihrem Namensverweis. Jeder Eintrag wird hoechstens einmal vergeben.
class _VerknuepfteEintraege {
  _VerknuepfteEintraege(
    List<HeroInventoryEntry> entries,
    InventoryItemSource source,
  ) {
    for (final entry in entries) {
      final ref = entry.sourceRef;
      if (entry.source != source || ref == null) continue;
      final slotRef = entry.slotRef;
      final ziel = slotRef == null ? _nachName : _nachSlot;
      ziel.putIfAbsent(slotRef ?? ref, () => <HeroInventoryEntry>[]).add(entry);
    }
  }

  final Map<String, List<HeroInventoryEntry>> _nachSlot = {};
  final Map<String, List<HeroInventoryEntry>> _nachName = {};

  /// Naechster freier Eintrag zum Slot hinter [verweis], sonst `null`.
  HeroInventoryEntry? nimm(SlotVerweis verweis) {
    final slotRef = verweis.slotRef;
    final perId = slotRef == null ? null : _naechster(_nachSlot, slotRef);
    return perId ?? _naechster(_nachName, verweis.sourceRef);
  }

  // Entnimmt den ersten Eintrag unter [schluessel].
  static HeroInventoryEntry? _naechster(
    Map<String, List<HeroInventoryEntry>> gruppen,
    String schluessel,
  ) {
    final eintraege = gruppen[schluessel];
    if (eintraege == null || eintraege.isEmpty) {
      return null;
    }
    return eintraege.removeAt(0);
  }
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
/// [projectileRef_] ist ein ID-Verweis (`w#{waffenId}|p#{geschossId}`,
/// also `HeroInventoryEntry.slotRef`) oder ein Namensverweis
/// (`w:{Waffe}|p:{Geschoss}`). Nur der ID-Verweis unterscheidet gleichnamige
/// Waffen; der Namensverweis trifft immer die erste (Befund ARCH-07-B2).
/// Aufrufer uebergeben deshalb `slotRef ?? sourceRef`.
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
  if (slotIdx < 0 || !slots[slotIdx].fuehrtGeschosse) return null;
  final projIdx = slots[slotIdx].rangedProfile.projectiles.indexWhere(
    (proj) => istIdVerweis ? proj.id == geschoss : proj.name.trim() == geschoss,
  );
  if (projIdx < 0) return null;
  return (slotIdx, projIdx);
}
