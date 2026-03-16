/// Einzelner Bewegungswert eines Begleiters (z.B. Schwimmen, Fliegen).
class HeroCompanionSpeed {
  const HeroCompanionSpeed({this.art = '', this.wert = 0});

  /// Art der Bewegung (z.B. 'zu Fuß', 'Schwimmen', 'Fliegen').
  final String art;

  /// Geschwindigkeitswert.
  final int wert;

  HeroCompanionSpeed copyWith({String? art, int? wert}) {
    return HeroCompanionSpeed(
      art: art ?? this.art,
      wert: wert ?? this.wert,
    );
  }

  Map<String, dynamic> toJson() => {'art': art, 'wert': wert};

  static HeroCompanionSpeed fromJson(Map<String, dynamic> json) {
    return HeroCompanionSpeed(
      art: (json['art'] as String?) ?? '',
      wert: (json['wert'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionSpeed && art == other.art && wert == other.wert;

  @override
  int get hashCode => Object.hash(art, wert);
}
