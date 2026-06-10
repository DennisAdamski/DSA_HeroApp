/// Normalisiert eine String-Liste fuer Persistenz und Anzeige.
///
/// Trimmt Whitespace, entfernt Leerstrings und Duplikate (Reihenfolge bleibt
/// stabil) und gibt eine unveraenderliche Liste zurueck. Nicht-String-Werte
/// werden ueber `toString()` uebernommen, damit auch rohe JSON-Listen
/// verarbeitet werden koennen.
List<String> normalizeStringList(Iterable<Object?> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final trimmed = value.toString().trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    normalized.add(trimmed);
  }
  return List<String>.unmodifiable(normalized);
}
