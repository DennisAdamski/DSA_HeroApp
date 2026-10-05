import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';

/// Vergibt jedem Inventareintrag ohne Instanz-ID eine neue (ARCH-03).
///
/// Vorhandene IDs bleiben unverändert, auch bei gleichnamigen Gegenständen.
/// Trägt ein späterer Eintrag dieselbe ID wie ein früherer (z. B. nach einer
/// Bearbeitung durch eine ältere App-Version), bekommt er eine neue, damit
/// zwei Stapel nie dieselbe Identität teilen. Gibt dieselbe Liste zurück,
/// wenn nichts zu ändern ist.
List<HeroInventoryEntry> vergibInstanzIds(
  List<HeroInventoryEntry> eintraege, {
  required String Function() neueId,
}) {
  final belegt = <String>{};
  var geaendert = false;
  final ergebnis = <HeroInventoryEntry>[];
  for (final eintrag in eintraege) {
    final id = eintrag.instanzId;
    if (id != null && id.isNotEmpty && belegt.add(id)) {
      ergebnis.add(eintrag);
      continue;
    }
    var frisch = neueId();
    while (!belegt.add(frisch)) {
      frisch = neueId();
    }
    ergebnis.add(eintrag.copyWith(instanzId: frisch));
    geaendert = true;
  }
  return geaendert ? ergebnis : eintraege;
}
