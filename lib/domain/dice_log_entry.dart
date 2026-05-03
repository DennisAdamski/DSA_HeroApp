import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
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
    };
  }

  static DiceLogEntry fromJson(Map<String, dynamic> json) {
    return DiceLogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      type: _probeTypeFromName(json['type'] as String?),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      diceValues: ((json['diceValues'] as List?) ?? const <dynamic>[])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      targetValue: (json['targetValue'] as num?)?.toInt(),
      automaticOutcome: _automaticOutcomeFromName(
        json['automaticOutcome'] as String?,
      ),
      total: (json['total'] as num?)?.toInt(),
      isNeutral: json['isNeutral'] as bool? ?? false,
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

ProbeType _probeTypeFromName(String? name) {
  for (final value in ProbeType.values) {
    if (value.name == name) return value;
  }
  return ProbeType.attribute;
}

AutomaticOutcome _automaticOutcomeFromName(String? name) {
  for (final value in AutomaticOutcome.values) {
    if (value.name == name) return value;
  }
  return AutomaticOutcome.none;
}
