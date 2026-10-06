// Stapel teilen (ARCH-03, Entscheidung vom 06.10.2026).
//
// Ein Stapel ist ein Gegenstand mit einer Instanz-ID und einer Menge. Teilen
// spaltet einen zweiten, unverknüpften Stapel mit neuer ID ab, etwa Pfeile
// vom Bogen in den Rucksack. Ein verknüpftes Geschoss gibt die verbleibende
// Menge an seinen eigenen Slot weiter; der Slot führt sie weiterhin.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';

/// Ob sich [e] teilen lässt.
///
/// Verlangt eine eindeutige Menge ab 2. Mit dem Kampf verknüpfte
/// Einzelstücke (Waffe, Rüstung, Nebenhand) sind je ein Slot und lassen sich
/// nicht teilen, verknüpfte Geschosse schon.
bool stapelTeilbar(HeroInventoryEntry e) {
  final menge = wirksameInventarMenge(e);
  if (menge == null || menge < 2) {
    return false;
  }
  final verknuepft =
      e.sourceRef != null && isCombatLinkedInventorySource(e.source);
  return !verknuepft || e.source == InventoryItemSource.geschoss;
}

/// Spaltet vom angezeigten Stapel [angezeigt] [abspalten] Stück ab.
///
/// Der abgespaltene Stapel bekommt die Instanz-ID [neueId] und den Ort
/// [woGetragen]. Alle übrigen Angaben übernimmt er vom gespeicherten Stapel,
/// auch Modifikatoren und Felder neuerer Versionen. Er ist manuell, ohne
/// Kampfverweis und nicht ausgerüstet. Er steht direkt hinter dem Original;
/// das Speichern stellt unverknüpfte Einträge ohnehin vor die verknüpften.
///
/// Wirft einen [StateError], wenn sich der Stapel nicht teilen lässt,
/// [abspalten] nicht zwischen 1 und Menge − 1 liegt oder der Stapel
/// inzwischen geändert oder entfernt wurde.
HeroSheet mitGeteiltemStapel(
  HeroSheet held,
  HeroInventoryEntry angezeigt, {
  required int abspalten,
  required String woGetragen,
  required String neueId,
}) {
  if (!stapelTeilbar(angezeigt)) {
    throw StateError('Dieser Gegenstand lässt sich nicht teilen.');
  }
  final menge = wirksameInventarMenge(angezeigt)!;
  if (abspalten < 1 || abspalten >= menge) {
    throw StateError('Abspalten lassen sich 1 bis ${menge - 1} Stück.');
  }
  final index = findeInventarEintragZurAenderung(
    held.inventoryEntries,
    angezeigt,
  );
  if (index < 0) {
    throw StateError('Der Gegenstand wurde inzwischen geändert oder entfernt.');
  }
  final gespeichert = held.inventoryEntries[index];
  final rest = mitInventarMenge(gespeichert, menge - abspalten);
  final abgespalten = mitInventarMenge(
    gespeichert.copyWith(
      instanzId: neueId,
      source: InventoryItemSource.manuell,
      sourceRef: null,
      slotRef: null,
      istAusgeruestet: false,
      woGetragen: woGetragen.trim(),
    ),
    abspalten,
  );
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries)
    ..[index] = rest
    ..insert(index + 1, abgespalten);

  final verweis = gespeichert.slotRef ?? gespeichert.sourceRef;
  final istGeschoss =
      gespeichert.source == InventoryItemSource.geschoss && verweis != null;
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
    combatConfig: istGeschoss
        ? applyAmmoCountChangeToConfig(
            held.combatConfig,
            verweis,
            menge - abspalten,
          )
        : held.combatConfig,
  );
}
