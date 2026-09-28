import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Die acht DSA-Grundeigenschaften eines Helden (unveraenderlich).
///
/// Kuerzel und Namen:
///   mu  = Mut            kl  = Klugheit       inn = Intuition    ch  = Charisma
///   ff  = Fingerfertigkeit  ge = Gewandtheit  ko  = Konstitution  kk  = Koerperkraft
///
/// Alle Felder sind unveraenderlich; Aenderungen erfolgen ueber [copyWith].
class Attributes {
  const Attributes({
    required this.mu,
    required this.kl,
    required this.inn,
    required this.ch,
    required this.ff,
    required this.ge,
    required this.ko,
    required this.kk,
    this.unbekannteFelder = const <String, Object?>{},
  });

  const Attributes.zero()
    : mu = 0,
      kl = 0,
      inn = 0,
      ch = 0,
      ff = 0,
      ge = 0,
      ko = 0,
      kk = 0,
      unbekannteFelder = const <String, Object?>{};

  final int mu; // Mut: Tapferkeit, Willenskraft, magische Kraftquelle
  final int kl; // Klugheit: Denkvermögen, Lernfähigkeit
  final int inn; // Intuition: Wahrnehmung, Menschenkenntnis
  final int ch; // Charisma: Ausstrahlung, Überzeugungskraft
  final int ff; // Fingerfertigkeit: Feinmotorik, Geschick der Hände
  final int ge; // Gewandtheit: Körperkoordination, Schnelligkeit
  final int ko; // Konstitution: Zähigkeit, Gesundheit
  final int kk; // Körperkraft: Muskeln, Hebeln, Tragen

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'mu',
    'kl',
    'inn',
    'ch',
    'ff',
    'ge',
    'ko',
    'kk',
  };

  Attributes copyWith({
    int? mu,
    int? kl,
    int? inn,
    int? ch,
    int? ff,
    int? ge,
    int? ko,
    int? kk,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return Attributes(
      mu: mu ?? this.mu,
      kl: kl ?? this.kl,
      inn: inn ?? this.inn,
      ch: ch ?? this.ch,
      ff: ff ?? this.ff,
      ge: ge ?? this.ge,
      ko: ko ?? this.ko,
      kk: kk ?? this.kk,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Uebernimmt die acht Werte aus [quelle] und behaelt die unbekannten
  /// Felder dieser Instanz.
  ///
  /// Fuer Werte, die neu errechnet oder aus Formularfeldern gelesen werden
  /// (etwa effektive Startwerte), damit ein Neuaufbau Felder einer neueren
  /// App-Version nicht verwirft.
  Attributes uebernimmWerte(Attributes quelle) {
    return copyWith(
      mu: quelle.mu,
      kl: quelle.kl,
      inn: quelle.inn,
      ch: quelle.ch,
      ff: quelle.ff,
      ge: quelle.ge,
      ko: quelle.ko,
      kk: quelle.kk,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'mu': mu,
      'kl': kl,
      'inn': inn,
      'ch': ch,
      'ff': ff,
      'ge': ge,
      'ko': ko,
      'kk': kk,
    }, unbekannteFelder);
  }

  // Lenient: fehlende Felder ergeben 0, damit aeltere Schemata
  // (vor schemaVersion 4) weiterhin lesbar bleiben.
  // num? → toInt() behandelt auch importierte float-Werte korrekt.
  static Attributes fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return Attributes(
      mu: getInt('mu'),
      kl: getInt('kl'),
      inn: getInt('inn'),
      ch: getInt('ch'),
      ff: getInt('ff'),
      ge: getInt('ge'),
      ko: getInt('ko'),
      kk: getInt('kk'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
