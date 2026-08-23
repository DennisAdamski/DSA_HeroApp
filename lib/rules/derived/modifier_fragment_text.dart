/// Gemeinsame Textnormalisierung fuer benannte Modifikator-Regeln.
///
/// Sowohl die Standard-Stat-Regeln (`standard_stat_modifier_rules.dart`) als
/// auch die Eigenschafts-Regeln (`attribute_trait_rules.dart`) vergleichen
/// Freitextfragmente gegen eine Alias-Liste. Beide brauchen dieselbe
/// Normalisierung; sie liegt deshalb hier statt doppelt in beiden Modulen.
library;

/// Normalisiert ein Modifier-Fragment fuer den Alias-Vergleich.
///
/// Umlaute werden zu `ae`/`oe`/`ue`/`ss` aufgeloest, `:()[]` zu Leerzeichen,
/// Vorzeichenzahlen isoliert (`KK+2` wird zu `kk +2`), der Rest auf
/// `[a-z0-9+- ]` reduziert und Mehrfach-Leerzeichen zusammengefasst.
String normalizeModifierFragment(String input) {
  var normalized = input
      .toLowerCase()
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  normalized = normalized.replaceAll(RegExp(r'[:()\[\]]'), ' ');
  normalized = normalized.replaceAllMapped(
    RegExp(r'([+-])\s*(\d+)'),
    (match) => ' ${match.group(1)!}${match.group(2)!}',
  );
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9+\-\s]'), ' ');
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Liefert den Resttext hinter einem Alias.
///
/// Beide Argumente muessen bereits durch [normalizeModifierFragment] gelaufen
/// sein. Ein exakter Treffer ergibt `''` (Alias ohne Zusatz), ein nicht
/// passender Alias `null`. Der Alias muss als vollstaendiges Wortpraefix
/// stehen, damit `Herausragende Eigenschaft` nicht auf
/// `Herausragendes Aussehen` anspringt.
String? modifierFragmentRemainderAfterAlias(
  String normalizedFragment,
  String normalizedAlias,
) {
  if (normalizedAlias.isEmpty) {
    return null;
  }
  if (normalizedFragment == normalizedAlias) {
    return '';
  }
  final prefix = '$normalizedAlias ';
  if (!normalizedFragment.startsWith(prefix)) {
    return null;
  }
  return normalizedFragment.substring(prefix.length).trim();
}
