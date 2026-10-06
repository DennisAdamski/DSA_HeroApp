// Verbrauch eines Inventarstücks (Trank, Elixier, Verband …).
//
// Mengenmodell nach der ARCH-03-Entscheidung vom 4. Oktober 2026, Lesart nach
// der vom 6. Oktober 2026 (`inventar_menge_rules.dart`): eine unklare Menge
// wird nie geraten, eine Abweichung durch eine ältere Version rechnet mit
// `anzahl`.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

import 'inventar_aenderung_rules.dart';
import 'inventar_menge_rules.dart';

/// Eindeutige Stückzahl eines Eintrags oder `null`, wenn sie offen ist.
///
/// Siehe [wirksameInventarMenge].
int? inventarMenge(HeroInventoryEntry e) => wirksameInventarMenge(e);

/// Ob ein Eintrag im Gefecht verbraucht werden kann.
///
/// Mit dem Kampf verknüpfte Einträge (Waffe, Rüstung, Geschoss) haben eigene
/// Schreibwege und werden hier nie abgebucht.
bool inventarAbbuchbar(HeroInventoryEntry e) {
  final menge = inventarMenge(e);
  return !isCombatLinkedInventorySource(e.source) && menge != null && menge > 0;
}

/// Derselbe Eintrag mit einem Stück weniger.
///
/// Schreibt Menge und Text gemeinsam; eine Abweichung ist danach aufgelöst.
HeroInventoryEntry inventarEintragNachVerbrauch(HeroInventoryEntry e) {
  if (!inventarAbbuchbar(e)) {
    throw StateError('Die Menge dieses Gegenstands ist nicht eindeutig.');
  }
  return mitInventarMenge(e, inventarMenge(e)! - 1);
}

/// Bucht ein Stück des angezeigten Gegenstands im gespeicherten Helden ab.
///
/// Trifft den Eintrag über seinen Inhalt (`mitGeaendertemInventarEintrag`);
/// wurde er inzwischen geändert, entsteht ein [StateError] statt einer
/// Abbuchung am falschen Gegenstand. Bei 0 bleibt der Eintrag bestehen.
HeroSheet mitVerbrauchtemInventarEintrag(
  HeroSheet held,
  HeroInventoryEntry angezeigt,
) => mitGeaendertemInventarEintrag(
  held,
  angezeigt,
  inventarEintragNachVerbrauch(angezeigt),
);
