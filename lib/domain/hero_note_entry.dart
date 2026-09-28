import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Einzelne freie Notiz eines Helden mit Titel und Langbeschreibung.
class HeroNoteEntry {
  /// Erzeugt einen persistierbaren Notizeintrag.
  const HeroNoteEntry({
    this.title = '',
    this.description = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Kurzer Anzeigetitel der Notiz.
  final String title;

  /// Vollstaendige Beschreibung der Notiz.
  final String description;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'title', 'description'};

  /// Liefert eine neue Instanz mit gezielt ersetzten Feldern.
  HeroNoteEntry copyWith({
    String? title,
    String? description,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroNoteEntry(
      title: title ?? this.title,
      description: description ?? this.description,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert den Eintrag fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'title': title,
      'description': description,
    }, unbekannteFelder);
  }

  /// Laedt einen Notizeintrag tolerant gegenueber fehlenden Feldern.
  static HeroNoteEntry fromJson(Map<String, dynamic> json) {
    String getString(String key) => (json[key] as String?) ?? '';

    return HeroNoteEntry(
      title: getString('title'),
      description: getString('description'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
