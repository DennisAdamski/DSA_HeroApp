import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';

/// Persistenter SE-Pool fuer Eigenschaften.
class HeroAttributeSePool {
  /// Erzeugt einen unveraenderlichen SE-Pool fuer Eigenschaften.
  const HeroAttributeSePool({
    this.mu = 0,
    this.kl = 0,
    this.inn = 0,
    this.ch = 0,
    this.ff = 0,
    this.ge = 0,
    this.ko = 0,
    this.kk = 0,
  });

  /// Verfuegbare Sondererfahrungen fuer Mut.
  final int mu;

  /// Verfuegbare Sondererfahrungen fuer Klugheit.
  final int kl;

  /// Verfuegbare Sondererfahrungen fuer Intuition.
  final int inn;

  /// Verfuegbare Sondererfahrungen fuer Charisma.
  final int ch;

  /// Verfuegbare Sondererfahrungen fuer Fingerfertigkeit.
  final int ff;

  /// Verfuegbare Sondererfahrungen fuer Gewandtheit.
  final int ge;

  /// Verfuegbare Sondererfahrungen fuer Konstitution.
  final int ko;

  /// Verfuegbare Sondererfahrungen fuer Koerperkraft.
  final int kk;

  /// Liest die verfuegbare SE-Anzahl fuer eine Eigenschaft.
  int valueFor(AttributeCode code) {
    return switch (code) {
      AttributeCode.mu => mu,
      AttributeCode.kl => kl,
      AttributeCode.inn => inn,
      AttributeCode.ch => ch,
      AttributeCode.ff => ff,
      AttributeCode.ge => ge,
      AttributeCode.ko => ko,
      AttributeCode.kk => kk,
    };
  }

  /// Liest die verfuegbare SE-Anzahl fuer einen persistierten Schluessel.
  int valueForKey(String key) {
    return switch (key.trim().toLowerCase()) {
      'mu' => mu,
      'kl' => kl,
      'inn' => inn,
      'ch' => ch,
      'ff' => ff,
      'ge' => ge,
      'ko' => ko,
      'kk' => kk,
      _ => 0,
    };
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAttributeSePool copyWith({
    int? mu,
    int? kl,
    int? inn,
    int? ch,
    int? ff,
    int? ge,
    int? ko,
    int? kk,
  }) {
    return HeroAttributeSePool(
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

  /// Passt eine Eigenschaft um [delta] an und begrenzt auf mindestens 0.
  HeroAttributeSePool adjust(AttributeCode code, int delta) {
    final nextValue = _clampNonNegative(valueFor(code) + delta);
    return switch (code) {
      AttributeCode.mu => copyWith(mu: nextValue),
      AttributeCode.kl => copyWith(kl: nextValue),
      AttributeCode.inn => copyWith(inn: nextValue),
      AttributeCode.ch => copyWith(ch: nextValue),
      AttributeCode.ff => copyWith(ff: nextValue),
      AttributeCode.ge => copyWith(ge: nextValue),
      AttributeCode.ko => copyWith(ko: nextValue),
      AttributeCode.kk => copyWith(kk: nextValue),
    };
  }

  /// Serialisiert den Pool fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
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

  /// Laedt einen SE-Pool tolerant gegenueber fehlenden Feldern.
  static HeroAttributeSePool fromJson(Map<String, dynamic> json) {
    int getInt(String key) =>
        _clampNonNegative((json[key] as num?)?.toInt() ?? 0);

    return HeroAttributeSePool(
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

/// Persistenter SE-Pool fuer Grundwerte.
class HeroStatSePool {
  /// Erzeugt einen unveraenderlichen SE-Pool fuer Grundwerte.
  const HeroStatSePool({
    this.lep = 0,
    this.au = 0,
    this.asp = 0,
    this.kap = 0,
    this.mr = 0,
  });

  /// Verfuegbare Sondererfahrungen fuer LeP.
  final int lep;

  /// Verfuegbare Sondererfahrungen fuer Au.
  final int au;

  /// Verfuegbare Sondererfahrungen fuer AsP.
  final int asp;

  /// Verfuegbare Sondererfahrungen fuer KaP.
  final int kap;

  /// Verfuegbare Sondererfahrungen fuer MR.
  final int mr;

  /// Liest die verfuegbare SE-Anzahl fuer einen Grundwertschluessel.
  int valueFor(String key) {
    return switch (key.trim().toLowerCase()) {
      'lep' => lep,
      'au' => au,
      'asp' => asp,
      'kap' => kap,
      'mr' => mr,
      _ => 0,
    };
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroStatSePool copyWith({int? lep, int? au, int? asp, int? kap, int? mr}) {
    return HeroStatSePool(
      lep: lep ?? this.lep,
      au: au ?? this.au,
      asp: asp ?? this.asp,
      kap: kap ?? this.kap,
      mr: mr ?? this.mr,
    );
  }

  /// Passt einen Grundwert um [delta] an und begrenzt auf mindestens 0.
  HeroStatSePool adjust(String key, int delta) {
    final normalizedKey = key.trim().toLowerCase();
    final nextValue = _clampNonNegative(valueFor(normalizedKey) + delta);
    return switch (normalizedKey) {
      'lep' => copyWith(lep: nextValue),
      'au' => copyWith(au: nextValue),
      'asp' => copyWith(asp: nextValue),
      'kap' => copyWith(kap: nextValue),
      'mr' => copyWith(mr: nextValue),
      _ => this,
    };
  }

  /// Serialisiert den Pool fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lep': lep,
      'au': au,
      'asp': asp,
      'kap': kap,
      'mr': mr,
    };
  }

  /// Laedt einen SE-Pool tolerant gegenueber fehlenden Feldern.
  static HeroStatSePool fromJson(Map<String, dynamic> json) {
    int getInt(String key) =>
        _clampNonNegative((json[key] as num?)?.toInt() ?? 0);

    return HeroStatSePool(
      lep: getInt('lep'),
      au: getInt('au'),
      asp: getInt('asp'),
      kap: getInt('kap'),
      mr: getInt('mr'),
    );
  }
}

int _clampNonNegative(int value) {
  return value < 0 ? 0 : value;
}
