import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/maneuver_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

// Regelgrundlage: Wege des Entdeckers S. 109 f. („Hinterher!“, Hetzjagd vom
// Pferde aus): TaW = (Wildnisleben + Tierkunde + 2 × Reiten + Fernkampfwaffe) /
// 5, höchstens das Doppelte des niedrigsten, MU/IN/GE, eine Stunde, TaP* =
// Tagesrationen, **nicht wiederholbar** („unabhängig von ihrem Ausgang“).
// Voraussetzung: Tierkunde und Reiten aktiviert.
//
// Eigene Tabellen für Waffe, Region, Sonderfertigkeiten und Verbrauch. Für
// Scharf-/Meisterschütze und Schnellladen gilt wie bei der Pirschjagd
// (Fußnote **): Sie gleichen nur positive Zuschläge außer der Waffe aus, ein
// Überschuss verfällt; die Reiter-Sonderfertigkeiten und die Jagd zu Pferde
// stehen dagegen außerhalb dieser Grenze (Lesart, das Buch nennt sie unter
// „Jagd zu Pferde“).

/// Fundstelle der Hetzjagd.
const String kHetzjagdQuelle = 'Wege des Entdeckers S. 109 f.';

/// Dauer einer Hetzjagd in Minuten.
const int kHetzjagdDauerMinuten = 60;

/// Name des Metatalents.
const String kHetzjagdTitel = 'Hetzjagd';

/// Talente der Hetzjagd ohne Waffe; Reiten zählt doppelt.
const List<String> kHetzjagdGrundtalente = <String>[
  'tal_wildnisleben',
  'tal_tierkunde',
  'tal_reiten',
  'tal_reiten',
];

/// Alle Talente der Hetzjagd mit der Waffe [waffenTalentId] (Reiten zweimal).
List<String> hetzjagdTalente(String waffenTalentId) => <String>[
  ...kHetzjagdGrundtalente,
  if (waffenTalentId.isNotEmpty) waffenTalentId,
];

/// Warum [held] nicht hetzen kann (Tierkunde und Reiten müssen aktiviert
/// sein, WdE S. 110); `null`, wenn die Voraussetzung erfüllt ist.
String? hetzjagdVoraussetzung(HeroSheet held) {
  bool aktiv(String id) => held.talents[id]?.talentValue != null;
  final fehlend = <String>[
    if (!aktiv('tal_tierkunde')) 'Tierkunde',
    if (!aktiv('tal_reiten')) 'Reiten',
  ];
  if (fehlend.isEmpty) return null;
  return 'Die Hetzjagd verlangt die aktivierten Talente ${fehlend.join(' und ')} '
      '($kHetzjagdQuelle).';
}

const String _bogen = 'tal_bogen';
const String _armbrust = 'tal_armbrust';
const String _wurfspeere = 'tal_wurfspeere';
const String _schleuder = 'tal_schleuder';
const String _blasrohr = 'tal_blasrohr';
const String _wurfmesser = 'tal_wurfmesser';

JagdWaffe _hetz(
  String schluessel,
  String name,
  String talent,
  int mod,
  JagdVerbrauch verbrauch,
) => JagdWaffe(
  schluessel: 'hetz:$schluessel',
  name: name,
  talentId: talent,
  modifikator: mod,
  verbrauch: verbrauch,
  herkunft: 'Waffentabelle',
);

/// Die Waffentabelle der Hetzjagd (WdE S. 110): nur Waffen, die vom
/// Pferderücken aus benutzbar sind, nicht leicht verloren gehen und sich
/// schnell nachladen lassen.
final List<JagdWaffe>
kHetzjagdWaffenTabelle = List<JagdWaffe>.unmodifiable(<JagdWaffe>[
  _hetz('efferdbart', 'Efferdbart', _wurfspeere, 10, JagdVerbrauch.speereHetz),
  _hetz('dschadra', 'Dschadra', _wurfspeere, 8, JagdVerbrauch.speereHetz),
  _hetz('holzspeer', 'Holzspeer', _wurfspeere, 8, JagdVerbrauch.speereHetz),
  _hetz('speer', 'Speer', _wurfspeere, 8, JagdVerbrauch.speereHetz),
  _hetz('wurfspeer', 'Wurfspeer', _wurfspeere, 8, JagdVerbrauch.speereHetz),
  _hetz('balestrina', 'Balestrina', _armbrust, 8, JagdVerbrauch.pfeileHetz),
  _hetz('ballaester', 'Balläster', _armbrust, 6, JagdVerbrauch.pfeileHetz),
  _hetz('eisenwalder', 'Eisenwalder', _armbrust, 5, JagdVerbrauch.pfeileHetz),
  _hetz('schleuder', 'Schleuder', _schleuder, 5, JagdVerbrauch.kugeln),
  _hetz('blasrohr', 'Blasrohr', _blasrohr, 4, JagdVerbrauch.pfeileHetz),
  _hetz('kurzbogen', 'Kurzbogen', _bogen, 2, JagdVerbrauch.pfeileHetz),
  _hetz('kompositbogen', 'Kompositbogen', _bogen, 2, JagdVerbrauch.pfeileHetz),
  _hetz('elfenbogen', 'Elfenbogen', _bogen, 1, JagdVerbrauch.pfeileHetz),
  _hetz(
    'orkischer_reiterbogen',
    'Orkischer Reiterbogen',
    _bogen,
    1,
    JagdVerbrauch.pfeileHetz,
  ),
]);

/// Waffe aus der Tabelle zum Schlüssel, sonst `null`.
JagdWaffe? hetzjagdWaffeAusTabelle(String schluessel) {
  for (final waffe in kHetzjagdWaffenTabelle) {
    if (waffe.schluessel == schluessel) return waffe;
  }
  return null;
}

/// Erschwernis einer persönlichen Waffe nach ihrer Höchstreichweite in
/// Schritt (WdE S. 110, Fußnote *): bis 15 Schritt +6 … über 80 Schritt −2.
/// Dazu kommt die Ladezeit oder [kHetzjagdAufhebenZuschlag] ([hetzjagdAufschlag]).
int hetzjagdReichweitenModifikator(int schritt) {
  const stufen = <(int, int)>[
    (15, 6),
    (20, 5),
    (25, 4),
    (30, 3),
    (40, 2),
    (50, 1),
    (60, 0),
    (80, -1),
  ];
  for (final (bis, wert) in stufen) {
    if (schritt <= bis) return wert;
  }
  return -2;
}

/// Zuschlag für Waffen, die nach einem Fehlwurf erst aufgehoben werden müssen
/// (Wurfwaffen), statt der Ladezeit.
const int kHetzjagdAufhebenZuschlag = 6;

/// Zuschlag einer persönlichen Waffe zur Reichweite: die Ladezeit der Waffe,
/// bei Wurfwaffen [kHetzjagdAufhebenZuschlag].
int hetzjagdAufschlag(MainWeaponSlot slot) {
  final wurf = slot.talentId == _wurfspeere || slot.talentId == _wurfmesser;
  return wurf ? kHetzjagdAufhebenZuschlag : slot.rangedProfile.reloadTime;
}

/// Die Fernkampfwaffe [slot] des Helden als Hetzjagdwaffe.
///
/// Waffen aus der Hetz-Tabelle übernehmen deren Wert, andere die Reichweite
/// plus Ladezeit bzw. Aufheb-Zuschlag. Waffen, die sich zur Jagd überhaupt
/// nicht eignen, Wurfmesser und Dolche („gehen zu leicht verloren“) sowie
/// Waffen der Pirschtabelle, die nicht in der Hetz-Tabelle stehen (Lang- und
/// Kriegsbogen …), ergeben `null`.
JagdWaffe? hetzjagdWaffeAusSlot(MainWeaponSlot slot) {
  final pirsch = jagdWaffeAusSlot(slot);
  if (pirsch == null || pirsch.talentId == _wurfmesser) return null;
  final slotId = pirsch.slotId;
  if (pirsch.herkunft.startsWith('wie ')) {
    final name = pirsch.herkunft.substring(4);
    for (final waffe in kHetzjagdWaffenTabelle) {
      if (waffe.name == name) {
        return JagdWaffe(
          schluessel: pirsch.schluessel,
          name: pirsch.name,
          talentId: pirsch.talentId,
          modifikator: waffe.modifikator,
          verbrauch: waffe.verbrauch,
          herkunft: 'wie ${waffe.name}',
          slotId: slotId,
        );
      }
    }
    return null;
  }
  final reichweite = jagdWaffenReichweite(slot);
  if (reichweite == null) return null;
  final aufschlag = hetzjagdAufschlag(slot);
  return JagdWaffe(
    schluessel: pirsch.schluessel,
    name: pirsch.name,
    talentId: pirsch.talentId,
    modifikator: hetzjagdReichweitenModifikator(reichweite) + aufschlag,
    verbrauch: pirsch.verbrauch.beiHetzjagd,
    herkunft:
        'Reichweite $reichweite Schritt${aufschlag == 0 ? '' : ', $aufschlag Ladezeit/Aufheben'}',
    slotId: slotId,
  );
}

/// Alle Fernkampfwaffen des Helden, die sich zur Hetzjagd eignen.
List<JagdWaffe> hetzjagdWaffenDesHelden(HeroSheet hero) => <JagdWaffe>[
  for (final slot in hero.combatConfig.weaponSlots) ?hetzjagdWaffeAusSlot(slot),
];

/// Erschwernis durch die Region bei der Hetzjagd (WdE S. 110).
int hetzjagdRegionsErschwernis(Wildnisregion region) => switch (region) {
  Wildnisregion.lichterWald ||
  Wildnisregion.graslandHeide ||
  Wildnisregion.savanneSteppe => -4,
  Wildnisregion.dichterWald ||
  Wildnisregion.tundra ||
  Wildnisregion.gebirge => 2,
  Wildnisregion.dschungel => 4,
  Wildnisregion.maraskanDschungel => 6,
  Wildnisregion.suempfeNord ||
  Wildnisregion.suempfeSued ||
  Wildnisregion.hochgebirge => 8,
  Wildnisregion.wueste || Wildnisregion.ewigesEis => 12,
};

/// Erleichterung durch den Sonderfertigkeit Schnellladen (WdE S. 110).
const int kHetzjagdSchnellladenErschwernis = -2;

/// Katalog-ID des Manövers Schnellladen für das Fernkampftalent [talentId];
/// `null`, wo es keines gibt.
String? schnellladenId(String talentId) => switch (talentId) {
  _bogen => 'man_schnellladen_bogen',
  _armbrust => 'man_schnellladen_armbrust',
  _ => null,
};

/// Ob der Held Schnellladen für [talentId] erlernt hat.
bool hatSchnellladen(
  HeroSheet hero, {
  required String talentId,
  required RulesCatalog? catalog,
}) {
  final id = schnellladenId(talentId);
  if (id == null) return false;
  final ids = catalog == null
      ? normalizeManeuverIds(hero.combatConfig.specialRules.activeManeuvers)
      : learnedManeuverIds(hero.combatConfig, catalog);
  return ids.contains(id);
}

/// Erleichterung durch einen abgerichteten Jagdhund, Jagdfalken oder ein
/// ähnliches Tier: −3 bis −7 nach Loyalität und Ausbildung (Meisterentscheid).
const int kHetzjagdTierMin = 3;

/// Größte Erleichterung durch ein Jagdtier.
const int kHetzjagdTierMax = 7;

/// Erleichterung der Jagd zu Pferde (Reiten-TaW mindestens 7, nur in Grasland,
/// Heide, Savanne, Steppe und Tundra).
const int kHetzjagdZuPferdErschwernis = -3;

/// Mindest-TaW Reiten für die Jagd zu Pferde.
const int kHetzjagdZuPferdReiten = 7;

/// Ob die Jagd zu Pferde in [region] mit Reiten-TaW [reitenTaw] zählt.
bool hetzjagdZuPferdMoeglich(Wildnisregion region, int reitenTaw) =>
    reitenTaw >= kHetzjagdZuPferdReiten &&
    (region == Wildnisregion.graslandHeide ||
        region == Wildnisregion.savanneSteppe ||
        region == Wildnisregion.tundra);

/// Reiter-Sonderfertigkeiten bei der Hetzjagd.
enum Reitersonderfertigkeit {
  /// Keine.
  keine('Keine', 0),

  /// Reiterkampf.
  reiterkampf('Reiterkampf', -2),

  /// Reiterkampf und Berittener Schütze (zusammen −7).
  berittenerSchuetze('Reiterkampf und Berittener Schütze', -7);

  const Reitersonderfertigkeit(this.bezeichnung, this.erleichterung);

  /// Anzeigename.
  final String bezeichnung;

  /// Erleichterung (negativ).
  final int erleichterung;
}

/// Eingabe einer Hetzjagd.
class HetzjagdEingabe {
  /// Erstellt die Eingabe.
  const HetzjagdEingabe({
    required this.region,
    required this.taw,
    required this.eigenschaften,
    required this.waffe,
    this.reitenTaw = 0,
    this.wetter = Jagdwetter.ruhig,
    this.nurSchmackhaft = false,
    this.schuetze = Schuetzenstufe.keine,
    this.schnellladen = false,
    this.gelaendekunde = Gelaendekunde.keine,
    this.ortskenntnis = false,
    this.eingesetzteAsp = 0,
    this.jagdglueck = false,
    this.jagdtier = 0,
    this.zuPferd = false,
    this.reiter = Reitersonderfertigkeit.keine,
    this.situativeErschwernis = 0,
  });

  /// Region der Jagd.
  final Wildnisregion region;

  /// TaW des Metatalents mit dieser Waffe.
  final int taw;

  /// MU/IN/GE samt Werten.
  final List<ProbeTargetValue> eigenschaften;

  /// Benutzte Fernkampfwaffe.
  final JagdWaffe waffe;

  /// TaW Reiten; entscheidet über die Jagd zu Pferde.
  final int reitenTaw;

  /// Wetter.
  final Jagdwetter wetter;

  /// Ob nur schmackhaftes Fleisch zählt (+2).
  final bool nurSchmackhaft;

  /// Schützen-Sonderfertigkeit zur Waffe.
  final Schuetzenstufe schuetze;

  /// Ob die Sonderfertigkeit Schnellladen zur Waffe gilt (−2).
  final bool schnellladen;

  /// Geländekunde.
  final Gelaendekunde gelaendekunde;

  /// Passende Ortskenntnis.
  final bool ortskenntnis;

  /// Eingesetzte AsP.
  final int eingesetzteAsp;

  /// Unter dem Einfluss des Jagdglücks (−5).
  final bool jagdglueck;

  /// Erleichterung durch ein Jagdtier als Betrag (0 ohne, sonst 3 bis 7).
  final int jagdtier;

  /// Ob die Jagd zu Pferde angesetzt wird (zählt nur, wenn
  /// [hetzjagdZuPferdMoeglich]).
  final bool zuPferd;

  /// Reiter-Sonderfertigkeiten.
  final Reitersonderfertigkeit reiter;

  /// Weitere Erschwernis (positiv) oder Erleichterung (negativ).
  final int situativeErschwernis;

  /// Ob die Jagd zu Pferde zählt.
  bool get zuPferdWirksam =>
      zuPferd && hetzjagdZuPferdMoeglich(region, reitenTaw);

  /// Wirksamer Betrag des Jagdtiers, auf 3 bis 7 begrenzt (0 ohne Tier).
  int get jagdtierWirksam =>
      jagdtier <= 0 ? 0 : jagdtier.clamp(kHetzjagdTierMin, kHetzjagdTierMax);
}

/// Berechnet die Erschwernis der Hetzjagd.
///
/// Scharf-/Meisterschütze und Schnellladen gleichen nur die positiven
/// Zuschläge außer der Waffe aus; was darüber hinausgeht, verfällt
/// ([JagdErschwernis.schuetze] enthält beide).
JagdErschwernis berechneHetzjagdErschwernis(HetzjagdEingabe e) {
  final teile = <int>[
    hetzjagdRegionsErschwernis(e.region),
    e.wetter.erschwernis,
    if (e.nurSchmackhaft) kJagdSchmackhaftErschwernis,
    GelaendekundeStaffel.standard.erschwernis(e.gelaendekunde),
    if (e.ortskenntnis) kOrtskenntnisErschwernis,
    wildnisAspErschwernis(e.eingesetzteAsp),
    if (e.jagdglueck) kJagdglueckErschwernis,
    -e.jagdtierWirksam,
    if (e.zuPferdWirksam) kHetzjagdZuPferdErschwernis,
    e.reiter.erleichterung,
    e.situativeErschwernis,
  ];
  final zuschlaege = teile.where((t) => t > 0).fold<int>(0, (a, b) => a + b);
  final erleichterungen = teile
      .where((t) => t < 0)
      .fold<int>(0, (a, b) => a + b);
  final sf =
      e.schuetze.hetzErleichterung +
      (e.schnellladen ? kHetzjagdSchnellladenErschwernis : 0);
  final wirksam = -sf > zuschlaege ? -zuschlaege : sf;
  return JagdErschwernis(
    waffe: e.waffe.modifikator,
    zuschlaege: zuschlaege,
    erleichterungen: erleichterungen,
    schuetze: wirksam,
    schuetzeVerfallen: wirksam - sf,
  );
}

/// Die Hetzjagd als allgemeine Wildnisprobe.
WildnisProbeEingabe hetzjagdProbeEingabe(HetzjagdEingabe e) =>
    WildnisProbeEingabe(
      taw: e.taw,
      eigenschaften: e.eigenschaften,
      basisErschwernis: berechneHetzjagdErschwernis(e).gesamt,
    );

/// Baut die Probe der Hetzjagd.
ResolvedProbeRequest baueHetzjagdProbe(HetzjagdEingabe e) => baueWildnisProbe(
  hetzjagdProbeEingabe(e),
  titel: kHetzjagdTitel,
  regelHinweis: kHetzjagdQuelle,
);

/// Hinweis zur Wiederholbarkeit der Hetzjagd.
const String kHetzjagdNichtWiederholbar =
    'Die Hetzjagd lässt sich nicht wiederholen, gleich wie sie ausgeht: Die '
    'Hetze hat weit und breit alles Jagdwild in die Flucht geschlagen.';

/// Wertet eine Hetzjagd aus: TaP* = Tagesrationen Wildbret fürs Inventar, dazu
/// Geschossverlust nach der Hetzjagd-Tabelle.
WildnisErgebnis werteHetzjagdAus(HetzjagdEingabe e, ProbeResult probe) {
  return wildnisRationenErgebnis(
    probe,
    erschwernis: berechneHetzjagdErschwernis(e).gesamt,
    hinweis: '${e.waffe.verbrauch.hinweis} $kHetzjagdNichtWiederholbar',
    gegenstand: kWildbretGegenstand,
    taetigkeit: kHetzjagdTitel,
    beschreibung: frischfleischBeschreibung(e.region),
    munition: WildnisMunition(
      waffenName: e.waffe.name,
      verbrauch: e.waffe.verbrauch,
      waffenSlotId: e.waffe.slotId,
    ),
  );
}
