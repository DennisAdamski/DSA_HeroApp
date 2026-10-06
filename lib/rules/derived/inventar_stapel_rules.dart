// Stapel teilen (ARCH-03, Entscheidung vom 06.10.2026).
//
// Ein Stapel ist ein Gegenstand mit einer Instanz-ID und einer Menge. Teilen
// spaltet einen zweiten, unverknüpften Stapel mit neuer ID ab, etwa Pfeile
// vom Bogen in den Rucksack. Ein verknüpftes Geschoss gibt die verbleibende
// Menge an seinen eigenen Slot weiter; der Slot führt sie weiterhin.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
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

// ---------------------------------------------------------------------------
// Zusammenführen (ARCH-03, Entscheidung vom 07.10.2026)
// ---------------------------------------------------------------------------

/// Grund, warum sich [quelle] nicht in [ziel] zusammenführen lässt, sonst
/// `null`.
///
/// Verlangt denselben Namen (ohne Groß-/Kleinschreibung) und Typ, gleiche
/// Markierungen (magisch, geweiht samt Beschreibung) und gleiche
/// Modifikatoren; Ort, Beschreibung und übrige Angaben kommen vom Ziel.
/// Beide brauchen eine eindeutige Menge. Die Quelle darf nicht mit dem Kampf
/// verknüpft sein; ein verknüpftes Ziel nur als Geschoss, dessen Slot die
/// Menge führt. Abenteuerbeute ist kein Ziel: Das Zurücknehmen des
/// Abenteuers entfernte sonst auch die hinzugefügten Stücke.
String? zusammenfuehrenGesperrt(
  HeroInventoryEntry quelle,
  HeroInventoryEntry ziel,
) {
  if (identical(quelle, ziel) ||
      (quelle.instanzId != null && quelle.instanzId == ziel.instanzId)) {
    return 'Ein Stapel lässt sich nicht mit sich selbst zusammenführen.';
  }
  if (wirksameInventarMenge(quelle) == null ||
      wirksameInventarMenge(ziel) == null) {
    return 'Beide Stapel brauchen eine Zahl als Anzahl.';
  }
  if (_mitKampfVerknuepft(quelle)) {
    return 'Ausgerüstetes zuerst im Kampfbereich ablegen.';
  }
  if (_mitKampfVerknuepft(ziel) &&
      ziel.source != InventoryItemSource.geschoss) {
    return 'Ausgerüstete Waffen und Rüstung sind Einzelstücke.';
  }
  if (ziel.source == InventoryItemSource.abenteuer) {
    return 'Abenteuerbeute nimmt keine weiteren Stücke auf.';
  }
  final gleich =
      _name(quelle) == _name(ziel) &&
      quelle.itemType == ziel.itemType &&
      quelle.isMagisch == ziel.isMagisch &&
      quelle.magischDescription.trim() == ziel.magischDescription.trim() &&
      quelle.isGeweiht == ziel.isGeweiht &&
      quelle.geweihtDescription.trim() == ziel.geweihtDescription.trim() &&
      _modifikatoren(quelle) == _modifikatoren(ziel);
  if (!gleich) {
    return 'Nur gleiche Gegenstände lassen sich zusammenführen.';
  }
  return null;
}

/// Stapel in [eintraege], in die sich [quelle] zusammenführen lässt.
List<HeroInventoryEntry> zusammenfuehrbareZiele(
  List<HeroInventoryEntry> eintraege,
  HeroInventoryEntry quelle,
) {
  return <HeroInventoryEntry>[
    for (final ziel in eintraege)
      if (zusammenfuehrenGesperrt(quelle, ziel) == null) ziel,
  ];
}

/// Führt den angezeigten Stapel [quelle] in den angezeigten Stapel [ziel]
/// zusammen: Das Ziel bekommt die Summe beider Mengen und behält seine
/// übrigen Angaben, die Quelle verschwindet. Gemerkte Kampfwerte eines
/// abgelegten Stapels bleiben erhalten. Ist das Ziel ein verknüpftes
/// Geschoss, steigt der Bestand an seinem Slot.
///
/// Wirft einen [StateError], wenn [zusammenfuehrenGesperrt] einen Grund
/// nennt oder ein Stapel inzwischen geändert oder entfernt wurde.
HeroSheet mitZusammengefuehrtemStapel(
  HeroSheet held,
  HeroInventoryEntry quelle,
  HeroInventoryEntry ziel,
) {
  final eintraege = held.inventoryEntries;
  final quellIndex = findeInventarEintragZurAenderung(eintraege, quelle);
  final zielIndex = findeInventarEintragZurAenderung(eintraege, ziel);
  if (quellIndex < 0 || zielIndex < 0 || quellIndex == zielIndex) {
    throw StateError('Ein Stapel wurde inzwischen geändert oder entfernt.');
  }
  final q = eintraege[quellIndex];
  final z = eintraege[zielIndex];
  final grund = zusammenfuehrenGesperrt(q, z);
  if (grund != null) {
    throw StateError(grund);
  }
  final summe = wirksameInventarMenge(q)! + wirksameInventarMenge(z)!;
  final zusammen = mitInventarMenge(
    z.copyWith(
      abgelegt: z.abgelegt ?? (_mitKampfVerknuepft(z) ? null : q.abgelegt),
    ),
    summe,
  );
  final neu = List<HeroInventoryEntry>.of(eintraege)..[zielIndex] = zusammen;
  neu.removeAt(quellIndex);
  final verweis = z.slotRef ?? z.sourceRef;
  final istGeschoss = _mitKampfVerknuepft(z) && verweis != null;
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(neu),
    combatConfig: istGeschoss
        ? applyAmmoCountChangeToConfig(held.combatConfig, verweis, summe)
        : held.combatConfig,
  );
}

// Mit einem Kampf-Slot verknüpft: Kampfquelle und Verweis.
bool _mitKampfVerknuepft(HeroInventoryEntry e) {
  return e.sourceRef != null && isCombatLinkedInventorySource(e.source);
}

// Name zum Vergleich, ohne Leerraum am Rand und Groß-/Kleinschreibung.
String _name(HeroInventoryEntry e) => e.gegenstand.trim().toLowerCase();

// Modifikatoren als vergleichbarer Text.
String _modifikatoren(HeroInventoryEntry e) {
  return stableContentHash(<String, Object?>{
    'm': e.modifiers.map((m) => m.toJson()).toList(),
  });
}
