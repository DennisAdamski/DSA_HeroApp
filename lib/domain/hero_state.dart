import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';

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
    this.buchungen = const <ZustandsBuchung>[],
    this.lastModified,
    this.unbekannteFelder = const <String, Object?>{},
  });

  const HeroState.empty()
    : schemaVersion = 6,
      lastModified = null,
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
      diceLog = const <DiceLogEntry>[],
      buchungen = const <ZustandsBuchung>[],
      unbekannteFelder = const <String, Object?>{};

  /// Maximale Anzahl persistierter Wuerfelprotokoll-Eintraege pro Held.
  ///
  /// Sessiontauglich dimensioniert, damit auch ein langer Spielabend im
  /// Protokoll nachvollziehbar bleibt.
  static const int diceLogMax = 50;

  /// Maximale Anzahl gespeicherter fachlicher Buchungen pro Held.
  ///
  /// Wie das Würfelprotokoll begrenzt; eine Gegenbuchung ist immer jünger
  /// als ihr Original und wird deshalb nach ihm verdrängt.
  static const int buchungenMax = 50;

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

  /// Fachliche Buchungen (ARCH-06), neueste am Ende.
  ///
  /// Halten fest, was ein Treffer tatsächlich verändert hat, damit er sich
  /// als Gegenbuchung zurücknehmen lässt und eine Wiederholung derselben
  /// Buchung nichts doppelt bucht. Nur bei Belegung im JSON, damit
  /// Bestandszustände ihren Inhalts-Hash behalten.
  final List<ZustandsBuchung> buchungen;

  /// Zeitpunkt der letzten Speicherung, analog zu `HeroSheet.lastModified`.
  ///
  /// Rein informativ: Der Wert bleibt aus `heroStateContentHash` und damit aus
  /// der Konflikterkennung heraus, damit ein blosses Neuspeichern keine Frage
  /// ausloest. Gebraucht wird er in der Konflikt-UI, die sonst auf beiden
  /// Seiten `Unbekannt` anzeigt und dem Nutzer die Entscheidung
  /// "welche Version ist neuer?" ohne Datengrundlage abverlangt.
  final DateTime? lastModified;

  /// JSON-Felder oberster Ebene, die diese Version nicht kennt; werden beim
  /// Speichern unveraendert zurueckgeschrieben (Befund ARCH-07-B6).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'schemaVersion',
    'currentLep',
    'currentAsp',
    'currentKap',
    'currentAu',
    'erschoepfung',
    'ueberanstrengung',
    'tempMods',
    'tempAttributeMods',
    'activeSpellEffects',
    'wpiZustand',
    'diceLog',
    'buchungen',
    'lastModified',
  };

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
    List<ZustandsBuchung>? buchungen,
    DateTime? lastModified,
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
      buchungen: buchungen ?? this.buchungen,
      lastModified: lastModified ?? this.lastModified,
      unbekannteFelder: unbekannteFelder,
    );
  }

  /// Hängt eine fachliche Buchung an und verdrängt die ältesten über
  /// [buchungenMax].
  HeroState withBuchung(ZustandsBuchung buchung) {
    final next = <ZustandsBuchung>[...buchungen, buchung];
    if (next.length > buchungenMax) {
      next.removeRange(0, next.length - buchungenMax);
    }
    return copyWith(buchungen: List<ZustandsBuchung>.unmodifiable(next));
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
    final json = <String, dynamic>{
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
      if (buchungen.isNotEmpty)
        'buchungen': buchungen
            .map((buchung) => buchung.toJson())
            .toList(growable: false),
      if (lastModified != null)
        'lastModified': lastModified!.toUtc().toIso8601String(),
    };
    return mitUnbekanntenFeldern(json, unbekannteFelder);
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
    final rawBuchungen = json['buchungen'] as List?;
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
      buchungen: rawBuchungen == null
          ? const <ZustandsBuchung>[]
          : List<ZustandsBuchung>.unmodifiable(
              rawBuchungen.whereType<Map>().map(
                (e) => ZustandsBuchung.fromJson(e.cast<String, dynamic>()),
              ),
            ),
      lastModified: DateTime.tryParse(json['lastModified'] as String? ?? ''),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
