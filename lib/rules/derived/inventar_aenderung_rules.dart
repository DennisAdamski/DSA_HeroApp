// Sofortänderungen im Inventar-Tab: Gegenstand löschen und Geldstand
// (ARCH-05).
//
// Beide arbeiten auf dem gespeicherten Helden. Inventareinträge haben keine
// eigene ID; ein Eintrag wird deshalb über seinen Inhalt wiedergefunden,
// nicht über seine Position, die sich durch einen anderen Schreibweg
// verschoben haben kann.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';

/// Position des ersten Eintrags in [eintraege], der inhaltlich [gesucht]
/// gleicht, sonst `-1`.
///
/// Verglichen wird das vollständige JSON einschließlich unbekannter Felder.
/// Zwei gleiche Einträge sind nicht unterscheidbar; das Entfernen des ersten
/// ergibt dann dieselbe Liste wie das des zweiten.
int findeGleichenInventarEintrag(
  List<HeroInventoryEntry> eintraege,
  HeroInventoryEntry gesucht,
) {
  final gesuchterHash = stableContentHash(gesucht.toJson());
  for (var index = 0; index < eintraege.length; index++) {
    if (stableContentHash(eintraege[index].toJson()) == gesuchterHash) {
      return index;
    }
  }
  return -1;
}

/// Entfernt den angezeigten Gegenstand [angezeigt] aus dem gespeicherten
/// Inventar.
///
/// Nur die Inventareinträge ändern sich; die Kampfkonfiguration samt
/// Geschossmengen bleibt, wie sie gespeichert ist. Mit dem Kampf verknüpfte
/// Einträge entstehen und verschwinden über ihren Slot und lassen sich hier
/// nicht löschen. Wurde der Gegenstand inzwischen geändert oder entfernt,
/// wirft die Funktion einen [StateError], statt einen anderen zu treffen.
HeroSheet ohneInventarEintrag(HeroSheet held, HeroInventoryEntry angezeigt) {
  final verknuepft =
      angezeigt.sourceRef != null &&
      isCombatLinkedInventorySource(angezeigt.source);
  if (verknuepft) {
    throw StateError(
      'Mit dem Kampf verknüpfte Gegenstände werden im Kampf-Tab entfernt.',
    );
  }
  final index = findeGleichenInventarEintrag(held.inventoryEntries, angezeigt);
  if (index < 0) {
    throw StateError('Der Gegenstand wurde inzwischen geändert oder entfernt.');
  }
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries)
    ..removeAt(index);
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
  );
}

/// Setzt den Geldstand auf den eingegebenen Text [wert].
///
/// Ein eingetippter Gesamtbetrag ist bewusst absolut. Gleicht er dem
/// gespeicherten Stand, kommt [held] selbst zurück, damit nichts gespeichert
/// wird.
HeroSheet mitDukaten(HeroSheet held, String wert) {
  final neu = wert.trim();
  if (neu == held.dukaten.trim()) {
    return held;
  }
  return held.copyWith(dukaten: neu);
}

/// Verschiebt den gespeicherten Geldstand um [deltaKreuzer].
///
/// Gerechnet wird ab dem gespeicherten Text, damit jeder schnelle Klick auf
/// einen Münzknopf zählt. Ist er nicht als Betrag lesbar, wirft die Funktion
/// einen [StateError], statt einen falschen Wert zu schreiben.
HeroSheet mitDukatenSchritt(HeroSheet held, int deltaKreuzer) {
  final neu = adjustDsaCurrencyText(
    rawValue: held.dukaten,
    deltaKreuzer: deltaKreuzer,
  );
  if (neu == null) {
    throw StateError(
      'Der gespeicherte Dukatenwert ist nicht numerisch lesbar.',
    );
  }
  return mitDukaten(held, neu);
}
