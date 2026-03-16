import 'package:dsa_heldenverwaltung/domain/combat_config.dart'
    show ArmorPiece;
import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion_attack.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion_sonderfertigkeit.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion_speed.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart'
    show HeroRitualCategory;

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
    this.mu,
    this.kl,
    this.inn,
    this.ch,
    this.ff,
    this.ge,
    this.ko,
    this.kk,
    this.ini,
    this.magieresistenz,
    this.loyalitaet,
    this.apGesamt,
    this.apAusgegeben,
    this.geschwindigkeiten = const <HeroCompanionSpeed>[],
    this.maxLep,
    this.maxAup,
    this.maxAsp,
    this.tragkraft = '',
    this.zugkraft = '',
    this.ausbildung = '',
    this.futterbedarf = '',
    this.vorteile = '',
    this.nachteile = '',
    this.gw,
    this.au,
    this.angriffe = const <HeroCompanionAttack>[],
    this.sonderfertigkeiten = const <HeroCompanionSonderfertigkeit>[],
    this.ruestungsTeile = const <ArmorPiece>[],
    this.ruestungsgewoehnung = 0,
    this.ritualCategories = const <HeroRitualCategory>[],
  });

  final String id;
  final String name;
  final BegleiterTyp typ;
  final String familie;
  final String aussehen;
  final String gattung;
  final String gewicht;
  final String groesse;
  final String alter;
  final int? mu;
  final int? kl;
  final int? inn;
  final int? ch;
  final int? ff;
  final int? ge;
  final int? ko;
  final int? kk;
  final int? ini;
  final int? magieresistenz;
  final int? loyalitaet;
  final int? apGesamt;
  final int? apAusgegeben;
  final List<HeroCompanionSpeed> geschwindigkeiten;
  final int? maxLep;
  final int? maxAup;
  final int? maxAsp;
  final String tragkraft;
  final String zugkraft;
  final String ausbildung;
  final String futterbedarf;
  final String vorteile;
  final String nachteile;
  final int? gw;
  final int? au;
  final List<HeroCompanionAttack> angriffe;
  final List<HeroCompanionSonderfertigkeit> sonderfertigkeiten;
  final List<ArmorPiece> ruestungsTeile;
  final int ruestungsgewoehnung;
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
    Object? mu = keepFieldValue,
    Object? kl = keepFieldValue,
    Object? inn = keepFieldValue,
    Object? ch = keepFieldValue,
    Object? ff = keepFieldValue,
    Object? ge = keepFieldValue,
    Object? ko = keepFieldValue,
    Object? kk = keepFieldValue,
    Object? ini = keepFieldValue,
    Object? magieresistenz = keepFieldValue,
    Object? loyalitaet = keepFieldValue,
    Object? apGesamt = keepFieldValue,
    Object? apAusgegeben = keepFieldValue,
    List<HeroCompanionSpeed>? geschwindigkeiten,
    Object? maxLep = keepFieldValue,
    Object? maxAup = keepFieldValue,
    Object? maxAsp = keepFieldValue,
    String? tragkraft,
    String? zugkraft,
    String? ausbildung,
    String? futterbedarf,
    String? vorteile,
    String? nachteile,
    Object? gw = keepFieldValue,
    Object? au = keepFieldValue,
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
      mu: identical(mu, keepFieldValue) ? this.mu : mu as int?,
      kl: identical(kl, keepFieldValue) ? this.kl : kl as int?,
      inn: identical(inn, keepFieldValue) ? this.inn : inn as int?,
      ch: identical(ch, keepFieldValue) ? this.ch : ch as int?,
      ff: identical(ff, keepFieldValue) ? this.ff : ff as int?,
      ge: identical(ge, keepFieldValue) ? this.ge : ge as int?,
      ko: identical(ko, keepFieldValue) ? this.ko : ko as int?,
      kk: identical(kk, keepFieldValue) ? this.kk : kk as int?,
      ini: identical(ini, keepFieldValue) ? this.ini : ini as int?,
      magieresistenz: identical(magieresistenz, keepFieldValue)
          ? this.magieresistenz
          : magieresistenz as int?,
      loyalitaet: identical(loyalitaet, keepFieldValue)
          ? this.loyalitaet
          : loyalitaet as int?,
      apGesamt: identical(apGesamt, keepFieldValue)
          ? this.apGesamt
          : apGesamt as int?,
      apAusgegeben: identical(apAusgegeben, keepFieldValue)
          ? this.apAusgegeben
          : apAusgegeben as int?,
      geschwindigkeiten: geschwindigkeiten ?? this.geschwindigkeiten,
      maxLep: identical(maxLep, keepFieldValue) ? this.maxLep : maxLep as int?,
      maxAup: identical(maxAup, keepFieldValue) ? this.maxAup : maxAup as int?,
      maxAsp: identical(maxAsp, keepFieldValue) ? this.maxAsp : maxAsp as int?,
      tragkraft: tragkraft ?? this.tragkraft,
      zugkraft: zugkraft ?? this.zugkraft,
      ausbildung: ausbildung ?? this.ausbildung,
      futterbedarf: futterbedarf ?? this.futterbedarf,
      vorteile: vorteile ?? this.vorteile,
      nachteile: nachteile ?? this.nachteile,
      gw: identical(gw, keepFieldValue) ? this.gw : gw as int?,
      au: identical(au, keepFieldValue) ? this.au : au as int?,
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
      vorteile: (json['vorteile'] as String?) ??
          (json['vorNachteile'] as String?) ??
          '',
      nachteile: (json['nachteile'] as String?) ?? '',
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
          _listEqual(geschwindigkeiten, other.geschwindigkeiten) &&
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
          _listEqual(ruestungsTeile, other.ruestungsTeile) &&
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

int? _parseIntOrString(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool _listEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
