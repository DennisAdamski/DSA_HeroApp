import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Zeiteinheiten, in denen DSA-Zauber ihre Wirkungsdauer angeben.
///
/// Die Auswahl deckt die in den Zauberbeschreibungen gebraeuchlichen Einheiten
/// ab (Liber Cantiones, Spalte `Wirkungsdauer`). `permanent` steht fuer
/// Wirkungsdauern ohne Ablauf ("dauerhaft", "bis zur Aufloesung").
enum SpellDurationUnit {
  /// Einzelne Aktionen innerhalb einer Kampfrunde.
  aktionen,

  /// Kampfrunden (KR), die uebliche Kampfzeiteinheit.
  kampfrunden,

  /// Spielrunden (SR), entspricht fuenf Minuten.
  spielrunden,

  /// Minuten fuer laengere, nicht kampfbezogene Wirkungen.
  minuten,

  /// Stunden fuer sehr lange Wirkungen.
  stunden,

  /// Tage fuer Wirkungen ueber mehrere Spieltage.
  tage,

  /// Wirkungen ohne festes Ende; ein Countdown entfaellt.
  permanent,
}

/// Wirkungsdauer eines laufenden Zaubereffekts inklusive Restlaufzeit.
///
/// [amount] ist die urspruenglich gewuerfelte bzw. eingetragene Gesamtdauer,
/// [remaining] die noch verbleibende Restdauer in derselben [unit]. Beide
/// Werte werden getrennt gehalten, damit am Spieltisch heruntergezaehlt werden
/// kann, ohne die Ausgangsdauer zu verlieren.
class SpellDuration {
  /// Erstellt eine Wirkungsdauer; ohne [remaining] laeuft sie voll.
  SpellDuration({
    required int amount,
    required this.unit,
    int? remaining,
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  }) : amount = amount < 0 ? 0 : amount,
       remaining = _clampRemaining(remaining ?? amount, amount);

  /// Gesamtdauer in [unit].
  final int amount;

  /// Verbleibende Dauer in [unit]; nie negativ und nie groesser als [amount].
  final int remaining;

  /// Zeiteinheit der Wirkungsdauer.
  final SpellDurationUnit unit;

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
    'amount',
    'remaining',
    'unit',
  };

  /// Wirkungsdauern ohne Ablauf werden nie als abgelaufen gemeldet.
  bool get isPermanent => unit == SpellDurationUnit.permanent;

  /// `true`, sobald die Restdauer aufgebraucht ist.
  bool get isExpired => !isPermanent && amount > 0 && remaining <= 0;

  /// Gibt eine Kopie mit geaenderten Feldern zurueck.
  ///
  /// Wird [amount] ohne eigenes [remaining] gesetzt, laeuft die Wirkungsdauer
  /// wieder voll -- eine neue Gesamtdauer bedeutet in der Praxis, dass der
  /// Zauber neu gewirkt oder korrigiert wurde.
  SpellDuration copyWith({
    int? amount,
    int? remaining,
    SpellDurationUnit? unit,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    final nextAmount = amount ?? this.amount;
    final nextRemaining = remaining ?? amount ?? this.remaining;
    return SpellDuration(
      amount: nextAmount,
      remaining: nextRemaining,
      unit: unit ?? this.unit,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'unit': unit != null && unit != this.unit,
          }),
    );
  }

  /// Serialisiert die Wirkungsdauer fuer Persistenz und Sync.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'amount': amount,
        'remaining': remaining,
        'unit': unit.name,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Laedt eine Wirkungsdauer robust aus JSON; unbekannte Einheiten fallen
  /// auf Kampfrunden zurueck, weil das die haeufigste Angabe ist.
  static SpellDuration fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    final unit = leseEnumWert(
      json['unit'],
      'unit',
      erkenne: (roh) => enumNachName(SpellDurationUnit.values, roh),
      ersatz: SpellDurationUnit.kampfrunden,
      unbekannt: enumRoh,
    );
    final amount = (json['amount'] as num?)?.toInt() ?? 0;
    final rawRemaining = (json['remaining'] as num?)?.toInt();
    return SpellDuration(
      amount: amount,
      remaining: rawRemaining,
      unit: unit,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SpellDuration &&
        other.amount == amount &&
        other.remaining == remaining &&
        other.unit == unit &&
        unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder) &&
        unbekannteFelderGleich(unbekannteEnumWerte, other.unbekannteEnumWerte);
  }

  @override
  int get hashCode => Object.hash(
    amount,
    remaining,
    unit,
    unbekannteFelderHash(unbekannteFelder),
    unbekannteFelderHash(unbekannteEnumWerte),
  );
}

// Haelt die Restdauer im gueltigen Bereich [0, amount].
int _clampRemaining(int remaining, int amount) {
  final normalizedAmount = amount < 0 ? 0 : amount;
  if (remaining < 0) {
    return 0;
  }
  return remaining > normalizedAmount ? normalizedAmount : remaining;
}
