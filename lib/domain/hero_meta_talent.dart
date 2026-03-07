/// Persistierte Definition eines heldenspezifischen Meta-Talents.
///
/// Meta-Talente werden nicht aus dem globalen Regelkatalog geladen, sondern
/// pro Held gespeichert. Sie referenzieren bestehende Talent-IDs und drei
/// Eigenschaftscodes fuer die Probe.
class HeroMetaTalent {
  /// Erzeugt ein heldenspezifisches Meta-Talent.
  const HeroMetaTalent({
    required this.id,
    required this.name,
    this.componentTalentIds = const <String>[],
    this.attributes = const <String>[],
    this.be = '',
  });

  /// Stabile ID innerhalb des Helden.
  final String id;

  /// Anzeigename des Meta-Talents.
  final String name;

  /// Referenzierte Talent-IDs, aus denen der Meta-TaW gemittelt wird.
  final List<String> componentTalentIds;

  /// Drei Eigenschaftscodes fuer Probe und Max-TaW-Berechnung.
  final List<String> attributes;

  /// Optionale BE-Regel im gleichen Format wie bei Katalogtalenten.
  final String be;

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroMetaTalent copyWith({
    String? id,
    String? name,
    List<String>? componentTalentIds,
    List<String>? attributes,
    String? be,
  }) {
    return HeroMetaTalent(
      id: id ?? this.id,
      name: name ?? this.name,
      componentTalentIds: _normalizeComponentTalentIds(
        componentTalentIds ?? this.componentTalentIds,
      ),
      attributes: _normalizeAttributes(attributes ?? this.attributes),
      be: be ?? this.be,
    );
  }

  /// Serialisiert das Meta-Talent fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'componentTalentIds': _normalizeComponentTalentIds(componentTalentIds),
      'attributes': _normalizeAttributes(attributes),
      'be': be,
    };
  }

  /// Laedt ein Meta-Talent tolerant aus JSON.
  static HeroMetaTalent fromJson(Map<String, dynamic> json) {
    String getString(String key) => (json[key] as String?) ?? '';

    return HeroMetaTalent(
      id: getString('id'),
      name: getString('name'),
      componentTalentIds: _normalizeComponentTalentIds(
        _readStringList(json['componentTalentIds']),
      ),
      attributes: _normalizeAttributes(_readStringList(json['attributes'])),
      be: getString('be'),
    );
  }
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw.map((entry) => entry.toString()).toList(growable: false);
}

List<String> _normalizeComponentTalentIds(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    normalized.add(trimmed);
  }
  return List<String>.unmodifiable(normalized);
}

List<String> _normalizeAttributes(Iterable<String> values) {
  final normalized = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    normalized.add(trimmed);
  }
  return List<String>.unmodifiable(normalized);
}
