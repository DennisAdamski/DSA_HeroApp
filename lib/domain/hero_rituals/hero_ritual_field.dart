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
  });

  /// Stabile ID der Felddefinition innerhalb einer Kategorie.
  final String id;

  /// Benutzerdefinierte Feldbezeichnung.
  final String label;

  /// Typ des Zusatzfelds.
  final HeroRitualFieldType type;

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualFieldDef copyWith({
    String? id,
    String? label,
    HeroRitualFieldType? type,
  }) {
    return HeroRitualFieldDef(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
    );
  }

  /// Serialisiert die Felddefinition fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'type': _ritualFieldTypeToJson(type)};
  }

  /// Liest eine Felddefinition tolerant aus JSON.
  static HeroRitualFieldDef fromJson(Map<String, dynamic> json) {
    return HeroRitualFieldDef(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      type: _ritualFieldTypeFromJson(json['type']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualFieldDef &&
          id == other.id &&
          label == other.label &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, label, type);
}

/// Konkreter Wert eines Zusatzfelds an einem einzelnen Ritual.
class HeroRitualFieldValue {
  /// Erzeugt einen unveraenderlichen Ritual-Zusatzfeldwert.
  const HeroRitualFieldValue({
    required this.fieldDefId,
    this.textValue = '',
    this.attributeCodes = const <String>[],
  });

  /// ID der referenzierten Felddefinition.
  final String fieldDefId;

  /// Gespeicherter Textwert fuer Felder vom Typ `text`.
  final String textValue;

  /// Gespeicherte Eigenschaftscodes fuer Felder vom Typ `threeAttributes`.
  final List<String> attributeCodes;

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualFieldValue copyWith({
    String? fieldDefId,
    String? textValue,
    List<String>? attributeCodes,
  }) {
    return HeroRitualFieldValue(
      fieldDefId: fieldDefId ?? this.fieldDefId,
      textValue: textValue ?? this.textValue,
      attributeCodes: attributeCodes ?? this.attributeCodes,
    );
  }

  /// Serialisiert den Zusatzfeldwert fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {
      'fieldDefId': fieldDefId,
      'textValue': textValue,
      'attributeCodes': attributeCodes,
    };
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualFieldValue &&
          fieldDefId == other.fieldDefId &&
          textValue == other.textValue &&
          _ritualListEqual(attributeCodes, other.attributeCodes);

  @override
  int get hashCode =>
      Object.hash(fieldDefId, textValue, Object.hashAll(attributeCodes));
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
