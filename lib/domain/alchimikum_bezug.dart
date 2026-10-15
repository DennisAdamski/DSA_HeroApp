import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Verweis eines Inventareintrags auf ein Katalogmittel (TRANK): Mittel-ID und
/// gewählte Qualitätsstufe.
///
/// Der Eintrag bleibt ein gewöhnlicher Verbrauchsgegenstand; der Verweis sagt
/// nur, **welche** Katalogwirkung das Anwenden vorschlägt (etwa die
/// Eigenschaftsänderungen eines Elixiers). Die Werte selbst stehen im Katalog,
/// nie am Gegenstand, damit sie sich dort korrigieren lassen. Nur geschrieben,
/// wenn belegt (Bestands-Hashes).
class AlchimikumBezug {
  /// Erstellt den Verweis.
  const AlchimikumBezug({
    required this.id,
    this.stufe = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Katalog-ID des Mittels, z. B. `alch_mutelixier`.
  final String id;

  /// Qualitätsstufe `A` bis `F`; leer bei Mitteln ohne Stufen.
  final String stufe;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'id', 'stufe'};

  /// Gibt eine Kopie mit selektiv überschriebenen Feldern zurück.
  AlchimikumBezug copyWith({
    String? id,
    String? stufe,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return AlchimikumBezug(
      id: id ?? this.id,
      stufe: stufe ?? this.stufe,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert den Verweis; die Stufe nur bei Belegung.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'id': id,
      if (stufe.isNotEmpty) 'stufe': stufe,
    }, unbekannteFelder);
  }

  /// Liest den Verweis tolerant; `null`, wenn keine ID vorliegt.
  static AlchimikumBezug? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      return null;
    }
    final stufe = json['stufe'];
    return AlchimikumBezug(
      id: id.trim(),
      stufe: stufe is String ? stufe.trim() : '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AlchimikumBezug &&
        other.id == id &&
        other.stufe == stufe &&
        unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);
  }

  @override
  int get hashCode =>
      Object.hash(id, stufe, unbekannteFelderHash(unbekannteFelder));
}
