import 'package:dsa_heldenverwaltung/domain/json_helpers.dart';

/// Einzelne freie Notiz eines Helden mit Titel und Langbeschreibung.
class HeroNoteEntry {
  /// Erzeugt einen persistierbaren Notizeintrag.
  const HeroNoteEntry({this.title = '', this.description = ''});

  /// Kurzer Anzeigetitel der Notiz.
  final String title;

  /// Vollstaendige Beschreibung der Notiz.
  final String description;

  /// Liefert eine neue Instanz mit gezielt ersetzten Feldern.
  HeroNoteEntry copyWith({String? title, String? description}) {
    return HeroNoteEntry(
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  /// Serialisiert den Eintrag fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'title': title, 'description': description};
  }

  /// Laedt einen Notizeintrag tolerant gegenueber fehlenden Feldern.
  static HeroNoteEntry fromJson(Map<String, dynamic> json) {
    return HeroNoteEntry(
      title: readJsonString(json, 'title'),
      description: readJsonString(json, 'description'),
    );
  }
}
