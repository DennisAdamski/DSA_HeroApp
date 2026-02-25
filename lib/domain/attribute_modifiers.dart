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
  });

  final int mu;
  final int kl;
  final int inn;
  final int ch;
  final int ff;
  final int ge;
  final int ko;
  final int kk;

  AttributeModifiers copyWith({
    int? mu,
    int? kl,
    int? inn,
    int? ch,
    int? ff,
    int? ge,
    int? ko,
    int? kk,
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
    );
  }
}
