import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Einzelne freie Notiz eines Helden mit Titel und Langbeschreibung.
class HeroNoteEntry {
  /// Erzeugt einen persistierbaren Notizeintrag.
  const HeroNoteEntry({
    this.title = '',
    this.description = '',
    this.ort = '',
    this.datum = '',
    this.lastModified,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Kurzer Anzeigetitel der Notiz.
  final String title;

  /// Vollstaendige Beschreibung der Notiz.
  final String description;

  /// Ort, an dem die Notiz entstand; leer bei Bestandsnotizen.
  ///
  /// Nur belegt im JSON, damit sich der Inhalts-Hash alter Helden nicht
  /// aendert.
  final String ort;

  /// Aventurisches Datum der Notiz als Anzeigetext (etwa `17. Boron 1020 BF`);
  /// leer bei Bestandsnotizen. Bewusst Freitext: so bleibt auch eine ungefaehre
  /// Angabe moeglich. Nur belegt im JSON.
  final String datum;

  /// Zeitpunkt der letzten Bearbeitung (UTC); `null` bei Bestandsnotizen.
  ///
  /// Nur belegt im JSON, damit sich der Inhalts-Hash alter Helden nicht
  /// aendert.
  final DateTime? lastModified;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'title',
    'description',
    'ort',
    'datum',
    'lastModified',
  };

  /// Liefert eine neue Instanz mit gezielt ersetzten Feldern.
  HeroNoteEntry copyWith({
    String? title,
    String? description,
    String? ort,
    String? datum,
    Object? lastModified = _copySentinel,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroNoteEntry(
      title: title ?? this.title,
      description: description ?? this.description,
      ort: ort ?? this.ort,
      datum: datum ?? this.datum,
      lastModified: identical(lastModified, _copySentinel)
          ? this.lastModified
          : lastModified as DateTime?,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert den Eintrag fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'title': title,
      'description': description,
      if (ort.isNotEmpty) 'ort': ort,
      if (datum.isNotEmpty) 'datum': datum,
      if (lastModified != null)
        'lastModified': lastModified!.toUtc().toIso8601String(),
    }, unbekannteFelder);
  }

  /// Laedt einen Notizeintrag tolerant gegenueber fehlenden Feldern.
  static HeroNoteEntry fromJson(Map<String, dynamic> json) {
    String getString(String key) => (json[key] as String?) ?? '';

    return HeroNoteEntry(
      title: getString('title'),
      description: getString('description'),
      ort: getString('ort'),
      datum: getString('datum'),
      lastModified: DateTime.tryParse(json['lastModified']?.toString() ?? ''),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

const Object _copySentinel = Object();
