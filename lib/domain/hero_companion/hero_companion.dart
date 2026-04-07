/// Begleiter/Vertraute eines Helden.
///
/// Ein Held kann mehrere Begleiter haben. Begleiter haben einen aehnlichen
/// Aufbau wie Helden, sind aber wesentlich weniger komplex.
library;

import 'package:dsa_heldenverwaltung/domain/combat_config.dart'
    show ArmorPiece;
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
    // Steigerungen (nur fuer Vertraute).
    this.steigerungen = const <String, int>{},
    this.startLep,
    this.startAsp,
    this.startMr,
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

  // ---- Steigerungen (Vertraute) ---------------------------------------------

  /// Gekaufte Steigerungen pro Wert-Schluessel (Komplexitaet F).
  /// Keys: 'mu','kl','inn','ch','ff','ge','ko','kk','ini','mr','loyalitaet','lep','asp'.
  final Map<String, int> steigerungen;

  /// Startwert fuer LeP — wird einmalig festgehalten und bestimmt das
  /// Steigerungsmaximum (1,5 × Startwert).
  final int? startLep;

  /// Startwert fuer AsP (analog zu startLep).
  final int? startAsp;

  /// Startwert fuer MR (analog zu startLep).
  final int? startMr;

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
    Map<String, int>? steigerungen,
    Object? startLep = _keepNull,
    Object? startAsp = _keepNull,
    Object? startMr = _keepNull,
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
      steigerungen: steigerungen ?? this.steigerungen,
      startLep: identical(startLep, _keepNull)
          ? this.startLep
          : startLep as int?,
      startAsp: identical(startAsp, _keepNull)
          ? this.startAsp
          : startAsp as int?,
      startMr:
          identical(startMr, _keepNull) ? this.startMr : startMr as int?,
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
      if (steigerungen.isNotEmpty) 'steigerungen': steigerungen,
      if (startLep != null) 'startLep': startLep,
      if (startAsp != null) 'startAsp': startAsp,
      if (startMr != null) 'startMr': startMr,
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
      // Backward-Compat: gw/au waren frueher als String gespeichert.
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
      steigerungen: ((json['steigerungen'] as Map?) ?? const <String, dynamic>{})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      startLep: (json['startLep'] as num?)?.toInt(),
      startAsp: (json['startAsp'] as num?)?.toInt(),
      startMr: (json['startMr'] as num?)?.toInt(),
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
          _listEqual(ritualCategories, other.ritualCategories) &&
          _mapEqual(steigerungen, other.steigerungen) &&
          startLep == other.startLep &&
          startAsp == other.startAsp &&
          startMr == other.startMr;

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
    ...steigerungen.entries.map((e) => '${e.key}:${e.value}'),
    startLep,
    startAsp,
    startMr,
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

bool _mapEqual(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
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
