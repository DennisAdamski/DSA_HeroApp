import 'package:dsa_heldenverwaltung/domain/json_helpers.dart';

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
  });

  const Attributes.zero()
    : mu = 0,
      kl = 0,
      inn = 0,
      ch = 0,
      ff = 0,
      ge = 0,
      ko = 0,
      kk = 0;

  final int mu; // Mut: Tapferkeit, Willenskraft, magische Kraftquelle
  final int kl; // Klugheit: Denkvermögen, Lernfähigkeit
  final int inn; // Intuition: Wahrnehmung, Menschenkenntnis
  final int ch; // Charisma: Ausstrahlung, Überzeugungskraft
  final int ff; // Fingerfertigkeit: Feinmotorik, Geschick der Hände
  final int ge; // Gewandtheit: Körperkoordination, Schnelligkeit
  final int ko; // Konstitution: Zähigkeit, Gesundheit
  final int kk; // Körperkraft: Muskeln, Hebeln, Tragen

  Attributes copyWith({
    int? mu,
    int? kl,
    int? inn,
    int? ch,
    int? ff,
    int? ge,
    int? ko,
    int? kk,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mu': mu,
      'kl': kl,
      'inn': inn,
      'ch': ch,
      'ff': ff,
      'ge': ge,
      'ko': ko,
      'kk': kk,
    };
  }

  // Lenient: fehlende Felder ergeben 0, damit aeltere Schemata
  // (vor schemaVersion 4) weiterhin lesbar bleiben.
  // num? → toInt() behandelt auch importierte float-Werte korrekt.
  static Attributes fromJson(Map<String, dynamic> json) {
    return Attributes(
      mu: readJsonInt(json, 'mu'),
      kl: readJsonInt(json, 'kl'),
      inn: readJsonInt(json, 'inn'),
      ch: readJsonInt(json, 'ch'),
      ff: readJsonInt(json, 'ff'),
      ge: readJsonInt(json, 'ge'),
      ko: readJsonInt(json, 'ko'),
      kk: readJsonInt(json, 'kk'),
    );
  }
}
