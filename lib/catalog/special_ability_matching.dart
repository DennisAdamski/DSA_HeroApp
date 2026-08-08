import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';

/// Sucht einen Katalogeintrag per Name (Groß-/Kleinschreibung tolerant).
///
/// Best-effort-Abgleich fuer Freitext-Sonderfertigkeiten-Dialoge (magisch,
/// allgemein, karmal), die keine direkte Katalog-Auswahl anbieten.
SpecialAbilityDef? matchCatalogSpecialAbility(
  List<SpecialAbilityDef> catalog,
  String name,
) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  for (final entry in catalog) {
    if (entry.name.trim().toLowerCase() == normalized) {
      return entry;
    }
  }
  return null;
}
