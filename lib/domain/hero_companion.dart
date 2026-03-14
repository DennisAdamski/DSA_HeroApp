/// Begleiter/Vertraute eines Helden.
///
/// Ein Held kann mehrere Begleiter haben. Begleiter haben einen aehnlichen
/// Aufbau wie Helden, sind aber wesentlich weniger komplex.
library;

import 'package:dsa_heldenverwaltung/domain/combat_config.dart'
    show ArmorPiece;
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart'
    show HeroRitualCategory;

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

/// Typ eines Begleiters.
enum BegleiterTyp {
  reittier,
  vertrauter,
  sonstigerBegleiter;

  String get label => switch (this) {
    BegleiterTyp.reittier => 'Reittier',
    BegleiterTyp.vertrauter => 'Vertrauter',
    BegleiterTyp.sonstigerBegleiter => 'Sonstiger Begleiter',
  };

  static BegleiterTyp fromJson(String? value) => switch (value) {
    'reittier' => BegleiterTyp.reittier,
    'vertrauter' => BegleiterTyp.vertrauter,
    _ => BegleiterTyp.sonstigerBegleiter,
  };
}

/// Persistierte Daten eines Begleiters/Vertrauten.
///
/// Eigenschaften sind nullable, da nicht jeder Begleiter alle acht DSA-
/// Eigenschaften definiert (Pferde z.B. haben nur KO und KK).
///
/// Einzelner Angriffsmodus eines Begleiters (z.B. Beißen, Krallen, Sturzflug).
class HeroCompanionAttack {
  const HeroCompanionAttack({
    required this.id,
    this.name = '',
    this.dk = '',
    this.at,
    this.pa,
    this.tp = '',
    this.beschreibung = '',
  });

  /// Stabiler Schluessel des Angriffs.
  final String id;

  /// Name des Angriffsmodus (z.B. 'Beißen', 'Krallen').
  final String name;

  /// Distanzklasse (Freitext, z.B. 'H', 'A', 'S').
  final String dk;

  /// Attacke-Wert.
  final int? at;

  /// Parade-Wert (null = keine Parade moeglich).
  final int? pa;

  /// Trefferpunkte-Formel (Freitext, z.B. '1W6+3').
  final String tp;

  /// Optionale Beschreibung des Angriffsmodus.
  final String beschreibung;

  HeroCompanionAttack copyWith({
    String? id,
    String? name,
    String? dk,
    Object? at = _keepNull,
    Object? pa = _keepNull,
    String? tp,
    String? beschreibung,
  }) {
    return HeroCompanionAttack(
      id: id ?? this.id,
      name: name ?? this.name,
      dk: dk ?? this.dk,
      at: identical(at, _keepNull) ? this.at : at as int?,
      pa: identical(pa, _keepNull) ? this.pa : pa as int?,
      tp: tp ?? this.tp,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dk': dk,
    if (at != null) 'at': at,
    if (pa != null) 'pa': pa,
    'tp': tp,
    'beschreibung': beschreibung,
  };

  static HeroCompanionAttack fromJson(Map<String, dynamic> json) {
    return HeroCompanionAttack(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      dk: (json['dk'] as String?) ?? '',
      at: (json['at'] as num?)?.toInt(),
      pa: (json['pa'] as num?)?.toInt(),
      tp: (json['tp'] as String?) ?? '',
      beschreibung: (json['beschreibung'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionAttack &&
          id == other.id &&
          name == other.name &&
          dk == other.dk &&
          at == other.at &&
          pa == other.pa &&
          tp == other.tp &&
          beschreibung == other.beschreibung;

  @override
  int get hashCode =>
      Object.hash(id, name, dk, at, pa, tp, beschreibung);
}

/// Sonderfertigkeit eines Begleiters.
class HeroCompanionSonderfertigkeit {
  const HeroCompanionSonderfertigkeit({this.name = '', this.beschreibung = ''});

  final String name;
  final String beschreibung;

  HeroCompanionSonderfertigkeit copyWith({String? name, String? beschreibung}) {
    return HeroCompanionSonderfertigkeit(
      name: name ?? this.name,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'beschreibung': beschreibung,
  };

  static HeroCompanionSonderfertigkeit fromJson(Map<String, dynamic> json) {
    return HeroCompanionSonderfertigkeit(
      name: (json['name'] as String?) ?? '',
      beschreibung: (json['beschreibung'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionSonderfertigkeit &&
          name == other.name &&
          beschreibung == other.beschreibung;

  @override
  int get hashCode => Object.hash(name, beschreibung);
}

class HeroCompanion {
  const HeroCompanion({
    required this.id,
    this.name = '',
    this.typ = BegleiterTyp.sonstigerBegleiter,
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
    this.apGesamt,
    this.apAusgegeben,
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
    this.vorteile = '',
    this.nachteile = '',
    this.gw,
    this.au,
    // Angriffe und Sonderfertigkeiten.
    this.angriffe = const <HeroCompanionAttack>[],
    this.sonderfertigkeiten = const <HeroCompanionSonderfertigkeit>[],
    // Ruestung
    this.ruestungsTeile = const <ArmorPiece>[],
    this.ruestungsgewoehnung = 0,
    // Ritualkategorien (nur fuer Vertraute: Vertrautenmagie).
    this.ritualCategories = const <HeroRitualCategory>[],
  });

  /// Stabiler Schluessel des Begleiters.
  final String id;

  /// Name des Begleiters.
  final String name;

  /// Typ des Begleiters (Reittier, Vertrauter, Sonstiger Begleiter).
  final BegleiterTyp typ;

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

  /// Gesamt-AP des Begleiters.
  final int? apGesamt;

  /// Ausgegebene AP des Begleiters.
  final int? apAusgegeben;

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

  /// Vorteile des Begleiters (Freitext).
  final String vorteile;

  /// Nachteile des Begleiters (Freitext).
  final String nachteile;

  /// Gefahrenwert (0–20).
  final int? gw;

  /// Ausdauer-Runden (Anzahl moeglicher Spielrunden bei einer Geschwindigkeit).
  final int? au;

  // ---- Angriffe und Sonderfertigkeiten ------------------------------------

  /// Angriffsmodi des Begleiters (z.B. Beißen, Krallen, Sturzflug).
  final List<HeroCompanionAttack> angriffe;

  /// Sonderfertigkeiten des Begleiters.
  final List<HeroCompanionSonderfertigkeit> sonderfertigkeiten;

  // ---- Ruestung -----------------------------------------------------------

  /// Ruestungsteile des Begleiters.
  final List<ArmorPiece> ruestungsTeile;

  /// Globale Ruestungsgewoehnung des Begleiters (0–3).
  final int ruestungsgewoehnung;

  // ---- Vertrautenmagie -------------------------------------------------------

  /// Ritualkategorien des Vertrauten (z.B. Vertrautenmagie mit aktiven Ritualen).
  /// Leer fuer Nicht-Vertraute.
  final List<HeroRitualCategory> ritualCategories;

  HeroCompanion copyWith({
    String? id,
    String? name,
    BegleiterTyp? typ,
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
    Object? apGesamt = _keepNull,
    Object? apAusgegeben = _keepNull,
    List<HeroCompanionSpeed>? geschwindigkeiten,
    Object? maxLep = _keepNull,
    Object? maxAup = _keepNull,
    Object? maxAsp = _keepNull,
    String? tragkraft,
    String? zugkraft,
    String? ausbildung,
    String? futterbedarf,
    String? vorteile,
    String? nachteile,
    Object? gw = _keepNull,
    Object? au = _keepNull,
    List<HeroCompanionAttack>? angriffe,
    List<HeroCompanionSonderfertigkeit>? sonderfertigkeiten,
    List<ArmorPiece>? ruestungsTeile,
    int? ruestungsgewoehnung,
    List<HeroRitualCategory>? ritualCategories,
  }) {
    return HeroCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      typ: typ ?? this.typ,
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
      apGesamt: identical(apGesamt, _keepNull) ? this.apGesamt : apGesamt as int?,
      apAusgegeben: identical(apAusgegeben, _keepNull) ? this.apAusgegeben : apAusgegeben as int?,
      geschwindigkeiten: geschwindigkeiten ?? this.geschwindigkeiten,
      maxLep: identical(maxLep, _keepNull) ? this.maxLep : maxLep as int?,
      maxAup: identical(maxAup, _keepNull) ? this.maxAup : maxAup as int?,
      maxAsp: identical(maxAsp, _keepNull) ? this.maxAsp : maxAsp as int?,
      tragkraft: tragkraft ?? this.tragkraft,
      zugkraft: zugkraft ?? this.zugkraft,
      ausbildung: ausbildung ?? this.ausbildung,
      futterbedarf: futterbedarf ?? this.futterbedarf,
      vorteile: vorteile ?? this.vorteile,
      nachteile: nachteile ?? this.nachteile,
      gw: identical(gw, _keepNull) ? this.gw : gw as int?,
      au: identical(au, _keepNull) ? this.au : au as int?,
      angriffe: angriffe ?? this.angriffe,
      sonderfertigkeiten: sonderfertigkeiten ?? this.sonderfertigkeiten,
      ruestungsTeile: ruestungsTeile ?? this.ruestungsTeile,
      ruestungsgewoehnung: ruestungsgewoehnung ?? this.ruestungsgewoehnung,
      ritualCategories: ritualCategories ?? this.ritualCategories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'typ': typ.name,
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
      if (apGesamt != null) 'apGesamt': apGesamt,
      if (apAusgegeben != null) 'apAusgegeben': apAusgegeben,
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
      'vorteile': vorteile,
      'nachteile': nachteile,
      if (gw != null) 'gw': gw,
      if (au != null) 'au': au,
      'angriffe': angriffe.map((a) => a.toJson()).toList(growable: false),
      'sonderfertigkeiten': sonderfertigkeiten
          .map((s) => s.toJson())
          .toList(growable: false),
      'ruestungsTeile': ruestungsTeile
          .map((p) => p.toJson())
          .toList(growable: false),
      'ruestungsgewoehnung': ruestungsgewoehnung,
      if (ritualCategories.isNotEmpty)
        'ritualCategories':
            ritualCategories.map((c) => c.toJson()).toList(growable: false),
    };
  }

  static HeroCompanion fromJson(Map<String, dynamic> json) {
    final rawGeschwindigkeiten =
        (json['geschwindigkeiten'] as List?) ?? const <dynamic>[];
    final rawRuestungsTeile =
        (json['ruestungsTeile'] as List?) ?? const <dynamic>[];
    return HeroCompanion(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      typ: BegleiterTyp.fromJson(json['typ'] as String?),
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
      // Backward-Compat: eigenAp wurde in apGesamt umbenannt.
      apGesamt: (json['apGesamt'] as num?)?.toInt() ??
          (json['eigenAp'] as num?)?.toInt(),
      apAusgegeben: (json['apAusgegeben'] as num?)?.toInt(),
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
      // Backward-Compat: altes 'vorNachteile'-Feld wird in 'vorteile' migriert.
      vorteile: (json['vorteile'] as String?) ??
          (json['vorNachteile'] as String?) ??
          '',
      nachteile: (json['nachteile'] as String?) ?? '',
      // Backward-Compat: gw/au waren fruehер als String gespeichert.
      gw: _parseIntOrString(json['gw']),
      au: _parseIntOrString(json['au']),
      angriffe: ((json['angriffe'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((m) => HeroCompanionAttack.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      sonderfertigkeiten:
          ((json['sonderfertigkeiten'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (m) => HeroCompanionSonderfertigkeit.fromJson(
                  m.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false),
      ruestungsTeile: rawRuestungsTeile
          .whereType<Map>()
          .map((m) => ArmorPiece.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      ruestungsgewoehnung:
          (json['ruestungsgewoehnung'] as num?)?.toInt() ?? 0,
      ritualCategories:
          ((json['ritualCategories'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (m) => HeroRitualCategory.fromJson(m.cast<String, dynamic>()),
              )
              .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanion &&
          id == other.id &&
          name == other.name &&
          typ == other.typ &&
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
          apGesamt == other.apGesamt &&
          apAusgegeben == other.apAusgegeben &&
          _speedListEqual(geschwindigkeiten, other.geschwindigkeiten) &&
          maxLep == other.maxLep &&
          maxAup == other.maxAup &&
          maxAsp == other.maxAsp &&
          tragkraft == other.tragkraft &&
          zugkraft == other.zugkraft &&
          ausbildung == other.ausbildung &&
          futterbedarf == other.futterbedarf &&
          vorteile == other.vorteile &&
          nachteile == other.nachteile &&
          gw == other.gw &&
          au == other.au &&
          _listEqual(angriffe, other.angriffe) &&
          _listEqual(sonderfertigkeiten, other.sonderfertigkeiten) &&
          _armorListEqual(ruestungsTeile, other.ruestungsTeile) &&
          ruestungsgewoehnung == other.ruestungsgewoehnung &&
          _listEqual(ritualCategories, other.ritualCategories);

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    typ,
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
    apGesamt,
    apAusgegeben,
    ...geschwindigkeiten,
    maxLep,
    maxAup,
    maxAsp,
    tragkraft,
    zugkraft,
    ausbildung,
    futterbedarf,
    vorteile,
    nachteile,
    gw,
    au,
    ...angriffe,
    ...sonderfertigkeiten,
    ...ruestungsTeile,
    ruestungsgewoehnung,
    ...ritualCategories,
  ]);
}

/// Liest einen int-Wert tolerant aus JSON – unterstuetzt num und String (Backward-Compat).
int? _parseIntOrString(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
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

bool _listEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _armorListEqual(List<ArmorPiece> a, List<ArmorPiece> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
