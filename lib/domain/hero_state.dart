import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

/// Laufzeitzustand eines Helden, getrennt von den Stammdaten (`HeroSheet`).
///
/// Enthalten sind vor allem aktuelle Ressourcenstaende und temporaere
/// Modifikatoren, die nicht dauerhaft ins Heldenblatt geschrieben werden.
class HeroState {
  const HeroState({
    this.schemaVersion = 6,
    required this.currentLep,
    required this.currentAsp,
    required this.currentKap,
    required this.currentAu,
    this.erschoepfung = 0,
    this.ueberanstrengung = 0,
    this.tempMods = const StatModifiers(),
    this.tempAttributeMods = const AttributeModifiers(),
    this.activeSpellEffects = const ActiveSpellEffectsState(),
    this.wpiZustand = const WundZustand(),
    this.diceLog = const <DiceLogEntry>[],
  });

  const HeroState.empty()
    : schemaVersion = 6,
      currentLep = 0,
      currentAsp = 0,
      currentKap = 0,
      currentAu = 0,
      erschoepfung = 0,
      ueberanstrengung = 0,
      tempMods = const StatModifiers(),
      tempAttributeMods = const AttributeModifiers(),
      activeSpellEffects = const ActiveSpellEffectsState(),
      wpiZustand = const WundZustand(),
      diceLog = const <DiceLogEntry>[];

  /// Maximale Anzahl persistierter Wuerfelprotokoll-Eintraege pro Held.
  static const int diceLogMax = 14;

  final int schemaVersion;
  final int currentLep;
  final int currentAsp;
  final int currentKap;
  final int currentAu;
  final int erschoepfung;
  final int ueberanstrengung;
  final StatModifiers tempMods;
  final AttributeModifiers tempAttributeMods;
  final ActiveSpellEffectsState activeSpellEffects;

  /// Aktueller Wundenzustand des Helden.
  final WundZustand wpiZustand;

  /// Persistiertes Wuerfelprotokoll, neueste Eintraege am Ende der Liste.
  final List<DiceLogEntry> diceLog;

  /// Immutable Update fuer Teilmengen des Laufzeitzustands.
  HeroState copyWith({
    int? currentLep,
    int? currentAsp,
    int? currentKap,
    int? currentAu,
    int? erschoepfung,
    int? ueberanstrengung,
    StatModifiers? tempMods,
    AttributeModifiers? tempAttributeMods,
    ActiveSpellEffectsState? activeSpellEffects,
    WundZustand? wpiZustand,
    List<DiceLogEntry>? diceLog,
  }) {
    return HeroState(
      schemaVersion: schemaVersion,
      currentLep: currentLep ?? this.currentLep,
      currentAsp: currentAsp ?? this.currentAsp,
      currentKap: currentKap ?? this.currentKap,
      currentAu: currentAu ?? this.currentAu,
      erschoepfung: erschoepfung ?? this.erschoepfung,
      ueberanstrengung: ueberanstrengung ?? this.ueberanstrengung,
      tempMods: tempMods ?? this.tempMods,
      tempAttributeMods: tempAttributeMods ?? this.tempAttributeMods,
      activeSpellEffects: activeSpellEffects ?? this.activeSpellEffects,
      wpiZustand: wpiZustand ?? this.wpiZustand,
      diceLog: diceLog ?? this.diceLog,
    );
  }

  /// Haengt einen neuen Eintrag an das Wuerfelprotokoll an und trimmt FIFO.
  HeroState withAppendedDiceLog(DiceLogEntry entry) {
    return withAppendedDiceLogEntries(<DiceLogEntry>[entry]);
  }

  /// Haengt mehrere Eintraege an das Wuerfelprotokoll an und trimmt FIFO.
  HeroState withAppendedDiceLogEntries(List<DiceLogEntry> entries) {
    if (entries.isEmpty) {
      return this;
    }
    final next = <DiceLogEntry>[...diceLog, ...entries];
    if (next.length > diceLogMax) {
      next.removeRange(0, next.length - diceLogMax);
    }
    return copyWith(diceLog: List<DiceLogEntry>.unmodifiable(next));
  }

  /// Serialisierung fuer Persistenz (eigene State-Box).
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'currentLep': currentLep,
      'currentAsp': currentAsp,
      'currentKap': currentKap,
      'currentAu': currentAu,
      'erschoepfung': erschoepfung,
      'ueberanstrengung': ueberanstrengung,
      'tempMods': tempMods.toJson(),
      'tempAttributeMods': tempAttributeMods.toJson(),
      'activeSpellEffects': activeSpellEffects.toJson(),
      'wpiZustand': wpiZustand.toJson(),
      'diceLog': diceLog.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  /// Robust gegen fehlende Felder in aelteren Daten.
  static HeroState fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    final rawDiceLog = json['diceLog'] as List?;
    final diceLog = rawDiceLog == null
        ? const <DiceLogEntry>[]
        : List<DiceLogEntry>.unmodifiable(
            rawDiceLog.whereType<Map>().map(
              (e) => DiceLogEntry.fromJson(e.cast<String, dynamic>()),
            ),
          );
    return HeroState(
      schemaVersion: 6,
      currentLep: getInt('currentLep'),
      currentAsp: getInt('currentAsp'),
      currentKap: getInt('currentKap'),
      currentAu: getInt('currentAu'),
      erschoepfung: getInt('erschoepfung'),
      ueberanstrengung: getInt('ueberanstrengung'),
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
      wpiZustand: WundZustand.fromJson(
        (json['wpiZustand'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      diceLog: diceLog,
    );
  }
}
