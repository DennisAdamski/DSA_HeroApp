import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';

class HeroState {
  const HeroState({
    this.schemaVersion = 1,
    required this.currentLep,
    required this.currentAsp,
    required this.currentKap,
    required this.currentAu,
    this.tempMods = const StatModifiers(),
  });

  const HeroState.empty()
      : schemaVersion = 1,
        currentLep = 0,
        currentAsp = 0,
        currentKap = 0,
        currentAu = 0,
        tempMods = const StatModifiers();

  final int schemaVersion;
  final int currentLep;
  final int currentAsp;
  final int currentKap;
  final int currentAu;
  final StatModifiers tempMods;

  HeroState copyWith({
    int? currentLep,
    int? currentAsp,
    int? currentKap,
    int? currentAu,
    StatModifiers? tempMods,
  }) {
    return HeroState(
      schemaVersion: schemaVersion,
      currentLep: currentLep ?? this.currentLep,
      currentAsp: currentAsp ?? this.currentAsp,
      currentKap: currentKap ?? this.currentKap,
      currentAu: currentAu ?? this.currentAu,
      tempMods: tempMods ?? this.tempMods,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'currentLep': currentLep,
      'currentAsp': currentAsp,
      'currentKap': currentKap,
      'currentAu': currentAu,
      'tempMods': tempMods.toJson(),
    };
  }

  static HeroState fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return HeroState(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      currentLep: getInt('currentLep'),
      currentAsp: getInt('currentAsp'),
      currentKap: getInt('currentKap'),
      currentAu: getInt('currentAu'),
      tempMods: StatModifiers.fromJson((json['tempMods'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }
}
