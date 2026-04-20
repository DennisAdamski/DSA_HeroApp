/// Liest einen String-Wert tolerant aus JSON.
///
/// Nicht-String-Werte werden via `toString()` konvertiert, `null` ergibt den
/// Fallback. So bleiben alte Schemata lesbar.
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

/// Liest einen int-Wert tolerant aus JSON.
///
/// `num` wird via `toInt()` konvertiert und kuerzt Nachkommastellen. Das ist
/// nuetzlich, wenn JSON-Dateien Floats statt Ints enthalten.
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

/// Liest einen bool-Wert; jeder Nicht-Bool-Wert ergibt den Fallback.
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

/// Liest eine JSON-Liste als String-Liste.
///
/// Nicht-Listen ergeben eine leere konstante Liste. Jedes Element wird via
/// `toString()` konvertiert, um typentolerante JSON-Quellen zu unterstuetzen.
List<String> readCatalogStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}

/// Liest ein eingebettetes JSON-Objekt tolerant.
///
/// Nicht-Objekte ergeben `null`.
Map<String, dynamic>? readCatalogObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

/// Liest eine JSON-Liste als Objekt-Liste.
///
/// Nicht-Listen ergeben eine leere konstante Liste; nicht-Objekt-Eintraege
/// werden ignoriert.
List<Map<String, dynamic>> readCatalogObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  final entries = <Map<String, dynamic>>[];
  for (final entry in value) {
    if (entry is Map<String, dynamic>) {
      entries.add(entry);
      continue;
    }
    if (entry is Map) {
      entries.add(entry.cast<String, dynamic>());
    }
  }
  return List<Map<String, dynamic>>.unmodifiable(entries);
}
