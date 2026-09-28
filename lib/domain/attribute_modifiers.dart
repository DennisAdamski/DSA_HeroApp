import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

class AttributeModifiers {
  const AttributeModifiers({
    this.mu = 0,
    this.kl = 0,
    this.inn = 0,
    this.ch = 0,
    this.ff = 0,
    this.ge = 0,
    this.ko = 0,
    this.kk = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  final int mu;
  final int kl;
  final int inn;
  final int ch;
  final int ff;
  final int ge;
  final int ko;
  final int kk;

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

  AttributeModifiers copyWith({
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
    return AttributeModifiers(
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
  /// Felder dieser Instanz (wie `Attributes.uebernimmWerte`).
  AttributeModifiers uebernimmWerte(AttributeModifiers quelle) {
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

  AttributeModifiers operator +(AttributeModifiers other) {
    return AttributeModifiers(
      mu: mu + other.mu,
      kl: kl + other.kl,
      inn: inn + other.inn,
      ch: ch + other.ch,
      ff: ff + other.ff,
      ge: ge + other.ge,
      ko: ko + other.ko,
      kk: kk + other.kk,
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

  static AttributeModifiers fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return AttributeModifiers(
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
