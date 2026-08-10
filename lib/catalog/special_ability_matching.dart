import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

/// Sucht einen Katalogeintrag per Name (Groß-/Kleinschreibung tolerant).
///
/// Best-effort-Abgleich fuer Freitext-Sonderfertigkeiten-Dialoge (magisch,
/// allgemein, karmal), die keine direkte Katalog-Auswahl anbieten.
///
/// Findet der exakte Vergleich nichts, wird auf den Basisnamen ohne
/// Auswahlvariante zurueckgefallen — so trifft ein gespeichertes
/// `Kulturkunde (Novadi)` weiterhin den Katalogeintrag `Kulturkunde`.
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
  final base = normalizeSpecialAbilityName(specialAbilityBaseName(name));
  if (base.isEmpty) {
    return null;
  }
  for (final entry in catalog) {
    if (normalizeSpecialAbilityName(entry.name) == base) {
      return entry;
    }
  }
  return null;
}
