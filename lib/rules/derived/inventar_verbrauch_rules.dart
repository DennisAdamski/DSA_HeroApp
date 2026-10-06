// Verbrauch eines Inventarstücks (Trank, Elixier, Verband …).
//
// Mengenmodell nach der ARCH-03-Entscheidung vom 4. Oktober 2026: `menge`
// ist die neue, additive Stückzahl; der Freitext `anzahl` bleibt die
// Darstellung, die die veröffentlichte App liest. Beide werden konsistent
// gehalten, eine unklare Menge wird nie geraten.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

import 'inventar_aenderung_rules.dart';

/// Eindeutige Stückzahl eines Eintrags oder `null`, wenn sie offen ist.
///
/// `menge` hat Vorrang; sonst zählt ein rein ganzzahliger `anzahl`-Text.
int? inventarMenge(HeroInventoryEntry e) =>
    e.menge ?? int.tryParse(e.anzahl.trim());

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
/// `anzahl` folgt nur, wenn sie dieselbe Zahl wie `menge` zeigt oder allein
/// die Menge trägt; ein abweichender Freitext bleibt unangetastet.
HeroInventoryEntry inventarEintragNachVerbrauch(HeroInventoryEntry e) {
  if (!inventarAbbuchbar(e)) {
    throw StateError('Die Menge dieses Gegenstands ist nicht eindeutig.');
  }
  final neu = inventarMenge(e)! - 1;
  final textZahl = int.tryParse(e.anzahl.trim());
  if (e.menge == null) return e.copyWith(anzahl: '$neu');
  return e.copyWith(
    menge: neu,
    anzahl: textZahl == e.menge ? '$neu' : e.anzahl,
  );
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
