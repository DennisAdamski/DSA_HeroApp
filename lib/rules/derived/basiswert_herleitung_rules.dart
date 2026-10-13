import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ini_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfbasis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

/// Schlüssel aller additiven Stat-Modifikatoren in fester Reihenfolge.
const List<String> kStatModifikatorSchluessel = <String>[
  'lep',
  'au',
  'asp',
  'kap',
  'mr',
  'iniBase',
  'at',
  'pa',
  'fk',
  'gs',
  'ausweichen',
  'rs',
];

/// Benannte Herkunft eines Teils der Stat-Modifikatoren.
class StatModifikatorQuelle {
  /// Erzeugt eine Quelle; [mods] sind ihre Beiträge je Basiswert.
  const StatModifikatorQuelle({
    required this.bezeichnung,
    required this.mods,
    this.quelle,
  });

  /// Anzeigename des Schritts, etwa „Rasse“ oder ein eigener Modifikatortext.
  final String bezeichnung;

  /// Beiträge dieser Quelle zu allen Basiswerten.
  final StatModifiers mods;

  /// Übergeordnete Herkunft, etwa „Eigener Modifikator“.
  final String? quelle;
}

/// Basiswerte eines Helden als erklärbare [Herleitung]en.
///
/// Die Endwerte sind die Werte von `DerivedStats`; `computeDerivedStatsFromInputs`
/// liest sie hier ab, statt sie getrennt zu rechnen.
class BasiswertHerleitungen {
  /// Erzeugt den Satz aller Basiswert-Herleitungen.
  const BasiswertHerleitungen({
    required this.maxLep,
    required this.maxAu,
    required this.maxAsp,
    required this.maxKap,
    required this.mr,
    required this.iniBase,
    required this.atBase,
    required this.paBase,
    required this.fkBase,
    required this.gs,
    required this.ausweichen,
  });

  /// Höchstwert der Lebensenergie.
  final Herleitung maxLep;

  /// Höchstwert der Ausdauer.
  final Herleitung maxAu;

  /// Höchstwert der Astralenergie.
  final Herleitung maxAsp;

  /// Höchstwert der Karmaenergie.
  final Herleitung maxKap;

  /// Magieresistenz.
  final Herleitung mr;

  /// Initiative-Basis einschließlich Sonderfertigkeiten.
  final Herleitung iniBase;

  /// Attacke-Basis.
  final Herleitung atBase;

  /// Parade-Basis.
  final Herleitung paBase;

  /// Fernkampf-Basis.
  final Herleitung fkBase;

  /// Geschwindigkeit.
  final Herleitung gs;

  /// Ausweichen ohne Waffenbezug (nur explizite Modifikatoren).
  final Herleitung ausweichen;

  /// Herleitung zum Stat-Schlüssel ([kStatModifikatorSchluessel]), sonst
  /// `null` (etwa für `rs`, das kein Basiswert ist).
  Herleitung? fuer(String statKey) {
    return switch (statKey) {
      'lep' => maxLep,
      'au' => maxAu,
      'asp' => maxAsp,
      'kap' => maxKap,
      'mr' => mr,
      'iniBase' => iniBase,
      'at' => atBase,
      'pa' => paBase,
      'fk' => fkBase,
      'gs' => gs,
      'ausweichen' => ausweichen,
      _ => null,
    };
  }
}

/// Zerlegt die Stat-Modifikatoren eines Helden in benannte Quellen.
///
/// Die Summe aller Quellen ist genau die Modifikatorsumme der Basiswerte
/// (Inspector, eigene, Text-, temporäre, Inventar- und Wundmodifikatoren).
/// [textAufteilung] zerlegt [textMods] nach Rasse, Kultur, Profession und
/// Vor-/Nachteilen; sie wird nur verwendet, wenn ihre Summe [textMods]
/// gleicht — sonst erscheint der Textanteil als ein Schritt, damit die
/// Herleitung nie vom gerechneten Wert abweicht.
List<StatModifikatorQuelle> sammleStatModifikatorQuellen({
  required HeroSheet sheet,
  required HeroState state,
  required StatModifiers textMods,
  List<StatModifikatorQuelle>? textAufteilung,
  StatModifiers inventar = const StatModifiers(),
  StatModifiers wunden = const StatModifiers(),
}) {
  final textQuellen =
      textAufteilung != null &&
          gleicheStatModifikatoren(summeDerQuellen(textAufteilung), textMods)
      ? textAufteilung
      : <StatModifikatorQuelle>[
          StatModifikatorQuelle(
            bezeichnung: 'Herkunft, Vor- und Nachteile',
            mods: textMods,
          ),
        ];
  return <StatModifikatorQuelle>[
    StatModifikatorQuelle(
      bezeichnung: 'Schnellmodifikatoren',
      mods: sheet.persistentMods,
      quelle: 'Inspector',
    ),
    ..._eigeneQuellen(sheet.statModifiers),
    ...textQuellen,
    StatModifikatorQuelle(
      bezeichnung: 'Temporäre Modifikatoren',
      mods: state.tempMods,
    ),
    StatModifikatorQuelle(bezeichnung: 'Inventar', mods: inventar),
    StatModifikatorQuelle(bezeichnung: 'Wunden', mods: wunden),
  ];
}

/// Text-Quellen aus der Aufschlüsselung nach Herkunft und Merkmalen.
List<StatModifikatorQuelle> herkunftsQuellen(ModifierSourceBreakdown b) {
  return <StatModifikatorQuelle>[
    StatModifikatorQuelle(bezeichnung: 'Rasse', mods: b.rasseStatMods),
    StatModifikatorQuelle(bezeichnung: 'Kultur', mods: b.kulturStatMods),
    StatModifikatorQuelle(
      bezeichnung: 'Profession',
      mods: b.professionStatMods,
    ),
    StatModifikatorQuelle(bezeichnung: 'Vorteile', mods: b.vorteileStatMods),
    StatModifikatorQuelle(bezeichnung: 'Nachteile', mods: b.nachteileStatMods),
  ];
}

/// Summe der Beiträge aller [quellen].
StatModifiers summeDerQuellen(Iterable<StatModifikatorQuelle> quellen) {
  var summe = const StatModifiers();
  for (final quelle in quellen) {
    summe = summe + quelle.mods;
  }
  return summe;
}

/// Vergleicht zwei Modifikatorsätze über alle bekannten Basiswerte.
bool gleicheStatModifikatoren(StatModifiers a, StatModifiers b) {
  for (final key in kStatModifikatorSchluessel) {
    if (statModValue(a, key) != statModValue(b, key)) {
      return false;
    }
  }
  return true;
}

/// Leitet alle Basiswerte aus Eigenschaften, Zukauf und [quellen] her.
///
/// [permanentAttributes] (ohne temporäre Zauberboni) tragen die
/// Ressourcen-Höchstwerte, [effectiveAttributes] alle übrigen Werte.
/// [wundGs] ist der GS-Anteil der Wunden, der in [quellen] enthalten ist;
/// er senkt die GS nie unter 1 (WdS S. 111).
BasiswertHerleitungen computeBasiswertHerleitungen({
  required HeroSheet sheet,
  required HeroState state,
  required Attributes permanentAttributes,
  required Attributes effectiveAttributes,
  required List<StatModifikatorQuelle> quellen,
  required bool hasFlinkFromVorteile,
  required bool hasBehaebigFromNachteile,
  int wundGs = 0,
}) {
  List<HerleitungsSchritt> mods(String key) =>
      _modifikatorSchritte(quellen, key);
  final p = permanentAttributes;
  final e = effectiveAttributes;
  final bought = sheet.bought;
  const untergrenze = 'Untergrenze 0';

  final lep = mitUntergrenze(
    <HerleitungsSchritt>[
      _grundwert(grundwertLep(p), '(KO ${p.ko} + KO ${p.ko} + KK ${p.kk}) / 2'),
      _stufe(
        stufenanteilLep(sheet.level),
        'Stufe ${sheet.level}, höchstens 21',
      ),
      _zukauf(bought.lep),
      ...mods('lep'),
    ],
    untergrenze: 0,
    bezeichnung: untergrenze,
  );
  final stufeAu = stufeFuerAu(sheet);
  final au = mitUntergrenze(
    <HerleitungsSchritt>[
      _grundwert(grundwertAu(p), '(MU ${p.mu} + KO ${p.ko} + GE ${p.ge}) / 2'),
      _stufe(
        stufeAu * 2,
        stufeAu == sheet.level
            ? 'Stufe $stufeAu × 2'
            : 'Aktivierungsstufe $stufeAu × 2 (episch)',
      ),
      _zukauf(bought.au),
      ...mods('au'),
    ],
    untergrenze: 0,
    bezeichnung: untergrenze,
  );
  final asp = mitUntergrenze(
    <HerleitungsSchritt>[
      _grundwert(
        grundwertAsp(p),
        '(MU ${p.mu} + IN ${p.inn} + CH ${p.ch}) / 2',
      ),
      _stufe(sheet.level * 2, 'Stufe ${sheet.level} × 2'),
      _zukauf(bought.asp),
      ...mods('asp'),
    ],
    untergrenze: 0,
    bezeichnung: untergrenze,
  );
  final kap = mitUntergrenze(
    <HerleitungsSchritt>[
      _grundwert(0, 'kein Grundwert aus Eigenschaften'),
      _zukauf(bought.kap),
      ...mods('kap'),
    ],
    untergrenze: 0,
    bezeichnung: untergrenze,
  );
  final mr = mitUntergrenze(
    <HerleitungsSchritt>[
      _grundwert(grundwertMr(e), '(MU ${e.mu} + KL ${e.kl} + KO ${e.ko}) / 5'),
      _zukauf(bought.mr),
      ...mods('mr'),
    ],
    untergrenze: 0,
    bezeichnung: untergrenze,
  );
  final special = sheet.combatConfig.specialRules;
  final ini = <HerleitungsSchritt>[
    _grundwert(
      grundwertIni(e),
      '(MU ${e.mu} + MU ${e.mu} + IN ${e.inn} + GE ${e.ge}) / 5',
    ),
    ...mods('iniBase'),
    if (special.kampfreflexe) _sf('Kampfreflexe', kKampfreflexeIniBonus),
    if (special.kampfgespuer) _sf('Kampfgespür', kKampfgespuerIniBonus),
  ];

  return BasiswertHerleitungen(
    maxLep: Herleitung(bezeichnung: 'LeP', schritte: lep),
    maxAu: Herleitung(bezeichnung: 'Au', schritte: au),
    maxAsp: Herleitung(bezeichnung: 'AsP', schritte: asp),
    maxKap: Herleitung(bezeichnung: 'KaP', schritte: kap),
    mr: Herleitung(bezeichnung: 'MR', schritte: mr),
    iniBase: Herleitung(bezeichnung: 'INI-Basis', schritte: ini),
    atBase: Herleitung(
      bezeichnung: 'AT-Basis',
      schritte: <HerleitungsSchritt>[
        _grundwert(
          grundwertAt(e),
          '(MU ${e.mu} + GE ${e.ge} + KK ${e.kk}) / 5',
        ),
        ...mods('at'),
      ],
    ),
    paBase: Herleitung(
      bezeichnung: 'PA-Basis',
      schritte: <HerleitungsSchritt>[
        _grundwert(
          grundwertPa(e),
          '(IN ${e.inn} + GE ${e.ge} + KK ${e.kk}) / 5',
        ),
        ...mods('pa'),
      ],
    ),
    fkBase: Herleitung(
      bezeichnung: 'FK-Basis',
      schritte: <HerleitungsSchritt>[
        _grundwert(
          grundwertFk(e),
          '(IN ${e.inn} + FF ${e.ff} + KK ${e.kk}) / 5',
        ),
        ...mods('fk'),
      ],
    ),
    gs: Herleitung(
      bezeichnung: 'GS',
      schritte: _gsSchritte(
        sheet: sheet,
        state: state,
        ge: e.ge,
        modSchritte: mods('gs'),
        wundGs: wundGs,
        hasFlink: hasFlinkFromVorteile,
        hasBehaebig: hasBehaebigFromNachteile,
      ),
    ),
    ausweichen: Herleitung(
      bezeichnung: 'Ausweichen',
      schritte: <HerleitungsSchritt>[
        _grundwert(0, 'ohne Waffe nur aus Modifikatoren'),
        ...mods('ausweichen'),
      ],
    ),
  );
}

// GS: Grundgeschwindigkeit mit GE-Anteil, Modifikatoren und Behinderung,
// dann Axxeleratus (verdoppelt), Flink/Behäbig und zuletzt die Wundgrenze.
List<HerleitungsSchritt> _gsSchritte({
  required HeroSheet sheet,
  required HeroState state,
  required int ge,
  required List<HerleitungsSchritt> modSchritte,
  required int wundGs,
  required bool hasFlink,
  required bool hasBehaebig,
}) {
  final activeArmorPieces = sheet.combatConfig.armor.pieces
      .where((piece) => piece.isActive)
      .toList(growable: false);
  final rgReduction = computeRgReduction(
    globalArmorTrainingLevel: sheet.combatConfig.armor.globalArmorTrainingLevel,
    activePieces: activeArmorPieces,
  );
  final beKampf = computeBeKampf(
    computeBeTotalRaw(activeArmorPieces),
    rgReduction,
  );
  final axxeleratus = isAxxeleratusEffectActive(sheet: sheet, state: state);
  final geAnteil = geAnteilGs(ge);
  final geText = switch (geAnteil) {
    1 => ', GE $ge über 15: +1',
    -1 => ', GE $ge unter 11: −1',
    _ => '',
  };
  final grundwert = _grundwert(
    kGrundgeschwindigkeit + geAnteil,
    '$kGrundgeschwindigkeit$geText',
  );

  // Dieselbe Kette einmal ohne den Wundanteil, für die Untergrenze.
  int gsFuer(int modSumme) {
    final vorZauber = grundwert.betrag + modSumme - beKampf;
    final mitZauber = computeAxxeleratusGs(
      gs: vorZauber,
      axxeleratusActive: axxeleratus,
    );
    return mitZauber + (hasFlink ? 1 : 0) - (hasBehaebig ? 1 : 0);
  }

  final modSumme = summeDer(modSchritte);
  final vorZauber = grundwert.betrag + modSumme - beKampf;
  final schritte = <HerleitungsSchritt>[
    grundwert,
    ...modSchritte,
    HerleitungsSchritt(
      bezeichnung: 'Behinderung',
      betrag: -beKampf,
      art: HerleitungsArt.modifikator,
      formel: 'BE $beKampf nach Rüstungsgewöhnung',
      quelle: 'Rüstung',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Axxeleratus',
      betrag:
          computeAxxeleratusGs(gs: vorZauber, axxeleratusActive: axxeleratus) -
          vorZauber,
      art: HerleitungsArt.zauber,
      formel: 'GS verdoppelt',
      bedingung: 'Axxeleratus aktiv',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Flink',
      betrag: hasFlink ? 1 : 0,
      art: HerleitungsArt.modifikator,
      quelle: 'Vorteil',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Behäbig',
      betrag: hasBehaebig ? -1 : 0,
      art: HerleitungsArt.modifikator,
      quelle: 'Nachteil',
    ),
  ];
  final endwert = begrenzeWundGs(
    ohneWunden: gsFuer(modSumme - wundGs),
    mitWunden: gsFuer(modSumme),
  );
  final ausgleich = endwert - summeDer(schritte);
  return <HerleitungsSchritt>[
    ...schritte,
    if (ausgleich != 0)
      HerleitungsSchritt(
        bezeichnung: 'Wunden senken die GS nicht unter 1',
        betrag: ausgleich,
        art: HerleitungsArt.begrenzung,
        quelle: 'WdS S. 111',
      ),
  ];
}

// Ein Schritt je Quelle, die zum Basiswert [key] beiträgt.
List<HerleitungsSchritt> _modifikatorSchritte(
  List<StatModifikatorQuelle> quellen,
  String key,
) {
  return <HerleitungsSchritt>[
    for (final quelle in quellen)
      HerleitungsSchritt(
        bezeichnung: quelle.bezeichnung,
        betrag: statModValue(quelle.mods, key),
        art: HerleitungsArt.modifikator,
        quelle: quelle.quelle,
      ),
  ];
}

// Eigene (benannte) Modifikatoren: je Eintrag eine Quelle für seinen Wert.
List<StatModifikatorQuelle> _eigeneQuellen(
  Map<String, List<HeroTalentModifier>> eigene,
) {
  final quellen = <StatModifikatorQuelle>[];
  for (final key in kStatModifikatorSchluessel) {
    for (final eintrag in eigene[key] ?? const <HeroTalentModifier>[]) {
      quellen.add(
        StatModifikatorQuelle(
          bezeichnung: eintrag.description,
          mods: _einzelwert(key, eintrag.modifier),
          quelle: 'Eigener Modifikator',
        ),
      );
    }
  }
  return quellen;
}

// Modifikatorsatz mit genau einem belegten Basiswert.
StatModifiers _einzelwert(String key, int wert) {
  return switch (key) {
    'lep' => StatModifiers(lep: wert),
    'au' => StatModifiers(au: wert),
    'asp' => StatModifiers(asp: wert),
    'kap' => StatModifiers(kap: wert),
    'mr' => StatModifiers(mr: wert),
    'iniBase' => StatModifiers(iniBase: wert),
    'at' => StatModifiers(at: wert),
    'pa' => StatModifiers(pa: wert),
    'fk' => StatModifiers(fk: wert),
    'gs' => StatModifiers(gs: wert),
    'ausweichen' => StatModifiers(ausweichen: wert),
    'rs' => StatModifiers(rs: wert),
    _ => const StatModifiers(),
  };
}

HerleitungsSchritt _grundwert(int betrag, String formel) => HerleitungsSchritt(
  bezeichnung: 'Grundwert',
  betrag: betrag,
  art: HerleitungsArt.grundwert,
  formel: formel,
);

HerleitungsSchritt _stufe(int betrag, String formel) => HerleitungsSchritt(
  bezeichnung: 'Stufe',
  betrag: betrag,
  art: HerleitungsArt.stufe,
  formel: formel,
);

HerleitungsSchritt _zukauf(int betrag) => HerleitungsSchritt(
  bezeichnung: 'Zugekauft',
  betrag: betrag,
  art: HerleitungsArt.zukauf,
);

HerleitungsSchritt _sf(String name, int betrag) => HerleitungsSchritt(
  bezeichnung: name,
  betrag: betrag,
  art: HerleitungsArt.sonderfertigkeit,
  quelle: 'Sonderfertigkeit',
);
