// Liest einen String-Wert lenient: nicht-String-Werte werden via toString()
// konvertiert, null ergibt den Fallback. So bleiben alte Schemata lesbar.
String readCatalogString(
  Map<String, dynamic> json,
  String key, {
  required String fallback,
}) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

// Liest einen int-Wert lenient: num wird via toInt() konvertiert (kürzt
// Nachkommastellen). Nützlich, wenn JSON-Dateien Floats statt Ints enthalten.
int readCatalogInt(
  Map<String, dynamic> json,
  String key, {
  required int fallback,
}) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

// Liest einen bool-Wert; jeder Nicht-Bool-Wert ergibt den Fallback.
bool readCatalogBool(
  Map<String, dynamic> json,
  String key, {
  required bool fallback,
}) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  return fallback;
}

// Liest eine JSON-Liste als String-Liste. Nicht-Listen ergeben eine leere
// konstante Liste. Jedes Element wird via toString() konvertiert, um
// typentolerante JSON-Quellen zu unterstuetzen.
List<String> readCatalogStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}
