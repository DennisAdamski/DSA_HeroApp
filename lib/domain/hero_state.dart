import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';

/// Laufzeitzustand eines Helden, getrennt von den Stammdaten (`HeroSheet`).
///
/// Enthalten sind vor allem aktuelle Ressourcenstaende und temporaere
/// Modifikatoren, die nicht dauerhaft ins Heldenblatt geschrieben werden.
class HeroState {
  const HeroState({
    this.schemaVersion = 3,
    required this.currentLep,
    required this.currentAsp,
    required this.currentKap,
    required this.currentAu,
    this.tempMods = const StatModifiers(),
    this.tempAttributeMods = const AttributeModifiers(),
    this.activeSpellEffects = const ActiveSpellEffectsState(),
  });

  const HeroState.empty()
      : schemaVersion = 3,
        currentLep = 0,
        currentAsp = 0,
        currentKap = 0,
        currentAu = 0,
        tempMods = const StatModifiers(),
        tempAttributeMods = const AttributeModifiers(),
        activeSpellEffects = const ActiveSpellEffectsState();

  final int schemaVersion;
  final int currentLep;
  final int currentAsp;
  final int currentKap;
  final int currentAu;
  final StatModifiers tempMods;
  final AttributeModifiers tempAttributeMods;
  final ActiveSpellEffectsState activeSpellEffects;

  /// Immutable Update fuer Teilmengen des Laufzeitzustands.
  HeroState copyWith({
    int? currentLep,
    int? currentAsp,
    int? currentKap,
    int? currentAu,
    StatModifiers? tempMods,
    AttributeModifiers? tempAttributeMods,
    ActiveSpellEffectsState? activeSpellEffects,
  }) {
    return HeroState(
      schemaVersion: schemaVersion,
      currentLep: currentLep ?? this.currentLep,
      currentAsp: currentAsp ?? this.currentAsp,
      currentKap: currentKap ?? this.currentKap,
      currentAu: currentAu ?? this.currentAu,
      tempMods: tempMods ?? this.tempMods,
      tempAttributeMods: tempAttributeMods ?? this.tempAttributeMods,
      activeSpellEffects: activeSpellEffects ?? this.activeSpellEffects,
    );
  }

  /// Serialisierung fuer Persistenz (eigene State-Box).
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'currentLep': currentLep,
      'currentAsp': currentAsp,
      'currentKap': currentKap,
      'currentAu': currentAu,
      'tempMods': tempMods.toJson(),
      'tempAttributeMods': tempAttributeMods.toJson(),
      'activeSpellEffects': activeSpellEffects.toJson(),
    };
  }

  /// Robust gegen fehlende Felder in aelteren Daten.
  static HeroState fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return HeroState(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      currentLep: getInt('currentLep'),
      currentAsp: getInt('currentAsp'),
      currentKap: getInt('currentKap'),
      currentAu: getInt('currentAu'),
      tempMods: StatModifiers.fromJson(
        (json['tempMods'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      tempAttributeMods: AttributeModifiers.fromJson(
        (json['tempAttributeMods'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
      activeSpellEffects: ActiveSpellEffectsState.fromJson(
        (json['activeSpellEffects'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
    );
  }
}
