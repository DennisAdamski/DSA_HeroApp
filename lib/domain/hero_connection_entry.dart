/// Beschreibt eine wichtige Verbindung oder Kontaktperson eines Helden.
class HeroConnectionEntry {
  /// Erzeugt einen persistierbaren Verbindungseintrag.
  const HeroConnectionEntry({
    this.name = '',
    this.ort = '',
    this.sozialstatus = '',
    this.loyalitaet = '',
    this.beschreibung = '',
  });

  /// Anzeigename der Verbindung.
  final String name;

  /// Relevanter Ort oder Aufenthaltsort.
  final String ort;

  /// Sozialstatus der Verbindung als Freitext.
  final String sozialstatus;

  /// Loyalitaet bzw. Beziehung zum Helden.
  final String loyalitaet;

  /// Ausfuehrliche Beschreibung oder Hintergrundnotiz.
  final String beschreibung;

  /// Liefert eine neue Instanz mit gezielt ersetzten Feldern.
  HeroConnectionEntry copyWith({
    String? name,
    String? ort,
    String? sozialstatus,
    String? loyalitaet,
    String? beschreibung,
  }) {
    return HeroConnectionEntry(
      name: name ?? this.name,
      ort: ort ?? this.ort,
      sozialstatus: sozialstatus ?? this.sozialstatus,
      loyalitaet: loyalitaet ?? this.loyalitaet,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  /// Serialisiert den Eintrag fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'ort': ort,
      'sozialstatus': sozialstatus,
      'loyalitaet': loyalitaet,
      'beschreibung': beschreibung,
    };
  }

  /// Laedt einen Verbindungseintrag tolerant gegenueber fehlenden Feldern.
  static HeroConnectionEntry fromJson(Map<String, dynamic> json) {
    String getString(String key) => (json[key] as String?) ?? '';

    return HeroConnectionEntry(
      name: getString('name'),
      ort: getString('ort'),
      sozialstatus: getString('sozialstatus'),
      loyalitaet: getString('loyalitaet'),
      beschreibung: getString('beschreibung'),
    );
  }
}
