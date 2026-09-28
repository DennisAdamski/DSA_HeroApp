import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Typ eines frei konfigurierbaren Zusatzfelds an einem Ritual.
enum HeroRitualFieldType {
  /// Freies Textfeld.
  text,

  /// Genau drei Eigenschaftscodes.
  threeAttributes,
}

/// Definition eines frei konfigurierbaren Zusatzfelds einer Ritualkategorie.
class HeroRitualFieldDef {
  /// Erzeugt ein unveraenderliches Ritual-Zusatzfeld.
  const HeroRitualFieldDef({
    required this.id,
    required this.label,
    required this.type,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile ID der Felddefinition innerhalb einer Kategorie.
  final String id;

  /// Benutzerdefinierte Feldbezeichnung.
  final String label;

  /// Typ des Zusatzfelds.
  final HeroRitualFieldType type;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'id', 'label', 'type'};

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualFieldDef copyWith({
    String? id,
    String? label,
    HeroRitualFieldType? type,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroRitualFieldDef(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Felddefinition fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'id': id,
      'label': label,
      'type': _ritualFieldTypeToJson(type),
    }, unbekannteFelder);
  }

  /// Liest eine Felddefinition tolerant aus JSON.
  static HeroRitualFieldDef fromJson(Map<String, dynamic> json) {
    return HeroRitualFieldDef(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      type: _ritualFieldTypeFromJson(json['type']),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualFieldDef &&
          id == other.id &&
          label == other.label &&
          type == other.type &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode =>
      Object.hash(id, label, type, unbekannteFelderHash(unbekannteFelder));
}

/// Konkreter Wert eines Zusatzfelds an einem einzelnen Ritual.
class HeroRitualFieldValue {
  /// Erzeugt einen unveraenderlichen Ritual-Zusatzfeldwert.
  const HeroRitualFieldValue({
    required this.fieldDefId,
    this.textValue = '',
    this.attributeCodes = const <String>[],
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// ID der referenzierten Felddefinition.
  final String fieldDefId;

  /// Gespeicherter Textwert fuer Felder vom Typ `text`.
  final String textValue;

  /// Gespeicherte Eigenschaftscodes fuer Felder vom Typ `threeAttributes`.
  final List<String> attributeCodes;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'fieldDefId',
    'textValue',
    'attributeCodes',
  };

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualFieldValue copyWith({
    String? fieldDefId,
    String? textValue,
    List<String>? attributeCodes,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroRitualFieldValue(
      fieldDefId: fieldDefId ?? this.fieldDefId,
      textValue: textValue ?? this.textValue,
      attributeCodes: attributeCodes ?? this.attributeCodes,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert den Zusatzfeldwert fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'fieldDefId': fieldDefId,
      'textValue': textValue,
      'attributeCodes': attributeCodes,
    }, unbekannteFelder);
  }

  /// Liest einen Zusatzfeldwert tolerant aus JSON.
  static HeroRitualFieldValue fromJson(Map<String, dynamic> json) {
    final rawAttributeCodes = json['attributeCodes'];
    return HeroRitualFieldValue(
      fieldDefId: (json['fieldDefId'] as String?) ?? '',
      textValue: (json['textValue'] as String?) ?? '',
      attributeCodes: rawAttributeCodes is List
          ? rawAttributeCodes
                .map((entry) => entry.toString())
                .toList(growable: false)
          : const <String>[],
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualFieldValue &&
          fieldDefId == other.fieldDefId &&
          textValue == other.textValue &&
          _ritualListEqual(attributeCodes, other.attributeCodes) &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    fieldDefId,
    textValue,
    Object.hashAll(attributeCodes),
    unbekannteFelderHash(unbekannteFelder),
  );
}

String _ritualFieldTypeToJson(HeroRitualFieldType value) {
  switch (value) {
    case HeroRitualFieldType.text:
      return 'text';
    case HeroRitualFieldType.threeAttributes:
      return 'threeAttributes';
  }
}

HeroRitualFieldType _ritualFieldTypeFromJson(Object? raw) {
  switch (raw) {
    case 'threeAttributes':
      return HeroRitualFieldType.threeAttributes;
    case 'text':
    default:
      return HeroRitualFieldType.text;
  }
}

bool _ritualListEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
