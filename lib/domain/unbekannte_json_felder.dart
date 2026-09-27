/// Erhalt von JSON-Feldern, die diese App-Version nicht kennt.
///
/// Eine neuere App-Version kann einem Helden Felder hinzufuegen. Liest eine
/// aeltere Version ihn und speichert ihn wieder, gingen diese Felder ohne
/// Vorkehrung verloren — per Konto-Sync sogar auf allen Geraeten (Befund
/// ARCH-07-B6). Modelle sammeln deshalb unbekannte Schluessel beim Laden ein
/// und schreiben sie beim Speichern unveraendert zurueck.
///
/// Bestandsdaten enthalten keine unbekannten Schluessel; ihr JSON und damit
/// ihr Inhalts-Hash bleiben unveraendert.
library;

/// Liefert alle Eintraege aus [json], deren Schluessel nicht in [bekannt]
/// steht, als unveraenderliche Kopie.
///
/// [bekannt] muss **jeden** Schluessel enthalten, den das Modell liest —
/// auch die nur bedingt geschriebenen. Sonst kaeme ein bewusst weggelassenes
/// Feld als „unbekannt“ mit altem Wert zurueck.
Map<String, Object?> sammleUnbekannteFelder(
  Map<String, dynamic> json,
  Set<String> bekannt,
) {
  final unbekannt = <String, Object?>{
    for (final entry in json.entries)
      if (!bekannt.contains(entry.key)) entry.key: _kopie(entry.value),
  };
  if (unbekannt.isEmpty) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.unmodifiable(unbekannt);
}

/// Ergaenzt [json] um die [unbekannt]en Felder, ohne bekannte zu ueberschreiben.
Map<String, dynamic> mitUnbekanntenFeldern(
  Map<String, dynamic> json,
  Map<String, Object?> unbekannt,
) {
  for (final entry in unbekannt.entries) {
    json.putIfAbsent(entry.key, () => _kopie(entry.value));
  }
  return json;
}

// Tiefe Kopie roher JSON-Werte, damit kein geteilter Zustand entsteht.
Object? _kopie(Object? wert) {
  if (wert is Map) {
    return <String, Object?>{
      for (final entry in wert.entries) '${entry.key}': _kopie(entry.value),
    };
  }
  if (wert is List) {
    return <Object?>[for (final element in wert) _kopie(element)];
  }
  return wert;
}
