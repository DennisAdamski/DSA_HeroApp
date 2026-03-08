/// Laufzeitzustand fuer aktivierte wichtige Zaubereffekte.
///
/// Die IDs referenzieren definierte Effekte aus den Regelmodulen und bleiben
/// bewusst getrennt von `HeroSheet.spells`, das bekannte bzw. gelernte Zauber
/// beschreibt.
class ActiveSpellEffectsState {
  /// Erstellt einen unveraenderlichen Effektzustand.
  const ActiveSpellEffectsState({
    this.activeEffectIds = const <String>[],
  });

  /// IDs aller aktuell aktiven Zaubereffekte.
  final List<String> activeEffectIds;

  /// Prueft, ob ein Effekt mit [effectId] aktiv ist.
  bool isActive(String effectId) {
    return activeEffectIds.contains(effectId.trim());
  }

  /// Gibt eine Kopie mit optional ersetzter Effektliste zurueck.
  ActiveSpellEffectsState copyWith({List<String>? activeEffectIds}) {
    return ActiveSpellEffectsState(
      activeEffectIds: _normalizeEffectIds(activeEffectIds ?? this.activeEffectIds),
    );
  }

  /// Aktiviert oder deaktiviert einen einzelnen Effekt.
  ActiveSpellEffectsState withToggled(String effectId, bool isActive) {
    final normalizedId = effectId.trim();
    if (normalizedId.isEmpty) {
      return this;
    }
    final next = List<String>.from(activeEffectIds);
    final containsId = next.contains(normalizedId);
    if (isActive && !containsId) {
      next.add(normalizedId);
    } else if (!isActive && containsId) {
      next.remove(normalizedId);
    }
    return copyWith(activeEffectIds: next);
  }

  /// Serialisiert den Effektzustand fuer Persistenz und Transfer.
  Map<String, dynamic> toJson() {
    return {
      'activeEffectIds': _normalizeEffectIds(activeEffectIds),
    };
  }

  /// Laedt den Effektzustand rueckwaertskompatibel aus JSON.
  static ActiveSpellEffectsState fromJson(Map<String, dynamic> json) {
    final rawIds = (json['activeEffectIds'] as List?) ?? const <dynamic>[];
    return ActiveSpellEffectsState(
      activeEffectIds: _normalizeEffectIds(rawIds),
    );
  }
}

List<String> _normalizeEffectIds(Iterable<dynamic> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final id = value.toString().trim();
    if (id.isEmpty || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    normalized.add(id);
  }
  return List<String>.unmodifiable(normalized);
}
