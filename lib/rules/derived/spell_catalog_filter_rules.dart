import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

import 'magic_rules.dart';

/// Kombiniert Repräsentation, Merkmal und Mindestverbreitung für Katalogzauber.
///
/// Klammerangaben wie `Dru(Elf)2` passen zu `Elf`, nicht allein zu `Dru`.
/// Synthetische Lernoptionen für fremde Zauber ändern die Sichtbarkeit nicht.
bool matchesSpellCatalogFilters({
  required SpellDef spell,
  required List<String> representations,
  required bool onlyLearnedRepresentations,
  String? trait,
  int minimumSpread = 0,
}) {
  final traits = parseSpellTraits(spell.traits);
  if (trait != null && !traits.contains(trait)) return false;
  if (!onlyLearnedRepresentations && minimumSpread == 0) return true;
  final entries = parseSpellAvailability(spell.availability);
  return entries.any((entry) {
    final representationMatches =
        !onlyLearnedRepresentations ||
        representations.contains(entry.learnedRepresentation);
    return representationMatches && entry.verbreitung >= minimumSpread;
  });
}

/// Liefert die im Katalog belegten Merkmale als sortierte Filterauswahl.
List<String> spellCatalogFilterTraits(Iterable<SpellDef> spells) {
  final traits = <String>{
    for (final spell in spells) ...parseSpellTraits(spell.traits),
  };
  return traits.toList()..sort();
}

/// Liefert belegte Verbreitungsstufen; `0` bleibt der ungefilterten UI vorbehalten.
List<int> spellCatalogFilterSpreads(Iterable<SpellDef> spells) {
  final spreads = <int>{
    for (final spell in spells)
      for (final entry in parseSpellAvailability(spell.availability))
        if (entry.verbreitung > 0) entry.verbreitung,
  };
  return spreads.toList()..sort();
}
