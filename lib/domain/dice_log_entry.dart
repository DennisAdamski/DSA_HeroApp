import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Eintrag im pro Held persistierten Wuerfelprotokoll.
///
/// Haelt das verdichtete Ergebnis einer Probe fuer die Anzeige im
/// Inspector-Probe-Tab fest. Volle `ProbeResult`-Details werden bewusst
/// NICHT serialisiert – nur was die Liste rendern muss.
class DiceLogEntry {
  const DiceLogEntry({
    required this.timestamp,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.success,
    required this.diceValues,
    this.targetValue,
    this.automaticOutcome = AutomaticOutcome.none,
    this.total,
    this.isNeutral = false,
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Zeitpunkt der Probe (UTC empfohlen).
  final DateTime timestamp;

  /// Probeart (Eigenschaft, Talent, Zauber, Kampf …).
  final ProbeType type;

  /// Anzeigetitel der Probe, z. B. `Eigenschaftsprobe: KL`.
  final String title;

  /// Sekundaere Beschreibung (Eigenschaftskette, Waffe, ZfW …).
  final String subtitle;

  /// `true`, wenn die Probe gelungen ist.
  final bool success;

  /// Roh-Wuerfelwerte in Wurfreihenfolge.
  final List<int> diceValues;

  /// Zielwert (z. B. Eigenschaftswert) – `null` bei Initiative/Schaden.
  final int? targetValue;

  /// Automatischer Erfolg/Fehlschlag, falls vorhanden.
  final AutomaticOutcome automaticOutcome;

  /// Summe (z. B. Initiative oder Schadenswurf) – `null` bei binaerer Probe.
  final int? total;

  /// Kennzeichnet Wuerfe ohne Erfolgs-/Misslingenslogik.
  final bool isNeutral;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzaehlungswerte einer neueren App-Version (JSON-Schluessel
  /// -> Rohwert). Die Felder tragen den Ersatzwert, mit dem Regeln rechnen;
  /// geschrieben wird der Rohwert, bis jemand das Feld auf einen anderen Wert
  /// setzt (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich der nur bedingt
  /// geschriebenen; alles andere bleibt erhalten. Eintraege sind
  /// unveraenderlich und werden nur angehaengt oder verdraengt.
  static const Set<String> jsonSchluessel = <String>{
    'timestamp',
    'type',
    'title',
    'subtitle',
    'success',
    'diceValues',
    'targetValue',
    'automaticOutcome',
    'total',
    'isNeutral',
  };

  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'success': success,
        'diceValues': List<int>.from(diceValues),
        if (targetValue != null) 'targetValue': targetValue,
        'automaticOutcome': automaticOutcome.name,
        if (total != null) 'total': total,
        if (isNeutral) 'isNeutral': true,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  static DiceLogEntry fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    return DiceLogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      type: leseEnumWert(
        json['type'],
        'type',
        erkenne: (roh) => enumNachName(ProbeType.values, roh),
        ersatz: ProbeType.attribute,
        unbekannt: enumRoh,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      diceValues: ((json['diceValues'] as List?) ?? const <dynamic>[])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      targetValue: (json['targetValue'] as num?)?.toInt(),
      automaticOutcome: leseEnumWert(
        json['automaticOutcome'],
        'automaticOutcome',
        erkenne: (roh) => enumNachName(AutomaticOutcome.values, roh),
        ersatz: AutomaticOutcome.none,
        unbekannt: enumRoh,
      ),
      total: (json['total'] as num?)?.toInt(),
      isNeutral: json['isNeutral'] as bool? ?? false,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }
}

/// Mappt ein vollstaendiges `ProbeResult` auf einen verschlankten Logeintrag.
DiceLogEntry diceLogEntryFromResult(ProbeResult result, {DateTime? timestamp}) {
  final request = result.request;
  final usesTotal = request.usesSummedTotal;
  return DiceLogEntry(
    timestamp: (timestamp ?? DateTime.now()).toUtc(),
    type: request.type,
    title: request.title,
    subtitle: request.subtitle,
    success: result.success,
    diceValues: List<int>.from(result.diceValues),
    targetValue: usesTotal
        ? null
        : (result.effectiveTargetValues.isNotEmpty
              ? result.effectiveTargetValues.first
              : null),
    automaticOutcome: result.automaticOutcome,
    total: usesTotal ? result.total : null,
    isNeutral: usesTotal,
  );
}

/// Baut einen neutralen Protokolleintrag fuer einfache Summenwuerfe.
DiceLogEntry diceLogEntryFromRoll({
  required String title,
  required String subtitle,
  required List<int> diceValues,
  DiceSpec? diceSpec,
  ProbeType type = ProbeType.genericRoll,
  int? total,
  DateTime? timestamp,
}) {
  final computedTotal =
      total ??
      diceValues.fold<int>(0, (sum, value) => sum + value) +
          (diceSpec?.modifier ?? 0);
  return DiceLogEntry(
    timestamp: (timestamp ?? DateTime.now()).toUtc(),
    type: type,
    title: title,
    subtitle: subtitle,
    success: true,
    diceValues: List<int>.from(diceValues),
    automaticOutcome: AutomaticOutcome.none,
    total: computedTotal,
    isNeutral: true,
  );
}

/// Baut einen Protokolleintrag fuer einen einfachen W20-Zielwertwurf.
DiceLogEntry diceLogEntryFromSimpleCheck({
  required String title,
  required String subtitle,
  required int roll,
  required int targetValue,
  ProbeType type = ProbeType.attribute,
  DateTime? timestamp,
}) {
  var automaticOutcome = AutomaticOutcome.none;
  var success = roll <= targetValue;
  if (roll == 1) {
    automaticOutcome = AutomaticOutcome.success;
    success = true;
  } else if (roll == 20) {
    automaticOutcome = AutomaticOutcome.failure;
    success = false;
  }
  return DiceLogEntry(
    timestamp: (timestamp ?? DateTime.now()).toUtc(),
    type: type,
    title: title,
    subtitle: subtitle,
    success: success,
    diceValues: <int>[roll],
    targetValue: targetValue,
    automaticOutcome: automaticOutcome,
    total: null,
  );
}
