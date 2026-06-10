/// Zentrale Lesehelfer fuer JSON-Maps in Domain-Modellen.
///
/// Die Semantik entspricht den bisher lokal duplizierten Helfern in den
/// fromJson-Fabriken: fehlende oder `null`-Werte ergeben den Fallback,
/// abweichende Typen werfen weiterhin einen `TypeError` (bewusst strikt,
/// damit defekte Daten frueh auffallen).
library;

/// Liest einen int-Wert; `num`-Werte werden mit `toInt()` konvertiert.
int readJsonInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  return (json[key] as num?)?.toInt() ?? fallback;
}

/// Liest einen String-Wert; nur echte Strings werden akzeptiert.
String readJsonString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  return (json[key] as String?) ?? fallback;
}

/// Liest einen bool-Wert; nur echte Bools werden akzeptiert.
bool readJsonBool(
  Map<String, dynamic> json,
  String key, {
  bool fallback = false,
}) {
  return (json[key] as bool?) ?? fallback;
}
