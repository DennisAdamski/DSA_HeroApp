class Attributes {
  const Attributes({
    required this.mu,
    required this.kl,
    required this.inn,
    required this.ch,
    required this.ff,
    required this.ge,
    required this.ko,
    required this.kk,
  });

  final int mu;
  final int kl;
  final int inn;
  final int ch;
  final int ff;
  final int ge;
  final int ko;
  final int kk;

  Attributes copyWith({
    int? mu,
    int? kl,
    int? inn,
    int? ch,
    int? ff,
    int? ge,
    int? ko,
    int? kk,
  }) {
    return Attributes(
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

  static Attributes fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return Attributes(
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
