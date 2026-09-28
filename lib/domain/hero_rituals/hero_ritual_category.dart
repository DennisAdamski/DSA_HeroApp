import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';
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
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Anzeigename der Ritualkenntnis; wird mit dem Kategorienamen synchronisiert.
  final String name;

  /// Aktueller Wert der Ritualkenntnis.
  final int value;

  /// Lernkomplexitaet der Ritualkenntnis auf der Skala `A-H`.
  final String learningComplexity;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'name',
    'value',
    'learningComplexity',
  };

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualKnowledge copyWith({
    String? name,
    int? value,
    String? learningComplexity,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroRitualKnowledge(
      name: name ?? this.name,
      value: value ?? this.value,
      learningComplexity: learningComplexity ?? this.learningComplexity,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Ritualkenntnis fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'name': name,
      'value': value,
      'learningComplexity': learningComplexity,
    }, unbekannteFelder);
  }

  /// Liest eine Ritualkenntnis tolerant aus JSON.
  static HeroRitualKnowledge fromJson(Map<String, dynamic> json) {
    return HeroRitualKnowledge(
      name: (json['name'] as String?) ?? '',
      value: (json['value'] as num?)?.toInt() ?? 3,
      learningComplexity: (json['learningComplexity'] as String?) ?? 'E',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualKnowledge &&
          name == other.name &&
          value == other.value &&
          learningComplexity == other.learningComplexity &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    name,
    value,
    learningComplexity,
    unbekannteFelderHash(unbekannteFelder),
  );
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
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
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

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzaehlungswerte einer neueren App-Version (JSON-Schluessel
  /// -> Rohwert). Die Felder tragen den Ersatzwert, mit dem Regeln rechnen;
  /// geschrieben wird der Rohwert, bis jemand das Feld auf einen anderen Wert
  /// setzt (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'name',
    'knowledgeMode',
    'ownKnowledge',
    'derivedTalentIds',
    'additionalFieldDefs',
    'rituals',
  };

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualCategory copyWith({
    String? id,
    String? name,
    HeroRitualKnowledgeMode? knowledgeMode,
    Object? ownKnowledge = _keepNullableField,
    List<String>? derivedTalentIds,
    List<HeroRitualFieldDef>? additionalFieldDefs,
    List<HeroRitualEntry>? rituals,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
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
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'knowledgeMode':
                knowledgeMode != null && knowledgeMode != this.knowledgeMode,
          }),
    );
  }

  /// Serialisiert die Ritualkategorie fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'id': id,
        'name': name,
        'knowledgeMode': _ritualKnowledgeModeToJson(knowledgeMode),
        'ownKnowledge': ownKnowledge?.toJson(),
        'derivedTalentIds': derivedTalentIds,
        'additionalFieldDefs': additionalFieldDefs
            .map((entry) => entry.toJson())
            .toList(growable: false),
        'rituals': rituals
            .map((entry) => entry.toJson())
            .toList(growable: false),
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest eine Ritualkategorie tolerant aus JSON.
  static HeroRitualCategory fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    final rawDerivedTalentIds =
        (json['derivedTalentIds'] as List?) ?? const <dynamic>[];
    final rawAdditionalFieldDefs =
        (json['additionalFieldDefs'] as List?) ?? const <dynamic>[];
    final rawRituals = (json['rituals'] as List?) ?? const <dynamic>[];
    final rawOwnKnowledge = json['ownKnowledge'];
    return HeroRitualCategory(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      knowledgeMode: leseEnumWert(
        json['knowledgeMode'],
        'knowledgeMode',
        erkenne: _ritualKnowledgeModeErkennen,
        ersatz: HeroRitualKnowledgeMode.ownKnowledge,
        unbekannt: enumRoh,
      ),
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
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
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
          _ritualListEqual(rituals, other.rituals) &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder) &&
          unbekannteFelderGleich(
            unbekannteEnumWerte,
            other.unbekannteEnumWerte,
          );

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    knowledgeMode,
    ownKnowledge,
    ...derivedTalentIds,
    ...additionalFieldDefs,
    ...rituals,
    unbekannteFelderHash(unbekannteFelder),
    unbekannteFelderHash(unbekannteEnumWerte),
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

HeroRitualKnowledgeMode? _ritualKnowledgeModeErkennen(Object? raw) {
  switch (raw) {
    case 'derivedTalents':
      return HeroRitualKnowledgeMode.derivedTalents;
    case 'ownKnowledge':
      return HeroRitualKnowledgeMode.ownKnowledge;
    default:
      return null;
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
