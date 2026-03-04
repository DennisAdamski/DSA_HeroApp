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

  final int mu;  // Mut: Tapferkeit, Willenskraft, magische Kraftquelle
  final int kl;  // Klugheit: Denkvermögen, Lernfähigkeit
  final int inn; // Intuition: Wahrnehmung, Menschenkenntnis
  final int ch;  // Charisma: Ausstrahlung, Überzeugungskraft
  final int ff;  // Fingerfertigkeit: Feinmotorik, Geschick der Hände
  final int ge;  // Gewandtheit: Körperkoordination, Schnelligkeit
  final int ko;  // Konstitution: Zähigkeit, Gesundheit
  final int kk;  // Körperkraft: Muskeln, Hebeln, Tragen

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
    );
  }
}
