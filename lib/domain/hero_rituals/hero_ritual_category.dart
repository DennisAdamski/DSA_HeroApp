import 'package:dsa_heldenverwaltung/domain/hero_rituals/hero_ritual_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals/hero_ritual_field.dart';

/// Beschreibt, wie die Werte einer Ritualkategorie hergeleitet werden.
enum HeroRitualKnowledgeMode {
  /// Die Kategorie besitzt eine eigene Ritualkenntnis mit TaW und Komplexitaet.
  ownKnowledge,

  /// Die Kategorie leitet sich von einem oder mehreren Talenten ab.
  derivedTalents,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualKnowledge &&
          name == other.name &&
          value == other.value &&
          learningComplexity == other.learningComplexity;

  @override
  int get hashCode => Object.hash(name, value, learningComplexity);
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualCategory &&
          id == other.id &&
          name == other.name &&
          knowledgeMode == other.knowledgeMode &&
          ownKnowledge == other.ownKnowledge &&
          _ritualListEqual(derivedTalentIds, other.derivedTalentIds) &&
          _ritualListEqual(additionalFieldDefs, other.additionalFieldDefs) &&
          _ritualListEqual(rituals, other.rituals);

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    knowledgeMode,
    ownKnowledge,
    ...derivedTalentIds,
    ...additionalFieldDefs,
    ...rituals,
  ]);
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

const Object _keepNullableField = Object();

bool _ritualListEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
