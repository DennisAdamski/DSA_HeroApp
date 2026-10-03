import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'maneuver_rules.dart';
import 'gefecht_kampfmittel_rules.dart';

/// Kombinierbare Kategorien, unabhängig vom für die Ausführung gewählten Budget.
enum GefechtsManoeverfilter { alle, angriff, verteidigung, sonstige }

/// Gemischte AT/PA gehören in beide Filter; passive Fähigkeiten bleiben sonstige.
Set<GefechtsManoeverfilter> gefechtsManoeverkategorien(ManeuverDef m) {
  // Diese aktiven Split-Katalogeinträge besitzen noch keinen Typ; IDs sind stabil.
  const katalogluecken = <String, GefechtsManoeverfilter>{
    'man_niederwerfen': GefechtsManoeverfilter.angriff,
    'man_offensiver_distanzklassenwechsel': GefechtsManoeverfilter.angriff,
    'man_formations_parade': GefechtsManoeverfilter.verteidigung,
    'man_seitenwechsel': GefechtsManoeverfilter.verteidigung,
    'man_eisenhagel': GefechtsManoeverfilter.angriff,
  };
  final katalogkategorie = katalogluecken[m.id];
  if (m.typ.trim().isEmpty && katalogkategorie != null) {
    return {katalogkategorie};
  }
  final typ = m.typ.toLowerCase();
  final angriff =
      typ.contains('angriff') ||
      typ.contains('attacke') ||
      RegExp(r'(^|\W)at($|\W)').hasMatch(typ);
  final abwehr =
      typ.contains('abwehr') ||
      typ.contains('parade') ||
      RegExp(r'(^|\W)pa($|\W)').hasMatch(typ);
  return {
    if (angriff) GefechtsManoeverfilter.angriff,
    if (abwehr) GefechtsManoeverfilter.verteidigung,
    if (!angriff && !abwehr) GefechtsManoeverfilter.sonstige,
  };
}

/// Verknüpft Kategorie, Suchtext, Lernstand und bekannte Sperren mit UND.
bool gefechtsManoeverImFilter(
  ManeuverDef m, {
  GefechtsManoeverfilter kategorie = GefechtsManoeverfilter.alle,
  String suche = '',
  bool nurErlernte = false,
  bool ohneSperre = false,
  bool erlernt = true,
  bool gesperrt = false,
}) =>
    (kategorie == GefechtsManoeverfilter.alle ||
        gefechtsManoeverkategorien(m).contains(kategorie)) &&
    m.name.toLowerCase().contains(suche.toLowerCase()) &&
    (!nurErlernte || erlernt) &&
    (!ohneSperre || !gesperrt);

/// Lernt auch talentbezogene Varianten; allgemeine Grundaktionen benötigen kein AP.
bool gefechtsManoeverErlernt(
  ManeuverDef m,
  HeroComputedSnapshot s,
  RulesCatalog k,
) {
  final gelernt = learnedManeuverIds(s.hero.combatConfig, k);
  final talent = s.hero.combatConfig.selectedWeapon.talentId;
  return gelernt.contains(m.id) || gelernt.contains('${m.id}::$talent');
}

/// Versteckt fehlende oder grundsätzlich widersprüchliche Schildausrüstung.
bool gefechtsSchildparadeSichtbar(HeroComputedSnapshot s) =>
    gefechtsKampfmittelprofile(s).any(
      (p) =>
          p.wahl.art == GefechtsKampfmittelArt.schild &&
          p.pa != null &&
          p.sperren.isEmpty,
    );
