/// Waffen-Großmeister im Gefecht (Hausregel „Epische Stufen“ S. 18).
///
/// Säbel-Pool: Punkte in Höhe des GE/INI-Bonus je KR, frei auf
/// Betäubungsschlag, Entwaffnen, Klingensturm und Klingenwand verteilbar.
/// Bonusschaden aus GE gilt nicht mit Wuchtschlag und darauf aufbauenden
/// Manövern; dann zählt wieder der TP/KK-Zuschlag aus KK.
library;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Manöver, die der Säbel-Pool erleichtert.
const Set<String> gefechtsPoolManoever = <String>{
  'man_betaeubungsschlag',
  'man_entwaffnen',
  'man_entwaffnen_meisterlich',
  'man_klingensturm',
  'man_klingenwand',
};

/// Der Pool gilt nur für die Hauptwaffe, für die die Vorschau rechnet.
bool _hauptwaffe(GefechtsKampfmittelwahl? wahl) =>
    wahl == null || wahl.art == GefechtsKampfmittelArt.hauptwaffe;

/// Noch freie Pool-Punkte dieser KR; 0 ohne Säbel-Großmeister.
int gefechtsGrossmeisterPoolFrei(
  Gefechtszustand s,
  HeroComputedSnapshot snap, {
  GefechtsKampfmittelwahl? kampfmittel,
}) {
  if (!_hauptwaffe(kampfmittel)) return 0;
  final pool = snap.combatPreviewStats.meisterschaft.poolPunkte ?? 0;
  final frei = pool - s.grossmeisterPoolVerbraucht;
  return frei < 0 ? 0 : frei;
}

/// Ob [manoever] mit der gewählten Waffe Pool-Punkte annimmt.
bool gefechtsPoolMoeglich(
  HeroComputedSnapshot snap,
  ManeuverDef? manoever, {
  GefechtsKampfmittelwahl? kampfmittel,
}) =>
    manoever != null &&
    gefechtsPoolManoever.contains(manoever.id) &&
    _hauptwaffe(kampfmittel) &&
    snap.combatPreviewStats.meisterschaft.poolPunkte != null;

/// Prüft die Pool-Punkte des Auftrags und rechnet sie als Erleichterung ein.
Gefechtspruefung ergaenzeGefechtsGrossmeisterPool(
  Gefechtspruefung p,
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  GefechtAuftrag a,
) {
  final punkte = a.grossmeisterPool;
  if (punkte == 0) return p;
  final frei = gefechtsGrossmeisterPoolFrei(
    s,
    snap,
    kampfmittel: a.kampfmittel,
  );
  final sperren = <String>[
    if (punkte < 0) 'Pool-Punkte dürfen nicht negativ sein.',
    if (!gefechtsPoolMoeglich(snap, a.manoever, kampfmittel: a.kampfmittel))
      'Säbel-Pool nur für Betäubungsschlag, Entwaffnen, Klingensturm und '
          'Klingenwand mit der Hauptwaffe.',
    if (punkte > frei) 'Säbel-Pool: nur noch $frei Punkte in dieser KR.',
  ];
  if (sperren.isNotEmpty) {
    return p.copyWith(
      status: Gefechtsfreigabe.gesperrt,
      sperrgruende: [...p.sperrgruende, ...sperren],
      gruende: [...sperren, ...p.gruende],
    );
  }
  return p.copyWith(
    zielwert: p.zielwert == null ? null : p.zielwert! + punkte,
    erschwernis: p.erschwernis - punkte,
    modifikatoren: [
      ...p.modifikatoren,
      Gefechtsmodifikator('Säbel-Pool', -punkte),
    ],
    grossmeisterPool: punkte,
  );
}

/// TP-Korrektur, wenn Bonusschaden aus GE auf eine Wuchtschlag-Ansage oder
/// ein darauf aufbauendes Manöver trifft: zurück zum KK-Zuschlag.
int gefechtsGeStattKkKorrektur(
  HeroComputedSnapshot snap,
  GefechtAuftrag a, {
  GefechtsKampfmittelwahl? kampfmittel,
}) {
  final m = snap.combatPreviewStats.meisterschaft;
  if (!m.geStattKkAktiv || !_hauptwaffe(kampfmittel)) return 0;
  final manoever = a.manoever;
  final wucht =
      a.wuchtschlag > 0 ||
      manoever?.id == 'man_wuchtschlag' ||
      (manoever?.voraussetzungen.contains('Wuchtschlag') ?? false);
  return wucht ? m.tpKkMitKk - m.tpKkMitGe : 0;
}

/// Klingensturm/Klingenwand: Pool-Punkte erhöhen den aufzuteilenden
/// Ausgangswert (Epische Stufen S. 18, Beispiel Klingensturm und -wand).
int gefechtsKlingenbasisMitPool(int basis, int punkte, {required int frei}) {
  if (punkte < 0 || punkte > frei) {
    throw ArgumentError('Säbel-Pool: höchstens $frei Punkte in dieser KR.');
  }
  return basis + punkte;
}
