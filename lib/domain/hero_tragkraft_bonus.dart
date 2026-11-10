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

  /// Zusätzliche Tragkraft in Stein (1 Stein = 1 kg); nie negativ.
  final int stein;

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
    return HeroTragkraftBonus(
      id: id ?? this.id,
      name: name ?? this.name,
      stein: stein ?? this.stein,
      kk: kk ?? this.kk,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'id': id,
      'name': name,
      'stein': stein,
      // Nur bei Belegung, damit der Eintrag ohne KK-Erhöhung schlank bleibt.
      if (kk != 0) 'kk': kk,
    }, unbekannteFelder);
  }

  /// Liest eine Quelle; `null` ohne verwertbare [id].
  static HeroTragkraftBonus? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) return null;
    final stein = (json['stein'] as num?)?.toInt() ?? 0;
    return HeroTragkraftBonus(
      id: id,
      name: (json['name'] as String?) ?? '',
      stein: stein < 0 ? 0 : stein,
      kk: (json['kk'] as num?)?.toInt() ?? 0,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
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
