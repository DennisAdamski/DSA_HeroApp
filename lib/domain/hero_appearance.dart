/// Aeussere Erscheinung eines Helden.
class HeroAppearance {
  const HeroAppearance({
    this.geschlecht = '',
    this.alter = '',
    this.groesse = '',
    this.gewicht = '',
    this.haarfarbe = '',
    this.augenfarbe = '',
    this.aussehen = '',
  });

  final String geschlecht;
  final String alter;
  final String groesse;
  final String gewicht;
  final String haarfarbe;
  final String augenfarbe;
  final String aussehen;

  HeroAppearance copyWith({
    String? geschlecht,
    String? alter,
    String? groesse,
    String? gewicht,
    String? haarfarbe,
    String? augenfarbe,
    String? aussehen,
  }) {
    return HeroAppearance(
      geschlecht: geschlecht ?? this.geschlecht,
      alter: alter ?? this.alter,
      groesse: groesse ?? this.groesse,
      gewicht: gewicht ?? this.gewicht,
      haarfarbe: haarfarbe ?? this.haarfarbe,
      augenfarbe: augenfarbe ?? this.augenfarbe,
      aussehen: aussehen ?? this.aussehen,
    );
  }

  /// Serialisiert als flache Map (Felder auf Root-Ebene).
  Map<String, dynamic> toJson() => {
        'geschlecht': geschlecht,
        'alter': alter,
        'groesse': groesse,
        'gewicht': gewicht,
        'haarfarbe': haarfarbe,
        'augenfarbe': augenfarbe,
        'aussehen': aussehen,
      };

  /// Liest aus einer flachen Map (Felder auf Root-Ebene).
  static HeroAppearance fromJson(Map<String, dynamic> json) {
    return HeroAppearance(
      geschlecht: (json['geschlecht'] as String?) ?? '',
      alter: (json['alter'] as String?) ?? '',
      groesse: (json['groesse'] as String?) ?? '',
      gewicht: (json['gewicht'] as String?) ?? '',
      haarfarbe: (json['haarfarbe'] as String?) ?? '',
      augenfarbe: (json['augenfarbe'] as String?) ?? '',
      aussehen: (json['aussehen'] as String?) ?? '',
    );
  }
}
