import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

import 'hero_merkmal_zuordnung_rules.dart';

/// Erkennt den Zaubererstatus ausschließlich aus den wirksamen Vorteilen.
/// Fehlender oder widersprüchlicher Status verlangt eine ausdrückliche Auswahl.
String? detectMagicStatus(HeroSheet hero, RulesCatalog catalog) {
  final effective = gleicheMerkmaleAb(
    hero,
    katalog: MerkmalKatalog.von(catalog),
  );
  final text = projiziereMerkmalText(effective.vorteile).toLowerCase();
  final matches = <String>{
    if (RegExp(r'\bvollzauberer\b').hasMatch(text)) 'full',
    if (RegExp(r'\bhalbzauberer\b').hasMatch(text)) 'half',
    if (RegExp(r'\bviertelzauberer\b').hasMatch(text)) 'quarter',
  };
  return matches.length == 1 ? matches.single : null;
}

/// Gültige ausdrücklich bestätigte Statuskennungen für Erwerbsnachweise.
bool isValidMagicStatus(String? status) =>
    const {'full', 'half', 'quarter'}.contains(status);
