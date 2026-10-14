/// Kampfvorschau als erklärbare [Herleitung]en (ARCH-04, Teilstand 3).
///
/// Die Funktionen hier rechnen keine eigenen Regeln: Sie ordnen die bereits
/// ermittelten Bausteine der Kampfvorschau (`combat_rules.dart`) als Schritte
/// an und ergänzen Begrenzungen als eigene Schritte. `computeCombatPreviewStats`
/// liest die Endwerte hier ab, so stimmen Anzeige und verwendeter Wert immer
/// überein.
library;

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

/// Herleitungen der Kampfvorschau für die Haupthand.
class KampfHerleitungen {
  /// Erzeugt den Satz; [pa] und [paMitIniParade] fehlen im Fernkampf.
  const KampfHerleitungen({
    required this.rs,
    required this.beKampf,
    required this.ebe,
    required this.at,
    required this.pa,
    required this.paMitIniParade,
    required this.tpZuschlag,
    required this.heldenIni,
    required this.kampfIni,
    required this.ausweichen,
    this.schildPa,
  });

  /// Rüstungsschutz einschließlich Modifikatoren und Armatrutz.
  final Herleitung rs;

  /// Kampfbehinderung nach Rüstungsgewöhnung.
  final Herleitung beKampf;

  /// Effektive Behinderung der gewählten Waffe (höchstens 0).
  final Herleitung ebe;

  /// Attacke bzw. Fernkampfwert der Haupthand.
  final Herleitung at;

  /// Parade ohne INI-Parade-Bonus; `null` im Fernkampf.
  final Herleitung? pa;

  /// Parade mit INI-Parade-Bonus; `null` im Fernkampf.
  final Herleitung? paMitIniParade;

  /// Fester TP-Zuschlag zu den Würfeln.
  final Herleitung tpZuschlag;

  /// Initiative des Helden ohne Waffe.
  final Herleitung heldenIni;

  /// Kampfinitiative mit Waffe und Nebenhand.
  final Herleitung kampfIni;

  /// Ausweichen in der aktuellen Ausrüstung.
  final Herleitung ausweichen;

  /// Parade mit dem Schild; `null` ohne geführten Schild.
  final Herleitung? schildPa;
}

/// Herleitungen einer Nebenhandwaffe.
class NebenhandHerleitungen {
  /// Erzeugt den Satz; [pa] und [paMitIniParade] fehlen im Fernkampf.
  const NebenhandHerleitungen({
    required this.at,
    required this.pa,
    required this.paMitIniParade,
    required this.tpZuschlag,
  });

  /// Attacke bzw. Fernkampfwert der Nebenhandwaffe.
  final Herleitung at;

  /// Parade ohne INI-Parade-Bonus; `null` im Fernkampf.
  final Herleitung? pa;

  /// Parade mit INI-Parade-Bonus; `null` im Fernkampf.
  final Herleitung? paMitIniParade;

  /// Fester TP-Zuschlag zu den Würfeln.
  final Herleitung tpZuschlag;
}

// Optionaler Text: leere Angaben erscheinen nicht als Quelle.
String? _text(String? wert) {
  final getrimmt = wert?.trim() ?? '';
  return getrimmt.isEmpty ? null : getrimmt;
}

String _mitVorzeichen(int wert) => wert >= 0 ? '+$wert' : '$wert';

/// Schrittnamen des Parierwaffenanteils in der Haupthand-PA; das Gefecht
/// trennt damit die Hauptwaffenparade von der Kombination.
const String kNebenhandPaSchritt = 'Nebenhand PA';
const String kParierwaffenSfSchritt = 'SF Parierwaffen';

// ---------------------------------------------------------------------------
// Rüstung und Behinderung
// ---------------------------------------------------------------------------

/// Rüstungsschutz aus den aktiven Teilen, [modifikatoren] und [armatrutz].
Herleitung herleiteRuestungsschutz({
  required List<ArmorPiece> aktiveTeile,
  required int modifikatoren,
  required int armatrutz,
}) {
  final schritte = <HerleitungsSchritt>[
    if (aktiveTeile.isEmpty)
      const HerleitungsSchritt(
        bezeichnung: 'Keine Rüstung',
        betrag: 0,
        art: HerleitungsArt.grundwert,
      ),
    for (final teil in aktiveTeile)
      HerleitungsSchritt(
        bezeichnung: _text(teil.name) ?? 'Rüstungsteil',
        betrag: clampNonNegative(teil.rs),
        art: HerleitungsArt.grundwert,
        quelle: 'Rüstung',
      ),
    HerleitungsSchritt(
      bezeichnung: 'Modifikatoren',
      betrag: modifikatoren,
      art: HerleitungsArt.modifikator,
    ),
    HerleitungsSchritt(
      bezeichnung: 'Armatrutz',
      betrag: armatrutz,
      art: HerleitungsArt.zauber,
      bedingung: 'Armatrutz aktiv',
    ),
  ];
  return Herleitung(
    bezeichnung: 'RS',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}

/// Kampfbehinderung aus den aktiven Teilen abzüglich [rgReduktion].
Herleitung herleiteBeKampf({
  required List<ArmorPiece> aktiveTeile,
  required int rgReduktion,
  required int ruestungsgewoehnung,
}) {
  final schritte = <HerleitungsSchritt>[
    if (aktiveTeile.isEmpty)
      const HerleitungsSchritt(
        bezeichnung: 'Keine Rüstung',
        betrag: 0,
        art: HerleitungsArt.grundwert,
      ),
    for (final teil in aktiveTeile)
      HerleitungsSchritt(
        bezeichnung: _text(teil.name) ?? 'Rüstungsteil',
        betrag: clampNonNegative(teil.be),
        art: HerleitungsArt.grundwert,
        quelle: 'Rüstung',
      ),
    HerleitungsSchritt(
      bezeichnung: 'Rüstungsgewöhnung',
      betrag: -rgReduktion,
      art: HerleitungsArt.sonderfertigkeit,
      quelle: ruestungsgewoehnung > 0
          ? 'Rüstungsgewöhnung ${_roemisch(ruestungsgewoehnung)}'
          : null,
    ),
  ];
  return Herleitung(
    bezeichnung: 'BE Kampf',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}

String _roemisch(int stufe) => switch (stufe) {
  1 => 'I',
  2 => 'II',
  3 => 'III',
  _ => '$stufe',
};

/// Effektive Behinderung: −BE Kampf − BE-Regel des Talents, höchstens 0.
Herleitung herleiteEbe({
  required int beKampf,
  required int beMod,
  String? talentName,
  String? talentBe,
}) {
  final talent = _text(talentName);
  final regel = _text(talentBe);
  final schritte = <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: 'BE Kampf',
      betrag: -beKampf,
      art: HerleitungsArt.grundwert,
      quelle: 'Rüstung',
    ),
    HerleitungsSchritt(
      bezeichnung: 'BE-Regel des Talents',
      betrag: -beMod,
      art: HerleitungsArt.modifikator,
      formel: regel == null ? null : 'eBE $regel',
      quelle: talent,
    ),
  ];
  return Herleitung(
    bezeichnung: 'eBE',
    schritte: mitObergrenze(
      schritte,
      obergrenze: 0,
      bezeichnung: 'Höchstens 0',
    ),
  );
}

// ---------------------------------------------------------------------------
// Attacke und Parade
// ---------------------------------------------------------------------------

/// Gemeinsame Schritte der Waffe für Nahkampf-AT und -PA.
List<HerleitungsSchritt> _waffenSchritte({
  required String wert,
  required int talent,
  required String? talentName,
  required int waffenWm,
  required String? waffenName,
  required int waffenmeister,
  required int ebeAnteil,
  required String ebeFormel,
  required int spezialisierung,
}) {
  return <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: 'Talent $wert-Anteil',
      betrag: talent,
      art: HerleitungsArt.zukauf,
      quelle: _text(talentName),
    ),
    HerleitungsSchritt(
      bezeichnung: 'WM $wert (Waffe)',
      betrag: waffenWm,
      art: HerleitungsArt.modifikator,
      quelle: _text(waffenName),
    ),
    HerleitungsSchritt(
      bezeichnung: 'Waffenmeister $wert',
      betrag: waffenmeister,
      art: HerleitungsArt.sonderfertigkeit,
    ),
    HerleitungsSchritt(
      bezeichnung: 'eBE $wert-Anteil',
      betrag: ebeAnteil,
      art: HerleitungsArt.modifikator,
      formel: ebeFormel,
      quelle: 'Behinderung',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Spezialisierung',
      betrag: spezialisierung,
      art: HerleitungsArt.sonderfertigkeit,
    ),
  ];
}

/// Attacke im Nahkampf (Haupt- oder Nebenhand).
///
/// Die Summanden entsprechen genau der AT-Summe der Kampfvorschau; für die
/// Nebenhandwaffe stehen [falscheHand] und Schildarmwunden in [armWunden].
Herleitung herleiteNahkampfAt({
  required int atBasis,
  required int talentAt,
  String? talentName,
  required int waffenWm,
  String? waffenName,
  required int waffenmeister,
  required int ebe,
  required int ebeAnteil,
  required int spezialisierung,
  int kampfstil = 0,
  int nebenhand = 0,
  String? nebenhandName,
  int falscheHand = 0,
  String? falscheHandLabel,
  int armWunden = 0,
  String armBezeichnung = 'Wunden Schwertarm',
  int manuell = 0,
}) {
  return Herleitung(
    bezeichnung: 'AT',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: 'AT-Basis',
        betrag: atBasis,
        art: HerleitungsArt.grundwert,
        quelle: 'Basiswert',
      ),
      ..._waffenSchritte(
        wert: 'AT',
        talent: talentAt,
        talentName: talentName,
        waffenWm: waffenWm,
        waffenName: waffenName,
        waffenmeister: waffenmeister,
        ebeAnteil: ebeAnteil,
        ebeFormel: 'eBE $ebe / 2, zur Null gerundet',
        spezialisierung: spezialisierung,
      ),
      ..._zusatzSchritte(
        kampfstil: kampfstil,
        nebenhand: nebenhand,
        nebenhandBezeichnung: 'Nebenhand AT',
        nebenhandName: nebenhandName,
        falscheHand: falscheHand,
        falscheHandLabel: falscheHandLabel,
        armWunden: armWunden,
        armBezeichnung: armBezeichnung,
        manuell: manuell,
      ),
    ],
  );
}

/// Parade im Nahkampf (Haupt- oder Nebenhand), ohne INI-Parade-Bonus.
///
/// Mit Parierwaffe trägt [nebenhand] deren PA-WM und [parierwaffeSf] den
/// Anteil der Parierwaffen-SF (Quelle [parierwaffeSfName]).
Herleitung herleiteNahkampfPa({
  required int paBasis,
  int axxeleratus = 0,
  required int talentPa,
  String? talentName,
  required int waffenWm,
  String? waffenName,
  required int waffenmeister,
  required int ebe,
  required int ebeAnteil,
  required int spezialisierung,
  int kampfstil = 0,
  int nebenhand = 0,
  String? nebenhandName,
  int parierwaffeSf = 0,
  String? parierwaffeSfName,
  int falscheHand = 0,
  String? falscheHandLabel,
  int armWunden = 0,
  String armBezeichnung = 'Wunden Schwertarm',
  int manuell = 0,
}) {
  return Herleitung(
    bezeichnung: 'PA',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: 'PA-Basis',
        betrag: paBasis,
        art: HerleitungsArt.grundwert,
        quelle: 'Basiswert',
      ),
      HerleitungsSchritt(
        bezeichnung: 'Axxeleratus PA',
        betrag: axxeleratus,
        art: HerleitungsArt.zauber,
        bedingung: 'Axxeleratus aktiv',
      ),
      ..._waffenSchritte(
        wert: 'PA',
        talent: talentPa,
        talentName: talentName,
        waffenWm: waffenWm,
        waffenName: waffenName,
        waffenmeister: waffenmeister,
        ebeAnteil: ebeAnteil,
        ebeFormel: 'eBE $ebe / 2, von der Null weg gerundet',
        spezialisierung: spezialisierung,
      ),
      ..._zusatzSchritte(
        kampfstil: kampfstil,
        nebenhand: nebenhand,
        nebenhandBezeichnung: kNebenhandPaSchritt,
        nebenhandName: nebenhandName,
        parierwaffeSf: parierwaffeSf,
        parierwaffeSfName: parierwaffeSfName,
        falscheHand: falscheHand,
        falscheHandLabel: falscheHandLabel,
        armWunden: armWunden,
        armBezeichnung: armBezeichnung,
        manuell: manuell,
      ),
    ],
  );
}

List<HerleitungsSchritt> _zusatzSchritte({
  required int kampfstil,
  required int nebenhand,
  required String nebenhandBezeichnung,
  required String? nebenhandName,
  int parierwaffeSf = 0,
  String? parierwaffeSfName,
  required int falscheHand,
  required String? falscheHandLabel,
  required int armWunden,
  required String armBezeichnung,
  required int manuell,
}) {
  return <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: 'Waffenloser Kampfstil',
      betrag: kampfstil,
      art: HerleitungsArt.sonderfertigkeit,
    ),
    HerleitungsSchritt(
      bezeichnung: nebenhandBezeichnung,
      betrag: nebenhand,
      art: HerleitungsArt.modifikator,
      quelle: _text(nebenhandName),
    ),
    HerleitungsSchritt(
      bezeichnung: kParierwaffenSfSchritt,
      betrag: parierwaffeSf,
      art: HerleitungsArt.sonderfertigkeit,
      quelle: parierwaffeSfName ?? 'ohne Parierwaffen-SF',
    ),
    HerleitungsSchritt(
      bezeichnung: _text(falscheHandLabel) ?? 'Falsche Hand',
      betrag: falscheHand,
      art: HerleitungsArt.modifikator,
    ),
    HerleitungsSchritt(
      bezeichnung: armBezeichnung,
      betrag: armWunden,
      art: HerleitungsArt.modifikator,
      quelle: 'Wunden',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Manueller Mod',
      betrag: manuell,
      art: HerleitungsArt.modifikator,
    ),
  ];
}

/// Parade mit dem Schild (WdS S. 70 f.): PA-Basis, Schild-WM, Bonus aus
/// Linkhand oder Schildkampf, PA-Anteil der eBE und Wunden des Schildarms.
Herleitung herleiteSchildPa({
  required int paBasis,
  int axxeleratus = 0,
  required int schildWm,
  String? schildName,
  required int sfBonus,
  String? sfName,
  required int ebe,
  required int ebeAnteil,
  int armWunden = 0,
}) {
  return Herleitung(
    bezeichnung: 'Schild-PA',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: 'PA-Basis',
        betrag: paBasis,
        art: HerleitungsArt.grundwert,
        quelle: 'Basiswert',
      ),
      HerleitungsSchritt(
        bezeichnung: 'Axxeleratus PA',
        betrag: axxeleratus,
        art: HerleitungsArt.zauber,
        bedingung: 'Axxeleratus aktiv',
      ),
      HerleitungsSchritt(
        bezeichnung: 'Schild-WM',
        betrag: schildWm,
        art: HerleitungsArt.modifikator,
        quelle: _text(schildName),
      ),
      HerleitungsSchritt(
        bezeichnung: 'SF Schildkampf',
        betrag: sfBonus,
        art: HerleitungsArt.sonderfertigkeit,
        formel: 'Linkhand +1, Schildkampf I +3, Schildkampf II +5',
        quelle: sfName,
      ),
      HerleitungsSchritt(
        bezeichnung: 'eBE PA-Anteil',
        betrag: ebeAnteil,
        art: HerleitungsArt.modifikator,
        formel: 'eBE $ebe / 2, von der Null weg gerundet',
        quelle: 'Behinderung',
      ),
      HerleitungsSchritt(
        bezeichnung: 'Wunden Schildarm',
        betrag: armWunden,
        art: HerleitungsArt.modifikator,
        quelle: 'Wunden',
      ),
    ],
  );
}

/// Fernkampfwert: genau die Summanden von `computeRangedAtValue`.
Herleitung herleiteFernkampfAt({
  required int fkBasis,
  required int talentAt,
  String? talentName,
  required int waffenWm,
  String? waffenName,
  required int ebe,
  required int spezialisierung,
  int geschoss = 0,
  String? geschossName,
  int manuell = 0,
}) {
  return Herleitung(
    bezeichnung: 'FK',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: 'FK-Basis',
        betrag: fkBasis,
        art: HerleitungsArt.grundwert,
        quelle: 'Basiswert',
      ),
      HerleitungsSchritt(
        bezeichnung: 'Talent AT-Anteil',
        betrag: talentAt,
        art: HerleitungsArt.zukauf,
        quelle: _text(talentName),
      ),
      HerleitungsSchritt(
        bezeichnung: 'WM AT (Waffe)',
        betrag: waffenWm,
        art: HerleitungsArt.modifikator,
        quelle: _text(waffenName),
      ),
      HerleitungsSchritt(
        bezeichnung: 'eBE',
        betrag: ebe,
        art: HerleitungsArt.modifikator,
        formel: 'volle eBE',
        quelle: 'Behinderung',
      ),
      HerleitungsSchritt(
        bezeichnung: 'Spezialisierung',
        betrag: spezialisierung,
        art: HerleitungsArt.sonderfertigkeit,
      ),
      HerleitungsSchritt(
        bezeichnung: 'Geschoss AT',
        betrag: geschoss,
        art: HerleitungsArt.modifikator,
        quelle: _text(geschossName),
      ),
      HerleitungsSchritt(
        bezeichnung: 'Manueller Mod',
        betrag: manuell,
        art: HerleitungsArt.modifikator,
      ),
    ],
  );
}

/// Parade mit INI-Parade-Bonus aus der Kampfinitiative.
Herleitung herleitePaMitIniParade({
  required Herleitung pa,
  required int iniParadeMod,
  required int kampfInitiative,
}) {
  return Herleitung(
    bezeichnung: 'PA',
    schritte: <HerleitungsSchritt>[
      ...pa.schritte,
      HerleitungsSchritt(
        bezeichnung: 'INI-Parade-Bonus',
        betrag: iniParadeMod,
        art: HerleitungsArt.modifikator,
        formel: '(Kampf-INI $kampfInitiative − 11) / 10',
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Trefferpunkte
// ---------------------------------------------------------------------------

/// Fester TP-Zuschlag zu den Würfeln der Waffe.
///
/// [kkBasis] und [kkSchwelle] sind die wirksamen Werte nach Waffenmeister;
/// [nutztTpKk] `false` steht für eine bewusst deaktivierte TP/KK-Regel (0/0).
Herleitung herleiteTpZuschlag({
  required int tpGrundwert,
  String? waffenName,
  required bool nutztTpKk,
  required int tpKk,
  required int kk,
  required int kkBasis,
  required int kkSchwelle,
  int waffenmeisterKkBasis = 0,
  int waffenmeisterKkSchwelle = 0,
  int axxeleratus = 0,
  int entfernung = 0,
  String? entfernungLabel,
  int geschoss = 0,
  String? geschossName,
}) {
  final wmHinweis = waffenmeisterKkBasis != 0 || waffenmeisterKkSchwelle != 0
      ? 'Waffenmeister: Basis ${_mitVorzeichen(waffenmeisterKkBasis)}, '
            'Schwelle ${_mitVorzeichen(waffenmeisterKkSchwelle)}'
      : null;
  return Herleitung(
    bezeichnung: 'TP',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: 'TP Grundwert',
        betrag: tpGrundwert,
        art: HerleitungsArt.grundwert,
        quelle: _text(waffenName),
      ),
      HerleitungsSchritt(
        bezeichnung: 'TP/KK',
        betrag: tpKk,
        art: HerleitungsArt.modifikator,
        formel: nutztTpKk
            ? '(KK $kk − $kkBasis) / $kkSchwelle, ganzzahlig'
            : 'deaktiviert (0/0)',
        bedingung: wmHinweis,
      ),
      HerleitungsSchritt(
        bezeichnung: 'Axxeleratus',
        betrag: axxeleratus,
        art: HerleitungsArt.zauber,
        bedingung: 'Axxeleratus aktiv',
      ),
      HerleitungsSchritt(
        bezeichnung: 'Entfernung',
        betrag: entfernung,
        art: HerleitungsArt.modifikator,
        quelle: _text(entfernungLabel),
      ),
      HerleitungsSchritt(
        bezeichnung: 'Geschoss',
        betrag: geschoss,
        art: HerleitungsArt.modifikator,
        quelle: _text(geschossName),
      ),
    ],
  );
}
