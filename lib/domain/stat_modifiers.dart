/// Aggregierte Modifikatoren fuer abgeleitete Kampf-/Ressourcenwerte.
///
/// Die Werte werden aus verschiedenen Quellen addiert:
/// - persistente Modifikatoren am Helden (`HeroSheet.persistentMods`)
/// - temporaere Modifikatoren am Zustand (`HeroState.tempMods`)
/// - geparste Textmodifikatoren aus Basisdaten (z. B. Vorteile/Nachteile)
class StatModifiers {
  const StatModifiers({
    this.lep = 0,
    this.au = 0,
    this.asp = 0,
    this.kap = 0,
    this.mr = 0,
    this.iniBase = 0,
    this.at = 0,
    this.pa = 0,
    this.fk = 0,
    this.gs = 0,
    this.ausweichen = 0,
  });

  final int lep;
  final int au;
  final int asp;
  final int kap;
  final int mr;
  final int iniBase;
  final int at;
  final int pa;
  final int fk;
  final int gs;
  final int ausweichen;

  /// Erstellt eine angepasste Kopie mit selektiv ueberschriebenen Feldern.
  StatModifiers copyWith({
    int? lep,
    int? au,
    int? asp,
    int? kap,
    int? mr,
    int? iniBase,
    int? at,
    int? pa,
    int? fk,
    int? gs,
    int? ausweichen,
  }) {
    return StatModifiers(
      lep: lep ?? this.lep,
      au: au ?? this.au,
      asp: asp ?? this.asp,
      kap: kap ?? this.kap,
      mr: mr ?? this.mr,
      iniBase: iniBase ?? this.iniBase,
      at: at ?? this.at,
      pa: pa ?? this.pa,
      fk: fk ?? this.fk,
      gs: gs ?? this.gs,
      ausweichen: ausweichen ?? this.ausweichen,
    );
  }

  /// Addiert zwei Modifikatorbloecke feldweise.
  StatModifiers operator +(StatModifiers other) {
    return StatModifiers(
      lep: lep + other.lep,
      au: au + other.au,
      asp: asp + other.asp,
      kap: kap + other.kap,
      mr: mr + other.mr,
      iniBase: iniBase + other.iniBase,
      at: at + other.at,
      pa: pa + other.pa,
      fk: fk + other.fk,
      gs: gs + other.gs,
      ausweichen: ausweichen + other.ausweichen,
    );
  }

  /// Serialisierung fuer Persistenz/Transfer.
  Map<String, dynamic> toJson() {
    return {
      'lep': lep,
      'au': au,
      'asp': asp,
      'kap': kap,
      'mr': mr,
      'iniBase': iniBase,
      'at': at,
      'pa': pa,
      'fk': fk,
      'gs': gs,
      'ausweichen': ausweichen,
    };
  }

  /// Robust gegen fehlende Schluessel: nicht vorhandene Felder werden `0`.
  static StatModifiers fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return StatModifiers(
      lep: getInt('lep'),
      au: getInt('au'),
      asp: getInt('asp'),
      kap: getInt('kap'),
      mr: getInt('mr'),
      iniBase: getInt('iniBase'),
      at: getInt('at'),
      pa: getInt('pa'),
      fk: getInt('fk'),
      gs: getInt('gs'),
      ausweichen: getInt('ausweichen'),
    );
  }
}
