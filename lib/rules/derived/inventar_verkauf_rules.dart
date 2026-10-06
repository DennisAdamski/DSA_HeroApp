// Verkaufen aus dem Inventar (ARCH-03, Entscheidung vom 07.10.2026).
//
// Verkauft wird der ganze Gegenstand oder ein Teil des Stapels. Der Erlös
// ist im Dialog frei wählbar, vorbelegt mit dem vollen Wert (Wert pro Stück
// mal Anzahl), und kommt auf den Geldstand. Ein ausgerüsteter Gegenstand
// verlässt dabei auch den Kampfbereich: Waffe, Rüstungsteil und Nebenhand
// samt Slot, Geschosse über den Bestand ihres Slots. Wie überall gehen
// Geschosse nie still verloren: Eine verkaufte Fernkampfwaffe legt ihre
// Geschosse ab, und Pfeile am Bogen bleiben bei 0 stehen.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfgegenstand_ablegen_rules.dart';

/// Höchstens verkaufbare Stückzahl von [e]; eine offene Menge gilt als ein
/// Stück (der ganze Eintrag).
int verkaufbareStueckzahl(HeroInventoryEntry e) {
  return wirksameInventarMenge(e) ?? 1;
}

/// Vorgeschlagener Erlös in Kreuzern für [anzahl] Stück von [e]: der volle
/// Wert pro Stück.
int verkaufsvorschlagKreuzer(HeroInventoryEntry e, int anzahl) {
  return e.wertSilber * anzahl * dsaKreuzerPerSilber;
}

/// Verkauft [anzahl] Stück des angezeigten Gegenstands [angezeigt] für
/// [erloesKreuzer] Kreuzer.
///
/// Der Erlös kommt auf den Geldstand. Unverknüpft sinkt die Menge, der
/// letzte Rest entfernt den Eintrag. Verknüpft siehe Dateikopf.
///
/// Wirft einen [StateError], wenn der Eintrag inzwischen geändert wurde,
/// [anzahl] nicht passt, der Erlös negativ oder der Geldstand nicht lesbar
/// ist oder der Kampfbereich die Entnahme nicht zulässt (letzte Waffe).
HeroSheet mitVerkauftemGegenstand(
  HeroSheet held,
  HeroInventoryEntry angezeigt, {
  required int anzahl,
  required int erloesKreuzer,
  required String Function() neueId,
}) {
  final index = findeInventarEintragZurAenderung(
    held.inventoryEntries,
    angezeigt,
  );
  if (index < 0) {
    throw StateError('Der Gegenstand wurde inzwischen geändert oder entfernt.');
  }
  final eintrag = held.inventoryEntries[index];
  final hoechstens = verkaufbareStueckzahl(eintrag);
  if (hoechstens < 1) {
    throw StateError('Von diesem Gegenstand ist nichts mehr da.');
  }
  if (anzahl < 1 || anzahl > hoechstens) {
    throw StateError('Verkaufen lassen sich 1 bis $hoechstens Stück.');
  }
  if (erloesKreuzer < 0) {
    throw StateError('Der Erlös kann nicht negativ sein.');
  }
  final mitGeld = mitDukatenSchritt(held, erloesKreuzer);
  final verknuepft =
      eintrag.sourceRef != null &&
      isCombatLinkedInventorySource(eintrag.source);
  if (!verknuepft) {
    return _ohneStueck(mitGeld, index, eintrag, hoechstens - anzahl);
  }
  if (eintrag.source == InventoryItemSource.geschoss) {
    return _ohneGeschosse(mitGeld, index, eintrag, hoechstens - anzahl);
  }
  return _ohneAusgeruestetes(mitGeld, eintrag, neueId);
}

// Unverknüpft: Rest als Menge, ohne Rest fällt der Eintrag weg.
HeroSheet _ohneStueck(
  HeroSheet held,
  int index,
  HeroInventoryEntry eintrag,
  int rest,
) {
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries);
  if (rest > 0) {
    eintraege[index] = mitInventarMenge(eintrag, rest);
  } else {
    eintraege.removeAt(index);
  }
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
  );
}

// Geschoss am Bogen: Der Slot führt den Bestand, auch bei 0 bleibt er.
HeroSheet _ohneGeschosse(
  HeroSheet held,
  int index,
  HeroInventoryEntry eintrag,
  int rest,
) {
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries)
    ..[index] = mitInventarMenge(eintrag, rest);
  final verweis = eintrag.slotRef ?? eintrag.sourceRef!;
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
    combatConfig: applyAmmoCountChangeToConfig(
      held.combatConfig,
      verweis,
      rest,
    ),
  );
}

// Ausgerüstete Waffe, Rüstung oder Nebenhand: Slot ganz entfernen, Eintrag
// gleich mit; die Geschosse einer Fernkampfwaffe werden abgelegt.
HeroSheet _ohneAusgeruestetes(
  HeroSheet held,
  HeroInventoryEntry eintrag,
  String Function() neueId,
) {
  final kampf = held.combatConfig;
  final slotRef = eintrag.slotRef ?? '';
  const ganz = KampfgegenstandEntfernen.ganzEntfernen;
  final HeroSheet ohneSlot;
  if (slotRef.startsWith('w#')) {
    final waffe = _mitId(kampf.weaponSlots, slotRef.substring(2), (w) => w.id);
    ohneSlot = ohneWaffeImKampf(held, waffe, wie: ganz, neueId: neueId);
  } else if (slotRef.startsWith('a#')) {
    final id = slotRef.substring(2);
    final teil = _mitId(kampf.armor.pieces, id, (t) => t.id);
    ohneSlot = ohneRuestungsteilImKampf(held, teil, wie: ganz, neueId: neueId);
  } else if (slotRef.startsWith('oh#')) {
    final id = slotRef.substring(3);
    final teil = _mitId(kampf.offhandEquipment, id, (t) => t.id);
    ohneSlot = ohneNebenhandteilImKampf(held, teil, wie: ganz, neueId: neueId);
  } else {
    throw StateError('Der zugehörige Eintrag im Kampfbereich fehlt.');
  }
  // Den verwaisten Eintrag verwirft auch der Abgleich; hier gleich.
  final eintraege = ohneSlot.inventoryEntries
      .where((e) => e.slotRef != eintrag.slotRef)
      .toList(growable: false);
  return ohneSlot.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
  );
}

// Slot mit der ID [id] in [slots]; fehlt er, ein [StateError].
T _mitId<T>(List<T> slots, String id, String Function(T) idVon) {
  for (final slot in slots) {
    if (idVon(slot) == id) return slot;
  }
  throw StateError('Der zugehörige Eintrag im Kampfbereich fehlt.');
}

/// Ob [e] gerade im Kampfbereich ausgerüstet ist; der Verkaufsdialog weist
/// dann darauf hin.
bool verkaufEntferntAusKampf(HeroInventoryEntry e) {
  return e.sourceRef != null &&
      isCombatLinkedInventorySource(e.source) &&
      e.source != InventoryItemSource.geschoss;
}
