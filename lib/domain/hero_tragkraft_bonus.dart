import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Dauerhafte Erhöhung der Tragkraft (SPIEL-02, Block „Dabei“).
///
/// Erfasst nur, was lange hält: eine Bärenrune bis zur nächsten Sonnenwende,
/// ein dauerhaft wirkender Gegenstand oder Segen. Kurzzeitzauber gehören nicht
/// hierher; sie laufen als Effekte. Die Quelle trägt nur ihr Ergebnis in Stein
/// (und eine eventuelle KK-Erhöhung nur für die Tragkraft), nie eine Rechnung:
/// Wie sich ein Wert ergibt (etwa RkP* × 10 bei der Bärenrune), steht beim
/// Eintrag als Name oder entsteht beim Anlegen.
///
/// Die [id] ist zufällig vergeben und bleibt beim Bearbeiten gleich; so
/// führt der Sync-Merge die Liste je Element zusammen.
class HeroTragkraftBonus {
  /// Erstellt eine Tragkraftquelle.
  const HeroTragkraftBonus({
    required this.id,
    this.name = '',
    this.stein = 0,
    this.kk = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile ID innerhalb des Helden.
  final String id;

  /// Anzeigename, z. B. „Bärenrune (RkP* 7)“.
  final String name;

  /// Zusätzliche Tragkraft in Stein (1 Stein = 1 kg), wie gespeichert.
  ///
  /// Der Leser verändert den Wert nicht; die Regelrechnung zählt über
  /// [wirksamerStein], das negative Werte als 0 behandelt.
  final int stein;

  /// Stein, der in die Tragkraft eingeht: nie negativ.
  int get wirksamerStein => stein < 0 ? 0 : stein;

  /// KK-Erhöhung, die nur die Tragkraft betrifft (Hausregel zur Bärenrune:
  /// KK +1). Die Eigenschaft im Bogen ändert sich dadurch nicht. Nur bei
  /// Belegung im JSON.
  final int kk;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'name',
    'stein',
    'kk',
  };

  /// Gezeigter Name; ein leerer Name heißt „Tragkraftbonus“.
  String get anzeigeName =>
      name.trim().isEmpty ? 'Tragkraftbonus' : name.trim();

  HeroTragkraftBonus copyWith({
    String? id,
    String? name,
    int? stein,
    int? kk,
    Map<String, Object?>? unbekannteFelder,
  }) {
    // Ein neu gesetztes Feld ersetzt den Rohwert eines unlesbaren Vorgängers.
    final felder = unbekannteFelder ?? this.unbekannteFelder;
    final ohneErsetzte = <String, Object?>{
      for (final eintrag in felder.entries)
        if (!(name != null && eintrag.key == 'name') &&
            !(stein != null && eintrag.key == 'stein') &&
            !(kk != null && eintrag.key == 'kk'))
          eintrag.key: eintrag.value,
    };
    return HeroTragkraftBonus(
      id: id ?? this.id,
      name: name ?? this.name,
      stein: stein ?? this.stein,
      kk: kk ?? this.kk,
      unbekannteFelder: ohneErsetzte.length == felder.length
          ? felder
          : Map<String, Object?>.unmodifiable(ohneErsetzte),
    );
  }

  Map<String, dynamic> toJson() {
    // Ein Feld mit unlesbarem Rohwert steht in [unbekannteFelder] und wird
    // unverändert zurückgeschrieben, statt durch den Ersatzwert zu ersetzen.
    return mitUnbekanntenFeldern(<String, dynamic>{
      'id': id,
      if (!unbekannteFelder.containsKey('name')) 'name': name,
      if (!unbekannteFelder.containsKey('stein')) 'stein': stein,
      // Nur bei Belegung, damit der Eintrag ohne KK-Erhöhung schlank bleibt.
      if (kk != 0 && !unbekannteFelder.containsKey('kk')) 'kk': kk,
    }, unbekannteFelder);
  }

  /// Liest eine Quelle; `null` ohne verwertbare [id].
  static HeroTragkraftBonus? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) return null;
    // Unlesbare Rohwerte (etwa Text statt Zahl) bleiben unverändert erhalten;
    // gerechnet wird mit dem Ersatzwert. Negative Zahlen bleiben stehen.
    final unlesbar = <String, Object?>{};
    final name = json['name'];
    final stein = json['stein'];
    final kk = json['kk'];
    if (name != null && name is! String) unlesbar['name'] = name;
    if (stein != null && stein is! num) unlesbar['stein'] = stein;
    if (kk != null && kk is! num) unlesbar['kk'] = kk;
    final unbekannt = <String, Object?>{
      ...sammleUnbekannteFelder(json, jsonSchluessel),
      for (final eintrag in unlesbar.entries)
        eintrag.key: kopiereJsonRohwert(eintrag.value),
    };
    return HeroTragkraftBonus(
      id: id,
      name: name is String ? name : '',
      stein: stein is num ? stein.toInt() : 0,
      kk: kk is num ? kk.toInt() : 0,
      unbekannteFelder: unbekannt.isEmpty
          ? const <String, Object?>{}
          : Map<String, Object?>.unmodifiable(unbekannt),
    );
  }
}

/// Liest die Liste der Tragkraftquellen; doppelte IDs und unlesbare Einträge
/// entfallen. Die erste Fundstelle zählt, die Reihenfolge bleibt erhalten.
List<HeroTragkraftBonus> leseTragkraftBoni(Object? roh) {
  if (roh is! List) return const <HeroTragkraftBonus>[];
  final gesehen = <String>{};
  final ergebnis = <HeroTragkraftBonus>[];
  for (final eintrag in roh) {
    if (eintrag is! Map) continue;
    final bonus = HeroTragkraftBonus.fromJson(
      Map<String, dynamic>.from(eintrag),
    );
    if (bonus != null && gesehen.add(bonus.id)) ergebnis.add(bonus);
  }
  return List<HeroTragkraftBonus>.unmodifiable(ergebnis);
}
