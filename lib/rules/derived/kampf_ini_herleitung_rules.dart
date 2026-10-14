/// Initiative und Ausweichen der Kampfvorschau als [Herleitung]en
/// (ARCH-04, Teilstand 3); Gegenstück zu `kampf_herleitung_rules.dart`.
///
/// Wie dort ordnen die Funktionen nur bereits ermittelte Bausteine an und
/// ergänzen Begrenzungen als eigene Schritte.
library;

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

// Optionaler Text: leere Angaben erscheinen nicht als Quelle.
String? _text(String? wert) {
  final getrimmt = wert?.trim() ?? '';
  return getrimmt.isEmpty ? null : getrimmt;
}

// ---------------------------------------------------------------------------
// Initiative
// ---------------------------------------------------------------------------

/// Initiative des Helden ohne Waffe, mindestens 0.
Herleitung herleiteHeldenIni({
  required int iniBasis,
  required int ebe,
  int sfBonus = 0,
  int kampfstil = 0,
  required int iniWurf,
  required int wuerfel,
  int axxeleratus = 0,
  int manuell = 0,
}) {
  final schritte = <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: 'INI-Basis',
      betrag: iniBasis,
      art: HerleitungsArt.grundwert,
      quelle: 'Basiswert',
    ),
    HerleitungsSchritt(
      bezeichnung: 'eBE',
      betrag: ebe,
      art: HerleitungsArt.modifikator,
      quelle: 'Behinderung',
    ),
    HerleitungsSchritt(
      bezeichnung: 'SF-Bonus',
      betrag: sfBonus,
      art: HerleitungsArt.sonderfertigkeit,
    ),
    HerleitungsSchritt(
      bezeichnung: 'Waffenloser Kampfstil',
      betrag: kampfstil,
      art: HerleitungsArt.sonderfertigkeit,
    ),
    HerleitungsSchritt(
      bezeichnung: 'INI-Wurf',
      betrag: iniWurf,
      art: HerleitungsArt.modifikator,
      formel: '${wuerfel}W6, eingetragener Wurf',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Axxeleratus',
      betrag: axxeleratus,
      art: HerleitungsArt.zauber,
      formel: 'INI-Basis $iniBasis ein zweites Mal',
      bedingung: 'Axxeleratus aktiv',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Manueller Mod',
      betrag: manuell,
      art: HerleitungsArt.modifikator,
    ),
  ];
  return Herleitung(
    bezeichnung: 'Helden-INI',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}

/// Initiative von Held und Waffe, mindestens 0.
///
/// Bei [nutztIniGe] `false` ist die INI/GE-Regel der Waffe bewusst
/// deaktiviert (0/0).
Herleitung herleiteWaffenIni({
  required Herleitung heldenIni,
  required int waffenIniMod,
  String? waffenName,
  required bool nutztIniGe,
  required int iniGe,
  required int ge,
  required int geBasis,
  required int geSchwelle,
  int geschoss = 0,
  String? geschossName,
  int waffenmeister = 0,
}) {
  final schritte = <HerleitungsSchritt>[
    ...heldenIni.schritte,
    HerleitungsSchritt(
      bezeichnung: 'Waffen-INI Mod',
      betrag: waffenIniMod,
      art: HerleitungsArt.modifikator,
      quelle: _text(waffenName),
    ),
    HerleitungsSchritt(
      bezeichnung: 'INI/GE',
      betrag: iniGe,
      art: HerleitungsArt.modifikator,
      formel: nutztIniGe
          ? '(GE $ge − $geBasis) / $geSchwelle, zur Null gerundet'
          : 'deaktiviert (0/0)',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Geschoss INI',
      betrag: geschoss,
      art: HerleitungsArt.modifikator,
      quelle: _text(geschossName),
    ),
    HerleitungsSchritt(
      bezeichnung: 'Waffenmeister INI',
      betrag: waffenmeister,
      art: HerleitungsArt.sonderfertigkeit,
    ),
  ];
  return Herleitung(
    bezeichnung: 'INI',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}

/// Kampfinitiative aus Haupthand und Nebenhand.
///
/// Mit Nebenhandwaffe ([nebenhandWaffenIni] gesetzt) gilt die höhere der
/// beiden Waffeninitiativen; der Unterschied erscheint als eigener Schritt.
/// Sonst wirkt der INI-Modifikator der Nebenhandausrüstung, mindestens 0.
Herleitung herleiteKampfIni({
  required Herleitung waffenIni,
  int? nebenhandWaffenIni,
  int nebenhandIniMod = 0,
  String? nebenhandName,
}) {
  if (nebenhandWaffenIni != null) {
    final differenz = nebenhandWaffenIni - waffenIni.wert;
    return Herleitung(
      bezeichnung: 'Kampf-INI',
      schritte: <HerleitungsSchritt>[
        ...waffenIni.schritte,
        if (differenz > 0)
          HerleitungsSchritt(
            bezeichnung: 'Höhere INI der Nebenhandwaffe',
            betrag: differenz,
            art: HerleitungsArt.modifikator,
            formel: 'Nebenhand-Waffen-INI $nebenhandWaffenIni',
            quelle: _text(nebenhandName),
          ),
      ],
    );
  }
  final schritte = <HerleitungsSchritt>[
    ...waffenIni.schritte,
    HerleitungsSchritt(
      bezeichnung: 'Nebenhand INI',
      betrag: nebenhandIniMod,
      art: HerleitungsArt.modifikator,
      quelle: _text(nebenhandName),
    ),
  ];
  return Herleitung(
    bezeichnung: 'Kampf-INI',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}

// ---------------------------------------------------------------------------
// Ausweichen
// ---------------------------------------------------------------------------

/// Schrittname des INI-Bonus im Ausweichen; das Gefecht ersetzt ihn durch den
/// Sitzungsanteil (`gefecht_herleitung_rules.dart`).
const String kAusweichenIniBonusSchritt = 'INI-Bonus';

/// Ausweichen in der aktuellen Ausrüstung, mindestens 0.
///
/// Entspricht `computeAusweichen`; [paBasis] ist die PA-Basis ohne
/// Axxeleratus, der Zauber wirkt über [axxeleratusPaBasis] und zusätzlich
/// über [axxeleratus].
Herleitung herleiteAusweichen({
  required int paBasis,
  int axxeleratusPaBasis = 0,
  required int sfBonus,
  required int akrobatik,
  int axxeleratus = 0,
  required int iniBonus,
  required int kampfInitiative,
  int manuell = 0,
  bool flink = false,
  bool behaebig = false,
  required int beKampf,
}) {
  final schritte = <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: 'PA-Basis',
      betrag: paBasis,
      art: HerleitungsArt.grundwert,
      quelle: 'Basiswert',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Axxeleratus PA',
      betrag: axxeleratusPaBasis,
      art: HerleitungsArt.zauber,
      bedingung: 'Axxeleratus aktiv',
    ),
    HerleitungsSchritt(
      bezeichnung: 'SF Ausweichen',
      betrag: sfBonus,
      art: HerleitungsArt.sonderfertigkeit,
    ),
    HerleitungsSchritt(
      bezeichnung: 'Akrobatik',
      betrag: akrobatik,
      art: HerleitungsArt.modifikator,
      formel: '(TaW Akrobatik − 9) / 3, abgerundet',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Axxeleratus',
      betrag: axxeleratus,
      art: HerleitungsArt.zauber,
      bedingung: 'Axxeleratus aktiv',
    ),
    HerleitungsSchritt(
      bezeichnung: kAusweichenIniBonusSchritt,
      betrag: iniBonus,
      art: HerleitungsArt.modifikator,
      formel: '(Kampf-INI $kampfInitiative − 20) / 10, aufgerundet',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Manueller Mod',
      betrag: manuell,
      art: HerleitungsArt.modifikator,
    ),
    HerleitungsSchritt(
      bezeichnung: 'Flink',
      betrag: flink ? 1 : 0,
      art: HerleitungsArt.modifikator,
      quelle: 'Vorteil',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Behäbig',
      betrag: behaebig ? -1 : 0,
      art: HerleitungsArt.modifikator,
      quelle: 'Nachteil',
    ),
    HerleitungsSchritt(
      bezeichnung: 'BE Kampf',
      betrag: -beKampf,
      art: HerleitungsArt.modifikator,
      quelle: 'Rüstung',
    ),
  ];
  return Herleitung(
    bezeichnung: 'Ausweichen',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}
