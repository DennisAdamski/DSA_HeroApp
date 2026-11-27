import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/weapon_combat_type.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/maneuver_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

// Der Geschossverlust gehört zur Ausbeute; Aufrufer der Jagd brauchen ihn
// trotzdem ohne zweiten Import.
export 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart'
    show JagdVerbrauch;

// Regelgrundlage: Wege des Entdeckers S. 106–109 („Die Metatalente zum Jagen
// und Sammeln“, „Pirschjagd“, „Ansitzjagd“): TaW = (Wildnisleben + Tierkunde
// + Fährtensuchen + Schleichen bzw. Sich Verstecken + Fernkampfwaffe) / 5,
// höchstens das Doppelte des niedrigsten, MU/IN/GE, eine bzw. anderthalb
// Stunden, TaP* = Tagesrationen. Modifikationen nach Waffe (Tabelle oder
// Reichweite), Scharf-/Meisterschütze, Geländekunde, Ortskenntnis, Region,
// Wetter, Beute, AsP und Jagdglück; Verbrauch an Geschossen.
//
// Scharf- und Meisterschütze dürfen nur andere Zuschläge ausgleichen, nie den
// Zuschlag der Waffe (WdE S. 108, Fußnote **: „Meisterschütze … Kurzbogen (+2)
// … höchstens 8 TaP* … auch bei Sturm (+6)“). Hier gleicht die Erleichterung
// die positiven Zuschläge außer der Waffe aus, ein Überschuss verfällt.
//
// Die Hetzjagd (S. 109 f.) steht in `hetzjagd_rules.dart`: eigene Waffen- und
// Regionstabellen, Reiten im TaW, nicht wiederholbar.

/// Art der Jagd zu Fuß.
enum Jagdart {
  /// Pirschjagd: anschleichen, eine Stunde je Probe.
  pirsch('Pirschjagd', 'tal_schleichen', 60, 'Wege des Entdeckers S. 107 f.'),

  /// Ansitzjagd: auflauern, anderthalb Stunden je Probe.
  ansitz('Ansitzjagd', 'tal_sich_verstecken', 90, 'Wege des Entdeckers S. 108');

  const Jagdart(this.titel, this.talentId, this.dauerMinuten, this.quelle);

  /// Name des Metatalents.
  final String titel;

  /// Das Talent, das Pirsch und Ansitz unterscheidet.
  final String talentId;

  /// Dauer einer Probe in Minuten.
  final int dauerMinuten;

  /// Fundstelle.
  final String quelle;
}

/// Talente der Jagd ohne Waffe, ergänzt um das Waffentalent ([jagdTalente]).
List<String> jagdGrundtalente(Jagdart art) => <String>[
  'tal_wildnisleben',
  'tal_tierkunde',
  'tal_faehrtensuchen',
  art.talentId,
];

/// Alle fünf Talente der Jagd mit der Waffe [waffenTalentId].
List<String> jagdTalente(Jagdart art, String waffenTalentId) => <String>[
  ...jagdGrundtalente(art),
  if (waffenTalentId.isNotEmpty) waffenTalentId,
];

/// Eine Jagdwaffe mit ihrem Modifikator.
class JagdWaffe {
  /// Erstellt eine Waffe.
  const JagdWaffe({
    required this.schluessel,
    required this.name,
    required this.talentId,
    required this.modifikator,
    required this.verbrauch,
    this.herkunft = '',
    this.slotId,
  });

  /// Stabiler Schlüssel (`tabelle:kurzbogen` oder `held:<Slot-ID>`).
  final String schluessel;

  /// Anzeigename.
  final String name;

  /// Kampftalent der Waffe.
  final String talentId;

  /// Erschwernis der Jagdprobe durch die Waffe.
  final int modifikator;

  /// Geschossverlust.
  final JagdVerbrauch verbrauch;

  /// Woher der Modifikator stammt (`Tabelle` oder `Reichweite 60 Schritt`).
  final String herkunft;

  /// Slot-ID der Waffe des Helden; `null` bei Tabellenwaffen und Slots ohne
  /// ID (deren Bestand sich nicht sicher wiederfinden lässt).
  final String? slotId;
}

JagdWaffe _tabelle(
  String schluessel,
  String name,
  String talent,
  int mod,
  JagdVerbrauch verbrauch,
) => JagdWaffe(
  schluessel: 'tabelle:$schluessel',
  name: name,
  talentId: talent,
  modifikator: mod,
  verbrauch: verbrauch,
  herkunft: 'Waffentabelle',
);

const String _bogen = 'tal_bogen';
const String _armbrust = 'tal_armbrust';
const String _wurfmesser = 'tal_wurfmesser';
const String _wurfbeile = 'tal_wurfbeile';
const String _wurfspeere = 'tal_wurfspeere';
const String _schleuder = 'tal_schleuder';
const String _diskus = 'tal_diskus';
const String _blasrohr = 'tal_blasrohr';

/// Die Waffentabelle der Pirsch- und Ansitzjagd (WdE S. 107 f.). Die Talente
/// folgen dem Waffenkatalog (Aventurisches Arsenal).
final List<JagdWaffe>
kJagdWaffenTabelle = List<JagdWaffe>.unmodifiable(<JagdWaffe>[
  _tabelle('borndorn', 'Borndorn', _wurfmesser, 10, JagdVerbrauch.wurfwaffen),
  _tabelle('wurfdolch', 'Wurfdolch', _wurfmesser, 10, JagdVerbrauch.wurfwaffen),
  _tabelle(
    'wurfmesser',
    'Wurfmesser',
    _wurfmesser,
    10,
    JagdVerbrauch.wurfwaffen,
  ),
  _tabelle(
    'wurfscheibe',
    'Wurfscheibe',
    _wurfmesser,
    9,
    JagdVerbrauch.wurfwaffen,
  ),
  _tabelle('wurfbeil', 'Wurfbeil', _wurfbeile, 8, JagdVerbrauch.wurfwaffen),
  _tabelle(
    'schneidzahn',
    'Schneidzahn',
    _wurfbeile,
    7,
    JagdVerbrauch.wurfwaffen,
  ),
  _tabelle('balestrina', 'Balestrina', _armbrust, 6, JagdVerbrauch.pfeile),
  _tabelle('efferdbart', 'Efferdbart', _wurfspeere, 6, JagdVerbrauch.speere),
  _tabelle('fledermaus', 'Fledermaus', _schleuder, 6, JagdVerbrauch.kugeln),
  _tabelle('wurfkeule', 'Wurfkeule', _wurfbeile, 6, JagdVerbrauch.wurfwaffen),
  _tabelle('blasrohr', 'Blasrohr', _blasrohr, 4, JagdVerbrauch.pfeile),
  _tabelle('dschadra', 'Dschadra', _wurfspeere, 4, JagdVerbrauch.speere),
  _tabelle('eisenwalder', 'Eisenwalder', _armbrust, 4, JagdVerbrauch.pfeile),
  _tabelle('holzspeer', 'Holzspeer', _wurfspeere, 4, JagdVerbrauch.speere),
  _tabelle('schleuder', 'Schleuder', _schleuder, 4, JagdVerbrauch.kugeln),
  _tabelle('speer', 'Speer', _wurfspeere, 4, JagdVerbrauch.speere),
  _tabelle('wurfspeer', 'Wurfspeer', _wurfspeere, 4, JagdVerbrauch.speere),
  _tabelle('balestra', 'Balestra', _armbrust, 2, JagdVerbrauch.pfeile),
  _tabelle('kurzbogen', 'Kurzbogen', _bogen, 2, JagdVerbrauch.pfeile),
  _tabelle(
    'leichte_armbrust',
    'Leichte Armbrust',
    _armbrust,
    2,
    JagdVerbrauch.pfeile,
  ),
  _tabelle(
    'stabschleuder',
    'Stabschleuder',
    _wurfspeere,
    2,
    JagdVerbrauch.kugeln,
  ),
  _tabelle('diskus', 'Diskus', _diskus, 2, JagdVerbrauch.wurfwaffen),
  _tabelle('jagddiskus', 'Jagddiskus', _diskus, 2, JagdVerbrauch.wurfwaffen),
  _tabelle('kampfdiskus', 'Kampfdiskus', _diskus, 2, JagdVerbrauch.wurfwaffen),
  _tabelle('kompositbogen', 'Kompositbogen', _bogen, 1, JagdVerbrauch.pfeile),
  _tabelle('arbalette', 'Arbalette', _armbrust, 0, JagdVerbrauch.kugeln),
  _tabelle('ballaester', 'Balläster', _armbrust, 0, JagdVerbrauch.pfeile),
  _tabelle(
    'speerschleuder',
    'Speerschleuder',
    _wurfspeere,
    0,
    JagdVerbrauch.pfeile,
  ),
  _tabelle(
    'orkischer_reiterbogen',
    'Orkischer Reiterbogen',
    _bogen,
    0,
    JagdVerbrauch.pfeile,
  ),
  _tabelle('kriegsbogen', 'Kriegsbogen', _bogen, -1, JagdVerbrauch.pfeile),
  _tabelle(
    'windenarmbrust',
    'Windenarmbrust',
    _armbrust,
    -2,
    JagdVerbrauch.pfeile,
  ),
  _tabelle('langbogen', 'Langbogen', _bogen, -2, JagdVerbrauch.pfeile),
  _tabelle('arbalone', 'Arbalone', _armbrust, -3, JagdVerbrauch.pfeile),
  _tabelle('elfenbogen', 'Elfenbogen', _bogen, -3, JagdVerbrauch.pfeile),
]);

/// Waffe aus der Tabelle zum Schlüssel, sonst `null`.
JagdWaffe? jagdWaffeAusTabelle(String schluessel) {
  for (final waffe in kJagdWaffenTabelle) {
    if (waffe.schluessel == schluessel) return waffe;
  }
  return null;
}

/// Andere Namen derselben Waffe (Katalog ↔ Tabelle).
const Map<String, String> _waffenAliase = <String, String>{
  'schwere armbrust': 'windenarmbrust',
};

String _vergleich(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'^improvisiert:\s*'), '')
    .replaceAll(RegExp(r'[^a-z]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

JagdWaffe? _tabellenwaffeZuName(String name) {
  final roh = name.trim().toLowerCase();
  final schluessel = _waffenAliase[roh] ?? _vergleich(name);
  if (schluessel.isEmpty) return null;
  return jagdWaffeAusTabelle('tabelle:$schluessel');
}

/// Erschwernis einer persönlichen Waffe nach ihrer Höchstreichweite in
/// Schritt (WdE S. 108, Fußnote *): bis 15 Schritt +8 … über 200 Schritt −3,
/// zuzüglich +2 für Waffen der Talente Wurfmesser und Wurfbeile.
int jagdWaffenModifikatorNachReichweite(int schritt, String talentId) {
  const stufen = <(int, int)>[
    (15, 8),
    (20, 7),
    (25, 6),
    (30, 5),
    (40, 4),
    (50, 3),
    (60, 2),
    (80, 1),
    (100, 0),
    (150, -1),
    (200, -2),
  ];
  var mod = -3;
  for (final (bis, wert) in stufen) {
    if (schritt <= bis) {
      mod = wert;
      break;
    }
  }
  final wurf = talentId == _wurfmesser || talentId == _wurfbeile;
  return mod + (wurf ? 2 : 0);
}

JagdVerbrauch _verbrauchNachTalent(String talentId) => switch (talentId) {
  _schleuder => JagdVerbrauch.kugeln,
  _wurfspeere => JagdVerbrauch.speere,
  _wurfmesser || _wurfbeile || _diskus => JagdVerbrauch.wurfwaffen,
  _ => JagdVerbrauch.pfeile,
};

/// Höchstreichweite aus den Distanzstufen der Waffe: die letzte Stufe, deren
/// Bezeichnung eine Schrittzahl ist (`60` oder `60 Schritt`, wie im
/// Waffenkatalog); `null`, wenn keine Stufe so beschriftet ist (etwa die
/// Vorgabe `Distanz 1` … `Distanz 5`).
int? jagdWaffenReichweite(MainWeaponSlot slot) {
  final muster = RegExp(r'^\s*(\d+)\s*(schritt)?\s*$', caseSensitive: false);
  int? letzte;
  for (final stufe in slot.rangedProfile.distanceBands) {
    final treffer = muster.firstMatch(stufe.label);
    if (treffer != null) letzte = int.parse(treffer.group(1)!);
  }
  return letzte;
}

/// Die Fernkampfwaffe [slot] des Helden als Jagdwaffe.
///
/// Waffen, deren Art oder Name in der Tabelle steht, übernehmen deren Wert;
/// sonst gilt die Reichweite. Ohne Talent oder ohne beides ergibt sich `null`.
JagdWaffe? jagdWaffeAusSlot(MainWeaponSlot slot) {
  if (slot.combatType != WeaponCombatType.ranged) return null;
  final talentId = slot.talentId.trim();
  if (talentId.isEmpty) return null;
  final slotId = slot.id.isEmpty ? null : slot.id;
  final name = slot.name.trim().isEmpty ? slot.weaponType : slot.name;
  final schluessel = 'held:${slot.id.isEmpty ? _vergleich(name) : slot.id}';
  final tabelle =
      _tabellenwaffeZuName(slot.weaponType) ?? _tabellenwaffeZuName(slot.name);
  if (tabelle != null) {
    return JagdWaffe(
      schluessel: schluessel,
      name: name,
      talentId: talentId,
      modifikator: tabelle.modifikator,
      verbrauch: tabelle.verbrauch,
      herkunft: 'wie ${tabelle.name}',
      slotId: slotId,
    );
  }
  // Lasso, Netze, Enterhaken und Kettenkugel laufen über das Talent
  // Schleuder, taugen aber nicht zur Jagd; nur Tabellenwaffen zählen.
  if (talentId == _schleuder) return null;
  final reichweite = jagdWaffenReichweite(slot);
  if (reichweite == null) return null;
  return JagdWaffe(
    schluessel: schluessel,
    name: name,
    talentId: talentId,
    modifikator: jagdWaffenModifikatorNachReichweite(reichweite, talentId),
    verbrauch: _verbrauchNachTalent(talentId),
    herkunft: 'Reichweite $reichweite Schritt',
    slotId: slotId,
  );
}

/// Alle Fernkampfwaffen des Helden, die sich zur Jagd eignen.
List<JagdWaffe> jagdWaffenDesHelden(HeroSheet hero) => <JagdWaffe>[
  for (final slot in hero.combatConfig.weaponSlots) ?jagdWaffeAusSlot(slot),
];

/// Wetter bei der Jagd.
enum Jagdwetter {
  /// Kein nennenswerter Wind.
  ruhig('Ruhig', 0),

  /// Steife Brise.
  steifeBrise('Steife Brise', 2),

  /// Starker Wind.
  starkerWind('Starker Wind', 4),

  /// Sturm.
  sturm('Sturm', 6);

  const Jagdwetter(this.bezeichnung, this.erschwernis);

  /// Anzeigename.
  final String bezeichnung;

  /// Erschwernis.
  final int erschwernis;
}

/// Scharf- und Meisterschütze für die gewählte Waffe.
enum Schuetzenstufe {
  /// Keine Schützen-Sonderfertigkeit.
  keine('Keine', 0, 0),

  /// Scharfschütze.
  scharfschuetze('Scharfschütze', -3, -1),

  /// Scharf- und Meisterschütze (gemeinsam −7, bei der Hetzjagd −3).
  meisterschuetze('Scharf- und Meisterschütze', -7, -3);

  const Schuetzenstufe(
    this.bezeichnung,
    this.jagdErleichterung,
    this.hetzErleichterung,
  );

  /// Anzeigename.
  final String bezeichnung;

  /// Erleichterung bei Pirsch- und Ansitzjagd (negativ).
  final int jagdErleichterung;

  /// Erleichterung bei der Hetzjagd (negativ, WdE S. 109).
  final int hetzErleichterung;
}

/// Katalog-ID des Manövers Scharfschütze.
const String kScharfschuetzeId = 'man_scharfschuetze';

/// Katalog-ID des Manövers Meisterschütze.
const String kMeisterschuetzeId = 'man_meisterschuetze';

/// Welche Schützen-Sonderfertigkeit der Held für [talentId] erlernt hat.
///
/// Beide Manöver werden je Fernkampftalent erlernt
/// (`man_scharfschuetze::tal_bogen`); Meisterschütze setzt Scharfschütze
/// voraus und zählt deshalb als beide.
Schuetzenstufe schuetzenstufeDesHelden(
  HeroSheet hero, {
  required String talentId,
  required RulesCatalog? catalog,
}) {
  if (talentId.isEmpty) return Schuetzenstufe.keine;
  final ids = catalog == null
      ? normalizeManeuverIds(hero.combatConfig.specialRules.activeManeuvers)
      : learnedManeuverIds(hero.combatConfig, catalog);
  bool hat(String id) => ids.contains('$id::$talentId');
  if (hat(kMeisterschuetzeId)) return Schuetzenstufe.meisterschuetze;
  if (hat(kScharfschuetzeId)) return Schuetzenstufe.scharfschuetze;
  return Schuetzenstufe.keine;
}

/// Erschwernis durch die Region bei Pirsch- und Ansitzjagd (WdE S. 108).
int jagdRegionsErschwernis(Wildnisregion region) => switch (region) {
  Wildnisregion.lichterWald ||
  Wildnisregion.graslandHeide ||
  Wildnisregion.savanneSteppe => -4,
  Wildnisregion.dichterWald || Wildnisregion.gebirge => -2,
  Wildnisregion.dschungel || Wildnisregion.maraskanDschungel => 0,
  Wildnisregion.suempfeSued || Wildnisregion.tundra => 2,
  Wildnisregion.suempfeNord || Wildnisregion.hochgebirge => 4,
  Wildnisregion.wueste || Wildnisregion.ewigesEis => 12,
};

/// Zuschlag für „nur schmackhaftes Fleisch“ bei Jagd und Fischen.
const int kJagdSchmackhaftErschwernis = 2;

/// Erleichterung durch die Firun-Liturgie Jagdglück.
const int kJagdglueckErschwernis = -5;

/// Eingabe einer Pirsch- oder Ansitzjagd.
class JagdEingabe {
  /// Erstellt die Eingabe.
  const JagdEingabe({
    required this.art,
    required this.region,
    required this.taw,
    required this.eigenschaften,
    required this.waffe,
    this.wetter = Jagdwetter.ruhig,
    this.nurSchmackhaft = false,
    this.schuetze = Schuetzenstufe.keine,
    this.gelaendekunde = Gelaendekunde.keine,
    this.ortskenntnis = false,
    this.eingesetzteAsp = 0,
    this.jagdglueck = false,
    this.situativeErschwernis = 0,
  });

  /// Pirsch oder Ansitz.
  final Jagdart art;

  /// Region der Jagd.
  final Wildnisregion region;

  /// TaW des Metatalents mit dieser Waffe.
  final int taw;

  /// MU/IN/GE samt Werten.
  final List<ProbeTargetValue> eigenschaften;

  /// Benutzte Fernkampfwaffe.
  final JagdWaffe waffe;

  /// Wetter.
  final Jagdwetter wetter;

  /// Ob nur schmackhaftes Fleisch zählt (+2).
  final bool nurSchmackhaft;

  /// Schützen-Sonderfertigkeit zur Waffe.
  final Schuetzenstufe schuetze;

  /// Geländekunde.
  final Gelaendekunde gelaendekunde;

  /// Passende Ortskenntnis.
  final bool ortskenntnis;

  /// Eingesetzte AsP.
  final int eingesetzteAsp;

  /// Unter dem Einfluss des Jagdglücks (−5).
  final bool jagdglueck;

  /// Weitere Erschwernis (positiv) oder Erleichterung (negativ).
  final int situativeErschwernis;
}

/// Die Erschwernis einer Jagd, aufgeschlüsselt.
class JagdErschwernis {
  /// Erstellt die Aufschlüsselung.
  const JagdErschwernis({
    required this.waffe,
    required this.zuschlaege,
    required this.erleichterungen,
    required this.schuetze,
    required this.schuetzeVerfallen,
  });

  /// Zuschlag oder Erleichterung der Waffe.
  final int waffe;

  /// Summe der übrigen positiven Zuschläge (Region, Wetter, Beute, situativ).
  final int zuschlaege;

  /// Summe der übrigen Erleichterungen (Region, Geländekunde, Ortskenntnis,
  /// AsP, Jagdglück, situativ).
  final int erleichterungen;

  /// Wirksamer Anteil der Schützen-SF (negativ, höchstens [zuschlaege]).
  final int schuetze;

  /// Anteil der Schützen-SF, der mangels Zuschlägen verfällt (≥ 0).
  final int schuetzeVerfallen;

  /// Gesamterschwernis (positiv = schwerer).
  int get gesamt => waffe + zuschlaege + erleichterungen + schuetze;
}

/// Berechnet die Erschwernis der Jagd.
///
/// Scharf- und Meisterschütze gleichen nur die positiven Zuschläge außer der
/// Waffe aus; was darüber hinausgeht, verfällt.
JagdErschwernis berechneJagdErschwernis(JagdEingabe e) {
  final teile = <int>[
    jagdRegionsErschwernis(e.region),
    e.wetter.erschwernis,
    if (e.nurSchmackhaft) kJagdSchmackhaftErschwernis,
    GelaendekundeStaffel.standard.erschwernis(e.gelaendekunde),
    if (e.ortskenntnis) kOrtskenntnisErschwernis,
    wildnisAspErschwernis(e.eingesetzteAsp),
    if (e.jagdglueck) kJagdglueckErschwernis,
    e.situativeErschwernis,
  ];
  final zuschlaege = teile.where((t) => t > 0).fold<int>(0, (a, b) => a + b);
  final erleichterungen = teile
      .where((t) => t < 0)
      .fold<int>(0, (a, b) => a + b);
  final sf = e.schuetze.jagdErleichterung;
  final wirksam = -sf > zuschlaege ? -zuschlaege : sf;
  return JagdErschwernis(
    waffe: e.waffe.modifikator,
    zuschlaege: zuschlaege,
    erleichterungen: erleichterungen,
    schuetze: wirksam,
    schuetzeVerfallen: wirksam - sf,
  );
}

/// Die Jagd als allgemeine Wildnisprobe: die ganze Erschwernis steckt in der
/// Basiserschwernis, weil die Schützen-SF sie nicht linear verrechnen.
WildnisProbeEingabe jagdProbeEingabe(JagdEingabe e) => WildnisProbeEingabe(
  taw: e.taw,
  eigenschaften: e.eigenschaften,
  basisErschwernis: berechneJagdErschwernis(e).gesamt,
);

/// Baut die Probe der Pirsch- oder Ansitzjagd.
ResolvedProbeRequest baueJagdProbe(JagdEingabe e) => baueWildnisProbe(
  jagdProbeEingabe(e),
  titel: e.art.titel,
  regelHinweis: e.art.quelle,
);

/// Wie lange frisches, unbehandeltes Fleisch oder Fisch in [region] hält
/// (WdE S. 121, „Haltbarkeit von frischem Fleisch oder Fisch“).
String frischfleischHaltbarkeit(Wildnisregion region) => switch (region) {
  Wildnisregion.dschungel ||
  Wildnisregion.maraskanDschungel ||
  Wildnisregion.suempfeNord ||
  Wildnisregion.suempfeSued =>
    'Frisch und unbehandelt (Sumpf, Dschungel): 2 Stunden appetitlich, '
        'weitere 2 genießbar.',
  Wildnisregion.wueste || Wildnisregion.savanneSteppe =>
    'Frisch und unbehandelt (warm): 4 Stunden appetitlich, weitere 4 '
        'genießbar.',
  Wildnisregion.tundra || Wildnisregion.hochgebirge =>
    'Frisch und unbehandelt (kalt): 9 Stunden appetitlich, weitere 9 '
        'genießbar.',
  Wildnisregion.ewigesEis =>
    'Bei Dauerfrost eine Woche appetitlich, danach ungenießbar durch '
        'Frostbrand.',
  _ =>
    'Frisch und unbehandelt (gemäßigt): 6 Stunden appetitlich, weitere 6 '
        'genießbar.',
};

/// Name des Inventareintrags für erjagte oder gefangene Tiere.
const String kWildbretGegenstand = 'Wildbret (frisch)';

/// Beschreibung eines Wildbret- oder Fischeintrags: Haltbarkeit in [region]
/// und wie sie sich verlängern lässt (WdE S. 121).
String frischfleischBeschreibung(Wildnisregion region) =>
    '${frischfleischHaltbarkeit(region)} Ausnehmen (Fleischer oder Kochen) '
    'verlängert die Haltbarkeit, Garen verdoppelt sie, Pökeln macht ab 7 '
    'TaP* dauerhaft haltbar (WdE S. 121).';

/// Wertet eine Jagd aus: TaP* = Tagesrationen Wildbret fürs Inventar, dazu
/// Geschossverlust und Wiederholbarkeit.
///
/// Mit einer Waffe des Helden ([JagdWaffe.slotId]) kennt das Ergebnis den Slot,
/// damit der Verlust am Geschossbestand abgebucht werden kann.
WildnisErgebnis werteJagdAus(JagdEingabe e, ProbeResult probe) {
  return wildnisRationenErgebnis(
    probe,
    erschwernis: berechneJagdErschwernis(e).gesamt,
    hinweis:
        '${e.waffe.verbrauch.hinweis} Weitere Versuche sind möglich, bis '
        'das Wild erlegt oder geflüchtet ist (Meisterentscheid).',
    gegenstand: kWildbretGegenstand,
    taetigkeit: e.art.titel,
    beschreibung: frischfleischBeschreibung(e.region),
    munition: WildnisMunition(
      waffenName: e.waffe.name,
      verbrauch: e.waffe.verbrauch,
      waffenSlotId: e.waffe.slotId,
    ),
  );
}
