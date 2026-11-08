import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_date_value.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Einzelne freie Notiz eines Helden mit Titel und Langbeschreibung.
class HeroNoteEntry {
  /// Erzeugt einen persistierbaren Notizeintrag.
  const HeroNoteEntry({
    this.title = '',
    this.description = '',
    this.ort = '',
    this.datum = const HeroAdventureDateValue(),
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

  /// Aventurisches Datum der Notiz; leer bei Bestandsnotizen. Tag, Monat und
  /// Jahr bleiben Freitext, Teilangaben sind erlaubt. Nur belegt im JSON
  /// ([HeroAdventureDateValue.istBelegt]).
  final HeroAdventureDateValue datum;

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
    HeroAdventureDateValue? datum,
    Object? lastModified = keepFieldValue,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroNoteEntry(
      title: title ?? this.title,
      description: description ?? this.description,
      ort: ort ?? this.ort,
      datum: datum ?? this.datum,
      lastModified: identical(lastModified, keepFieldValue)
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
      if (datum.istBelegt) 'datum': datum.toJson(),
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
      datum: HeroAdventureDateValue.lese(json['datum']),
      lastModified: DateTime.tryParse(json['lastModified']?.toString() ?? ''),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
