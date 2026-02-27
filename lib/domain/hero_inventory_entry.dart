class HeroInventoryEntry {
  const HeroInventoryEntry({
    this.gegenstand = '',
    this.woGetragen = '',
    this.typ = '',
    this.welchesAbenteuer = '',
    this.gewicht = '',
    this.wert = '',
    this.artefakt = '',
    this.anzahl = '',
    this.amKoerper = '',
    this.woDann = '',
    this.gruppe = '',
    this.beschreibung = '',
  });

  final String gegenstand;
  final String woGetragen;
  final String typ;
  final String welchesAbenteuer;
  final String gewicht;
  final String wert;
  final String artefakt;
  final String anzahl;
  final String amKoerper;
  final String woDann;
  final String gruppe;
  final String beschreibung;

  HeroInventoryEntry copyWith({
    String? gegenstand,
    String? woGetragen,
    String? typ,
    String? welchesAbenteuer,
    String? gewicht,
    String? wert,
    String? artefakt,
    String? anzahl,
    String? amKoerper,
    String? woDann,
    String? gruppe,
    String? beschreibung,
  }) {
    return HeroInventoryEntry(
      gegenstand: gegenstand ?? this.gegenstand,
      woGetragen: woGetragen ?? this.woGetragen,
      typ: typ ?? this.typ,
      welchesAbenteuer: welchesAbenteuer ?? this.welchesAbenteuer,
      gewicht: gewicht ?? this.gewicht,
      wert: wert ?? this.wert,
      artefakt: artefakt ?? this.artefakt,
      anzahl: anzahl ?? this.anzahl,
      amKoerper: amKoerper ?? this.amKoerper,
      woDann: woDann ?? this.woDann,
      gruppe: gruppe ?? this.gruppe,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gegenstand': gegenstand,
      'woGetragen': woGetragen,
      'typ': typ,
      'welchesAbenteuer': welchesAbenteuer,
      'gewicht': gewicht,
      'wert': wert,
      'artefakt': artefakt,
      'anzahl': anzahl,
      'amKoerper': amKoerper,
      'woDann': woDann,
      'gruppe': gruppe,
      'beschreibung': beschreibung,
    };
  }

  static HeroInventoryEntry fromJson(Map<String, dynamic> json) {
    String getString(String key) => (json[key] as String?) ?? '';

    return HeroInventoryEntry(
      gegenstand: getString('gegenstand'),
      woGetragen: getString('woGetragen'),
      typ: getString('typ'),
      welchesAbenteuer: getString('welchesAbenteuer'),
      gewicht: getString('gewicht'),
      wert: getString('wert'),
      artefakt: getString('artefakt'),
      anzahl: getString('anzahl'),
      amKoerper: getString('amKoerper'),
      woDann: getString('woDann'),
      gruppe: getString('gruppe'),
      beschreibung: getString('beschreibung'),
    );
  }
}
