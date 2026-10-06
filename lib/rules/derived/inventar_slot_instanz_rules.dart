// Verweis Slot → Instanz (ARCH-03).
//
// Jeder verknüpfte Kampf-Slot (Waffe, Geschoss, Rüstungsstück, Nebenhand)
// merkt sich in `inventarInstanzId` die Instanz-ID seines Inventareintrags.
// Der Abgleich ordnet darüber zuerst zu (`inventory_sync_rules.dart`); das
// ist die Grundlage dafür, dass Ablegen und Ausrüsten künftig das Exemplar
// behalten. Der Verweis Eintrag → Slot (`slotRef`) bleibt daneben bestehen.
//
// Gesetzt wird ausschließlich in `HeroActions.saveHero`, nach dem Abgleich
// und der Vergabe der Instanz-IDs, nie beim Laden: Sonst änderten sich die
// Inhalts-Hashes jedes Bestandshelden.

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/inventar_verweise.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Setzt an jedem Slot die Instanz-ID des Eintrags, der per `slotRef` auf
/// ihn verweist.
///
/// [eintraege] ist das bereits abgeglichene Inventar mit vergebenen
/// Instanz-IDs. Ein Slot ohne solchen Eintrag (unbenannt, ohne ID) verliert
/// einen veralteten Verweis. Verweisen mehrere Einträge auf denselben Slot,
/// zählt der erste. Ändert sich nichts, kommt [config] selbst zurück, damit
/// das Speichern ein Fixpunkt bleibt.
CombatConfig bindeSlotsAnInstanzen(
  CombatConfig config,
  List<HeroInventoryEntry> eintraege,
) {
  final bindung = _InstanzBindung(eintraege);
  final waffen = config.weaponSlots.map(bindung.waffe).toList();
  final ruestung = config.armor.pieces.map(bindung.ruestung).toList();
  final nebenhand = config.offhandEquipment.map(bindung.nebenhand).toList();
  if (!bindung.geaendert) {
    return config;
  }
  return config.copyWith(
    weapons: waffen,
    armor: config.armor.copyWith(pieces: ruestung),
    offhandEquipment: nebenhand,
  );
}

/// Instanz-IDs je Slot-Verweis; merkt sich, ob ein Slot sich ändert.
class _InstanzBindung {
  _InstanzBindung(List<HeroInventoryEntry> eintraege) {
    for (final eintrag in eintraege) {
      final slotRef = eintrag.slotRef;
      final instanzId = eintrag.instanzId;
      final verknuepft =
          eintrag.sourceRef != null &&
          isCombatLinkedInventorySource(eintrag.source);
      if (!verknuepft || slotRef == null || instanzId == null) continue;
      _instanzJeSlot.putIfAbsent(slotRef, () => instanzId);
    }
  }

  final Map<String, String> _instanzJeSlot = {};

  /// Ob mindestens ein Slot einen anderen Verweis bekommen hat.
  bool geaendert = false;

  /// Instanz-ID zum Slot hinter [verweis], leer ohne Eintrag.
  String _instanzFuer(SlotVerweis verweis) {
    final slotRef = verweis.slotRef;
    return slotRef == null ? '' : _instanzJeSlot[slotRef] ?? '';
  }

  /// Ob sich der Verweis von [bisher] zu [neu] ändert; merkt es sich.
  bool _aendert(String bisher, String neu) {
    final aendert = bisher != neu;
    geaendert |= aendert;
    return aendert;
  }

  /// [slot] samt Geschossen mit gebundener Instanz.
  MainWeaponSlot waffe(MainWeaponSlot slot) {
    var ergebnis = slot;
    final geschosse = slot.rangedProfile.projectiles;
    final neueGeschosse = <RangedProjectile>[
      for (final geschoss in geschosse) _geschoss(slot, geschoss),
    ];
    final geschossGeaendert = Iterable<int>.generate(geschosse.length)
        .any((i) => !identical(geschosse[i], neueGeschosse[i]));
    if (geschossGeaendert) {
      final profil = slot.rangedProfile.copyWith(projectiles: neueGeschosse);
      ergebnis = ergebnis.copyWith(rangedProfile: profil);
    }
    final instanz = _instanzFuer(verweisFuerWaffe(slot));
    if (_aendert(slot.inventarInstanzId, instanz)) {
      ergebnis = ergebnis.copyWith(inventarInstanzId: instanz);
    }
    return ergebnis;
  }

  // [geschoss] der Waffe [slot] mit gebundener Instanz.
  RangedProjectile _geschoss(MainWeaponSlot slot, RangedProjectile geschoss) {
    final instanz = _instanzFuer(verweisFuerGeschoss(slot, geschoss));
    if (!_aendert(geschoss.inventarInstanzId, instanz)) {
      return geschoss;
    }
    return geschoss.copyWith(inventarInstanzId: instanz);
  }

  /// [teil] mit gebundener Instanz.
  ArmorPiece ruestung(ArmorPiece teil) {
    final instanz = _instanzFuer(verweisFuerRuestung(teil));
    if (!_aendert(teil.inventarInstanzId, instanz)) {
      return teil;
    }
    return teil.copyWith(inventarInstanzId: instanz);
  }

  /// [teil] mit gebundener Instanz.
  OffhandEquipmentEntry nebenhand(OffhandEquipmentEntry teil) {
    final instanz = _instanzFuer(verweisFuerNebenhand(teil));
    if (!_aendert(teil.inventarInstanzId, instanz)) {
      return teil;
    }
    return teil.copyWith(inventarInstanzId: instanz);
  }
}

/// JSON-Schlüssel des Verweises Slot → Instanz.
const String kInventarInstanzSchluessel = 'inventarInstanzId';

/// [json] eines Slots ohne den Verweis auf die Inventarinstanz, auf jeder
/// Ebene (auch an den Geschossen einer Waffe).
///
/// Für Fingerabdrücke, die ein Waffen- oder Teilprofil binden: Den Verweis
/// setzt allein das Speichern, er beschreibt kein Profil. Ohne ihn verlöre
/// etwa ein gebundener Ladezustand beim ersten Speichern seine Waffe.
Map<String, dynamic> ohneInstanzverweise(Map<String, dynamic> json) {
  return _ohneInstanzverweis(json) as Map<String, dynamic>;
}

// Entfernt den Instanzverweis rekursiv aus Maps und Listen.
Object? _ohneInstanzverweis(Object? wert) {
  if (wert is Map) {
    return <String, dynamic>{
      for (final eintrag in wert.entries)
        if (eintrag.key != kInventarInstanzSchluessel)
          eintrag.key.toString(): _ohneInstanzverweis(eintrag.value),
    };
  }
  if (wert is List) {
    return wert.map(_ohneInstanzverweis).toList(growable: false);
  }
  return wert;
}
