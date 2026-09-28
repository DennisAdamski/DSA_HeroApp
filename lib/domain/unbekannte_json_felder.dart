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
///
/// Neben `HeroSheet` und `HeroState` traegt **jedes** verschachtelte Modell,
/// das in ihrem JSON steht, einen eigenen Satz und ein eigenes
/// `jsonSchluessel` (Ausruestung, Kampfeinstellungen, Talente, Zauber,
/// Rituale, Sprachen, Sonderfertigkeiten, Begleiter, Abenteuer, Notizen,
/// Kontakte, Gruppen, Reisebericht, Eigenschaften und Grundwerte, SE-Pools,
/// Bilder, Steigerungsverlauf sowie die Teilmodelle des Laufzeitzustands).
/// Das wirkt nur, solange Aenderungen ueber `copyWith` der vorhandenen
/// Instanz laufen; wer ein bestehendes Objekt per Konstruktor neu aufbaut,
/// verliert die Felder. Neu errechnete Werte werden deshalb per `copyWith`
/// (bzw. `uebernimmWerte` bei `Attributes`/`AttributeModifiers`) in die
/// vorhandene Instanz uebernommen.
///
/// Ausgenommen ist nur `OffhandSlot`: der Altschluessel `offhand` wird beim
/// Laden migriert und nie geschrieben.
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

/// Liest einen Aufzaehlungswert und bewahrt einen unbekannten Rohwert.
///
/// Erkennt [erkenne] den Rohwert [roh], ist das Ergebnis der erkannte Wert.
/// Sonst liefert die Funktion [ersatz]; ist [roh] dabei belegt (weder `null`
/// noch ein leerer Text), stammt er vermutlich aus einer neueren App-Version
/// und wird unter [schluessel] in [unbekannt] vermerkt. Regeln rechnen nur
/// mit dem Ersatz; [mitUnbekanntenEnumWerten] schreibt den Rohwert zurueck.
E leseEnumWert<E>(
  Object? roh,
  String schluessel, {
  required E? Function(Object? roh) erkenne,
  required E ersatz,
  required Map<String, Object?> unbekannt,
}) {
  final erkannt = erkenne(roh);
  if (erkannt != null) {
    return erkannt;
  }
  if (roh != null && !(roh is String && roh.trim().isEmpty)) {
    unbekannt[schluessel] = _kopie(roh);
  }
  return ersatz;
}

/// Erkennt einen Aufzaehlungswert ueber seinen Namen; sonst `null`.
E? enumNachName<E extends Enum>(List<E> werte, Object? roh) {
  if (roh is! String) {
    return null;
  }
  return werte.asNameMap()[roh];
}

/// Friert gesammelte unbekannte Aufzaehlungswerte ein.
Map<String, Object?> festeEnumWerte(Map<String, Object?> werte) {
  if (werte.isEmpty) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.unmodifiable(werte);
}

/// Ersetzt in [json] die Ersatzwerte durch die bewahrten Rohwerte.
///
/// Anders als [mitUnbekanntenFeldern] ueberschreibt diese Funktion: Der
/// Schluessel ist bekannt, geschrieben wurde aber nur der Ersatz.
Map<String, dynamic> mitUnbekanntenEnumWerten(
  Map<String, dynamic> json,
  Map<String, Object?> werte,
) {
  for (final entry in werte.entries) {
    json[entry.key] = _kopie(entry.value);
  }
  return json;
}

/// Entfernt die Rohwerte der Felder, die [geaendert] als geaendert meldet.
///
/// Fuer `copyWith`: Ein Feld gilt als geaendert, wenn ein **anderer** Wert
/// als der bisherige gesetzt wird. Wer den bisherigen Wert (auch den
/// Ersatz) nur durchreicht, etwa in einer Normalisierung oder einem Abgleich,
/// laesst den Rohwert stehen. Eine echte Aenderung durch den Nutzer
/// ueberschreibt ihn bewusst.
Map<String, Object?> ohneGeaenderteEnumWerte(
  Map<String, Object?> werte,
  Map<String, bool> geaendert,
) {
  if (werte.isEmpty ||
      !geaendert.entries.any((e) => e.value && werte.containsKey(e.key))) {
    return werte;
  }
  return festeEnumWerte(<String, Object?>{
    for (final entry in werte.entries)
      if (geaendert[entry.key] != true) entry.key: entry.value,
  });
}

/// Vergleicht zwei Saetze unbekannter Felder inhaltlich (tief, wie JSON).
///
/// Fuer `==` von Modellen, die unbekannte Felder tragen: Zwei Objekte, die
/// sich nur darin unterscheiden, sind verschiedene Daten.
bool unbekannteFelderGleich(Map<String, Object?> a, Map<String, Object?> b) {
  return _jsonGleich(a, b);
}

/// Hashwert passend zu [unbekannteFelderGleich].
///
/// Beruht nur auf den Schluesseln: gleiche Saetze haben gleiche Schluessel,
/// und die Werte muessen dafuer nicht tief gehasht werden.
int unbekannteFelderHash(Map<String, Object?> felder) {
  return Object.hashAllUnordered(felder.keys);
}

// Tiefer Vergleich roher JSON-Werte; Map-Reihenfolge zaehlt nicht.
bool _jsonGleich(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_jsonGleich(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonGleich(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
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
