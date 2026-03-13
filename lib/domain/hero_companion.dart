/// Begleiter/Vertraute eines Helden.
///
/// Ein Held kann mehrere Begleiter haben. Begleiter haben einen aehnlichen
/// Aufbau wie Helden, sind aber wesentlich weniger komplex.
library;

/// Einzelner Bewegungswert eines Begleiters (z.B. Schwimmen, Fliegen).
class HeroCompanionSpeed {
  const HeroCompanionSpeed({this.art = '', this.wert = 0});

  /// Art der Bewegung (z.B. 'zu Fuß', 'Schwimmen', 'Fliegen').
  final String art;

  /// Geschwindigkeitswert.
  final int wert;

  HeroCompanionSpeed copyWith({String? art, int? wert}) {
    return HeroCompanionSpeed(
      art: art ?? this.art,
      wert: wert ?? this.wert,
    );
  }

  Map<String, dynamic> toJson() => {'art': art, 'wert': wert};

  static HeroCompanionSpeed fromJson(Map<String, dynamic> json) {
    return HeroCompanionSpeed(
      art: (json['art'] as String?) ?? '',
      wert: (json['wert'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionSpeed && art == other.art && wert == other.wert;

  @override
  int get hashCode => Object.hash(art, wert);
}

/// Persistierte Daten eines Begleiters/Vertrauten.
///
/// Eigenschaften sind nullable, da nicht jeder Begleiter alle acht DSA-
/// Eigenschaften definiert (Pferde z.B. haben nur KO und KK).
///
/// TODO(companion): Kampfwerte (AT, PA, TP, …) – wird in Folgeschritt ergaenzt.
/// TODO(companion): Ruestung – wird in Folgeschritt ergaenzt.
/// TODO(companion): Bedeutung von Gw und Au klaeren.
class HeroCompanion {
  const HeroCompanion({
    required this.id,
    this.name = '',
    this.familie = '',
    this.aussehen = '',
    this.gattung = '',
    this.gewicht = '',
    this.groesse = '',
    this.alter = '',
    // Eigenschaften – nullable, da nicht jeder Begleiter alle besitzt.
    this.mu,
    this.kl,
    this.inn,
    this.ch,
    this.ff,
    this.ge,
    this.ko,
    this.kk,
    // Abgeleitete Kampf-/Bewegungswerte.
    this.ini,
    this.magieresistenz,
    this.loyalitaet,
    this.eigenAp,
    this.geschwindigkeiten = const <HeroCompanionSpeed>[],
    // Lebenspunkte.
    this.maxLep,
    this.maxAup,
    this.maxAsp,
    // Weitere Eigenschaften.
    this.tragkraft = '',
    this.zugkraft = '',
    this.ausbildung = '',
    this.futterbedarf = '',
    this.vorNachteile = '',
    // TODO(companion): Bedeutung von Gw und Au klaeren.
    this.gw = '',
    this.au = '',
  });

  /// Stabiler Schluessel des Begleiters.
  final String id;

  /// Name des Begleiters.
  final String name;

  /// Familien-/Artgruppe (z.B. 'Greif', 'Rappe').
  final String familie;

  /// Aussehen des Begleiters.
  final String aussehen;

  /// Gattung (z.B. 'Hund', 'Rabe', 'Pferd').
  final String gattung;

  /// Gewicht als Freitext (z.B. '~50 kg').
  final String gewicht;

  /// Groesse als Freitext.
  final String groesse;

  /// Alter oder Geburtsjahr.
  final String alter;

  // ---- DSA-Eigenschaften (nullable) ----------------------------------------

  /// Mut.
  final int? mu;

  /// Klugheit.
  final int? kl;

  /// Intuition.
  final int? inn;

  /// Charisma.
  final int? ch;

  /// Fingerfertigkeit.
  final int? ff;

  /// Gewandtheit.
  final int? ge;

  /// Konstitution.
  final int? ko;

  /// Koerperkraft.
  final int? kk;

  // ---- Kampf- und Bewegungswerte -------------------------------------------

  /// Ini-Basiswert.
  final int? ini;

  /// Magieresistenz.
  final int? magieresistenz;

  /// Loyalitaet gegenueber dem Helden.
  final int? loyalitaet;

  /// Eigene Abenteuerpunkte des Begleiters.
  final int? eigenAp;

  /// Geschwindigkeitswerte (z.B. zu Fuss, Schwimmen, Fliegen).
  final List<HeroCompanionSpeed> geschwindigkeiten;

  // ---- Lebenspunkte --------------------------------------------------------

  /// Maximale Lebenspunkte.
  final int? maxLep;

  /// Maximale Ausdauerpunkte.
  final int? maxAup;

  /// Maximale Astralpunkte.
  final int? maxAsp;

  // ---- Weitere Angaben -----------------------------------------------------

  /// Tragkraft des Begleiters.
  final String tragkraft;

  /// Zugkraft des Begleiters.
  final String zugkraft;

  /// Ausbildung/Dressur.
  final String ausbildung;

  /// Futterbedarf.
  final String futterbedarf;

  /// Vor- und Nachteile (Freitext).
  final String vorNachteile;

  /// Gw-Merkmal – Zweck noch ungeklaert.
  // TODO(companion): Bedeutung von Gw klaeren.
  final String gw;

  /// Au-Merkmal – Zweck noch ungeklaert.
  // TODO(companion): Bedeutung von Au klaeren.
  final String au;

  HeroCompanion copyWith({
    String? id,
    String? name,
    String? familie,
    String? aussehen,
    String? gattung,
    String? gewicht,
    String? groesse,
    String? alter,
    Object? mu = _keepNull,
    Object? kl = _keepNull,
    Object? inn = _keepNull,
    Object? ch = _keepNull,
    Object? ff = _keepNull,
    Object? ge = _keepNull,
    Object? ko = _keepNull,
    Object? kk = _keepNull,
    Object? ini = _keepNull,
    Object? magieresistenz = _keepNull,
    Object? loyalitaet = _keepNull,
    Object? eigenAp = _keepNull,
    List<HeroCompanionSpeed>? geschwindigkeiten,
    Object? maxLep = _keepNull,
    Object? maxAup = _keepNull,
    Object? maxAsp = _keepNull,
    String? tragkraft,
    String? zugkraft,
    String? ausbildung,
    String? futterbedarf,
    String? vorNachteile,
    String? gw,
    String? au,
  }) {
    return HeroCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      familie: familie ?? this.familie,
      aussehen: aussehen ?? this.aussehen,
      gattung: gattung ?? this.gattung,
      gewicht: gewicht ?? this.gewicht,
      groesse: groesse ?? this.groesse,
      alter: alter ?? this.alter,
      mu: identical(mu, _keepNull) ? this.mu : mu as int?,
      kl: identical(kl, _keepNull) ? this.kl : kl as int?,
      inn: identical(inn, _keepNull) ? this.inn : inn as int?,
      ch: identical(ch, _keepNull) ? this.ch : ch as int?,
      ff: identical(ff, _keepNull) ? this.ff : ff as int?,
      ge: identical(ge, _keepNull) ? this.ge : ge as int?,
      ko: identical(ko, _keepNull) ? this.ko : ko as int?,
      kk: identical(kk, _keepNull) ? this.kk : kk as int?,
      ini: identical(ini, _keepNull) ? this.ini : ini as int?,
      magieresistenz: identical(magieresistenz, _keepNull)
          ? this.magieresistenz
          : magieresistenz as int?,
      loyalitaet: identical(loyalitaet, _keepNull)
          ? this.loyalitaet
          : loyalitaet as int?,
      eigenAp: identical(eigenAp, _keepNull) ? this.eigenAp : eigenAp as int?,
      geschwindigkeiten: geschwindigkeiten ?? this.geschwindigkeiten,
      maxLep: identical(maxLep, _keepNull) ? this.maxLep : maxLep as int?,
      maxAup: identical(maxAup, _keepNull) ? this.maxAup : maxAup as int?,
      maxAsp: identical(maxAsp, _keepNull) ? this.maxAsp : maxAsp as int?,
      tragkraft: tragkraft ?? this.tragkraft,
      zugkraft: zugkraft ?? this.zugkraft,
      ausbildung: ausbildung ?? this.ausbildung,
      futterbedarf: futterbedarf ?? this.futterbedarf,
      vorNachteile: vorNachteile ?? this.vorNachteile,
      gw: gw ?? this.gw,
      au: au ?? this.au,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'familie': familie,
      'aussehen': aussehen,
      'gattung': gattung,
      'gewicht': gewicht,
      'groesse': groesse,
      'alter': alter,
      if (mu != null) 'mu': mu,
      if (kl != null) 'kl': kl,
      if (inn != null) 'inn': inn,
      if (ch != null) 'ch': ch,
      if (ff != null) 'ff': ff,
      if (ge != null) 'ge': ge,
      if (ko != null) 'ko': ko,
      if (kk != null) 'kk': kk,
      if (ini != null) 'ini': ini,
      if (magieresistenz != null) 'magieresistenz': magieresistenz,
      if (loyalitaet != null) 'loyalitaet': loyalitaet,
      if (eigenAp != null) 'eigenAp': eigenAp,
      'geschwindigkeiten': geschwindigkeiten
          .map((s) => s.toJson())
          .toList(growable: false),
      if (maxLep != null) 'maxLep': maxLep,
      if (maxAup != null) 'maxAup': maxAup,
      if (maxAsp != null) 'maxAsp': maxAsp,
      'tragkraft': tragkraft,
      'zugkraft': zugkraft,
      'ausbildung': ausbildung,
      'futterbedarf': futterbedarf,
      'vorNachteile': vorNachteile,
      'gw': gw,
      'au': au,
    };
  }

  static HeroCompanion fromJson(Map<String, dynamic> json) {
    final rawGeschwindigkeiten =
        (json['geschwindigkeiten'] as List?) ?? const <dynamic>[];
    return HeroCompanion(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      familie: (json['familie'] as String?) ?? '',
      aussehen: (json['aussehen'] as String?) ?? '',
      gattung: (json['gattung'] as String?) ?? '',
      gewicht: (json['gewicht'] as String?) ?? '',
      groesse: (json['groesse'] as String?) ?? '',
      alter: (json['alter'] as String?) ?? '',
      mu: (json['mu'] as num?)?.toInt(),
      kl: (json['kl'] as num?)?.toInt(),
      inn: (json['inn'] as num?)?.toInt(),
      ch: (json['ch'] as num?)?.toInt(),
      ff: (json['ff'] as num?)?.toInt(),
      ge: (json['ge'] as num?)?.toInt(),
      ko: (json['ko'] as num?)?.toInt(),
      kk: (json['kk'] as num?)?.toInt(),
      ini: (json['ini'] as num?)?.toInt(),
      magieresistenz: (json['magieresistenz'] as num?)?.toInt(),
      loyalitaet: (json['loyalitaet'] as num?)?.toInt(),
      eigenAp: (json['eigenAp'] as num?)?.toInt(),
      geschwindigkeiten: rawGeschwindigkeiten
          .whereType<Map>()
          .map(
            (m) => HeroCompanionSpeed.fromJson(m.cast<String, dynamic>()),
          )
          .toList(growable: false),
      maxLep: (json['maxLep'] as num?)?.toInt(),
      maxAup: (json['maxAup'] as num?)?.toInt(),
      maxAsp: (json['maxAsp'] as num?)?.toInt(),
      tragkraft: (json['tragkraft'] as String?) ?? '',
      zugkraft: (json['zugkraft'] as String?) ?? '',
      ausbildung: (json['ausbildung'] as String?) ?? '',
      futterbedarf: (json['futterbedarf'] as String?) ?? '',
      vorNachteile: (json['vorNachteile'] as String?) ?? '',
      gw: (json['gw'] as String?) ?? '',
      au: (json['au'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanion &&
          id == other.id &&
          name == other.name &&
          familie == other.familie &&
          aussehen == other.aussehen &&
          gattung == other.gattung &&
          gewicht == other.gewicht &&
          groesse == other.groesse &&
          alter == other.alter &&
          mu == other.mu &&
          kl == other.kl &&
          inn == other.inn &&
          ch == other.ch &&
          ff == other.ff &&
          ge == other.ge &&
          ko == other.ko &&
          kk == other.kk &&
          ini == other.ini &&
          magieresistenz == other.magieresistenz &&
          loyalitaet == other.loyalitaet &&
          eigenAp == other.eigenAp &&
          _speedListEqual(geschwindigkeiten, other.geschwindigkeiten) &&
          maxLep == other.maxLep &&
          maxAup == other.maxAup &&
          maxAsp == other.maxAsp &&
          tragkraft == other.tragkraft &&
          zugkraft == other.zugkraft &&
          ausbildung == other.ausbildung &&
          futterbedarf == other.futterbedarf &&
          vorNachteile == other.vorNachteile &&
          gw == other.gw &&
          au == other.au;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    familie,
    aussehen,
    gattung,
    gewicht,
    groesse,
    alter,
    mu,
    kl,
    inn,
    ch,
    ff,
    ge,
    ko,
    kk,
    ini,
    magieresistenz,
    loyalitaet,
    eigenAp,
    ...geschwindigkeiten,
    maxLep,
    maxAup,
    maxAsp,
    tragkraft,
    zugkraft,
    ausbildung,
    futterbedarf,
    vorNachteile,
    gw,
    au,
  ]);
}

/// Sentinel-Wert fuer nullable copyWith-Felder.
const Object _keepNull = Object();

bool _speedListEqual(
  List<HeroCompanionSpeed> a,
  List<HeroCompanionSpeed> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
