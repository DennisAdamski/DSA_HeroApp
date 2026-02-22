class BoughtStats {
  const BoughtStats({
    this.lep = 0,
    this.au = 0,
    this.asp = 0,
    this.kap = 0,
    this.mr = 0,
  });

  final int lep;
  final int au;
  final int asp;
  final int kap;
  final int mr;

  BoughtStats copyWith({
    int? lep,
    int? au,
    int? asp,
    int? kap,
    int? mr,
  }) {
    return BoughtStats(
      lep: lep ?? this.lep,
      au: au ?? this.au,
      asp: asp ?? this.asp,
      kap: kap ?? this.kap,
      mr: mr ?? this.mr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lep': lep,
      'au': au,
      'asp': asp,
      'kap': kap,
      'mr': mr,
    };
  }

  static BoughtStats fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return BoughtStats(
      lep: getInt('lep'),
      au: getInt('au'),
      asp: getInt('asp'),
      kap: getInt('kap'),
      mr: getInt('mr'),
    );
  }
}
