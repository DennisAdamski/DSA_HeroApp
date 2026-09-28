import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

class BoughtStats {
  const BoughtStats({
    this.lep = 0,
    this.au = 0,
    this.asp = 0,
    this.kap = 0,
    this.mr = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  final int lep;
  final int au;
  final int asp;
  final int kap;
  final int mr;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'lep',
    'au',
    'asp',
    'kap',
    'mr',
  };

  BoughtStats copyWith({
    int? lep,
    int? au,
    int? asp,
    int? kap,
    int? mr,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return BoughtStats(
      lep: lep ?? this.lep,
      au: au ?? this.au,
      asp: asp ?? this.asp,
      kap: kap ?? this.kap,
      mr: mr ?? this.mr,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'lep': lep,
      'au': au,
      'asp': asp,
      'kap': kap,
      'mr': mr,
    }, unbekannteFelder);
  }

  static BoughtStats fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return BoughtStats(
      lep: getInt('lep'),
      au: getInt('au'),
      asp: getInt('asp'),
      kap: getInt('kap'),
      mr: getInt('mr'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
