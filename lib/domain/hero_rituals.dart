/// Beschreibt, wie die Werte einer Ritualkategorie hergeleitet werden.
enum HeroRitualKnowledgeMode {
  /// Die Kategorie besitzt eine eigene Ritualkenntnis mit TaW und Komplexitaet.
  ownKnowledge,

  /// Die Kategorie leitet sich von einem oder mehreren Talenten ab.
  derivedTalents,
}

/// Typ eines frei konfigurierbaren Zusatzfelds an einem Ritual.
enum HeroRitualFieldType {
  /// Freies Textfeld.
  text,

  /// Genau drei Eigenschaftscodes.
  threeAttributes,
}

/// Eigene Ritualkenntnis fuer eine Ritualkategorie.
class HeroRitualKnowledge {
  /// Erzeugt eine unveraenderliche Ritualkenntnis.
  const HeroRitualKnowledge({
    required this.name,
    this.value = 3,
    this.learningComplexity = 'E',
  });

  /// Anzeigename der Ritualkenntnis; wird mit dem Kategorienamen synchronisiert.
  final String name;

  /// Aktueller Wert der Ritualkenntnis.
  final int value;

  /// Lernkomplexitaet der Ritualkenntnis auf der Skala `A-H`.
  final String learningComplexity;

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualKnowledge copyWith({
    String? name,
    int? value,
    String? learningComplexity,
  }) {
    return HeroRitualKnowledge(
      name: name ?? this.name,
      value: value ?? this.value,
      learningComplexity: learningComplexity ?? this.learningComplexity,
    );
  }

  /// Serialisiert die Ritualkenntnis fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'learningComplexity': learningComplexity,
    };
  }

  /// Liest eine Ritualkenntnis tolerant aus JSON.
  static HeroRitualKnowledge fromJson(Map<String, dynamic> json) {
    return HeroRitualKnowledge(
      name: (json['name'] as String?) ?? '',
      value: (json['value'] as num?)?.toInt() ?? 3,
      learningComplexity: (json['learningComplexity'] as String?) ?? 'E',
    );
  }
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
}

/// Einzelnes Ritual innerhalb einer Ritualkategorie.
class HeroRitualEntry {
  /// Erzeugt einen unveraenderlichen Ritualeintrag.
  const HeroRitualEntry({
    required this.name,
    this.wirkung = '',
    this.kosten = '',
    this.wirkungsdauer = '',
    this.merkmale = '',
    this.zauberdauer = '',
    this.zielobjekt = '',
    this.reichweite = '',
    this.technik = '',
    this.additionalFieldValues = const <HeroRitualFieldValue>[],
  });

  /// Anzeigename des Rituals.
  final String name;

  /// Wirkungsbeschreibung des Rituals.
  final String wirkung;

  /// Kosten des Rituals.
  final String kosten;

  /// Wirkungsdauer des Rituals.
  final String wirkungsdauer;

  /// Merkmale des Rituals.
  final String merkmale;

  /// Optionale Zauberdauer.
  final String zauberdauer;

  /// Optionales Zielobjekt.
  final String zielobjekt;

  /// Optionale Reichweite.
  final String reichweite;

  /// Optionale Technik.
  final String technik;

  /// Werte der frei konfigurierten Zusatzfelder.
  final List<HeroRitualFieldValue> additionalFieldValues;

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualEntry copyWith({
    String? name,
    String? wirkung,
    String? kosten,
    String? wirkungsdauer,
    String? merkmale,
    String? zauberdauer,
    String? zielobjekt,
    String? reichweite,
    String? technik,
    List<HeroRitualFieldValue>? additionalFieldValues,
  }) {
    return HeroRitualEntry(
      name: name ?? this.name,
      wirkung: wirkung ?? this.wirkung,
      kosten: kosten ?? this.kosten,
      wirkungsdauer: wirkungsdauer ?? this.wirkungsdauer,
      merkmale: merkmale ?? this.merkmale,
      zauberdauer: zauberdauer ?? this.zauberdauer,
      zielobjekt: zielobjekt ?? this.zielobjekt,
      reichweite: reichweite ?? this.reichweite,
      technik: technik ?? this.technik,
      additionalFieldValues:
          additionalFieldValues ?? this.additionalFieldValues,
    );
  }

  /// Serialisiert das Ritual fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'wirkung': wirkung,
      'kosten': kosten,
      'wirkungsdauer': wirkungsdauer,
      'merkmale': merkmale,
      'zauberdauer': zauberdauer,
      'zielobjekt': zielobjekt,
      'reichweite': reichweite,
      'technik': technik,
      'additionalFieldValues': additionalFieldValues
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  /// Liest ein Ritual tolerant aus JSON.
  static HeroRitualEntry fromJson(Map<String, dynamic> json) {
    final rawAdditionalFieldValues =
        (json['additionalFieldValues'] as List?) ?? const <dynamic>[];
    return HeroRitualEntry(
      name: (json['name'] as String?) ?? '',
      wirkung: (json['wirkung'] as String?) ?? '',
      kosten: (json['kosten'] as String?) ?? '',
      wirkungsdauer: (json['wirkungsdauer'] as String?) ?? '',
      merkmale: (json['merkmale'] as String?) ?? '',
      zauberdauer: (json['zauberdauer'] as String?) ?? '',
      zielobjekt: (json['zielobjekt'] as String?) ?? '',
      reichweite: (json['reichweite'] as String?) ?? '',
      technik: (json['technik'] as String?) ?? '',
      additionalFieldValues: rawAdditionalFieldValues
          .whereType<Map>()
          .map(
            (entry) =>
                HeroRitualFieldValue.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

/// Heldenspezifische Ritualkategorie mit eigener Ritualliste.
class HeroRitualCategory {
  /// Erzeugt eine unveraenderliche Ritualkategorie.
  const HeroRitualCategory({
    required this.id,
    required this.name,
    required this.knowledgeMode,
    this.ownKnowledge,
    this.derivedTalentIds = const <String>[],
    this.additionalFieldDefs = const <HeroRitualFieldDef>[],
    this.rituals = const <HeroRitualEntry>[],
  });

  /// Stabile ID der Kategorie innerhalb des Helden.
  final String id;

  /// Anzeigename der Kategorie.
  final String name;

  /// Herkunft der Ritualwerte.
  final HeroRitualKnowledgeMode knowledgeMode;

  /// Eigene Ritualkenntnis, wenn [knowledgeMode] `ownKnowledge` ist.
  final HeroRitualKnowledge? ownKnowledge;

  /// Referenzierte Talente, wenn [knowledgeMode] `derivedTalents` ist.
  final List<String> derivedTalentIds;

  /// Frei definierte Zusatzfelder fuer alle Rituale der Kategorie.
  final List<HeroRitualFieldDef> additionalFieldDefs;

  /// Alle Rituale dieser Kategorie.
  final List<HeroRitualEntry> rituals;

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualCategory copyWith({
    String? id,
    String? name,
    HeroRitualKnowledgeMode? knowledgeMode,
    Object? ownKnowledge = _keepNullableField,
    List<String>? derivedTalentIds,
    List<HeroRitualFieldDef>? additionalFieldDefs,
    List<HeroRitualEntry>? rituals,
  }) {
    return HeroRitualCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      knowledgeMode: knowledgeMode ?? this.knowledgeMode,
      ownKnowledge: identical(ownKnowledge, _keepNullableField)
          ? this.ownKnowledge
          : ownKnowledge as HeroRitualKnowledge?,
      derivedTalentIds: derivedTalentIds ?? this.derivedTalentIds,
      additionalFieldDefs: additionalFieldDefs ?? this.additionalFieldDefs,
      rituals: rituals ?? this.rituals,
    );
  }

  /// Serialisiert die Ritualkategorie fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'knowledgeMode': _ritualKnowledgeModeToJson(knowledgeMode),
      'ownKnowledge': ownKnowledge?.toJson(),
      'derivedTalentIds': derivedTalentIds,
      'additionalFieldDefs': additionalFieldDefs
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'rituals': rituals.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  /// Liest eine Ritualkategorie tolerant aus JSON.
  static HeroRitualCategory fromJson(Map<String, dynamic> json) {
    final rawDerivedTalentIds =
        (json['derivedTalentIds'] as List?) ?? const <dynamic>[];
    final rawAdditionalFieldDefs =
        (json['additionalFieldDefs'] as List?) ?? const <dynamic>[];
    final rawRituals = (json['rituals'] as List?) ?? const <dynamic>[];
    final rawOwnKnowledge = json['ownKnowledge'];
    return HeroRitualCategory(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      knowledgeMode: _ritualKnowledgeModeFromJson(json['knowledgeMode']),
      ownKnowledge: rawOwnKnowledge is Map
          ? HeroRitualKnowledge.fromJson(
              rawOwnKnowledge.cast<String, dynamic>(),
            )
          : null,
      derivedTalentIds: rawDerivedTalentIds
          .map((entry) => entry.toString())
          .toList(growable: false),
      additionalFieldDefs: rawAdditionalFieldDefs
          .whereType<Map>()
          .map(
            (entry) =>
                HeroRitualFieldDef.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      rituals: rawRituals
          .whereType<Map>()
          .map(
            (entry) => HeroRitualEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

String _ritualKnowledgeModeToJson(HeroRitualKnowledgeMode value) {
  switch (value) {
    case HeroRitualKnowledgeMode.ownKnowledge:
      return 'ownKnowledge';
    case HeroRitualKnowledgeMode.derivedTalents:
      return 'derivedTalents';
  }
}

HeroRitualKnowledgeMode _ritualKnowledgeModeFromJson(Object? raw) {
  switch (raw) {
    case 'derivedTalents':
      return HeroRitualKnowledgeMode.derivedTalents;
    case 'ownKnowledge':
    default:
      return HeroRitualKnowledgeMode.ownKnowledge;
  }
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

const Object _keepNullableField = Object();
