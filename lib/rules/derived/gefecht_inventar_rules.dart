import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

import 'inventar_verbrauch_rules.dart';

/// Gruppen der Inventarsicht im Gefecht, nach Griffnähe geordnet.
enum GefechtsInventargruppe { verbrauch, amKoerper, gepaeck, begleiter }

/// Sichtbarer Name einer Gruppe.
String gefechtsInventargruppenName(GefechtsInventargruppe g) => switch (g) {
  GefechtsInventargruppe.verbrauch => 'Verbrauchsgüter',
  GefechtsInventargruppe.amKoerper => 'Am Körper',
  GefechtsInventargruppe.gepaeck => 'Gepäck',
  GefechtsInventargruppe.begleiter => 'Beim Begleiter',
};

/// Ein Inventarstück mit seiner Einordnung für das Gefecht.
class GefechtsInventarposten {
  /// [traeger] nennt den Begleiter, wenn er das Stück trägt.
  const GefechtsInventarposten({
    required this.eintrag,
    required this.gruppe,
    required this.menge,
    required this.benutzbar,
    this.traeger,
  });
  final HeroInventoryEntry eintrag;
  final GefechtsInventargruppe gruppe;
  final int? menge;

  /// Verbrauchsgüter und magische Gegenstände ohne Kampfverknüpfung.
  final bool benutzbar;
  final String? traeger;
}

/// Ordnet das Inventar für die Gefechtsansicht.
///
/// Begleitergepäck steht zuletzt, Verbrauchsgüter zuerst; kampfverknüpfte
/// Einträge erscheinen zur Orientierung, sind aber nie benutzbar.
List<GefechtsInventarposten> gefechtsInventar(HeroSheet hero) {
  final namen = {for (final c in hero.companions) c.id: c.name};
  final posten = <GefechtsInventarposten>[];
  for (final e in hero.inventoryEntries) {
    final verknuepft = isCombatLinkedInventorySource(e.source);
    final beimBegleiter = e.traegerTyp == InventoryTraeger.begleiter;
    final gruppe = beimBegleiter
        ? GefechtsInventargruppe.begleiter
        : !verknuepft && e.itemType == InventoryItemType.verbrauchsgegenstand
        ? GefechtsInventargruppe.verbrauch
        : verknuepft || e.istAusgeruestet || e.amKoerper.trim().isNotEmpty
        ? GefechtsInventargruppe.amKoerper
        : GefechtsInventargruppe.gepaeck;
    posten.add(
      GefechtsInventarposten(
        eintrag: e,
        gruppe: gruppe,
        menge: inventarMenge(e),
        benutzbar:
            !verknuepft &&
            (e.itemType == InventoryItemType.verbrauchsgegenstand ||
                e.isMagisch),
        traeger: beimBegleiter ? namen[e.traegerId] : null,
      ),
    );
  }
  posten.sort((a, b) => a.gruppe.index.compareTo(b.gruppe.index));
  return posten;
}

/// Wo ein benutzter Gegenstand liegt (WdS S. 55, MCP 6971).
enum GefechtsAufbewahrung {
  /// Bereits in der Hand oder unmittelbar greifbar.
  griffbereit,

  /// Gürteltasche: 10 Aktionen.
  guerteltasche,

  /// Rucksack: 20 Aktionen, wenn überhaupt so schnell zugänglich.
  rucksack,

  /// Getragenes Artefakt per Schlüsselwort: freie Aktion.
  artefakt,
}

/// Sichtbarer Name einer Aufbewahrung.
String gefechtsAufbewahrungName(GefechtsAufbewahrung a) => switch (a) {
  GefechtsAufbewahrung.griffbereit => 'Griffbereit (1 Aktion)',
  GefechtsAufbewahrung.guerteltasche => 'Gürteltasche (10)',
  GefechtsAufbewahrung.rucksack => 'Rucksack (20)',
  GefechtsAufbewahrung.artefakt => 'Artefakt aktivieren (frei)',
};

/// Vorbelegung aus dem Freitext „Wo getragen“, sonst Gürteltasche.
GefechtsAufbewahrung gefechtsAufbewahrungVorgabe(HeroInventoryEntry e) {
  final wo = '${e.woGetragen} ${e.amKoerper}'.toLowerCase();
  if (wo.contains('rucksack')) return GefechtsAufbewahrung.rucksack;
  if (wo.contains('gürtel') || wo.contains('guertel')) {
    return GefechtsAufbewahrung.guerteltasche;
  }
  if (e.isMagisch && e.itemType != InventoryItemType.verbrauchsgegenstand) {
    return GefechtsAufbewahrung.artefakt;
  }
  return GefechtsAufbewahrung.guerteltasche;
}

/// Dauer in Aktionen; 0 bedeutet freie Aktion.
///
/// WdS S. 55: Gürteltasche 10, Rucksack 20 Aktionen; eine gelungene FF-Probe
/// halbiert diese Zeit (aufgerundet, App-Konvention).
int gefechtsBenutzungsdauer(GefechtsAufbewahrung a, {bool ffGelungen = false}) {
  final basis = switch (a) {
    GefechtsAufbewahrung.griffbereit => 1,
    GefechtsAufbewahrung.guerteltasche => 10,
    GefechtsAufbewahrung.rucksack => 20,
    GefechtsAufbewahrung.artefakt => 0,
  };
  final halbierbar =
      a == GefechtsAufbewahrung.guerteltasche ||
      a == GefechtsAufbewahrung.rucksack;
  return ffGelungen && halbierbar ? (basis + 1) ~/ 2 : basis;
}
