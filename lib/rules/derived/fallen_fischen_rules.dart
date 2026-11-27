import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

// Regelgrundlage: Wege des Entdeckers S. 110 f. („Angeln“: Talent
// Fischen/Angeln ohne Metatalent; „Speerfischen“: Metatalent aus Wildnisleben,
// Tierkunde, Selbstbeherrschung und Speere oder Wurfspeere, MU/IN/GE, nicht
// wiederholbar) und S. 111 f. („Tierfallen aufstellen“: (2 × Fallenstellen +
// Tierkunde + Fährtensuchen + Wildnisleben) / 5, höchstens das Doppelte des
// niedrigsten und höchstens der TaW Fallenstellen, KL/IN/FF, Geländekunde
// −5/−3). Bei allen drei nennen die TaP* die Zahl der Tagesrationen.
//
// Lesart Tierfallen: Die Regionsliste nennt das Gebirge zweimal („Sümpfe,
// Moore, Marschen, Tundra, Gebirge: +2“ und „Gebirge: +4“); hier gilt der
// eigene Eintrag +4.

// ---------------------------------------------------------------------------
// Tierfallen aufstellen
// ---------------------------------------------------------------------------

/// Talent Fallenstellen.
const String kFallenstellenTalent = 'tal_fallenstellen';

/// Talente des Metatalents Tierfallen stellen; Fallenstellen zählt doppelt.
const List<String> kTierfallenTalente = <String>[
  kFallenstellenTalent,
  kFallenstellenTalent,
  'tal_tierkunde',
  'tal_faehrtensuchen',
  'tal_wildnisleben',
];

/// Geländekunde beim Fallenstellen: passend −5, ähnlich −3.
const GelaendekundeStaffel kTierfallenGelaendekunde = GelaendekundeStaffel(
  passend: -5,
  aehnlich: -3,
);

/// Zuschlag für „nur schmackhaftes Fleisch“ beim Fallenstellen.
const int kTierfallenSchmackhaftErschwernis = 1;

/// TaW Tierfallen stellen: Mittel mit doppeltem Fallenstellen, höchstens das
/// Doppelte des niedrigsten Talents und höchstens der TaW Fallenstellen.
int tierfallenTaw(Map<String, HeroTalentEntry> talente) {
  final meta = computeMetaTalentBaseTaw(
    talentEntries: talente,
    componentTalentIds: kTierfallenTalente,
  );
  final fallen = talente[kFallenstellenTalent]?.talentValue ?? 0;
  return meta > fallen ? fallen : meta;
}

/// Erschwernis durch die Region beim Fallenstellen (WdE S. 112); `null`, wo
/// es nicht möglich ist (Hochgebirge, Ewiges Eis, Wüste).
int? tierfallenRegionsErschwernis(Wildnisregion region) => switch (region) {
  Wildnisregion.lichterWald ||
  Wildnisregion.dichterWald ||
  Wildnisregion.dschungel ||
  Wildnisregion.maraskanDschungel => -4,
  Wildnisregion.suempfeNord ||
  Wildnisregion.suempfeSued ||
  Wildnisregion.tundra => 2,
  Wildnisregion.gebirge => 4,
  Wildnisregion.hochgebirge ||
  Wildnisregion.ewigesEis ||
  Wildnisregion.wueste => null,
  Wildnisregion.graslandHeide || Wildnisregion.savanneSteppe => 0,
};

/// Eingabe für Tierfallen, Angeln und Speerfischen.
class RationenProbeEingabe {
  /// Erstellt die Eingabe.
  const RationenProbeEingabe({
    required this.region,
    required this.taw,
    required this.eigenschaften,
    this.nurSchmackhaft = false,
    this.gelaendekunde = Gelaendekunde.keine,
    this.ortskenntnis = false,
    this.eingesetzteAsp = 0,
    this.situativeErschwernis = 0,
  });

  /// Region.
  final Wildnisregion region;

  /// TaW der Probe.
  final int taw;

  /// Die drei Probeneigenschaften samt Wert.
  final List<ProbeTargetValue> eigenschaften;

  /// Ob nur schmackhafte Beute zählt.
  final bool nurSchmackhaft;

  /// Geländekunde.
  final Gelaendekunde gelaendekunde;

  /// Passende Ortskenntnis.
  final bool ortskenntnis;

  /// Eingesetzte AsP.
  final int eingesetzteAsp;

  /// Weitere Erschwernis (positiv) oder Erleichterung (negativ).
  final int situativeErschwernis;

  WildnisProbeEingabe _alsWildnis(
    int basis, {
    GelaendekundeStaffel staffel = GelaendekundeStaffel.standard,
  }) => WildnisProbeEingabe(
    taw: taw,
    eigenschaften: eigenschaften,
    basisErschwernis: basis,
    gelaendekunde: gelaendekunde,
    ortskenntnis: ortskenntnis,
    eingesetzteAsp: eingesetzteAsp,
    situativeErschwernis: situativeErschwernis,
    gelaendekundeStaffel: staffel,
  );
}

/// Tierfallen als allgemeine Wildnisprobe; `null`, wo es nicht möglich ist.
WildnisProbeEingabe? tierfallenProbeEingabe(RationenProbeEingabe e) {
  final region = tierfallenRegionsErschwernis(e.region);
  if (region == null) return null;
  return e._alsWildnis(
    region + (e.nurSchmackhaft ? kTierfallenSchmackhaftErschwernis : 0),
    staffel: kTierfallenGelaendekunde,
  );
}

// ---------------------------------------------------------------------------
// Fischen: Angeln und Speerfischen
// ---------------------------------------------------------------------------

/// Talent Fischen/Angeln (IN/FF/KK).
const String kAngelnTalent = 'tal_fischen_angeln';

/// Name des Inventareintrags für gefangenen Fisch.
const String kFischGegenstand = 'Fisch (frisch)';

/// Erschwernis durch die Region beim Angeln und Speerfischen (WdE S. 110);
/// `null` in der Wüste.
int? fischenRegionsErschwernis(Wildnisregion region) => switch (region) {
  Wildnisregion.suempfeSued => -4,
  Wildnisregion.suempfeNord => -2,
  Wildnisregion.gebirge => 2,
  Wildnisregion.hochgebirge || Wildnisregion.ewigesEis => 8,
  Wildnisregion.wueste => null,
  _ => 0,
};

/// Angeln als allgemeine Wildnisprobe; `null` in der Wüste.
WildnisProbeEingabe? angelnProbeEingabe(RationenProbeEingabe e) {
  final region = fischenRegionsErschwernis(e.region);
  if (region == null) return null;
  return e._alsWildnis(
    region + (e.nurSchmackhaft ? kJagdSchmackhaftErschwernis : 0),
  );
}

/// Talente des Metatalents Speerfischen mit [speertalent] (Speere oder
/// Wurfspeere).
List<String> speerfischenTalente(String speertalent) => <String>[
  'tal_wildnisleben',
  'tal_tierkunde',
  'tal_selbstbeherrschung',
  speertalent,
];

/// Die beiden Speertalente, mit denen gefischt werden kann.
const List<String> kSpeerfischenSpeertalente = <String>[
  'tal_speere',
  'tal_wurfspeere',
];

/// Waffe beim Speerfischen (WdE S. 111).
enum Fischspeer {
  /// Fischspeer oder Efferdbart.
  fischspeer('Fischspeer oder Efferdbart', -3),

  /// Wurfspeer.
  wurfspeer('Wurfspeer', 0),

  /// Angespitzter Stock.
  stock('Angespitzter Stock', 3);

  const Fischspeer(this.bezeichnung, this.erschwernis);

  /// Anzeigename.
  final String bezeichnung;

  /// Erschwernis.
  final int erschwernis;
}

/// Erleichterung durch Scharfschütze beim Speerfischen (WdE S. 111).
const int kSpeerfischenScharfschuetze = -3;

/// Speerfischen als allgemeine Wildnisprobe; `null` in der Wüste.
///
/// Scharfschütze zählt nur mit dem Talent Wurfspeere, weil es die Fernkampf-
/// Sonderfertigkeit ist; der Aufrufer übergibt [scharfschuetze] passend.
WildnisProbeEingabe? speerfischenProbeEingabe(
  RationenProbeEingabe e, {
  required Fischspeer speer,
  bool scharfschuetze = false,
}) {
  final region = fischenRegionsErschwernis(e.region);
  if (region == null) return null;
  return e._alsWildnis(
    region +
        speer.erschwernis +
        (scharfschuetze ? kSpeerfischenScharfschuetze : 0) +
        (e.nurSchmackhaft ? kJagdSchmackhaftErschwernis : 0),
  );
}

/// Der rohe TaW eines einzelnen Talents (ohne Metatalent-Deckel, der einen
/// negativen Wert sonst verdoppeln würde).
int einzeltalentTaw(Map<String, HeroTalentEntry> talente, String talentId) =>
    talente[talentId]?.talentValue ?? 0;
